class_name KarateGear
extends RefCounted
## Karate's fighting gear and its aura (2026-11-21). The fists' own wraps are a melee
## weapon like any other (MeleeModel._wraps, on the grip bones); this adds the rest:
## an armoured bracer on each forearm, a guard down each shin and a plate over each
## instep, all in the robots' factory look with a band of the player's glow, and the
## aura: a thin see-through shell of flame-like energy in the player's trim colour,
## rising off the whole body, with sparks drifting up out of it and, at a full wind-up
## on the ground, dust and grit lifting off the floor round the feet.
##
## Every piece is measured to the body it is on (the bones' own vertices, in the bone's
## space), so the gear fits every robot and every Character Creator body, creature legs
## and all, and the aura is the body's own mesh pushed out along smoothed normals, so it
## follows each body's shape. Built only while Karate is out (RobotModel builds it with
## the weapon), so it is never shown with any other weapon.
##
## The aura never hides anyone: it is added light, brightest at the body's outline and
## clear across the middle, and it is drawn with the depth test like anything else, so it
## never shows through a wall. It is in the trim colour, never a damage red of its own.
##
## In first person (the arms' model, viewmodel) only the bracers and the aura on the arms
## are built: the rest of the body is out of view, and ViewModel adds the pulse round the
## edges of the screen (see edge_pulse()).

const AURA_SHADER := "res://game/combat/karate_aura.gdshader"
const EDGE_SHADER := "res://game/combat/karate_edge.gdshader"
const ARMS := ["forearm_l", "forearm_r"]
const LEGS := ["shin_l", "shin_r", "foot_l", "foot_r"]
const MEASURED := ["forearm_l", "forearm_r", "hand_l", "hand_r", "shin_l", "shin_r", "foot_l", "foot_r"]
## How the aura looks at rest, wound right up, and flaring on a blow (see set_level).
const AURA_REST := 0.14
const AURA_THICK := 0.022      ## how far the shell stands off the body at rest (m)...
const AURA_THICK_FULL := 0.05  ## ...and wound right up
const SPARKS := 26             ## sparks in the air at once at most (High/Medium)
const SPARKS_LOW := 10         ## ...and on Low
const GRIT := 18
const FP_AURA := 0.4          ## the aura on your own arms in first person is this bright, against everyone else's view of it
const IGNITE := 0.45          ## seconds the aura's flare takes on taking Karate out

static var _measures := {}     # mesh -> {bone: AABB in the bone's space}
static var _aura_meshes := {}  # mesh -> the same mesh with smoothed normals, for the aura


