class_name PortraitView
extends Control
## A small 3D picture in a menu (a robot on a stage, the death screen's "who got you"),
## drawn as sharply as the screen allows.
##
## The menus are laid out on a 1600x900 canvas and stretched to the window. A plain
## SubViewportContainer draws its 3D at the canvas size (a 360 px wide stage is 360
## pixels of 3D however big the window is) and the stretch then blows it up: soft, with
## stair-steps no anti-aliasing setting can reach. This keeps the picture at the real
## number of screen pixels it covers instead, whatever the window's size.
##
## On top of that it follows the player's graphics settings (GraphicsQuality): their
## anti-aliasing picks, and with MSAA at 4x or more (the High preset) a small picture
## is drawn at twice the size and shrunk, which cleans up what is left (a big one, like
## the main menu's showcase, has pixels enough already: see SUPERSAMPLE_PIXELS). The
## render scale and Resolution settings never make it smaller.
##
## A picture that fills the screen like the game does (the results screen's killcam:
## `like_game`) is drawn the way the game itself is instead: the render scale and the
## Resolution setting shrink it as they shrink the game, and it is never drawn bigger.
##
## `view` is the SubViewport to build the 3D in (its own world, clear background).

const SUPERSAMPLE_FROM_MSAA := 4   ## this much MSAA or more: draw at twice the size...
const SUPERSAMPLE_PIXELS := 2600000.0   ## ...unless that would be more pixels than this (a 1440p lobby banner is 1.3 million)
const MAX_SIDE := 4096             ## the picture is never wider or taller than this (pixels)

var view: SubViewport
var picture: SubViewportContainer   ## what draws `view` (give it a material to change how)
var like_game := false:             ## drawn at the game's own render scale (see above)
	set(v):
		like_game = v
		apply_graphics()

var _factor := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture = SubViewportContainer.new()
	picture.stretch = true
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The 3D is drawn on a clear background, so its edges come out already multiplied
	# by how much of each pixel they cover: blend it that way, or they go dark.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	picture.material = blend
	add_child(picture)
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	picture.add_child(view)
	resized.connect(fit)


func _enter_tree() -> void:
	apply_graphics()
	if not Settings.changed.is_connected(apply_graphics):
		Settings.changed.connect(apply_graphics)


func _exit_tree() -> void:
	if Settings.changed.is_connected(apply_graphics):
		Settings.changed.disconnect(apply_graphics)


## The player's anti-aliasing picks on the picture (again when the settings change).
func apply_graphics() -> void:
	if like_game:
		GraphicsQuality.apply_viewport(view, Settings.graphics(), Settings.resolution_scale())
	else:
		GraphicsQuality.apply_viewport(view, Settings.graphics(), -1.0)
		view.scaling_3d_scale = 1.0
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	fit()


## How many times the picture's own size it is drawn at with these picks.
static func supersample(picks: Dictionary) -> float:
	return 2.0 if int(picks.get("msaa", 0)) >= SUPERSAMPLE_FROM_MSAA else 1.0


## Pixels of 3D per canvas unit right now: what the window's stretch makes of this
## control, times the supersampling.
func pixel_factor() -> float:
	var stretch := 1.0
	if is_inside_tree():
		var s := (get_viewport().get_stretch_transform() * get_global_transform_with_canvas()).get_scale()
		stretch = maxf(maxf(absf(s.x), absf(s.y)), 0.01)
	var extra := supersample(Settings.graphics()) if not like_game else 1.0
	if size.x * size.y * stretch * stretch * extra * extra > SUPERSAMPLE_PIXELS:
		extra = 1.0
	var k := stretch * extra
	var longest := maxf(maxf(size.x, size.y), 1.0)
	return clampf(k, 1.0 / longest, MAX_SIDE / longest)


## Size the picture for the screen. The container is made as big as the picture is in
## pixels and scaled back down to this control's size, so the viewport inside it has
## every pixel the screen (and the supersampling) can show.
func fit() -> void:
	var k := pixel_factor()
	if size.x < 1.0 or size.y < 1.0:
		return
	_factor = k
	picture.position = Vector2.ZERO
	picture.scale = Vector2.ONE / k
	picture.size = (size * k).round()


func _process(_delta: float) -> void:
	# The window's stretch changes without this control changing size: keep up with it.
	if is_visible_in_tree() and not is_equal_approx(pixel_factor(), _factor):
		fit()
