class_name CustomCharacter
extends RefCounted
## A character made in the Character Creator: the legs of one body, the torso (and
## arms) of another and the head of a third (robots, or the other bodies: a person,
## a goblin, a frog... see Characters.KITS), three colours for the body (its main
## colour, a second colour and a detail colour), a skin tone, and up to one accessory
## in each slot (hat, face, neck, shoulder, back, waist, tail), each in a colour of
## its own if you like.
##
## It travels as a character id like any robot's ("needle", "templar"), so the lobby,
## the save file and every match pass it around unchanged:
##
##   custom:n=Sir Bolt|l=frog|t=templar|h=goblin|p=gold|p2=red|s=tan|hat=top_hat.purple|face=shades|back=cape
##
## (p, p2, p3: the three body colours; s: skin; "top_hat.purple": a purple top hat.)
##
## normalize() rebuilds the id from what it can read, so an id from another player
## only ever names parts that exist, and a name that is short and plain.

const PREFIX := "custom:"
const MAX_NAME := 16
## Body regions, and the bones whose triangles each one takes from its body. The
## torso takes everything else (spine, chest, arms, hands).
const HEAD_BONES := ["head"]
const LEG_BONES := ["hips", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]

## The colours a body or an accessory can be painted. "" = as it was built.
## A body has three: its main colour (a robot's shell, a creature's clothes, fur or
## hide: "armor"), its second colour (a robot's frame, jeans, a belly, a beak: "trim")
## and its detail colour (a robot's fittings, hair, spots, horns: "mark"). See
## RobotModel.CHANNELS.
const PAINTS := [
	{"id": "", "name": "Original", "color": Color(0.90, 0.91, 0.93)},
	{"id": "white", "name": "Snow", "color": Color(0.97, 0.97, 0.97)},
	{"id": "gunmetal", "name": "Gunmetal", "color": Color(0.30, 0.32, 0.35)},
	{"id": "black", "name": "Midnight", "color": Color(0.07, 0.075, 0.09)},
	{"id": "gold", "name": "Gold", "color": Color(0.95, 0.72, 0.24)},
	{"id": "yellow", "name": "Lemon", "color": Color(0.97, 0.87, 0.22)},
	{"id": "orange", "name": "Tangerine", "color": Color(0.95, 0.50, 0.10)},
	{"id": "red", "name": "Crimson", "color": Color(0.72, 0.10, 0.10)},
	{"id": "pink", "name": "Bubblegum", "color": Color(0.95, 0.50, 0.72)},
	{"id": "purple", "name": "Royal", "color": Color(0.40, 0.18, 0.62)},
	{"id": "blue", "name": "Cobalt", "color": Color(0.14, 0.30, 0.78)},
	{"id": "sky", "name": "Sky", "color": Color(0.42, 0.72, 0.95)},
	{"id": "teal", "name": "Lagoon", "color": Color(0.08, 0.58, 0.58)},
	{"id": "green", "name": "Moss", "color": Color(0.28, 0.45, 0.22)},
	{"id": "lime", "name": "Lime", "color": Color(0.58, 0.85, 0.20)},
	{"id": "brown", "name": "Chestnut", "color": Color(0.42, 0.27, 0.15)},
	{"id": "sand", "name": "Desert", "color": Color(0.80, 0.68, 0.48)},
	{"id": "cream", "name": "Cream", "color": Color(0.96, 0.91, 0.76)},
	{"id": "silver", "name": "Silver", "color": Color(0.70, 0.72, 0.76)},
	{"id": "maroon", "name": "Maroon", "color": Color(0.42, 0.08, 0.14)},
	{"id": "hotpink", "name": "Hot Pink", "color": Color(0.96, 0.18, 0.55)},
	{"id": "lavender", "name": "Lavender", "color": Color(0.72, 0.62, 0.92)},
	{"id": "navy", "name": "Navy", "color": Color(0.08, 0.13, 0.36)},
	{"id": "cyan", "name": "Cyan", "color": Color(0.12, 0.82, 0.92)},
	{"id": "mint", "name": "Mint", "color": Color(0.55, 0.92, 0.72)},
	{"id": "olive", "name": "Olive", "color": Color(0.42, 0.44, 0.18)},
	{"id": "forest", "name": "Forest", "color": Color(0.08, 0.30, 0.15)},
	{"id": "coral", "name": "Coral", "color": Color(0.98, 0.48, 0.40)},
	{"id": "peach", "name": "Peach", "color": Color(0.99, 0.78, 0.60)},
	{"id": "indigo", "name": "Indigo", "color": Color(0.30, 0.20, 0.66)},
]
## The body's colours, in RobotModel.CHANNELS order: [key in an id, what the creator calls it].
const BODY_COLORS := [["p", "Main colour"], ["p2", "Second colour"], ["p3", "Detail colour"], ["s", "Skin"]]

