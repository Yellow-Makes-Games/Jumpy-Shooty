class_name LayoutEvent
extends MapEvent
## A map of flying islands that rearranges itself on a timer (Cirrus: five building
## islands round a quad, only two of them up at any time). Put one in a map scene. It
## needs no terminal: it runs by itself for as long as a match does.
##
## One turn of its clock:
##  - `hold_time` seconds in the arrangement the map is in. A clock ticks once a second,
##    softly, all over the map and a little louder near `tick_from` (the clock tower).
##  - A bell tolls, and for `windup_time` seconds the change builds up, slowly and then
##    fast: a rising tone, a growing rumble, the engines (Flare Kinds) spooling up. The
##    islands that are about to go down are `doomed`: their engines and lamps turn
##    `doom_color` and sputter, and they sag. Nothing else moves yet: this is the time to get off.
##  - For `move_time` seconds the doomed islands fall away below the map (whoever is
##    still on one goes down with it, under the map's kill height), the ones that
##    stay glide to their new places, and the ones coming up rise out of the clouds
##    into theirs. A clunk when everything has arrived.
## Then the next turn begins.
##
## An arrangement is which `up_count` islands are up (never the same set twice running)
## and how they stand, drawn at random from a pool, never the same kind twice running:
##   Swap    each at its home, where the scene has it.
##   Drift   each a turn round the middle from its home (`drift_turns`).
##   Close   each `close_in` metres nearer the middle: a jump apart.
##   Far     each `far_out` metres further out, and all high or all low (`far_heights`).
##   Split   one high and one low (`split_height`).
## The look of the whole map has a second version (the sky, the sun, the ambient light,
## the fog below, and the kinds in Lit Kinds: windows and lamps that come on) and goes
## from one to the other with every change. During the warning and the move the clouds
## below swirl and paper and leaves blow about. All of it is in the world, none on the
## HUD. MapSpinners set to Countdown are the hands of a clock: once round per turn, at
## twelve when the bell goes. One set to Swing is the bell.
##
## The host owns it, like every MapEvent: it keeps the clock, and decides each
## arrangement a whole turn ahead. `state` holds the present arrangement and the next
## one as one number, so every copy places everything from the clock and that number
## alone: the islands are in the same place for everyone, also for someone who joins
## part-way, and everyone knows which islands are doomed. With the clock stopped (no
## match, or a team mode) every island is up at its home. In a team mode (Search and
## Destroy, Capture the Flag) it never runs: their bomb sites and flag stands are
## fixed spots worked out when the map loads.

enum Kind { SWAP, DRIFT, CLOSE, FAR, SPLIT }
const KIND_NAMES := ["Swap", "Drift", "Close", "Far", "Split"]
const BITS := 11             ## an arrangement fits in this many bits of `state`
const MASK := (1 << BITS) - 1

## How many islands are up at a time.
@export_range(1, 4) var up_count := 2
## Seconds the map stays as it is before the bell goes.
@export var hold_time := 60.0
## Seconds from the bell to the move: the warning.
@export var windup_time := 8.0
## Seconds a move takes.
@export var move_time := 4.0
## Metres below its home an island is parked when it is down (well under the kill height).
@export var down := 120.0
## Where the clock's tick comes from (in the map's frame): it is a little louder near here.
@export var tick_from := Vector3(0, 24, 0)

@export_group("Arrangements")
## Drift: the turns to pick from, in degrees round the middle.
@export var drift_turns: PackedFloat32Array = [-36.0, 36.0]
## Close: metres nearer the middle.
@export var close_in := 12.0
## Far: metres further out, and the heights to pick from (metres above home).
@export var far_out := 9.0
@export var far_heights: PackedFloat32Array = [7.0, -9.0]
## Split: metres one island stands above home, and the other below.
@export var split_height := 8.0

