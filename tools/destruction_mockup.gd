extends SceneTree
## CONCEPT ONLY: stills of the proposed destruction model, staged by hand on the
## Construction Site. Nothing here is game code; it poses geometry and takes pictures.
##
##   godot --path . --script tools/destruction_mockup.gd -- --scene=NAME --stage=N --out=FILE.png
##       [--size=1600x900] [--cam=x,y,z:lx,ly,lz:fov]

var map: MapRoot
var cam: Camera3D
var extras: Node3D
var rng := RandomNumberGenerator.new()
var scene := "holes"
var stage := 0
var out := "mock.png"
var cam_override := ""
var _wait := 8
var _plain := {}
var _puff_tex: Texture2D
var _post: Array = []   # callables run after build
var sim := false         # a scene that runs physics and films it (out = a folder for the frames)
var measure := false     # ...or only times it (no pictures)
var sim_seconds := 9.0
var variant := 0


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg.begins_with("--stage="):
			stage = int(arg.substr(8))
		elif arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg == "--measure":
			measure = true
		elif arg.begins_with("--seconds="):
			sim_seconds = float(arg.substr(10))
		elif arg.begins_with("--variant="):
			variant = int(arg.substr(10))
		elif arg.begins_with("--cam="):
			cam_override = arg.substr(6)
		elif arg.begins_with("--size="):
			size = Vector2i(int(arg.substr(7).get_slice("x", 0)), int(arg.substr(7).get_slice("x", 1)))
	rng.seed = 7
	map = Maps.make("construction_site")
	root.size = size
	DisplayServer.window_set_size(size)
	root.add_child(map)
	extras = Node3D.new()
	cam = Camera3D.new()
	cam.far = 600.0
	cam.near = 0.05
	call("scene_" + scene)
	map.build()
	MapMesher._shade = map.face_shade
	MapMesher._shade_basis = Basis()
	root.add_child(extras)
	for c: Callable in _post:
		c.call()
	root.add_child(cam)
	cam.make_current()
	if cam_override != "":
		var p := cam_override.split(":")
		look(_v(p[0]), _v(p[1]), float(p[2]) if p.size() > 2 else 60.0)


func _process(delta: float) -> bool:
	if sim:
		return _sim_process(delta)
	if _wait > 0:
		_wait -= 1
		return false
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	return true


func _v(text: String) -> Vector3:
	var c := text.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	cam.position = from
	cam.look_at_from_position(from, at)
	cam.fov = fov


# ---------------------------------------------------------------- map surgery

