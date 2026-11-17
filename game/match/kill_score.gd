class_name KillScore
extends RefCounted
## How good a kill looks on a killcam: the score that picks the match's best kills
## for the results screen, and the tags shown with them ("HEADSHOT", "42 M").
##
## The host scores each kill the moment it happens, from facts it already has (who
## was where, in what move, with what, how the blow landed), and sends the score with
## the death. So every copy of the match has the same scores and the same best kills;
## nothing extra has to be measured or sent per frame.
##
## Why these points: this is a movement shooter, so the kills worth watching again
## are the ones that show off the movement (on the rope, off a wall, gliding, in the
## air) and the aim (a headshot, a long way off, a target in the air); a multikill is
## the classic highlight, and a kick or a crash into a wall is the game's own flourish.
## A plain kill on the ground at close range scores just the base, so it is only
## shown when the match had nothing better. Ties go to the earlier kill.

const BASE := 100
const RANGE_FROM := 15.0     ## metres: every metre past this is worth RANGE_PER points...
const RANGE_PER := 3.0
const RANGE_MAX := 150       ## ...up to this many
const LONG_SHOT := 30.0      ## the "42 M" tag from this far
const HEADSHOT := 60
const MID_AIR := 40          ## the killer is off the ground
const ON_ROPE := 50          ## ...swinging on the grapple (on top of MID_AIR)
const WALL_RUN := 45         ## ...running along a wall (on top of MID_AIR)
const GLIDING := 40          ## ...gliding (on top of MID_AIR)
const AIR_SHOT := 35         ## the victim was in the air
const MULTI := 90            ## per earlier kill by the same killer in the last MULTI_WINDOW seconds
const MULTI_WINDOW := 4.0
const KICK := 60
const FLYING_KICK := 100
const SMASHED := 70          ## shoved or reeled into a wall
const MELEE := 30
const CLUTCH := 40           ## the killer had CLUTCH_HP or less left
const CLUTCH_HP := 25.0

## Tag bits (sent with the score; every copy turns them back into words).
const T_HEADSHOT := 1
const T_LONG := 2
const T_MID_AIR := 4
const T_ROPE := 8
const T_WALL := 16
const T_GLIDE := 32
const T_AIR_SHOT := 64
const T_KICK := 128
const T_FLYING_KICK := 256
const T_SMASHED := 512
const T_MELEE := 1024
const T_CLUTCH := 2048

const S := MovementController.State
const AIRBORNE := [S.AIR, S.GRAPPLE, S.WALL_RUN, S.FLIP, S.DIVE, S.GLIDE]


## facts: {distance: metres, headshot, killer_state, victim_state (MovementController.State),
## cause ("", "kick", "flying_kick", "slam"), melee, streak (earlier kills in the window),
## killer_hp}. Returns [score, tag bits].
static func score(facts: Dictionary) -> Array:
	var points := BASE
	var tags := 0
	var dist := float(facts.get("distance", 0.0))
	points += mini(int(maxf(dist - RANGE_FROM, 0.0) * RANGE_PER), RANGE_MAX)
	if dist >= LONG_SHOT:
		tags |= T_LONG
	if facts.get("headshot", false):
		points += HEADSHOT
		tags |= T_HEADSHOT
	var ks := int(facts.get("killer_state", S.GROUND))
	if ks in AIRBORNE:
		points += MID_AIR
		tags |= T_MID_AIR
		if ks == S.GRAPPLE:
			points += ON_ROPE
			tags |= T_ROPE
		elif ks == S.WALL_RUN:
			points += WALL_RUN
			tags |= T_WALL
		elif ks == S.GLIDE:
			points += GLIDING
			tags |= T_GLIDE
	if int(facts.get("victim_state", S.GROUND)) in AIRBORNE:
		points += AIR_SHOT
		tags |= T_AIR_SHOT
	match str(facts.get("cause", "")):
		"kick":
			points += KICK
			tags |= T_KICK
		"flying_kick":
			points += FLYING_KICK
			tags |= T_FLYING_KICK
		"slam":
			points += SMASHED
			tags |= T_SMASHED
		_:
			if facts.get("melee", false):
				points += MELEE
				tags |= T_MELEE
	points += MULTI * int(facts.get("streak", 0))
	if float(facts.get("killer_hp", 100.0)) <= CLUTCH_HP:
		points += CLUTCH
		tags |= T_CLUTCH
	return [points, tags]


## The words for a kill, most telling first: ["TRIPLE KILL", "ON THE ROPE", "HEADSHOT", "42 M"].
static func tag_words(tags: int, streak: int, distance: float) -> Array:
	var out: Array = []
	if streak >= 1:
		out.append(["DOUBLE KILL", "TRIPLE KILL", "QUAD KILL"][mini(streak, 3) - 1] if streak <= 3 else "MULTI KILL")
	if tags & T_FLYING_KICK:
		out.append("FLYING KICK")
	elif tags & T_KICK:
		out.append("KICKED OUT")
	if tags & T_SMASHED:
		out.append("SMASHED INTO A WALL")
	if tags & T_ROPE:
		out.append("ON THE ROPE")
	elif tags & T_WALL:
		out.append("OFF THE WALL")
	elif tags & T_GLIDE:
		out.append("GLIDING")
	elif tags & T_MID_AIR:
		out.append("MID-AIR")
	if tags & T_HEADSHOT:
		out.append("HEADSHOT")
	if tags & T_AIR_SHOT:
		out.append("AIR SHOT")
	if tags & T_MELEE:
		out.append("CUT DOWN")
	if tags & T_CLUTCH:
		out.append("CLUTCH")
	if tags & T_LONG:
		out.append("%d M" % roundi(distance))
	return out


## The match's best kills: highest score first, the earlier kill first on a tie.
## kills: Array of kill infos (see Match.kill_info). Returns at most `count`.
static func best(kills: Array, count: int = 3) -> Array:
	var sorted := kills.duplicate()
	sorted.sort_custom(func(a, b):
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.seq) < int(b.seq))
	return sorted.slice(0, count)
