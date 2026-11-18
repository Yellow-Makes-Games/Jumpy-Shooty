class_name KillcamView
extends Node3D
## Plays a KillClip: the killer's view (their camera, their first-person arms and gun,
## their shots) with everyone else as stand-in bodies moving the way the clip says.
## Added to a world that already has the map in it: the arena (the death killcam) or
## the results screen's own little world (see KillcamScreen).
##
## Plays once and holds the last frame (`finished`), or, with `loop`, starts over.
##
## A blow (a kick, a crash into a wall, a blade; see KillScore.is_blow) plays in third
## person instead: the killer is a body like everyone else and the camera follows close
## behind them, turned towards the victim, so you see the swing or the kick land.
##
## A body knocked out falls the way it fell in the match: when the clip has its remains
## (KillClip.Wreck), the body gives way to the replay's own ragdoll or giblets, posed
## from that recording on the replay's clock (so slow motion slows the fall too, and a
## video saved frame by frame has it frame by frame). They are this replay's, freed
## with it or when it starts over. With gore off (Settings.gore), or with no recording,
## the body stays and plays its death instead.

signal finished
signal kill_moment   ## the killing blow lands

const SLOW := 0.3            ## results screen: the kill plays at this speed...
const SLOW_FROM := 0.25      ## ...from this long before it...
const SLOW_UNTIL := 0.45     ## ...to this long after
const S := MovementController.State
## Third person: the camera sits this far behind the killer's head...
const CHASE_BACK := 3.4
const CHASE_UP := 0.9          ## ...this far above it...
const CHASE_SIDE := 0.7        ## ...this far to the right...
const CHASE_EASE := 18.0       ## ...and keeps up at this rate (1/s: tight, so a fast killer stays close)
const LOOK_EASE := 6.0         ## where it looks turns at this rate (smoother)
const CHASE_VICTIM := 18.0     ## turns towards the victim when they are this close (m)

var clip: KillClip
var slow_motion := false
var loop := false
## Stepped by hand (step()), rockets and all, instead of with the game's frames: for
## saving a video at a steady frame rate however fast the computer draws.
var manual := false
var time := 0.0              ## where we are, on the killer's clock (see KillClip)
var done := false
var camera: Camera3D
## Sounds: the killer's gun as your own (2D); others in the world (3D) when `world_sound`.
var world_sound := true
## Watched from behind the killer (a blow), not through their eyes.
var third_person := false

var _puppet: Player          # stands in for the killer, for their first-person arms
var _view: ViewModel
var _weapon := ""
var _ghosts: Dictionary = {} # id -> Ghost
var _fx: Node3D              # tracers, rockets, explosions
var _events: Array = []      # [time the killer saw it, event], in order
var _next := 0
var _killed := false
var _rope: MeshInstance3D
var _hook: MeshInstance3D
var _seen := {}              # killer: swing/kick counters last seen (see _watch)
var _akimbo_shots := 0
var _was_reloading := false
var _chase_ready := false    # third person: the camera has been placed once (then it eases)
var _chase_look := Vector3.ZERO
var _wrecks: Dictionary = {}  # KillClip.Wreck -> the replay's own Ragdoll or Gibs for it (null: none could be made)


## One other player: a body that moves and animates the way the clip says.
class Ghost:
	var root := Node3D.new()
	var visual := Node3D.new()
	var robot: RobotModel
	var animator: RobotAnimator
	var anim := RobotAnimInput.new()
	var weapon := "?"
	var rope: MeshInstance3D
	var hook: MeshInstance3D
	var seen := {}
	var akimbo_shots := 0


func setup(watch: KillClip, slow: bool = false) -> KillcamView:
	clip = watch
	slow_motion = slow
	name = "Killcam"
	third_person = KillScore.is_blow(int(clip.info.get("tags", 0)))
	time = clip.start
	for e in clip.events:
		_events.append([clip.event_time(e), e])
	_events.sort_custom(func(a, b): return a[0] < b[0])
	return self


func _ready() -> void:
	_fx = Node3D.new()
	_fx.name = "KillcamFx"
	add_child(_fx)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 800.0
	camera.fov = Settings.field_of_view
	camera.set_cull_mask_value(CameraRig.BODY_LAYER, false)
	camera.set_cull_mask_value(CameraRig.VIEW_BODY_LAYER, false)
	add_child(camera)
	camera.make_current()
	var rope := _make_rope()
	_rope = rope[0]
	_hook = rope[1]
	_frame(0.0)