func xf_of(node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != map:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func shown(node: Node) -> bool:
	var p := node
	while p != null and p != map:
		if p is Node3D and not (p as Node3D).visible:
			return false
		p = p.get_parent()
	return true


func blocks() -> Array:
	var list := []
	for n in map.find_children("*", "", true, false):
		if n is MapBlock and shown(n):
			list.append(n)
	return list


func aligned(b: Basis) -> bool:
	return b.is_equal_approx(Basis())


## Cuts `region` out of every axis-aligned box block that reaches into it (the parts
## outside stay, as new blocks); anything else whose middle is inside is hidden.
## `only` = path prefixes to touch ([] = everything).
func cut_region(region: AABB, only: Array = [], skip: Array = []) -> void:
	for b: MapBlock in blocks():
		var path := str(map.get_path_to(b))
		if not only.is_empty() and not only.any(func(p): return path.begins_with(p)):
			continue
		if skip.any(func(p): return path.begins_with(p)):
			continue
		var xf := xf_of(b)
		if b.shape == MapBlock.Shape.BOX and aligned(xf.basis):
			var box := AABB(xf.origin - b.size * 0.5, b.size)
			if not box.intersects(region):
				continue
			b.visible = false
			for rest: AABB in subtract(box, region):
				if rest.size.x < 0.004 or rest.size.y < 0.004 or rest.size.z < 0.004:
					continue
				var copy := b.duplicate() as MapBlock
				for c in copy.get_children():
					copy.remove_child(c)
					c.free()
				copy.size = rest.size
				copy.transform = Transform3D(Basis(), rest.get_center())
				copy.visible = true
				map.add_child(copy)
		elif region.has_point(xf.origin):
			b.visible = false


func subtract(box: AABB, cut: AABB) -> Array:
	var rest := []
	var lo := box.position
	var hi := box.end
	for a in 3:
		if cut.position[a] > lo[a]:
			var e := hi
			e[a] = minf(cut.position[a], hi[a])
			rest.append(AABB(lo, e - lo))
			lo[a] = e[a]
		if cut.end[a] < hi[a]:
			var s := lo
			s[a] = maxf(cut.end[a], lo[a])
			rest.append(AABB(s, hi - s))
			hi[a] = s[a]
	return rest


func hide_near(point: Vector3, radius: float, prefixes: Array) -> void:
	for b: MapBlock in blocks():
		var path := str(map.get_path_to(b))
		if prefixes.any(func(p): return path.begins_with(p)) and xf_of(b).origin.distance_to(point) < radius:
			b.visible = false


## A block added to the map before it is built (so it is drawn like any other).
func blk(kind: String, pos: Vector3, size: Vector3, euler_deg: Vector3 = Vector3.ZERO, shape: int = 0, tint: Color = Color.WHITE) -> MapBlock:
	var b := MapBlock.new()
	b.shape = shape
	b.size = size
	b.kind = kind
	b.tint = tint
	b.transform = Transform3D(Basis.from_euler(euler_deg * PI / 180.0), pos)
	map.add_child(b)
	return b


# ---------------------------------------------------------------- loose geometry

func plain(kind: String, mul: float = 1.0) -> StandardMaterial3D:
	var key := "%s %.2f" % [kind, mul]
	if not _plain.has(key):
		var m := StandardMaterial3D.new()
		var c: Color = map.palette.colors.get(kind, Color(0.7, 0.7, 0.7))
		m.albedo_color = Color(c.r * mul, c.g * mul, c.b * mul)
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.95
		_plain[key] = m
	return _plain[key]


func flat(color: Color, unshaded := true, no_depth := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = no_depth
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A convex lump: the hull of `pts` (its own frame), placed by `xf`. `patterned` draws
## the kind's own surface pattern, measured from the lump (a slab's joints go with it).
func hull(kind: String, pts: PackedVector3Array, xf: Transform3D = Transform3D(), mul: float = 1.0, patterned := false, tint := Color.WHITE, moves := false) -> MeshInstance3D:
	var buf := [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	MapMesher._shade_basis = xf.basis.orthonormalized()
	for face in MapMesher.hull_faces(pts):
		MapMesher._flat(buf, Transform3D(), face[1], face[0], tint)
	MapMesher._shade_basis = Basis()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buf[0]
	arrays[Mesh.ARRAY_NORMAL] = buf[1]
	arrays[Mesh.ARRAY_COLOR] = buf[2]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	if patterned:
		mi.mesh = mesh if xf == Transform3D() and not moves else MapMesher.riding(mesh)
		mi.material_override = map.material_for(kind)
	else:
		mi.mesh = mesh
		mi.material_override = plain(kind, mul)
	mi.transform = xf
	extras.add_child(mi)
	return mi


static func box_pts(size: Vector3, center: Vector3 = Vector3.ZERO) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in 8:
		pts.append(center + Vector3(size.x * (0.5 if i & 1 else -0.5), size.y * (0.5 if i & 2 else -0.5), size.z * (0.5 if i & 4 else -0.5)))
	return pts


## The part of the convex lump `pts` on the side of `plane` its normal points away from.
func clip(pts: PackedVector3Array, plane: Plane) -> PackedVector3Array:
	var keep := PackedVector3Array()
	var faces := MapMesher.hull_faces(pts)
	for p in pts:
		if plane.distance_to(p) <= 0.0:
			keep.append(p)
	for face in faces:
		var ring: Array = face[1]
		for i in ring.size():
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % ring.size()]
			var da := plane.distance_to(a)
			var db := plane.distance_to(b)
			if (da < 0.0) != (db < 0.0) and absf(da - db) > 1e-6:
				var hit := a.lerp(b, da / (da - db))
				var dup := false
				for k in keep:
					if k.distance_to(hit) < 0.001:
						dup = true
						break
				if not dup:
					keep.append(hit)
	return keep


## A rough lump about `size` across: a box with corners knocked off.
func lump_pts(size: Vector3, cuts: int = 4) -> PackedVector3Array:
	var pts := box_pts(size)
	for i in cuts:
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var reach := absf(n.x) * size.x * 0.5 + absf(n.y) * size.y * 0.5 + absf(n.z) * size.z * 0.5
		var cut := clip(pts, Plane(n, reach * rng.randf_range(0.45, 0.8)))
		if cut.size() >= 4:
			pts = cut
	return pts


func rand_basis(max_tilt: float = PI) -> Basis:
	return Basis.from_euler(Vector3(rng.randf_range(-max_tilt, max_tilt), rng.randf_range(-PI, PI), rng.randf_range(-max_tilt, max_tilt)))


func chunk(kind: String, pos: Vector3, size: Vector3, mul: float = 0.9, tilt: float = PI) -> MeshInstance3D:
	return hull(kind, lump_pts(size), Transform3D(rand_basis(tilt), pos), mul * rng.randf_range(0.9, 1.05))


## A heap of rubble on the ground at `at` (its foot), `radius` across and `height` high.
func rubble(kind: String, at: Vector3, radius: float, height: float, count: int, big: float = 0.5, squash := Vector2.ONE) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := radius * pow(rng.randf(), 0.75)
		var k := 1.0 - r / radius
		var s := lerpf(0.08, big, pow(rng.randf(), 2.2) * (0.35 + 0.65 * k))
		var y := height * k * k * rng.randf_range(0.2, 1.0) + s * 0.3
		var p := at + Vector3(cos(a) * r * squash.x, y, sin(a) * r * squash.y)
		chunk(kind, p, Vector3(s * rng.randf_range(0.7, 1.5), s * rng.randf_range(0.4, 0.9), s * rng.randf_range(0.7, 1.3)), rng.randf_range(0.72, 0.98), 0.5 if y < 0.25 else PI)


## Fine grit: lots of tiny boxes in one mesh.
func grit(kind: String, at: Vector3, radius: float, count: int, squash := Vector2.ONE, mul := 0.85) -> void:
	var pieces := []
	for i in count:
		var a := rng.randf() * TAU
		var r := radius * pow(rng.randf(), 0.6)
		var s := rng.randf_range(0.02, 0.07)
		pieces.append({"xf": Transform3D(rand_basis(), at + Vector3(cos(a) * r * squash.x, s * 0.4, sin(a) * r * squash.y)),
			"size": Vector3(s, s * 0.7, s * 1.3), "kind": kind, "shape": "box", "tint": Color.WHITE * rng.randf_range(0.8, 1.05)})
	var meshes := MapMesher.build(pieces, map.face_shade)
	var mi := MeshInstance3D.new()
	mi.mesh = meshes[kind]
	mi.material_override = plain(kind, mul)
	extras.add_child(mi)


func puff_texture() -> Texture2D:
	if _puff_tex == null:
		var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.frequency = 0.045
		noise.seed = 3
		for y in 96:
			for x in 96:
				var d := Vector2(x - 47.5, y - 47.5).length() / 47.5
				var n := 0.75 + 0.5 * noise.get_noise_2d(x, y)
				var a := clampf(1.0 - d * (0.85 + 0.3 * n), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * n))
		_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


## A soft cloud of dust: overlapping see-through puffs facing the camera.
func dust(at: Vector3, spread: Vector3, count: int, size: float, color: Color) -> void:
	for i in count:
		var m := StandardMaterial3D.new()
		var shade := rng.randf_range(0.88, 1.06)
		m.albedo_color = Color(color.r * shade, color.g * shade, color.b * shade, color.a * rng.randf_range(0.5, 1.0))
		m.albedo_texture = puff_texture()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		var q := QuadMesh.new()
		var s := size * rng.randf_range(0.6, 1.4)
		q.size = Vector2(s, s)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = at + Vector3(rng.randfn(0, 0.5) * spread.x, absf(rng.randfn(0, 0.5)) * spread.y, rng.randfn(0, 0.5) * spread.z)
		extras.add_child(mi)


## A bar from a to b (rebar, a rod).
func rod(a: Vector3, b: Vector3, radius: float = 0.012, color := Color(0.5, 0.25, 0.16)) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = a.distance_to(b)
	c.radial_segments = 5
	c.rings = 0
	var mi := MeshInstance3D.new()
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	mi.material_override = m
	var up := (b - a).normalized()
	var side := up.cross(Vector3(0.31, 0.2, 0.93)).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	extras.add_child(mi)


## Rebar torn out of concrete: starts at `from` along `dir`, droops and kinks.
func rebar(from: Vector3, dir: Vector3, length: float, droop: float = 0.6, radius: float = 0.012) -> void:
	var p := from
	var d := dir.normalized()
	var steps := 4
	for i in steps:
		var q := p + d * (length / steps)
		rod(p, q, radius)
		p = q
		d = (d + Vector3(rng.randf_range(-0.25, 0.25), -droop * rng.randf_range(0.3, 1.0), rng.randf_range(-0.25, 0.25))).normalized()


## A flat picture on a surface (bullet marks, cracks, dust stains): a quad a hair off it.
func decal(tex: Texture2D, at: Vector3, normal: Vector3, size: Vector2, spin: float = 0.0, unshaded := false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z := normal.normalized()
	var x := (Vector3.UP.cross(z) if absf(z.y) < 0.9 else Vector3.RIGHT.cross(z)).normalized()
	var basis := Basis(x, z.cross(x), z).rotated(z, spin)
	mi.transform = Transform3D(basis, at + z * 0.004)
	extras.add_child(mi)
	return mi


## A bullet mark: a chipped crater (pale fresh material), a dark pit, hairline cracks.
## core = pit radius, crater = chip radius, both as a share of the picture (0..0.5).
## `through` leaves the pit see-through (the real hole is behind it).
func hole_texture(sd: int, core: float, crater: float, through: bool, base: Color, cracks: int = 3, soot: float = 0.0) -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = sd
	noise.frequency = 0.9
	var fine := FastNoiseLite.new()
	fine.seed = sd + 50
	fine.frequency = 0.18
	var lr := RandomNumberGenerator.new()
	lr.seed = sd
	var crack_angles := []
	for i in cracks:
		crack_angles.append([lr.randf() * TAU, lr.randf_range(0.6, 1.0)])
	var fresh := Color(base.r * 1.16 + 0.05, base.g * 1.16 + 0.05, base.b * 1.15 + 0.05)
	for y in n:
		for x in n:
			var v := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / n
			var ang := v.angle()
			var r := v.length()
			var wob := 1.0 + 0.32 * noise.get_noise_2d(cos(ang) * 2.0, sin(ang) * 2.0) + 0.12 * fine.get_noise_2d(x, y)
			var rc := r / wob
			var col := Color(0, 0, 0, 0)
			if rc < core:
				col = Color(0, 0, 0, 0) if through else Color(0.05, 0.05, 0.055, 1.0)
				if through and rc > core * 0.72:
					col = Color(0.1, 0.1, 0.1, 1.0)   # the lip of the hole
			elif rc < crater:
				# The chipped dish: paler than the face, darker toward the pit and under its top lip.
				var t := (rc - core) / maxf(crater - core, 0.001)
				var lit := 0.72 + 0.3 * t + 0.1 * fine.get_noise_2d(x * 2.0, y * 2.0) - 0.16 * clampf(-v.y / maxf(r, 0.001), 0.0, 1.0) * (1.0 - t)
				col = Color(fresh.r * lit, fresh.g * lit, fresh.b * lit, 1.0)
				if t > 0.9:
					col.a = (1.0 - t) / 0.1
			else:
				# Dust / soot round it.
				var halo := clampf(1.0 - (rc - crater) / (crater * 0.9), 0.0, 1.0)
				if soot > 0.0:
					col = Color(0.08, 0.08, 0.08, halo * halo * soot)
				else:
					col = Color(fresh.r, fresh.g, fresh.b, halo * halo * 0.3)
				for c in crack_angles:
					var da := absf(angle_difference(ang, c[0] + 0.25 * fine.get_noise_2d(r * 300.0, c[0] * 40.0)))
					var reach: float = crater + (0.5 - crater) * c[1]
					if r < reach and da * r * n < 0.75:
						col = Color(0.12, 0.12, 0.13, 0.85 * (1.0 - (r - crater) / maxf(reach - crater, 0.001)))
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A web of cracks spreading from the middle (painted on a face that is about to go).
func crack_texture(sd: int, branches: int = 7) -> Texture2D:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var lr := RandomNumberGenerator.new()
	lr.seed = sd
	for b in branches:
		var p := Vector2(n * 0.5, n * 0.5) + Vector2(lr.randf_range(-6, 6), lr.randf_range(-6, 6))
		var ang := TAU * b / branches + lr.randf_range(-0.3, 0.3)
		_crack_walk(img, lr, p, ang, n * lr.randf_range(0.3, 0.48), 2.2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _crack_walk(img: Image, lr: RandomNumberGenerator, p: Vector2, ang: float, length: float, width: float) -> void:
	var n := img.get_width()
	var steps := int(length / 1.5)
	for s in steps:
		ang += lr.randf_range(-0.22, 0.22)
		if lr.randf() < 0.06:
			ang += lr.randf_range(-0.9, 0.9)
		p += Vector2(cos(ang), sin(ang)) * 1.5
		var w := width * (1.0 - float(s) / steps) + 0.6
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				var a := clampf(1.0 - Vector2(dx, dy).length() / w, 0.0, 1.0)
				var old := img.get_pixel(q.x, q.y)
				img.set_pixel(q.x, q.y, Color(0.1, 0.1, 0.11, maxf(old.a, a * 0.9)))
		if width > 1.2 and lr.randf() < 0.035:
			_crack_walk(img, lr, p, ang + lr.randf_range(0.5, 1.1) * (1 if lr.randf() < 0.5 else -1), length * 0.45, width * 0.6)


func stain_texture(color: Color) -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5, y - n * 0.5).length() / (n * 0.5)
			var k := 0.7 + 0.6 * noise.get_noise_2d(x, y)
			var a := clampf(1.0 - d * (0.8 + 0.4 * k), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a * color.a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func label(text: String, at: Vector3, color := Color.WHITE, px: int = 28) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = px
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.06, 0.08, 0.95)
	l.no_depth_test = true
	l.render_priority = 10
	l.position = at
	extras.add_child(l)


## Voronoi pieces of the rectangle (0,0)..(w,h): an array of convex polygons
## (PackedVector2Array) with their seeds [{seed, poly}].
func voronoi(w: float, h: float, seeds: Array) -> Array:
	var cells := []
	for i in seeds.size():
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
		for j in seeds.size():
			if i == j:
				continue
			var mid: Vector2 = (seeds[i] + seeds[j]) * 0.5
			var nrm: Vector2 = (seeds[j] - seeds[i]).normalized()
			poly = _clip2(poly, mid, nrm)
			if poly.size() < 3:
				break
		if poly.size() >= 3:
			cells.append({"seed": seeds[i], "poly": poly})
	return cells


func _clip2(poly: PackedVector2Array, point: Vector2, nrm: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := (a - point).dot(nrm)
		var db := (b - point).dot(nrm)
		if da <= 0.0:
			result.append(a)
		if (da < 0.0) != (db < 0.0) and absf(da - db) > 1e-9:
			result.append(a.lerp(b, da / (da - db)))
	return result


## Shrinks a polygon toward its middle by `gap` metres (a crack between neighbours).
func inset(poly: PackedVector2Array, gap: float) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in poly:
		mid += p
	mid /= poly.size()
	var result := PackedVector2Array()
	for p in poly:
		var d := p - mid
		result.append(mid + d * maxf(0.0, 1.0 - gap / maxf(d.length(), 0.001)))
	return result


func poly_mid(poly: PackedVector2Array) -> Vector2:
	var mid := Vector2.ZERO
	for p in poly:
		mid += p
	return mid / poly.size()


# ================================================================ scenes

const WALL8 := "Tower/BlockWall8"
const BLOCK_COL := Color(0.7, 0.7, 0.69)

## Bullet marks on the ground-floor block wall (x = -7, z 7..13, 3.6 high), seen from the east.
func scene_holes() -> void:
	var face_x := -6.85
	var back_x := -7.15
	# What hit it: [y, z, kind]
	var marks := [
		# a pistol magazine: shallow chips, none go through
		[2.3, 8.05, "pistol"], [2.17, 8.3, "pistol"], [2.45, 8.42, "pistol"], [2.05, 8.6, "pistol"], [2.36, 8.78, "pistol"], [2.15, 8.95, "pistol"],
		# a rifle burst climbing with recoil: every round goes through
		[0.92, 7.95, "rifle"], [1.0, 8.15, "rifle"], [1.11, 8.3, "rifle"], [1.19, 8.52, "rifle"], [1.33, 8.66, "rifle"], [1.42, 8.9, "rifle"], [1.58, 9.04, "rifle"], [1.65, 9.27, "rifle"],
		# a shotgun blast: a wide pattern of small pits, a few through
		[1.1, 9.95, "pellet"], [1.22, 10.08, "pellet_t"], [1.01, 10.13, "pellet"], [1.31, 9.9, "pellet"], [1.15, 10.24, "pellet"], [0.93, 10.0, "pellet_t"], [1.26, 10.3, "pellet"], [1.05, 9.8, "pellet"], [1.38, 10.12, "pellet"], [0.96, 10.27, "pellet"], [1.2, 9.72, "pellet"],
		# a sniper round
		[2.4, 9.85, "heavy"],
	]
	var spec := {
		"pistol": {"size": 0.26, "core": 0.011, "crater": 0.045, "through": false, "cracks": 2},
		"rifle": {"size": 0.32, "core": 0.02, "crater": 0.06, "through": true, "cracks": 3},
		"pellet": {"size": 0.12, "core": 0.007, "crater": 0.022, "through": false, "cracks": 0},
		"pellet_t": {"size": 0.12, "core": 0.009, "crater": 0.025, "through": true, "cracks": 0},
		"heavy": {"size": 0.75, "core": 0.04, "crater": 0.12, "through": true, "cracks": 6},
	}
	if stage >= 1:
		hide_near(Vector3(-4, 1, 10), 3.2, ["TowerCover"])
		# The chewed-open patch: 1.4 m wide, 1.1 m high
		var patch := AABB(Vector3(back_x - 0.01, 0.95, 10.65), Vector3(0.32, 1.15, 1.5))
		cut_region(patch, [WALL8])
		for m in marks:
			var s: Dictionary = spec[m[2]]
			if s.through:
				var h: float = s.core * 2.2
				cut_region(AABB(Vector3(back_x - 0.01, m[0] - h, m[1] - h), Vector3(0.32, h * 2, h * 2)), [WALL8])
		_post.append(func():
			var i := 0
			for m in marks:
				var s: Dictionary = spec[m[2]]
				i += 1
				var tex := hole_texture(100 + i, s.core / s.size, s.crater / s.size, s.through, BLOCK_COL, s.cracks)
				decal(tex, Vector3(face_x, m[0], m[1]), Vector3(1, 0, 0), Vector2(s.size, s.size), rng.randf() * TAU)
			_chewed(patch, face_x, back_x)
			# What fell out of it
			grit("block", Vector3(face_x + 0.35, 0.0, 11.4), 0.9, 160, Vector2(0.55, 1.0))
			grit("block", Vector3(face_x + 0.12, 0.0, 8.4), 0.7, 60, Vector2(0.3, 1.3))
			grit("block", Vector3(face_x + 0.1, 0.0, 10.0), 0.5, 30, Vector2(0.3, 1.0))
			rubble("block", Vector3(face_x + 0.3, 0.0, 11.4), 0.6, 0.12, 22, 0.2, Vector2(0.6, 1.0))
			decal(stain_texture(Color(0.78, 0.78, 0.76, 0.5)), Vector3(face_x + 0.7, 0.0, 11.4), Vector3.UP, Vector2(2.6, 3.0))
			decal(stain_texture(Color(0.78, 0.78, 0.76, 0.3)), Vector3(face_x + 0.4, 0.0, 8.5), Vector3.UP, Vector2(1.4, 2.6))
		)
	if stage >= 2:
		_post.append(func():
			label("Pistol: chips the face,\nstops in the wall", Vector3(face_x, 2.78, 8.5))
			label("Rifle: goes clean through.\nYou can see and shoot through every hole", Vector3(face_x, 0.55, 8.6))
			label("Shotgun: a spread of pits,\na few pellets get through", Vector3(face_x, 0.62, 10.05))
			label("Sniper: big crater,\nlong cracks", Vector3(face_x, 2.95, 9.85))
			label("Keep shooting one spot and it opens:\nsmall pieces break away first", Vector3(face_x, 2.45, 11.45))
		)
	look(Vector3(-4.3, 1.62, 8.85), Vector3(-7.0, 1.6, 10.05), 62.0)


## A patch of wall shot until it opens: small pieces at the middle, bigger further out;
## the middle ones are gone, the next ring is loose (cracked apart), the rest holds.
func _chewed(patch: AABB, face_x: float, back_x: float) -> void:
	var w := patch.size.z
	var h := patch.size.y
	var mid := Vector2(w * 0.5, h * 0.52)
	var seeds := []
	var lr := RandomNumberGenerator.new()
	lr.seed = 21
	for i in 70:
		var a := lr.randf() * TAU
		var r := pow(lr.randf(), 1.5) * 0.95
		var p := mid + Vector2(cos(a) * r * w * 0.6, sin(a) * r * h * 0.6)
		if p.x > 0.02 and p.y > 0.02 and p.x < w - 0.02 and p.y < h - 0.02:
			seeds.append(p)
	for c in voronoi(w, h, seeds):
		var s: Vector2 = c.seed
		var d := Vector2((s.x - mid.x) / 0.36, (s.y - mid.y) / 0.27).length() + lr.randf_range(-0.15, 0.15)
		if d < 1.0:
			continue   # shot away
		var poly: PackedVector2Array = c.poly
		var loose := d < 1.9
		var front := face_x
		if loose:
			front = face_x - lr.randf_range(0.0, 0.05) * (2.0 - d)   # chipped back a little
		_extrude("block", poly, patch.position.z, patch.position.y, back_x, front, 1.0, true)
		if loose:
			for i in poly.size():
				var a := poly[i]
				var b := poly[(i + 1) % poly.size()]
				if (a.x < 0.001 and b.x < 0.001) or (a.y < 0.001 and b.y < 0.001) or (a.x > w - 0.001 and b.x > w - 0.001) or (a.y > h - 0.001 and b.y > h - 0.001):
					continue   # the edge of the patch is not a crack
				_line(Vector3(front, patch.position.y + a.y, patch.position.z + a.x), Vector3(front, patch.position.y + b.y, patch.position.z + b.x), Vector3(1, 0, 0), 0.007 if d < 1.45 else 0.004)


var _line_mat: StandardMaterial3D

## A dark hairline on a face (a crack between two pieces).
func _line(a: Vector3, b: Vector3, normal: Vector3, width: float) -> void:
	if a.distance_to(b) < 0.004:
		return
	if _line_mat == null:
		_line_mat = flat(Color(0.13, 0.14, 0.17), true)
	var side := (b - a).normalized().cross(normal).normalized() * width * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := normal * 0.003
	for v in [a - side, b - side, b + side, a - side, b + side, a + side]:
		st.add_vertex(v + o)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _line_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extras.add_child(mi)


## A polygon (u along z, v up) pushed through the wall from x0 to x1.
func _extrude(kind: String, poly: PackedVector2Array, z0: float, y0: float, x0: float, x1: float, mul: float, patterned: bool) -> void:
	var pts := PackedVector3Array()
	for p in poly:
		pts.append(Vector3(x0, y0 + p.y, z0 + p.x))
		pts.append(Vector3(x1, y0 + p.y, z0 + p.x))
	hull(kind, pts, Transform3D(), mul, patterned)


# ---------------------------------------------------------------- more helpers

var _tops: Array = []

## The top of the highest solid thing under (x, z) that is no higher than `below`.
func top_at(x: float, z: float, below: float) -> float:
	if _tops.is_empty():
		for b: MapBlock in blocks():
			if not b.solid or b.shape != MapBlock.Shape.BOX:
				continue
			_tops.append(xf_of(b) * AABB(-b.size * 0.5, b.size))
	var best := 0.0
	for box: AABB in _tops:
		if x >= box.position.x and x <= box.end.x and z >= box.position.z and z <= box.end.z and box.end.y <= below and box.end.y > best:
			best = box.end.y
	return best


## Rubble that fell from `from` high: every piece lies on whatever is under it.
func rubble_drop(kind: String, at: Vector3, radius: float, count: int, big: float, squash := Vector2.ONE, heap: float = 0.0) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := radius * pow(rng.randf(), 0.8)
		var k := 1.0 - r / radius
		var s := lerpf(0.07, big, pow(rng.randf(), 2.0) * (0.4 + 0.6 * k))
		var x := at.x + cos(a) * r * squash.x
		var z := at.z + sin(a) * r * squash.y
		var y := top_at(x, z, at.y) + s * 0.3 + heap * k * k * rng.randf()
		chunk(kind, Vector3(x, y, z), Vector3(s * rng.randf_range(0.8, 1.6), s * rng.randf_range(0.4, 0.8), s * rng.randf_range(0.7, 1.2)), rng.randf_range(0.74, 1.0), 0.35 if heap * k < 0.1 else PI)


## A flat convex piece of wall or slab: `poly` in the plane (u, v) from `origin`,
## as thick as d0..d1 along n. Built round its own middle and placed by `move`
## (identity = where it was).
func prism(kind: String, poly: PackedVector2Array, origin: Vector3, u: Vector3, v: Vector3, n: Vector3, d0: float, d1: float, move: Transform3D = Transform3D(), patterned := true, mul := 1.0) -> MeshInstance3D:
	if move == Transform3D():
		var pts := PackedVector3Array()
		for p in poly:
			pts.append(origin + u * p.x + v * p.y + n * d0)
			pts.append(origin + u * p.x + v * p.y + n * d1)
		return hull(kind, pts, Transform3D(), mul, patterned)
	var m := poly_mid(poly)
	var c := origin + u * m.x + v * m.y + n * (d0 + d1) * 0.5
	# (Built a little off its own origin, so the pattern's seams, which the shader
	# measures from there, do not all cross the middle of every piece.)
	var shift := Vector3(0.4, 0.2, 0.4) if kind == "block" else Vector3(1.5, 0.75, 1.5)
	var local := PackedVector3Array()
	for p in poly:
		local.append(shift + u * (p.x - m.x) + v * (p.y - m.y) + n * (d0 - d1) * 0.5)
		local.append(shift + u * (p.x - m.x) + v * (p.y - m.y) + n * (d1 - d0) * 0.5)
	return hull(kind, local, Transform3D(move.basis, c + move.origin - move.basis * shift), mul, patterned)


## Blockwork broken the way blockwork breaks: along its level courses, into blocks
## and bits of blocks, smaller the nearer the blast at `mid`. [{poly, mid}]
func masonry_cells(w: float, h: float, mid: Vector2, lr: RandomNumberGenerator, course: float = 0.4) -> Array:
	var cells := []
	var rows := roundi(h / course)
	for j in rows:
		var x := -lr.randf() * 0.4
		while x < w:
			var cy := (j + 0.5) * course
			var d := Vector2(x + 0.3 - mid.x, cy - mid.y).length()
			var length := lerpf(0.34, 0.8, clampf(d / 2.2, 0.0, 1.0)) * lr.randf_range(0.8, 1.2)
			var x0 := maxf(x, 0.0)
			var x1 := minf(x + length, w)
			x += length
			if x1 - x0 < 0.02:
				continue
			var rect := PackedVector2Array([Vector2(x0, j * course), Vector2(x1, j * course), Vector2(x1, (j + 1) * course), Vector2(x0, (j + 1) * course)])
			var parts := [rect]
			if d < 2.0 and lr.randf() < 0.6:
				# snapped across
				var at := Vector2(lerpf(x0, x1, lr.randf_range(0.3, 0.7)), cy)
				var nrm := Vector2(1, lr.randf_range(-0.8, 0.8)).normalized()
				parts = [_clip2(rect, at, nrm), _clip2(rect, at, -nrm)]
			for poly: PackedVector2Array in parts:
				if poly.size() >= 3:
					cells.append({"poly": poly, "mid": poly_mid(poly)})
	return cells


## A jagged round figure for "how far the breach reaches this way" (0.75..1.25).
func ragged(angle: float, sd: int) -> float:
	var noise := FastNoiseLite.new()
	noise.seed = sd
	noise.frequency = 0.5
	return 1.0 + 0.3 * noise.get_noise_2d(cos(angle) * 2.0, sin(angle) * 2.0)


# ================================================================ wall breach

## The second-floor block wall on the north face (z -16..-15.7, x -16..6, y 8..11.6),
## seen from outside. Stage 0 whole, 1 shot up, 2 the blast, 3 afterwards.
func scene_breach() -> void:
	var wall := "Tower/BlockWall2"
	var out_z := -16.0
	var in_z := -15.7
	var patch := AABB(Vector3(-13.6, 8.0, out_z - 0.01), Vector3(6.0, 3.6, 0.32))
	var mid := Vector2(3.0, 1.75)
	var centre := Vector3(patch.position.x + mid.x, patch.position.y + mid.y, out_z)
	var n_out := Vector3(0, 0, -1)
	if stage >= 1:
		var lr := RandomNumberGenerator.new()
		lr.seed = 5
		var shots := []
		for i in 16:
			shots.append(Vector3(centre.x + lr.randfn(0, 0.9), centre.y + lr.randfn(0, 0.6), out_z))
		if stage == 1:
			for s: Vector3 in shots:
				var h := 0.045
				cut_region(AABB(Vector3(s.x - h, s.y - h, out_z - 0.01), Vector3(h * 2, h * 2, 0.32)), [wall])
		_post.append(func():
			var i := 0
			for s: Vector3 in shots:
				i += 1
				if stage == 1 or Vector2((s.x - centre.x) / 1.5, (s.y - centre.y) / 1.2).length() > 1.7:
					decal(hole_texture(300 + i, 0.02 / 0.34, 0.07 / 0.34, stage == 1, BLOCK_COL, 3), s, n_out, Vector2(0.34, 0.34), lr.randf() * TAU)
			if stage == 1:
				decal(crack_texture(11, 9), centre + Vector3(0.2, 0.1, 0), n_out, Vector2(3.4, 3.0))
				decal(crack_texture(12, 6), centre + Vector3(-0.9, -0.5, 0), n_out, Vector2(1.6, 1.6))
		)
	if stage >= 2:
		cut_region(patch, [wall])
		_post.append(func():
			var lr := RandomNumberGenerator.new()
			lr.seed = 9
			var origin := Vector3(patch.position.x, patch.position.y, 0)
			var u := Vector3(1, 0, 0)
			var v := Vector3(0, 1, 0)
			for c in masonry_cells(patch.size.x, patch.size.y, mid, lr):
				var m: Vector2 = c.mid
				var off := Vector2((m.x - mid.x) / 1.75, (m.y - mid.y) / 1.4)
				var d := off.length() / ragged(off.angle(), 4)
				if m.y < 0.4:
					d *= 1.5   # the bottom course is bedded on the slab: it holds longer
				var poly: PackedVector2Array = c.poly
				if d >= 1.0:
					var loose := d < 1.45
					var move := Transform3D()
					if loose and lr.randf() < 0.5:
						move = Transform3D(Basis.from_euler(Vector3(lr.randf_range(-0.05, 0.05), lr.randf_range(-0.06, 0.06), lr.randf_range(-0.03, 0.03))), Vector3(0, 0, -lr.randf_range(0.0, 0.07)))
					prism("block", poly, origin, u, v, Vector3(0, 0, 1), out_z, in_z, move, true)
					if loose and move == Transform3D():
						for i in poly.size():
							var a := poly[i]
							var b := poly[(i + 1) % poly.size()]
							_line(origin + u * a.x + v * a.y + Vector3(0, 0, out_z), origin + u * b.x + v * b.y + Vector3(0, 0, out_z), n_out, 0.012)
				elif stage == 2:
					# in the air: thrown out and away from the middle
					var t := lr.randf_range(0.12, 0.3)
					var vel := Vector3(off.x * 3.5, off.y * 3.0 + 1.5, -lr.randf_range(5.0, 13.0) * (1.3 - 0.6 * d))
					var p := vel * t + Vector3(0, -4.9 * t * t, 0)
					var spin := Basis.from_euler(Vector3(lr.randf_range(-1, 1), lr.randf_range(-1, 1), lr.randf_range(-1, 1)) * t * 9.0)
					prism("block", poly, origin, u, v, Vector3(0, 0, 1), out_z, in_z, Transform3D(spin, p), true)
			if stage == 2:
				rng.seed = 31
				# smaller bits ahead of the blocks, and the dust
				for i in 70:
					var dir := Vector3(rng.randfn(0, 0.5), rng.randfn(0.1, 0.4), -1.0).normalized()
					var s := rng.randf_range(0.05, 0.22)
					chunk("block", centre + dir * rng.randf_range(0.6, 5.0) + Vector3(0, -rng.randf() * 0.5, 0), Vector3(s, s * 0.7, s * 1.2), 0.85)
				dust(centre + Vector3(0, 0, 0.3), Vector3(1.1, 0.8, 0.3), 16, 1.5, Color(1.0, 0.8, 0.5, 0.6))
				dust(centre + Vector3(0, -0.2, -0.7), Vector3(3.0, 1.8, 1.4), 70, 2.4, Color(0.6, 0.6, 0.58, 0.42))
				dust(centre + Vector3(0, 0.0, -2.6), Vector3(2.4, 1.6, 1.8), 34, 2.0, Color(0.66, 0.66, 0.63, 0.24))
			else:
				rng.seed = 32
				# what is left: blocks and bits on the floor inside, on the ledge, and below
				rubble_drop("block", Vector3(centre.x, 8.3, in_z + 0.9), 1.9, 80, 0.5, Vector2(1.0, 0.55), 0.3)
				rubble_drop("block", Vector3(centre.x, 7.9, out_z - 2.6), 3.4, 150, 0.55, Vector2(1.0, 0.8), 0.25)
				grit("block", Vector3(centre.x, 8.0, in_z + 0.8), 2.0, 200, Vector2(1.0, 0.5))
				decal(stain_texture(Color(0.8, 0.8, 0.78, 0.55)), Vector3(centre.x, 8.0, in_z + 0.9), Vector3.UP, Vector2(5.0, 3.0))
				# dust still hanging
				dust(centre + Vector3(0, -0.9, -0.3), Vector3(2.4, 0.8, 1.2), 14, 2.2, Color(0.82, 0.82, 0.8, 0.1))
		)
	look(Vector3(-17.8, 10.5, -22.2), Vector3(-10.3, 9.45, -16.3), 55.0)


# ================================================================ floor breach

## A hole blown in the second floor's concrete slab (y 7.6..8.0) at x 0, z -10.5.
## Stage 1 seen from above, stage 2 from the floor below.
func scene_slab() -> void:
	var patch := AABB(Vector3(-2.4, 7.59, -12.9), Vector3(4.8, 0.43, 4.8))
	var mid := Vector2(2.4, 2.4)
	var centre := Vector3(patch.position.x + mid.x, 8.0, patch.position.z + mid.y)
	cut_region(patch, ["Tower/Floor2"])
	hide_near(centre, 3.4, ["TowerCover"])
	hide_near(centre + Vector3(0, -4, 0), 3.4, ["TowerCover"])
	_post.append(func():
		var lr := RandomNumberGenerator.new()
		lr.seed = 14
		var seeds := []
		for i in 150:
			var a := lr.randf() * TAU
			var r := pow(lr.randf(), 1.25) * 3.4
			var p := mid + Vector2(cos(a), sin(a)) * r
			if p.x > 0.05 and p.y > 0.05 and p.x < patch.size.x - 0.05 and p.y < patch.size.z - 0.05:
				seeds.append(p)
		var origin := Vector3(patch.position.x, 0, patch.position.z)
		var u := Vector3(1, 0, 0)
		var v := Vector3(0, 0, 1)
		var radius := 1.45
		var fallen := []
		for c in voronoi(patch.size.x, patch.size.z, seeds):
			var m: Vector2 = poly_mid(c.poly)
			var off := (m - mid) / radius
			var d := off.length() / ragged(off.angle(), 8)
			var poly: PackedVector2Array = c.poly
			if d < 1.0:
				fallen.append(poly)
				continue
			var move := Transform3D()
			if d < 1.5:
				# hanging on its bars: tipped down toward the hole
				var out := Vector3(off.x, 0, off.y).normalized()
				var tilt := lr.randf_range(0.12, 0.5) * (1.6 - d) / 0.6
				move = Transform3D(Basis(out.cross(Vector3.UP).normalized(), tilt), Vector3(0, -sin(tilt) * 0.22, 0) - out * 0.02)
			prism("concrete", poly, origin, u, v, Vector3.UP, 7.6, 8.0, move, true)
			if d < 2.1 and move == Transform3D():
				for i in poly.size():
					var a := poly[i]
					var b := poly[(i + 1) % poly.size()]
					if minf(a.x, b.x) < 0.001 or minf(a.y, b.y) < 0.001 or maxf(a.x, b.x) > patch.size.x - 0.001 or maxf(a.y, b.y) > patch.size.z - 0.001:
						continue
					_line(origin + u * a.x + v * a.y + Vector3(0, 8.0, 0), origin + u * b.x + v * b.y + Vector3(0, 8.0, 0), Vector3.UP, 0.012 if d < 1.7 else 0.006)
					_line(origin + u * a.x + v * a.y + Vector3(0, 7.6, 0), origin + u * b.x + v * b.y + Vector3(0, 7.6, 0), Vector3.DOWN, 0.012 if d < 1.7 else 0.006)
		# The slab's steel: a mat of bars both ways, torn and bent down into the hole.
		rng.seed = 40
		var step := 0.3
		for axis in 2:
			var k := -1.8
			while k <= 1.8:
				var reach := sqrt(maxf(0.0, 1.0 - pow(k / (radius * 1.25), 2.0))) * radius * 1.25
				if reach > 0.25:
					for side in [-1.0, 1.0]:
						var along := Vector3(side, 0, 0) if axis == 0 else Vector3(0, 0, side)
						var across := Vector3(0, 0, k) if axis == 0 else Vector3(k, 0, 0)
						var from := Vector3(centre.x, 7.7 + 0.03 * axis, centre.z) + across + along * reach
						if rng.randf() < 0.85:
							rebar(from, -along + Vector3(0, -0.15, 0), rng.randf_range(0.35, reach * 1.0), 0.45, 0.016)
				k += step
		# What fell: the big pieces lie on the floor below, with the small stuff round them.
		var floor_y := 4.0
		for poly: PackedVector2Array in fallen:
			var m := poly_mid(poly)
			var drift := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
			var spin := Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-PI, PI), rng.randf_range(-0.45, 0.45)))
			var lift := rng.randf_range(0.2, 0.5) if rng.randf() < 0.45 else 0.0
			prism("concrete", poly, origin, u, v, Vector3.UP, 7.6, 8.0, Transform3D(spin, drift + Vector3(0, floor_y + 0.24 + lift - 7.8, 0)), false, rng.randf_range(0.86, 1.0))
		rubble("concrete", Vector3(centre.x, floor_y, centre.z), 2.6, 0.6, 150, 0.45)
		grit("concrete", Vector3(centre.x, floor_y, centre.z), 3.0, 500)
		grit("concrete", Vector3(centre.x, 8.0, centre.z), 2.6, 70, Vector2.ONE, 0.95)
		decal(stain_texture(Color(0.86, 0.86, 0.83, 0.6)), Vector3(centre.x, floor_y, centre.z), Vector3.UP, Vector2(8.0, 8.0))
		decal(stain_texture(Color(0.2, 0.2, 0.2, 0.35)), Vector3(centre.x, 8.0, centre.z), Vector3.UP, Vector2(6.5, 6.5))
		dust(Vector3(centre.x, floor_y + 0.3, centre.z), Vector3(2.4, 1.2, 2.4), 22, 2.6, Color(0.8, 0.8, 0.78, 0.12))
	)
	if stage == 2:
		look(Vector3(4.0, 5.1, -6.4), Vector3(0.0, 6.3, -10.5), 76.0)
	else:
		look(Vector3(2.9, 10.0, -7.2), Vector3(-0.2, 7.5, -10.6), 66.0)



