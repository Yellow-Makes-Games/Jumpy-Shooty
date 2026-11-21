class_name MapBuildBudget
extends RefCounted
## Lets a long map build stop now and then, so the screen keeps drawing (the
## loading screen's animation) instead of freezing until the map is done.
##
## The build's loops ask due() as they go; when this frame's slice of time is used
## up they `await wait()`, which picks up again on the next frame:
##     if budget and budget.due():
##         await budget.wait()
## With no budget (null) nothing waits and the build runs straight through, as the
## tests and the editor tools want.

const SLICE_USEC := 8000   ## work this long, then let a frame draw

var waits := 0   ## how many frames the build has been spread over (for the timing line)
var slice_usec := SLICE_USEC
var _tree: SceneTree
var _since := 0


## `slice_usec`: how long to work each frame (the tests pass 0 to stop at every check).
func _init(tree: SceneTree, slice: int = SLICE_USEC) -> void:
	_tree = tree
	slice_usec = slice
	_since = Time.get_ticks_usec()


## This frame's slice is used up.
func due() -> bool:
	return Time.get_ticks_usec() - _since >= slice_usec


## Waits for the next frame (await it).
func wait() -> void:
	waits += 1
	await _tree.process_frame
	_since = Time.get_ticks_usec()
