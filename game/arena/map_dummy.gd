@tool
class_name MapDummy
extends Marker3D
## A target dummy: a robot that stands still and can be shot (test maps). Shots on
## it give the same hit markers, damage numbers and headshots as a player, and a
## readout over its head shows the damage. Stand it on a floor and turn it (around
## y) to face the way it should look. The orange figure is only shown in the editor.

## Which robot it looks like (an id from Characters).
@export var character := "vanguard"
## The gun it holds (an id from WeaponData).
@export var gun := "rifle"
## Shown over its head with the readout, e.g. the distance from the firing line.
@export var caption := ""

var _figure: MeshInstance3D


func _enter_tree() -> void:
	if not Engine.is_editor_hint() or _figure != null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.2, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.8
	_figure = MeshInstance3D.new()
	_figure.mesh = body
	_figure.position.y = 0.9
	_figure.material_override = mat
	_figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_figure, false, Node.INTERNAL_MODE_FRONT)
	var nose := MeshInstance3D.new()   # points the way the dummy faces
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.7)
	nose.mesh = box
	nose.position = Vector3(0, 0.6, -0.55)
	nose.material_override = mat
	_figure.add_child(nose)
