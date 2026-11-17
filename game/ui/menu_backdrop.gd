class_name MenuBackdrop
extends Control
## The background behind every menu: a deep blue gradient, a glowing horizon with a
## floor grid drifting toward you, a honeycomb fading in from the top right, slow
## motes of light, orange slashes down the right-hand side and a targeting frame in
## the corners of the screen. Drawn in code.

const TOP := Color(0.035, 0.06, 0.12)
const MID := Color(0.06, 0.085, 0.15)
const BOTTOM := Color(0.015, 0.02, 0.035)
const HORIZON := 0.58          ## where the floor grid starts, as a share of the height
const MOTES := 26

var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var hy := h * HORIZON
	# Sky: dark at the top, lighter toward the horizon. Floor: darker toward you.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([TOP, TOP, MID, MID]))
	draw_polygon(PackedVector2Array([Vector2(0, hy), Vector2(w, hy), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(0.04, 0.055, 0.1), Color(0.04, 0.055, 0.1), BOTTOM, BOTTOM]))
	_draw_honeycomb(w, hy)
	# Glow along the horizon: orange low down, a cooler haze above it.
	var warm := Color(UiKit.ACCENT, 0.16)
	draw_polygon(PackedVector2Array([Vector2(0, hy - 70), Vector2(w, hy - 70), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([Color(warm, 0), Color(warm, 0), warm, warm]))
	var cool := Color(UiKit.CYAN, 0.06)
	draw_polygon(PackedVector2Array([Vector2(0, hy - 220), Vector2(w, hy - 220), Vector2(w, hy - 40), Vector2(0, hy - 40)]),
		PackedColorArray([Color(cool, 0), Color(cool, 0), cool, cool]))
	draw_line(Vector2(0, hy), Vector2(w, hy), Color(UiKit.ACCENT, 0.5), 1.5)
	draw_polygon(PackedVector2Array([Vector2(0, hy), Vector2(w, hy), Vector2(w, hy + 46), Vector2(0, hy + 46)]),
		PackedColorArray([Color(warm, 0.1), Color(warm, 0.1), Color(warm, 0), Color(warm, 0)]))
	# Floor grid in perspective: lines fanning out from the centre of the horizon,
	# and cross lines that drift toward you. Every fourth line is brighter.
	var vp := Vector2(w * 0.5, hy)
	var line := Color(0.45, 0.75, 1.0, 0.09)
	var reach := int(ceil(w / (h * 0.16))) + 6       # enough lines to cover a wide screen
	for i in range(-reach, reach + 1):
		var strong := i % 4 == 0
		draw_line(vp, Vector2(w * 0.5 + i * h * 0.16, h), Color(line, line.a * (1.9 if strong else 1.0)), 1.0)
	var drift := fmod(_t * 0.14, 1.0)
	for i in 16:
		var z := (i + drift) / 16.0          # 0 at the horizon, 1 at the bottom
		var y := hy + (h - hy) * z * z
		draw_line(Vector2(0, y), Vector2(w, y), Color(line, line.a * (0.3 + 1.4 * z)), 1.0)
	# A band of light sweeping up the floor now and then.
	var sweep := fmod(_t * 0.09, 1.6)
	if sweep < 1.0:
		var sy := h - (h - hy) * sweep
		var band := Color(UiKit.CYAN, 0.07 * (1.0 - sweep))
		draw_polygon(PackedVector2Array([Vector2(0, sy - 26), Vector2(w, sy - 26), Vector2(w, sy), Vector2(0, sy)]),
			PackedColorArray([Color(band, 0), Color(band, 0), band, band]))
	# Motes of light rising slowly.
	for i in MOTES:
		var seed := float(i) * 12.9898
		var fx := fposmod(sin(seed) * 43758.5453, 1.0)
		var speed := 0.012 + 0.02 * fposmod(sin(seed * 1.7) * 9631.11, 1.0)
		var fy := fposmod(fposmod(sin(seed * 2.3) * 2371.7, 1.0) - _t * speed, 1.0)
		var twinkle := 0.5 + 0.5 * sin(_t * (0.6 + fx) + seed)
		var col := UiKit.CYAN if i % 3 else UiKit.ACCENT
		var p := Vector2(fx * w, fy * h)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(col, 0.10 + 0.22 * twinkle))
	# Orange slashes on the right.
	for i in 3:
		var x := w * 0.86 + i * 38.0
		var slash := PackedVector2Array([Vector2(x, 0), Vector2(x + 16, 0), Vector2(x - h * 0.25 + 16, h), Vector2(x - h * 0.25, h)])
		draw_colored_polygon(slash, Color(UiKit.ACCENT, 0.075 - i * 0.02))
	# Darker toward the left and right edges, so the page in the middle stands out.
	var shade := Color(0, 0, 0, 0.42)
	var edge := minf(w * 0.22, 420.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]),
		PackedColorArray([shade, Color(shade, 0), Color(shade, 0), shade]))
	draw_polygon(PackedVector2Array([Vector2(w - edge, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - edge, h)]),
		PackedColorArray([Color(shade, 0), shade, shade, Color(shade, 0)]))
	_draw_frame(w, h)


## Hexagons fading in from the top right corner.
func _draw_honeycomb(w: float, hy: float) -> void:
	var r := 34.0
	var dx := r * 1.5
	var dy := r * sqrt(3.0)
	var origin := Vector2(w + 10.0, -10.0)
	var far := minf(w * 0.5, 760.0)
	for col in range(0, int(far / dx) + 2):
		for row in range(0, int(hy / dy) + 1):
			var c := origin + Vector2(-col * dx, row * dy + (dy * 0.5 if col % 2 else 0.0))
			var fade := 1.0 - clampf(c.distance_to(origin) / far, 0.0, 1.0)
			if fade <= 0.02 or c.y > hy - r:
				continue
			var lit := 0.5 + 0.5 * sin(_t * 0.7 + col * 1.3 + row * 2.1)
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(c + Vector2.from_angle(k * PI / 3.0) * (r - 3.0))
			draw_polyline(pts, Color(0.5, 0.8, 1.0, 0.085 * fade * (0.6 + 0.4 * lit)), 1.0, true)
			if lit > 0.97:
				draw_colored_polygon(pts.slice(0, 6), Color(UiKit.CYAN, 0.035 * fade))


## A targeting frame in the corners of the screen, with ruler ticks along the top.
func _draw_frame(w: float, h: float) -> void:
	var m := 18.0
	HudStyle.brackets(self, Rect2(m, m, w - m * 2.0, h - m * 2.0), 26.0, Color(1, 1, 1, 0.22), 2.0)
	var cx := w * 0.5
	for i in range(-12, 13):
		var tall := i % 4 == 0
		draw_line(Vector2(cx + i * 14.0, m), Vector2(cx + i * 14.0, m + (9.0 if tall else 5.0)), Color(1, 1, 1, 0.16 if tall else 0.09), 1.0)