## Adds the gear and aura to `model` (a RobotModel). Returns the node holding them.
static func attach(model: RobotModel, trim: Color, viewmodel: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "KarateGear"
	model.add_child(root)
	var sizes := measure(model)
	var lit := []
	for bone in (ARMS if viewmodel else ARMS + LEGS):
		if model.skeleton.find_bone(bone) < 0 or not sizes.has(bone):
			continue
		var at := BoneAttachment3D.new()
		at.name = "Gear_" + bone
		at.bone_name = bone
		model.skeleton.add_child(at)
		var holder := Node3D.new()
		at.add_child(holder)
		for part in _piece(bone, sizes):
			var mi := MeshInstance3D.new()
			mi.mesh = part[0]
			mi.material_override = MeleeModel.material(part[2], trim, viewmodel)
			if part[2] == "edge":
				lit.append(mi.material_override)
			if viewmodel:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.extra_cull_margin = 10.0
			mi.set_meta("leg", bone in LEGS)
			holder.add_child(mi)
		root.set_meta("attach_" + bone, at)
	# The aura: the body's own mesh, pushed out and lit, twice: a close flickering shell,
	# and outer flames that grow with the charge.
	var shells := []
	for outer in ([false] if viewmodel else [false, true]):   # (in first person: only the close shell, the flames would fill the view)
		var shell := MeshInstance3D.new()
		shell.name = "AuraOuter" if outer else "Aura"
		shell.mesh = aura_mesh(model)
		shell.skin = model.mesh.skin
		var mat := ShaderMaterial.new()
		mat.shader = load(AURA_SHADER)
		mat.set_shader_parameter("color", trim)
		mat.set_shader_parameter("first_person", viewmodel)
		mat.set_shader_parameter("outer", outer)
		mat.render_priority = 1 if outer else 0
		shell.material_override = mat
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.extra_cull_margin = 2.0
		model.skeleton.add_child(shell)
		shell.skeleton = shell.get_path_to(model.skeleton)
		shells.append(shell)
	root.set_meta("shells", shells)
	root.set_meta("lit", lit)
	root.set_meta("trim", trim)
	root.set_meta("level", 0.0)
	root.set_meta("phase", 0.0)
	if not viewmodel:
		root.set_meta("sparks", _sparks(root, trim, _low()))
		root.set_meta("grit", _grit(root, trim))
	return root


## Sets how strongly the aura burns. `glow` is the swing's (MeleeSwing.glow(): 1 at rest,
## up to 2.6 wound right up with a tremble on top, and a flare on a blow); `draw` is how
## far the ignition flare on taking Karate out has got (1 = over); `on_floor`: grit
## lifts only off the floor; `alive`: a dead robot's aura goes out.
static func set_level(gear: Node3D, glow: float, draw: float, delta: float, on_floor: bool = true, alive: bool = true) -> void:
	if gear == null:
		return
	var want := clampf((glow - 1.0) / 1.6, 0.0, 1.6)   # 0 at rest, 1 wound right up, more on a flare
	var ignite := 0.0
	if draw < 1.0:
		ignite = sin(clampf(draw, 0.0, 1.0) * PI) * 1.3   # taking Karate out: the aura ignites with a flare
	want = maxf(want, ignite)
	# A blow that landed flares it (see flare()), fading quickly.
	var flared: float = gear.get_meta("flare", 0.0)
	want = maxf(want, flared * 1.5)
	gear.set_meta("flare", move_toward(flared, 0.0, delta * 3.0))
	if not alive:
		want = -1.0
	var level: float = gear.get_meta("level", 0.0)
	# Quick to flare up, slower to settle back down.
	level = move_toward(level, want, delta * (9.0 if want > level else 2.5))
	gear.set_meta("level", level)
	# The pulse: a slow breath at rest, quickening as the charge builds.
	var rate := lerpf(1.1, 4.5, clampf(level, 0.0, 1.0))
	var phase: float = gear.get_meta("phase", 0.0) + delta * rate * TAU
	gear.set_meta("phase", fmod(phase, TAU * 64.0))
	var beat := pow(0.5 + 0.5 * sin(phase), 3.0)
	var shown := 0.0 if level < 0.0 else AURA_REST + level * 0.8
	for shell in gear.get_meta("shells"):
		var mat: ShaderMaterial = (shell as MeshInstance3D).material_override
		var near: bool = mat.get_shader_parameter("first_person")   # your own arms, right in front of you: kept thin and faint
		mat.set_shader_parameter("level", maxf(level, 0.0) * (0.4 if near else 1.0))
		mat.set_shader_parameter("strength", shown * (0.85 + 0.3 * beat) * (FP_AURA if near else 1.0))
		mat.set_shader_parameter("thick", lerpf(AURA_THICK, AURA_THICK_FULL, clampf(level, 0.0, 1.0)) * (0.92 + 0.16 * beat) * (0.45 if near else 1.0))
		shell.visible = level > -0.99 and (not mat.get_shader_parameter("outer") or level > 0.05)
	var trim: Color = gear.get_meta("trim")
	for m in gear.get_meta("lit", []):
		var energy := MeleeModel.GLOW_ENERGY * (0.0 if level < 0.0 else 1.0 + 1.4 * level + 0.4 * beat)
		if m is ShaderMaterial:
			m.set_shader_parameter("emission", trim * energy)
		else:
			(m as StandardMaterial3D).emission_energy_multiplier = energy
	var sparks: GPUParticles3D = gear.get_meta("sparks") if gear.has_meta("sparks") else null
	if sparks:
		sparks.emitting = level > 0.0
		sparks.amount_ratio = clampf(0.25 + 0.75 * level, 0.0, 1.0)
		sparks.speed_scale = 0.8 + 0.8 * clampf(level, 0.0, 1.0)
	var grit: GPUParticles3D = gear.get_meta("grit") if gear.has_meta("grit") else null
	if grit:
		grit.emitting = on_floor and level > 0.9 and alive


## A blow landed: the aura flares up (`amount` 0..1) and settles back.
static func flare(gear: Node3D, amount: float) -> void:
	if gear:
		gear.set_meta("flare", maxf(gear.get_meta("flare", 0.0), amount))


## Puts every piece of the gear and the aura on a render layer (RobotModel.set_layer).
## `also`: another layer for the legs' pieces (your own body in first person, which still
## shows your legs), 0 for none.
static func set_layers(gear: Node3D, layers: int, also: int = 0) -> void:
	if gear == null:
		return
	var model := gear.get_parent() as RobotModel
	for c in model.skeleton.get_children():
		if c is BoneAttachment3D and str(c.name).begins_with("Gear_"):
			for mi in c.get_child(0).get_children():
				mi.layers = layers | (also if mi.get_meta("leg", false) else 0)
	for shell in gear.get_meta("shells"):
		(shell as VisualInstance3D).layers = layers
	for key in ["sparks", "grit"]:
		var p: GPUParticles3D = gear.get_meta(key) if gear.has_meta(key) else null
		if p:
			p.layers = layers


## A full-screen pulse of the trim colour round the edges of your view (first person):
## add it to a CanvasLayer; set_edge() drives it. Never across the middle.
static func edge_pulse(trim: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "KarateEdge"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(EDGE_SHADER)
	mat.set_shader_parameter("color", trim)
	mat.set_shader_parameter("strength", 0.0)
	rect.material = mat
	return rect


static func set_edge(rect: ColorRect, gear: Node3D) -> void:
	if rect == null:
		return
	var level: float = gear.get_meta("level", 0.0) if gear else 0.0
	var phase: float = gear.get_meta("phase", 0.0) if gear else 0.0
	var beat := pow(0.5 + 0.5 * sin(phase), 3.0)
	var s := clampf(level, 0.0, 1.3) * (0.7 + 0.3 * beat) if gear else 0.0
	(rect.material as ShaderMaterial).set_shader_parameter("strength", s)
	rect.visible = s > 0.01


# ---------------------------------------------------------------------------
# Measuring the body

## Each MEASURED bone's own vertices (those it moves most), as a box in the bone's space.
static func measure(model: RobotModel) -> Dictionary:
	var mesh: Mesh = model.mesh.mesh
	if _measures.has(mesh):
		return _measures[mesh]
	var skin := model.mesh.skin
	var names := PackedStringArray()
	for b in skin.get_bind_count():
		var n := String(skin.get_bind_name(b))
		if n == "":
			n = model.rig.bone_names[skin.get_bind_bone(b)]
		names.append(n)
	var out := {}
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat and "." in mat.resource_name:
			continue   # a gun
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty():
			continue
		var per := bones.size() / verts.size()
		for v in verts.size():
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			var b := bones[v * per + best]
			var bone := names[b]
			if not bone in MEASURED:
				continue
			var p := skin.get_bind_pose(b) * verts[v]
			out[bone] = (out[bone] as AABB).expand(p) if out.has(bone) else AABB(p, Vector3.ZERO)
	_measures[mesh] = out
	return out


## The body's mesh with its normals smoothed across the facets (so the aura pushed out
## along them stays whole instead of splitting at every edge).
static func aura_mesh(model: RobotModel) -> Mesh:
	var mesh: Mesh = model.mesh.mesh
	if _aura_meshes.has(mesh):
		return _aura_meshes[mesh]
	var skin := model.mesh.skin
	var dimmed := {}   # skin bind -> true: the hands and fingers (dimmed, see karate_aura.gdshader)
	for b in skin.get_bind_count():
		var n := String(skin.get_bind_name(b))
		if n == "":
			n = model.rig.bone_names[skin.get_bind_bone(b)]
		if n.begins_with("hand") or n.begins_with("finger") or n.begins_with("thumb") or n.begins_with("pistol"):
			dimmed[b] = true
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat and ("." in mat.resource_name or mat.resource_name.to_lower().contains("visor")):
			continue   # the gun, and the visor (it glows already)
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(verts.size(), 1)
		var sum := {}
		for v in verts.size():
			var key := (verts[v] * 200.0).round()
			sum[key] = sum.get(key, Vector3.ZERO) + normals[v]
		var smooth := PackedVector3Array()
		smooth.resize(verts.size())
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for v in verts.size():
			var n: Vector3 = sum[(verts[v] * 200.0).round()]
			smooth[v] = n.normalized() if n.length_squared() > 1e-8 else normals[v]
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			colors[v] = Color(0.3, 1, 1) if per > 0 and dimmed.has(bones[v * per + best]) else Color.WHITE
		arrays[Mesh.ARRAY_NORMAL] = smooth
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_TEX_UV] = null
		arrays[Mesh.ARRAY_TEX_UV2] = null
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_aura_meshes[mesh] = out
	return out


# ---------------------------------------------------------------------------
# The pieces, in each bone's own space (+X right, +Y up, -Z forward at rest; the arm
# and shin hang down -Y from the bone, the foot reaches forward -Z from the ankle)

static func _piece(bone: String, sizes: Dictionary) -> Array:
	var box: AABB = sizes[bone]
	var side := -1.0 if bone.ends_with("_l") else 1.0
	var k := MeleeKit.new()
	match bone.trim_suffix("_l").trim_suffix("_r"):
		"forearm":
			_bracer(k, box, side)
		"shin":
			_shin_guard(k, box)
		"foot":
			_foot_plate(k, box)
	return k.parts()


## A bracer round the wrist end of the forearm: an eight-sided armoured cuff, a raised
## plate on the outside of the arm with two ridges, and a glowing band round the wrist.
static func _bracer(k: MeleeKit, box: AABB, side: float) -> void:
	var c := box.get_center()
	var rx := box.size.x * 0.5 + 0.012
	var rz := box.size.z * 0.5 + 0.012
	var r := maxf(rx, rz)
	var squash := Vector2(rx / r, rz / r)
	var bottom := box.position.y + box.size.y * 0.1     # the wrist end
	var top := box.position.y + box.size.y * 0.72
	var xf := Transform3D(Basis.IDENTITY, Vector3(c.x, 0.0, c.z))
	k.bar("dark", [[bottom, r * 1.08], [bottom + 0.02, r * 1.12], [top - 0.02, r * 1.02], [top, r * 0.96]], 8, squash, xf)
	k.bar("edge", [[bottom + 0.028, r * 1.14], [bottom + 0.042, r * 1.14]], 8, squash, xf)
	k.bar("plate", [[bottom + 0.05, r * 1.13], [top - 0.012, r * 1.06]], 8, squash * Vector2(0.98, 0.98), xf)
	# The raised plate on the outside of the arm (away from the body).
	var out_x := c.x + side * (rx * 1.08)
	var h := (top - bottom) * 0.42
	var mid := (top + bottom) * 0.5 + 0.01
	k.plate("dark", MeleeKit.cut_rect(rz * 0.62, h, 0.012), -0.007, 0.007,
		Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(side, 0, 0)), Vector3(out_x, mid, c.z)))
	for y in [mid - h * 0.4, mid + h * 0.15]:
		k.box("detail", Vector3(out_x + side * 0.008, y, c.z), Vector3(0.008, 0.012, rz * 1.0))


