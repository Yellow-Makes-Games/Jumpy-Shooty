extends Node
## The body of tools/combat/explosion_film.gd (a separate file: it uses the game's
## autoloads). Sets off every explosive weapon's blast in a real Practice match, with a
## caption for each, and prints "FILM BLAST <frame> <name>" as each goes off so the film's
## script can cut stills out of it.

const EXPLOSIVES := ["rocket_launcher", "grenade_launcher", "mortar", "flare_gun", "plasma_cannon"]
const EACH := 1.9   ## seconds given to each blast

var _me: Player
var _cam: Camera3D
var _caption: Label
var _blast_name := ""


func run(map: String, only: String) -> void:
	Settings.third_person = false   # (not saved: nothing here calls save_settings)
	Game.start_practice(map)
	await _frames(60)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_cam = Camera3D.new()
	_cam.cull_mask &= ~(1 << (CameraRig.VIEW_BODY_LAYER - 1)) & ~(1 << (Player.VIEWMODEL_LAYER - 1))
	_cam.fov = 70.0
	_cam.far = 600.0
	Net.arena.add_child(_cam)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.position.y = 40
	layer.add_child(_caption)
	Match.exploded.connect(_on_exploded)
	await _frames(30)
	print("FILM START %d" % Engine.get_process_frames())
	if only in ["", "ground"]:
		await _ground()
	if only in ["", "first"]:
		await _first_person()
	if only in ["", "wall"]:
		await _wall()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## Each blast on open ground, eight metres off, from about head height.
func _ground() -> void:
	var spot := _open_ground()
	var eye: Vector3 = spot[0]
	var at: Vector3 = spot[1]
	var back := eye - at
	back.y = 0.0
	_me.teleport(eye - Vector3.UP * 1.8 + back.normalized() * 3.0, 0.0)   # (behind the camera, out of the way)
	Net.arena.hud.visible = false
	_cam.global_position = eye
	_cam.look_at(at + Vector3.UP * 1.2)
	_cam.make_current()
	for w: String in EXPLOSIVES:
		_caption.text = WeaponData.by_id(w).display_name.to_upper()
		_blast_name = "ground_" + w
		Net.arena._on_exploded(-1, at, w)
		print("FILM BLAST %d %s" % [Engine.get_process_frames(), _blast_name])
		_blast_name = ""
		await _seconds(EACH)


## The same, through the player's own eyes: a blast six metres ahead.
func _first_person() -> void:
	var spot := _open_ground()
	var eye: Vector3 = spot[0]
	var at: Vector3 = spot[1]
	var flat := at - eye
	flat.y = 0.0
	var yaw := atan2(-flat.x, -flat.z)
	var feet := eye - Vector3.UP * CameraRig.EYE_HEIGHT
	_me.teleport(feet + flat.normalized() * 2.0, yaw)
	_me.input.yaw = yaw
	_me.input.pitch = -0.25
	await _frames(2)
	var mine := get_viewport().get_camera_3d()
	if _me.rig and _me.rig.camera:
		_me.rig.camera.make_current()
	elif mine:
		mine.make_current()
	Net.arena.hud.visible = true
	await _frames(20)
	for w: String in ["rocket_launcher", "grenade_launcher", "plasma_cannon"]:
		_caption.text = "FIRST PERSON  ·  " + WeaponData.by_id(w).display_name.to_upper()
		_blast_name = "first_" + w
		Net.arena._on_exploded(-1, at, w)
		print("FILM BLAST %d %s" % [Engine.get_process_frames(), _blast_name])
		_blast_name = ""
		await _seconds(EACH)


## Real rounds, flown by the host, into a block wall that breaks.
func _wall() -> void:
	var d: MapDestruction = Net.arena.layout.destruction
	if d == null:
		print("FILM no destruction on this map: no wall part")
		return
	var pick := _block_wall(d)
	if pick.is_empty():
		print("FILM no open block wall found")
		return
	var c: Vector3 = pick.at
	var n: Vector3 = pick.out
	var side := n.cross(Vector3.UP).normalized()
	var feet: Vector3 = pick.feet
	var yaw := atan2(n.x, n.z)   # (facing the wall: along -n)
	_me.teleport(feet, yaw)
	_me.input.yaw = yaw
	_cam.global_position = pick.cam
	_cam.look_at(c + n * 1.0)
	_cam.make_current()
	Net.arena.hud.visible = false
	await _frames(20)
	var shots := [["rocket_launcher", Vector3(0, 0, 0)], ["rocket_launcher", Vector3(0, 0.6, 0)],
		["grenade_launcher", Vector3(0, -0.4, 0)], ["mortar", Vector3(0, 0.3, 0)], ["plasma_cannon", Vector3(0, 0.2, 0)],
		["flare_gun", Vector3(0, 0.4, 0)]]
	for k in shots.size():
		var w: String = shots[k][0]
		var spread := minf(float(pick.width) * 0.5 - 1.0, 4.0)
		var target: Vector3 = c + side * lerpf(-spread, spread, float(k) / (shots.size() - 1)) + shots[k][1]
		_caption.text = "ON A WALL  ·  " + WeaponData.by_id(w).display_name.to_upper()
		_blast_name = "wall_%d_%s" % [k, w]
		_fire(w, feet + Vector3.UP * CameraRig.EYE_HEIGHT, target)
		await _seconds(EACH + 0.4)
	_blast_name = ""
	await _seconds(1.5)


