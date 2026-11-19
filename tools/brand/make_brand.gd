extends Node
## Draws the game's icon and boot splash in the menu's own look (Chakra Petch, white
## JUMPY over orange SHOOTY on the dark navy) and saves them to game/brand/:
##   icon.png     256 x 256: the window and taskbar icon (application/config/icon)
##   icon.ico     16 to 256 px: the .exe's icon (application/config/windows_native_icon)
##   splash.png   1920 x 1080: the boot splash (application/boot_splash/image)
##
## It renders, so it needs a window (not --headless), and runs as a scene (fonts drawn
## from a --script run come out as solid boxes):
##   godot --path . res://tools/brand/make_brand.tscn

const OUT := "res://game/brand/"
const ICO_SIZES := [16, 24, 32, 48, 64, 128, 256]
const BG := Color(0.03, 0.04, 0.065)
const NAVY := Color(0.06, 0.085, 0.13)
const ORANGE := Color(1.0, 0.55, 0.2)
const CYAN := Color(0.4, 0.9, 1.0)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var icon := await _icon(256, false)
	icon.save_png(OUT + "icon.png")
	var pngs := []
	for s in ICO_SIZES:
		pngs.append((await _icon(s, s <= 32)).save_png_to_buffer())
	_save_ico(OUT + "icon.ico", pngs)
	var splash := await _render(Vector2(1920, 1080), _draw_splash)
	splash.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	splash.save_png(OUT + "splash.png")
	print("brand: icon.png, icon.ico (%s), splash.png written to %s" % [ICO_SIZES, OUT])
	get_tree().quit()


## The icon at `px` pixels, with see-through cut corners: drawn once as it looks and
## once as a white-on-black mask of its plate, which becomes its alpha.
func _icon(px: int, small: bool) -> Image:
	var look := await _render(Vector2(512, 512), _draw_icon.bind(small))
	var mask := await _render(Vector2(512, 512), _draw_icon_mask)
	look.resize(px, px, Image.INTERPOLATE_LANCZOS)
	mask.resize(px, px, Image.INTERPOLATE_LANCZOS)
	for y in px:
		for x in px:
			var c := look.get_pixel(x, y)
			c.a = mask.get_pixel(x, y).r
			look.set_pixel(x, y, c)
	return look


## Draw with `paint` (it gets the canvas Control) as a picture `size` big, and return
## it. Drawn on the window itself, scaled to fit it: text drawn in a SubViewport comes
## out as solid boxes.
func _render(size: Vector2, paint: Callable) -> Image:
	var view := get_viewport().get_visible_rect().size
	var k := minf(view.x / size.x, view.y / size.y)
	_size = size
	_base = k
	var canvas := Control.new()
	canvas.size = view
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(Vector2.ZERO, view), Color.BLACK)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		paint.call(canvas))
	add_child(canvas)
	for i in 8:   # (the glyphs reach the GPU over the first frames)
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	canvas.queue_free()
	await RenderingServer.frame_post_draw
	var px := float(shot.get_width()) / view.x   # texture pixels per canvas unit
	var img := shot.get_region(Rect2i(0, 0, roundi(size.x * k * px), roundi(size.y * k * px)))
	img.convert(Image.FORMAT_RGBA8)
	return img


var _size := Vector2.ONE   ## the picture being drawn (its own units)
var _base := 1.0           ## its scale onto the window

const GLYPH_MAX := 96   ## bigger text is drawn at this size and scaled (big glyphs come out as boxes)


func _text(c: Control, font: Font, at: Vector2, text: String, _align, _w, size: int, color: Color) -> void:
	var k := maxf(1.0, size / float(GLYPH_MAX))
	c.draw_set_transform(at * _base, 0.0, Vector2(k, k) * _base)
	c.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size / k), color)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(_base, _base))


func _outline(c: Control, font: Font, at: Vector2, text: String, _align, _w, size: int, outline: int, color: Color) -> void:
	var k := maxf(1.0, size / float(GLYPH_MAX))
	c.draw_set_transform(at * _base, 0.0, Vector2(k, k) * _base)
	c.draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size / k), maxi(1, int(outline / k)), color)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(_base, _base))


## Chakra Petch as a signed-distance-field font: sharp at any size. (Drawn the usual way,
## glyphs over about 100 px on screen come out as solid boxes.)
func _font(weight := "Bold") -> Font:
	if not _fonts.has(weight):
		var f := FontFile.new()
		f.data = FileAccess.get_file_as_bytes("res://game/ui/fonts/ChakraPetch-%s.ttf" % weight)
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16
		f.msdf_size = 64
		_fonts[weight] = f
	return _fonts[weight]


var _fonts := {}


## A cut-corner plate, like the menu's panels: top-left and bottom-right corners cut.
func _plate(c: Control, r: Rect2, cut: float, fill: Color) -> PackedVector2Array:
	var p := PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(0, cut),
		r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])
	c.draw_colored_polygon(p, fill)
	return p