# ================================================================ collapse

const BAY_LO := Vector2(-16.0, -16.0)     # the north-west bay of the concrete frame (x, z)
const BAY_HI := Vector2(-6.05, -6.05)
const FLOOR_TOPS := [4.0, 8.0, 12.0, 16.0, 20.0]
const CORNER := Vector3(-15.5, 0, -15.5)  # the column that goes

## Stage 0: who holds what (the support view). 1: the corner column is shot out.
## 2: the bay comes down. 3: afterwards.
func scene_collapse() -> void:
	if stage == 0:
		_post.append(_support_view)
	elif stage == 1:
		_column_gone(false)
		_post.append(func():
			dust(Vector3(CORNER.x, 1.4, CORNER.z), Vector3(1.6, 1.4, 1.6), 26, 2.2, Color(0.66, 0.66, 0.63, 0.34))
			# the floors above start to let go: cracks along the lines they will tear on
			for top: float in FLOOR_TOPS:
				for k in 5:
					decal(crack_texture(60 + k, 5), Vector3(BAY_LO.x - 0.001, top - 0.2 - rng.randf() * 0.1, lerpf(-15.0, -7.0, k / 4.0)), Vector3(-1, 0, 0), Vector2(2.6, 1.3), rng.randf() * 0.4)
					decal(crack_texture(70 + k, 5), Vector3(lerpf(-15.0, -7.0, k / 4.0), top - 0.2 - rng.randf() * 0.1, BAY_LO.y - 0.001), Vector3(0, 0, -1), Vector2(2.6, 1.3), rng.randf() * 0.4)
		)
	else:
		_column_gone(true)
		cut_region(AABB(Vector3(-16.4, -0.05, -16.4), Vector3(10.35, 30.0, 10.35)), ["Tower", "TowerCover"])
		_post.append(_bay_down)
	look(Vector3(-33.0, 13.0, -37.0), Vector3(-10.5, 8.8, -10.5), 46.0)


