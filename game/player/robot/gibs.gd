class_name Gibs
extends Node3D
## A robot blown apart (see Remains). Not built yet: spawn makes nothing, so a ragdoll
## (or the old body) shows instead.


## `p`'s body in pieces, flung by the killing blow (Match.death_fx), added to the world.
## Returns the node holding them, or null when there are none.
static func spawn(_p: Player, _fx: Dictionary) -> Node3D:
	return null