## As Match._host_projectile does, without its checks (who is holding what, how soon).
func _fire(w: String, origin: Vector3, target: Vector3) -> void:
	var data := WeaponData.by_id(w)
	var dist := origin.distance_to(target)
	var t := dist / data.projectile_speed
	var aim := target + Vector3.UP * 0.5 * data.projectile_gravity * t * t   # (lobbed rounds drop: aim above)
	var dir := (aim - origin).normalized()
	var id: int = Match._next_projectile
	Match._next_projectile += 1
	Match._projectiles[id] = {"pos": origin, "vel": dir * data.projectile_speed, "shooter": _me.peer_id, "weapon": w, "t": 0.0}
	Match._projectile_spawn(id, _me.peer_id, w, origin, dir)


func _on_exploded(_id: int, _at: Vector3, _w: String) -> void:
	if _blast_name != "":
		print("FILM BLAST %d %s" % [Engine.get_process_frames(), _blast_name])
		_blast_name = ""


## [eye, ground point] for a blast on open ground: from a spawn point, the first way
## round with at least ten metres clear and flat ground eight metres off.
func _open_ground() -> Array:
	var space := (Net.arena as Node3D).get_world_3d().direct_space_state
	for s: Array in Net.arena.layout.spawns:
		var eye: Vector3 = s[0] + Vector3.UP * 1.8
		for k in 12:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, s[1] + TAU * k / 12.0)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * 12.0, 1)).is_empty():
				continue
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye + dir * 8.0, eye + dir * 8.0 + Vector3.DOWN * 4.0, 1))
			if down.is_empty() or (down.normal as Vector3).y < 0.9:
				continue
			return [eye, down.position + Vector3.UP * 0.05]
	var s0: Array = Net.arena.layout.spawns[0]
	return [s0[0] + Vector3.UP * 1.8, s0[0] + Vector3.FORWARD.rotated(Vector3.UP, s0[1]) * 8.0]


## A fine block wall out in the open with ten metres clear in front of it, floor to
## stand on, and room for a camera off to one side: {at (a cell in the middle of it,
## chest high), out (the way its open face looks), feet, cam, width}.
func _block_wall(d: MapDestruction) -> Dictionary:
	var space := (Net.arena as Node3D).get_world_3d().direct_space_state
	var clear := func(a: Vector3, b: Vector3) -> bool:
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty()
	for open_sky in [true, false]:
		for i in d.panels.size():
			var p: Dictionary = d.panels[i]
			if not p.fine or p.kind != "block" or p.thin == 1 or p.nu * p.nv < 150:
				continue
			var basis: Basis = (p.xf as Transform3D).basis
			var normal: Vector3 = basis[p.thin].normalized()
			if absf(normal.y) > 0.2:
				continue
			var width: float = float(p.nu) * float(p.cell[p.u]) * basis[p.u].length()
			if width < 5.0:
				continue
			var iu: int = p.nu / 2
			for s in [1.0, -1.0]:
				var out: Vector3 = normal * s
				var side := out.cross(Vector3.UP).normalized()
				# (the row of cells about chest high above the floor in front)
				var first := d.cell_center(p.first + iu * p.su)
				var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(first + out * 2.0 + Vector3.UP * 3.0, first + out * 2.0 + Vector3.DOWN * 6.0, 1))
				if down.is_empty():
					continue
				var iv := clampi(roundi((float(down.position.y) + 1.3 - first.y) / maxf(float(p.cell[p.v]), 0.05)), 1, p.nv - 2)
				var at := d.cell_center(p.first + iu * p.su + iv * p.sv)
				if not clear.call(at + out * 0.6, at + out * 11.0):
					continue
				var stand := at + out * 10.0
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(stand + Vector3.UP, stand + Vector3.DOWN * 4.0, 1))
				if ground.is_empty() or absf((ground.position as Vector3).y - at.y) > 2.5:
					continue
				var cam := at + out * 7.0 + side * 5.5 + Vector3.UP * 0.6
				if not clear.call(stand + Vector3.UP * 1.5, cam) or not clear.call(cam, at + out * 0.6):
					continue
				if open_sky and not clear.call(at + out * 1.5, at + out * 1.5 + Vector3.UP * 30.0):
					continue
				print("FILM wall %d at %s facing %s, %.1f m wide" % [i, at, out, width])
				return {"at": at, "out": out, "feet": ground.position, "cam": cam, "width": width}
	return {}


func _seconds(t: float) -> void:
	var left := t
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