func _exit_tree() -> void:
	if _puppet:
		_puppet.free()   # never in the tree: freed by hand
		_puppet = null


## 0..1 through the clip.
func progress() -> float:
	return clampf((time - clip.start) / maxf(clip.end - clip.start, 0.01), 0.0, 1.0)


## Seconds of the clip left to play, at normal speed.
func time_left() -> float:
	return maxf(clip.end - time, 0.0)


func restart() -> void:
	time = clip.start
	done = false
	_killed = false
	_next = 0
	for child in _fx.get_children():
		child.queue_free()
	_wrecks.clear()   # (they were in _fx)
	for g in _ghosts.values():
		(g as Ghost).seen.clear()
		(g as Ghost).animator.respawn()
	_seen.clear()
	_chase_ready = false
	_frame(0.0)


func _process(delta: float) -> void:
	if not manual:
		step(delta)


## Moves the clip on by `delta` seconds (slower round the kill in slow motion).
func step(delta: float) -> void:
	if done:
		return
	if manual:
		for rocket in _fx.get_children():
			if rocket is Projectile:
				(rocket as Projectile)._physics_process(delta)
	var rate := 1.0
	if slow_motion and time >= clip.kill_time - SLOW_FROM and time <= clip.kill_time + SLOW_UNTIL:
		rate = SLOW
	time = minf(time + delta * rate, clip.end)
	_frame(delta)
	if time >= clip.end:
		if loop:
			restart()
		else:
			done = true
			finished.emit()


func _frame(delta: float) -> void:
	if third_person:
		_play_ghost(clip.killer, delta)
	else:
		_play_killer(delta)
	for id in clip.tracks:
		if id != clip.killer:
			_play_ghost(id, delta)
	_play_wrecks()
	if third_person:
		_chase(delta)
	while _next < _events.size() and _events[_next][0] <= time:
		_play_event(_events[_next][1])
		_next += 1
	if not _killed and time >= clip.kill_time:
		_killed = true
		kill_moment.emit()


# ---------------------------------------------------------------------------
# The killer: their eyes and arms

func _play_killer(delta: float) -> void:
	var track: KillClip.Track = clip.tracks.get(clip.killer)
	if track == null or track.is_empty():
		return
	var f := track.sample(time)
	var weapon := str(f[11])
	if weapon != _weapon:
		_build_arms(weapon, track.color)
	var feet: Vector3 = f[0]
	var yaw := float(f[2])
	var pitch := float(f[3])
	var pose := int(f[4])
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, _roll(f))), feet + Vector3(0, float(f[10]), 0))
	# The arms follow what the killer was doing (see ViewModel).
	var p := _puppet
	p.alive = bool(f[8])
	p.velocity = f[1]
	p.input.yaw = yaw
	p.input.pitch = pitch
	p.input.sprint = Vector2(p.velocity.x, p.velocity.z).length() > 9.0
	p.motor.state = Player.pose_state(pose)
	p.motor.crouched = Player.pose_crouched(pose)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	p.motor.wall_normal = -right if int(f[5]) & 1 else right
	p.motor.grapple.attached = bool(f[6])
	p.motor.grapple.anchor = f[7]
	var reloading := int(f[5]) & 4 != 0
	if p.weapon:
		if reloading and not _was_reloading:
			p.weapon.ammo = 0
			p.weapon.start_reload()
		elif not reloading and p.weapon.is_reloading():
			p.weapon.reset()
		p.weapon.update(delta)
	_was_reloading = reloading
	_watch(int(f[5]), weapon, _seen, null)
	if _view:
		_view.update(delta)
	_draw_rope(_rope, _hook, bool(f[6]) and p.alive, _view.marker("grapple") if _view else camera.global_position, f[7])


## Leaning away from a wall while running along it, as the killer's camera did.
func _roll(f: Array) -> float:
	if Player.pose_state(int(f[4])) != S.WALL_RUN:
		return 0.0
	return deg_to_rad(7.0) * (1.0 if int(f[5]) & 1 else -1.0)