## Skin tone: the colour of bare skin on the bodies that have some (a person's, a
## goblin's, an imp's, a zombie's, the yeti's face: "skin"). "" = as it was built.
const SKINS := [
	{"id": "", "name": "Natural", "color": Color(0.87, 0.66, 0.52)},
	{"id": "porcelain", "name": "Porcelain", "color": Color(0.97, 0.86, 0.78)},
	{"id": "fair", "name": "Fair", "color": Color(0.94, 0.77, 0.64)},
	{"id": "tan", "name": "Tan", "color": Color(0.82, 0.61, 0.44)},
	{"id": "olive", "name": "Olive", "color": Color(0.70, 0.53, 0.36)},
	{"id": "brown", "name": "Brown", "color": Color(0.52, 0.35, 0.23)},
	{"id": "deep", "name": "Deep", "color": Color(0.32, 0.21, 0.15)},
	{"id": "green", "name": "Goblin Green", "color": Color(0.45, 0.62, 0.24)},
	{"id": "swamp", "name": "Swamp", "color": Color(0.52, 0.63, 0.50)},
	{"id": "teal", "name": "Merfolk", "color": Color(0.20, 0.62, 0.62)},
	{"id": "blue", "name": "Frost", "color": Color(0.42, 0.55, 0.82)},
	{"id": "purple", "name": "Orchid", "color": Color(0.60, 0.42, 0.78)},
	{"id": "pink", "name": "Candy", "color": Color(0.96, 0.62, 0.72)},
	{"id": "red", "name": "Brimstone", "color": Color(0.78, 0.16, 0.13)},
	{"id": "yellow", "name": "Sunny", "color": Color(0.96, 0.84, 0.30)},
	{"id": "grey", "name": "Stone", "color": Color(0.60, 0.62, 0.63)},
	{"id": "chalk", "name": "Chalk", "color": Color(0.93, 0.93, 0.91)},
]