## A guard down the front of the shin: a knee cap at the top, armour plates down the
## front with a glowing strip between them, and straps round the back.
static func _shin_guard(k: MeleeKit, box: AABB) -> void:
	var c := box.get_center()
	var hx := box.size.x * 0.5
	var front := box.position.z - 0.006            # just in front of the shin (-Z)
	var top := box.position.y + box.size.y * 0.92
	var bottom := box.position.y + box.size.y * 0.16
	var w := hx * 1.12
	var face := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3(c.x, 0, front))
	# Two long plates either side of the glowing strip, the outer edges swept back.
	var upper := PackedVector2Array([Vector2(-w, bottom + 0.03), Vector2(-0.008, bottom), Vector2(-0.008, top - 0.05),
		Vector2(-w * 0.9, top - 0.07)])
	k.plate("plate", upper, -0.016, 0.0, face)
	var other := PackedVector2Array()
	for p in upper:
		other.append(Vector2(-p.x, p.y))
	k.plate("plate", other, -0.016, 0.0, face)
	k.plate("edge", PackedVector2Array([Vector2(-0.007, bottom + 0.01), Vector2(0.007, bottom + 0.01),
		Vector2(0.007, top - 0.055), Vector2(-0.007, top - 0.055)]), -0.012, -0.002, face)
	# Backing, a little wider, so the plates sit on something.
	k.plate("dark", MeleeKit.cut_rect(w * 1.04, (top - bottom) * 0.5, 0.02, Vector2(0, (top + bottom) * 0.5)), 0.0, 0.01, face)
	# The knee cap.
	k.plate("dark", MeleeKit.cut_rect(w * 0.8, 0.045, 0.018, Vector2(0, top - 0.02)), -0.03, -0.004, face)
	k.plate("plate", MeleeKit.cut_rect(w * 0.6, 0.032, 0.012, Vector2(0, top - 0.02)), -0.038, -0.03, face)
	# Straps round the back of the calf.
	var depth := box.size.z
	for y in [bottom + 0.05, (top + bottom) * 0.5]:
		k.box("detail", Vector3(c.x, y, front + depth * 0.5 + 0.004), Vector3(hx * 2.0 + 0.004, 0.014, depth + 0.004))