## The icon: a navy cut-corner plate with a big white J and orange S, the orange slash
## across a cut corner and a cyan edge, as the menu's frames have. `small`: bolder
## strokes for 16 to 32 px.
func _draw_icon(c: Control, small := false) -> void:
	var s := _size.x
	var r := Rect2(Vector2(s, s) * 0.03, Vector2(s, s) * 0.94)
	var cut := s * 0.2
	var p := _plate(c, r, cut, NAVY)
	var edge := p.duplicate()
	edge.append(p[0])
	c.draw_polyline(edge, Color(CYAN, 0.55), s * (0.022 if small else 0.012), true)
	# The orange slashes across the two cut corners.
	var w := s * (0.05 if small else 0.035)
	c.draw_line(r.position + Vector2(cut * 0.25, cut * 1.05), r.position + Vector2(cut * 1.05, cut * 0.25), ORANGE, w, true)
	c.draw_line(r.end - Vector2(cut * 0.25, cut * 1.05), r.end - Vector2(cut * 1.05, cut * 0.25), ORANGE, w, true)
	# J and S, overlapping a little, each with a halo of its own colour.
	var font := _font()
	var size := int(s * 0.66)
	var base := s * 0.735
	var j_at := Vector2(s * 0.13, base)
	var s_at := Vector2(s * 0.45, base)
	for k in 3:
		var o := s * 0.012 * (k + 1)
		_outline(c, font, j_at, "J", HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(o * 2.0), Color(1, 1, 1, 0.05))
		_outline(c, font, s_at, "S", HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(o * 2.0), Color(ORANGE, 0.06))
	_outline(c, font, s_at, "S", HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(s * 0.03), BG)
	_text(c, font, s_at, "S", HORIZONTAL_ALIGNMENT_LEFT, -1, size, ORANGE)
	_outline(c, font, j_at, "J", HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(s * 0.03), BG)
	_text(c, font, j_at, "J", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


## The icon's outline, white on black: its alpha.
func _draw_icon_mask(c: Control) -> void:
	var s := _size.x
	_plate(c, Rect2(Vector2(s, s) * 0.03, Vector2(s, s) * 0.94), s * 0.2, Color.WHITE)


## The splash: the menu's logo in the middle of the dark navy, a faint floor grid
## going off to the horizon, a cyan rule and the tagline. (Shown "cover": the edges
## may be cropped on a narrow window, so everything that matters is near the middle.)
func _draw_splash(c: Control) -> void:
	var s := _size
	c.draw_rect(Rect2(Vector2.ZERO, s), BG)
	# A glow behind the logo.
	var mid := s * 0.5
	for k in 12:
		var rad := s.y * (0.62 - k * 0.04)
		c.draw_circle(mid, rad, Color(0.1, 0.16, 0.26, 0.05))
	# The horizon and a floor grid in perspective, as on the main menu.
	var horizon := s.y * 0.72
	c.draw_line(Vector2(0, horizon), Vector2(s.x, horizon), Color(ORANGE, 0.55), 2.0, true)
	for i in range(-14, 15):
		var x := mid.x + i * 150.0
		c.draw_line(Vector2(mid.x + i * 12.0, horizon), Vector2(x * 1.0 + i * 260.0, s.y), Color(CYAN, 0.10), 1.5, true)
	var y := horizon
	var gap := 6.0
	while y < s.y:
		c.draw_line(Vector2(0, y), Vector2(s.x, y), Color(CYAN, 0.08), 1.0)
		gap *= 1.35
		y += gap
	# JUMPY / SHOOTY.
	var font := _font()
	var size := 190
	var jumpy := "JUMPY"
	var shooty := "SHOOTY"
	var jw := font.get_string_size(jumpy, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var sw := font.get_string_size(shooty, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var top := s.y * 0.40
	var j_at := Vector2(mid.x - jw * 0.5, top)
	var s_at := Vector2(mid.x - sw * 0.5, top + size * 0.86)
	for k in 4:
		_outline(c, font, j_at, jumpy, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14 + k * 14, Color(1, 1, 1, 0.035))
		_outline(c, font, s_at, shooty, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14 + k * 14, Color(ORANGE, 0.045))
	_text(c, font, j_at, jumpy, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
	_text(c, font, s_at, shooty, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ORANGE)
	# A cyan rule and the tagline.
	var rule_y := s_at.y + 52.0
	c.draw_line(Vector2(mid.x - sw * 0.5, rule_y), Vector2(mid.x + sw * 0.5, rule_y), Color(CYAN, 0.6), 3.0, true)
	var tag := "H I G H - M O B I L I T Y   A R E N A   S H O O T E R"
	var semi := _font("SemiBold")
	var tw := semi.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text(c, semi, Vector2(mid.x - tw * 0.5, rule_y + 52.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(CYAN, 0.9))


## A Windows .ico holding PNG images (fine from Vista on): a 6-byte header, a
## 16-byte entry per image, then the PNGs.
func _save_ico(path: String, pngs: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_16(0)
	f.store_16(1)
	f.store_16(pngs.size())
	var offset := 6 + 16 * pngs.size()
	for i in pngs.size():
		var size: int = ICO_SIZES[i]
		var data: PackedByteArray = pngs[i]
		f.store_8(size % 256)   # 256 is stored as 0
		f.store_8(size % 256)
		f.store_8(0)
		f.store_8(0)
		f.store_16(1)
		f.store_16(32)
		f.store_32(data.size())
		f.store_32(offset)
		offset += data.size()
	for data in pngs:
		f.store_buffer(data)
	f.close()
