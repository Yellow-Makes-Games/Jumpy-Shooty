@tool
class_name MapRoot
extends Node3D
## The root node of a map scene (game/maps/*.tscn). Under it go:
##  - MapBlock nodes: everything you stand on, hide behind or look at. Group them
##    under plain Node3D nodes as you like (the maps group each object, so a click
##    selects the whole container or staircase; see docs/DEVELOPMENT.md).
##  - MapSpawn nodes: where players appear.
##  - MapDummy nodes: target dummies to shoot at (test maps).
##  - MapWeaponSpawn nodes (under "WeaponSpawns"): Deathmatch weapon pickups.
##  - Race maps only: MapCheckpoint gates (numbered, the last one the finish),
##    MapHazard blocks (touch one and you go back to your checkpoint), MapMover
##    groups (blocks that slide or spin) and, under "BotRoute", the MapRoutePoint
##    steps bots follow round the course.
##  - MapSpinner groups: scenery that turns (drawn, never solid); MapTerminal consoles
##    players hold interact at, and the MapEvent (GravityEvent) each one sets off.
##  - Label3D nodes: signs and painted numbers.
##  - A WorldEnvironment (sky, ambient light, fog) and a DirectionalLight3D (the sun).
##
## When a match starts, the arena calls build(): every visible MapBlock becomes part
## of one collision body and of one merged mesh per kind, and the spawn list is read.

## Colours for every block kind.
@export var palette: MapPalette:
	set(v):
		if palette and palette.changed.is_connected(_palette_changed):
			palette.changed.disconnect(_palette_changed)
		palette = v
		if palette:
			palette.changed.connect(_palette_changed)
		_palette_changed()

## Darkens faces by the way they point, so plain boxes have some form even in flat
## light: (faces looking along x, faces looking along z, faces looking down).
## Tops stay at full brightness. (1, 1, 1) = off.
@export var face_shade := Vector3.ONE:
	set(v):
		face_shade = v
		_palette_changed()

## Draws a 1 m / 4 m grid on every surface, to judge distance (test maps).
@export var grid_texture := false:
	set(v):
		grid_texture = v
		_palette_changed()

## Editor only: show blocks that are solid but not drawn, as faint blue boxes.
@export var show_invisible_blocks := true:
	set(v):
		show_invisible_blocks = v
		_palette_changed()

@export_group("Rules")
## Falling below this height counts as falling out of the map.
@export var kill_height := -25.0
## Leaving this area (x, z) also counts as falling out. Zero size = no limit.
@export var bounds := Rect2():
	set(v):
		bounds = v
		update_gizmos()
## A high point near the middle that scripted test players swing from.
@export var swing_point := Vector3(0, 5.5, 0):
	set(v):
		swing_point = v
		update_gizmos()

const FALLBACK_PALETTE := "res://game/maps/palettes/construction_site.tres"

## [position, yaw] of every spawn point; filled in by build().
var spawns: Array = []
## [position, yaw, MapDummy] of every target dummy; filled in by build().
var dummies: Array = []
## [position, weapon id] of every Deathmatch weapon pickup (MapWeaponSpawn); filled in by build().
var weapon_spawns: Array = []
## Race maps, filled in by build(). Checkpoints: {number, finish, xf, opening},
## sorted by number. Hazards: {xf, size, shape, mover} (mover = index into movers,
## or -1). Movers: {node: MapMover, base: Transform3D, body: AnimatableBody3D}.
## Route: {pos, action, aim, radius, boost} in running order.
var checkpoints: Array = []
var hazards: Array = []
var movers: Array = []
var route: Array = []
## The map's MapSpinner nodes (scenery that turns), filled in by build().
var spinners: Array = []
## Seconds the map's moving parts have been running (the same on every copy of the
## game: the arena starts it when the match starts).
var clock := 0.0
## If set, the moving parts follow this clock (seconds) instead of counting their own.
var clock_source: Callable
## Set before build(): walls and floors of the palette's breakable kinds can be broken
## (arena matches; never races). Then `destruction` holds them (see MapDestruction).
var destructible := false
var destruction: MapDestruction
## build() made meshes (false in the movement tests).
var has_meshes := true

var _materials := {}
static var _fallback := {}
static var _ghost: StandardMaterial3D


