class_name WorldGravity
extends RefCounted
## How strong gravity is right now, as a share of normal: 1.0 almost always, lower
## while a map event (see GravityEvent) has turned it down.
##
## This is the one number the movement code multiplies its gravity by
## (MovementController and Grapple), so everything that falls by the players' rules
## follows it: jumps, falls, swings, slides downhill, wall runs and floats. Bullets,
## rockets and grenades do not read it: weapons behave the same whatever it says.
##
## Only a map event changes it. The arena puts it back to 1.0 when a match starts
## and when the map is unloaded, so a match that ends mid-event never leaks into
## the next one.

static var scale := 1.0


static func reset() -> void:
	scale = 1.0
