extends Node
## The body of tools/robot/hit_film.gd (a separate file: it uses the game's autoloads).
## Hits a player in a real Practice match on the Testing Grounds, hit after hit of every
## kind with a caption for each, so the game can be filmed taking them (see HitReaction).
## The hits are made up here (Player.flinch, Arena.hit_sparks): nobody is hurt.

const EAST := -PI / 2.0
const START := Vector3(51, 6.05, -30.0)   # the platform at the start of the grapple lane: open ground ahead
## Cameras of the film's own: [where from, looking at (both from the feet), field of view].
const CAMERAS := {
	"side": [Vector3(0.4, 1.2, 4.4), Vector3(0.1, 0.95, 0.0), 36.0],      # beside the gun arm: the body in profile
	"front": [Vector3(3.6, 1.5, 2.0), Vector3(0.0, 0.95, 0.0), 40.0],     # ahead and to the gun side
	"back": [Vector3(-3.4, 1.8, 1.4), Vector3(0.3, 1.0, 0.1), 40.0],      # behind the gun shoulder
}
const STEP := 120                         # physics steps a second
# Which way a blow travels (the body faces east: +x), by where it comes from.
const FROM := {"the front": Vector3(-1, 0, 0), "behind": Vector3(1, 0, 0), "the left": Vector3(0, 0, 1), "the right": Vector3(0, 0, -1),
	"front left": Vector3(-0.7, 0, 0.7), "nowhere": Vector3.ZERO}
## The film: [caption, damage, where from, headshot, what (a HitReaction kind), how many (fast, one after another)].
const HITS := {
	"small": [["SMALL HIT", 8.0, "the front", false, HitReaction.SHOT, 1], ["SMALL HIT", 8.0, "the left", false, HitReaction.SHOT, 1]],
	"medium": [["MEDIUM HIT", 30.0, "the front", false, HitReaction.SHOT, 1], ["MEDIUM HIT", 30.0, "the left", false, HitReaction.SHOT, 1]],
	"big": [["BIG HIT", 80.0, "the front", false, HitReaction.SHOT, 1], ["BIG HIT", 80.0, "the right", false, HitReaction.SHOT, 1],
		["BIG HIT", 80.0, "behind", false, HitReaction.SHOT, 1]],
	"head": [["HEADSHOT", 45.0, "the front", true, HitReaction.SHOT, 1], ["HEADSHOT", 45.0, "the left", true, HitReaction.SHOT, 1]],
	"melee": [["MELEE HIT", 40.0, "the front", false, HitReaction.MELEE, 1], ["KICK", 25.0, "the left", false, HitReaction.MELEE, 1],
		["FULL-CHARGE MELEE HIT", 80.0, "the front", false, HitReaction.HEAVY, 1], ["FLYING KICK", 60.0, "front left", false, HitReaction.HEAVY, 1]],
	"rapid": [["RAPID FIRE", 12.0, "front left", false, HitReaction.SHOT, 14], ["CRASH INTO THE FLOOR", 40.0, "nowhere", false, HitReaction.CRASH, 1]],
}
const ORDER := ["small", "medium", "big", "head", "melee", "rapid"]

var _me: Player
var _cam: Camera3D
var _cam_from := Vector3.ZERO
var _cam_at := Vector3.ZERO
var _caption: Label


## `scenes`: which of HITS, in order ("all": every one, then a big hit in the air).
func run(scenes: Array, view: String) -> void:
	Settings.third_person = view != "first"   # (not saved: nothing here calls save_settings)
	Game.start_practice("testing_grounds")
	await _frames(40)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	if CAMERAS.has(view):
		# Facing east, the gun arm is on the +z side. Not the first-person body or arms.
		_cam = Camera3D.new()
		_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
		_cam.fov = CAMERAS[view][2]
		_cam_from = CAMERAS[view][0]
		_cam_at = CAMERAS[view][1]
		Net.arena.add_child(_cam)
		_cam.make_current()
		_follow(1.0)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.position.y = 70
	layer.add_child(_caption)
	await _frames(40)
	print("FILM START %d" % Engine.get_process_frames())
	await _physics(40)
	var all := scenes.has("all")
	for scene in (ORDER if all else scenes):
		for h in HITS.get(scene, []):
			await _hit(h)
	if all or scenes.has("air"):
		await _air()
	Input.action_release("jump")
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


func _hit(h: Array) -> void:
	var count := int(h[5])
	_caption.text = "%s  ·  %d damage%s  ·  from %s" % [h[0], int(h[1]), " each" if count > 1 else "", h[2]] if str(h[2]) != "nowhere" \
		else "%s  ·  %d damage" % [h[0], int(h[1])]
	await _physics(30)
	for i in count:
		_land(FROM[h[2]], float(h[1]), bool(h[3]), int(h[4]))
		if count > 1:
			await _physics(int(0.085 * STEP))
	await _physics(int(1.0 * STEP))
	_caption.text = ""
	await _physics(10)


# One made-up hit: the flinch, and for a bullet the sparks where it lands (as a shot from 20 m off would strike them).
func _land(way: Vector3, damage: float, headshot: bool, blow: int) -> void:
	_me.flinch(way, damage, headshot, blow)
	if blow == HitReaction.SHOT and way != Vector3.ZERO:
		var at := _me.global_position + Vector3(0, 1.62 if headshot else 1.2, 0) - way.normalized() * (0.14 if headshot else 0.24)
		Net.arena.hit_sparks(at - way.normalized() * 20.0, PackedVector3Array([at]), [true])
	print("FILM hit %.0f %s" % [damage, way])


## A jump, and a big hit at the top of it.
func _air() -> void:
	for from in ["the front"]:
		_caption.text = "BIG HIT IN THE AIR  ·  80 damage  ·  from %s" % from
		await _physics(30)
		Input.action_press("jump")
		await _physics(3)
		Input.action_release("jump")
		while _me.velocity.y > 1.5:
			await _physics(1)
		_land(FROM[from], 80.0, false, HitReaction.SHOT)
		for i in 600:
			await _physics(1)
			if _me.is_on_floor():
				break
		await _physics(int(0.9 * STEP))
		_caption.text = ""
		await _physics(12)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_follow(0.25)


## The camera of its own keeps beside the body (`share` of the way there each step).
func _follow(share: float) -> void:
	if _cam == null or not is_instance_valid(_me):
		return
	var feet := _me.global_position
	var want := feet + _cam_from
	_cam.global_position = want if share >= 1.0 else _cam.global_position.lerp(want, share)
	_cam.look_at(feet + _cam_at)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