func _build_arms(weapon: String, color: Color) -> void:
	_weapon = weapon
	if _view:
		_view.queue_free()
		_view = null
	if _puppet == null:
		_puppet = Player.new()
		_puppet.peer_id = clip.killer
		_puppet.motor = MovementController.new()
	_puppet.weapon = WeaponState.new(WeaponData.by_id(weapon)) if WeaponData.has(weapon) else null
	_view = ViewModel.new()
	camera.add_child(_view)
	_view.setup(_puppet, color)
	_view.respawn()
	_akimbo_shots = 0


## Third person: the camera behind and above the killer, looking where they look, or
## (when the victim is close by and in the clip) between the killer and the victim.
## It stays on the killer's side of walls.
func _chase(delta: float) -> void:
	var track: KillClip.Track = clip.tracks.get(clip.killer)
	var g: Ghost = _ghosts.get(clip.killer)
	if track == null or track.is_empty() or g == null:
		return
	var f := track.sample(time)
	var yaw := float(f[2])
	var head: Vector3 = f[0] + Vector3(0, 1.6, 0)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var look := head + forward * 6.0
	var victim: Ghost = _ghosts.get(clip.victim)
	var chest := Vector3.INF
	if victim and victim.root.visible:
		chest = victim.root.global_position + Vector3(0, 1.1, 0)
	else:   # fallen: where their remains are
		for w: KillClip.Wreck in _wrecks:
			if w.who == clip.victim and _wrecks[w] != null:
				chest = _wrecks[w].focus()
	if chest != Vector3.INF and chest.distance_to(head) < CHASE_VICTIM:
		look = head.lerp(chest, 0.6)
	var want := head - forward * CHASE_BACK + Vector3.UP * CHASE_UP + right * CHASE_SIDE
	if is_inside_tree():   # stay on this side of a wall
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(head, want))
		if not hit.is_empty():
			want = hit.position + (head - hit.position).normalized() * 0.35
	var k := 1.0 - exp(-CHASE_EASE * delta)
	var kl := 1.0 - exp(-LOOK_EASE * delta)
	if not _chase_ready:
		camera.global_position = want
		_chase_look = look
		_chase_ready = true
	else:
		camera.global_position = camera.global_position.lerp(want, k)
		_chase_look = _chase_look.lerp(look, kl)
	if camera.global_position.distance_to(_chase_look) > 0.05:
		camera.look_at(_chase_look, Vector3.UP)


# ---------------------------------------------------------------------------
# Everyone else

func _play_ghost(id: int, delta: float) -> void:
	var track: KillClip.Track = clip.tracks[id]
	var t := clip.time_for(id, time)
	if track.is_empty() or t < track.first_time() - 0.5:
		return
	var f := track.sample(t)
	var g: Ghost = _ghosts.get(id)
	if g == null or g.weapon != str(f[11]):
		g = _build_ghost(id, track, str(f[11]))
	g.root.visible = bool(f[9]) and t <= track.last_time() + 1.0
	g.root.global_position = f[0]
	g.visual.transform = Transform3D(Basis(Vector3.UP, float(f[2])), Vector3.ZERO)
	var pose := int(f[4])
	var a := g.anim
	a.state = Player.pose_state(pose)
	a.crouched = Player.pose_crouched(pose)
	a.velocity = f[1]
	a.yaw = float(f[2])
	a.pitch = float(f[3])
	a.flags = int(f[5])
	a.grapple_on = bool(f[6])
	a.grapple_anchor = f[7]
	a.alive = bool(f[8])
	_watch(a.flags, g.weapon, g.seen, g)
	g.animator.update(delta, a, g.visual.global_transform)
	_draw_rope(g.rope, g.hook, a.grapple_on and a.alive and g.root.visible, g.robot.marker("grapple"), a.grapple_anchor)


func _build_ghost(id: int, track: KillClip.Track, weapon: String) -> Ghost:
	var old: Ghost = _ghosts.get(id)
	if old:
		old.root.queue_free()
	var g := Ghost.new()
	g.weapon = weapon
	g.root.name = "Ghost_%d" % id
	add_child(g.root)
	g.root.add_child(g.visual)
	g.robot = RobotModel.new().build(track.character, track.color, false, weapon)
	g.visual.add_child(g.robot)
	g.animator = RobotAnimator.new(g.robot)
	var rope := _make_rope()
	g.rope = rope[0]
	g.hook = rope[1]
	_ghosts[id] = g
	return g


