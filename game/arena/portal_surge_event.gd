class_name PortalSurgeEvent
extends MapEvent
## A map's ring gates open for a while (Empyrean Tower's Portal Surge). Put one in a
## map scene with MapRingGate nodes (two for each Pair number) and point a
## MapTerminal's Event at it (the rune altar: a terminal with Channel Time 2).
##
## Once started the gates power up over `open_time` (their emitter nodes light in
## turn, then the portal's surface forms), stay open for `duration`, collapse over
## `close_time`, and then the terminal stays locked for `cooldown`. While they are
## open, walking (or falling, or swinging) into a gate brings you out of the other
## gate of its pair, your speed carried through and turned to match, facing the way
## that gate faces: the portal gun's own maths (Portals), nothing new.
##
## The gates' portals belong to the map, not to a player: the portal gun's rules do
## not apply to them (no limit on how far apart a pair is; nobody's death, tool or
## broken wall closes them) and they leave players' own portals alone. Only players
## go through: bullets, rockets and grenades fly on as if the portal were not there.
## Before the gates are fully open, and from the moment they start to collapse, a
## gate is only a ring: dormant gates do not teleport.
##
## All of it is in the world, nothing on the HUD: the surfaces are violet and gold
## (never the portal gun's blue and orange), a rising shimmer and a mechanical whine
## as they open, a soft hum from each gate while it is open, a soft whoosh as they
## collapse, and the map's light pulses a little warmer throughout. Never red, never
## flashing, no alarm.
##
## The host owns the clock (MapEvent): every copy opens and closes its gates from it,
## also a copy that joins part-way, and each copy moves the players it runs through.

## Seconds the gates take to power up.
@export var open_time := 2.0
## Seconds they stay open.
@export var duration := 30.0
## Seconds they take to collapse.
@export var close_time := 2.0
## Seconds after that before the altar can start it again.
@export var cooldown := 60.0

@export_group("Look and sound")
## The colour the map's light leans toward while the surge runs.
@export var warm_color := Color(1.0, 0.78, 0.5)
## How far it leans (0 = not at all).
@export_range(0.0, 1.0) var warm_amount := 0.35
## Kinds from the palette that glow brighter while it runs (rune lines, conduits).
@export var pulse_kinds: PackedStringArray = []

const OPEN_SOUND := "surge_open"
const CLOSE_SOUND := "surge_close"

## 0..1: how far open the gates are right now.
var level := 0.0

var _gates: Array = []       # every MapRingGate in the map
var _pairs: Array = []       # [[Portal, Portal], ...] for Portals, when they are open
var _linked := false         # the pairs are with the arena's Portals right now
var _found := false
var _map: MapRoot
var _env: Environment
var _env_base := {}
var _sun: DirectionalLight3D
var _sun_base := {}
var _pulse_mats: Array = []  # [StandardMaterial3D, its emission energy]
var _looks := false
var _time := 0.0
var _closing_played := false
## Tests: the Portals node to hand the open pairs to, instead of the arena's.
var portals_override: Node


func length() -> float:
	return open_time + duration + close_time + cooldown


## How far open the gates are `t` seconds after it started.
func level_at(t: float) -> float:
	if t <= 0.0 or t >= open_time + duration + close_time:
		return 0.0
	if t < open_time:
		return t / open_time
	if t <= open_time + duration:
		return 1.0
	return 1.0 - (t - open_time - duration) / close_time


## Can people go through the gates right now? Only while they are fully open.
func passable() -> bool:
	return running and elapsed >= open_time and elapsed < open_time + duration


## Are the gates open or on their way (not the cooldown)?
func active() -> bool:
	return running and elapsed < open_time + duration + close_time


func _update(delta: float) -> void:
	_time += delta
	level = level_at(elapsed) if running else 0.0
	_find_gates()
	var usable := passable()
	for g in _gates:
		(g as MapRingGate).set_power(level, usable)
	_link(usable)
	if running and not _closing_played and elapsed >= open_time + duration:
		_closing_played = true
		_play(CLOSE_SOUND)
	_show()


func apply_state(now_running: bool, at: float) -> void:
	var was := running
	super(now_running, at)
	if running and not was:
		_closing_played = elapsed >= open_time + duration
		if elapsed < open_time:
			_play(OPEN_SOUND)
	if running:
		_update(0.0)


func _exit_tree() -> void:
	super()
	_link(false)