func _column_gone(all_of_it: bool) -> void:
	if not all_of_it:
		cut_region(AABB(Vector3(CORNER.x - 0.6, 0.55, CORNER.z - 0.6), Vector3(1.2, 2.2, 1.2)), ["Tower/Column/"])
	_post.append(func():
		rng.seed = 77
		# the stump, its bars standing out of it
		var stump := clip(box_pts(Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0)), Plane(Vector3(0.35, 1, 0.2).normalized(), 0.62))
		if all_of_it:
			hull("concrete", stump, Transform3D(Basis(), Vector3(CORNER.x, 0, CORNER.z)), 0.95)
		for i in 8:
			var a := TAU * i / 8.0
			var foot := Vector3(CORNER.x + cos(a) * 0.33, 0.55, CORNER.z + sin(a) * 0.33)
			if all_of_it:
				rebar(foot, Vector3(cos(a) * 0.5, 1, sin(a) * 0.5), rng.randf_range(0.5, 1.1), 0.35, 0.02)
			else:
				# buckled bars still joining the two ends
				var p := foot
				var top := Vector3(foot.x, 2.75, foot.z)
				var bulge := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.2, 0.5)
				var last := p
				for sgm in 6:
					var t := (sgm + 1) / 6.0
					var q := foot.lerp(top, t) + bulge * sin(t * PI)
					rod(last, q, 0.02)
					last = q
		rubble("concrete", Vector3(CORNER.x, 0, CORNER.z), 2.4, 0.3, 70, 0.4)
		grit("concrete", Vector3(CORNER.x, 0, CORNER.z), 3.2, 260)
		decal(stain_texture(Color(0.84, 0.84, 0.8, 0.55)), Vector3(CORNER.x, 0.0, CORNER.z), Vector3.UP, Vector2(7, 7))
	)


