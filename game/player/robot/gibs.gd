class_name Gibs
extends Node3D
## A robot blown apart (see Remains): its own body cut into pieces at the joints (head,
## chest, hips, each upper arm, forearm, thigh and shin, the gun or the blade in its
## fist), flung by the killing blow (Match.death_fx) with a handful of scrap (bolts and
## plates in the player's trim colour and grey metal), sparks and smoke. Looks only:
## every copy of the game makes its own. The pieces tumble to rest, and LIFETIME after
## the death they burn away (Dissolve) and the whole lot is gone.
##
## Every triangle of a robot follows one bone, so each body part is a clean cut: its
## bones' triangles, moved off the skeleton into the bone's own space (see cut). Each
## piece then starts where that bone stood in the robot's last pose, in its own paint.
##
## A killcam replays the pieces' flight from Killcam's recording of it (capture()): a
## puppet() is the same pieces, held still by physics and placed from the recording
## (pose()) on the replay's own clock.

## Which piece a bone's triangles go in; a bone not listed goes with its parent's (a
## hand's grip bones with the forearm).
const PIECE_OF := {
	"root": "hips", "hips": "hips", "spine": "chest", "chest": "chest", "head": "head",
	"upper_arm_l": "upper_arm_l", "forearm_l": "forearm_l", "hand_l": "forearm_l", "grapple": "forearm_l",
	"upper_arm_r": "upper_arm_r", "forearm_r": "forearm_r", "hand_r": "forearm_r",
	"thigh_l": "thigh_l", "shin_l": "shin_l", "foot_l": "shin_l",
	"thigh_r": "thigh_r", "shin_r": "shin_r", "foot_r": "shin_r",
}
## The bone each piece moves with (its other bones' triangles keep their place on it, as posed).
const PIECE_BONE := {
	"head": "head", "chest": "chest", "hips": "hips",
	"upper_arm_l": "upper_arm_l", "forearm_l": "forearm_l", "upper_arm_r": "upper_arm_r", "forearm_r": "forearm_r",
	"thigh_l": "thigh_l", "shin_l": "shin_l", "thigh_r": "thigh_r", "shin_r": "shin_r",
	"gun": "pistol", "gun_l": "pistol_l",
}
## The body's pieces (every character has all of them), then the gun (or two, akimbo).
const BODY_PIECES := ["head", "chest", "hips", "upper_arm_l", "forearm_l", "upper_arm_r", "forearm_r",
	"thigh_l", "shin_l", "thigh_r", "shin_r"]

const MAX_PIECES := 30          ## pieces and scrap together, at most
const SCRAP := [12, 17]         ## how many bits of scrap (at least, at most; fewer if the pieces are many)
const MAX_SPEED := 20.0         ## no piece flies off faster than this (m/s)
const SPIN := 14.0              ## how fast pieces tumble at most (rad/s)
const BLAST_SPEED := [3.0, 8.0]   ## how hard the blow throws them (from its knockback): least, most
const SMOKING := ["chest", "head", "hips"]   ## the pieces that trail smoke for a moment
const SMOKE_TIME := 1.8         ## seconds they smoke
const GREY := Color(0.42, 0.44, 0.48)        ## the scrap's bare metal
const DARK := Color(0.17, 0.18, 0.21)        ## and its gunmetal

static var _cuts := {}          # body mesh -> its pieces (see cut)

## Who fell, as what, and how the blow fell (Match.death_fx): kept with the recording.
var who := 0
var character := ""
var weapon := ""
var body_color := Color.WHITE
var blow: Dictionary = {}
var _age := 0.0
var _edge := Color(1.0, 0.55, 0.2)
var _dissolve: Dissolve
var _first: Array = []   # each body in the world at the death (see capture)


## `p`'s body in pieces, flung by the killing blow (Match.death_fx), added to the world.
## Returns the node holding them, or null when there are none (no model, or it could
## not be cut: Remains then shows a ragdoll instead).
static func spawn(p: Player, fx: Dictionary) -> Node3D:
	if p == null or p.robot == null or p.robot.mesh == null or p.robot.skeleton == null:
		return null
	var parent: Node = Net.arena
	if parent == null or not parent.is_inside_tree() or not p.robot.is_inside_tree():
		return null
	var pieces := cut(p.robot)
	if pieces.is_empty():
		return null
	var g := Gibs.new()
	g.name = "Gibs%d" % p.peer_id
	g.top_level = true   # its pieces are placed in world space
	g._edge = RobotModel.trim_color(Net.player_color(p.peer_id))
	g.who = p.peer_id
	g.character = p.character
	g.weapon = p.robot.weapon
	g.body_color = Net.player_color(p.peer_id)
	g.blow = fx.duplicate()
	var bodies := g._build(p.robot, pieces)
	if bodies.is_empty():
		g.free()
		return null
	g._first = g.capture()
	parent.add_child(g)
	g._throw(bodies, p, fx)
	g.effects(p.global_position + Vector3(0, 1.0, 0), fx)
	if DevArgs.sync_log:
		print("GIBS %d %d %d" % [Net.my_id(), p.peer_id, bodies.size()])
	return g


