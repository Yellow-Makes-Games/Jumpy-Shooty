class_name MovementTuning
extends Resource
## Every number that shapes how movement feels lives here, in one place.
## Distances are metres, speeds metres/second, times seconds.
## Values are first guesses to be tuned by playtesting.

const EYE_HEIGHT := 1.6  ## eyes above the feet, standing

@export_group("Ground")
@export var run_speed := 8.0          ## top speed you accelerate to while running
@export var sprint_speed := 11.5      ## top speed while holding sprint
@export var ground_accel := 11.0      ## how quickly you reach top speed
@export var friction := 7.0           ## how quickly you stop when you let go
@export var stop_speed := 3.0         ## below this speed, friction acts as if you were at this speed (crisp stops)
@export var overspeed_friction := 1.6 ## gentler friction when above top speed, so momentum from jumps and swings carries

@export_group("Air")
@export var air_accel := 3.0          ## steering strength in the air
@export var air_speed := 8.0          ## air steering can push you up to this speed, never slows you down
@export var gravity := 22.0
@export var max_fall_speed := 55.0

@export_group("Jump")
@export var jump_velocity := 7.2
@export var coyote_time := 0.12       ## you can still jump this long after running off a ledge
@export var jump_buffer := 0.12       ## a jump pressed this long before landing still happens

@export_group("Grapple")
@export var grapple_range := 45.0         ## how far the hook reaches
@export var grapple_cooldown := 0.6       ## seconds after letting go before it can fire again
@export var grapple_min_length := 2.0     ## the rope never gets shorter than this
@export var grapple_attach_height := 1.2  ## where the rope meets the body (chest height)
@export var grapple_air_accel := 6.0      ## steering strength while swinging (lets you pump the swing)
@export var grapple_reel_speed := 0.0     ## metres per second the rope shortens on its own (0 = never)
@export var grapple_jump_boost := 4.5     ## upward kick when you jump off the rope
