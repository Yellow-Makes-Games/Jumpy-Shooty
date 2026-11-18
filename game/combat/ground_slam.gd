class_name GroundSlam
## The ground slam: with a melee weapon, hold crouch while you wind a swing up in
## mid-air and let go. You drive straight down, and where you land everyone near takes
## the blow and is thrown up and away: all of it right under you, less toward the
## edge. It hits harder the more it was wound up and the further you fell. The host
## decides who it hit (Match.request_ground_slam). Numbers to tune by playtesting.

const RADIUS := 4.0          ## metres from where you land that it reaches
const DIRECT := 1.2          ## within this, the whole blow
const EDGE := 0.3            ## the share of it at the rim
const ABOVE := 2.5           ## it does not reach anyone higher above the floor than this
const COOLDOWN := 3.0        ## seconds between slams
const FALL_FULL := 10.0      ## fall this far (metres) or more for the whole of...
const FALL_BONUS := 0.5      ## ...this much extra, as a share of the blow
const HAMMER := 1.3          ## the hammer's slam is this much stronger
const SHOVE_OUT := 0.7       ## how much of the weapon's shove throws them outward...
const SHOVE_UP := 0.6        ## ...and how much of it is added to its lift
const BREAK_AT := 0.95       ## wound up this far, it breaks the floor under you if that can break...
const BREAK_AT_HAMMER := 0.5 ## ...and the hammer needs only this much


## The blow right under you: the weapon's own for that wind-up, more for a long fall.
static func damage(weapon: WeaponData, charge: float, fell: float) -> float:
	return weapon.melee_damage(charge) * _scale(weapon, fell)


## How hard it throws someone a share `part` of the blow reaches: [outward, upward] m/s.
static func shove(weapon: WeaponData, charge: float, fell: float, part: float) -> Array:
	var push: Array = weapon.melee_knockback(charge)
	var hard := float(push[0]) * _scale(weapon, fell) * part
	return [hard * SHOVE_OUT, float(push[1]) * part + hard * SHOVE_UP]


static func _scale(weapon: WeaponData, fell: float) -> float:
	return (1.0 + FALL_BONUS * clampf(fell / FALL_FULL, 0.0, 1.0)) * (HAMMER if weapon.id == "hammer" else 1.0)


## The share of the blow that reaches someone `distance` metres from where you landed.
static func share(distance: float) -> float:
	if distance > RADIUS:
		return 0.0
	return lerpf(1.0, EDGE, clampf((distance - DIRECT) / (RADIUS - DIRECT), 0.0, 1.0))


## Does a slam wound up this far break the floor under it?
static func breaks_floor(weapon: WeaponData, charge: float) -> bool:
	return charge >= (BREAK_AT_HAMMER if weapon.id == "hammer" else BREAK_AT)


## How big it looks and sounds, 0..1.
static func power(weapon: WeaponData, charge: float, fell: float) -> float:
	return clampf(0.3 + 0.45 * charge + 0.25 * clampf(fell / FALL_FULL, 0.0, 1.0) + (0.1 if weapon.id == "hammer" else 0.0), 0.0, 1.0)
