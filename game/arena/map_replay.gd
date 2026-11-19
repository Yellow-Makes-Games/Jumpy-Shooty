class_name MapReplay
extends RefCounted
## Killcams and the map's moving parts: a crane that swings its load round, an island
## that flies, a wall shot through, a walkway that draws in, furniture that slides
## about. A killcam (see Killcam and KillcamView) records what each of them looked like
## while it records the players, and a replay puts them back the way they were at each
## moment, so a kill made from the crane's slab replays on the slab, and a wall that
## was shot through later stands whole until the shot that broke it.
##
## A part takes part by joining the group GROUP and having three methods:
##
##   replay_capture() -> Variant
##       What it looks like right now, as a plain value (numbers, vectors,
##       transforms, arrays and dictionaries of them). Called about 30 times a
##       second while a match is recorded, so keep it cheap; it is only stored when it
##       differs (==) from the last one.
##
##   replay_show(state: Variant, next: Variant, u: float, holder: Node3D) -> void
##       Look the way `state` says (blended `u` 0..1 toward `next`; `next` is null
##       outside the recording, and a part that cannot blend just shows `state`).
##       Called every frame of a replay. It must only change what is DRAWN, never
##       collision or anything the game plays by: a death killcam plays in the live
##       arena while the match goes on round it (the host's bots are still standing
##       on that crane). `holder` is the replay's own node: anything made for the
##       replay can go under it, and goes with it.
##
##   replay_clear() -> void
##       The replay is over (or starts again): back to drawing the live state.
##
## A part is found again by its path from its MapRoot, so the same part answers in the
## live arena and in the copy of the map the results screen plays the best kills in.
## Make the nodes that join the group (and the nodes they build at runtime) the same
## every time the map is built.
##
## Parts that do it now: MapRoot (every MapMover and MapIsland: their bodies, meshes
## and the signs and lamps riding them), MapDestruction (cracked and broken walls),
## CraneEvent (its hoist rope) and MapSpan (walkways in and out). A new kind of moving
## part, on a new map, does the same three things and it is in every killcam.

const GROUP := "replay_props"
const DESTRUCTION_KEY := "Breakables"   ## MapDestruction's key (it is that node under the map)


## The map's parts that are recorded: [key (path from the map), node], in a steady order.
static func parts(map: Node) -> Array:
	var out := []
	if map == null or not is_instance_valid(map) or not map.is_inside_tree():
		return out
	for node in map.get_tree().get_nodes_in_group(GROUP):
		if node == map or map.is_ancestor_of(node):
			out.append([str(map.get_path_to(node)), node])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## Whether a copy of the map built to play these clips (KillClip, nulls skipped) needs
## its breakable walls (MapRoot.destructible): one of them recorded them.
static func wants_destruction(clips: Array) -> bool:
	for clip in clips:
		if clip != null and (clip.get("props") as Dictionary).has(DESTRUCTION_KEY):
			return true
	return false


## The part at `key` in `map`, or null.
static func find(map: Node, key: String) -> Node:
	if map == null or not is_instance_valid(map):
		return null
	var node := map.get_node_or_null(NodePath(key))
	return node if node != null and node.has_method("replay_show") else null


## Everything drawn under `node` (meshes, signs, lamps), at any depth.
static func drawn_under(node: Node) -> Array:
	var out: Array = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		out.append(node)
	return out


## Draws `v` at `xf` without moving the node (the game goes on seeing it where it is).
## Holds until the node moves again; call it again each frame before drawing.
static func draw_at(v: VisualInstance3D, xf: Transform3D) -> void:
	if is_instance_valid(v) and v.is_inside_tree():
		RenderingServer.instance_set_transform(v.get_instance(), xf)


## Back to drawing `v` where it is.
static func draw_live(v: VisualInstance3D) -> void:
	if is_instance_valid(v) and v.is_inside_tree():
		RenderingServer.instance_set_transform(v.get_instance(), v.global_transform)
