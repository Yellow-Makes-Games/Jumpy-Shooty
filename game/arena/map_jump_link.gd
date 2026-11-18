@tool
class_name MapJumpLink
extends Marker3D
## Tells bots how to cross a gap the navigation mesh cannot join: where to stand (this
## node), what to do, and where they come down. Cirrus uses them for the quad in its
## Ring layout, which only the grapple reaches: a bot that wants to be over there
## walks to the nearest link, hooks the grapple point the link names and lets the
## rope carry it over; to come back it runs off the edge toward the island below.
##
## Put one on the floor where the crossing starts, a little back from the edge.
## Inside a MapIsland it rides the island, like its hook and landing if they are
## inside one too. Bots only use a link when walking will not get them where they
## are going (see BotBrain). People need none of this: it is the route a person would
## take anyway.

enum How {
	GRAPPLE,   ## aim at Hook, fire the grapple, ride the rope, let go and steer to Landing
	LEAP,      ## run at Landing and off the edge, steering in the air (a drop to somewhere lower)
}

const GROUP := "map_jump_links"

@export var how := How.GRAPPLE
## What to hook (a MapGrapplePoint, or any Node3D on something solid). Grapple only.
@export_node_path("Node3D") var hook: NodePath
## Where the bot comes down: a Node3D on the floor over there.
@export_node_path("Node3D") var landing: NodePath
## The layout it is for: 0 or 1 (see LayoutEvent), or -1 for a map with one layout.
@export var layout := -1


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## Can it be used right now? (Not in the other layout, nor while the map is moving.)
func usable() -> bool:
	var map := MapRoot.of(self)
	if map == null:
		return true
	return not map.shifting and (layout < 0 or map.layout_state == layout)


func takeoff() -> Vector3:
	return global_position


func hook_point() -> Vector3:
	var node := get_node_or_null(hook) as Node3D
	return node.global_position if node else Vector3.INF


func landing_point() -> Vector3:
	var node := get_node_or_null(landing) as Node3D
	return node.global_position if node else global_position
