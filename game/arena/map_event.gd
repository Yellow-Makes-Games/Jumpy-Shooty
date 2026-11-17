class_name MapEvent
extends Node
## Something a map does for a while when a MapTerminal fires it (Halcyon's low
## gravity, see GravityEvent). Put one in the map scene and point a terminal's
## Event at it.
##
## The host owns it: it starts it (host_start) and keeps its clock. Everyone else is
## told when it starts and how far along it is (also when they join mid-match, and
## now and then to stay in step), and plays the same thing from the same moment.
## To make another kind of event, extend this and fill in length() and _update().
##
## (Like the other map nodes, this reaches the game's autoloads by path, not by
## name, so a map scene still loads in the tests that run without them.)

const GROUP := "map_events"
const RESYNC := 5.0   ## seconds between the host's reminders of where the event is

signal started
signal ended

## It has been started and has not finished yet (cooldown included): terminals stay
## locked while this is true.
var running := false
## Seconds since it started, on the host's clock.
var elapsed := 0.0

var _resync := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	var net := autoload("Net")
	if net:
		net.match_started.connect(stop)
	var rules := autoload("Match")
	if rules:
		rules.match_over.connect(_on_match_over)


## One of the game's autoloads ("Net", "Match", "Sound", "DevArgs"), or null.
func autoload(which: String) -> Node:
	return get_node_or_null("/root/" + which) if is_inside_tree() else null


## Is this copy of the game the one that decides (the host, or playing offline)?
func is_host() -> bool:
	var net := autoload("Net")
	return net == null or net.is_host()


func _tell(now_running: bool, at: float) -> void:
	var net := autoload("Net")
	if net:
		net.send_map_event_state(index(), now_running, at)   # reaches apply_state() here too
	else:
		apply_state(now_running, at)


func _exit_tree() -> void:
	stop()


func _on_match_over(_results: Array) -> void:
	stop()


## Seconds from start to the moment a terminal may fire it again.
func length() -> float:
	return 0.0


## Called every physics frame while it runs, and once more with running = false
## when it stops, so the event can put everything back.
func _update(_delta: float) -> void:
	pass


func busy() -> bool:
	return running


## Which event this is in the map (the same number on every copy of the game).
func index() -> int:
	return get_tree().get_nodes_in_group(GROUP).find(self) if is_inside_tree() else -1


## Host: start it now. `by` is the player who set it off (0 = nobody).
func host_start(by: int = 0) -> void:
	if running or not is_host():
		return
	var net := autoload("Net")
	print("[map] %s started%s" % [name, " by %s" % net.player_name(by) if by != 0 and net else ""])
	_tell(true, 0.0)


## Everyone: the host says where the event is.
func apply_state(now_running: bool, at: float) -> void:
	var was := running
	running = now_running
	elapsed = at if now_running else 0.0
	_resync = RESYNC
	if running and not was:
		started.emit()
	elif was and not running:
		_update(0.0)
		ended.emit()


## Ends it at once, wherever it was (the match is over, or the map is going away).
func stop() -> void:
	if not running:
		return
	running = false
	elapsed = 0.0
	_update(0.0)
	ended.emit()


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if elapsed >= length():
		if is_host():
			print("[map] %s is ready again" % name)
			_tell(false, 0.0)
		else:
			stop()   # the host's word follows; nothing is left to show either way
		return
	_update(delta)
	var net := autoload("Net")
	if net and net.is_host() and net.is_online:
		_resync -= delta
		if _resync <= 0.0:
			net.send_map_event_state(index(), true, elapsed)


## The event with this number in the running map, or null.
static func at(tree: SceneTree, i: int) -> MapEvent:
	var list := tree.get_nodes_in_group(GROUP)
	return list[i] as MapEvent if i >= 0 and i < list.size() else null
