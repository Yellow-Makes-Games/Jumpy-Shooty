class_name Ragdoll
extends Node3D
## A knocked-out robot falling as a ragdoll (see Remains). Not built yet: spawn makes
## nothing, so the body stays as it always has.


## A ragdoll in place of `p`'s body, thrown by the killing blow (Match.death_fx), added
## to the world. Returns it, or null when there is none.
static func spawn(_p: Player, _fx: Dictionary) -> Node3D:
	return null
