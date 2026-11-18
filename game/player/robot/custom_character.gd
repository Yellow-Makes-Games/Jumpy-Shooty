class_name CustomCharacter
extends RefCounted
## A character made in the Character Creator: the legs of one robot, the torso (and
## arms) of another and the head of a third, a coat of paint, and up to one
## accessory in each slot (hat, glasses, neck, back).
##
## It travels as a character id like any robot's ("needle", "templar"), so the lobby,
## the save file and every match pass it around unchanged:
##
##   custom:n=Sir Bolt|l=kestrel|t=templar|h=rivet|p=gold|hat=top_hat|face=shades|neck=gold_chain|back=cape
##
## normalize() rebuilds the id from what it can read, so an id from another player
## only ever names parts that exist, and a name that is short and plain.

const PREFIX := "custom:"
const MAX_NAME := 16
## Body regions, and the bones whose triangles each one takes from its robot. The
## torso takes everything else (spine, chest, arms, hands, guns).
const HEAD_BONES := ["head"]
const LEG_BONES := ["hips", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]

## Body paint: the colour of the main shell ("armor"). "" = as the robot was built.
const PAINTS := [
	{"id": "", "name": "Factory", "color": Color(0.90, 0.91, 0.93)},
	{"id": "gunmetal", "name": "Gunmetal", "color": Color(0.30, 0.32, 0.35)},
	{"id": "black", "name": "Midnight", "color": Color(0.07, 0.075, 0.09)},
	{"id": "gold", "name": "Gold", "color": Color(0.95, 0.72, 0.24)},
	{"id": "red", "name": "Crimson", "color": Color(0.72, 0.10, 0.10)},
	{"id": "blue", "name": "Cobalt", "color": Color(0.14, 0.30, 0.78)},
	{"id": "green", "name": "Moss", "color": Color(0.28, 0.45, 0.22)},
	{"id": "pink", "name": "Bubblegum", "color": Color(0.95, 0.50, 0.72)},
	{"id": "purple", "name": "Royal", "color": Color(0.40, 0.18, 0.62)},
	{"id": "sand", "name": "Desert", "color": Color(0.80, 0.68, 0.48)},
]

## The accessory slots, in the order the creator lists them. "" = none.
const SLOTS := ["hat", "face", "neck", "back"]
const SLOT_NAMES := {"hat": "Hat", "face": "Face", "neck": "Neck", "back": "Back"}
const ACCESSORIES := {
	"hat": [
		{"id": "", "name": "None"},
		{"id": "top_hat", "name": "Top Hat"},
		{"id": "cowboy", "name": "Cowboy Hat"},
		{"id": "crown", "name": "Crown"},
		{"id": "cap", "name": "Ball Cap"},
		{"id": "wizard", "name": "Wizard Hat"},
		{"id": "viking", "name": "Viking Helmet"},
		{"id": "party", "name": "Party Hat"},
		{"id": "halo", "name": "Halo"},
		{"id": "headphones", "name": "Headphones"},
		{"id": "beanie", "name": "Beanie"},
	],
	"face": [
		{"id": "", "name": "None"},
		{"id": "shades", "name": "Shades"},
		{"id": "round_specs", "name": "Round Specs"},
		{"id": "monocle", "name": "Monocle"},
		{"id": "goggles", "name": "Goggles"},
		{"id": "mustache", "name": "Mustache"},
		{"id": "eye_patch", "name": "Eye Patch"},
	],
	"neck": [
		{"id": "", "name": "None"},
		{"id": "gold_chain", "name": "Gold Chain"},
		{"id": "bow_tie", "name": "Bow Tie"},
		{"id": "scarf", "name": "Scarf"},
		{"id": "medal", "name": "Medal"},
		{"id": "tie", "name": "Necktie"},
	],
	"back": [
		{"id": "", "name": "None"},
		{"id": "cape", "name": "Cape"},
		{"id": "wings", "name": "Wings"},
		{"id": "backpack", "name": "Backpack"},
		{"id": "rocket_pack", "name": "Rocket Pack"},
		{"id": "sword", "name": "Sword on Back"},
	],
}

static var _normal := {}   # id as given -> normalized id ("" if not a custom character)

