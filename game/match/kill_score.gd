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
## Motion drives this game, so momentum counts for a lot, but only when BOTH players
## are moving: it scores the two speeds together (their geometric mean), so a kill on
## someone standing still, or from standing still, gets next to none of it. A flick,
## the aim swinging a long way in the moment before the kill, counts too. And the
## kills everyone agrees are the coolest are trickshots, several of these at once, so
## each extra trick in the same kill (in the air, hitting a target in the air, a
## flick, a long shot) adds a big combo bonus on top.
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
## Blows: a kick, a flying kick, a crash into a wall, a blade. Close up, the moves that
## make a shot special come with the blow anyway (a grapple reels you in fast and in the
## air, the kick flings the target fast and into the air, you turn to face them), so on
## a blow: momentum counts at BLOW_MOTION of its points, and the flick, the air shot and
## the trickshot combo do not count. That keeps grapple-and-kick a good killcam, not
## the best one every time (players found it was).
const KICK := 40
const FLYING_KICK := 60
const SMASHED := 50          ## shoved or reeled into a wall
const MELEE := 30
const BLOW_MOTION := 0.4
const BLOWS := 128 | 256 | 512 | 1024   ## T_KICK | T_FLYING_KICK | T_SMASHED | T_MELEE
const CLUTCH := 40           ## the killer had CLUTCH_HP or less left
const CLUTCH_HP := 25.0
## Momentum (m/s, the whole velocity). Sprinting is 11.5; a swing, a dive or a rocket
## burst takes you past 18, and 25 and up is rare. The two players' speeds count
## together, as sqrt(killer * victim): 0 if either stands still, the speed itself if
## both go the same speed. Every m/s of that past MOTION_FROM is worth MOTION_PER.
const MOTION_FROM := 6.0
const MOTION_PER := 10.0
const MOTION_MAX := 220      ## (at 28 m/s each)
const SPEED_CAP := 40.0      ## a speed counts as at most this (a blow can fling a body faster)
const FAST := 18.0           ## the "24 M/S" tags from this fast
## A trickshot: TRICK for each trick past the first in the same kill. The tricks:
## the killer in the air (or on the rope, a wall, gliding), the victim in the air, a
## flick, a long shot.
const TRICK := 75
## The flick: how far the killer's aim swung (degrees, every turn added up) in the
## FLICK_WINDOW seconds before the kill.
const FLICK_WINDOW := 0.6
const FLICK_FROM := 20.0     ## every degree past this is worth a point...
const FLICK_MAX := 120       ## ...up to this many (at 140 degrees)
const FLICK := 60.0          ## the "FLICK 95°" tag from this far
## A spin: the killer turned all the way round in the air before the shot (one way,
## within the SPIN_WINDOW seconds they were last in the air). It takes the flick's place
## (it is a bigger one) and is one trick for the combo.
const SPIN_WINDOW := 1.5
const SPINS := [[720.0, 131072, 400], [360.0, 65536, 250], [180.0, 32768, 150]]   ## [degrees, tag, points], biggest first

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
const T_FAST := 4096
const T_TARGET_FAST := 8192
const T_FLICK := 16384
const T_180 := 32768
const T_360 := 65536
const T_720 := 131072
const T_SPIN := T_180 | T_360 | T_720

const TRICKS := [T_MID_AIR, T_AIR_SHOT, T_FLICK, T_LONG]

const S := MovementController.State
const AIRBORNE := [S.AIR, S.GRAPPLE, S.WALL_RUN, S.FLIP, S.DIVE, S.GLIDE, S.WALL_SIT]


