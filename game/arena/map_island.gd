@tool
class_name MapIsland
extends MapMover
## A group of blocks that flies: a building island that can stand anywhere round a
## middle point, at any height, or be parked far below the map (Cirrus). Put MapBlocks
## under it like under any group. In the game they become one moving body that carries
## anyone standing on it, and everything else inside the group rides along: spawn
## points, weapon and power-up spots, grapple points, jump links, breakable glass.
##
## Where it sits in the scene is its home. A pose says where it is instead: turned so
## many degrees round `pivot`, so many metres up, so many metres further out (it
## turns with the swing, so the side that faced the pivot still does). A LayoutEvent
## gives it the pose it comes from and the one it goes to and moves `blend` between
## them, on every copy of the game from the host's clock, so it is in the same place
## for everyone. (Travel, Period, Spin, Phase and Hold, a plain MapMover's settings, do
## nothing here.)

const GROUP := "map_islands"

## The point (in the map's frame) it turns round: the middle of the quad.
@export var pivot := Vector3.ZERO

## Degrees a second it goes round the pivot for as long as a match runs, if the map
## has an OrbitEvent (Empyrean Tower's drifting debris). 0: it stays where a
## LayoutEvent puts it.
@export var orbit := 0.0

## MapRoot moves this node along with the body it builds (see MapRoot.update_movers).
var carries_nodes := true
## Where it comes from and where it goes: (degrees round the pivot, metres up, metres out).
var pose_a := Vector3.ZERO
var pose_b := Vector3.ZERO
## 0 = at pose_a, 1 = at pose_b, in between on the way (a LayoutEvent sets it).
var blend := 0.0
## It is standing where people can be (not parked below, not on its way up).
var up := true
## It goes down at the next move (the warning is on): get off.
var doomed := false
## Metres it sags under its pose (a doomed island's engines failing).
var dip := 0.0

var _base: Transform3D
var _has_base := false
var _body: Node3D
var _parked := false
var _sputter_mats := {}    # MeshInstance3D -> its own failing-engine material


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
		_base_xf()   # (before anything moves it)


## MapRoot.build() says which body it made for this island.
func built(body: Node3D) -> void:
	_body = body
	_parked = false
	_sputter_mats.clear()


## The offset from where it sits in the scene, right now (MapRoot asks).
func offset_at(_t: float) -> Transform3D:
	return _base_xf().affine_inverse() * pose_of(pose_a.lerp(pose_b, blend) - Vector3(0, dip, 0))


## Where a pose puts it, in the map's frame.
func pose_of(pose: Vector3) -> Transform3D:
	var base := _base_xf()
	var rel := base.origin - pivot
	var flat := Vector2(rel.x, rel.z)
	var r := flat.length()
	var turn := Basis(Vector3.UP, deg_to_rad(pose.x))
	var out := Vector3.ZERO
	if r > 0.001:
		flat = flat / r * maxf(r + pose.z, 0.0)
		out = turn * Vector3(flat.x, 0.0, flat.y)
	return Transform3D(turn * base.basis, pivot + Vector3(out.x, rel.y + pose.y, out.z))


## Parked: far below the map, not drawn and not there to bump into (nor for the bots'
## navigation mesh to be worked out over).
func set_parked(on: bool) -> void:
	if on == _parked or _body == null:
		return
	_parked = on
	_body.visible = not on
	if _body is CollisionObject3D:
		(_body as CollisionObject3D).collision_layer = 0 if on else 1


func is_parked() -> bool:
	return _parked


## Its engines failing, `amount` 0..1: the meshes of `kinds` glow `color` and flicker
## instead of burning steadily. 0 puts them back.
func sputter(amount: float, kinds: PackedStringArray, color: Color, time: float) -> void:
	if _body == null or (amount <= 0.0 and _sputter_mats.is_empty()):
		return
	var map := MapRoot.of(self)
	for child in _body.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.has_meta("kind") or not kinds.has(mesh.get_meta("kind")):
			continue
		if amount <= 0.0:
			mesh.material_override = map.material_for(mesh.get_meta("kind")) if map else null
			continue
		if not _sputter_mats.has(mesh):
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.emission_enabled = true
			_sputter_mats[mesh] = mat
		var own: StandardMaterial3D = _sputter_mats[mesh]
		var flicker := 0.5 + 0.5 * sin(time * 31.0) * sin(time * 7.3 + 1.0)
		own.albedo_color = color
		own.emission = color
		own.emission_energy_multiplier = lerpf(1.2, 4.5, flicker) * (0.4 + 0.6 * amount)
		mesh.material_override = own
	if amount <= 0.0:
		_sputter_mats.clear()


## Where it sits in the scene, in the map's frame.
func _base_xf() -> Transform3D:
	if _has_base:
		return _base
	var xf := transform
	var node := get_parent()
	while node != null and not node is MapRoot:
		if node is Node3D:
			xf = (node as Node3D).transform * xf
		node = node.get_parent()
	_base = xf
	_has_base = not Engine.is_editor_hint()   # (in the editor it may be dragged about: ask again)
	return xf
