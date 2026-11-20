class_name ObjectiveProps
extends Node3D
## What the team modes put in the arena (see Teams), on every copy: only pictures,
## moved each frame to where Teams says things are.
##  - Capture the Flag: each team's flag on a pole over a glowing stand at its base.
##    A carried flag rides on its carrier's back (smaller); a dropped one stands where
##    it fell, its pole blinking.
##  - Search and Destroy: the two bomb sites as glowing rings with a big A and B over
##    them, and the bomb: on its carrier's back, lying where it was dropped, or
##    planted, blinking faster and faster as the fuse runs down. When it goes off,
##    a blast (see blast()).

const STAND_RADIUS := 1.1

var _flags: Array = []        # per team: Node3D (pole and cloth)
var _stands: Array = []
var _bomb: Node3D
var _bomb_light: OmniLight3D
var _bomb_lamp: StandardMaterial3D
var _sites: Array = []
var _t := 0.0


func _ready() -> void:
	name = "Objectives"
	if Teams.is_ctf():
		for t in 2:
			var stand := _ring(Teams.team_color(t), STAND_RADIUS, 0.6)
			stand.position = Teams.flag_home(t)
			add_child(stand)
			_stands.append(stand)
			var flag := _make_flag(Teams.team_color(t))
			add_child(flag)
			_flags.append(flag)
	elif Teams.is_snd():
		for i in Teams.sites.size():
			var site := _ring(Color(1.0, 0.72, 0.2), Teams.SITE_RADIUS, 0.35)
			site.position = Teams.sites[i]
			var letter := Label3D.new()
			letter.text = Teams.site_letter(i)
			letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			letter.font_size = 160
			letter.pixel_size = 0.012
			letter.outline_size = 24
			letter.modulate = Color(1.0, 0.8, 0.35, 0.95)
			letter.no_depth_test = false
			letter.position.y = 3.4
			site.add_child(letter)
			add_child(site)
			_sites.append(site)
		_bomb = _make_bomb()
		add_child(_bomb)
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	if Teams.is_ctf():
		for t in _flags.size():
			_place_flag(t)
	elif _bomb:
		_place_bomb()


func _place_flag(t: int) -> void:
	var flag: Node3D = _flags[t]
	var f: Dictionary = Teams.flags[t] if t < Teams.flags.size() else {}
	var state := int(f.get("state", Teams.Flag.HOME))
	flag.visible = true
	if state == Teams.Flag.CARRIED:
		var p: Player = Net.arena.get_player(int(f.carrier)) if Net.arena else null
		if p and p.alive:
			var back := Vector3(sin(p.visual.global_rotation.y), 0.0, cos(p.visual.global_rotation.y))
			flag.global_position = p.global_position + Vector3(0, 0.7, 0) + back * 0.35
			flag.scale = Vector3.ONE * 0.6
			flag.rotation.y = p.visual.global_rotation.y
			flag.get_node("Cloth").rotation.y = sin(_t * 9.0) * 0.25
			return
		flag.visible = p != null
	flag.scale = Vector3.ONE
	flag.global_position = Teams.flag_position(t)
	flag.rotation.y = _t * 0.6 if state == Teams.Flag.HOME else 0.0
	flag.get_node("Cloth").rotation.y = sin(_t * 2.0) * 0.2
	var tip := flag.get_node("Tip") as MeshInstance3D
	tip.visible = state != Teams.Flag.DROPPED or fmod(_t, 0.6) < 0.4   # dropped: it blinks


