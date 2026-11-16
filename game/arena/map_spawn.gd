@tool
class_name MapSpawn
extends Marker3D
## A place players appear. Stand it on a floor and turn it (around y) to face the
## way players should look. The green figure is only shown in the editor.

var _figure: MeshInstance3D


func _enter_tree() -> void:
	if not Engine.is_editor_hint() or _figure != null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.95, 0.45, 0.55)
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
	var nose := MeshInstance3D.new()   # points the way the player will face
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.7)
	nose.mesh = box
	nose.position = Vector3(0, 0.6, -0.55)
	nose.material_override = mat
	_figure.add_child(nose)
