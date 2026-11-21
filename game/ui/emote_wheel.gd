class_name EmoteWheel
extends Control
## The emote wheel (part of the Hud): hold the emote key and the six emotes on your
## wheel (Settings.emote_wheel) come up round the crosshair; the mouse picks one
## instead of turning your view (you can keep moving), and letting go plays it
## (Player.try_emote: only standing still on the ground; otherwise nothing happens and
## nothing is kept for later). A quick tap plays the last one again.
##
##   wheel.player = your Player     # every frame (Hud does)
##   wheel.open(); wheel.nudge(Vector2(0, -80)); wheel.release()   # what the key and the mouse do

const RADIUS := 150.0        ## canvas pixels from the crosshair to a slot's name
const REACH := 110.0         ## the pointer goes this far from the middle at most...
const DEAD := 34.0           ## ...and nearer than this it picks nothing
const TAP := 0.22            ## seconds: let go sooner than this, having picked nothing, and the last one plays again
const HINT_TIME := 1.6       ## seconds the "stand still" line stays up

var player: Player           ## whose wheel it is (you), or null
var last := ""               ## the emote played last (a tap plays it again)

var _open := false
var _pointer := Vector2.ZERO
var _held := 0.0
var _hint := 0.0             # seconds the hint still shows


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Which slot a pointer this far from the middle picks: 0 at the top and on round
## clockwise, or -1 in the middle (nothing picked).
static func slot_for(pointer: Vector2, slots: int = Emote.SLOTS) -> int:
	if pointer.length() < DEAD or slots <= 0:
		return -1
	return posmod(roundi(atan2(pointer.x, -pointer.y) / (TAU / slots)), slots)


## Which way a slot is from the middle (a unit vector on the screen).
static func way_of(slot: int, slots: int = Emote.SLOTS) -> Vector2:
	var angle := TAU * slot / maxi(slots, 1)
	return Vector2(sin(angle), -cos(angle))


func is_open() -> bool:
	return _open


## The slot the pointer is on now, or -1.
func picked() -> int:
	return slot_for(_pointer) if _open else -1


## The key goes down: the wheel comes up (if you are alive to use it).
func open() -> void:
	if _open or player == null or not is_instance_valid(player) or not player.alive:
		return
	_open = true
	_pointer = Vector2.ZERO
	_held = 0.0
	queue_redraw()


## The mouse moves while it is up: the pointer goes with it.
func nudge(by: Vector2) -> void:
	if not _open:
		return
	_pointer = (_pointer + by).limit_length(REACH)
	queue_redraw()


## The key comes up: the picked emote plays, or (a quick tap) the last one again.
## Returns the emote it started, or "".
func release() -> String:
	if not _open:
		return ""
	_open = false
	queue_redraw()
	var slot := slot_for(_pointer)
	var wheel := Emote.wheel(Settings.emote_wheel)
	var want := ""
	if slot >= 0:
		want = wheel[slot]
	elif _held <= TAP:
		want = last if Emote.valid(last) else str(wheel[0])
	if want == "" or player == null or not is_instance_valid(player):
		return ""
	if not player.try_emote(want):
		_hint = HINT_TIME if player.alive else 0.0
		return ""
	last = want
	return want


func _process(delta: float) -> void:
	# The key (read here, not as an event: a test's held keys are not events).
	if not DevArgs.scripted_input and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DevArgs.drives_keys):
		if Input.is_action_just_pressed("emote"):
			open()
		elif Input.is_action_just_released("emote"):
			release()
	if _open:
		_held += delta
		if player == null or not is_instance_valid(player) or not player.alive:
			_open = false   # (knocked out with it up)
		queue_redraw()
	if _hint > 0.0:
		_hint = maxf(_hint - delta, 0.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if _open and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		nudge((event as InputEventMouseMotion).relative * 0.6)
		get_viewport().set_input_as_handled()   # (the view stays where it is while you pick)


func _draw() -> void:
	var middle := size * 0.5
	var font := HudStyle.font(true)
	if _hint > 0.0 and not _open:
		var words := "STAND STILL TO EMOTE"
		var wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, middle + Vector2(-wide * 0.5, 96.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UiKit.TEXT, clampf(_hint / 0.4, 0.0, 1.0) * 0.9))
	if not _open:
		return
	var wheel := Emote.wheel(Settings.emote_wheel)
	var on := slot_for(_pointer)
	draw_circle(middle, RADIUS + 78.0, Color(0.02, 0.03, 0.05, 0.42))
	draw_arc(middle, RADIUS + 78.0, 0.0, TAU, 72, Color(UiKit.CYAN, 0.35), 1.5, true)
	draw_arc(middle, DEAD + 8.0, 0.0, TAU, 40, Color(UiKit.TEXT, 0.25), 1.5, true)
	for i in wheel.size():
		var way := way_of(i, wheel.size())
		var lit := i == on
		if lit:   # the slice it is on
			var from := TAU * (i - 0.5) / wheel.size() - PI * 0.5
			draw_arc(middle, RADIUS, from, from + TAU / wheel.size(), 24, Color(UiKit.ACCENT, 0.28), 132.0, true)
		var words := Emote.name_of(wheel[i]).to_upper()
		var size_ := 19 if lit else 16
		var wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_).x
		var at := middle + way * RADIUS + Vector2(-wide * 0.5, size_ * 0.35)
		draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, 5, Color(0, 0, 0, 0.75))
		draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, UiKit.ACCENT if lit else UiKit.TEXT)
	draw_line(middle, middle + _pointer, Color(UiKit.TEXT, 0.35), 2.0, true)
	draw_circle(middle + _pointer, 5.0, UiKit.ACCENT if on >= 0 else UiKit.TEXT)
