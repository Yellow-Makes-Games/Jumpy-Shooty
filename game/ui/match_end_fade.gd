class_name MatchEndFade
extends CanvasLayer
## The moment a match ends (the winning kill, the clock, the finish line): the game
## slows right down, "MATCH OVER" comes up with who won, and the screen fades to black;
## then `done` (Game goes on to the results, which play the best kills).
##
## Timed in real seconds (the slow motion is taken back out of each frame's delta), so it
## lasts the same however slow the game is running.
##
##   var fade := MatchEndFade.new()
##   get_tree().root.add_child(fade)
##   fade.done.connect(...)
##   fade.play(results)

signal done

const SLOW := 0.2           ## the game runs at this speed...
const SLOW_IN := 0.35       ## ...eased into over this many seconds
const TEXT_AT := 0.25       ## "MATCH OVER" comes up from here...
const FADE_AT := 1.0        ## ...the screen starts going black here...
const FADE_TIME := 1.3      ## ...and is black after this long
const HOLD := 0.35          ## black, with the words, before going on

## One is playing (the debug menu's own slow motion keeps out of its way).
static var running := false

var _t := 0.0
var _title := "MATCH OVER"
var _sub := ""
var _black: ColorRect
var _words: Control
var _finished := false


func play(results: Array) -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	running = true
	var race: bool = not results.is_empty() and results[0].get("race", false)
	if race:
		_title = "RACE OVER"
	if not results.is_empty():
		var first: Dictionary = results[0]
		var won: bool = first.id == Net.my_id()
		if race:
			_sub = ("YOU WIN THE RACE" if won else "%s WINS" % str(first.name).to_upper()) if first.get("finished", false) else "NOBODY FINISHED"
		else:
			_sub = "VICTORY" if won else "%s WINS" % str(first.name).to_upper()
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_words = Control.new()
	_words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.draw.connect(_draw_words)
	add_child(_words)
	if DevArgs.sync_log:
		print("MATCH_END_FADE %d %s" % [Net.my_id(), _sub])


func _process(delta: float) -> void:
	if _finished or _black == null:
		return
	_t += delta / maxf(Engine.time_scale, 0.001)   # real seconds, whatever the slow motion
	Engine.time_scale = lerpf(1.0, SLOW, smoothstep(0.0, SLOW_IN, _t))
	_black.color.a = smoothstep(FADE_AT, FADE_AT + FADE_TIME, _t)
	var arena := Net.arena
	if arena and is_instance_valid(arena) and arena.hud:
		arena.hud.set_fade(1.0 - smoothstep(0.0, TEXT_AT + 0.3, _t))   # the HUD gives way to the words
	_words.queue_redraw()
	if _t >= FADE_AT + FADE_TIME + HOLD:
		_finished = true
		Engine.time_scale = 1.0
		running = false
		done.emit()


func _exit_tree() -> void:
	Engine.time_scale = 1.0   # never leave the game slowed down
	running = false


func _draw_words() -> void:
	var a := smoothstep(TEXT_AT, TEXT_AT + 0.35, _t)
	if a <= 0.0:
		return
	var size := _words.size
	var c := size * 0.5
	var pop := 1.0 + 0.12 * (1.0 - a)
	# A band behind the words, so they read over a bright sky before the screen goes dark.
	var band := 120.0 * a
	_words.draw_rect(Rect2(0, c.y - band * 0.5 - 10.0, size.x, band), Color(0, 0, 0, 0.45 * a * (1.0 - _black.color.a)))
	HudStyle.text(_words, Vector2(c.x, c.y - 12.0), _title, int(64 * pop), Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
	if _sub != "":
		HudStyle.label(_words, Vector2(c.x, c.y + 40.0), _sub, 16, Color(HudStyle.ORANGE, a), HORIZONTAL_ALIGNMENT_CENTER)
