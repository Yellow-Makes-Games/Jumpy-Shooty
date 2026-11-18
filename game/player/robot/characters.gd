class_name Characters
extends RefCounted
## The characters a player can choose to play as. They differ in looks only: every
## character shares one skeleton, one set of animations, the same hitbox and the
## same movement, so the choice never changes how the game plays.
##
## Each character is two model files made by tools/robot/build.py:
## ID.glb (the full body) and ID_arms.glb (the first-person arms and pistol).
## To add one: add its design to tools/robot/designs.py (and to PLAYABLE there),
## rebuild, and list it here.
##
## A character can also be one made in the Character Creator (see CustomCharacter):
## its id starts "custom:" and says whose legs, torso and head it uses.
## Everything here takes those ids too.
##
## The creator's parts are not only robots'. KITS are the other bodies it can take
## a head, a torso or legs from: a person, a goblin, a frog... Each is one small
## file of body parts (kits/ID.glb, from tools/robot/creatures.py) with no guns and
## no animations of its own: a character with a kit's torso moves on a robot's
## skeleton (see base) and RobotModel puts the parts on it. To add one: add its
## design to creatures.py (and to KITS there), rebuild, and list it here.

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

const KIT_DIR := DIR + "kits/"
const KITS := [
	{"id": "human", "name": "Dude", "blurb": "A person: short hair, a T-shirt, jeans and trainers."},
	{"id": "goblin", "name": "Goblin", "blurb": "Great pointed ears, a long nose, fangs, a leather tunic and clawed feet."},
	{"id": "frog", "name": "Frog", "blurb": "A wide head with eyes on top, a pale belly, long legs and webbed feet."},
	{"id": "skeleton", "name": "Bones", "blurb": "A skeleton: glowing eyes in a skull, a rib cage with a heart in it."},
	{"id": "alien", "name": "Zorp", "blurb": "A little grey visitor: a great bulb of a head, huge black eyes, long fingers."},
	{"id": "cat", "name": "Whiskers", "blurb": "A ginger cat: pointed ears, green eyes, white paws, a long tail, a bell on its collar."},
	{"id": "rex", "name": "Rex", "blurb": "A small dinosaur: a snout full of teeth, a thick tail, claws, spines down its back."},
	{"id": "yeti", "name": "Yeti", "blurb": "A shaggy snow beast: a blue face in white fur, small horns, huge hands and feet."},
	{"id": "duck", "name": "Quackers", "blurb": "A yellow duck: an orange bill, feathered wings, webbed feet, a neckerchief."},
	{"id": "jack", "name": "Jack", "blurb": "A pumpkin-headed scarecrow: a glowing carved face, a flannel shirt stuffed with straw."},
	{"id": "astronaut", "name": "Cosmo", "blurb": "An astronaut: a round helmet with a gold visor, a puffy suit, a pack on the back."},
	{"id": "imp", "name": "Imp", "blurb": "A little devil: curling horns, a toothy grin, hooves and a tail with a spade on it."},
	{"id": "snowman", "name": "Frosty", "blurb": "A snowman: coal eyes, a carrot nose, stick arms in mittens, a scarf."},
	{"id": "shark", "name": "Chomp", "blurb": "A shark on two legs: rows of teeth, a white belly, fins on its back and arms."},
	{"id": "ninja", "name": "Ninja", "blurb": "Wrapped head to toe, only the eyes showing; a headband and a sash."},
	{"id": "zombie", "name": "Zombie", "blurb": "A person, some time after: green skin, a bit of brain showing, one shoe."},
	{"id": "wizard", "name": "Wizard", "blurb": "A long white beard, a robe to the ankles with wide sleeves, curly-toed shoes."},
	{"id": "bear", "name": "Teddy", "blurb": "A brown bear: round ears, a pale muzzle and belly, stout limbs, a bow tie."},
	{"id": "mushroom", "name": "Shroom", "blurb": "A toadstool on legs: a wide spotted cap over a little face."},
	{"id": "banana", "name": "Peel", "blurb": "A banana, its skin peeled down round its waist, on thin black limbs."},
]
## First-person arms only: a kit's forearms and hands are thinned by this much, so
## bulky ones held up to the camera do not fill the view (the robots' are thinned
## when their files are built: FP_SLIM in tools/robot/designs.py).
const KIT_FP_SLIM := {"yeti": 0.72, "astronaut": 0.8, "bear": 0.82, "jack": 0.9}


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


## Every body the Character Creator can take a head, a torso or legs from: the
## robots, then the kits.
static func part_ids() -> Array:
	return ids() + KITS.map(func(k): return k.id)


static func is_kit(id: String) -> bool:
	for k in KITS:
		if k.id == id:
			return true
	return false


static func has_part(id: String) -> bool:
	return id in ids() or is_kit(id)


## A part's name and blurb (a robot's or a kit's).
static func part_info(id: String) -> Dictionary:
	for k in KITS:
		if k.id == id:
			return k
	return info(id)


static func part_name(id: String) -> String:
	return part_info(id).name


## The model file a part's triangles come from.
static func part_file(id: String) -> String:
	return (KIT_DIR if is_kit(id) else DIR) + id + ".glb"


## The character after `id` in the list (wrapping round). After a custom
## character: the robot after the one its torso comes from.
static func next(id: String) -> String:
	if CustomCharacter.is_custom(id):
		id = base(id)
	return LIST[(ids().find(valid(id)) + 1) % LIST.size()].id


## The robot a character's skeleton, animations, guns and first-person arms come
## from: itself, or a custom character's torso (if that is a kit, which has none of
## those: the first robot; RobotModel.build swaps the kit's own arms in).
static func base(id: String) -> String:
	if CustomCharacter.is_custom(id):
		var torso := CustomCharacter.parse(id).torso
		return torso if torso in ids() else default_id()
	return valid(id)


## The full-body model file (a custom character: its base robot's; RobotModel.build
## puts the rest together).
static func body(id: String) -> String:
	return DIR + base(id) + ".glb"


## The first-person arms and pistol.
static func arms(id: String) -> String:
	return DIR + base(id) + "_arms.glb"
