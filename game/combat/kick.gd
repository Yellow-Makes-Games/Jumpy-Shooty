class_name Kick
## The kick everyone has, whatever they carry (F), and the flying kick.
##
## A kick is a quick front kick: a short wind-up, then it hits anyone within
## REACH metres and ARC degrees of where you look, and shoves them hard. It has
## its own cooldown, so you can kick between shots or swings.
##
## The flying kick: grapple another player (the hook catches robots as well as
## walls) and the rope reels you both together. Press kick (or swing a melee
## weapon) while you are hooked to them and you let go and fly at them feet first,
## homing in for a moment. Landing it does big damage and sends them flying.
## The host decides every hit (see Match.request_kick).

const DAMAGE := 20.0
const REACH := 2.5           ## metres from your eyes (to the edge of their body)
const ARC := 50.0            ## degrees either side of where you look
const KNOCKBACK := 19.5
const KNOCKBACK_UP := 4.5
const COOLDOWN := 0.75       ## seconds between kicks
const WINDUP := 0.12         ## click to the blow landing
const LUNGE := 2.0           ## a small step forward
const STRUCTURE := 1.0       ## times DAMAGE against breakable walls

## Closing speed bonus (both kicks): knockback grows by this much per m/s the kicker
## is moving toward the target faster than the target is moving away, up to SPEED_MAX times.
const SPEED_KNOCKBACK := 0.16
const SPEED_MAX := 4.0

const FLYING_DAMAGE := 60.0
const FLYING_REACH := 3.2    ## a little longer: you are already flying at them
const FLYING_ARC := 80.0
const FLYING_KNOCKBACK := 45.0
const FLYING_KNOCKBACK_UP := 8.0
const FLYING_SPEED := 26.0   ## how fast you fly at them (or your own speed, if faster)
const FLYING_TIME := 0.7     ## seconds the kick can fly before it gives up
const FLYING_STEER := 9.0    ## how quickly it bends toward them as they move
## The host only takes a flying kick from someone who had a player hooked this
## recently (seconds).
const FLYING_WINDOW := 2.5