## The accessory slots, in the order the creator lists them. "" = none.
const SLOTS := ["hat", "face", "neck", "shoulder", "back", "waist", "tail"]
const SLOT_NAMES := {"hat": "Hat", "face": "Face", "neck": "Neck", "shoulder": "Shoulder", "back": "Back", "waist": "Waist", "tail": "Tail"}
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
		{"id": "pirate", "name": "Pirate Hat"},
		{"id": "chef", "name": "Chef's Hat"},
		{"id": "propeller", "name": "Propeller Cap"},
		{"id": "santa", "name": "Santa Hat"},
		{"id": "sombrero", "name": "Sombrero"},
		{"id": "fez", "name": "Fez"},
		{"id": "hard_hat", "name": "Hard Hat"},
		{"id": "mortarboard", "name": "Mortarboard"},
		{"id": "jester", "name": "Jester Hat"},
		{"id": "bucket", "name": "Bucket"},
		{"id": "traffic_cone", "name": "Traffic Cone"},
		{"id": "bandana", "name": "Bandana"},
		{"id": "flower_crown", "name": "Flower Crown"},
		{"id": "mohawk", "name": "Mohawk"},
		{"id": "afro", "name": "Afro"},
		{"id": "devil_horns", "name": "Devil Horns"},
		{"id": "antlers", "name": "Antlers"},
		{"id": "bunny_ears", "name": "Bunny Ears"},
		{"id": "cat_ears", "name": "Cat Ears"},
		{"id": "unicorn", "name": "Unicorn Horn"},
	],
	"face": [
		{"id": "", "name": "None"},
		{"id": "shades", "name": "Shades"},
		{"id": "round_specs", "name": "Round Specs"},
		{"id": "monocle", "name": "Monocle"},
		{"id": "goggles", "name": "Goggles"},
		{"id": "mustache", "name": "Mustache"},
		{"id": "eye_patch", "name": "Eye Patch"},
		{"id": "aviators", "name": "Aviators"},
		{"id": "three_d", "name": "3D Glasses"},
		{"id": "heart_shades", "name": "Heart Shades"},
		{"id": "laser_visor", "name": "Laser Visor"},
		{"id": "bandit_mask", "name": "Bandit Mask"},
		{"id": "bandana_mask", "name": "Bandana Mask"},
		{"id": "snorkel", "name": "Snorkel"},
		{"id": "clown_nose", "name": "Clown Nose"},
		{"id": "beard", "name": "Beard"},
		{"id": "handlebar", "name": "Handlebar"},
		{"id": "lollipop", "name": "Lollipop"},
	],
	"neck": [
		{"id": "", "name": "None"},
		{"id": "gold_chain", "name": "Gold Chain"},
		{"id": "bow_tie", "name": "Bow Tie"},
		{"id": "scarf", "name": "Scarf"},
		{"id": "medal", "name": "Medal"},
		{"id": "tie", "name": "Necktie"},
		{"id": "neckerchief", "name": "Neckerchief"},
		{"id": "lei", "name": "Flower Lei"},
		{"id": "bell_collar", "name": "Bell Collar"},
		{"id": "spiked_collar", "name": "Spiked Collar"},
		{"id": "pearls", "name": "Pearls"},
		{"id": "ruff", "name": "Ruff"},
		{"id": "dog_tags", "name": "Dog Tags"},
		{"id": "stethoscope", "name": "Stethoscope"},
	],
	"shoulder": [
		{"id": "", "name": "None"},
		{"id": "parrot", "name": "Parrot"},
		{"id": "epaulettes", "name": "Epaulettes"},
		{"id": "pauldrons", "name": "Pauldrons"},
		{"id": "shoulder_spikes", "name": "Spikes"},
		{"id": "drone", "name": "Drone Buddy"},
		{"id": "boombox", "name": "Boombox"},
		{"id": "bandolier", "name": "Bandolier"},
	],
	"back": [
		{"id": "", "name": "None"},
		{"id": "cape", "name": "Cape"},
		{"id": "wings", "name": "Wings"},
		{"id": "backpack", "name": "Backpack"},
		{"id": "rocket_pack", "name": "Rocket Pack"},
		{"id": "sword", "name": "Sword on Back"},
		{"id": "bat_wings", "name": "Bat Wings"},
		{"id": "butterfly_wings", "name": "Butterfly Wings"},
		{"id": "turtle_shell", "name": "Turtle Shell"},
		{"id": "guitar", "name": "Guitar"},
		{"id": "quiver", "name": "Quiver"},
		{"id": "shield", "name": "Shield"},
		{"id": "surfboard", "name": "Surfboard"},
		{"id": "banner", "name": "Banner"},
		{"id": "balloons", "name": "Balloons"},
		{"id": "windup_key", "name": "Wind-up Key"},
	],
	"waist": [
		{"id": "", "name": "None"},
		{"id": "buckle_belt", "name": "Big Buckle"},
		{"id": "utility_belt", "name": "Utility Belt"},
		{"id": "champion_belt", "name": "Champion's Belt"},
		{"id": "fanny_pack", "name": "Bum Bag"},
		{"id": "tutu", "name": "Tutu"},
		{"id": "grass_skirt", "name": "Grass Skirt"},
		{"id": "pool_float", "name": "Pool Float"},
		{"id": "hula_hoop", "name": "Hula Hoop"},
	],
	"tail": [
		{"id": "", "name": "None"},
		{"id": "fox_tail", "name": "Fox Tail"},
		{"id": "monkey_tail", "name": "Monkey Tail"},
		{"id": "bunny_tail", "name": "Bunny Tail"},
		{"id": "dino_tail", "name": "Dino Tail"},
		{"id": "devil_tail", "name": "Devil Tail"},
		{"id": "scorpion_tail", "name": "Scorpion Tail"},
		{"id": "peacock", "name": "Peacock Fan"},
		{"id": "power_cord", "name": "Power Cord"},
	],
}

static var _normal := {}   # id as given -> normalized id ("" if not a custom character)

var name := "Custom"
var legs := "vanguard"
var torso := "vanguard"
var head := "vanguard"
var paint := ""    ## main colour (an id from PAINTS)
var paint2 := ""   ## second colour
var paint3 := ""   ## detail colour
var skin := ""     ## an id from SKINS
var accessories := {"hat": "", "face": "", "neck": "", "shoulder": "", "back": "", "waist": "", "tail": ""}
var colors := {}   ## slot -> the colour its accessory is painted (an id from PAINTS; none or "": as built)


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
			"l": c.legs = _part(v)
			"t": c.torso = _part(v)
			"h": c.head = _part(v)
			"p": c.paint = v if has_paint(v) else ""
			"p2": c.paint2 = v if has_paint(v) else ""
			"p3": c.paint3 = v if has_paint(v) else ""
			"s": c.skin = v if has_skin(v) else ""
			_:
				var piece := v.get_slice(".", 0)   # "top_hat.purple": a purple top hat
				if k in SLOTS and has_accessory(k, piece) and piece != "":
					c.accessories[k] = piece
					var tint := v.get_slice(".", 1) if "." in v else ""
					if tint != "" and has_paint(tint):
						c.colors[k] = tint
	return c