## facts: {distance: metres, headshot, killer_state, victim_state (MovementController.State),
## cause ("", "kick", "flying_kick", "slam"), melee, streak (earlier kills in the window),
## killer_hp, killer_speed and victim_speed (m/s), flick and spin (degrees)}. Returns [score, tag bits].
static func score(facts: Dictionary) -> Array:
	var tags := 0
	var dist := float(facts.get("distance", 0.0))
	if dist >= LONG_SHOT:
		tags |= T_LONG
	if facts.get("headshot", false):
		tags |= T_HEADSHOT
	var ks := int(facts.get("killer_state", S.GROUND))
	if ks in AIRBORNE:
		tags |= T_MID_AIR
		if ks == S.GRAPPLE:
			tags |= T_ROPE
		elif ks == S.WALL_RUN:
			tags |= T_WALL
		elif ks == S.GLIDE:
			tags |= T_GLIDE
	if int(facts.get("victim_state", S.GROUND)) in AIRBORNE:
		tags |= T_AIR_SHOT
	match str(facts.get("cause", "")):
		"kick":
			tags |= T_KICK
		"flying_kick":
			tags |= T_FLYING_KICK
		"slam":
			tags |= T_SMASHED
		_:
			if facts.get("melee", false):
				tags |= T_MELEE
	if float(facts.get("killer_hp", 100.0)) <= CLUTCH_HP:
		tags |= T_CLUTCH
	var speed := float(facts.get("killer_speed", 0.0))
	if speed >= FAST:
		tags |= T_FAST
	var target := float(facts.get("victim_speed", 0.0))
	if target >= FAST:
		tags |= T_TARGET_FAST
	var flick := float(facts.get("flick", 0.0))
	if flick >= FLICK:
		tags |= T_FLICK
	if tags & T_MID_AIR and not is_blow(tags):   # a spin is a shot's, in the air
		var spun := float(facts.get("spin", 0.0))
		for s in SPINS:
			if spun >= float(s[0]):
				tags = (tags & ~T_FLICK) | int(s[1])
				break
	var total := 0
	for part in parts(tags, int(facts.get("streak", 0)), dist, speed, target, flick):
		total += int(part[1])
	return [total, tags]


## Where a kill's points came from, as [words, points] (none of them 0), the base first:
## [["KILL", 100], ["HEADSHOT", 60], ["SPEED 24 M/S", 60], ["FLICK 95°", 75]].
## They add up to its score. From the facts score() sends with the death, so every
## copy can show them (the host scores from the same rounded numbers it sends).
static func parts(tags: int, streak: int, distance: float, speed: float = 0.0, target: float = 0.0, flick: float = 0.0) -> Array:
	var out: Array = [["KILL", BASE]]
	var add := func(words: String, points: int) -> void:
		if points != 0:
			out.append([words, points])
	if streak >= 1:
		add.call(tag_words(0, streak, 0.0)[0], MULTI * streak)
	if tags & T_FLYING_KICK:
		add.call("FLYING KICK", FLYING_KICK)
	elif tags & T_KICK:
		add.call("KICKED OUT", KICK)
	if tags & T_SMASHED:
		add.call("SMASHED INTO A WALL", SMASHED)
	if tags & T_MELEE:
		add.call("CUT DOWN", MELEE)
	if tags & T_MID_AIR:
		add.call("MID-AIR", MID_AIR)
	if tags & T_ROPE:
		add.call("ON THE ROPE", ON_ROPE)
	elif tags & T_WALL:
		add.call("OFF THE WALL", WALL_RUN)
	elif tags & T_GLIDE:
		add.call("GLIDING", GLIDING)
	if tags & T_HEADSHOT:
		add.call("HEADSHOT", HEADSHOT)
	var blow := is_blow(tags)
	if tags & T_SPIN:
		add.call(spin_words(tags), spin_points(tags))
	elif not blow:   # (aim counts for shots; on a blow you just face them)
		add.call("FLICK %d°" % roundi(flick), mini(int(maxf(flick - FLICK_FROM, 0.0)), FLICK_MAX))
	var motion := motion_points(speed, target)
	if blow:
		add.call("MOMENTUM %d M/S (BLOW)" % roundi(minf(speed, SPEED_CAP)), int(motion * BLOW_MOTION))
	else:
		add.call("MOMENTUM %d · %d M/S" % [roundi(minf(speed, SPEED_CAP)), roundi(minf(target, SPEED_CAP))], motion)
	var tricks := trick_count(tags)
	if tricks >= 2:
		add.call("TRICKSHOT ×%d" % tricks, TRICK * (tricks - 1))
	if tags & T_AIR_SHOT and not blow:
		add.call("AIR SHOT", AIR_SHOT)
	if tags & T_CLUTCH:
		add.call("CLUTCH", CLUTCH)
	add.call("RANGE %d M" % roundi(distance), mini(int(maxf(distance - RANGE_FROM, 0.0) * RANGE_PER), RANGE_MAX))
	return out