## Remains: from the moment of each death in the clip, the replay's own ragdoll or
## giblets where the recording says, the body they replaced out of sight until it is
## back (respawned).
func _play_wrecks() -> void:
	for w: KillClip.Wreck in clip.wrecks:
		var t := clip.time_for(w.who, time)
		var shown := t >= w.first_time() and t < w.first_time() + Remains.LIFETIME and _gore_shows(w) \
			and (third_person or w.who != clip.killer)   # (no body of the killer's own in front of their eyes)
		var body: Node3D = _wrecks.get(w)
		if not shown:
			if body:
				body.queue_free()
			_wrecks.erase(w)
			continue
		if not _wrecks.has(w):
			body = _make_wreck(w)
			_wrecks[w] = body
		if body == null:
			continue   # (none could be made: the body stays, playing its death)
		body.call("pose", w.pose_at(t))
		var g: Ghost = _ghosts.get(w.who)
		# Hidden while dead (and just at the death, when its frames may still say alive).
		if g and (not g.anim.alive or t - w.first_time() < 0.2):
			g.root.visible = false


## Remains show as the game would show them now: none with gore off, and giblets only
## with full gore (Settings.gore). Without them the body plays its death instead.
func _gore_shows(w: KillClip.Wreck) -> bool:
	return Settings.gore != "off" and (w.kind != "gibs" or Settings.gore == "full")


## The replay's own ragdoll or giblets for `w`, made from the body it replaces (posed as
## it was at the death), in _fx. Null if none can be made.
func _make_wreck(w: KillClip.Wreck) -> Node3D:
	var g: Ghost = _ghosts.get(w.who)
	var source: RobotModel = g.robot if g and g.weapon == w.weapon else null
	var spare: RobotModel = null   # no body to make them from (not in the clip): a fresh one
	if source == null:
		spare = RobotModel.new().build(w.character, w.color, false, w.weapon if w.weapon != "" else "pistol")
		_fx.add_child(spare)
		source = spare
	var made: Node3D = null
	if w.kind == "gibs":
		made = Gibs.puppet(source, w.scrap, RobotModel.trim_color(w.color))
	else:
		made = Ragdoll.puppet(w.character, w.color, w.weapon if w.weapon != "" else "pistol", source.skeleton)
	if made:
		_fx.add_child(made)
		if made is Ragdoll:
			(made as Ragdoll).model.global_transform = source.global_transform   # (where the body was, so it is not culled)
		var t := clip.time_for(w.who, time)
		made.call("pose", w.pose_at(t))
		if made is Gibs and t - w.first_time() < 0.3:   # (not for pieces already lying there when the clip starts)
			var mid := (made as Gibs).focus()
			(made as Gibs).effects(mid, w.fx, false)
			_sound("heavy_hit", mid, false)
		if DevArgs.sync_log:
			print("KILLCAM WRECK %d %d %s %.2f %.2f" % [Net.my_id(), w.who, w.kind, time - clip.kill_time, w.last_time() - w.first_time()])   # (when, and how much of the fall was recorded)
	if spare:
		for i in spare.mesh.get_surface_override_material_count() if spare.mesh else 0:   # headless Godot grumbles otherwise
			spare.mesh.set_surface_override_material(i, null)
		spare.free()
	return made


## New swings, kicks and wind-ups from the animation flags (see Player._watch_swings).
## `g` is null for the killer (their arms move instead of a body).
func _watch(flags: int, weapon: String, seen: Dictionary, g: Ghost) -> void:
	var melee := weapon != "none" and WeaponData.melee(weapon)
	var swings := RobotAnimInput.swings_of(flags)
	var kicks := RobotAnimInput.kicks_of(flags)
	var flying := RobotAnimInput.flying_of(flags)
	if not seen.has("swings"):
		seen.merge({"swings": swings, "kicks": kicks, "flying": flying, "wind": -1.0})
		return
	if melee and RobotAnimInput.winding_of(flags):
		seen.wind = maxf(float(seen.wind), 0.0) + get_process_delta_time()
		var held := WeaponData.by_id(weapon).charge_of(seen.wind)
		if g:
			g.animator.wind(held)
		elif _view:
			_view.wind(held)
	if swings != int(seen.swings):
		seen.swings = swings
		if melee:
			var power := WeaponData.by_id(weapon).charge_of(maxf(float(seen.wind), 0.0))
			if g:
				g.animator.swing(power)
			elif _view:
				_view.swing(power)
		seen.wind = -1.0
	if g and flying != bool(seen.flying):
		g.animator.set_flying_kick(flying)
	seen.flying = flying
	if kicks != int(seen.kicks):
		seen.kicks = kicks
		if g:
			g.animator.kick(flying)
		if world_sound or g == null:
			_sound("kick" if not flying else "flying_kick", camera.global_position if g == null else g.root.global_position, g == null)


