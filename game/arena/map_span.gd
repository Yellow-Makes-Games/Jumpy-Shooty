@tool
class_name MapSpan
extends Node3D
## A walkway that extends and retracts, for a map with two layouts (Cirrus: the
## skyways from the quad, the bridges between islands). Each Node3D directly under it
## is one segment (MapBlocks inside, like any group), in order from the end that is
## fixed, the first child, to the tip, the last. The span runs along its own +z.
##
## `extent` says how much of it is out: 1 = all of it, 0 = none. Going in, the tip
## goes first; each segment draws back toward the fixed end as it goes, and once it
## is most of the way in nobody can stand on it (whoever was on it falls). Coming
## out, a segment grows from the one before it and turns solid as it arrives; a
## player standing in its way is lifted onto it, never trapped inside it. A
## LayoutEvent sets `extent` on every copy of the game from the host's clock.
##
## Blocks of the kinds in `light_kinds` are its warning lights: while it is moving
## they flash one after another along it, toward the end that is going.
##
## Inside a MapIsland the whole span rides the island.

const GROUP := "map_spans"
const SOLID_FROM := 0.8    ## a segment this far out (0..1) can be stood on

## Which of the map's layouts it is out in: 0 (the first: Cirrus's Hub) or 1 (the
## second: Ring). In the other it is drawn in.
@export_range(0, 1) var out_in := 0
## Block kinds that flash while it moves.
@export var light_kinds: PackedStringArray = []

## 0..1: how much of it is out (a LayoutEvent sets this).
var extent := 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if is_equal_approx(v, extent) and _shown_extent >= 0.0:
			return
		extent = v
		_apply()
## It is on the move (a LayoutEvent says so): the lights race.
var racing := false

var _segments: Array = []   # {body, meshes: Node3D, lights: [MeshInstance3D], z0, z1, box: AABB, top: float, solid: bool}
var _shown_extent := -1.0
var _time := 0.0
var _map: MapRoot
var _replay_extent := -1.0   # a killcam playing: how far out it draws it (see MapReplay), or -1


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
		add_to_group(MapReplay.GROUP)


## Its blocks as pieces in its own frame (a fresh list: MapRoot.collect_pieces places them).
func collect_pieces() -> Array:
	var pieces := []
	for child in get_children():
		if child is Node3D and (child as Node3D).visible:
			_collect(child, (child as Node3D).transform, pieces)
	return pieces


func segment_count() -> int:
	return _segments.size()


## Can segment `i` be stood on right now?
func segment_solid(i: int) -> bool:
	return i >= 0 and i < _segments.size() and _segments[i].solid


## Called by MapRoot.build(): one moving body and one set of meshes per segment,
## placed at `base` under `on` (the map, or the body of the mover it rides).
func build(map: MapRoot, on: Node3D, base: Transform3D, with_meshes: bool) -> void:
	_map = map
	for seg in _segments:
		if is_instance_valid(seg.body):
			seg.body.queue_free()
	_segments = []
	for child in get_children():
		if not child is Node3D or not (child as Node3D).visible:
			continue
		var pieces := []
		_collect(child, (child as Node3D).transform, pieces)
		if pieces.is_empty():
			continue
		var body := AnimatableBody3D.new()
		body.name = "%s_%d" % [name, _segments.size()]
		body.sync_to_physics = false   # (it rides whatever it is built on, and carries whoever stands on it)
		body.transform = base
		body.set_meta("span", self)   # (bots ask what they are standing on)
		on.add_child(body)
		var box := AABB()
		var any := false
		var deck_top := 0.0     # the top of its biggest flat piece: where feet go
		var deck_area := 0.0
		for piece in pieces:
			var b: AABB = (piece.xf as Transform3D) * AABB(-(piece.size as Vector3) * 0.5, piece.size)
			if piece.solid and b.size.x * b.size.z > deck_area:
				deck_area = b.size.x * b.size.z
				deck_top = b.end.y
			if piece.solid:
				for lump in map.collision_shapes(piece):
					var shape := CollisionShape3D.new()
					shape.shape = lump
					shape.transform = piece.xf
					body.add_child(shape)
				box = box.merge(b) if any else b
				any = true
		var holder := Node3D.new()
		holder.name = "Meshes"
		body.add_child(holder)
		var lights := []
		if with_meshes:
			var meshes := MapMesher.build(pieces, map.face_shade)
			for kind in meshes:
				var mesh := MeshInstance3D.new()
				mesh.mesh = meshes[kind]
				mesh.material_override = map.material_for(kind)
				holder.add_child(mesh)
				if kind in light_kinds:
					lights.append(mesh)
		_segments.append({"body": body, "meshes": holder, "lights": lights, "z0": box.position.z, "z1": box.end.z,
			"box": box, "top": deck_top, "solid": true})
	# It starts as the first layout has it: out, or drawn in (before the bots'
	# navigation mesh is baked: a walkway that is not there must not be on it).
	extent = 1.0 if out_in == 0 else 0.0
	_shown_extent = -1.0
	_apply()