## A body colour by its key in an id ("p", "p2", "p3", "s").
func body_color(key: String) -> String:
	match key:
		"p": return paint
		"p2": return paint2
		"p3": return paint3
	return skin


func set_body_color(key: String, id: String) -> void:
	match key:
		"p": paint = id
		"p2": paint2 = id
		"p3": paint3 = id
		"s": skin = id


## The body's four colours as RobotModel wants them (alpha 0: as built).
func channel_colors() -> Array[Color]:
	return [paint_color(paint), paint_color(paint2), paint_color(paint3), skin_color(skin)]


## The colour a slot's accessory is painted ("" = as built).
func color_of(slot: String) -> String:
	return colors.get(slot, "") if accessories.get(slot, "") != "" else ""


func to_id() -> String:
	var out := PREFIX + "n=%s|l=%s|t=%s|h=%s" % [clean_name(name), legs, torso, head]
	for pair in BODY_COLORS:
		if body_color(pair[0]) != "":
			out += "|%s=%s" % [pair[0], body_color(pair[0])]
	for slot in SLOTS:
		if accessories.get(slot, "") != "":
			out += "|%s=%s" % [slot, accessories[slot]]
			if color_of(slot) != "":
				out += "." + color_of(slot)
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


## A body a part can come from (a robot or a kit), or the default robot.
static func _part(id: String) -> String:
	return id if Characters.has_part(id) else Characters.default_id()


static func has_paint(id: String) -> bool:
	for p in PAINTS:
		if p.id == id:
			return true
	return false


static func paint_color(id: String) -> Color:
	for p in PAINTS:
		if p.id == id and id != "":
			return p.color
	return Color(0, 0, 0, 0)   # no paint: as it was built


static func has_skin(id: String) -> bool:
	for k in SKINS:
		if k.id == id:
			return true
	return false


static func skin_color(id: String) -> Color:
	for k in SKINS:
		if k.id == id and id != "":
			return k.color
	return Color(0, 0, 0, 0)   # as it was built


static func skin_name(id: String) -> String:
	for k in SKINS:
		if k.id == id:
			return k.name
	return SKINS[0].name


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


## Which body each bone's triangles come from ("head", "legs" or "torso").
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
	var parts := "%s head, %s torso, %s legs" % [Characters.part_name(head), Characters.part_name(torso), Characters.part_name(legs)]
	if head == torso and torso == legs:
		parts = Characters.part_name(head)
	var extras: Array = []
	for slot in SLOTS:
		if accessories.get(slot, "") != "":
			extras.append(accessory_name(slot, accessories[slot]))
	if paint != "":
		parts += ", %s paint" % paint_name(paint)
	return parts + (".  " + ", ".join(extras) + "." if not extras.is_empty() else ".")


## A random character (the creator's Randomize button). Accessories: each slot
## filled a little under half the time. allowed(key): whether an item may be used
## (see Achievements for the keys); without it, anything goes.
static func random(rng: RandomNumberGenerator = null, allowed: Callable = Callable()) -> CustomCharacter:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ok := func(key: String) -> bool: return not allowed.is_valid() or allowed.call(key)
	var c := CustomCharacter.new()
	var ids := Characters.part_ids().filter(func(id): return ok.call("part:" + id))
	var paints := PAINTS.filter(func(p): return p.id != "" and ok.call("paint:" + p.id))
	c.legs = ids[rng.randi() % ids.size()]
	c.torso = ids[rng.randi() % ids.size()]
	c.head = ids[rng.randi() % ids.size()]
	# Paint and skin: as built about half the time, so a frog is often green.
	c.paint = paints[rng.randi() % paints.size()].id if rng.randf() < 0.5 else ""
	c.paint2 = paints[rng.randi() % paints.size()].id if rng.randf() < 0.3 else ""
	c.paint3 = paints[rng.randi() % paints.size()].id if rng.randf() < 0.3 else ""
	c.skin = SKINS[rng.randi() % SKINS.size()].id if rng.randf() < 0.5 else ""
	for slot in SLOTS:
		var list: Array = ACCESSORIES[slot].filter(func(a): return a.id != "" and ok.call("%s:%s" % [slot, a.id]))
		c.accessories[slot] = list[rng.randi() % list.size()].id if rng.randf() < 0.45 and not list.is_empty() else ""
		if c.accessories[slot] != "" and rng.randf() < 0.3:
			c.colors[slot] = paints[rng.randi() % paints.size()].id
	return c