## A plate over the instep: armour shaped to the top of the foot with a glowing line
## across the toes.
static func _foot_plate(k: MeleeKit, box: AABB) -> void:
	var c := box.get_center()
	var hx := box.size.x * 0.5 + 0.006
	var top := box.position.y + box.size.y + 0.004
	var toe := box.position.z + 0.02
	var heel := minf(box.position.z + box.size.z * 0.62, -0.01)
	var lay := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(c.x, top, 0))
	k.plate("plate", PackedVector2Array([Vector2(-hx * 0.9, toe + 0.03), Vector2(-hx * 0.6, toe), Vector2(hx * 0.6, toe),
		Vector2(hx * 0.9, toe + 0.03), Vector2(hx, heel), Vector2(-hx, heel)]), -0.014, 0.0, lay)
	k.plate("edge", PackedVector2Array([Vector2(-hx * 0.62, toe + 0.012), Vector2(hx * 0.62, toe + 0.012),
		Vector2(hx * 0.66, toe + 0.026), Vector2(-hx * 0.66, toe + 0.026)]), -0.019, -0.012, lay)
	k.plate("dark", MeleeKit.cut_rect(hx * 0.7, (heel - toe) * 0.3, 0.01, Vector2(0, heel - (heel - toe) * 0.32)), -0.02, -0.013, lay)