func _place_bomb() -> void:
	var carrier := Teams.bomb_carrier
	var at := Teams.bomb_position()
	_bomb.visible = at != Vector3.INF and not (Teams.phase == Teams.Phase.OVER and Teams.round_reason == "exploded")
	if not _bomb.visible:
		return
	var p: Player = Net.arena.get_player(carrier) if carrier != 0 and Net.arena else null
	if p:
		var back := Vector3(sin(p.visual.global_rotation.y), 0.0, cos(p.visual.global_rotation.y))
		_bomb.global_position = p.global_position + Vector3(0, 1.0, 0) + back * 0.32
		# Being planted: it is in the planter's free hand, down in front of them (see FreeHand).
		if Teams.holder == carrier and Teams.phase == Teams.Phase.LIVE and p.robot != null and p.hand.w > 0.0:
			_bomb.global_position = _bomb.global_position.lerp(p.robot.marker("hand_l") - Vector3(0, 0.06, 0), smoothstep(0.0, 1.0, p.hand.w))
		_bomb.rotation.y = p.visual.global_rotation.y
		_bomb.visible = p.alive
	else:
		_bomb.global_position = at + Vector3(0, 0.12, 0)
		_bomb.rotation.y = 0.0
	var on := true
	if Teams.phase == Teams.Phase.PLANTED:
		var rate := lerpf(1.0, 6.0, 1.0 - clampf(Teams.fuse_left / Teams.FUSE, 0.0, 1.0))
		on = fmod(_t * rate, 1.0) < 0.35
	else:
		on = fmod(_t, 1.5) < 0.2
	_bomb_lamp.emission_energy_multiplier = 4.0 if on else 0.3
	_bomb_light.light_energy = 1.4 if on else 0.0


## A blast where the bomb was (the sound and the shake are the arena's).
func blast(at: Vector3) -> void:
	var w := WeaponData.by_id("rocket_launcher")
	for off in [Vector3.ZERO, Vector3(1.6, 0.8, 0.4), Vector3(-1.2, 1.4, -1.0), Vector3(0.3, 2.4, 1.3)]:
		ShotFx.landed(get_parent(), at + off, w)


# ---------------------------------------------------------------------------
# Building

static func _glow(color: Color, energy: float = 1.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


## A flat glowing ring on the floor (a flag stand or a bomb site).
func _ring(color: Color, radius: float, alpha: float) -> Node3D:
	var root := Node3D.new()
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	disc.mesh = cyl
	var fill := StandardMaterial3D.new()
	fill.albedo_color = Color(color, alpha * 0.35)
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = fill
	disc.position.y = 0.03
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.08
	torus.outer_radius = radius
	edge.mesh = torus
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(color, alpha + 0.3)
	line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.material_override = line
	edge.position.y = 0.05
	edge.scale.y = 0.3
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(edge)
	return root


func _make_flag(color: Color) -> Node3D:
	var flag := Node3D.new()
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.045
	cyl.height = 2.4
	pole.mesh = cyl
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.82, 0.84, 0.88)
	metal.metallic = 0.7
	metal.roughness = 0.35
	pole.material_override = metal
	pole.position.y = 1.2
	flag.add_child(pole)
	var cloth_root := Node3D.new()
	cloth_root.name = "Cloth"
	cloth_root.position = Vector3(0, 2.05, 0)
	flag.add_child(cloth_root)
	var cloth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.6, 0.04)
	cloth.mesh = box
	cloth.material_override = _glow(color, 0.9)
	cloth.position.x = 0.5
	cloth_root.add_child(cloth)
	var tip := MeshInstance3D.new()
	tip.name = "Tip"
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.18
	tip.mesh = ball
	tip.material_override = _glow(color, 2.5)
	tip.position.y = 2.45
	flag.add_child(tip)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.0
	light.omni_range = 4.0
	light.position.y = 2.0
	flag.add_child(light)
	return flag


func _make_bomb() -> Node3D:
	var bomb := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.48, 0.26, 0.32)
	body.mesh = box
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.16, 0.17, 0.2)
	shell.metallic = 0.4
	shell.roughness = 0.55
	body.material_override = shell
	bomb.add_child(body)
	for x in [-0.14, 0.0, 0.14]:
		var can := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 0.34
		can.mesh = cyl
		can.rotation.x = PI * 0.5
		can.position = Vector3(x, 0.15, 0)
		can.material_override = _glow(Color(0.9, 0.55, 0.15), 0.25)
		bomb.add_child(can)
	var lamp := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.045
	dot.height = 0.09
	lamp.mesh = dot
	_bomb_lamp = _glow(Color(1.0, 0.15, 0.1), 4.0)
	lamp.material_override = _bomb_lamp
	lamp.position = Vector3(0.17, 0.16, 0.12)
	bomb.add_child(lamp)
	_bomb_light = OmniLight3D.new()
	_bomb_light.light_color = Color(1.0, 0.2, 0.1)
	_bomb_light.omni_range = 3.0
	_bomb_light.position = Vector3(0, 0.4, 0)
	bomb.add_child(_bomb_light)
	return bomb
