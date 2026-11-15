class_name CameraRig
extends Node3D
## First- and third-person camera for the local player. Both views look from the
## same pivot with the same aim, so gameplay is identical; only the viewpoint moves.
## The third-person view uses a spring arm that shortens when a wall gets in the way.

const EYE_HEIGHT := MovementTuning.EYE_HEIGHT
const TP_DISTANCE := 3.4
const TP_SHOULDER := 0.55
const BLEND_TIME := 0.18
const BODY_LAYER := 2   ## render layer of the local player's own body (hidden in first person)

var pivot: Node3D
var arm: SpringArm3D
var tp_anchor: Node3D
var camera: Camera3D

var _blend := 0.0   # 0 = first person, 1 = third person


func _init() -> void:
	name = "CameraRig"


func setup(body: CollisionObject3D) -> void:
	pivot = Node3D.new()
	pivot.position.y = EYE_HEIGHT
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = TP_DISTANCE
	arm.position = Vector3(TP_SHOULDER, 0.15, 0.0)
	arm.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	arm.add_excluded_object(body.get_rid())
	pivot.add_child(arm)
	tp_anchor = Node3D.new()
	arm.add_child(tp_anchor)
	camera = Camera3D.new()
	camera.top_level = true
	camera.near = 0.05
	camera.far = 800.0
	add_child(camera)
	camera.make_current()
	_blend = 1.0 if Settings.third_person else 0.0
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func set_view(yaw: float, pitch: float) -> void:
	pivot.global_rotation = Vector3(pitch, yaw, 0.0)


func is_third_person() -> bool:
	return Settings.third_person


func _process(delta: float) -> void:
	if not camera:
		return
	var target: float = 1.0 if Settings.third_person else 0.0
	_blend = move_toward(_blend, target, delta / BLEND_TIME)
	var s := smoothstep(0.0, 1.0, _blend)
	var fp := pivot.global_transform
	var tp := tp_anchor.global_transform
	camera.global_transform = fp.interpolate_with(tp, s)
	# Hide our own body while the camera is inside or near it.
	camera.set_cull_mask_value(BODY_LAYER, _blend > 0.35)
	camera.set_cull_mask_value(Player.VIEWMODEL_LAYER, _blend <= 0.35)


func _on_settings_changed() -> void:
	if camera:
		camera.fov = Settings.field_of_view