# ---------------------------------------------------------------------------
# Particles

static func _low() -> bool:
	var s := Engine.get_main_loop() as SceneTree
	var settings := s.root.get_node_or_null("Settings") if s else null
	if settings == null:
		return false
	return not bool(settings.call("graphics").get("sky_motion", true))   # (Low turns the moving sky off: the same budget)


## Sparks drifting up out of the aura.
static func _sparks(root: Node3D, trim: Color, low: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "AuraSparks"
	p.amount = SPARKS_LOW if low else SPARKS
	p.lifetime = 0.9
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 3.5, 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.28, 0.75, 0.2)
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.8, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.2))
	fade.add_point(Vector2(0.2, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = fade
	pm.scale_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.055)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = trim.lightened(0.35)
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0.9, 0)
	p.emitting = false
	root.add_child(p)
	return p


## Grit and dust lifting off the floor round the feet at a full wind-up.
static func _grit(root: Node3D, trim: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "AuraGrit"
	p.amount = GRIT
	p.lifetime = 1.1
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 3, 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.5
	pm.emission_ring_inner_radius = 0.18
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.ZERO
	pm.angular_velocity_min = -160.0
	pm.angular_velocity_max = 160.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.15, 1.0))
	fade.add_point(Vector2(0.8, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = fade
	pm.scale_curve = ct
	p.process_material = pm
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.022, 0.018, 0.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.4, 0.38)
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = trim
	m.emission_energy_multiplier = 0.25   # lit from underneath by the aura
	chunk.material = m
	p.draw_pass_1 = chunk
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0.03, 0)
	p.emitting = false
	root.add_child(p)
	return p


# ---------------------------------------------------------------------------
# Afterimages

const GHOST_EVERY := 0.035   ## seconds between afterimages of a spinning blow
const GHOST_LIFE := 0.24     ## how long each one hangs in the air, fading
const GHOST_SHADER := "res://game/combat/karate_ghost.gdshader"

## An afterimage of `model` as it is posed right now: its body (the aura's smoothed mesh)
## on a still copy of its skeleton, left where it is in the world and fading out in the
## trim colour. Never solid: added light, brightest at the outline.
static func ghost(model: RobotModel, parent: Node = null) -> void:
	var gear := model.karate_gear
	if gear == null or not model.is_inside_tree():
		return
	if parent == null or not is_instance_valid(parent):
		parent = model.get_tree().current_scene if model.get_tree().current_scene else model.get_tree().root
	var src := model.skeleton
	var sk := Skeleton3D.new()
	for i in src.get_bone_count():
		sk.add_bone(src.get_bone_name(i))
	for i in src.get_bone_count():
		sk.set_bone_parent(i, src.get_bone_parent(i))
		sk.set_bone_rest(i, src.get_bone_rest(i))
		sk.set_bone_pose(i, src.get_bone_pose(i))
	var root := Node3D.new()
	root.name = "KarateGhost"
	parent.add_child(root)
	root.global_transform = src.global_transform
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.mesh = aura_mesh(model)
	mi.skin = model.mesh.skin
	var mat := ShaderMaterial.new()
	mat.shader = load(GHOST_SHADER)
	mat.set_shader_parameter("color", gear.get_meta("trim"))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = model.mesh.layers
	sk.add_child(mi)
	mi.skeleton = mi.get_path_to(sk)
	var tw := root.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, GHOST_LIFE)
	tw.tween_callback(root.queue_free)