@export_group("Second look")
## The way to the sun in the second look (the first is the scene's Sun as it stands).
@export var sun_direction := Vector3(-0.8, 0.22, 0.55)
@export var sun_color := Color(1.0, 0.56, 0.32)
@export var sun_energy := 0.9
@export var ambient_color := Color(0.62, 0.5, 0.66)
@export var ambient_energy := 0.75
## The fog below the map (what sinking islands vanish into), in the second look.
@export var fog_color := Color(0.71, 0.49, 0.48)
## Kinds that light up in the second look (windows, lamps, light strips), and how bright.
@export var lit_kinds: PackedStringArray = []
@export var lit_glow := 2.4

@export_group("The move")
## Kinds that burn bright as the move builds and goes (the islands' engines), and how
## many times brighter.
@export var flare_kinds: PackedStringArray = []
@export var flare_gain := 3.5
## The colour a doomed island's engines turn while they sputter, and how far it sags.
## Doom Kinds turn that colour and flicker too (its lamps: the engines are underneath,
## where nobody standing on it can see them).
@export var doom_kinds: PackedStringArray = []
@export var doom_color := Color(1.0, 0.16, 0.08)
@export var doom_dip := 0.7
## Scraps of paper and leaves blown about during a move: how many (0 = none), and the
## box (in the map's frame) they blow through.
@export var scraps := 260
@export var scrap_volume := AABB(Vector3(-44, -18, -44), Vector3(88, 44, 88))

## Something to hear is due: "tick", "tock", "toll" (the bell: the warning begins),
## "move" (the islands go) or "lock" (they have arrived).
signal cue(what: String)

const TICK_SOUND := "clock_tick"
const TOCK_SOUND := "clock_tock"
const TOLL_SOUND := "bell_toll"
const RISE_SOUND := "layout_rise"
const MOVE_SOUND := "island_move"
const LOCK_SOUND := "bridge_lock"
const RISE_LENGTH := 8.0      ## seconds the rising tone lasts as recorded
const TICK_QUIET := -7.0      ## dB: the tick heard everywhere, under the one from the tower
const SWING := 0.5            ## radians the bell swings at first
const SWING_RATE := 0.55      ## swings per second
const SWING_FADE := 3.2       ## seconds for the swing to die down to about a third

## 0..1: which look the map has right now (0 = the scene's own, 1 = the second).
var blend := 0.0
## 0..1: how far through a move it is (0 when nothing moves).
var progress := 0.0
## 0..1: how far through the warning before a move it is (0 at any other time).
var windup := 0.0
## The host's dice (a test may seed it).
var rng := RandomNumberGenerator.new()

var _map: MapRoot
var _islands: Array = []
var _hands: Array = []     # MapSpinners that are clock hands
var _bells: Array = []     # MapSpinners that swing when the bell goes
var _sets: Array = []      # every set of up_count islands, by their numbers
var _found := false
var _looks := false
var _env: Environment
var _env_base := {}
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _sun_base := {}
var _lit: Array = []      # [StandardMaterial3D, base energy, had emission]
var _flare: Array = []    # [StandardMaterial3D, base energy]
var _scraps: MultiMeshInstance3D
var _scrap_mat: ShaderMaterial
var _shown := -1.0
var _shown_flare := -1.0
var _shake_wait := 0.0
var _time := 0.0
var _tolled := -1.0       # seconds since the bell last went on this copy (-1 = it has not)
var _turn_due := false
var _all_doom_kinds: PackedStringArray = []


func _ready() -> void:
	super()
	rng.randomize()
	_place.call_deferred()   # every island home, once the map is built


func team_mode() -> bool:
	var teams := autoload("Teams")
	return teams != null and teams.active()


## One whole turn: the wait, the warning and the move.
func length() -> float:
	return hold_time + windup_time + move_time


# ---------------------------------------------------------------------------
# Arrangements

## An arrangement as a number: which set of islands is up (1.. in sets(); 0 = all of
## them, at home), how they stand, a throw of the dice for the details, and the look.
static func pack(which_set: int, kind: int, variant: int, look: int) -> int:
	return (which_set & 15) | ((kind & 7) << 4) | ((variant & 7) << 7) | ((look & 1) << 10)


