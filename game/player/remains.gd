class_name Remains
extends RefCounted
## What is left when a player is knocked out: a ragdoll (Ragdoll), or giblets (Gibs)
## when the host says the body was blown apart (Match.death_fx "gib"). Looks only:
## nothing here touches gameplay or hit detection, and every copy of the game makes its
## own. Each stays LIFETIME seconds whether or not its player is back by then, the last
## DISSOLVE_TIME of them burning away (see Dissolve). Settings.gore turns them off.
##
## Killcam records how each one falls, so a replay can show it falling the same way
## (with copies of its own: see KillcamView). Those copies are not counted here.

const DEBRIS_LAYER := 1 << 3   ## physics layer 4: remains collide with the level (layer 1) only
const LIFETIME := 10.0         ## seconds a body stays, whether or not its player has respawned
const DISSOLVE_TIME := 1.5     ## the end of LIFETIME, burning away
const MAX_BODIES := 8          ## at most this many sets of remains at once; the oldest goes first

static var _bodies: Array = []
static var _hidden := false


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
	return bodies().size()


## The remains in the world now (each a Ragdoll or Gibs), oldest first.
static func bodies() -> Array:
	_bodies = _bodies.filter(func(b): return is_instance_valid(b))
	return _bodies


## Hides them all, and any made while hidden, or shows them again: the death killcam
## draws the fall again from its recording, and the bodies lying in the arena now would
## be in the way (as the live players are, see Killcam).
static func set_hidden(on: bool) -> void:
	_hidden = on
	for b in bodies():
		(b as Node3D).visible = not on


static func _track(n: Node3D) -> void:
	_bodies = _bodies.filter(func(b): return is_instance_valid(b))
	_bodies.append(n)
	n.visible = not _hidden
	while _bodies.size() > MAX_BODIES:
		(_bodies.pop_front() as Node3D).queue_free()