func _ready() -> void:
	# Run on its own (F6 in the editor): play it in practice mode.
	if not Engine.is_editor_hint() and get_tree().current_scene == self:
		var id := scene_file_path
		for m in Maps.LIST:
			if m.scene == id:
				id = m.id
		get_node("/root/Game").call_deferred("start_practice", id)


## The MapRoot a node belongs to, or null.
static func of(node: Node) -> MapRoot:
	while node != null and not node is MapRoot:
		node = node.get_parent()
	return node as MapRoot


## Makes the playable level: collision for every solid block and (unless
## `with_meshes` is false, as in the movement tests) one mesh per kind.
func build(with_meshes: bool = true) -> void:
	var pieces := []
	spawns = []
	checkpoints = []
	hazards = []
	movers = []
	route = []
	weapon_spawns = []
	spinners = []
	_collect(self, Transform3D.IDENTITY, pieces, spawns)
	for s in spinners:
		(s as MapSpinner).build(self, with_meshes)
	checkpoints.sort_custom(func(a, b): return a.number < b.number)
	dummies = []
	_collect_dummies(self, Transform3D.IDENTITY)
	for i in movers.size():
		_build_mover(i, with_meshes)
	has_meshes = with_meshes
	if destructible:
		destruction = MapDestruction.new()
		add_child(destruction)
		pieces = destruction.setup(self, pieces, spawns)
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	for piece in pieces:
		if piece.solid:
			var shape := CollisionShape3D.new()
			shape.shape = _collision_shape(piece)
			shape.transform = piece.xf
			body.add_child(shape)
	if not with_meshes:
		return
	var meshes := MapMesher.build(pieces, face_shade)
	for kind in meshes:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh_%s" % kind
		mesh.mesh = meshes[kind]
		mesh.material_override = material_for(kind)
		add_child(mesh)


## Every visible block as a piece (see MapBlock.to_piece), in the map's frame.
func collect_pieces() -> Array:
	var pieces := []
	_collect(self, Transform3D.IDENTITY, pieces, [])
	return pieces


func _collect(node: Node, xf: Transform3D, pieces: Array, spawn_list: Array, mover: int = -1) -> void:
	for child in node.get_children():
		var at := xf
		if child is Node3D:
			if not (child as Node3D).visible:
				continue   # hidden in the editor: left out of the game
			at = xf * (child as Node3D).transform
		if child is MapSpinner:
			if not spinners.has(child):
				spinners.append(child)   # scenery that turns: it draws its own blocks, none of them solid
			continue
		if child is MapMover and mover == -1:
			# Its blocks are built into a moving body of their own (see _build_mover),
			# in the mover's own frame.
			var m := {"node": child, "base": at, "pieces": [], "body": null}
			movers.append(m)
			_collect(child, Transform3D.IDENTITY, m.pieces, spawn_list, movers.size() - 1)
			continue
		if child is MapBlock:
			pieces.append((child as MapBlock).to_piece(at))
			if child is MapHazard:
				var b := child as MapBlock
				hazards.append({"xf": Transform3D(at.basis.orthonormalized(), at.origin), "size": b.size * at.basis.get_scale().abs(),
					"shape": MapBlock.SHAPE_NAMES[b.shape], "mover": mover})
		elif child is MapSpawn:
			spawn_list.append([at.origin + Vector3(0, 0.2, 0), atan2(at.basis.z.x, at.basis.z.z)])
		elif child is MapWeaponSpawn:
			weapon_spawns.append([at.origin, (child as MapWeaponSpawn).weapon])
		elif child is MapCheckpoint:
			var c := child as MapCheckpoint
			checkpoints.append({"number": c.number, "finish": c.finish, "opening": c.opening,
				"xf": Transform3D(at.basis.orthonormalized(), at.origin)})
		elif child is MapRoutePoint:
			var r := child as MapRoutePoint
			route.append({"pos": at.origin, "action": r.action, "aim": r.aim, "radius": r.radius, "boost": r.boost})
		_collect(child, at, pieces, spawn_list, mover)


## A mover's blocks as one moving body (collision for the solid ones) and meshes.
func _build_mover(index: int, with_meshes: bool) -> void:
	var m: Dictionary = movers[index]
	var body := AnimatableBody3D.new()
	body.name = "Mover_%d" % index
	body.sync_to_physics = false   # moved in _physics_process; it still carries whoever stands on it
	body.transform = m.base
	add_child(body)
	m.body = body
	for piece in m.pieces:
		if piece.solid:
			var shape := CollisionShape3D.new()
			shape.shape = _collision_shape(piece)
			shape.transform = piece.xf
			body.add_child(shape)
	if not with_meshes:
		return
	var meshes := MapMesher.build(m.pieces, face_shade)
	for kind in meshes:
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[kind]
		mesh.material_override = material_for(kind)
		body.add_child(mesh)