## The arrangement the map is in (or was in when the move now under way began).
func now() -> int:
	return state & MASK


## The arrangement the next move goes to.
func next() -> int:
	return (state >> BITS) & MASK


static func kind_of(config: int) -> int:
	return (config >> 4) & 7


static func look_of(config: int) -> int:
	return (config >> 10) & 1


## Every set of `up_count` islands (their numbers, in the order the map has them).
func sets() -> Array:
	if _sets.is_empty():
		_combine([], 0)
	return _sets


func _combine(chosen: Array, from: int) -> void:
	if chosen.size() == up_count:
		_sets.append(chosen.duplicate())
		return
	for i in range(from, island_count()):
		chosen.append(i)
		_combine(chosen, i + 1)
		chosen.pop_back()


func island_count() -> int:
	if not _found:
		_find_parts()
	return _islands.size()


## The numbers of the islands that are up in an arrangement.
func up_in(config: int) -> Array:
	var which := config & 15
	if which == 0 or which > sets().size():
		return range(island_count())
	return sets()[which - 1]


## Where island `i` stands in an arrangement it is up in: (degrees round the middle,
## metres up, metres out) from its home.
func rest_pose(config: int, i: int) -> Vector3:
	if (config & 15) == 0:
		return Vector3.ZERO
	var variant := (config >> 7) & 7
	match kind_of(config):
		Kind.DRIFT:
			return Vector3(drift_turns[variant % drift_turns.size()] if not drift_turns.is_empty() else 0.0, 0.0, 0.0)
		Kind.CLOSE:
			return Vector3(0.0, 0.0, -close_in)
		Kind.FAR:
			return Vector3(0.0, far_heights[variant % far_heights.size()] if not far_heights.is_empty() else 0.0, far_out)
		Kind.SPLIT:
			var high := (up_in(config).find(i) + variant) % 2 == 0
			return Vector3(0.0, split_height if high else -split_height, 0.0)
	return Vector3.ZERO


## What an arrangement is called (for the log and the tests): "Drift: Labs, Library".
func describe(config: int) -> String:
	if (config & 15) == 0:
		return "all up"
	var names := up_in(config).map(func(i): return (_islands[i] as Node).name)
	return "%s: %s" % [KIND_NAMES[mini(kind_of(config), KIND_NAMES.size() - 1)], ", ".join(names)]


## Host: an arrangement to follow `config`: another set of islands, another kind, the
## other look.
func pick_after(config: int) -> int:
	var count := sets().size()
	var which := rng.randi_range(1, count)
	while which == (config & 15) and count > 1:
		which = rng.randi_range(1, count)
	var kind := rng.randi_range(0, Kind.size() - 1)
	while kind == kind_of(config):
		kind = rng.randi_range(0, Kind.size() - 1)
	return pack(which, kind, rng.randi_range(0, 7), 1 - look_of(config))


## Host: the arrangement a match begins in: a set at random, every island at its home.
func pick_first() -> int:
	return pack(rng.randi_range(1, sets().size()), Kind.SWAP, 0, 0)


# ---------------------------------------------------------------------------
# The clock

## Are the islands on the move right now?
func moving() -> bool:
	return running and elapsed >= hold_time + windup_time


## Has the bell gone, with the move still to come?
func warning() -> bool:
	return running and elapsed >= hold_time and elapsed < hold_time + windup_time


## Seconds until the bell (0 once it has gone, or when the clock is not running).
func time_to_bell() -> float:
	return maxf(hold_time - elapsed, 0.0) if running else 0.0


## Host: start the clock (a match has begun), in an arrangement picked at random.
## Never in a team mode.
func host_start(by: int = 0) -> void:
	if running or not is_host() or team_mode():
		return
	var first := pick_first()
	state = first | (pick_after(first) << BITS)
	print("[map] %s: %s, then %s" % [name, describe(now()), describe(next())])
	super(by)


## Should the clock be running? (The host asks.) Only while a match is being played.
func _wanted() -> bool:
	var rules := autoload("Match")
	return rules != null and rules.running and not team_mode()


