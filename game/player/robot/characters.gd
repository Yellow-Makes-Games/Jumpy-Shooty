class_name Characters
extends RefCounted
## The robots a player can choose to play as. They differ in looks only: every
## character shares one skeleton, one set of animations, the same hitbox and the
## same movement, so the choice never changes how the game plays.
##
## Each character is two model files made by tools/robot/build.py:
## ID.glb (the full body) and ID_arms.glb (the first-person arms and pistol).
## To add one: add its design to tools/robot/designs.py (and to PLAYABLE there),
## rebuild, and list it here.

const DIR := "res://game/player/robot/"
const LIST := [
	{"id": "needle", "name": "Needle", "blurb": "Slim and sleek: one glowing eye, thin struts, blade limbs."},
	{"id": "vanguard", "name": "Vanguard", "blurb": "Athletic armoured frame: broad shoulders, helmet with a visor band."},
	{"id": "kestrel", "name": "Kestrel", "blurb": "Scout racer: wedge helmet with crest fins, back thrusters, talon feet."},
	{"id": "bulwark", "name": "Bulwark", "blurb": "Walking tank: three-eyed head in a high collar, dome shoulders, piston legs."},
	{"id": "rivet", "name": "Rivet", "blurb": "Site worker: hard hat, camera-lens eye, hazard stripes, tank backpack."},
	{"id": "specter", "name": "Specter", "blurb": "Stealth frame: hood with a V visor, trailing scarf, blade fins."},
	{"id": "orbit", "name": "Orbit", "blurb": "Gyro bot: glowing orb head in gimbal rings, a glowing core in its chest."},
]


static func default_id() -> String:
	return LIST[0].id


static func ids() -> Array:
	return LIST.map(func(c): return c.id)


static func has(id: String) -> bool:
	return id in ids()


## `id` if it is a real character, otherwise the default one.
static func valid(id: String) -> String:
	return id if has(id) else default_id()


static func name_of(id: String) -> String:
	return info(id).name


static func info(id: String) -> Dictionary:
	for c in LIST:
		if c.id == id:
			return c
	return LIST[0]


## The character after `id` in the list (wrapping round).
static func next(id: String) -> String:
	return LIST[(ids().find(valid(id)) + 1) % LIST.size()].id


## The full-body model file.
static func body(id: String) -> String:
	return DIR + valid(id) + ".glb"


## The first-person arms and pistol.
static func arms(id: String) -> String:
	return DIR + valid(id) + "_arms.glb"
