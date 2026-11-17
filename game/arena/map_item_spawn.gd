@tool
class_name MapItemSpawn
extends Marker3D
## Deathmatch: a place a power-up floats, waiting to be picked up (see ItemPickup).
## Stand it on a floor; the item hovers about a metre above it. In other games the
## spot is empty. The coloured ghost is editor-only.

@export_enum("damage", "health_small", "health_medium", "uber") var item := "health_small":
	set(v):
		item = v
		if _label:
			_label.text = v.to_upper()

const HOVER := 0.9   ## the same as ItemPickup.HOVER (kept apart so map scenes need no game code)

var _ghost: MeshInstance3D
var _label: Label3D


func _enter_tree() -> void:
	if not Engine.is_editor_hint() or _ghost != null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 1.0, 0.5, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	_ghost = MeshInstance3D.new()
	_ghost.mesh = box
	_ghost.position.y = HOVER
	_ghost.material_override = mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost, false, Node.INTERNAL_MODE_FRONT)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.04
	pad.mesh = disc
	pad.material_override = mat
	_ghost.add_child(pad)
	pad.position.y = 0.03 - HOVER
	_label = Label3D.new()
	_label.text = item.to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.modulate = Color(0.6, 1.0, 0.7)
	_label.position.y = 0.45
	_ghost.add_child(_label)
