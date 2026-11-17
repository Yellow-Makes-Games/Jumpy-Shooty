extends SceneTree
## MapTerminal checks: the rules the host keeps for a terminal, stepped by hand with
## made-up players (no map, no arena).
##  - one press of interact within range fires the terminal's event (the default);
##  - a press from out of range does nothing, nor does one made while the event runs
##    or cools down, and a key kept down does not fire it again: it takes a new press;
## and for a terminal that asks for a hold (Channel Time above 0):
##  - holding interact within range for 2 s fires the terminal's event;
##  - letting go early cancels, and the next hold starts from nothing;
##  - leaving the range cancels (walking off, or knocked out of it), and so does dying;
##  - taking damage does not cancel;
##  - it cannot be used while its event runs, nor in the cooldown after;
##  - only one player holds it at a time: it stays the first holder's until they are done;
##  - a hold from out of range starts nothing; a player's hold reaches the host through Net.
## Run: godot --headless --path . --script tests/terminal_test.gd

const STEP := 1.0 / 60.0

var failures := 0
var event: GravityEvent
var terminal: MapTerminal
var where := {}   # peer id -> Vector3 (feet), or missing when dead


func _initialize() -> void:
	print("Terminal checks")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	event = GravityEvent.new()
	event.name = "LowGravity"
	root.add_child(event)
	terminal = MapTerminal.new()
	terminal.event = NodePath("../LowGravity")
	terminal.position = Vector3(0, 1.2, 0)
	root.add_child(terminal)
	# Stepped by hand here, so the checks do not depend on how fast the test runs.
	event.set_physics_process(false)
	terminal.set_physics_process(false)
	var near := Vector3(1.2, 1.2, 0)   # standing on the dais beside the console
	var far := Vector3(3.5, 1.2, 0)

	print("  defaults")
	_expect(is_zero_approx(terminal.channel_time) and is_equal_approx(terminal.range, 2.0), "one press, within 2 m")
	_expect(terminal.reaches(near) and not terminal.reaches(far), "beside the console is in range, 3.5 m away is not")
	_expect(terminal.ready_to_use(), "it starts ready")

	print("  one press in range fires the event")
	where = {1: far}
	terminal.host_set_holding(1, true)
	_step(0.5)
	_expect(terminal.phase == MapTerminal.Phase.READY and not event.running, "a press from 3.5 m away does nothing")
	terminal.host_set_holding(1, false)
	where = {1: near}
	terminal.host_set_holding(1, true)
	_step(STEP)
	_expect(event.running, "a press beside the console starts the event at once")
	_expect(terminal.phase == MapTerminal.Phase.BUSY and not terminal.ready_to_use(), "and the terminal is locked")
	_expect(terminal.channeler == 0 and is_zero_approx(terminal.progress), "nobody is left holding it")
	_step(0.5)
	terminal.host_set_holding(1, false)   # the key comes up half a second later, as a tap does
	where = {1: near, 2: Vector3(-1.2, 1.2, 0)}
	terminal.host_set_holding(2, true)    # someone else presses while gravity is low...
	_advance_event(10.0)
	_expect(event.active() and terminal.phase == MapTerminal.Phase.BUSY, "10 s in (gravity low): a press does nothing")
	_advance_event(event.ease_time * 2.0 + event.duration + 20.0)
	_expect(event.running and not event.active() and terminal.phase == MapTerminal.Phase.BUSY, "20 s into the cooldown: still locked")
	_finish_event()                       # ...and keeps the key down until it is ready again
	_step(0.5)
	_expect(terminal.phase == MapTerminal.Phase.READY and not event.running, "ready again; the key kept down since then does not fire it")
	terminal.host_set_holding(2, false)
	terminal.host_set_holding(2, true)
	_step(STEP)
	_expect(event.running, "a new press does")
	terminal.host_set_holding(2, false)
	_finish_event()
	var net0 := root.get_node_or_null("/root/Net")
	if net0:
		where = {7: near}
		net0.terminal_hold(terminal.index(), true, 7)   # what a player's copy of the game sends
		_step(STEP)
		_expect(event.running, "a player's press reaches the host through Net")
		net0.terminal_hold(terminal.index(), false, 7)
		_finish_event()

	print("  a terminal that asks for a hold: 2 s in range fires the event")
	terminal.channel_time = 2.0
	where = {1: near}
	terminal.host_set_holding(1, true)
	_step(1.9)
	_expect(terminal.phase == MapTerminal.Phase.CHANNEL and terminal.channeler == 1, "after 1.9 s it is still being held (by player 1)")
	_expect(terminal.progress > 0.9 and terminal.progress < 1.0, "the ring is nearly full (%.2f)" % terminal.progress)
	_expect(not event.running, "the event has not started yet")
	_step(0.2)
	_expect(event.running, "after 2 s the event starts")
	_expect(terminal.phase == MapTerminal.Phase.BUSY and not terminal.ready_to_use(), "and the terminal is locked")
	terminal.host_set_holding(1, false)
	_finish_event()

	print("  letting go early cancels")
	terminal.host_set_holding(1, true)
	_step(1.5)
	terminal.host_set_holding(1, false)
	_step(0.1)
	_expect(terminal.phase == MapTerminal.Phase.READY and is_zero_approx(terminal.progress), "let go at 1.5 s: back to ready, nothing kept")
	_step(1.0)
	_expect(not event.running, "the event did not start")
	terminal.host_set_holding(1, true)
	_step(1.0)
	_expect(not event.running and terminal.progress < 0.6, "holding again starts from nothing (%.2f after 1 s)" % terminal.progress)
	terminal.host_set_holding(1, false)
	_step(0.1)

	print("  leaving the range cancels")
	terminal.host_set_holding(1, true)
	_step(1.5)
	where[1] = far   # walked off, or kicked off the dais: the key is still down
	_step(0.1)
	_expect(terminal.phase == MapTerminal.Phase.READY and is_zero_approx(terminal.progress), "moved 3.5 m away at 1.5 s: cancelled")
	_step(1.0)
	_expect(not event.running, "the event did not start")
	where[1] = near
	_step(1.0)
	_expect(terminal.phase == MapTerminal.Phase.CHANNEL and terminal.progress < 0.6, "back in range, still holding: a fresh hold")
	where.erase(1)   # dead
	_step(0.1)
	_expect(terminal.phase == MapTerminal.Phase.READY, "dying cancels too")
	where[1] = near
	terminal.host_set_holding(1, false)
	_step(0.1)

	print("  taking damage does not cancel")
	var rules := root.get_node_or_null("/root/Match")
	terminal.host_set_holding(1, true)
	_step(0.8)
	if rules:
		rules.health[1] = 35.0
		rules.player_hit.emit(2, 1, 65.0, false)
	_step(0.6)
	_expect(terminal.phase == MapTerminal.Phase.CHANNEL and terminal.channeler == 1 and terminal.progress > 0.6,
		"shot at 0.8 s: still holding at 1.4 s (%.2f)" % terminal.progress)
	if rules:
		rules.player_hit.emit(2, 1, 20.0, true)
	_step(0.7)
	_expect(event.running, "and the event starts on time")
	terminal.host_set_holding(1, false)
	if rules:
		rules.health.erase(1)

	print("  it cannot be used during the event or the cooldown")
	terminal.host_set_holding(1, true)
	_advance_event(10.0)
	_expect(event.active() and terminal.phase == MapTerminal.Phase.BUSY and not terminal.ready_to_use(), "10 s in (gravity low): locked")
	_step(2.5)
	_expect(terminal.phase == MapTerminal.Phase.BUSY and is_zero_approx(terminal.progress), "holding it for 2.5 s does nothing")
	_advance_event(event.ease_time * 2.0 + event.duration + 20.0)
	_expect(event.running and not event.active() and terminal.phase == MapTerminal.Phase.BUSY and not terminal.ready_to_use(),
		"20 s into the cooldown (gravity back to normal): still locked")
	_step(2.5)
	_expect(terminal.phase == MapTerminal.Phase.BUSY, "holding it does nothing")
	terminal.host_set_holding(1, false)
	_finish_event()
	_expect(terminal.phase == MapTerminal.Phase.READY and terminal.ready_to_use(), "after the cooldown it is ready again")

	print("  one player at a time")
	where = {1: near, 2: Vector3(-1.2, 1.2, 0)}
	terminal.host_set_holding(2, true)
	_step(0.5)
	terminal.host_set_holding(1, true)
	_step(1.0)
	_expect(terminal.channeler == 2 and terminal.progress > 0.7, "player 2 started first: it stays theirs when player 1 holds too (%.2f)" % terminal.progress)
	terminal.host_set_holding(2, false)
	_step(STEP)
	_step(STEP)
	_expect(terminal.phase == MapTerminal.Phase.CHANNEL and terminal.channeler == 1 and terminal.progress < 0.1,
		"player 2 lets go: player 1's hold starts, from nothing")
	_step(1.0)
	terminal.host_set_holding(2, true)
	_step(1.2)
	_expect(event.running, "player 1 finishes it")
	terminal.host_set_holding(1, false)
	terminal.host_set_holding(2, false)
	_finish_event()

	print("  out of range, and through Net")
	where = {7: far}
	terminal.host_set_holding(7, true)
	_step(2.5)
	_expect(terminal.phase == MapTerminal.Phase.READY and not event.running, "a hold from 3.5 m away starts nothing")
	terminal.host_set_holding(7, false)
	var net := root.get_node_or_null("/root/Net")
	if net:
		where = {7: near}
		net.terminal_hold(terminal.index(), true, 7)   # what a player's copy of the game sends
		_step(0.5)
		_expect(terminal.phase == MapTerminal.Phase.CHANNEL and terminal.channeler == 7, "a player's hold reaches the host through Net")
		net.terminal_hold(terminal.index(), false, 7)
		_step(0.1)
		_expect(terminal.phase == MapTerminal.Phase.READY, "and so does letting go")

	terminal.free()
	event.free()
	print("FAIL: %d checks failed" % failures if failures else "PASS: every check passed")
	quit(1 if failures else 0)


## Runs the host's rules (and the event's clock) for `seconds`.
func _step(seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(STEP, left)
		left -= dt
		terminal.host_step(dt, func(id: int) -> Variant: return where.get(id))
		event._physics_process(dt)


## Moves the running event's clock to `at` seconds after it started.
func _advance_event(at: float) -> void:
	event.elapsed = at
	_step(STEP)


func _finish_event() -> void:
	if event.running:
		_advance_event(event.length() + 0.1)
	_step(STEP)
	_step(STEP)


func _expect(ok: bool, what: String) -> void:
	print("    %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
