class_name OrbitEvent
extends MapEvent
## A clock that turns a map's orbiting parts for as long as a match runs (Empyrean
## Tower's drifting chunks of debris). Put one in a map scene; no terminal needed.
## Every MapIsland in the map whose Orbit is not zero then goes round its Pivot at
## that many degrees a second, carrying whoever stands on it (and its pickups, spawn
## points and grapple points), the way Cirrus's islands carry theirs.
##
## The host owns the clock, as with every MapEvent: it starts it when a match starts
## and reminds everyone of it every few seconds, and every copy places the islands
## from that clock alone, so they are in the same place for everyone, also for someone
## who joins part-way. With the clock stopped every island is at its home. Nothing
## else changes: no warning, no sound, nothing is ever "doomed", and the bots'
## navigation mesh is left alone (they do not go out there).

var _islands: Array = []
var _found := false


## It never ends by itself (the match's end does not stop it either: the chunks drift on).
func length() -> float:
	return INF


## Terminals have nothing to do with it.
func busy() -> bool:
	return false


func _on_match_over(_results: Array) -> void:
	pass


func _wanted() -> bool:
	var rules := autoload("Match")
	return rules != null and rules.running


func _physics_process(delta: float) -> void:
	if not running:
		if is_host() and _wanted():
			host_start()
		return
	super(delta)


func _update(_delta: float) -> void:
	if not _found and is_inside_tree():
		_found = true
		var map := MapRoot.of(self)
		for n in get_tree().get_nodes_in_group(MapIsland.GROUP):
			var island := n as MapIsland
			if island != null and island.orbit != 0.0 and (map == null or MapRoot.of(island) == map):
				_islands.append(island)
	var t := elapsed if running else 0.0
	for i in _islands:
		var island := i as MapIsland
		var pose := Vector3(fposmod(island.orbit * t, 360.0), 0.0, 0.0)
		island.pose_a = pose
		island.pose_b = pose
		island.blend = 0.0
