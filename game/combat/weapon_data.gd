class_name WeaponData
extends Resource
## Describes one weapon. New weapons are new WeaponData values, not new code,
## unless they need a new kind of behaviour (for example projectiles).

enum Kind { HITSCAN }

@export var id := "pistol"
@export var display_name := "Pistol"
@export var kind: Kind = Kind.HITSCAN
@export var damage := 25.0           ## 4 hits to take a full-health player down
@export var fire_interval := 0.17    ## fastest possible rate: about 6 shots per second
@export var automatic := false       ## false = one shot per click
@export var magazine := 12
@export var reload_time := 1.3
@export var max_range := 200.0
@export var spread_degrees := 0.25   ## small random aim wobble per shot


## Semi-automatic pistol: the only weapon for now. Numbers are first guesses for playtesting.
static func pistol() -> WeaponData:
	return WeaponData.new()


static func by_id(weapon_id: String) -> WeaponData:
	match weapon_id:
		_: return pistol()
