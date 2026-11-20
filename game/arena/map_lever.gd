@tool
class_name MapLever
extends MapTerminal
## A big control lever players throw by pressing "interact" (the crane cab on the
## Construction Site). It is a MapTerminal in everything but its looks: the same rules,
## the same Event, Range and Channel Time, and the host decides in the same way. Stand
## it on a floor, build its pedestal from MapBlocks round it, and point Event at a
## MapEvent in the same map (a CraneEvent).
##
## In place of a terminal's ring of light it draws the lever itself, standing out of
## the floor at this node and swinging along the node's own z axis: leaning back
## (toward +z) while it is ready, thrown forward (toward -z) with a clack when someone
## sets it off, and staying there until its event has finished, when it swings back.
## A small lamp beside it (Lamp At) is lit in Light's colour while the lever can be
## thrown and glows amber while it cannot. Nothing about it is on the HUD.

const PULL_SOUND := "lever_pull"
const BUSY_COLOR := Color(1.0, 0.55, 0.1)

## How far it leans either way, in degrees.
@export_range(5.0, 80.0) var lean := 32.0
## How long the lever is, from its pivot to the middle of its knob (metres).
@export var length := 0.7
## How high above this node the lever's pivot is (the top of its pedestal).
@export var pivot_height := 0.55
## The colour of its knob.
@export var knob := Color(0.86, 0.13, 0.1)
## Where its lamp is, from this node (in its own frame).
@export var lamp_at := Vector3(0.28, 1.0, 0.0)

var _arm: Node3D
var _lamp: MeshInstance3D
var _lamp_material: StandardMaterial3D
var _angle := 0.0   # degrees: -lean = back (ready), +lean = thrown


func _build_screen() -> void:
	_angle = -lean
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position.y = pivot_height
	add_child(_arm)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.21, 0.24)
	steel.metallic = 0.6
	steel.roughness = 0.45
	var rod := MeshInstance3D.new()
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.022
	rod_mesh.bottom_radius = 0.03
	rod_mesh.height = length
	rod_mesh.radial_segments = 8
	rod.mesh = rod_mesh
	rod.position.y = length * 0.5
	rod.material_override = steel
	_arm.add_child(rod)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.07
	hub_mesh.bottom_radius = 0.07
	hub_mesh.height = 0.12
	hub_mesh.radial_segments = 10
	hub.mesh = hub_mesh
	hub.rotation.z = PI * 0.5   # its axle lies along x, the way the lever turns
	hub.material_override = steel
	_arm.add_child(hub)
	var ball := MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.075
	ball_mesh.height = 0.15
	ball_mesh.radial_segments = 12
	ball_mesh.rings = 6
	ball.mesh = ball_mesh
	ball.position.y = length
	var red := StandardMaterial3D.new()
	red.albedo_color = knob
	red.roughness = 0.35
	ball.material_override = red
	_arm.add_child(ball)
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_material.albedo_color = light
	_lamp = MeshInstance3D.new()
	_lamp.name = "Lamp"
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.055
	lamp_mesh.height = 0.11
	lamp_mesh.radial_segments = 10
	lamp_mesh.rings = 5
	_lamp.mesh = lamp_mesh
	_lamp.position = lamp_at
	_lamp.material_override = _lamp_material
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamp)
	_pose()


## Where a hand goes to throw it: its knob, wherever the lever has got to.
func hand_point() -> Vector3:
	return _arm.global_transform * Vector3(0.0, length, 0.0) if _arm != null and _arm.is_inside_tree() else focus()


func _pose() -> void:
	if _arm:
		_arm.rotation.x = deg_to_rad(-_angle)   # (+ angle leans it toward -z)


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _arm == null:
		return
	var open := phase == Phase.READY and ready_to_use()
	var thrown := not open
	# Thrown over in a fifth of a second, let back in a little over half of one.
	_angle = move_toward(_angle, lean if thrown else -lean, delta * lean * (10.0 if thrown else 3.5))
	_pose()
	# Ready: steadily lit, breathing a little. Locked: amber, dimmer.
	var colour := light * (0.85 + 0.15 * sin(_time * 3.0)) if open else BUSY_COLOR * 0.75
	_lamp_material.albedo_color = Color(colour.r, colour.g, colour.b)


## Everyone: the host says what state it is in. Thrown: the clack of the lever.
func apply_state(new_phase: int, who: int, how_far: float) -> void:
	var was := phase
	super(new_phase, who, how_far)
	if phase == Phase.BUSY and was != Phase.BUSY and who != 0:
		var dev := _autoload("DevArgs")
		var sound := _autoload("Sound")
		if dev and dev.sound_log:
			print("SFX3D %s" % PULL_SOUND)
		if sound and not sound.silent:
			sound.play_at(PULL_SOUND, focus(), "body")


## A lever does not hum: a hold on it is silent, and the clack says it has gone.
func _start_hum(_gain: float = -16.0) -> void:
	pass


func _refresh_ghost() -> void:
	super()
	if _label:
		_label.text = "LEVER"


func _get_configuration_warnings() -> PackedStringArray:
	return [] if not event.is_empty() else ["Point Event at a MapEvent node in this map (a CraneEvent), or throwing it does nothing."]
