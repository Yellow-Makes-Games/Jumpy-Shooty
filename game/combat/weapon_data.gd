class_name WeaponData
extends Resource
## Describes one weapon. New weapons are new WeaponData values, not new code,
## unless they need a new kind of behaviour (for example projectiles).
##
## Every player picks one weapon before the match (in the lobby, or on the Practice and
## Vs Bots pages) and can swap it while waiting to respawn. All numbers are first
## guesses for playtesting. Damage is per pellet; a full-health player has 100.
##
## Melee weapons (Kind.MELEE) swing instead of shooting: a swing winds up for
## `windup` seconds, then hits everyone within `max_range` metres and `arc_degrees`
## of where you look. They have no ammo. Every hit, gun or blade, shoves the target
## (`knockback`), and a hard enough shove into a wall hurts too (see Match).

enum Kind { HITSCAN, MELEE, PROJECTILE }

## The weapons in groups, as the pickers show them (and the number keys pick them while
## you wait to respawn: 1 for sidearms, 2 for shotguns... pressing again goes through the group).
const GROUPS := [
	["Sidearms", ["pistol", "revolver", "machine_pistol"]],
	["Shotguns", ["shotgun", "break_action"]],
	["Rifles", ["smg", "rifle", "burst_rifle", "lmg"]],
	["Marksman", ["lever_action", "bolt_action", "sniper", "railgun"]],
	["Explosives", ["rocket_launcher", "grenade_launcher"]],
	["Melee", ["sword", "hammer", "dagger", "brass_knuckles", "spear", "axe", "bat"]],
]
## Every weapon a player can pick, in the order the pickers show them.
const IDS := ["pistol", "revolver", "machine_pistol", "shotgun", "break_action", "smg", "rifle", "burst_rifle", "lmg",
	"lever_action", "bolt_action", "sniper", "railgun", "rocket_launcher", "grenade_launcher",
	"sword", "hammer", "dagger", "brass_knuckles", "spear", "axe", "bat"]
const MELEE := ["sword", "hammer", "dagger", "brass_knuckles", "spear", "axe", "bat"]
const GUNS := ["pistol", "revolver", "machine_pistol", "shotgun", "break_action", "smg", "rifle", "burst_rifle", "lmg",
	"lever_action", "bolt_action", "sniper", "railgun", "rocket_launcher", "grenade_launcher"]
## Guns held like the pistol (in both hands round the grip, no stock): they use the
## pistol's poses, with their own reload and firing clips.
const SIDEARMS := ["pistol", "revolver", "machine_pistol"]