## Points for the two players' speeds together (see MOTION_FROM).
static func motion_points(speed: float, target: float) -> int:
	var both := sqrt(clampf(speed, 0.0, SPEED_CAP) * clampf(target, 0.0, SPEED_CAP))
	return mini(int(maxf(both - MOTION_FROM, 0.0) * MOTION_PER), MOTION_MAX)


## "180", "360" or "720" for a spin's tag (see SPINS); "" for none.
static func spin_words(tags: int) -> String:
	for s in SPINS:
		if tags & int(s[1]):
			return str(int(s[0]))
	return ""


static func spin_points(tags: int) -> int:
	for s in SPINS:
		if tags & int(s[1]):
			return int(s[2])
	return 0


## A kick, a flying kick, a crash into a wall or a blade, not a shot (see BLOWS).
static func is_blow(tags: int) -> bool:
	return (tags & BLOWS) != 0


## How many tricks a kill had at once (see TRICK). A blow has none: tricks are for shots.
static func trick_count(tags: int) -> int:
	if is_blow(tags):
		return 0
	var n := 0
	for t in TRICKS:
		if tags & t:
			n += 1
	if tags & T_SPIN:   # (in the flick's place)
		n += 1
	return n


## parts() for a kill info (see Match.kill_info).
static func breakdown(info: Dictionary) -> Array:
	return parts(int(info.get("tags", 0)), int(info.get("streak", 0)), float(info.get("distance", 0.0)),
		float(info.get("speed", 0.0)), float(info.get("target_speed", 0.0)), float(info.get("flick", 0.0)))


## The words for a kill (see Match.kill_info), most telling first:
## ["TRIPLE KILL", "ON THE ROPE", "HEADSHOT", "FLICK 95°", "24 M/S", "42 M"].
static func words(info: Dictionary) -> Array:
	return tag_words(int(info.get("tags", 0)), int(info.get("streak", 0)), float(info.get("distance", 0.0)),
		float(info.get("speed", 0.0)), float(info.get("target_speed", 0.0)), float(info.get("flick", 0.0)))


static func tag_words(tags: int, streak: int, distance: float, speed: float = 0.0, target: float = 0.0, flick: float = 0.0) -> Array:
	var out: Array = []
	if streak >= 1:
		out.append(["DOUBLE KILL", "TRIPLE KILL", "QUAD KILL"][mini(streak, 3) - 1] if streak <= 3 else "MULTI KILL")
	if trick_count(tags) >= 2:
		out.append("TRICKSHOT")
	if tags & T_SPIN:
		out.append(spin_words(tags))
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
	var blow := is_blow(tags)   # (a blow flings the target: its speed and the air say little)
	if tags & T_FLICK and not blow:
		out.append("FLICK %d°" % roundi(flick))
	if tags & T_FAST:
		out.append("%d M/S" % roundi(minf(speed, SPEED_CAP)))
	if tags & T_TARGET_FAST and not blow:
		out.append("TARGET AT %d M/S" % roundi(minf(target, SPEED_CAP)))
	if tags & T_AIR_SHOT and not blow:
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
