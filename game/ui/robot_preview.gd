class_name RobotPreview
extends PortraitView
## Robots standing in their idle pose, in a player's colour: one (show_robot,
## turning slowly) or a lineup side by side (show_lineup, for the main menu).
## Its own small 3D world, so nothing behind the menu shows through, drawn as sharply
## as the screen allows (see PortraitView).
##
## On a stage (`staged`: the lobby's and the Character Creator's portrait) the one
## robot stands on a lit pedestal (PortraitStage), framed clear of the name above its
## head, and holds its weapon the way it does in a match, changing its hold now and
## then (PortraitPoser). It can be turned by hand (see `drag`) and builds in like a
## hologram when another character takes its place.

const KEY := Color(1.0, 0.95, 0.88)       ## the main light: warm white, so colours stay true
const RIM := Color(0.6, 0.75, 1.0)        ## the light from behind, when no one player's colour is on show
const SWAY := 24.0                        ## degrees a single robot turns either way
const STAGE_SWAY := 10.0                  ## ...on a stage (it has more going on)
const STAGE_YAW := 20.0                  ## on a stage it stands turned this far from facing you
const BUILD_IN := 0.42                    ## seconds a character takes to build in
const DRIFT := 9.0                        ## seconds the stage's camera takes to drift round and back

signal framed   ## on a stage: the camera was set for a new character or a new size (see height())

var character := ""
var color := Color.WHITE
var weapon := "pistol"   ## the gun in its hands
var turn := true   ## sway left and right; false keeps it facing you
var facing := 0.0  ## a single robot's extra turn (radians): PI shows its back
var staged := false   ## on a lit stage (see above)
var drag := 0.0       ## turned this far by hand (radians); PortraitFrame sets it
var held := false     ## being turned by hand right now: the sway waits
## On a stage: this much of the picture's height, from the top, is kept clear above
## the character's head, and the front of the ring it stands on comes this far down.
var clear_top := 0.10
var floor_at := 0.95

var _stage: Node3D
var _camera: Camera3D
var _rim: DirectionalLight3D
var _robots: Array = []   # {robot: RobotModel, pose: RobotPose, phase: float}
var _time := 0.0
var _base_fov := 28.0
var _lineup := false
var _spin := 0.0   # turning toward `facing`
var _sway := 1.0   # how much of the sway shows (it eases out while the robot is turned by hand)
var _set: PortraitStage      # the pedestal, the light and the dust (staged)
var _poser: PortraitPoser    # how the one on the stage holds its weapon (staged)
var _build := -1.0           # seconds into building in, or -1
var _overlay: ShaderMaterial # the hologram a character builds in from
var _top := 1.8              # how tall the one on the stage is...
var _wide := 0.6             # ...and how wide
var _per_metre := 100.0      # canvas pixels a metre of it takes
var _eye := Vector3(0, 1.0, 4.6)
var _look := Vector3(0, 1.0, 0)