## A replay's giblets (see KillcamView): `model`'s body cut as for spawn(), with `scrap`
## bits of scrap (as many as the recording has), every body held still (kinematic, and
## in no physics layer) until pose() places it. `model` must be in the world, posed as
## at the death. Not yet in the world itself; the replay frees it. Null if it can't be cut.
static func puppet(model: RobotModel, scrap: int, edge: Color) -> Gibs:
	if model == null or model.mesh == null or model.skeleton == null or not model.is_inside_tree():
		return null
	var pieces := cut(model)
	if pieces.is_empty():
		return null
	var g := Gibs.new()
	g.name = "ReplayGibs"
	g.top_level = true
	g._edge = edge
	var bodies := g._build(model, pieces, scrap)
	if bodies.is_empty():
		g.free()
		return null
	for body in bodies:
		var b := body as RigidBody3D
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		b.freeze = true
		b.collision_layer = 0
		b.collision_mask = 0
	g.set_process(false)   # the replay decides when it goes
	return g


## Where each body is in the world now, in order: what Killcam records.
func capture() -> Array:
	var out := []
	for c in get_children():
		var b := c as RigidBody3D
		if b:
			out.append(b.global_transform if b.is_inside_tree() else b.transform)
	return out


## capture() at the moment of the death, before the blow moved anything.
func start_pose() -> Array:
	return _first


## How many of the bodies are scrap.
func scrap_count() -> int:
	return get_children().filter(func(c): return String((c as Node).name).begins_with("scrap")).size()


## A puppet: puts each body where `bodies` (from capture()) says.
func pose(bodies: Array) -> void:
	var i := 0
	for c in get_children():
		var b := c as RigidBody3D
		if b == null:
			continue
		b.visible = i < bodies.size()   # (a piece the recording lacks stays out of sight)
		if b.visible:
			b.global_transform = bodies[i]
		i += 1


## Where the body was: its chest, or the middle of the pieces.
func focus() -> Vector3:
	var chest := get_node_or_null("chest") as Node3D
	if chest:
		return chest.global_position
	var mid := Vector3.ZERO
	var n := 0
	for c in get_children():
		if c is Node3D:
			mid += (c as Node3D).global_position
			n += 1
	return mid / maxi(n, 1)


## How long since the death (s).
func age() -> float:
	return _age


## A robot's body cut into its pieces, by the bone each triangle follows (made once per
## body mesh: per model file and gun, or per custom character and gun). Each piece:
## {name, bone: the bone it moves with, parts: [{bone, mesh: in that bone's own space,
## surfaces: which surface of the body mesh each of its surfaces is, triangles}]}.
## Empty if the mesh can't be cut.
static func cut(model: RobotModel) -> Array:
	var source: Mesh = model.mesh.mesh
	if _cuts.has(source):
		return _cuts[source]
	var skin := model.mesh.skin
	if source == null or skin == null:
		return []
	var skeleton := model.skeleton
	var piece_of := PackedStringArray()   # skin bind -> the piece its triangles go in
	var bone_of := PackedStringArray()    # skin bind -> its bone's name
	for b in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(b))
		if bone_name == "":
			bone_name = model.rig.bone_names[skin.get_bind_bone(b)]
		bone_of.append(bone_name)
		piece_of.append(_piece_for(skeleton, bone_name))
	var sorted := {}   # piece -> bind -> surface -> its triangles' indices (an Array: shared, so it fills in place)
	var all_arrays := []   # each surface of the body mesh's arrays
	for s in source.get_surface_count():
		var mat := source.surface_get_material(s)
		var gun := mat != null and "." in mat.resource_name   # "<gun>.<kind>"
		var arrays := source.surface_get_arrays(s)
		all_arrays.append(arrays)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty() or bones.is_empty():
			continue
		var per := bones.size() / verts.size()   # 4 or 8 bones per vertex
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		for t in range(0, index.size(), 3):
			var v := index[t]
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			var bind := bones[v * per + best]
			if bind < 0 or bind >= piece_of.size():
				bind = 0
			var piece := piece_of[bind]
			if gun:
				piece = "gun_l" if piece.ends_with("_l") else "gun"   # akimbo: a gun in each hand
			if not sorted.has(piece):
				sorted[piece] = {}
			if not sorted[piece].has(bind):
				sorted[piece][bind] = {}
			if not sorted[piece][bind].has(s):
				sorted[piece][bind][s] = []
			(sorted[piece][bind][s] as Array).append_array([index[t], index[t + 1], index[t + 2]])
	var out := []
	for piece in BODY_PIECES + ["gun", "gun_l"]:
		if not sorted.has(piece):
			continue
		var parts := []
		for bind in sorted[piece]:
			var part := _bake(all_arrays, sorted[piece][bind], skin.get_bind_pose(bind))
			part["bone"] = bone_of[bind]
			parts.append(part)
		out.append({"name": piece, "bone": PIECE_BONE[piece], "parts": parts})
	if _cuts.size() > 64:
		_cuts.clear()
	_cuts[source] = out
	return out


