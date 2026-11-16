class_name MenuBackdrop
extends Control
## The background behind every menu: a dark blue gradient, a floor grid drifting
## slowly toward you, and orange slashes down the right-hand side. Drawn in code.

const TOP := Color(0.09, 0.12, 0.19)
const BOTTOM := Color(0.03, 0.035, 0.05)
const HORIZON := 0.56          ## where the floor grid starts, as a share of the height

var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	# Glow along the horizon.
	var hy := h * HORIZON
	var glow := Color(UiKit.ACCENT, 0.10)
	draw_polygon(PackedVector2Array([Vector2(0, hy - 90), Vector2(w, hy - 90), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([Color(glow, 0), Color(glow, 0), glow, glow]))
	draw_line(Vector2(0, hy), Vector2(w, hy), Color(UiKit.ACCENT, 0.25), 1.0)
	# Floor grid in perspective: lines fanning out from the centre of the horizon,
	# and cross lines that drift toward you.
	var vp := Vector2(w * 0.5, hy)
	var line := Color(0.5, 0.7, 1.0, 0.07)
	for i in range(-24, 25):
		draw_line(vp, Vector2(w * 0.5 + i * w * 0.09, h), line, 1.0)
	var drift := fmod(_t * 0.12, 1.0)
	for i in 14:
		var z := (i + drift) / 14.0          # 0 at the horizon, 1 at the bottom
		var y := hy + (h - hy) * z * z
		draw_line(Vector2(0, y), Vector2(w, y), Color(line, line.a * (0.4 + z)), 1.0)
	# Orange slashes on the right.
	for i in 3:
		var x := w * 0.84 + i * 34.0
		var slash := PackedVector2Array([Vector2(x, 0), Vector2(x + 14, 0), Vector2(x - h * 0.25 + 14, h), Vector2(x - h * 0.25, h)])
		draw_colored_polygon(slash, Color(UiKit.ACCENT, 0.07 - i * 0.02))