@export var id := "pistol"
@export var display_name := "Pistol"
@export var short_name := "Pistol"       ## for the pickers' buttons
@export var blurb := ""
@export var kind: Kind = Kind.HITSCAN
@export var damage := 25.0           ## per pellet
@export var pellets := 1             ## shots per trigger pull (the shotgun's spread of pellets)
@export var fire_interval := 0.17    ## seconds between shots, at least
@export var automatic := false       ## false = one shot per click
@export var magazine := 12
@export var reload_time := 1.3       ## the whole magazine, or one round when reload_per_round
@export var reload_per_round := false   ## loads a round at a time (shotgun); firing stops the reload
@export var max_range := 200.0
@export var spread_degrees := 0.25   ## random aim wobble per shot (the pellets' cone for a shotgun)
@export var falloff_start := 1000.0  ## metres: full damage up to here...
@export var falloff_end := 1000.0    ## ...then less and less, down to falloff_min x damage from here on
@export var falloff_min := 1.0
@export var headshot_multiplier := 1.5
@export var muzzle_bone := "muzzle"  ## the marker bone in the robot model where shots leave the barrel
@export var crosshair := "cross"     ## cross, spread (a ring the size of the cone), dot
@export var kick := 1.0              ## how hard the gun kicks in the hands when it fires
## Knockback: metres per second added to the target's speed, along the shot (per
## pellet) or away from the swing, plus a little lift so it carries off the ground.
@export var knockback := 1.5
@export var knockback_up := 0.0
## Damage to breakable walls and floors, times the weapon's damage (see MapDestruction).
@export var structure_damage := 1.0
## Burst fire: each pull fires `burst` rounds, `burst_gap` seconds apart (fire_interval is between bursts).
@export var burst := 1
@export var burst_gap := 0.0
## A shot that goes through everyone in its path (the railgun), not just the first.
@export var pierce := false
@export_group("Projectile")
## Kind.PROJECTILE: a rocket or grenade that flies (the host follows it) and blows up
## where it lands: full `damage` within `splash_inner` metres, falling to nothing at
## `splash_radius`. Your own blast hurts you `self_damage` times as much, and shoves you
## just as hard (rocket jumps).
@export var projectile_speed := 30.0
@export var projectile_gravity := 0.0
@export var splash_radius := 4.0
@export var splash_inner := 1.0
@export var self_damage := 0.4
@export var fuse := 6.0               ## seconds before it blows up in mid-air anyway
@export_group("Melee")
@export var windup := 0.0            ## seconds from the click to the blow landing
@export var arc_degrees := 0.0       ## hits anyone within this angle of where you look
@export var lunge := 0.0             ## forward speed a swing gives you (closes the gap)
@export var backstab_multiplier := 1.0  ## damage from behind
@export var move_bonus := 1.0        ## running speed while carrying it (light blades are quicker)


static func pistol() -> WeaponData:
	var w := WeaponData.new()
	w.blurb = "Semi-auto sidearm. Accurate, quick to reload, 4 body shots."
	w.knockback = 2.0
	return w


## Pump-action: ten pellets in a wide cone. A kill in one shot up close, weak beyond
## about 15 m. Loads a shell at a time; shooting stops the reload.
static func shotgun() -> WeaponData:
	var w := WeaponData.new()
	w.id = "shotgun"
	w.display_name = "Shotgun"
	w.short_name = "Shotgun"
	w.blurb = "Pump-action. One shot up close, weak past 15 m. Loads a shell at a time."
	w.damage = 11.0
	w.pellets = 10
	w.fire_interval = 0.8
	w.magazine = 6
	w.reload_time = 0.5
	w.reload_per_round = true
	w.max_range = 60.0
	w.spread_degrees = 4.5
	w.falloff_start = 9.0
	w.falloff_end = 22.0
	w.falloff_min = 0.25
	w.headshot_multiplier = 1.25
	w.muzzle_bone = "muzzle_shotgun"
	w.crosshair = "spread"
	w.kick = 2.2
	w.knockback = 1.3      # per pellet: a full blast up close is a real shove
	w.knockback_up = 0.25
	return w


## Fully automatic: ten shots a second, 30 rounds, a little wobble.
static func rifle() -> WeaponData:
	var w := WeaponData.new()
	w.id = "rifle"
	w.display_name = "Assault Rifle"
	w.short_name = "Rifle"
	w.blurb = "Full-auto, 10 shots a second. Good at every range, 30 rounds."
	w.damage = 13.0
	w.fire_interval = 0.1
	w.automatic = true
	w.magazine = 30
	w.reload_time = 1.9
	w.spread_degrees = 0.9
	w.falloff_start = 35.0
	w.falloff_end = 70.0
	w.falloff_min = 0.7
	w.muzzle_bone = "muzzle_rifle"
	w.kick = 0.55
	w.knockback = 0.9
	return w


## Bolt-action: a headshot kills, two body shots do. Slow to work the bolt.
static func sniper() -> WeaponData:
	var w := WeaponData.new()
	w.id = "sniper"
	w.display_name = "Sniper Rifle"
	w.short_name = "Sniper"
	w.blurb = "Bolt-action. A headshot kills, two body shots do. Pinpoint, slow."
	w.damage = 75.0
	w.structure_damage = 1.5
	w.fire_interval = 1.25
	w.magazine = 5
	w.reload_time = 2.4
	w.max_range = 300.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 2.0
	w.muzzle_bone = "muzzle_sniper"
	w.crosshair = "dot"
	w.kick = 2.6
	w.knockback = 9.0
	w.knockback_up = 2.0
	return w