func _init(preview_size: Vector2 = Vector2(150, 190), zoom: float = 1.0, on_stage: bool = false) -> void:
	super()
	staged = on_stage
	custom_minimum_size = preview_size
	size = preview_size
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.90)
	env.ambient_light_energy = 0.34   # low: the lights shape the body, and its colours stay deep
	# What shiny parts reflect: a dim studio (dark above and below, a soft band of light
	# round the middle) instead of the flat grey of an empty background.
	var studio := ProceduralSkyMaterial.new()
	studio.sky_top_color = Color(0.05, 0.06, 0.09)
	studio.sky_horizon_color = Color(0.42, 0.46, 0.55)
	studio.ground_bottom_color = Color(0.02, 0.02, 0.03)
	studio.ground_horizon_color = Color(0.30, 0.33, 0.40)
	studio.sun_angle_max = 0.0
	studio.sky_curve = 0.25
	studio.ground_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = studio
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# The same film look as the arenas (Filmic; they use a white point of 2.4 to 3.2).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.8
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)
	var key := DirectionalLight3D.new()   # high, from the front and one side: it shapes the body and casts its shadows
	key.rotation_degrees = Vector3(-38, 34, 0)
	key.light_color = KEY
	key.light_energy = 1.5
	key.shadow_enabled = true
	key.shadow_blur = 1.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 14.0
	view.add_child(key)
	_rim = DirectionalLight3D.new()   # from behind, in the player's colour: lifts the outline off a dark menu
	_rim.rotation_degrees = Vector3(-18, 205, 0)
	_rim.light_energy = 2.4
	_rim.light_color = RIM
	view.add_child(_rim)
	var fill := DirectionalLight3D.new()   # faint and cool, from the other side and below: nothing goes flat black
	fill.rotation_degrees = Vector3(12, -55, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.62, 0.72, 1.0)
	view.add_child(fill)
	_camera = Camera3D.new()
	_base_fov = (40.0 if staged else 28.0) / zoom
	_camera.fov = _base_fov
	_camera.position = Vector3(0, 1.0, 4.6)
	view.add_child(_camera)
	_stage = Node3D.new()
	view.add_child(_stage)
	if staged:
		_set = PortraitStage.new()
		view.add_child(_set)
		resized.connect(_frame)


## Show this character. entrance (on a stage): it builds in like a hologram, the ring
## under it pulsing, with a quiet shimmer (for when another character takes the stage,
## not for a change of colour or gun).
func show_robot(id: String, player_color: Color, gun: String = "", entrance: bool = false) -> void:
	id = Characters.valid(id)
	gun = weapon if gun == "" else (gun if gun == "none" else WeaponData.valid(gun))   # "none": empty hands
	if id == character and player_color == color and gun == weapon and not _robots.is_empty() and not _lineup:
		return
	var carry := _poser   # the same character with another gun or colour keeps its place in its round of holds
	var same := id == character and not _robots.is_empty()
	character = id
	color = player_color
	weapon = gun
	_lineup = false
	_drop_robots()
	_add(id, player_color, Vector3.ZERO, 0.0, gun)
	_rim.light_color = RobotModel.trim_color(player_color).lerp(Color.WHITE, 0.2)
	_camera.position = Vector3(0, 1.0, 4.6)
	if not staged:
		return
	var robot: RobotModel = _robots[0].robot
	_poser = PortraitPoser.new(robot, _stage)
	if same and carry:
		_poser.resume(carry)
	_poser.update(0.0)
	_set.set_color(RobotModel.trim_color(player_color))
	var box := robot.mesh.get_aabb()
	_top = clampf(box.end.y, 1.2, 2.7) if box.size != Vector3.ZERO else 1.8
	_wide = clampf(maxf(absf(box.position.x), absf(box.end.x)) * 2.0, 0.4, 1.6) if box.size != Vector3.ZERO else 0.6
	_frame()
	_build = -1.0
	robot.mesh.material_overlay = null
	if entrance and is_inside_tree():
		_build = 0.0
		_set.pulse()
		Sound.play("ui_materialize")
		_show_build()


## Several robots side by side, the first on the right (as you look at them) and
## each next one to its left. They all idle, out of step, angled a little inward.
func show_lineup(ids: Array, colors: Array, spacing: float = 1.15) -> void:
	_lineup = true
	_drop_robots()
	_rim.light_color = RIM
	var n := ids.size()
	for i in n:
		var x := (n - 1) * spacing * 0.5 - i * spacing
		_add(ids[i], colors[i % colors.size()], Vector3(x, 0, 0), i * 0.37)
	# Pull the camera back until the whole row fits the frame.
	var aspect := maxf(custom_minimum_size.x / maxf(custom_minimum_size.y, 1.0), 0.1)
	var half_h := tan(deg_to_rad(_base_fov * 0.5))
	var half_w := (n - 1) * spacing * 0.5 + 0.6
	var dist := maxf(4.6, half_w / (half_h * aspect))
	_camera.position = Vector3(0, 1.0, dist)
	_camera.rotation = Vector3.ZERO


