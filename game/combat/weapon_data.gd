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

enum Kind { HITSCAN, MELEE }

## Every weapon a player can pick, in the order the pickers show them.
const IDS := ["pistol", "shotgun", "rifle", "sniper", "sword", "hammer", "dagger"]
const GUNS := ["pistol", "shotgun", "rifle", "sniper"]
const MELEE := ["sword", "hammer", "dagger"]

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


func is_melee() -> bool:
	return kind == Kind.MELEE


static var _cache := {}


static func by_id(weapon_id: String) -> WeaponData:
	weapon_id = valid(weapon_id)
	if not _cache.has(weapon_id):
		match weapon_id:
			"shotgun": _cache[weapon_id] = shotgun()
			"rifle": _cache[weapon_id] = rifle()
			"sniper": _cache[weapon_id] = sniper()
			"sword": _cache[weapon_id] = sword()
			"hammer": _cache[weapon_id] = hammer()
			"dagger": _cache[weapon_id] = dagger()
			_: _cache[weapon_id] = pistol()
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