## A melee weapon: no ammo, no spread, full damage within reach.
static func _melee(id: String, display: String) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = display
	w.short_name = display
	w.kind = Kind.MELEE
	w.automatic = true       # hold the button to keep swinging
	w.magazine = 0
	w.reload_time = 0.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 1.0
	w.muzzle_bone = "pistol"   # the fist: the blade rides on the grip bone
	w.crosshair = "melee"
	return w


## Two hits kill. Every swing lunges forward a little, so you can chase.
static func sword() -> WeaponData:
	var w := _melee("sword", "Sword")
	w.blurb = "Two slashes kill. Each swing lunges you forward. Hold to keep swinging."
	w.damage = 50.0
	w.structure_damage = 1.5
	w.fire_interval = 0.55
	w.windup = 0.12
	w.max_range = 2.9
	w.arc_degrees = 55.0
	w.lunge = 5.0
	w.knockback = 9.0
	w.knockback_up = 3.5
	w.kick = 1.0
	w.move_bonus = 1.08
	return w


## Slow and brutal: sends people flying, and into walls hard enough to hurt.
static func hammer() -> WeaponData:
	var w := _melee("hammer", "Hammer")
	w.blurb = "Slow, huge knockback. Smash people into walls, or smash through them."
	w.damage = 65.0
	w.structure_damage = 3.0   # knocks holes in walls in two blows
	w.fire_interval = 1.05
	w.windup = 0.32
	w.max_range = 3.1
	w.arc_degrees = 65.0
	w.lunge = 2.0
	w.knockback = 24.0
	w.knockback_up = 6.5
	w.kick = 2.0
	w.move_bonus = 1.0
	return w


## Quick jabs, and a stab in the back kills outright.
static func dagger() -> WeaponData:
	var w := _melee("dagger", "Dagger")
	w.blurb = "Fast jabs, fastest on your feet. A stab in the back kills."
	w.damage = 26.0
	w.fire_interval = 0.3
	w.windup = 0.06
	w.max_range = 2.4
	w.arc_degrees = 40.0
	w.lunge = 3.0
	w.knockback = 4.0
	w.knockback_up = 1.5
	w.backstab_multiplier = 4.0
	w.kick = 0.6
	w.move_bonus = 1.15
	return w


# ---------------------------------------------------------------------------
# The fifteen newer weapons

static func _gun(id: String, display: String, short: String, muzzle: String = "") -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = display
	w.short_name = short
	w.muzzle_bone = muzzle if muzzle != "" else "muzzle_" + id
	return w


## Six heavy rounds: two body shots and a headshot kill. Loads all six at once.
static func revolver() -> WeaponData:
	var w := _gun("revolver", "Revolver", "Revolver")
	w.blurb = "Six heavy rounds. Two to the body and one to the head kill. Slow to reload."
	w.damage = 45.0
	w.fire_interval = 0.42
	w.magazine = 6
	w.reload_time = 2.0
	w.spread_degrees = 0.15
	w.falloff_start = 30.0
	w.falloff_end = 60.0
	w.falloff_min = 0.7
	w.headshot_multiplier = 1.6
	w.kick = 2.2
	w.knockback = 4.0
	w.knockback_up = 0.5
	return w