func take_state(value: int) -> void:
	# The host says the turn is over before this copy's own clock got there: the clunk is due.
	if (value & MASK) != now() and running and elapsed > length() - 1.0:
		_turn_due = true
	super(value)


func apply_state(now_running: bool, at: float) -> void:
	var was := running
	super(now_running, at)
	if _turn_due:
		_turn_due = false
		_locked()
	_place()
	if running and not was:
		_rescue.call_deferred()


## A new match: every island home, the clock at nought (the host starts it again).
func _on_match_started() -> void:
	state = 0
	_tolled = -1.0
	if running:
		stop()
	_place()


## The match is over: the clock runs on while the scores are up. The next match puts it back.
func _on_match_over(_results: Array) -> void:
	pass


func _update(_delta: float) -> void:
	_place()


func _physics_process(delta: float) -> void:
	if not running:
		if is_host() and _wanted():
			host_start()
		return
	var before := elapsed
	elapsed += delta
	if elapsed >= length():
		# The move is done: the next turn begins. The host picks what comes after it; any
		# other copy hears in a moment.
		elapsed -= length()
		var arrived := next()
		state = arrived | ((pick_after(arrived) if is_host() else arrived) << BITS)
		before = -1.0
		_locked()
		if is_host():
			print("[map] %s: %s, then %s" % [name, describe(now()), describe(next())])
			_resync = 0.0   # (everyone is told at once)
	_cues(before, elapsed)
	_place()
	var net := autoload("Net")
	if net and net.is_host() and net.is_online:
		_resync -= delta
		if _resync <= 0.0:
			_resync = RESYNC
			net.send_map_event_state(index(), true, elapsed)


## The clock has just started on this copy: whoever this copy plays (its own player,
## and on the host the bots) and is standing on an island that is not up is put back
## at a spawn point. (A match begins with every island there; the clock takes most away.)
func _rescue() -> void:
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena) or _map == null:
		return
	var root: Node = arena.get("players_root")
	if root == null:
		return
	for p in root.get_children():
		if not p.get("is_local") or not p.get("alive"):
			continue
		var island := _map.island_at((p as Node3D).global_position)
		if island != null and not island.up:
			arena.call("_respawn", p)


# ---------------------------------------------------------------------------
# Where everything is

## Puts every island where the state and the clock say.
func _place() -> void:
	if not is_inside_tree():
		return
	if not _found:
		_find_parts()
	var now_moving := moving()
	var now_warning := warning()
	var a := now()
	var b := next()
	progress = clampf((elapsed - hold_time - windup_time) / maxf(move_time, 0.01), 0.0, 1.0) if now_moving else 0.0
	windup = clampf((elapsed - hold_time) / maxf(windup_time, 0.01), 0.0, 1.0) if now_warning else 0.0
	var up_a := up_in(a)
	var up_b := up_in(b)
	for i in _islands.size():
		var island := _islands[i] as MapIsland
		var here := up_a.has(i)
		var there := up_b.has(i)
		island.doomed = here and not there and (now_warning or now_moving)
		island.dip = doom_dip * windup * windup if island.doomed and now_warning else (doom_dip if island.doomed else 0.0)
		island.sputter(maxf(windup, 0.01) if island.doomed else 0.0, _doom_kinds(), doom_color, _time)
		if not now_moving:
			# At rest: up at its place, or parked below.
			var pose := rest_pose(a, i) if here else Vector3(0.0, -down, 0.0)
			island.pose_a = pose
			island.pose_b = pose
			island.blend = 0.0
			island.up = here
			island.set_parked(not here)
		elif here and there:
			# It stays: it glides to its new place, and is there before the others arrive.
			island.pose_a = rest_pose(a, i)
			island.pose_b = rest_pose(b, i)
			island.blend = smoothstep(0.0, 0.8, progress)
			island.up = true
			island.set_parked(false)
		elif here:
			# It goes: straight down, faster and faster.
			island.pose_a = rest_pose(a, i)
			island.pose_b = Vector3(island.pose_a.x, -down, island.pose_a.z)
			island.blend = progress * progress
			island.up = false
			island.set_parked(false)
		elif there:
			# It comes: straight up into its place, a little after the others have gone.
			island.pose_b = rest_pose(b, i)
			island.pose_a = Vector3(island.pose_b.x, -down, island.pose_b.z)
			island.blend = smoothstep(0.3, 1.0, progress)
			island.up = false
			island.set_parked(progress < 0.3)
		else:
			island.set_parked(true)
	if _map:
		_map.layout_state = a
		_map.warning = now_warning
		_map.shifting = now_moving
	var flare := 0.0
	if now_warning:
		flare = 0.6 * windup * windup
	elif now_moving:
		flare = lerpf(0.6, 1.0, sin(progress * PI)) if progress < 0.5 else sin(progress * PI)
	blend = lerpf(float(look_of(a)), float(look_of(b)), smoothstep(0.0, 1.0, progress)) if now_moving else float(look_of(a))
	_show(flare)


