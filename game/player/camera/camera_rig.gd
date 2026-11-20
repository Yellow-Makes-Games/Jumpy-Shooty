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
const VIEW_BODY_LAYER := 4   ## your own legs and torso as seen in first person (hidden in third person)
const BODY_SWAP := 0.35   ## how far toward third person the view switches to the full body
const VIEW_BODY_UNTIL := 0.03  ## the first-person body goes as soon as the camera pulls out (it has no head)

const KICK_ZOOM := 0.09   ## how far a full kick() narrows the field of view, as a share of it
const RUSH_WIDEN := 0.06  ## how far a full rush() widens it
const GLIDE_WIDEN := 0.07 ## first person: how far a fast glide widens the field of view, as a share of it
const ZOOM_FOV := 30.0    ## zoomed in (a pseudo aim down sights): this many degrees off your field of view...
const ZOOM_MIN_FOV := 40.0  ## ...but never narrower than this
const ZOOM_TIME := 0.12   ## seconds to zoom in or out

## Set every frame by the player: how much a glide's speed widens the view now, 0..1.
var glide_widen := 0.0
## Set every frame by the player: zoomed in (the zoom button), or not. The view eases
## to zoom_fov() and back; the player turns slower by aim_scale() as it does, so the
## aim feels the same.
var zoom := false

var pivot: Node3D
var arm: SpringArm3D
var tp_anchor: Node3D
var camera: Camera3D

var _blend := 0.0   # 0 = first person, 1 = third person
var _kick := 0.0    # the view punched in by a heavy landing (see kick), easing back
var _rush := 0.0    # the view widened by a burst of speed (see rush), easing back
var _widen := 0.0   # the view widened by a glide (eases toward glide_widen)
var _zoom := 0.0    # 0 = not zoomed, 1 = zoomed (eases toward zoom)
## The first-person view is this far (a world offset) from the eyes: coming out of a
## portal it starts where the eyes would be had you walked through, and the player
## eases this to nothing (Player.view_carried).
var shift := Vector3.ZERO


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


## eye: eye height above the feet (lower when crouched). roll: head tilt in radians
## (leaning away from a wall while wall-running).
func set_view(yaw: float, pitch: float, eye: float = EYE_HEIGHT, roll: float = 0.0) -> void:
	pivot.position.y = eye
	pivot.global_rotation = Vector3(pitch, yaw, roll)


func is_third_person() -> bool:
	return Settings.third_person


## 1 while the first-person body is shown, falling to 0 by the time the full body
## is (on the way to third person). The body is placed and posed by this.
func first_person_amount() -> float:
	return 1.0 - clampf((_blend - VIEW_BODY_UNTIL) / (BODY_SWAP - VIEW_BODY_UNTIL), 0.0, 1.0)


func _process(delta: float) -> void:
	if not camera:
		return
	var target: float = 1.0 if Settings.third_person else 0.0
	var before := _blend
	_blend = move_toward(_blend, target, delta / BLEND_TIME)
	place()
	# Hide our own body while the camera is inside or near it.
	camera.set_cull_mask_value(BODY_LAYER, _blend > BODY_SWAP)
	# (The player placed the first-person body for last frame's blend, so wait for both.)
	camera.set_cull_mask_value(VIEW_BODY_LAYER, maxf(_blend, before) <= VIEW_BODY_UNTIL)
	camera.set_cull_mask_value(Player.VIEWMODEL_LAYER, _blend <= BODY_SWAP)
	var widen := glide_widen * (1.0 - _blend)   # (first person only)
	var zoom_to := 1.0 if zoom else 0.0
	if _kick > 0.0 or _rush > 0.0 or _widen > 0.0 or widen > 0.0 or _zoom != zoom_to:
		_kick = maxf(_kick - delta * 3.5, 0.0)
		_rush = maxf(_rush - delta * 3.0, 0.0)
		_widen = move_toward(_widen, widen, delta * (2.5 if widen > _widen else 1.5))
		_zoom = move_toward(_zoom, zoom_to, delta / ZOOM_TIME)
		camera.fov = view_fov() * (1.0 - KICK_ZOOM * _kick * _kick * Settings.camera_shake) * (1.0 + RUSH_WIDEN * _rush * _rush) \
			* (1.0 + GLIDE_WIDEN * smoothstep(0.0, 1.0, _widen))


## The field of view when zoomed in: yours, less ZOOM_FOV.
static func zoom_fov() -> float:
	return maxf(Settings.field_of_view - ZOOM_FOV, minf(ZOOM_MIN_FOV, Settings.field_of_view))


## The field of view now, before the kicks and glides: yours, or on the way to zoom_fov().
func view_fov() -> float:
	return lerpf(Settings.field_of_view, zoom_fov(), smoothstep(0.0, 1.0, _zoom))


## How much slower the mouse turns the view now: as much as the view is narrower (the
## same mouse movement moves things on screen as far, zoomed in or not).
func aim_scale() -> float:
	return tan(deg_to_rad(view_fov()) * 0.5) / tan(deg_to_rad(Settings.field_of_view) * 0.5)


## Puts the camera where this frame's view is. The rig does it every frame, but
## after the player's own frame work (it is the player's child): the player calls
## this as soon as it has set the view, so that what it places afterwards from the
## camera (the first-person arms hang off it; ropes and tracers start at them) is
## where this frame is drawn, not where the last one was. A frame behind, a rope
## starts beside the wrist it leaves as soon as you move or turn.
func place() -> void:
	if not camera:
		return
	var s := smoothstep(0.0, 1.0, _blend)
	camera.global_transform = pivot.global_transform.interpolate_with(tp_anchor.global_transform, s)
	if shift != Vector3.ZERO:
		camera.global_position += shift * (1.0 - s)


## The view punches in for a moment and eases back (`amount` 0..1): the landing of a ground slam.
func kick(amount: float) -> void:
	_kick = clampf(maxf(_kick, amount), 0.0, 1.0)


## The view widens for a moment and eases back (`amount` 0..1): shot out of a portal.
func rush(amount: float) -> void:
	_rush = clampf(maxf(_rush, amount), 0.0, 1.0)


func _on_settings_changed() -> void:
	if camera:
		camera.fov = view_fov()