## Where the pile stands above the ground at (x, z).
func _mound(x: float, z: float) -> float:
	var d := Vector2(x + 11.8, z + 11.8).length()
	return 2.1 * exp(-d * d / 34.0)


func _bay_down() -> void:
	var lr := RandomNumberGenerator.new()
	lr.seed = 3
	var size := BAY_HI - BAY_LO
	var origin := Vector3(BAY_LO.x, 0, BAY_LO.y)
	var u := Vector3(1, 0, 0)
	var v := Vector3(0, 0, 1)
	# how far each floor has got at this moment (stage 2), bottom floor first
	var progress := [1.0, 1.0, 1.0, 1.0, 1.0] if stage == 3 else [1.0, 0.85, 0.58, 0.36, 0.2]
	for f in FLOOR_TOPS.size():
		var top: float = FLOOR_TOPS[f]
		var seeds := []
		for i in 17:
			seeds.append(Vector2(lr.randf_range(0.4, size.x - 0.4), lr.randf_range(0.4, size.y - 0.4)))
		var p: float = progress[f]
		for c in voronoi(size.x, size.y, seeds):
			var poly: PackedVector2Array = c.poly
			var m := poly_mid(poly)
			var wx := BAY_LO.x + m.x
			var wz := BAY_LO.y + m.y
			if (f == 1 or f == 2) and wx > -13.0 and wx < -8.0 and wz > -13.0 and wz < -8.0:
				continue   # the opening these two floors already had
			var centre := Vector3(wx, top - 0.2, wz)
			var on_x := false   # touches the edge that still stands along x = BAY_HI.x
			var on_z := false
			for q in poly:
				on_x = on_x or q.x > size.x - 0.01
				on_z = on_z or q.y > size.y - 0.01
			var move: Transform3D
			if (on_x or on_z) and f >= 1 and lr.randf() < 0.75:
				# still held by its bars along the edge: it swings down and hangs
				var angle := lr.randf_range(1.0, 1.4) * minf(1.0, p * 1.3)
				var rot := Basis(Vector3(0, 0, 1), angle) if on_x and not (on_z and m.y > m.x) else Basis(Vector3(1, 0, 0), -angle)
				var pivot := Vector3(BAY_HI.x, top - 0.2, wz) if rot.z.is_equal_approx(Vector3(0, 0, 1)) else Vector3(wx, top - 0.2, BAY_HI.y)
				move = Transform3D(rot, pivot + rot * (centre - pivot) - centre)
			else:
				var away := Vector2(wx - BAY_HI.x, wz - BAY_HI.y).normalized()
				var drift := lr.randf_range(0.3, 1.0 + 0.5 * f)
				var fx := wx + away.x * drift
				var fz := wz + away.y * drift
				var rest := _mound(fx, fz) + 0.25 + f * 0.36 + lr.randf_range(0.0, 0.3)
				var lean := lr.randf_range(0.05, 0.3) + 0.5 * clampf((Vector2(fx + 11.8, fz + 11.8).length() - 3.5) / 4.0, 0.0, 1.0)
				var axis := Vector3(-away.y, 0, away.x).rotated(Vector3.UP, lr.randf_range(-0.5, 0.5))
				var rot := Basis(axis.normalized(), -lean * p) * Basis(Vector3.UP, lr.randf_range(-0.3, 0.3) * p)
				if stage == 2 and p < 1.0:
					rot = Basis(axis.normalized(), -lr.randf_range(0.1, 0.9) * p) * Basis(Vector3(1, 0, 0), lr.randf_range(-0.15, 0.15))
				var y := lerpf(centre.y, rest, p * p) if p < 1.0 else rest
				move = Transform3D(rot, Vector3((fx - wx) * p, y - centre.y, (fz - wz) * p))
			prism("concrete", poly, origin, u, v, Vector3.UP, top - 0.4, top, move, true)
	# The corner column, in lengths
	rng.seed = 12
	for i in 4:
		var length := rng.randf_range(2.2, 4.0)
		var pts := lump_pts(Vector3(0.9, length, 0.9), 2)
		var at := Vector3(CORNER.x + rng.randf_range(-2.5, 1.0), 0, CORNER.z + rng.randf_range(-2.5, 1.0))
		if stage == 3:
			at.y = _mound(at.x, at.z) + 0.6 + i * 0.4
			hull("concrete", pts, Transform3D(Basis.from_euler(Vector3(rng.randf_range(1.2, 1.7), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))), at), 0.97)
		else:
			at = Vector3(CORNER.x - 0.4 * i, 2.0 + i * 3.4, CORNER.z - 0.5 * i)
			hull("concrete", pts, Transform3D(Basis.from_euler(Vector3(0.25 * i + 0.2, 0.4 * i, 0.3 * i)), at), 0.97)
	# The block walls of the bay: in the air (stage 2) or in the heap
	var mid := Vector3(-11.8, 0, -11.8)
	if stage == 2:
		for i in 230:
			var face := rng.randi() % 3
			var h := rng.randf_range(1.0, 15.0)
			var at := Vector3(rng.randf_range(-16.8, -6.5), h, -16.4 - rng.randf() * 1.6) if face == 0 else Vector3(-16.4 - rng.randf() * 1.6, h, rng.randf_range(-16.8, -6.5))
			if face == 2:
				at = Vector3(rng.randf_range(-15.5, -7.0), h * 0.7, rng.randf_range(-15.5, -7.0))
			hull("block", box_pts(Vector3(rng.randf_range(0.3, 0.8), 0.4, 0.3)), Transform3D(rand_basis(), at), rng.randf_range(0.9, 1.02))
		dust(mid + Vector3(-1.0, 0.3, -1.0), Vector3(10.0, 3.0, 10.0), 190, 6.5, Color(0.7, 0.69, 0.65, 0.5))
		dust(mid + Vector3(-1.5, 3.0, -1.5), Vector3(7.0, 8.0, 7.0), 90, 6.0, Color(0.74, 0.73, 0.69, 0.25))
		dust(mid + Vector3(-4, 0.5, -4), Vector3(15.0, 1.6, 15.0), 90, 6.0, Color(0.76, 0.75, 0.7, 0.3))
	else:
		for i in 520:
			var a := rng.randf() * TAU
			var r := 9.0 * pow(rng.randf(), 0.7)
			var x := mid.x - absf(cos(a)) * r * 0.9 + 3.0
			var z := mid.z - absf(sin(a)) * r * 0.9 + 3.0
			var y := maxf(top_at(x, z, 6.0), _mound(x, z) + rng.randf_range(0.0, 1.4) * exp(-r * 0.25))
			hull("block", box_pts(Vector3(rng.randf_range(0.3, 0.8), 0.4, 0.3)), Transform3D(rand_basis(0.5 if y < 0.5 else PI), Vector3(x, y + 0.2, z)), rng.randf_range(0.86, 1.02))
		for i in 260:
			var a := rng.randf() * TAU
			var r := 8.5 * pow(rng.randf(), 0.8)
			var x := mid.x + cos(a) * r - 1.0
			var z := mid.z + sin(a) * r - 1.0
			if x > BAY_HI.x - 0.3 and z > BAY_HI.y - 0.3:
				continue
			var s := rng.randf_range(0.2, 1.0)
			chunk("concrete", Vector3(x, maxf(top_at(x, z, 6.0), _mound(x, z) * rng.randf_range(0.6, 1.3)) + s * 0.3, z), Vector3(s, s * 0.6, s * 0.9), rng.randf_range(0.72, 0.98))
		grit("concrete", mid + Vector3(-1, 0.02, -1), 11.0, 900)
		decal(stain_texture(Color(0.86, 0.85, 0.8, 0.7)), mid + Vector3(-1.5, 0.01, -1.5), Vector3.UP, Vector2(30, 30))
		dust(mid + Vector3(-1, 0.6, -1), Vector3(9.0, 2.5, 9.0), 46, 7.0, Color(0.78, 0.77, 0.72, 0.13))
	# Torn edges where the bay left the rest: broken concrete and bars at every floor
	rng.seed = 51
	for top: float in FLOOR_TOPS:
		for k in 34:
			var t := lerpf(BAY_LO.x, BAY_HI.x, k / 33.0)
			var s := rng.randf_range(0.3, 0.6)
			chunk("concrete", Vector3(BAY_HI.x - 0.02, top - 0.2, t), Vector3(s, 0.4, s), 0.95, 0.25)
			chunk("concrete", Vector3(t, top - 0.2, BAY_HI.y - 0.02), Vector3(s, 0.4, s), 0.95, 0.25)
			if k % 2 == 0:
				rebar(Vector3(BAY_HI.x, top - 0.3, t), Vector3(-1, -0.2, 0), rng.randf_range(0.4, 1.2), 0.5, 0.02)
				rebar(Vector3(t, top - 0.3, BAY_HI.y), Vector3(0, -0.2, -1), rng.randf_range(0.4, 1.2), 0.5, 0.02)