func _doom_kinds() -> PackedStringArray:
	if _all_doom_kinds.is_empty():
		_all_doom_kinds = flare_kinds.duplicate()
		_all_doom_kinds.append_array(doom_kinds)
	return _all_doom_kinds


func _find_parts() -> void:
	_map = MapRoot.of(self)
	if _map == null:
		return
	_found = true
	var all := _map.find_children("*", "", true, false)
	_islands = all.filter(func(n): return n is MapIsland)
	_hands = all.filter(func(n): return n is MapSpinner and (n as MapSpinner).driven == MapSpinner.Driven.COUNTDOWN)
	_bells = all.filter(func(n): return n is MapSpinner and (n as MapSpinner).driven == MapSpinner.Driven.SWING)


# ---------------------------------------------------------------------------
# What you hear and feel: the tick, the bell, the build-up, the clunk

## The sounds due between two moments of a turn (`before` is -1 just after a turn began).
func _cues(before: float, now: float) -> void:
	if now - before > 0.5 and before >= 0.0:
		return   # the clock was put right, not run: nothing is due
	if now < hold_time:
		var second := int(now)
		if before >= 0.0 and second > int(before):
			cue.emit("tick" if second % 2 == 1 else "tock")
			_tick(TICK_SOUND if second % 2 == 1 else TOCK_SOUND)
	if before < hold_time and now >= hold_time:
		_tolled = now - hold_time
		cue.emit("toll")
		_sound(TOLL_SOUND)
		_sound(RISE_SOUND, RISE_LENGTH / maxf(windup_time, 0.5))
	if before < hold_time + windup_time and now >= hold_time + windup_time:
		cue.emit("move")
		_sound(MOVE_SOUND)
		_log_aboard()


## For the sync log: how many players are still on islands that are now going down.
func _log_aboard() -> void:
	var dev := autoload("DevArgs")
	var net := autoload("Net")
	if dev == null or not dev.sync_log or net == null or net.arena == null or _map == null:
		return
	var aboard := 0
	var players := 0
	for p in net.arena.players_root.get_children():
		if p.get("alive"):
			players += 1
			aboard += int(_map.doomed_at((p as Node3D).global_position))
	print("ISLANDS_GO %d of %d players still aboard a doomed island" % [aboard, players])


## The move is over: everything has arrived.
func _locked() -> void:
	cue.emit("lock")
	_sound(LOCK_SOUND)
	_shake(0.5)


## Heard all over the map: not placed in the world.
func _sound(which: String, pitch: float = 1.0) -> void:
	var sound := autoload("Sound")
	if sound == null:
		return
	var player: AudioStreamPlayer = sound.play(which)
	if player and not is_equal_approx(pitch, 1.0):
		player.pitch_scale = pitch


## The clock: quiet everywhere, and once more from the tower for whoever is near it.
func _tick(which: String) -> void:
	var sound := autoload("Sound")
	if sound == null:
		return
	sound.play(which, TICK_QUIET)
	if _map:
		sound.play_at(which, _map.global_transform * tick_from, "body")


