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
##
## A character can also be one made in the Character Creator (see CustomCharacter):
## its id starts "custom:" and says which robot's legs, torso and head it uses.
## Everything here takes those ids too.

const DIR := "res://game/player/robot/"
const LIST := [
	{"id": "needle", "name": "Needle", "blurb": "Slim and sleek: one glowing eye, thin struts, blade limbs."},
	{"id": "vanguard", "name": "Vanguard", "blurb": "Athletic armoured frame: broad shoulders, helmet with a visor band."},
	{"id": "kestrel", "name": "Kestrel", "blurb": "Scout racer: wedge helmet with crest fins, back thrusters, talon feet."},
	{"id": "bulwark", "name": "Bulwark", "blurb": "Walking tank: three-eyed head in a high collar, dome shoulders, piston legs."},
	{"id": "rivet", "name": "Rivet", "blurb": "Site worker: hard hat, camera-lens eye, hazard stripes, tank backpack."},
	{"id": "specter", "name": "Specter", "blurb": "Stealth frame: hood with a V visor, trailing scarf, blade fins."},
	{"id": "orbit", "name": "Orbit", "blurb": "Gyro bot: glowing orb head in gimbal rings, a glowing core in its chest."},
	{"id": "templar", "name": "Templar", "blurb": "Crusader knight: great helm, white surcoat with a red cross over chain mail."},
]


static func default_id() -> String:
	return LIST[0].id


static func ids() -> Array:
	return LIST.map(func(c): return c.id)


static func has(id: String) -> bool:
	return id in ids() or CustomCharacter.is_custom(id)


## `id` if it is a real character, otherwise the default one. A custom character's
## id comes back rebuilt (see CustomCharacter.normalize).
static func valid(id: String) -> String:
	if CustomCharacter.is_custom(id):
		return CustomCharacter.normalize(id)
	return id if id in ids() else default_id()


static func is_custom(id: String) -> bool:
	return CustomCharacter.is_custom(id)


static func name_of(id: String) -> String:
	return info(id).name


static func info(id: String) -> Dictionary:
	if CustomCharacter.is_custom(id):
		var c := CustomCharacter.parse(id)
		return {"id": c.to_id(), "name": c.name, "blurb": c.blurb()}
	for c in LIST:
		if c.id == id:
			return c
	return LIST[0]


## The character after `id` in the list (wrapping round). After a custom
## character: the robot after the one its torso comes from.
static func next(id: String) -> String:
	if CustomCharacter.is_custom(id):
		id = CustomCharacter.parse(id).torso
	return LIST[(ids().find(valid(id)) + 1) % LIST.size()].id


## The robot a character's skeleton, animations and first-person arms come from:
## itself, or a custom character's torso.
static func base(id: String) -> String:
	if CustomCharacter.is_custom(id):
		return CustomCharacter.parse(id).torso
	return valid(id)


## The full-body model file (a custom character: its torso robot's; RobotModel.build
## puts the rest together).
static func body(id: String) -> String:
	return DIR + base(id) + ".glb"


## The first-person arms and pistol.
static func arms(id: String) -> String:
	return DIR + base(id) + "_arms.glb"
