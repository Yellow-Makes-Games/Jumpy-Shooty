@tool
class_name MapRoot
extends Node3D
## The root node of a map scene (game/maps/*.tscn). Under it go:
##  - MapBlock nodes: everything you stand on, hide behind or look at. Group them
##    under plain Node3D nodes as you like (the maps group each object, so a click
##    selects the whole container or staircase; see docs/DEVELOPMENT.md).
##  - MapSpawn nodes: where players appear.
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
	_collect(self, Transform3D.IDENTITY, pieces, spawns)
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


func _collect(node: Node, xf: Transform3D, pieces: Array, spawn_list: Array) -> void:
	for child in node.get_children():
		var at := xf
		if child is Node3D:
			if not (child as Node3D).visible:
				continue   # hidden in the editor: left out of the game
			at = xf * (child as Node3D).transform
		if child is MapBlock:
			pieces.append((child as MapBlock).to_piece(at))
		elif child is MapSpawn:
			spawn_list.append([at.origin + Vector3(0, 0.2, 0), atan2(at.basis.z.x, at.basis.z.z)])
		_collect(child, at, pieces, spawn_list)


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