## Is this copy's own player standing on an island that is about to go down?
func _on_doomed() -> bool:
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena) or _map == null:
		return false
	var player: Node = arena.get("local_player")
	return player != null and is_instance_valid(player) and player.get("alive") and _map.doomed_at((player as Node3D).global_position)


func _shake(amount: float) -> void:
	var net := autoload("Net")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena):
		return
	var player: Node = arena.get("local_player")
	if player != null and is_instance_valid(player) and player.get("rig") != null:
		player.shake(amount)


func _process(delta: float) -> void:
	_time += delta
	if _tolled >= 0.0:
		_tolled += delta
	# A rumble that grows through the warning, and carries on while the islands go.
	var rumble := 0.0
	if warning():
		rumble = 0.04 + 0.26 * windup * windup
	elif moving():
		rumble = 0.3 * (1.0 - 0.5 * progress)
	if rumble > 0.0 and _on_doomed():
		rumble = 0.35 + 0.45 * windup if warning() else 0.8   # (the ground under you is going: you feel it, indoors too)
	if rumble > 0.0:
		_shake_wait -= delta
		if _shake_wait <= 0.0:
			_shake_wait = 0.07
			_shake(rumble)
	# The clock's hands: a step each second, at twelve when the bell goes.
	var turn := 0.0
	if running and elapsed < hold_time:
		turn = floorf(elapsed) / maxf(hold_time, 1.0)
	for hand in _hands:
		(hand as MapSpinner).angle = -TAU * turn
	var swing := 0.0
	if _tolled >= 0.0 and _tolled < SWING_FADE * 5.0:
		swing = SWING * sin(TAU * SWING_RATE * _tolled) * exp(-_tolled / SWING_FADE)
	for bell in _bells:
		(bell as MapSpinner).angle = swing


# ---------------------------------------------------------------------------
# The look: afternoon to sunset, lamps on, engines flaring, clouds and scraps

func _show(flare: float) -> void:
	if is_equal_approx(blend, _shown) and is_equal_approx(flare, _shown_flare):
		return
	_shown = blend
	_shown_flare = flare
	if not _looks:
		_find_looks()
	var k := blend
	if _env:
		_env.ambient_light_color = (_env_base.color as Color).lerp(ambient_color, k)
		_env.ambient_light_energy = lerpf(_env_base.energy, ambient_energy, k)
		_env.glow_intensity = lerpf(_env_base.glow, _env_base.glow * 1.3, maxf(k, flare))
		_env.fog_light_color = (_env_base.fog as Color).lerp(fog_color, k)
	if _sky:
		_sky.set_shader_parameter("sunset", k)
		_sky.set_shader_parameter("swirl", flare)
		_sky.set_shader_parameter("sun_dir", (_sun_base.dir as Vector3).slerp(sun_direction.normalized(), k) if _sun else sun_direction.normalized())
	if _sun:
		var dir: Vector3 = (_sun_base.dir as Vector3).slerp(sun_direction.normalized(), k)
		_sun.basis = _facing(dir)
		_sun.light_color = (_sun_base.color as Color).lerp(sun_color, k)
		_sun.light_energy = lerpf(_sun_base.energy, sun_energy, k)
	for m in _lit:
		var mat: StandardMaterial3D = m[0]
		mat.emission_energy_multiplier = lerpf(m[1], lit_glow, k)
	for m in _flare:
		var mat: StandardMaterial3D = m[0]
		mat.emission_energy_multiplier = m[1] * (1.0 + flare_gain * flare)
	if flare > 0.0 and _scraps == null and scraps > 0 and _map and _map.has_meshes and DisplayServer.get_name() != "headless":
		_build_scraps()
	if _scraps:
		_scraps.visible = flare > 0.002
		_scrap_mat.set_shader_parameter("fade", flare)


## A light's basis shining from `to_sun` (it shines along its own -z).
static func _facing(to_sun: Vector3) -> Basis:
	var z := to_sun.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


