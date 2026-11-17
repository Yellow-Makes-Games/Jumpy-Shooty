class_name KillcamScreen
extends Control
## The match's best kills (Match.highlights), fullscreen: played one after another
## from the killers' eyes, the kill itself in slow motion, in a world of its own with
## a copy of the map. After a match it counts them down (#3, #2, then the best) before
## the results page shows; the page's "Best kills" list plays one again the same way.
## Jump, Fire, Enter or a click goes on to the next; Esc skips the rest.
##
## Every copy plays its own recording of the same kills (see Killcam). A copy that
## joined after one of them happened has nothing to show for it and says so.

signal clip_changed(index: int)   ## index into `highlights` (0 is the best)
signal done                       ## the last one finished, or the rest were skipped

const PAUSE := 1.2   ## seconds the last frame of a clip stays before the next one

var highlights: Array = []
var index := -1           ## the kill playing, as an index into `highlights`
var order: Array = []     ## the indexes still to play after this one

var _box: SubViewportContainer
var _view: SubViewport
var _map: MapRoot
var _player: KillcamView
var _overlay: Control
var _wait := -1.0         # counting down to the next clip
var _missing := false
var _finished := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under it can be clicked while it plays
	var back := ColorRect.new()
	back.color = Color(0.01, 0.015, 0.03)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.audio_listener_enable_3d = false   # its sounds play as your own (see KillcamView.world_sound)
	_box.add_child(_view)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## Play `list` (kill infos, best first): the indexes in `which`, in that order.
## By default every one, counting down to the best.
func play(list: Array, which: Array = []) -> void:
	highlights = list
	order = which.duplicate() if not which.is_empty() else range(list.size() - 1, -1, -1)
	if highlights.is_empty() or order.is_empty():
		_finish()
		return
	if _map == null:
		_map = Maps.make(Net.map_id())
		_map.name = "Level"
		_view.add_child(_map)
		_map.build()
	show_clip(order.pop_front())


func show_clip(i: int) -> void:
	index = clampi(i, 0, highlights.size() - 1)
	_wait = -1.0
	if _player:
		_player.queue_free()
		_player = null
	var clip := Killcam.clip_for(highlights[index])
	_missing = clip == null
	if DevArgs.sync_log:
		print("KILLCAM_RESULTS %d %d %s" % [Net.my_id(), int(highlights[index].seq), "missing" if _missing else "play"])
	if _missing:
		_wait = PAUSE * 2.0
	else:
		_player = KillcamView.new().setup(clip, true)
		_player.world_sound = false
		_view.add_child(_player)
		_player.finished.connect(func(): _wait = PAUSE)
	clip_changed.emit(index)


## On to the next kill (or done, after the last).
func next() -> void:
	if order.is_empty():
		_finish()
	else:
		show_clip(order.pop_front())


## Skip the rest.
func skip_all() -> void:
	order.clear()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _player:
		_player.queue_free()
		_player = null
	if DevArgs.sync_log:
		print("KILLCAM_RESULTS_DONE %d" % Net.my_id())
	done.emit()


func _process(delta: float) -> void:
	_overlay.queue_redraw()
	if _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			next()


func _input(event: InputEvent) -> void:
	if _finished or not is_visible_in_tree() or event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		skip_all()
	elif event.is_action_pressed("jump") or event.is_action_pressed("fire") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		next()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw_overlay() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hint := "%s / CLICK  NEXT   ·   ESC  SKIP" % Settings.action_text("jump").to_upper()
	var count := "BEST KILL #%d" % (index + 1)
	if _player and is_instance_valid(_player):
		KillcamOverlay.draw(_overlay, r, _player, count, hint, size.y < 600.0)
	elif _missing and index >= 0:
		var h: Dictionary = highlights[index]
		var c := r.get_center()
		HudStyle.label(_overlay, c - Vector2(0, 34), count, 14, HudStyle.RED, HORIZONTAL_ALIGNMENT_CENTER)
		HudStyle.text(_overlay, c, "%s  >  %s" % [Net.player_name(int(h.killer)), Net.player_name(int(h.victim))], 30,
			HudStyle.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		HudStyle.text(_overlay, c + Vector2(0, 36), "Before you joined: no replay on this copy", 16, Color(1, 1, 1, 0.6),
			HORIZONTAL_ALIGNMENT_CENTER, false)
		HudStyle.label(_overlay, Vector2(r.end.x - 40, r.end.y - 40), hint, 12, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
