extends Node
## The body of tests/portal_view_test.gd (a separate file: it uses the game's autoloads).

var failures := 0


func _check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


func run() -> void:
	var root := Node3D.new()
	add_child(root)
	var portals := Portals.new()
	portals.views_enabled = true
	root.add_child(portals)
	var cam := Camera3D.new()
	cam.fov = 90.0
	root.add_child(cam)
	cam.make_current()

	# A pair on two walls, one facing +z, the other facing +x, 20 m apart.
	portals.place(7, 0, Vector3(0, 1.5, 0), Vector3(0, 0, 1), Vector3.UP)
	portals.place(7, 1, Vector3(20, 1.5, -6), Vector3(1, 0, 0), Vector3.UP)
	var a := portals.get_portal(7, 0)
	var b := portals.get_portal(7, 1)
	_through("wall to wall, straight on", portals, cam, a, b, Vector3(0, 1.6, 4))
	_through("wall to wall, from the side and above", portals, cam, a, b, Vector3(2.5, 3.0, 1.5))
	_check("the other one looks back the other way", _sees(b, a, cam, Vector3(24, 1.2, -5)))

	# Out of a floor: a wall portal's partner on the ground.
	portals.place(8, 0, Vector3(-10, 1.5, 0), Vector3(0, 0, 1), Vector3.UP)
	portals.place(8, 1, Vector3(-10, 0.02, 15), Vector3.UP, Vector3(0, 0, -1))
	var c := portals.get_portal(8, 0)
	var d := portals.get_portal(8, 1)
	_through("wall to floor", portals, cam, c, d, Vector3(-9, 1.8, 3))
	_through("floor to wall, looking down", portals, cam, d, c, Vector3(-10.5, 3.0, 16))

	# What opens and what does not.
	_look(cam, Vector3(0, 1.6, 5), a.frame.origin)
	portals.update_views(cam)
	_check("a portal in view opens its view", a.live)
	_check("one behind the camera does not", not b.live)
	_look(cam, Vector3(0, 1.6, -3), Vector3(0, 1.6, -10))
	portals.update_views(cam)
	_check("nor one behind you (you are behind its wall)", not a.live)
	_look(cam, Vector3(0, 1.6, -3), a.frame.origin)
	portals.update_views(cam)
	_check("nor one seen from behind its wall", not a.live)
	portals.place(9, 0, Vector3(3, 1.5, 0), Vector3(0, 0, 1), Vector3.UP)
	_look(cam, Vector3(2, 1.6, 6), Vector3(2, 1.5, 0))
	portals.update_views(cam)
	_check("a lone portal (no partner) shows its plain face", not portals.get_portal(9, 0).live)
	_check("...while one beside it is see-through", a.live)
	_check("a live portal's plain face is for portal cameras only", a._disc.layers == 1 << (Portal.FLAT_LAYER - 1))
	_check("a lone one's face is for everyone", portals.get_portal(9, 0)._disc.layers == 1)
	_check("the main camera does not see plain faces of live portals", not cam.get_cull_mask_value(Portal.FLAT_LAYER))
	var vm := a._view_cam.cull_mask
	_check("portal cameras see the plain faces", vm & (1 << (Portal.FLAT_LAYER - 1)) != 0)
	_check("...and never a window", vm & (1 << (Portal.VIEW_LAYER - 1)) == 0)
	_check("...your whole body, not the first-person one or the gun",
		vm & (1 << (CameraRig.BODY_LAYER - 1)) != 0 and vm & (1 << (CameraRig.VIEW_BODY_LAYER - 1)) == 0 and vm & (1 << (Player.VIEWMODEL_LAYER - 1)) == 0)
	_check("the layer numbers match the camera rig's and the player's",
		Portal._BODY_LAYER == CameraRig.BODY_LAYER and Portal._VIEW_BODY_LAYER == CameraRig.VIEW_BODY_LAYER and Portal._VIEWMODEL_LAYER == Player.VIEWMODEL_LAYER)
	_check("the window renders only while live", a._view.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	_look(cam, Vector3(0, 1.6, 5), Vector3(0, 1.6, 20))
	portals.update_views(cam)
	_check("...and stops when it goes out of view", a._view.render_target_update_mode == SubViewport.UPDATE_DISABLED and not a._window.visible)

	# At most MAX_VIEWS, the nearest.
	for i in 4:
		portals.place(20 + i, 0, Vector3(-3 + i * 2, 1.5, -1), Vector3(0, 0, 1), Vector3.UP)
		portals.place(20 + i, 1, Vector3(-3 + i * 2, 1.5, -30), Vector3(0, 0, 1), Vector3.UP)
	_look(cam, Vector3(0, 1.6, 12), Vector3(0, 1.5, 0))
	portals.update_views(cam)
	_check("at most %d views at once" % Portals.MAX_VIEWS, portals.live_views().size() == Portals.MAX_VIEWS)
	var far_live := false
	for i in 4:
		if portals.get_portal(20 + i, 1).live:
			far_live = true
	_check("...the nearest ones", not far_live)

	# Sized to the portal on screen.
	var t := tan(deg_to_rad(45.0))
	var near_px := Portals.view_pixels(2.0, Portal.HALF_HEIGHT, t, 1080.0)
	var far_px := Portals.view_pixels(40.0, Portal.HALF_HEIGHT, t, 1080.0)
	_check("close up it is sharp (%d px)" % near_px, near_px >= 600 and near_px <= Portals.VIEW_MAX_PX)
	_check("far off it is small (%d px)" % far_px, far_px == Portals.VIEW_MIN_PX)
	_check("never taller than the screen", Portals.view_pixels(0.6, Portal.HALF_HEIGHT, t, 480.0) <= 480)

	root.queue_free()
	print("portal view: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP if absf((at - from).normalized().y) < 0.95 else Vector3.FORWARD)


## From `eye`, a few points on `from`'s oval show (in its window) what lies straight on
## through `to`.
func _through(name: String, portals: Portals, cam: Camera3D, from: Portal, to: Portal, eye: Vector3) -> void:
	_check(name, _sees(from, to, cam, eye))


func _sees(from: Portal, to: Portal, cam: Camera3D, eye: Vector3) -> bool:
	_look(cam, eye, from.frame.origin)
	if not from.update_view(cam, to, 400):
		print("  no view from %s" % eye)
		return false
	var worst := 0.0
	for spot in [Vector2(0, 0), Vector2(0.6, 0.3), Vector2(-0.5, -0.7), Vector2(0.2, 0.9), Vector2(-0.95, 0.0)]:
		# A point on the oval, and where it shows in the window (Portal's window shader).
		var on := from.frame * Vector3(spot.x * from.half_width, spot.y * from.half_height, 0.0)
		var uv := Vector2(0.5 + spot.x * 0.5, 0.5 - spot.y * 0.5)
		# Straight on through: the same point on the other side, the ray turned to match.
		var ray := (on - eye).normalized()
		var out_at := to.frame * Vector3(-spot.x * from.half_width, spot.y * from.half_height, 0.0)
		var beyond := out_at + from.carry(to, ray) * 7.0
		var px := from._view_cam.unproject_position(beyond)
		var got := px / Vector2(from._view.size)
		worst = maxf(worst, got.distance_to(uv))
	if worst > 0.01:
		print("  off by %.3f of the window" % worst)
	return worst <= 0.01