## A sidearm that sprays: sixteen rounds a second, all over the place past 12 m.
static func machine_pistol() -> WeaponData:
	var w := _gun("machine_pistol", "Machine Pistol", "Mach. Pistol")
	w.blurb = "Full-auto sidearm, 16 rounds a second. Wild past 12 m, quick on your feet."
	w.damage = 9.0
	w.fire_interval = 0.062
	w.automatic = true
	w.magazine = 24
	w.reload_time = 1.4
	w.spread_degrees = 1.7
	w.falloff_start = 12.0
	w.falloff_end = 30.0
	w.falloff_min = 0.5
	w.kick = 0.35
	w.knockback = 0.6
	w.move_bonus = 1.05
	return w


## Two barrels, two shots close together, then break it open for two more.
static func break_action() -> WeaponData:
	var w := _gun("break_action", "Break-Action Shotgun", "Double Barrel")
	w.blurb = "Two barrels, two quick blasts, the widest spread there is. Breaks open to reload both."
	w.damage = 11.0
	w.pellets = 12
	w.fire_interval = 0.28
	w.magazine = 2
	w.reload_time = 1.7
	w.max_range = 50.0
	w.spread_degrees = 6.0
	w.falloff_start = 6.0
	w.falloff_end = 16.0
	w.falloff_min = 0.2
	w.headshot_multiplier = 1.25
	w.crosshair = "spread"
	w.kick = 3.0
	w.knockback = 1.8
	w.knockback_up = 0.35
	return w


## Small, fast and light: deadly up close, weak far away.
static func smg() -> WeaponData:
	var w := _gun("smg", "Submachine Gun", "SMG")
	w.blurb = "Full-auto, 14 rounds a second. Deadly up close, fades past 15 m. Light to carry."
	w.damage = 10.0
	w.fire_interval = 0.07
	w.automatic = true
	w.magazine = 32
	w.reload_time = 1.6
	w.spread_degrees = 1.3
	w.falloff_start = 15.0
	w.falloff_end = 35.0
	w.falloff_min = 0.55
	w.kick = 0.4
	w.knockback = 0.7
	w.move_bonus = 1.06
	return w


## Three rounds per pull, tight together: two bursts to the body kill.
static func burst_rifle() -> WeaponData:
	var w := _gun("burst_rifle", "Burst Rifle", "Burst")
	w.blurb = "Three-round bursts, tight and accurate. Two full bursts kill at any range."
	w.damage = 17.0
	w.burst = 3
	w.burst_gap = 0.065
	w.fire_interval = 0.4
	w.magazine = 30
	w.reload_time = 2.0
	w.spread_degrees = 0.4
	w.falloff_start = 40.0
	w.falloff_end = 80.0
	w.falloff_min = 0.75
	w.kick = 0.6
	w.knockback = 1.0
	return w


## A hundred-round belt: hold the trigger and keep holding it. Heavy to carry.
static func lmg() -> WeaponData:
	var w := _gun("lmg", "Light Machine Gun", "LMG")
	w.blurb = "A 100-round belt at 12 a second. Never stops, but slows you down and takes ages to reload."
	w.damage = 13.0
	w.fire_interval = 0.085
	w.automatic = true
	w.magazine = 100
	w.reload_time = 3.6
	w.spread_degrees = 1.4
	w.falloff_start = 35.0
	w.falloff_end = 70.0
	w.falloff_min = 0.7
	w.structure_damage = 1.3
	w.kick = 0.7
	w.knockback = 1.2
	w.move_bonus = 0.9
	return w


## Work the lever between shots; loads a round at a time.
static func lever_action() -> WeaponData:
	var w := _gun("lever_action", "Lever-Action Rifle", "Lever")
	w.blurb = "Hard-hitting and quick to cycle: a headshot and a body shot kill. Loads a round at a time."
	w.damage = 55.0
	w.fire_interval = 0.72
	w.magazine = 7
	w.reload_time = 0.45
	w.reload_per_round = true
	w.spread_degrees = 0.1
	w.falloff_start = 50.0
	w.falloff_end = 100.0
	w.falloff_min = 0.8
	w.headshot_multiplier = 1.8
	w.kick = 2.2
	w.knockback = 5.0
	w.knockback_up = 1.0
	return w