## The piece a bone's triangles go in: its own, or the nearest listed bone above it.
static func _piece_for(skeleton: Skeleton3D, bone_name: String) -> String:
	var i := skeleton.find_bone(bone_name)
	while i >= 0:
		var n := skeleton.get_bone_name(i)
		if PIECE_OF.has(n):
			return PIECE_OF[n]
		i = skeleton.get_bone_parent(i)
	return "chest"


## One bone's triangles from some of the body's surfaces (surface -> indices; `all_arrays`:
## every surface's arrays), as a plain mesh in the bone's own space: only the vertices
## they use, put through the bind pose.
static func _bake(all_arrays: Array, surfaces: Dictionary, bind_pose: Transform3D) -> Dictionary:
	var mesh := ArrayMesh.new()
	var which := PackedInt32Array()
	var triangles := 0
	for s in surfaces:
		var arrays: Array = all_arrays[s]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var used := PackedInt32Array(surfaces[s])
		var remap := {}   # source vertex -> new
		var out_verts := PackedVector3Array()
		var out_normals := PackedVector3Array()
		var out_index := PackedInt32Array()
		out_index.resize(used.size())
		for i in used.size():
			var v := used[i]
			if not remap.has(v):
				remap[v] = out_verts.size()
				out_verts.append(bind_pose * verts[v])
				if not normals.is_empty():
					out_normals.append((bind_pose.basis * normals[v]).normalized())
			out_index[i] = remap[v]
		var baked := []
		baked.resize(Mesh.ARRAY_MAX)
		baked[Mesh.ARRAY_VERTEX] = out_verts
		if not out_normals.is_empty():
			baked[Mesh.ARRAY_NORMAL] = out_normals
		baked[Mesh.ARRAY_INDEX] = out_index
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, baked)
		which.append(s)
		triangles += used.size() / 3
	return {"mesh": mesh, "surfaces": which, "triangles": triangles}


## The pieces as bodies, each where its bone stands now, then the scrap. Not yet in
## the world (see _throw). `scrap`: how many bits of scrap (-1: a few, at random).
func _build(model: RobotModel, pieces: Array, scrap: int = -1) -> Array:
	var skeleton := model.skeleton
	var frame := skeleton.global_transform
	var bodies := []
	for piece in pieces:
		var main := skeleton.find_bone(piece.bone)
		if main < 0:
			continue
		var body := _body(piece.name)
		body.transform = (frame * skeleton.get_bone_global_pose(main)).orthonormalized()
		var inside := body.transform.affine_inverse()
		for part in piece.parts:
			var bone := skeleton.find_bone(part.bone)
			var mi := MeshInstance3D.new()
			mi.mesh = part.mesh
			mi.transform = inside * frame * skeleton.get_bone_global_pose(maxi(bone, 0))
			for i in (part.surfaces as PackedInt32Array).size():
				mi.set_surface_override_material(i, _own(model.mesh.get_active_material(part.surfaces[i])))
			body.add_child(mi)
		bodies.append(body)
	# The blade in the fist (it is not in the body mesh): copies of its pieces.
	for held in [model.melee, model.melee_left]:
		if held == null or held.get_child_count() == 0:
			continue
		var holder := held.get_child(0) as Node3D
		var body := _body("melee")
		body.transform = holder.global_transform.orthonormalized()
		var inside := body.transform.affine_inverse()
		for c in holder.get_children():
			var src := c as MeshInstance3D
			if src == null or src.mesh == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = src.mesh
			mi.transform = inside * src.global_transform
			for i in src.mesh.get_surface_count():
				mi.set_surface_override_material(i, _own(src.get_active_material(i)))
			body.add_child(mi)
		bodies.append(body)
	for body in bodies:
		if not _shape(body):
			body.free()
	bodies = bodies.filter(func(b): return is_instance_valid(b))
	if bodies.is_empty():
		return bodies
	# Scrap from round the middle of the body.
	var trim := _edge
	var mid := frame * skeleton.get_bone_global_pose(maxi(skeleton.find_bone("chest"), 0)).origin
	var count := scrap if scrap >= 0 else mini(randi_range(SCRAP[0], SCRAP[1]), MAX_PIECES - bodies.size())
	for i in maxi(count, 0):
		var body := _scrap(i, trim)
		body.name = "scrap%d" % i
		body.transform = Transform3D(Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)),
			mid + Vector3(randf_range(-0.25, 0.25), randf_range(-0.45, 0.2), randf_range(-0.2, 0.2)))
		bodies.append(body)
	for body in bodies:
		add_child(body)
	return bodies


