extends CharacterBody3D
## A stand-in player for grapple_point_test.gd: alive and visible.

var alive := true


func visible_in_world() -> bool:
	return true