func _support_view() -> void:
	# Every column of the concrete frame, drawn through the building
	var green := flat(Color(0.25, 0.95, 0.45, 0.5), true, true)
	var red := flat(Color(1.0, 0.22, 0.18, 0.75), true, true)
	var bay := flat(Color(1.0, 0.45, 0.15, 0.3), true, true)
	for b: MapBlock in blocks():
		var path := str(map.get_path_to(b))
		if not path.begins_with("Tower/Column"):
			continue
		var xf := xf_of(b)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b.size + Vector3(0.12, 0.0, 0.12)
		mi.mesh = bm
		mi.transform = xf
		var is_corner := absf(xf.origin.x - CORNER.x) < 0.1 and absf(xf.origin.z - CORNER.z) < 0.1
		mi.material_override = red if is_corner else green
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extras.add_child(mi)
	for top: float in FLOOR_TOPS:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(BAY_HI.x - BAY_LO.x, 0.42, BAY_HI.y - BAY_LO.y)
		mi.mesh = bm
		mi.position = Vector3((BAY_LO.x + BAY_HI.x) * 0.5, top - 0.2, (BAY_LO.y + BAY_HI.y) * 0.5)
		mi.material_override = bay
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extras.add_child(mi)




# ================================================================ simulated collapse
#
# Nothing here is posed. The bay's slabs, walls and column are cut into loose pieces,
# every piece is a rigid body in the game's own physics engine (Jolt), and all the
# script does is (1) blow out the foot of a column and (2) let go of what that column
# held. Where the pieces go is the physics engine's doing.