## A material of the dead robot's to keep: a glowing one is copied, so the visor stays
## lit (the robot's own powers down, then lights up again when it respawns).
func _own(m: Material) -> Material:
	var b := m as BaseMaterial3D
	if b and b.emission_enabled:
		return b.duplicate()
	return m


func _body(piece: String) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = piece
	body.collision_layer = Remains.DEBRIS_LAYER
	body.collision_mask = 1   # the level only: not each other, not players
	body.continuous_cd = true
	body.linear_damp = 0.05
	body.angular_damp = 0.6
	var surface := PhysicsMaterial.new()
	surface.friction = 0.8
	surface.bounce = 0.25
	body.physics_material_override = surface
	return body


## A box round the body's meshes, a little inside them, and a mass to go with it.
## False if it has nothing to show.
func _shape(body: RigidBody3D) -> bool:
	var box := AABB()
	var first := true
	for c in body.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b := mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return false
	var size := (box.size * 0.85).max(Vector3.ONE * 0.04)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = box.get_center()
	body.add_child(shape)
	body.mass = clampf(size.x * size.y * size.z * 120.0, 0.2, 6.0)
	return true


## One bit of scrap: a plate in the trim colour or bare metal, a bolt, or a lump of gunmetal.
func _scrap(i: int, trim: Color) -> RigidBody3D:
	var body := _body("scrap")
	var mi := MeshInstance3D.new()
	var look := StandardMaterial3D.new()
	look.metallic = 0.6
	look.roughness = 0.45
	var size: Vector3
	match i % 4:
		0, 1:   # a plate
			var plate := BoxMesh.new()
			plate.size = Vector3(randf_range(0.07, 0.16), randf_range(0.012, 0.022), randf_range(0.06, 0.13))
			mi.mesh = plate
			size = plate.size
			look.albedo_color = trim if i % 4 == 0 else GREY
			look.metallic = 0.3 if i % 4 == 0 else 0.6
		2:   # a bolt
			var bolt := CylinderMesh.new()
			bolt.top_radius = randf_range(0.014, 0.022)
			bolt.bottom_radius = bolt.top_radius
			bolt.height = randf_range(0.06, 0.11)
			bolt.radial_segments = 6
			bolt.rings = 1
			mi.mesh = bolt
			size = Vector3(bolt.top_radius * 2.0, bolt.height, bolt.top_radius * 2.0)
			look.albedo_color = GREY.lightened(0.25)
			look.metallic = 0.8
			look.roughness = 0.3
		_:   # a lump
			var lump := BoxMesh.new()
			lump.size = Vector3(randf_range(0.05, 0.09), randf_range(0.04, 0.08), randf_range(0.05, 0.09))
			mi.mesh = lump
			size = lump.size
			look.albedo_color = DARK
	mi.set_surface_override_material(0, look)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size.max(Vector3.ONE * 0.02)
	shape.shape = b
	body.add_child(shape)
	body.mass = 0.15
	return body


