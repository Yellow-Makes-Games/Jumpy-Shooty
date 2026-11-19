extends SceneTree
## Headless checks for grapple aim magnets. Run:
##   godot --headless --path . --script tests/grapple_point_test.gd
## A grapple point hanging in open air is caught when aimed near it, not when aimed
## well off it, out of reach, or behind a wall; another player is caught a little
## off aim (player_magnet), but not as far off as a grapple point.

var failures := 0
var _frame := 0


func _initialize() -> void:
	physics_frame.connect(_tick)


func _body(at: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	b.add_child(cs)
	b.position = at
	return b


func _check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


## Aim from me's eyes toward `at`, turned `off_deg` sideways.
func _aim(me: Node3D, input: PlayerInput, at: Vector3, off_deg: float) -> void:
	var eye := me.global_position + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
	var d := (at - eye).normalized()
	input.aim_dir = Vector3.ZERO
	input.yaw = atan2(-d.x, -d.z) + deg_to_rad(off_deg)
	input.pitch = asin(clampf(d.y, -1.0, 1.0))


var players: Node3D
var me: CharacterBody3D
var foe: CharacterBody3D
var point: MapGrapplePoint
var wall: StaticBody3D


func _setup() -> void:
	players = Node3D.new()
	root.add_child(players)
	me = _body(Vector3.ZERO)
	players.add_child(me)
	point = MapGrapplePoint.new()
	point.position = Vector3(0, 12, -20)   # open air: nothing solid to hit
	root.add_child(point)
	wall = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 7, -10)
	foe = _body(Vector3(30, 0, 0))
	foe.set_script(load("res://tests/grapple_point_test_foe.gd"))
	players.add_child(foe)


func _tick() -> void:
	_frame += 1
	if _frame == 1:
		_setup()
		return
	if _frame != 3:
		return
	var tuning := MovementTuning.new()
	var g := Grapple.new(tuning)
	var input := PlayerInput.new()

	_aim(me, input, point.global_position, 5.0)
	var hit := g.find_target(me, input)
	_check("snaps to a grapple point 5 degrees off aim", hit.get("collider") == point)
	_fly(g, input)
	_check("the hook flies to the point and bites there", (g.biting or g.attached) and g.anchor.is_equal_approx(point.global_position) and g.target == null)
	g.reset()

	_aim(me, input, point.global_position, 15.0)
	_check("no snap 15 degrees off aim", g.find_target(me, input).get("collider") != point)

	point.reach = 10.0
	_aim(me, input, point.global_position, 2.0)
	_check("no snap out of reach", g.find_target(me, input).get("collider") != point)
	point.reach = 55.0

	root.add_child(wall)
	await physics_frame
	await physics_frame
	_aim(me, input, point.global_position, 2.0)
	_check("no snap through a wall", g.find_target(me, input).get("collider") != point)
	wall.queue_free()
	point.queue_free()
	await physics_frame
	await physics_frame

	var chest := Grapple.target_point(foe)
	_aim(me, input, chest, 2.0)
	hit = g.find_target(me, input)
	_check("snaps to a player 2 degrees off aim", hit.get("collider") == foe)
	_fly(g, input)
	_check("the hook flies to the player and catches them", (g.biting or g.attached) and g.target == foe)
	g.reset()

	_aim(me, input, chest, 6.0)
	_check("no player snap 6 degrees off aim", g.find_target(me, input).get("collider") != foe)

	g.hook_players = false
	_aim(me, input, chest, 2.0)
	_check("no player snap when players can't be hooked (races)", g.find_target(me, input).get("collider") != foe)

	print("ALL PASS" if failures == 0 else "%d FAILED" % failures)
	quit(failures)


## Fires the hook and lets it fly (the body standing still) until it bites, or for 2 s.
func _fly(g: Grapple, input: PlayerInput) -> void:
	g.fire(me, input)
	for i in 120:
		if not g.flying:
			return
		g.update(1.0 / 60.0)
		g.follow_target(me, 1.0 / 60.0)
