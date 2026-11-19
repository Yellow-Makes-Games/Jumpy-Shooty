class_name PlayerLevel
extends RefCounted
## Your level, from your experience: every kill adds its killcam score (see KillScore:
## about 100 for a plain kill, several hundred for a stylish one), kept by Achievements
## as the "xp" count. Each level takes a little more than the one before.
##
##   PlayerLevel.of(Achievements.stat("xp"))   # {level, into, need}

const FIRST := 1500   ## experience from level 1 to 2
const STEP := 300     ## each level after needs this much more than the one before


## The experience it takes to go from `level` to the next.
static func need(level: int) -> int:
	return FIRST + STEP * maxi(level - 1, 0)


## Your level for `xp` experience, how far into it you are, and what it takes.
static func of(xp: int) -> Dictionary:
	var level := 1
	var left := maxi(xp, 0)
	while left >= need(level):
		left -= need(level)
		level += 1
	return {"level": level, "into": left, "need": need(level)}