func _collect(node: Node, xf: Transform3D, pieces: Array) -> void:
	if node is MapBlock:
		pieces.append((node as MapBlock).to_piece(xf))
	for child in node.get_children():
		if child is Node3D and (child as Node3D).visible:
			_collect(child, xf * (child as Node3D).transform, pieces)


func _apply() -> void:
	_shown_extent = extent
	var n := _segments.size()
	_draw(_replay_extent if _replay_extent >= 0.0 else extent)
	for i in n:
		var seg: Dictionary = _segments[i]
		var out := clampf(extent * n - i, 0.0, 1.0)
		var solid := out >= SOLID_FROM
		if solid != seg.solid:
			seg.solid = solid
			var body: AnimatableBody3D = seg.body
			body.set_meta("unhookable", not solid)   # a rope hooked on it lets go (see Grapple)
			# Off every layer while it is in: nothing touches it, and the bots' navigation
			# mesh (baked from layer 1) leaves it out.
			body.collision_layer = 1 if solid else 0
			if solid:
				_lift_players(seg)


## Draws it `amount` (0..1) of the way out: each segment drawn back toward the fixed
## end, squeezed along the span from its near edge.
func _draw(amount: float) -> void:
	var n := _segments.size()
	for i in n:
		var seg: Dictionary = _segments[i]
		var out := clampf(amount * n - i, 0.0, 1.0)
		var holder: Node3D = seg.meshes
		holder.visible = out > 0.02
		var z0: float = seg.z0
		holder.transform = Transform3D(Basis.from_scale(Vector3(1, 1, maxf(out, 0.02))), Vector3(0, 0, z0 * (1.0 - maxf(out, 0.02))))


# Killcams (see MapReplay): drawn as far out as it was (only drawn: whoever stands on
# it in the live match still does).
func replay_capture() -> Variant:
	return extent


func replay_show(state: Variant, next: Variant, u: float, _holder: Node3D) -> void:
	if not (state is float or state is int):
		return
	var e := float(state)
	if next is float or next is int:
		e = lerpf(e, float(next), u)
	if is_equal_approx(e, _replay_extent):
		return
	_replay_extent = e
	_draw(e)


func replay_clear() -> void:
	if _replay_extent < 0.0:
		return
	_replay_extent = -1.0
	_draw(extent)


## A segment has just turned solid: anyone standing in it is stood on it.
func _lift_players(seg: Dictionary) -> void:
	var net := get_node_or_null("/root/Net") if is_inside_tree() else null
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena) or arena.get("players_root") == null:
		return
	var body: AnimatableBody3D = seg.body
	var box: AABB = seg.box
	var to_local := body.global_transform.affine_inverse()
	for player in arena.players_root.get_children():
		if not player.is_local or not player.alive:
			continue
		var feet: Vector3 = to_local * (player as Node3D).global_position
		var inside := feet.x > box.position.x - 0.4 and feet.x < box.end.x + 0.4 and feet.z > box.position.z - 0.4 and feet.z < box.end.z + 0.4
		var top: float = seg.top
		if inside and feet.y < top and feet.y > box.position.y - 1.8:
			feet.y = top + 0.02
			(player as Node3D).global_position = body.global_transform * feet
			if (player as CharacterBody3D).velocity.y < 0.0:
				(player as CharacterBody3D).velocity.y = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _segments.is_empty():
		return
	_time += delta
	var n := _segments.size()
	for i in n:
		for light in _segments[i].lights:
			# Still: all lit. Moving: a flash runs along it toward the tip, three times a second.
			(light as MeshInstance3D).visible = not racing or fposmod(_time * 3.0 - float(i) / maxf(n, 1.0) * 1.5, 1.0) < 0.5