func _find_looks() -> void:
	_looks = true
	if _map == null or not _map.has_meshes or DisplayServer.get_name() == "headless":
		return
	var found := _map.find_children("*", "WorldEnvironment", true, false)
	if not found.is_empty() and (found[0] as WorldEnvironment).environment:
		var world := found[0] as WorldEnvironment
		# Our own copy, so the scene's shared Environment is never left changed.
		_env = world.environment.duplicate()
		world.environment = _env
		_env_base = {"color": _env.ambient_light_color, "energy": _env.ambient_light_energy, "glow": _env.glow_intensity, "fog": _env.fog_light_color}
		if _env.sky and _env.sky.sky_material is ShaderMaterial:
			_env.sky = _env.sky.duplicate()
			_sky = _env.sky.sky_material.duplicate()
			_env.sky.sky_material = _sky
	_sun = _map.get_node_or_null("Sun") as DirectionalLight3D
	if _sun:
		_sun_base = {"color": _sun.light_color, "energy": _sun.light_energy, "dir": _sun.basis.z.normalized()}
	for kind in lit_kinds:
		var mat := _map.material_for(kind) as StandardMaterial3D
		if mat:
			if not mat.emission_enabled:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 0.0
			_lit.append([mat, mat.emission_energy_multiplier])
	for kind in flare_kinds:
		var mat := _map.material_for(kind) as StandardMaterial3D
		if mat and mat.emission_enabled:
			_flare.append([mat, mat.emission_energy_multiplier])


const SCRAP_SHADER := "
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float fade = 0.0;
varying vec3 tint;
varying float show;
void vertex() {
	// INSTANCE_CUSTOM: two random numbers (x, y), a size (z) and a speed (w). Each scrap
	// circles the middle of the map on the wind, bobbing and tumbling as it goes.
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * INSTANCE_CUSTOM.w;
	float turn = t * 0.55 + INSTANCE_CUSTOM.x * 6.283;
	float c = cos(turn * 0.35);
	float s = sin(turn * 0.35);
	centre = vec3(centre.x * c - centre.z * s, centre.y + sin(t * 1.3 + INSTANCE_CUSTOM.y * 40.0) * 1.6, centre.x * s + centre.z * c);
	float spin = t * 5.0 + INSTANCE_CUSTOM.y * 20.0;
	vec3 right = normalize(vec3(cos(spin), sin(spin * 0.7) * 0.6, sin(spin)));
	vec3 up = normalize(cross(right, vec3(sin(spin * 0.5), 1.0, cos(spin * 0.5))));
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * INSTANCE_CUSTOM.z;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	// Paper (cream), or a leaf (green to gold).
	tint = INSTANCE_CUSTOM.x < 0.55 ? vec3(0.97, 0.94, 0.86) : mix(vec3(0.42, 0.62, 0.2), vec3(0.9, 0.62, 0.16), INSTANCE_CUSTOM.y);
	show = step(1.0 - fade, 0.25 + 0.75 * fract(INSTANCE_CUSTOM.x * 7.31 + INSTANCE_CUSTOM.y * 3.17));
}
void fragment() {
	if (show < 0.5) {
		discard;
	}
	ALBEDO = tint;
}
"


func _build_scraps() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.7)
	var shader := Shader.new()
	shader.code = SCRAP_SHADER
	_scrap_mat = ShaderMaterial.new()
	_scrap_mat.shader = shader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = scraps
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var box := scrap_volume
	for i in scraps:
		var at := box.position + Vector3(rng.randf() * box.size.x, rng.randf() * box.size.y, rng.randf() * box.size.z)
		mm.set_instance_transform(i, Transform3D(Basis(), at))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf_range(0.22, 0.42), rng.randf_range(0.7, 1.5)))
	_scraps = MultiMeshInstance3D.new()
	_scraps.name = "Scraps"
	_scraps.multimesh = mm
	_scraps.material_override = _scrap_mat
	_scraps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scraps.extra_cull_margin = 16384.0   # they are drawn all over the map from one node
	_map.add_child(_scraps)
