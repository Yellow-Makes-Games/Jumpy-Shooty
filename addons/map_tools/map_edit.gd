@tool
extends RefCounted
## One change to a map, described so it can be done and undone: nodes to add, nodes
## to take out, properties to set and methods to call. The tools and commands make
## these; the plugin turns one into a single undo step (plugin.gd apply_edit), and the
## tests just apply() it.

## The name shown in Edit > Undo.
var name := ""
## [parent, node, index]: add `node` under `parent` at `index` (-1 = last).
var adds := []
## Nodes to take out of the scene.
var removes := []
## [object, property, new value, old value].
var sets := []
## [object, method, args...] called when it is done (after the rest), and when undone.
var do_calls := []
var undo_calls := []
## What is selected afterwards (if `reselect`).
var select := []
var reselect := false


func is_empty() -> bool:
	return adds.is_empty() and removes.is_empty() and sets.is_empty() and do_calls.is_empty()


## Does it at once, with no undo. `keeper`: the scene root that owns added nodes.
func apply(keeper: Node = null) -> void:
	for r: Node in removes:
		r.get_parent().remove_child(r)
	for a in adds:
		var parent: Node = a[0]
		var node: Node = a[1]
		parent.add_child(node, true)
		if a[2] >= 0:
			parent.move_child(node, a[2])
		if keeper:
			MapPiece.adopt(node, keeper)
	for s in sets:
		(s[0] as Object).set(s[1], s[2])
	for c in do_calls:
		(c[0] as Object).callv(c[1], c.slice(2))