func _add(id: String, player_color: Color, at: Vector3, phase: float, gun: String = "pistol") -> void:
	var robot := RobotModel.new().build(id, player_color, false, gun)
	robot.position = at
	_stage.add_child(robot)
	var entry := posed(robot, gun, phase)
	_robots.append(entry)
	pose_at(entry, phase)


## What pose_at needs to keep a robot idling with `gun` in its hands:
## {robot, pose, phase, hold}. (Also used by the main menu's CharacterShowcase.)
static func posed(robot: RobotModel, gun: String, phase: float = 0.0) -> Dictionary:
	var entry := {"robot": robot, "pose": robot.rig.new_pose(), "phase": phase, "hold": null}
	# A long gun: hold it the way the game does (its aim pose on the arms, chest turned).
	if robot.rig.has_clip("aim_" + gun):
		var hold := robot.rig.new_pose()
		robot.rig.sample(hold, "aim_" + gun, 0.0)
		entry.hold = hold
	return entry


## Pose a robot (an entry from posed) at `t` seconds into its idle.
static func pose_at(r: Dictionary, t: float) -> void:
	var robot: RobotModel = r.robot
	var pose: RobotPose = r.pose
	robot.rig.sample(pose, robot.idle, fmod(t, robot.rig.length(robot.idle)))   # (its torso's own idle: see RobotModel.idle)
	if r.hold:
		var hold: RobotPose = r.hold
		var rig := robot.rig
		var arms := PackedInt32Array()
		for n in ["upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r", "pistol", "pistol_slide", "pistol_mag", "pistol_vent",
				"index_l", "index_l2", "fingers_l", "fingers_l2", "thumb_l", "thumb_l2", "index_r", "index_r2", "fingers_r", "fingers_r2", "thumb_r", "thumb_r2"]:
			arms.append(rig.bones[n])
		pose.blend_bones(hold, 1.0, arms)
		var chest: int = rig.bones["chest"]
		pose.rot[chest] = pose.rot[chest] * hold.rot[chest]
		pose.rot[rig.bones["head"]] = hold.rot[chest].inverse() * pose.rot[rig.bones["head"]]
	pose.apply(robot.skeleton)
	robot.settle_sway()


func _process(delta: float) -> void:
	super(delta)
	if _robots.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	if staged and _poser:
		_poser.update(delta)
	else:
		for r in _robots:
			var robot: RobotModel = r.robot
			pose_at(r, _time + r.phase)
			if _lineup:   # each turned a little toward the middle of the row
				robot.rotation.y = PI + 0.15 - clampf(robot.position.x * 0.4, -0.5, 0.5)
	if _lineup:
		return
	# Turned by hand, it stops swaying; let go, it comes back to that once it has turned back.
	var free := not held and absf(drag) < 0.02
	_sway = move_toward(_sway, 1.0 if free else 0.0, delta * (0.8 if free else 4.0))
	var swing := STAGE_SWAY if staged else SWAY
	var sway := sin(_time * 0.6) * deg_to_rad(swing) * smoothstep(0.0, 1.0, _sway) if turn else 0.0
	_spin = lerp_angle(_spin, facing, minf(delta * 8.0, 1.0))
	var front := deg_to_rad(180.0 + STAGE_YAW) if staged else deg_to_rad(200.0)   # 180 = facing you
	_stage.rotation.y = front + sway + _spin + drag
	if staged:
		_set.update(delta)
		_place_camera()
		if _build >= 0.0:
			_build += delta
			_show_build()


## How tall the character on the stage is (metres, hat and all).
func height() -> float:
	return _top


## ...and how wide, shoulder to shoulder.
func width() -> float:
	return _wide


## How many canvas pixels a metre of the character on the stage takes.
func per_metre() -> float:
	return _per_metre


## How far the stage has been turned by hand, wound back to the nearest whole turn
## (so letting go never spins it the long way home).
func settle_drag() -> void:
	drag = wrapf(drag, -PI, PI)


# --- On a stage

