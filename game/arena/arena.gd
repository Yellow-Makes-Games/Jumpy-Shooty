extends Node3D
## The arena scene: builds the level, spawns one Player per connected peer,
## and hosts the HUD and pause menu.

const KIND_COLORS := {
	"floor": Color(0.34, 0.36, 0.40),
	"wall": Color(0.55, 0.57, 0.62),
	"block": Color(0.46, 0.48, 0.53),
	"ramp": Color(0.62, 0.52, 0.36),
	"bridge": Color(0.36, 0.50, 0.62),
	"pillar": Color(0.50, 0.42, 0.40),
	"cover": Color(0.42, 0.50, 0.40),
}

var layout: GreyboxLayout
var players_root: Node3D
var local_player: Player
var hud: Hud
var pause_menu: PauseMenu


func _ready() -> void:
	layout = GreyboxLayout.new().build()
	_build_environment()
	_build_level()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	hud = Hud.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.visibility_changed.connect(_on_pause_toggled)
	Net.arena = self
	Net.players_changed.connect(_sync_players)
	_sync_players()
	_capture_mouse(true)


func _exit_tree() -> void:
	if Net.arena == self:
		Net.arena = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.visible = not pause_menu.visible
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not pause_menu.visible:
		_capture_mouse(true)


func _physics_process(_delta: float) -> void:
	if local_player and local_player.global_position.y < -25.0:
		_respawn(local_player)


func _process(_delta: float) -> void:
	if local_player:
		hud.update_local(local_player)


## Called by Net for every movement snapshot from another player.
func on_snapshot(sender: int, remote_time: float, data: PackedFloat32Array) -> void:
	var p := players_root.get_node_or_null("Player_%d" % sender) as Player
	if p and not p.is_local:
		p.apply_snapshot(remote_time, data)


func _sync_players() -> void:
	for id in Net.players:
		if not players_root.has_node("Player_%d" % id):
			_spawn(id)
	for p in players_root.get_children():
		if not Net.players.has((p as Player).peer_id):
			p.queue_free()
	hud.set_players(Net.players)


func _spawn(id: int) -> void:
	var p := Player.new()
	var local := id == Net.my_id()
	p.setup(id, local)
	players_root.add_child(p)
	if local:
		local_player = p
		_respawn(p)


func _respawn(p: Player) -> void:
	var ids := Net.players.keys()
	ids.sort()
	var index: int = max(ids.find(p.peer_id), 0)
	var s: Array = layout.spawns[(index + randi() % 2 * 4) % layout.spawns.size()]
	p.teleport(s[0], s[1])


func _on_pause_toggled() -> void:
	_capture_mouse(not pause_menu.visible)


func _capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------------------
# Level building

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.38, 0.62)
	sky_mat.sky_horizon_color = Color(0.70, 0.74, 0.80)
	sky_mat.ground_horizon_color = Color(0.45, 0.47, 0.50)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_level() -> void:
	var level := Node3D.new()
	level.name = "Level"
	add_child(level)
	var grid := _grid_texture()
	var materials := {}
	for kind in KIND_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = KIND_COLORS[kind]
		m.albedo_texture = grid
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)  # one grid square per 4 m (sub-lines every 1 m)
		m.roughness = 0.85
		materials[kind] = m
	for piece in layout.pieces:
		var body := StaticBody3D.new()
		body.transform = piece.xf
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = piece.size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = piece.size
		mesh.mesh = bm
		mesh.material_override = materials[piece.kind]
		body.add_child(mesh)
		level.add_child(body)


## A greybox grid so you can judge distance and speed. Not final art.
func _grid_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	for i in size:
		for j in size:
			var major := i < 3 or j < 3
			var minor := (i % 64) < 1 or (j % 64) < 1
			if major:
				img.set_pixel(i, j, Color(0.62, 0.62, 0.62))
			elif minor:
				img.set_pixel(i, j, Color(0.85, 0.85, 0.85))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