# ---------------------------------------------------------------------------
# Shots, rockets, blows

func _play_event(e: Dictionary) -> void:
	var who := int(e.who)
	var mine := who == clip.killer
	match str(e.kind):
		"shot":
			var weapon := str(e.weapon)
			var data := WeaponData.by_id(weapon)
			var muzzle: Vector3 = e.muzzle
			var left := false
			if mine and _view:
				left = data.is_akimbo() and _akimbo_shots % 2 == 1
				_akimbo_shots += 1
				_view.fire(left)
				muzzle = _view.marker(data.muzzle_bone_left if left else data.muzzle_bone)
			elif _ghosts.has(who):
				var g: Ghost = _ghosts[who]
				left = data.is_akimbo() and g.akimbo_shots % 2 == 1
				g.akimbo_shots += 1
				g.animator.fire(left)
				muzzle = g.robot.marker(data.muzzle_bone_left if left else data.muzzle_bone)
			ShotFx.spawn(_fx, muzzle, e.ends, e.hits, weapon)
			if mine:
				Sound.gun_fire(weapon, muzzle, true)
			elif world_sound:
				Sound.gun_fire(weapon, muzzle, false)
		"projectile":
			var data := WeaponData.by_id(str(e.weapon))
			var muzzle := Vector3.INF
			if mine and _view:
				_view.fire()
				muzzle = _view.marker(data.muzzle_bone)
			elif _ghosts.has(who):
				(_ghosts[who] as Ghost).animator.fire()
				muzzle = (_ghosts[who] as Ghost).robot.marker(data.muzzle_bone)
			var track: KillClip.Track = clip.tracks.get(who)
			var color := RobotModel.trim_color(track.color if track else Color.WHITE)
			var rocket := Projectile.make(int(e.id), data, e.origin, e.direction, muzzle, color)
			rocket.set_physics_process(not manual)   # (stepped with the clip instead)
			_fx.add_child(rocket)
			if mine:
				Sound.gun_fire(data.id, camera.global_position, true)
			elif world_sound:
				Sound.gun_fire(data.id, e.origin, false)
		"boom":
			var rocket := _fx.get_node_or_null("Projectile_%d" % int(e.id))
			if rocket:
				rocket.queue_free()
			ShotFx.landed(_fx, e.at, WeaponData.by_id(str(e.weapon)))
			_sound(ShotFx.landed_sound(WeaponData.by_id(str(e.weapon))), e.at, false)
		"melee":
			if mine and _view and str(e.weapon) not in ["kick", "flying_kick"] and not (e.points as PackedVector3Array).is_empty():
				_view.hit_stop()


func _sound(sound: String, at: Vector3, own: bool) -> void:
	if own or not world_sound:
		Sound.play(sound, -2.0 if own else -8.0, 0.05)
	else:
		Sound.play_at(sound, at, "fire", 0.0, 0.05)


# ---------------------------------------------------------------------------
# Grapple ropes (drawn like Player's)

func _make_rope() -> Array:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	mat.metallic = 0.6
	mat.roughness = 0.4
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = mat
	rope.mesh = cyl
	rope.top_level = true
	rope.visible = false
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope)
	var hook := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	var hook_mat := StandardMaterial3D.new()
	hook_mat.albedo_color = Color(0.95, 0.7, 0.15)
	box.material = hook_mat
	hook.mesh = box
	hook.top_level = true
	hook.visible = false
	add_child(hook)
	return [rope, hook]


func _draw_rope(rope: MeshInstance3D, hook: MeshInstance3D, on: bool, from: Vector3, anchor: Vector3) -> void:
	var span := anchor - from
	var dist := span.length()
	rope.visible = on and dist > 0.05
	hook.visible = on
	if not rope.visible:
		return
	var y := span / dist
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	rope.global_transform = Transform3D(Basis(x, y * dist, z), from + span * 0.5)
	hook.global_position = anchor