## The sniper's lighter cousin: iron sights, quicker bolt, a round at a time.
static func bolt_action() -> WeaponData:
	var w := _gun("bolt_action", "Bolt-Action Rifle", "Bolt Action")
	w.blurb = "Iron sights and a quick bolt. A headshot kills, so do two to the body. Loads a round at a time."
	w.damage = 70.0
	w.fire_interval = 1.0
	w.magazine = 5
	w.reload_time = 0.5
	w.reload_per_round = true
	w.max_range = 250.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 1.6
	w.structure_damage = 1.4
	w.crosshair = "dot"
	w.kick = 2.4
	w.knockback = 7.0
	w.knockback_up = 1.5
	return w


## A slug that goes through everyone in a line. Slow to recharge.
static func railgun() -> WeaponData:
	var w := _gun("railgun", "Railgun", "Railgun")
	w.blurb = "A magnetic slug that goes through everyone in its path. Slow to recharge."
	w.damage = 80.0
	w.pierce = true
	w.fire_interval = 1.6
	w.magazine = 4
	w.reload_time = 2.6
	w.max_range = 300.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 1.5
	w.structure_damage = 2.5
	w.crosshair = "dot"
	w.kick = 3.0
	w.knockback = 12.0
	w.knockback_up = 2.5
	return w


## A rocket that blows up where it hits: splash damage, huge knockback, rocket jumps.
static func rocket_launcher() -> WeaponData:
	var w := _gun("rocket_launcher", "Rocket Launcher", "Rockets")
	w.kind = Kind.PROJECTILE
	w.blurb = "Rockets: a direct hit kills, the blast knocks everyone flying. Fire at your feet to rocket jump."
	w.damage = 105.0
	w.fire_interval = 0.9
	w.magazine = 1
	w.reload_time = 1.5
	w.max_range = 400.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 1.0
	w.structure_damage = 2.5
	w.projectile_speed = 34.0
	w.splash_radius = 4.5
	w.splash_inner = 1.0
	w.self_damage = 0.35
	w.crosshair = "ring"
	w.kick = 2.8
	w.knockback = 17.0
	w.knockback_up = 7.0
	w.move_bonus = 0.95
	return w


## Grenades in an arc that burst on contact.
static func grenade_launcher() -> WeaponData:
	var w := _gun("grenade_launcher", "Grenade Launcher", "Grenades")
	w.kind = Kind.PROJECTILE
	w.blurb = "Lobs grenades in an arc that burst on contact. Six in the drum, loaded one at a time."
	w.damage = 85.0
	w.fire_interval = 0.6
	w.magazine = 6
	w.reload_time = 0.55
	w.reload_per_round = true
	w.max_range = 300.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 1.0
	w.structure_damage = 2.0
	w.projectile_speed = 26.0
	w.projectile_gravity = 16.0
	w.splash_radius = 3.6
	w.splash_inner = 0.8
	w.self_damage = 0.35
	w.crosshair = "ring"
	w.kick = 1.8
	w.knockback = 12.0
	w.knockback_up = 5.0
	return w


## Fists with brass on: the fastest hits there are, left-right-left.
static func brass_knuckles() -> WeaponData:
	var w := _melee("brass_knuckles", "Brass Knuckles")
	w.short_name = "Knuckles"
	w.blurb = "Quick punches, three to kill. Fastest on your feet of anything."
	w.damage = 34.0
	w.fire_interval = 0.3
	w.windup = 0.05
	w.max_range = 2.2
	w.arc_degrees = 45.0
	w.lunge = 3.5
	w.knockback = 6.0
	w.knockback_up = 1.5
	w.kick = 0.7
	w.move_bonus = 1.18
	return w


