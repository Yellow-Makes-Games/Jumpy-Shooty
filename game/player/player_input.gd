class_name PlayerInput
extends RefCounted
## One frame of player intent. Filled from the keyboard and mouse for the local
## player, from the AI for bots, and from scripts in tests. The movement code only
## ever reads this, so humans, bots and tests all move by the same rules.

var move := Vector2.ZERO   ## x = right, y = forward, length 0..1
var yaw := 0.0             ## look direction around the vertical axis, radians
var pitch := 0.0           ## look up/down, radians
var jump_held := false
var jump_pressed := false  ## true only on the frame the jump was pressed
var sprint := false
var crouch := false
var dive_pressed := false
var grapple := false
var fire := false          ## trigger held (automatic weapons)
var fire_pressed := false  ## trigger pulled this frame (semi-automatic weapons)


func clear_edges() -> void:
	jump_pressed = false
	dive_pressed = false
	fire_pressed = false