## Sets every body flying: away from the blast, or along the blow, spread out from the
## middle of the body, with the robot's own speed, and tumbling.
func _throw(bodies: Array, p: Player, fx: Dictionary) -> void:
	var push: Vector3 = fx.get("push", Vector3.ZERO)
	var dir: Vector3 = fx.get("dir", Vector3.ZERO)
	var blast := fx.has("at")
	var at: Vector3 = fx.get("at", Vector3.ZERO)
	var way := dir if dir.length_squared() > 0.01 else (push.normalized() if push.length_squared() > 0.01 else Vector3.ZERO)
	var strength := clampf(push.length(), BLAST_SPEED[0], BLAST_SPEED[1])
	var carried := p.latest_velocity().limit_length(MAX_SPEED * 0.6)
	var mid := Vector3.ZERO
	for body in bodies:
		mid += (body as Node3D).position
	mid /= bodies.size()
	for body in bodies:
		var b := body as RigidBody3D
		var out := b.position - mid
		out = out.normalized() if out.length_squared() > 0.0001 else Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized()
		var scrap := String(b.name).begins_with("scrap")
		var v: Vector3
		if blast:
			var away := b.position - at
			away = away.normalized() if away.length_squared() > 0.0001 else out
			v = away * strength * randf_range(0.75, 1.25) + out * randf_range(1.0, 3.0)
		else:
			v = way * strength * randf_range(0.6, 1.1) + out * randf_range(2.0, 4.5)
		v += Vector3.UP * randf_range(2.0, 4.5)
		if scrap:
			v = v * randf_range(1.0, 1.4) + Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2))
		b.linear_velocity = (v + carried).limit_length(MAX_SPEED)
		b.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * SPIN * (1.5 if scrap else 1.0)


## A burst of sparks and smoke where the body was, smoke trailing from a few pieces, and
## a crunch of metal (unless `loud` is off: a replay plays its own). `mid`: the middle
## of the body. (A blast already made its own fireball.)
func effects(mid: Vector3, fx: Dictionary, loud: bool = true) -> void:
	var way: Vector3 = fx.get("dir", Vector3.ZERO)
	if fx.has("at"):
		way = mid - (fx.at as Vector3)
	way.y = 0.0
	way = way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD
	if loud:
		Sound.play_at("heavy_hit", mid, "body", 0.0, 0.05)
		var rattle := Sound.play_at("break_concrete", mid, "body", -3.0, 0.05)
		if rattle:
			rattle.pitch_scale *= 1.35   # chunks of metal, not stone
	if DisplayServer.get_name() == "headless":
		return
	var parent := get_parent()
	if not fx.has("at"):
		ShotFx.explosion(parent, mid, 0.7)   # popped by a bullet or a blade: a small blast of its own
	MeleeFx._sparks(parent, mid, way, Color(1.0, 0.8, 0.45), 1.0)
	MeleeFx._sparks(parent, mid, -way, _edge.lerp(Color.WHITE, 0.5), 0.8)
	for body in get_children():
		if String((body as Node).name) in SMOKING:
			_smoke(body)


## Dark smoke trailing from `body` as it flies, for SMOKE_TIME.
func _smoke(body: Node3D) -> void:
	var fx := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.09
	puff.height = 0.18
	puff.radial_segments = 6
	puff.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	puff.material = mat
	fx.mesh = puff
	fx.amount = 28
	fx.lifetime = 0.9
	fx.local_coords = false   # the smoke stays behind as the piece flies on
	fx.direction = Vector3.UP
	fx.spread = 40.0
	fx.gravity = Vector3(0, 0.8, 0)
	fx.initial_velocity_min = 0.2
	fx.initial_velocity_max = 0.7
	fx.scale_amount_min = 0.8
	fx.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.22, 0.21, 0.2, 0.7))
	fade.set_color(1, Color(0.35, 0.34, 0.33, 0.0))
	fx.color_ramp = fade
	var grow := Curve.new()
	grow.max_value = 2.0
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.6))
	fx.scale_amount_curve = grow
	body.add_child(fx)
	fx.emitting = true
	var tw := fx.create_tween()
	tw.tween_interval(SMOKE_TIME)
	tw.tween_callback(func(): fx.emitting = false)
	tw.tween_interval(fx.lifetime + 0.1)
	tw.tween_callback(fx.queue_free)


func _process(delta: float) -> void:
	_age += delta
	var burn := _age - (Remains.LIFETIME - Remains.DISSOLVE_TIME)
	if burn < 0.0:
		return
	if _dissolve == null:
		_dissolve = Dissolve.prepare(self, _edge)
	_dissolve.set_progress(burn / Remains.DISSOLVE_TIME)
	if _age >= Remains.LIFETIME:
		queue_free()