## The map's gates, and the pairs their portals make: gate A's front with gate B's
## front, and (for gates with two sides) back with back.
func _find_gates() -> void:
	if _found or not is_inside_tree():
		return
	_found = true
	_map = MapRoot.of(self)
	var by_pair := {}
	for n in get_tree().get_nodes_in_group(MapRingGate.GROUP):
		var gate := n as MapRingGate
		if gate == null or (_map != null and MapRoot.of(gate) != _map):
			continue
		_gates.append(gate)
		if not by_pair.has(gate.pair):
			by_pair[gate.pair] = []
		by_pair[gate.pair].append(gate)
	var numbers := by_pair.keys()
	numbers.sort()
	for number in numbers:
		var two: Array = by_pair[number]
		if two.size() != 2:
			push_warning("PortalSurgeEvent: pair %d has %d gates, it needs 2" % [number, two.size()])
			continue
		var a: Array = (two[0] as MapRingGate).frames()
		var b: Array = (two[1] as MapRingGate).frames()
		_pairs.append([a[0], b[0]])
		if a.size() > 1 and b.size() > 1:
			_pairs.append([a[1], b[1]])
		elif a.size() > 1:
			_pairs.append([a[1], b[0]])   # (one of them stands against a wall: either side of the other leads to its front)
		elif b.size() > 1:
			_pairs.append([a[0], b[1]])


## How many pairs of gates the map has.
func pair_count() -> int:
	_find_gates()
	var seen := {}
	for g in _gates:
		seen[(g as MapRingGate).pair] = true
	return seen.size()


func gates() -> Array:
	_find_gates()
	return _gates


## The arena's Portals node (found by name, not by type: like the other map nodes this
## script must load in tests that run without the game's autoloads, which Portals uses).
func _portals() -> Node:
	if portals_override != null:
		return portals_override if is_instance_valid(portals_override) else null
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena):
		return null
	return arena.get("portals") as Node


func _link(on: bool) -> void:
	if on == _linked:
		return
	var portals := _portals()
	if portals == null:
		if not on:
			_linked = false
		return
	_linked = on
	portals.call("set_map_pairs", _pairs if on else [])


# ---------------------------------------------------------------------------
# The look: the map's light a little warmer, breathing slowly

func _show() -> void:
	if not is_inside_tree():
		return
	if not _looks:
		_find_looks()
	# A slow breath on top of the level (about 5 s a cycle, never a flash).
	var breath := level * (0.8 + 0.2 * sin(_time * 1.25))
	if _env:
		_env.ambient_light_color = (_env_base.color as Color).lerp(warm_color, breath * warm_amount)
		_env.ambient_light_energy = lerpf(_env_base.energy, _env_base.energy * 1.12, breath)
	if _sun:
		_sun.light_color = (_sun_base.color as Color).lerp(warm_color, breath * warm_amount * 0.6)
	for m in _pulse_mats:
		(m[0] as StandardMaterial3D).emission_energy_multiplier = (m[1] as float) * (1.0 + 0.6 * breath)


func _find_looks() -> void:
	_looks = true
	_map = MapRoot.of(self)
	if _map == null or not _map.has_meshes or DisplayServer.get_name() == "headless":
		return
	var found := _map.find_children("*", "WorldEnvironment", true, false)
	if not found.is_empty() and (found[0] as WorldEnvironment).environment:
		var world := found[0] as WorldEnvironment
		_env = world.environment.duplicate()   # our own copy: the scene's shared one is never left changed
		world.environment = _env
		_env_base = {"color": _env.ambient_light_color, "energy": _env.ambient_light_energy}
	_sun = _map.get_node_or_null("Sun") as DirectionalLight3D
	if _sun:
		_sun_base = {"color": _sun.light_color}
	for kind in pulse_kinds:
		var mat := _map.material_for(kind) as StandardMaterial3D
		if mat and mat.emission_enabled:
			_pulse_mats.append([mat, mat.emission_energy_multiplier])


# ---------------------------------------------------------------------------
# The sound: one swell as they open and one whoosh as they close, heard everywhere
# (each gate hums by itself: see MapRingGate)

func _play(which: String) -> void:
	var dev := autoload("DevArgs")
	var sound := autoload("Sound")
	if dev and dev.sound_log:
		print("SFX %s" % which)
	if sound == null or sound.silent:
		return
	sound.play(which)