var _bodies: Array = []     # {body: RigidBody3D, at: float (when it is let go), push: Vector3, last: Vector3}
var _puffs: Array = []      # {node, mat, age, life, size, alpha}
var _sim_time := 0.0
var _sim_frame := 0
var _step_ms: Array = []
var _active: Array = []
var _last_usec := 0
const T_BLAST := 1.0

func scene_sim() -> void:
	sim = true
	var corners := [CORNER]
	var regions := [AABB(Vector3(-16.4, -0.05, -16.4), Vector3(10.35, 30.0, 10.35))]
	if variant == 1:
		# two columns on the west side: two bays
		corners = [CORNER, Vector3(-15.5, 0, -5.5)]
		regions = [AABB(Vector3(-16.4, -0.05, -16.4), Vector3(10.35, 30.0, 20.8))]
	var taken := []
	for region: AABB in regions:
		taken.append_array(take_region(region))
		cut_region(region, ["Tower", "TowerCover"])
	_post.append(func(): _make_bodies(taken, regions, corners))
	look(Vector3(-33.0, 13.0, -37.0), Vector3(-10.5, 8.8, -10.5), 46.0)


## The solid concrete, blockwork and planks inside `region`, clipped to it: [{kind, box, path}]
func take_region(region: AABB) -> Array:
	var list := []
	for b: MapBlock in blocks():
		var path := str(map.get_path_to(b))
		if not path.begins_with("Tower/"):
			continue
		if not b.solid or b.shape != MapBlock.Shape.BOX or not ["concrete", "block", "plank"].has(b.kind):
			continue
		var xf := xf_of(b)
		if not aligned(xf.basis):
			continue
		var box := AABB(xf.origin - b.size * 0.5, b.size).intersection(region)
		if box.size.x > 0.05 and box.size.y > 0.05 and box.size.z > 0.05:
			list.append({"kind": b.kind, "box": box, "path": path})
	return list