## Where the stage's camera stands for this character and this shape of picture: a
## little below its middle, looking up at it (a hero's angle), from just far enough
## that its head clears the top and the front of the ring under it clears the bottom.
## A narrow picture gets a smaller ring, so its sides fit too.
func _frame() -> void:
	if not staged or size.y < 1.0:
		return
	_camera.fov = _base_fov
	var half := tan(deg_to_rad(_base_fov * 0.5))
	var want_top := atan((1.0 - 2.0 * clampf(clear_top, 0.0, 0.6)) * half)   # where its head goes, as an angle off the camera's middle...
	var want_floor := atan((1.0 - 2.0 * clampf(floor_at, 0.5, 1.0)) * half)  # ...and the front of the ring
	var eye_y := _top * 0.46
	var ring := PortraitStage.RADIUS
	var dist := 4.0
	for pass_ in 3:
		var reach := ring * PortraitStage.OUTSIDE   # how far toward the camera the stage's light comes
		var near := reach + 0.6
		var far := 40.0
		for i in 28:   # how far back, so it fills just that much of the picture
			var d := (near + far) * 0.5
			if atan((_top - eye_y) / d) + atan(eye_y / (d - reach)) > want_top - want_floor:
				near = d
			else:
				far = d
		dist = (near + far) * 0.5
		# The ring's width on screen, at its nearest: no wider than the picture.
		var per_metre := size.y * 0.5 / (half * (dist - reach * 0.5))
		ring = minf(PortraitStage.RADIUS, (size.x * 0.5 - 24.0) / (per_metre * PortraitStage.OUTSIDE))
	var reach := ring * PortraitStage.OUTSIDE
	var pitch := -atan(eye_y / (dist - reach)) - want_floor
	_per_metre = size.y * 0.5 / (half * dist)
	_set.set_radius(ring)
	_eye = Vector3(0, eye_y, dist)
	_look = _eye + Vector3(0, tan(pitch), -1.0)
	_place_camera()
	framed.emit()


## The camera drifts a hand's width round the character and back, never still.
func _place_camera() -> void:
	var round := sin(_time * TAU / DRIFT) * deg_to_rad(2.2)
	var bob := sin(_time * TAU / (DRIFT * 0.62) + 1.0) * 0.012
	var eye := _eye.rotated(Vector3.UP, round) + Vector3(0, bob, 0)
	_camera.look_at_from_position(eye, _look.rotated(Vector3.UP, round) + Vector3(0, bob, 0), Vector3.UP)


## Building in: a hologram of the character in its player's colour, made solid from
## the feet up.
func _show_build() -> void:
	if _robots.is_empty():
		return
	var robot: RobotModel = _robots[0].robot
	if _build < 0.0 or _build >= BUILD_IN:
		_build = -1.0
		_overlay_on(robot, null)
		return
	if _overlay == null:
		_overlay = ShaderMaterial.new()
		_overlay.shader = PortraitStage.hologram_shader()
	_overlay.set_shader_parameter("tint", RobotModel.trim_color(color))
	_overlay.set_shader_parameter("line", lerpf(-0.08, _top + 0.12, _build / BUILD_IN))
	_overlay_on(robot, _overlay)


static func _overlay_on(robot: RobotModel, overlay: Material) -> void:
	robot.mesh.material_overlay = overlay
	for held_weapon in [robot.melee, robot.melee_left]:
		if held_weapon:
			for c in held_weapon.get_child(0).get_children():
				if c is MeshInstance3D:
					c.material_overlay = overlay


func _exit_tree() -> void:
	super()
	_drop_robots()


func _drop_robots() -> void:
	_poser = null
	for r in _robots:
		release(r.robot)
	_robots.clear()
	_stage.rotation.y = 0.0


## Free a robot shown in a preview's own 3D world.
static func release(robot: RobotModel) -> void:
	if not is_instance_valid(robot):
		return
	# Let go of the per-player materials first; headless Godot (used by the tests)
	# prints an error when a robot inside the preview's own 3D world is freed with them.
	robot.mesh.material_overlay = null
	for i in robot.mesh.mesh.get_surface_count():
		robot.mesh.set_surface_override_material(i, null)
	robot.queue_free()