## The longest reach: a straight thrust that carries you with it.
static func spear() -> WeaponData:
	var w := _melee("spear", "Spear")
	w.blurb = "The longest reach. A straight thrust that lunges you a long way. Narrow: aim it."
	w.damage = 50.0
	w.fire_interval = 0.7
	w.windup = 0.15
	w.max_range = 4.2
	w.arc_degrees = 22.0
	w.lunge = 7.0
	w.knockback = 11.0
	w.knockback_up = 2.0
	w.kick = 1.2
	w.move_bonus = 1.04
	return w


## Heavier than the sword, lighter than the hammer. Chops through walls.
static func axe() -> WeaponData:
	var w := _melee("axe", "Axe")
	w.blurb = "A heavy diagonal chop: two kill, and it bites through walls."
	w.damage = 60.0
	w.structure_damage = 3.5
	w.fire_interval = 0.85
	w.windup = 0.2
	w.max_range = 3.0
	w.arc_degrees = 55.0
	w.lunge = 3.0
	w.knockback = 13.0
	w.knockback_up = 4.5
	w.kick = 1.6
	return w


## A wide swing that sends people further than anything else.
static func bat() -> WeaponData:
	var w := _melee("bat", "Bat")
	w.blurb = "A wide, flat swing. Light damage, but the hardest knockback of all: home runs into walls."
	w.damage = 40.0
	w.fire_interval = 0.75
	w.windup = 0.2
	w.max_range = 3.0
	w.arc_degrees = 75.0
	w.lunge = 2.5
	w.knockback = 29.0
	w.knockback_up = 9.0
	w.kick = 1.8
	return w


func is_melee() -> bool:
	return kind == Kind.MELEE


func is_projectile() -> bool:
	return kind == Kind.PROJECTILE


## The shortest time between two rounds (inside a burst, for a burst rifle).
func shot_gap() -> float:
	return minf(burst_gap, fire_interval) if burst > 1 else fire_interval


## Which group of the pickers the weapon is in (0 = sidearms).
static func group_of(weapon_id: String) -> int:
	for i in GROUPS.size():
		if weapon_id in GROUPS[i][1]:
			return i
	return 0


## Held in both hands round the grip, like the pistol.
static func sidearm(weapon_id: String) -> bool:
	return weapon_id in SIDEARMS


static var _cache := {}


static func _make(weapon_id: String) -> WeaponData:
	match weapon_id:
		"shotgun": return shotgun()
		"rifle": return rifle()
		"sniper": return sniper()
		"sword": return sword()
		"hammer": return hammer()
		"dagger": return dagger()
		"revolver": return revolver()
		"machine_pistol": return machine_pistol()
		"break_action": return break_action()
		"smg": return smg()
		"burst_rifle": return burst_rifle()
		"lmg": return lmg()
		"lever_action": return lever_action()
		"bolt_action": return bolt_action()
		"railgun": return railgun()
		"rocket_launcher": return rocket_launcher()
		"grenade_launcher": return grenade_launcher()
		"brass_knuckles": return brass_knuckles()
		"spear": return spear()
		"axe": return axe()
		"bat": return bat()
	return pistol()


static func by_id(weapon_id: String) -> WeaponData:
	weapon_id = valid(weapon_id)
	if not _cache.has(weapon_id):
		_cache[weapon_id] = _make(weapon_id)
	return _cache[weapon_id]


static func default_id() -> String:
	return IDS[0]


static func has(weapon_id: String) -> bool:
	return weapon_id in IDS


## `weapon_id` if it is a real weapon, otherwise the default one.
static func valid(weapon_id: String) -> String:
	return weapon_id if has(weapon_id) else default_id()


static func melee(weapon_id: String) -> bool:
	return weapon_id in MELEE


static func name_of(weapon_id: String) -> String:
	return by_id(weapon_id).display_name


## Damage of one pellet that hit at `distance` metres, before headshots.
func damage_at(distance: float) -> float:
	if distance <= falloff_start or falloff_end <= falloff_start:
		return damage if distance <= falloff_end else damage * falloff_min
	var u := clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return damage * lerpf(1.0, falloff_min, u)