func _make_bodies(taken: Array, regions: Array, corners: Array) -> void:
	var lr := RandomNumberGenerator.new()
	lr.seed = 2
	var region: AABB = regions[0]
	for t in taken:
		var box: AABB = t.box
		var s := box.size
		if t.kind != "block" and s.y <= 0.6 and s.x * s.z > 0.5:
			# a floor slab: irregular pieces, about one per 5 square metres
			var seeds := []
			var count := maxi(2, roundi(s.x * s.z / 5.0))
			for i in count:
				seeds.append(Vector2(lr.randf_range(0.2, s.x - 0.2), lr.randf_range(0.2, s.z - 0.2)))
			for c in voronoi(s.x, s.z, seeds):
				var poly: PackedVector2Array = inset(c.poly, 0.02)
				var m := poly_mid(poly)
				var centre := Vector3(box.position.x + m.x, box.get_center().y, box.position.z + m.y)
				var local := PackedVector3Array()
				var shift := Vector3(1.5, 0.75, 1.5)
				for p in poly:
					local.append(shift + Vector3(p.x - m.x, -s.y * 0.5, p.y - m.y))
					local.append(shift + Vector3(p.x - m.x, s.y * 0.5, p.y - m.y))
				var body := _body(t.kind, local, Transform3D(Basis(), centre - shift), 2400.0 if t.kind == "concrete" else 600.0, true)
				_schedule(body, centre, corners)
				# Bars: a piece on the edge that still stands stays tied to it at two points.
				var on_x := absf(box.end.x - region.end.x) < 0.05
				var on_z := absf(box.end.z - region.end.z) < 0.05
				var ties := []
				for p in c.poly:
					if (on_x and p.x > s.x - 0.01) or (on_z and p.y > s.z - 0.01):
						ties.append(Vector3(box.position.x + p.x, box.get_center().y, box.position.z + p.y))
				if ties.size() >= 2 and lr.randf() < 0.75 and t.kind == "concrete":
					_bodies[-1]["pins"] = [(ties[0] as Vector3).lerp(ties[1], 0.15), (ties[1] as Vector3).lerp(ties[0], 0.15)]
		elif t.kind == "concrete":
			# a column: lengths of about 2 m. The foot of the one under attack is blown to bits.
			var y := box.position.y
			while y < box.end.y - 0.1:
				var h := minf(lr.randf_range(1.6, 2.4), box.end.y - y)
				var centre := Vector3(box.get_center().x, y + h * 0.5, box.get_center().z)
				if y < 3.4:
					for i in 10:
						var bit := lump_pts(Vector3(lr.randf_range(0.25, 0.5), lr.randf_range(0.25, 0.5), lr.randf_range(0.25, 0.5)), 3)
						var at := Vector3(centre.x + lr.randf_range(-0.25, 0.25), y + lr.randf_range(0.2, h - 0.2), centre.z + lr.randf_range(-0.25, 0.25))
						var b := _body("concrete", bit, Transform3D(rand_basis(), at), 2400.0, false)
						var away := Vector3(lr.randf_range(-1, 1), lr.randf_range(0.0, 0.5), lr.randf_range(-1, 1)).normalized()
						_bodies.append({"body": b, "at": T_BLAST, "push": away * lr.randf_range(3.0, 9.0), "last": Vector3.ZERO})
				else:
					var body := _body("concrete", box_pts(Vector3(s.x - 0.03, h - 0.03, s.z - 0.03)), Transform3D(Basis(), centre), 2400.0, false, 0.97)
					_schedule(body, centre, corners)
				y += h
		elif t.kind == "block":
			# blockwork: lumps two courses high, breaking along the courses
			var along_x := s.x > s.z
			var w := s.x if along_x else s.z
			var u := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
			var n := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
			var thick := s.z if along_x else s.x
			for c in masonry_cells(w, s.y, Vector2(-50, -50), lr, 0.8):
				var poly: PackedVector2Array = inset(c.poly, 0.012)
				var m := poly_mid(poly)
				var centre := box.position + u * m.x + Vector3(0, m.y, 0) + n * thick * 0.5
				var local := PackedVector3Array()
				var shift := Vector3(0.4, 0.2, 0.4)
				for p in poly:
					local.append(shift + u * (p.x - m.x) + Vector3(0, p.y - m.y, 0) - n * (thick * 0.5 - 0.01))
					local.append(shift + u * (p.x - m.x) + Vector3(0, p.y - m.y, 0) + n * (thick * 0.5 - 0.01))
				var body := _body("block", local, Transform3D(Basis(), centre - shift), 1400.0, true)
				_schedule(body, centre, corners)
	print("BODIES ", _bodies.size())


var _body_count := 0

func _body(kind: String, local: PackedVector3Array, xf: Transform3D, density: float, patterned: bool, mul := 1.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	_body_count += 1
	body.name = "Piece%d" % _body_count
	var shape := ConvexPolygonShape3D.new()
	shape.points = local
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var lo := local[0]
	var hi := local[0]
	for p in local:
		lo = lo.min(p)
		hi = hi.max(p)
	var size := hi - lo
	body.mass = clampf(size.x * size.y * size.z * 0.7 * density, 15.0, 30000.0)
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.02
	body.physics_material_override = material
	body.angular_damp = 0.3
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.transform = xf
	var mi := hull(kind, local, Transform3D(), mul, patterned, Color.WHITE, true)
	extras.remove_child(mi)
	body.add_child(mi)
	extras.add_child(body)
	return body


## When a piece is let go: the nearer the lost column, the sooner (the failure runs
## outward from it at about 25 m a second).
func _schedule(body: RigidBody3D, centre: Vector3, corners: Array) -> void:
	var nearest := 1e9
	for c: Vector3 in corners:
		nearest = minf(nearest, Vector2(centre.x - c.x, centre.z - c.z).length())
	_bodies.append({"body": body, "at": T_BLAST + 0.35 + nearest / 25.0, "push": Vector3.ZERO, "last": Vector3.ZERO})


func _puff(at: Vector3, size: float, alpha: float, life: float, color := Color(0.74, 0.73, 0.69)) -> void:
	if _puffs.size() > 420 or measure:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.albedo_texture = puff_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = Vector3.ONE * size
	extras.add_child(mi)
	_puffs.append({"node": mi, "mat": m, "age": 0.0, "life": life, "size": size, "alpha": alpha,
		"drift": Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 0.9), rng.randf_range(-0.6, 0.6))})


func _sim_process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		_last_usec = Time.get_ticks_usec()
		return false
	var now := Time.get_ticks_usec()
	if _sim_frame > 0:
		_step_ms.append((now - _last_usec) / 1000.0)
		_active.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	_last_usec = now
	_sim_time += delta
	for b in _bodies:
		var body: RigidBody3D = b.body
		if body.freeze and _sim_time >= b.at:
			body.freeze = false
			for at: Vector3 in b.get("pins", []):
				var pin := PinJoint3D.new()
				extras.add_child(pin)
				pin.global_position = at
				pin.node_a = pin.get_path_to(body)
			if b.push != Vector3.ZERO:
				body.linear_velocity = b.push
				body.angular_velocity = Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
				if rng.randf() < 0.5:
					_puff(body.position, rng.randf_range(1.5, 2.6), 0.5, 2.2)
			elif body.mass > 400.0 and rng.randf() < 0.5:
				_puff(body.position, rng.randf_range(1.5, 3.0), 0.3, 2.0)   # dust shaken out as it tears free
		elif not body.freeze:
			# dust where something heavy stops short
			var v := body.linear_velocity
			var last: Vector3 = b.last
			if last.y < -3.5 and v.y > last.y * 0.5 and body.mass > 100.0:
				_puff(body.position + Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)), rng.randf_range(3.0, 6.0), 0.42, rng.randf_range(3.0, 5.5))
			b.last = v
	for p in _puffs:
		p.age += delta
		var k: float = clampf(p.age / p.life, 0.0, 1.0)
		(p.node as MeshInstance3D).scale = Vector3.ONE * p.size * (1.0 + 1.6 * sqrt(k))
		(p.node as MeshInstance3D).position += (p.drift as Vector3) * delta
		(p.mat as StandardMaterial3D).albedo_color.a = p.alpha * (1.0 - k) * minf(1.0, p.age * 8.0)
	if not measure:
		root.get_texture().get_image().save_jpg("%s/f_%04d.jpg" % [out, _sim_frame], 0.93)
	_sim_frame += 1
	if _sim_time < sim_seconds:
		return false
	var sorted := _step_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for ms in _step_ms:
		total += ms
	var asleep := 0
	var lines := PackedStringArray()
	for b in _bodies:
		var body: RigidBody3D = b.body
		if body.sleeping:
			asleep += 1
		lines.append("%.2f %.2f %.2f" % [body.position.x, body.position.y, body.position.z])
	print("FRAMES %d  BODIES %d  ASLEEP_AT_END %d  FRAME_MS mean %.2f  p95 %.2f  max %.2f  PEAK_ACTIVE %d" % [_sim_frame, _bodies.size(), asleep, total / maxf(_step_ms.size(), 1), sorted[int(sorted.size() * 0.95)], sorted[-1], _active.max()])
	var pinned := 0
	var hanging := 0
	for b in _bodies:
		if b.has("pins"):
			pinned += 1
			if (b.body as RigidBody3D).position.y > 3.0:
				hanging += 1
	print("PINNED %d  STILL_UP %d  JOINTS %d" % [pinned, hanging, extras.find_children("*", "PinJoint3D", true, false).size()])
	var f := FileAccess.open(out + "/rest.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
	return true