var name := "Custom"
var legs := "vanguard"
var torso := "vanguard"
var head := "vanguard"
var paint := ""
var accessories := {"hat": "", "face": "", "neck": "", "back": ""}


static func is_custom(id: String) -> bool:
	return id.begins_with(PREFIX)


## The id rebuilt from what can be read of it; "" if it isn't a custom character.
static func normalize(id: String) -> String:
	if not is_custom(id):
		return ""
	if not _normal.has(id):
		if _normal.size() > 512:
			_normal.clear()
		_normal[id] = parse(id).to_id()
	return _normal[id]


static func parse(id: String) -> CustomCharacter:
	var c := CustomCharacter.new()
	if not is_custom(id):
		return c
	for field in id.substr(PREFIX.length()).split("|"):
		var k := field.get_slice("=", 0)
		var v := field.substr(k.length() + 1) if "=" in field else ""
		match k:
			"n": c.name = clean_name(v)
			"l": c.legs = _robot(v)
			"t": c.torso = _robot(v)
			"h": c.head = _robot(v)
			"p": c.paint = v if has_paint(v) else ""
			_:
				if k in SLOTS and has_accessory(k, v):
					c.accessories[k] = v
	return c


func to_id() -> String:
	var out := PREFIX + "n=%s|l=%s|t=%s|h=%s" % [clean_name(name), legs, torso, head]
	if paint != "":
		out += "|p=" + paint
	for slot in SLOTS:
		if accessories[slot] != "":
			out += "|%s=%s" % [slot, accessories[slot]]
	return out


func duplicate() -> CustomCharacter:
	return parse(to_id())


## A name safe to put in an id: no separators, plain spaces, at most MAX_NAME letters.
static func clean_name(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		if ch in "|=:\n\r\t":
			continue
		out += ch
	out = out.strip_edges().left(MAX_NAME)
	return out if out != "" else "Custom"


static func _robot(id: String) -> String:
	for c in Characters.LIST:
		if c.id == id:
			return id
	return Characters.default_id()


static func has_paint(id: String) -> bool:
	for p in PAINTS:
		if p.id == id:
			return true
	return false


static func paint_color(id: String) -> Color:
	for p in PAINTS:
		if p.id == id and id != "":
			return p.color
	return Color(0, 0, 0, 0)   # no paint: the robot's own


static func has_accessory(slot: String, id: String) -> bool:
	if not ACCESSORIES.has(slot):
		return false
	for a in ACCESSORIES[slot]:
		if a.id == id:
			return true
	return false


static func accessory_name(slot: String, id: String) -> String:
	for a in ACCESSORIES.get(slot, []):
		if a.id == id:
			return a.name
	return "None"


static func paint_name(id: String) -> String:
	for p in PAINTS:
		if p.id == id:
			return p.name
	return PAINTS[0].name


## Which robot each bone's triangles come from ("head", "legs" or "torso").
static func region_of(bone: String) -> String:
	if bone in HEAD_BONES:
		return "head"
	if bone in LEG_BONES:
		return "legs"
	return "torso"


func part(region: String) -> String:
	match region:
		"head": return head
		"legs": return legs
	return torso


## A line about it, for the picker.
func blurb() -> String:
	var parts := "%s head, %s torso, %s legs" % [Characters.name_of(head), Characters.name_of(torso), Characters.name_of(legs)]
	var extras: Array = []
	for slot in SLOTS:
		if accessories[slot] != "":
			extras.append(accessory_name(slot, accessories[slot]))
	if paint != "":
		parts += ", %s paint" % paint_name(paint)
	return parts + (".  " + ", ".join(extras) + "." if not extras.is_empty() else ".")


## A random character (the creator's Randomize button). Accessories: each slot
## filled about half the time.
static func random(rng: RandomNumberGenerator = null) -> CustomCharacter:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var c := CustomCharacter.new()
	var ids := Characters.ids()
	c.legs = ids[rng.randi() % ids.size()]
	c.torso = ids[rng.randi() % ids.size()]
	c.head = ids[rng.randi() % ids.size()]
	c.paint = PAINTS[rng.randi() % PAINTS.size()].id
	for slot in SLOTS:
		var list: Array = ACCESSORIES[slot]
		c.accessories[slot] = list[rng.randi_range(1, list.size() - 1)].id if rng.randf() < 0.55 else ""
	return c