## Moves the moving parts to where they are at `clock` seconds.
func update_movers(delta: float) -> void:
	clock = clock_source.call() if clock_source.is_valid() else clock + delta
	for m in movers:
		if m.body:
			(m.body as AnimatableBody3D).transform = m.base * (m.node as MapMover).offset_at(clock)


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and not movers.is_empty():
		update_movers(delta)


## Where a hazard is right now (it may be riding a mover).
func hazard_xf(h: Dictionary) -> Transform3D:
	if h.mover < 0:
		return h.xf
	var m: Dictionary = movers[h.mover]
	return (m.body.transform if m.body else m.base) * h.xf


## Is `point` inside a hazard (grown by `margin` metres all round)? With `at` (a
## map clock time), where the moving ones will be then rather than now.
func hazard_at(point: Vector3, margin: float = 0.0, at: float = -INF) -> bool:
	for h in hazards:
		var xf: Transform3D = hazard_xf(h)
		if at > -INF and h.mover >= 0:
			var m: Dictionary = movers[h.mover]
			xf = m.base * (m.node as MapMover).offset_at(at) * h.xf
		var local := xf.affine_inverse() * point
		var half: Vector3 = h.size * 0.5 + Vector3(margin, margin, margin)
		if absf(local.y) > half.y:
			continue
		if h.shape == "box":
			if absf(local.x) <= half.x and absf(local.z) <= half.z:
				return true
		elif Vector2(local.x, local.z).length() <= half.x:
			return true
	return false


## Will a moving part be there to stand on at `point` at map clock `at`? -1 if no
## moving part ever passes over it (look at the ground itself then), else 0 or 1.
func mover_ground_at(point: Vector3, at: float, tolerance: float = 0.5) -> int:
	var near := false
	for m in movers:
		var mxf: Transform3D = m.base * (m.node as MapMover).offset_at(at)
		for piece in m.pieces:
			if not piece.solid:
				continue
			var local: Vector3 = (mxf * (piece.xf as Transform3D)).affine_inverse() * point
			var half: Vector3 = piece.size * 0.5
			if absf(local.x) > half.x or absf(local.z) > half.z:
				continue
			near = true
			if absf(local.y - half.y) <= tolerance:
				return 1
	return 0 if near else -1


func _collect_dummies(node: Node, xf: Transform3D) -> void:
	for child in node.get_children():
		if not child is Node3D or not (child as Node3D).visible:
			continue
		var at := xf * (child as Node3D).transform
		if child is MapDummy:
			dummies.append([at.origin, atan2(at.basis.z.x, at.basis.z.z), child])
		_collect_dummies(child, at)


func _collision_shape(piece: Dictionary) -> Shape3D:
	if piece.shape == "cyl":
		var c := CylinderShape3D.new()
		c.radius = piece.size.x * 0.5
		c.height = piece.size.y
		return c
	var box := BoxShape3D.new()
	box.size = piece.size
	return box


## The material blocks of this kind are drawn with.
func material_for(kind: String) -> Material:
	if _materials.is_empty():
		_materials = MapScenery.materials(palette, grid_texture)
	if not _materials.has(kind):
		_materials[kind] = MapScenery.missing_material()
	return _materials[kind]


## For blocks outside a map (a scene of its own): the Construction Site's colours.
static func fallback_material(kind: String) -> Material:
	if _fallback.is_empty():
		_fallback = MapScenery.materials(load(FALLBACK_PALETTE), false)
	return _fallback.get(kind, MapScenery.missing_material())


## Editor only: how solid-but-not-drawn blocks look.
static func ghost_material() -> Material:
	if _ghost == null:
		_ghost = StandardMaterial3D.new()
		_ghost.albedo_color = Color(0.35, 0.65, 1.0, 0.12)
		_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _ghost


func _palette_changed() -> void:
	_materials.clear()
	if Engine.is_editor_hint() and is_inside_tree():
		propagate_call("refresh_preview")
		update_gizmos()


func _get_configuration_warnings() -> PackedStringArray:
	return [] if palette else ["Give the map a palette (the colours of its block kinds)."]
