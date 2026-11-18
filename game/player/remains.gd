class_name Remains
extends RefCounted
## What is left when a player is knocked out: a ragdoll (Ragdoll), or giblets (Gibs)
## when the host says the body was blown apart (Match.death_fx "gib"). Looks only:
## nothing here touches gameplay or hit detection, and every copy of the game makes its
## own. Each stays LIFETIME seconds whether or not its player is back by then, the last
## DISSOLVE_TIME of them burning away (see Dissolve). Settings.gore turns them off.

const DEBRIS_LAYER := 1 << 3   ## physics layer 4: remains collide with the level (layer 1) only
const LIFETIME := 10.0         ## seconds a body stays, whether or not its player has respawned
const DISSOLVE_TIME := 1.5     ## the end of LIFETIME, burning away
const MAX_BODIES := 8          ## at most this many sets of remains at once; the oldest goes first

static var _bodies: Array = []


## Arena: `p` was just knocked out. Returns true when remains took the body's place (the
## player's own model is then hidden until they respawn).
static func spawn(p: Player, fx: Dictionary) -> bool:
	if Settings.gore == "off" or p.racing or Match.death_cause.get(p.peer_id, "") == "fell":
		return false
	var made: Node3D = null
	if fx.get("gib", false) and Settings.gore == "full":
		made = Gibs.spawn(p, fx)
	if made == null:
		made = Ragdoll.spawn(p, fx)
	if made == null:
		return false
	_track(made)
	return true


## How many sets of remains are in the world now (tests).
static func count() -> int:
	_bodies = _bodies.filter(func(b): return is_instance_valid(b))
	return _bodies.size()


static func _track(n: Node3D) -> void:
	_bodies = _bodies.filter(func(b): return is_instance_valid(b))
	_bodies.append(n)
	while _bodies.size() > MAX_BODIES:
		(_bodies.pop_front() as Node3D).queue_free()
