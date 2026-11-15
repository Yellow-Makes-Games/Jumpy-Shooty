class_name WeaponData
extends Resource
## Describes one weapon. New weapons are new WeaponData values, not new code,
## unless they need a new kind of behaviour (for example projectiles).

enum Kind { HITSCAN }

@export var id := "test_gun"
@export var display_name := "Test Gun"
@export var kind: Kind = Kind.HITSCAN
@export var damage := 20.0
@export var fire_interval := 0.12   ## seconds between shots (0.12 = ~8 shots per second)
@export var automatic := true        ## hold to keep firing
@export var magazine := 20
@export var reload_time := 1.5
@export var max_range := 200.0
@export var spread_degrees := 0.6    ## random aim wobble per shot


## The placeholder weapon used until the real weapons are designed.
static func test_gun() -> WeaponData:
	return WeaponData.new()


static func by_id(weapon_id: String) -> WeaponData:
	match weapon_id:
		_: return test_gun()
