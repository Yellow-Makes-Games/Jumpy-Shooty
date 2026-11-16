class_name RobotModel
extends Node3D
## One robot on screen: the model from a .glb file, coloured for its player.
## RobotAnimator poses its skeleton every frame.

const VIEW_SHADER := "res://game/player/robot/viewmodel.gdshader"
const VISOR_ENERGY := 1.6

var rig: RobotRig
var skeleton: Skeleton3D
var mesh: MeshInstance3D

var _glow_materials: Array = []   # [material, is_shader]
var _glow_color := Color.WHITE


## The colour used on a robot's trim and visor: the player colour, made more vivid.
static func trim_color(player_color: Color) -> Color:
	return Color.from_hsv(player_color.h, minf(player_color.s * 1.35, 1.0), player_color.v)


## viewmodel: draw with the first-person shader (own field of view, never clips into walls).
func setup(path: String, player_color: Color, viewmodel: bool = false) -> RobotModel:
	rig = RobotRig.open(path)
	var node := rig.scene.instantiate()
	add_child(node)
	skeleton = node.find_child("Skeleton3D", true, false)
	var player := node.find_child("AnimationPlayer", true, false)
	if player:
		player.free()   # RobotAnimator plays the clips itself
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			mesh = c
	var trim := trim_color(player_color)
	_glow_color = trim
	for i in mesh.mesh.get_surface_count():
		var base: StandardMaterial3D = mesh.mesh.surface_get_material(i)
		var kind := base.resource_name
		var color := trim if kind == "accent" else base.albedo_color
		if viewmodel:
			var sm := ShaderMaterial.new()
			sm.shader = load(VIEW_SHADER)
			sm.set_shader_parameter("albedo", color)
			sm.set_shader_parameter("roughness", base.roughness)
			sm.set_shader_parameter("metallic", base.metallic)
			if kind == "visor":
				sm.set_shader_parameter("emission", trim * VISOR_ENERGY)
				_glow_materials.append([sm, true])
			mesh.set_surface_override_material(i, sm)
		elif kind == "accent" or kind == "visor":
			var m: StandardMaterial3D = base.duplicate()
			if kind == "visor":
				m.emission_enabled = true
				m.emission = trim
				m.emission_energy_multiplier = VISOR_ENERGY
				_glow_materials.append([m, false])
			else:
				m.albedo_color = color
			mesh.set_surface_override_material(i, m)
	if viewmodel:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 10.0   # the shader moves it on screen; never cull it
	return self


## Where a marker bone ("muzzle", "grapple") is in the world right now.
func marker(bone: String) -> Vector3:
	var i: int = rig.bones.get(bone, -1)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## How brightly the visor and lights glow: 1 = on, 0 = powered down (dead).
func set_power(power: float) -> void:
	for entry in _glow_materials:
		if entry[1]:
			(entry[0] as ShaderMaterial).set_shader_parameter("emission", _glow_color * VISOR_ENERGY * power)
		else:
			(entry[0] as StandardMaterial3D).emission_energy_multiplier = VISOR_ENERGY * power


func set_layer(layer: int) -> void:
	mesh.layers = 1 << (layer - 1)
