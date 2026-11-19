class_name KillcamExport
extends Node
## Saves a killcam as a video to share: plays the clip offscreen, in a world of its own
## with a copy of the map, one frame at a time (FPS a second of video, however fast the
## computer draws), with the killcam's words over it, and writes a 1080p 60 fps MP4
## (H.264). The file goes in the Videos folder, under "Jumpy Shooty" (see folder()).
##
## The MP4 is written by Windows' own video encoder, through a small helper the game
## carries (game/encoder/Mp4Encoder.exe, built from tools/mp4_encoder): each frame is
## piped to it as it is drawn. Where that can't run (not Windows, or it fails to start),
## the video is an AVI instead (AviWriter: Motion JPEG), at the same size and rate.
##
##   var save := KillcamExport.new()
##   add_child(save)
##   save.finished.connect(func(path, error): ...)
##   save.start(clip)

signal progress(fraction: float)
signal finished(path: String, error: String)   ## error is "" when it worked

const SIZE := Vector2i(1920, 1080)
const FPS := 60
const BITRATE := 16_000_000   ## bits a second: sharp 1080p60 for fast motion
const ENCODER := "res://game/encoder/Mp4Encoder.exe"
const ENCODER_COPY := "user://encoder/Mp4Encoder.exe"   ## (an .exe can't run from inside the game's pack)
const ENCODE_TIMEOUT := 120.0   ## seconds to wait for the encoder to finish the file
const OVERLAY_SCALE := 1.5   ## the killcam's words: the size they have on a 720p video
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


## A file name for this kill: killcam_Host_on_P2_2026-11-17_16-05-09.mp4
static func file_name(clip: KillClip, ext: String = "mp4") -> String:
	var who := func(id: int) -> String:
		var t: KillClip.Track = clip.tracks.get(id)
		return (t.name if t else Net.player_name(id)).validate_filename().replace(" ", "_")
	var when := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	return "killcam_%s_on_%s_%s.%s" % [who.call(clip.killer), who.call(clip.victim), when, ext]


## The MP4 encoder, ready to run: copied out of the game's pack the first time (and
## again when it changes). "" where there is none (not Windows).
static func encoder_path() -> String:
	if OS.get_name() != "Windows" or not FileAccess.file_exists(ENCODER):
		return ""
	var bytes := FileAccess.get_file_as_bytes(ENCODER)
	if bytes.is_empty():
		return ""
	var copy := ProjectSettings.globalize_path(ENCODER_COPY)
	if not FileAccess.file_exists(copy) or FileAccess.get_file_as_bytes(copy) != bytes:
		DirAccess.make_dir_recursive_absolute(copy.get_base_dir())
		var f := FileAccess.open(copy, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_buffer(bytes)
		f.close()
	return copy


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
	# The words are laid out for a 720p picture and scaled up to fill this one.
	var words := Vector2(SIZE) / OVERLAY_SCALE
	_overlay = Control.new()
	_overlay.size = words
	_overlay.scale = Vector2(OVERLAY_SCALE, OVERLAY_SCALE)
	_overlay.draw.connect(func():
		KillcamOverlay.draw(_overlay, Rect2(Vector2.ZERO, words), _player, title, "JUMPY SHOOTY  ·  %s" % _map_name.to_upper()))
	_view.add_child(_overlay)
	_record.call_deferred(clip)


func _record(clip: KillClip) -> void:
	var dir := into if into != "" else folder()
	DirAccess.make_dir_recursive_absolute(dir)
	# The MP4 encoder, taking frames as they are drawn; or, failing that, an AVI.
	var mp4_path := dir.path_join(file_name(clip, "mp4"))
	var pipe := {}
	var exe := encoder_path()
	if exe != "":
		pipe = OS.execute_with_pipe(exe, [mp4_path, str(SIZE.x), str(SIZE.y), str(FPS), str(BITRATE)], true)   # (blocking: a frame waits for the encoder rather than being dropped)
	var avi: AviWriter = null if not pipe.is_empty() else AviWriter.new(SIZE.x, SIZE.y, FPS)
	var frames := 0
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
				blank = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
			img = blank
		if avi:
			avi.add_frame(img)
		else:
			if img.get_size() != SIZE:
				img = img.duplicate()
				img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			(pipe.stdio as FileAccess).store_buffer(img.get_data())
		frames += 1
		if _player.done:
			held += 1
		_player.step(step)
		progress.emit(clampf((_player.time - clip.start) / maxf(clip.end - clip.start, 0.01), 0.0, 1.0))
	var path := mp4_path
	var error := ""
	if avi:
		path = dir.path_join(file_name(clip, "avi"))
		var err := avi.save(path)
		error = "" if err == OK else error_string(err)
	else:
		error = await _finish_mp4(pipe)
	if DevArgs.sync_log:
		print("KILLCAM_SAVED %d %d %d %.1f %s %s" % [Net.my_id(), int(clip.info.get("seq", 0)), frames, frames / float(FPS),
			"ok" if error == "" else error.replace(" ", "_"), path])
	finished.emit(path, error)
	queue_free()


## Close the encoder's input (the end of the video) and wait for it to write the file.
## "" when it did; what went wrong if not.
func _finish_mp4(pipe: Dictionary) -> String:
	var pid := int(pipe.pid)
	(pipe.stdio as FileAccess).close()
	var waited := 0.0
	while OS.is_process_running(pid) and waited < ENCODE_TIMEOUT:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	if OS.is_process_running(pid):
		OS.kill(pid)
		return "the video encoder took too long"
	var code := OS.get_process_exit_code(pid)
	if code != 0:
		var why := (pipe.stderr as FileAccess).get_as_text().strip_edges() if pipe.has("stderr") and pipe.stderr else ""
		return "the video encoder failed (%d)%s" % [code, (": " + why) if why != "" else ""]
	return ""
