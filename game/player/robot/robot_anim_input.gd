class_name RobotAnimInput
extends RefCounted
## Everything the body animation needs to know about a player this frame. It is
## filled the same way for you, for bots, and for other players (from their
## network snapshots), so everyone sees the same animation.

var state: int = MovementController.State.AIR
var crouched := false
var velocity := Vector3.ZERO     ## world space
var yaw := 0.0                   ## facing, radians
var pitch := 0.0                 ## aim up/down, radians
var flags := 0                   ## see make_flags()
var grapple_on := false
var grapple_anchor := Vector3.ZERO
var alive := true

const FLIP_FRONT := 0
const FLIP_BACK := 1
const FLIP_LEFT := 2
const FLIP_RIGHT := 3


## Small facts packed into one number so they fit in a movement snapshot:
## bit 0     the wall being run on (or last kicked off) is on the right
## bit 1     the mantle in progress is a vault (otherwise a ledge climb)
## bit 2     reloading
## bits 3-4  flip direction (front, back, left, right)
## bits 5-6  wall-jump counter (goes up by one, wrapping, on every wall jump)
## bits 7-8  melee swing counter (goes up by one, wrapping, on every swing)
## bits 9-10 kick counter (every kick, flying or not)
## bit 11    in a flying kick
## bits 12-13 rocket-boot burst counter
## bit 14    winding up a melee swing (holding the button)
static func make_flags(wall_right: bool, vaulting: bool, reloading: bool, flip: int, wall_jumps: int, swings: int = 0,
		kicks: int = 0, flying_kick: bool = false, boosts: int = 0, winding: bool = false) -> int:
	return (1 if wall_right else 0) | (2 if vaulting else 0) | (4 if reloading else 0) \
		| ((flip & 3) << 3) | ((wall_jumps & 3) << 5) | ((swings & 3) << 7) \
		| ((kicks & 3) << 9) | ((1 if flying_kick else 0) << 11) | ((boosts & 3) << 12) \
		| ((1 if winding else 0) << 14)


static func winding_of(f: int) -> bool:
	return (f >> 14) & 1 == 1


static func kicks_of(f: int) -> int:
	return (f >> 9) & 3


static func flying_of(f: int) -> bool:
	return (f >> 11) & 1 == 1


static func boosts_of(f: int) -> int:
	return (f >> 12) & 3


static func swings_of(f: int) -> int:
	return (f >> 7) & 3


func wall_right() -> bool:
	return flags & 1 != 0


func vaulting() -> bool:
	return flags & 2 != 0


func reloading() -> bool:
	return flags & 4 != 0


func flip() -> int:
	return (flags >> 3) & 3


func wall_jumps() -> int:
	return (flags >> 5) & 3
