class_name TargetDummy
extends StaticBody3D
## A robot that stands still to be shot at (placed in a map with a MapDummy).
##
## It has a player's hitbox and 100 health, and the host checks shots against it
## exactly as against a player (Match._host_shot), so you get the same hit markers,
## damage numbers and headshots. Over its head a readout shows the last hit and the
## damage so far: hits, headshots, total, and how long the kill took. Brought to 0
## it falls over, then gets back up with full health. Left alone for RESET_TIME it
## heals, and the next hit starts a new count.

const DOWN_TIME := 2.0     ## seconds it stays down after a kill
const RESET_TIME := 3.0    ## seconds without a hit before it heals to full
const COLOR := Color(1.0, 0.55, 0.2)   ## the orange trim of a training robot
const LAST_TIME := 1.2     ## how long the big number for the last hit stays
const NEAR := 16.0         ## metres: closer than this the readout always shows...
const SHOWN_AFTER_HIT := 8.0   ## ...further away, only for this long after a hit (so far ones do not crowd the view)

var index := 0
var caption := ""
var yaw := 0.0             ## the way it faces (like a player's yaw)
var health := Match.MAX_HEALTH
var robot: RobotModel
var animator: RobotAnimator

var _visual: Node3D
var _anim := RobotAnimInput.new()
var _down_left := 0.0
var _since_hit := 99.0
var _hits := 0
var _heads := 0
var _damage := 0.0
var _start := 0.0          # Net.now() of the first hit of this count
var _kill_time := -1.0     # seconds the kill took (-1: not down yet)
var _last_age := 99.0
var _last: Label3D         # the big number for the last hit
var _info: Label3D         # health and the count so far


func setup(i: int, pos: Vector3, facing: float, character: String, gun: String, text: String = "") -> TargetDummy:
	index = i
	caption = text
	name = "Dummy_%d" % i
	yaw = facing
	position = pos
	collision_layer = 1 << 1   # layer 2, like players: you bump into it and shots show a hit
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.CAPSULE_RADIUS
	capsule.height = Player.CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position.y = Player.CAPSULE_HEIGHT * 0.5
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.basis = Basis(Vector3.UP, yaw)
	add_child(_visual)
	robot = RobotModel.new().build(character, COLOR, false, gun)
	_visual.add_child(robot)
	animator = RobotAnimator.new(robot)
	_anim.state = MovementController.State.GROUND
	_anim.yaw = yaw

	_info = _label(26)
	_last = _label(40)   # sits on top of the readout (see _refresh)
	_last.visible = false
	_refresh()
	return self


func _label(size: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0015
	l.font_size = size
	l.outline_size = 8
	l.font = HudStyle.font(true)
	l.position.y = Player.CAPSULE_HEIGHT + 0.35
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # grows upward from just over the head
	add_child(l)
	return l


func is_down() -> bool:
	return health <= 0.0


## The host decided a shot hit us (told to every player, so all show the same).
## `distance` is how far the shooter was, in metres (-1 if unknown).
func show_hit(amount: float, headshot: bool, new_health: float, distance: float) -> void:
	if _since_hit >= RESET_TIME or _kill_time >= 0.0 or _hits == 0:
		_hits = 0
		_heads = 0
		_damage = 0.0
		_start = Net.now()
		_kill_time = -1.0
	_hits += 1
	_heads += 1 if headshot else 0
	_damage += amount
	_since_hit = 0.0
	health = new_health
	_last.text = ("HEAD %d" if headshot else "%d") % roundi(amount)
	if distance >= 0.0:
		_last.text += "  ·  %.1f m" % distance
	_last.modulate = HudStyle.YELLOW if headshot else Color.WHITE
	_last.visible = true
	_last_age = 0.0
	if health <= 0.0:
		_kill_time = Net.now() - _start
		_down_left = DOWN_TIME
	_refresh()


func _process(delta: float) -> void:
	_since_hit += delta
	if _down_left > 0.0:
		_down_left -= delta
		if _down_left <= 0.0:
			health = Match.MAX_HEALTH
			animator.respawn()
			_refresh()
	elif _since_hit >= RESET_TIME and health < Match.MAX_HEALTH:
		health = Match.MAX_HEALTH
		_refresh()
	_last_age += delta
	if _last.visible:
		var a := clampf((LAST_TIME - _last_age) / 0.3, 0.0, 1.0)
		_last.modulate.a = a
		_last.outline_modulate.a = a
		_last.visible = a > 0.0
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(global_position) < NEAR
	_info.visible = near or _since_hit < SHOWN_AFTER_HIT or is_down()
	_anim.alive = not is_down()
	animator.update(delta, _anim, _visual.global_transform)


func _refresh() -> void:
	var lines: Array[String] = []
	lines.append(caption if caption != "" else "TARGET DUMMY")
	lines.append("DOWN" if is_down() else "%d / %d" % [roundi(health), roundi(Match.MAX_HEALTH)])
	if _hits > 0:
		var count := "%d hit%s" % [_hits, "" if _hits == 1 else "s"]
		if _heads > 0:
			count += " (%d head)" % _heads
		count += "  ·  %d damage" % roundi(_damage)
		lines.append(count)
		if _kill_time >= 0.0:
			lines.append("Killed in %.2f s" % _kill_time)
	_info.text = "\n".join(lines)
	# Both labels keep their size on screen, so the gap between them is in pixels, not metres.
	_last.offset.y = lines.size() * _info.font_size * 1.25 + 6.0
	_info.modulate = Color(1.0, 0.45, 0.4) if is_down() else Color(0.93, 0.94, 0.96)
