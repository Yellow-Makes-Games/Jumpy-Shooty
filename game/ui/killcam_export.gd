class_name KillcamExport
extends Node
## Saves a killcam as a video to share: plays the clip offscreen, in a world of its own
## with a copy of the map, one frame at a time (FPS a second of video, however fast the
## computer draws), with the killcam's words over it, and writes an AVI (AviWriter).
## The file goes in the Videos folder, under "Jumpy Shooty" (see folder()).
##
##   var save := KillcamExport.new()
##   add_child(save)
##   save.finished.connect(func(path, error): ...)
##   save.start(clip)

signal progress(fraction: float)
signal finished(path: String, error: String)   ## error is "" when it worked

const SIZE := Vector2i(1280, 720)
const FPS := 30
const HOLD := 1.0   ## seconds the last frame stays at the end

var _view: SubViewport
var _player: KillcamView
var _overlay: Control
var _map_name := ""
## Where to save (a folder); "" for folder(). Tests save to a scratch folder instead.
var into := ""


## Where videos are saved: Videos/Jumpy Shooty (or the game's own data folder if the
## computer has no Videos folder).
static func folder() -> String:
	var videos := OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
	if videos == "":
		return ProjectSettings.globalize_path("user://killcams")
	return videos.path_join("Jumpy Shooty")


## A file name for this kill: killcam_Host_on_P2_2026-11-17_16-05-09.avi
static func file_name(clip: KillClip) -> String:
	var who := func(id: int) -> String:
		var t: KillClip.Track = clip.tracks.get(id)
		return (t.name if t else Net.player_name(id)).validate_filename().replace(" ", "_")
	var when := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	return "killcam_%s_on_%s_%s.avi" % [who.call(clip.killer), who.call(clip.victim), when]


func start(clip: KillClip, title: String = "KILLCAM") -> void:
	name = "KillcamExport"
	_map_name = Maps.name_of(clip.map if clip.map != "" else Net.map_id())
	_view = SubViewport.new()
	_view.size = SIZE
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.audio_listener_enable_3d = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var map := Maps.make(clip.map if clip.map != "" else Net.map_id())
	map.name = "Level"
	map.destructible = MapReplay.wants_destruction([clip])   # (to show the walls as they were)
	_view.add_child(map)
	map.build()
	_player = KillcamView.new().setup(clip, true)
	_player.map = map
	_player.manual = true
	_player.world_sound = false
	_view.add_child(_player)
	_overlay = Control.new()
	_overlay.size = Vector2(SIZE)
	_overlay.draw.connect(func():
		KillcamOverlay.draw(_overlay, Rect2(Vector2.ZERO, Vector2(SIZE)), _player, title, "JUMPY SHOOTY  ·  %s" % _map_name.to_upper()))
	_view.add_child(_overlay)
	_record.call_deferred(clip)


func _record(clip: KillClip) -> void:
	var avi := AviWriter.new(SIZE.x, SIZE.y, FPS)
	var held := 0
	var step := 1.0 / FPS
	var blank: Image = null
	var headless := DisplayServer.get_name() == "headless"
	while held < int(HOLD * FPS):
		_overlay.queue_redraw()
		if headless:
			await get_tree().process_frame   # nothing is drawn: no "drawn" signal comes
		else:
			await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return   # the page closed while saving
		var img: Image = null if headless else _view.get_texture().get_image()
		if img == null or img.is_empty():   # no screen to draw on (a headless test run)
			if blank == null:
				blank = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
			img = blank
		avi.add_frame(img)
		if _player.done:
			held += 1
		_player.step(step)
		progress.emit(clampf((_player.time - clip.start) / maxf(clip.end - clip.start, 0.01), 0.0, 1.0))
	var dir := into if into != "" else folder()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name(clip))
	var err := avi.save(path)
	if DevArgs.sync_log:
		print("KILLCAM_SAVED %d %d %d %.1f %s %s" % [Net.my_id(), int(clip.info.get("seq", 0)), avi.frame_count(), avi.length(),
			"ok" if err == OK else error_string(err), path])
	finished.emit(path, "" if err == OK else error_string(err))
	queue_free()
