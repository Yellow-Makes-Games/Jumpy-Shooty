@tool
class_name MapBlock
extends Node3D
## One piece of a map: a box, a cylinder or a tube, painted with a "kind" from the
## map's palette. Move and turn it like any node; resize it with the inspector's
## Size or by dragging the orange handles on its faces (see addons/map_tools).
##
## In the game, MapRoot.build() merges every block into one mesh per kind and one
## collision body, so a map of thousands of blocks still draws in a few calls. A
## block (or a group of them) hidden with the eye icon is left out of the game.

enum Shape { BOX, CYLINDER, TUBE }

@export var shape := Shape.BOX:
	set(v):
		shape = v
		notify_property_list_changed()
		_changed()

## Box: width (x), height (y), depth (z). Cylinder and tube: diameter (x) and
## height (y), standing along the block's own y axis; z is not used.
@export var size := Vector3.ONE:
	set(v):
		size = v.max(Vector3(0.01, 0.01, 0.01))
		_changed()

## Which colour from the map's palette.
@export var kind := "concrete":
	set(v):
		kind = v
		_changed()

## You bump into it and stand on it. Off: drawn only (paint on the floor, thin rods).
@export var solid := true

## You can see it. Off: an invisible wall, often a plain box under finer drawn parts.
@export var drawn := true:
	set(v):
		drawn = v
		_changed()

## Multiplied into the kind's colour, to make one block a little lighter or darker.
@export var tint := Color.WHITE:
	set(v):
		tint = v
		_changed()

## Cylinders and tubes: how many flat sides.
@export_range(3, 48) var sides := 12:
	set(v):
		sides = v
		_changed()

## Tubes: the inside diameter.
@export var inner := 0.0:
	set(v):
		inner = v
		_changed()

const SHAPE_NAMES := ["box", "cyl", "tube"]

var _preview: MeshInstance3D
var _triangles: TriangleMesh
var _shaded_for := Basis()   # the world orientation the preview's face shading was made for


## This block as a piece for MapMesher and the collision builder. `xf` is where it
## sits (from MapRoot); any scale in it is folded into the size.
func to_piece(xf: Transform3D) -> Dictionary:
	var scale := xf.basis.get_scale().abs()
	var piece := {
		"xf": Transform3D(xf.basis.orthonormalized(), xf.origin),
		"size": size * scale, "kind": kind, "solid": solid, "shape": SHAPE_NAMES[shape],
	}
	if not drawn:
		piece["hidden"] = true
	if tint != Color.WHITE:
		piece["tint"] = tint
	if shape != Shape.BOX:
		piece["sides"] = sides
	if shape == Shape.TUBE:
		piece["inner"] = inner * scale.x
	return piece


## Moves one face (0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z) to `reach` from the block's
## centre (in its own units), keeping the opposite face where it is. On a cylinder
## or tube, faces 0 to 1 and 4 to 5 set the diameter instead. Sizes snap to `step`.
## Used by the resize handles (addons/map_tools/block_gizmo.gd).
func move_face(face: int, reach: float, step: float) -> void:
	var axis := face / 2
	var dir := 1.0 if face % 2 == 0 else -1.0
	if shape != Shape.BOX and axis != 1:
		var d := maxf(roundf(reach * 2.0 / step) * step, step)
		size = Vector3(d, size.y, d)
		return
	var length := maxf(roundf((reach + size[axis] * 0.5) / step) * step, step)
	var shift := Vector3.ZERO
	shift[axis] = (length - size[axis]) * 0.5 * dir
	var new_size := size
	new_size[axis] = length
	size = new_size
	position += transform.basis * shift


# ---------------------------------------------------------------------------
# Editor preview (in the game the merged meshes take over)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		refresh_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _preview != null:
		# Moving needs nothing; turning changes which faces are shaded darker.
		if not global_basis.orthonormalized().is_equal_approx(_shaded_for):
			refresh_preview()


func _changed() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		refresh_preview()
		update_configuration_warnings()


## Redraws this block in the editor (MapRoot calls it when the palette changes).
func refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var root := MapRoot.of(self)
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	_shaded_for = global_basis.orthonormalized()
	var piece := to_piece(Transform3D.IDENTITY)
	piece.erase("hidden")
	var shade := root.face_shade if root else Vector3.ONE
	var meshes := MapMesher.build([piece], shade, _shaded_for)
	_preview.mesh = meshes.get(kind)
	var shown := drawn or root == null or root.show_invisible_blocks
	_preview.visible = shown
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if drawn:
		_preview.material_override = root.material_for(kind) if root else MapRoot.fallback_material(kind)
	else:
		_preview.material_override = MapRoot.ghost_material()
	_triangles = _preview.mesh.generate_triangle_mesh() if shown and _preview.mesh else null
	update_gizmos()


## For the editor gizmo: what you click to select this block.
func preview_triangles() -> TriangleMesh:
	return _triangles


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"kind":
			var root := MapRoot.of(self) if is_inside_tree() else null
			if root and root.palette:
				property.hint = PROPERTY_HINT_ENUM_SUGGESTION
				property.hint_string = ",".join(root.palette.colors.keys())
		"sides":
			if shape == Shape.BOX:
				property.usage &= ~PROPERTY_USAGE_EDITOR
		"inner":
			if shape != Shape.TUBE:
				property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	var root := MapRoot.of(self)
	if root == null:
		return ["A map block only shows up in the game inside a map (a scene whose root is a MapRoot)."]
	if root.palette and not root.palette.colors.has(kind):
		return ["The map's palette has no colour for \"%s\"." % kind]
	return []
