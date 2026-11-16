class_name WeaponData
extends Resource
## Describes one weapon. New weapons are new WeaponData values, not new code,
## unless they need a new kind of behaviour (for example projectiles).
##
## Every player picks one gun before the match (in the lobby, or on the Practice and
## Vs Bots pages) and keeps it for the whole match. All numbers are first guesses for
## playtesting. Damage is per pellet; a full-health player has 100.

enum Kind { HITSCAN }

## Every gun a player can pick, in the order the pickers show them.
const IDS := ["pistol", "shotgun", "rifle", "sniper"]

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


static func pistol() -> WeaponData:
	var w := WeaponData.new()
	w.blurb = "Semi-auto sidearm. Accurate, quick to reload, 4 body shots."
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
	return w


## Bolt-action: a headshot kills, two body shots do. Slow to work the bolt.
static func sniper() -> WeaponData:
	var w := WeaponData.new()
	w.id = "sniper"
	w.display_name = "Sniper Rifle"
	w.short_name = "Sniper"
	w.blurb = "Bolt-action. A headshot kills, two body shots do. Pinpoint, slow."
	w.damage = 75.0
	w.fire_interval = 1.25
	w.magazine = 5
	w.reload_time = 2.4
	w.max_range = 300.0
	w.spread_degrees = 0.0
	w.headshot_multiplier = 2.0
	w.muzzle_bone = "muzzle_sniper"
	w.crosshair = "dot"
	w.kick = 2.6
	return w


static var _cache := {}


static func by_id(weapon_id: String) -> WeaponData:
	weapon_id = valid(weapon_id)
	if not _cache.has(weapon_id):
		match weapon_id:
			"shotgun": _cache[weapon_id] = shotgun()
			"rifle": _cache[weapon_id] = rifle()
			"sniper": _cache[weapon_id] = sniper()
			_: _cache[weapon_id] = pistol()
	return _cache[weapon_id]


static func default_id() -> String:
	return IDS[0]


static func has(weapon_id: String) -> bool:
	return weapon_id in IDS


## `weapon_id` if it is a real weapon, otherwise the default one.
static func valid(weapon_id: String) -> String:
	return weapon_id if has(weapon_id) else default_id()


static func name_of(weapon_id: String) -> String:
	return by_id(weapon_id).display_name


## Damage of one pellet that hit at `distance` metres, before headshots.
func damage_at(distance: float) -> float:
	if distance <= falloff_start or falloff_end <= falloff_start:
		return damage if distance <= falloff_end else damage * falloff_min
	var u := clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return damage * lerpf(1.0, falloff_min, u)
