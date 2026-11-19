extends SceneTree
## Headless checks on the Character Creator's characters (CustomCharacter,
## Accessories, RobotModel.build).
## Run: godot --headless --path . --script tests/custom_character_test.gd
##
## An id survives the trip to text and back, and one with made-up parts, a long
## name or separators in it comes back safe (so a lobby can take one from anyone).
## A custom character's model takes each region's triangles from the robot named
## for it, every accessory adds triangles on the right bone, and the first-person
## body still leaves the head (and so a hat) out. The creatures (a person, a
## goblin, a frog...: Characters.KITS) are parts like the robots': they mix with
## them, take the paint, the team colour and a skin tone, borrow the default
## robot's skeleton and guns, and have first-person arms of their own. A body has
## a main, a second and a detail colour (the Templar's plate, surcoat and cross; a
## frog's back, belly and spots) and each accessory a colour of its own. The
## creator's rows step through and list every choice, and its colour buttons open
## a palette.

var failures := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("CUSTOM CHARACTER TEST PASSED" if failures == 0 else "CUSTOM CHARACTER TEST FAILED: %d" % failures)
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	print("Ids")
	var c := CustomCharacter.new()
	c.name = "Sir Bolt"
	c.legs = "kestrel"
	c.torso = "templar"
	c.head = "rivet"
	c.paint = "gold"
	c.accessories = {"hat": "top_hat", "face": "shades", "neck": "gold_chain", "back": "cape"}
	var id := c.to_id()
	var back := CustomCharacter.parse(id)
	_expect("an id reads back the same", back.to_id() == id and back.name == "Sir Bolt" and back.torso == "templar"
		and back.accessories.neck == "gold_chain" and back.paint == "gold")
	_expect("Characters takes a custom id", Characters.has(id) and Characters.valid(id) == id)
	_expect("its name is its own", Characters.name_of(id) == "Sir Bolt")
	_expect("its skeleton and arms are its torso's", Characters.body(id).ends_with("templar.glb") and Characters.arms(id).ends_with("templar_arms.glb"))
	var junk := "custom:n=A|very=long:name|l=dragon|t=../../x|h=rivet|p=plaid|hat=tinfoil|face=shades|shoulder=parrot|s=plaid|zz=1"
	var fixed := Characters.valid(junk)
	var f := CustomCharacter.parse(fixed)
	_expect("unknown parts become the default robot", f.legs == Characters.default_id() and f.torso == Characters.default_id() and f.head == "rivet")
	_expect("unknown paint, skin and accessories are dropped", f.paint == "" and f.skin == "" and f.accessories.hat == ""
		and f.accessories.face == "shades" and f.accessories.shoulder == "parrot")
	_expect("a name can't carry separators or run long", CustomCharacter.clean_name("a|b=c:d\nefghijklmnopqrstuvwxyz") == "abcdefghijklmnop")
	_expect("a plain robot id is untouched", Characters.valid("templar") == "templar" and Characters.valid("nope") == Characters.default_id())
	_expect("bots after a custom character take the robot after its torso", Characters.next(id) == Characters.next("templar"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var r := CustomCharacter.random(rng)
		if Characters.valid(r.to_id()) != r.to_id():
			_expect("a random character is valid", false)
			break

	print("Models")
	for robot in Characters.ids():
		var same := CustomCharacter.new()
		same.legs = robot
		same.torso = robot
		same.head = robot
		var whole := _triangles(RobotModel.new().setup(Characters.body(robot), Color.RED))
		var built := _triangles(RobotModel.new().build(same.to_id(), Color.RED))
		_expect("%s's head, torso and legs together make %s (%d of %d triangles)" % [robot, robot, built, whole], built == whole)
	var mixed := RobotModel.new().build(id, Color.RED)
	_expect("painted: the shell takes the paint", _has_color(mixed, "armor", CustomCharacter.paint_color("gold")))
	var heads := _bone_triangles(mixed, "head", "")
	var rivet_heads := _bone_triangles(RobotModel.new().setup(Characters.body("rivet"), Color.RED), "head", "")
	_expect("a mixed robot's head is the head robot's, plus the hat and shades", heads > rivet_heads)
	var plain := CustomCharacter.parse(id)
	plain.accessories = {"hat": "", "face": "", "neck": "", "back": ""}
	_expect("without accessories the head is just the head robot's",
		_bone_triangles(RobotModel.new().build(plain.to_id(), Color.RED), "head", "") == rivet_heads)

	print("Accessories")
	for slot in CustomCharacter.SLOTS:
		for a in CustomCharacter.ACCESSORIES[slot]:
			if a.id == "":
				continue
			for torso in ["needle", "bulwark", "frog"]:
				var one := CustomCharacter.new()
				one.legs = "vanguard"
				one.torso = torso
				one.head = torso
				one.accessories[slot] = a.id
				var model := RobotModel.new().build(one.to_id(), Color.RED)
				var bone: String = "tail" if slot == "tail" else Accessories.SLOT_BONE[slot]   # a tail has a bone of its own
				var extra := 0
				for s in model.mesh.mesh.get_surface_count():
					var m := model.mesh.mesh.surface_get_material(s)
					if m and m.resource_name in Accessories.MATERIALS and _surface_bone(model, s) == bone and not _from_robot(model, s):
						extra += model.mesh.mesh.surface_get_array_len(s) / 3
				_expect("%s (%s) on %s: %d triangles on the %s" % [a.name, slot, torso, extra, bone], extra >= 8)
				_free(model)
	# A hat is on the head bone, so the first-person body (no head) leaves it out.
	var hatted := CustomCharacter.parse(id)
	var m := RobotModel.new().build(hatted.to_id(), Color.RED)
	m.add_view_mesh(4)
	_expect("first person: no head, so no hat", _bone_triangles(m, "head", "view") == 0)
	_expect("first person: the cape and chain are still on the chest", _bone_triangles(m, "chest", "view") > _bone_triangles(
		RobotModel.new().setup(Characters.body("templar"), Color.RED), "chest", ""))
	_free(m)

	print("Fitting")
	_fitting()

	print("Creatures")
	var k := CustomCharacter.new()
	k.name = "Greg"
	k.legs = "frog"
	k.torso = "human"
	k.head = "goblin"
	k.paint = "blue"
	k.skin = "deep"
	k.accessories.tail = "fox_tail"
	var kid := k.to_id()
	var kback := CustomCharacter.parse(Characters.valid(kid))
	_expect("a creature's id reads back the same", Characters.valid(kid) == kid and kback.legs == "frog" and kback.torso == "human"
		and kback.head == "goblin" and kback.skin == "deep" and kback.accessories.tail == "fox_tail")
	_expect("a creature's skeleton, guns and arms file are the default robot's", Characters.body(kid).ends_with(Characters.default_id() + ".glb")
		and Characters.arms(kid).ends_with(Characters.default_id() + "_arms.glb") and Characters.base(kid) == Characters.default_id())
	_expect("the pickers still list only the robots", Characters.ids().size() == Characters.LIST.size() and not Characters.has("frog")
		and Characters.has_part("frog") and Characters.part_ids().size() == Characters.LIST.size() + Characters.KITS.size())
	_expect("skin shows on a person, not on a robot", RobotModel.shows_skin(k) and not RobotModel.shows_skin(CustomCharacter.new()))
	var greg := RobotModel.new().build(kid, Color.RED)
	_expect("a creature takes the paint", _has_color(greg, "armor", CustomCharacter.paint_color("blue")))
	_expect("and the skin tone", _has_color(greg, "skin", CustomCharacter.skin_color("deep")))
	_expect("it holds the default robot's gun", _has_gun(greg, "pistol"))
	_free(greg)
	var team := RobotModel.new().build(kid, Color.RED, false, "pistol", false, Color(0.9, 0.1, 0.1))
	_expect("a team's colour repaints a creature", _has_color(team, "armor", Color(0.9, 0.1, 0.1)) and not _has_color(team, "armor", CustomCharacter.paint_color("blue")))
	_free(team)
	var host_arms := _triangles(RobotModel.new().setup(Characters.arms(Characters.default_id()), Color.RED, true, "pistol"))
	for kit in Characters.KITS:
		var whole := CustomCharacter.new()
		whole.legs = kit.id
		whole.torso = kit.id
		whole.head = kit.id
		var body := RobotModel.new().build(whole.to_id(), Color.RED, false, "rifle")
		var parts := [_bone_triangles(body, "head", "keep"), _bone_triangles(body, "chest", "keep"), _bone_triangles(body, "thigh_l", "keep")]
		var armed := _has_gun(body, "rifle")
		_free(body)
		var arms := RobotModel.new().build(whole.to_id(), Color.RED, true, "pistol", true)
		var own := 0   # triangles of the creature's own arms (not the gun's)
		for s in arms.mesh.mesh.get_surface_count():
			var mat := arms.mesh.mesh.surface_get_material(s)
			if mat and not "." in mat.resource_name:
				own += arms.mesh.mesh.surface_get_array_len(s) / 3 if arms.mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] == null else (arms.mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var arms_gun := _has_gun(arms, "pistol")
		_free(arms)
		_expect("%s: a head, a chest and legs (%s triangles), a rifle, and first-person arms (%d triangles) with a pistol" % [kit.name, parts, own],
			parts[0] > 20 and parts[1] > 20 and parts[2] > 4 and armed and own > 40 and arms_gun)
	_expect("the default robot's own arms are untouched (%d triangles)" % host_arms, host_arms > 100)

	print("Colours")
	var t := CustomCharacter.new()
	t.name = "Sir Red"
	t.legs = "templar"
	t.torso = "templar"
	t.head = "templar"
	t.paint = "red"
	t.paint2 = "gold"
	t.paint3 = "black"
	t.accessories.hat = "top_hat"
	t.accessories.back = "cape"
	t.colors = {"hat": "purple", "neck": "green"}   # nothing round the neck: that colour is dropped
	var tid := t.to_id()
	var tback := CustomCharacter.parse(Characters.valid(tid))
	_expect("second, detail and accessory colours read back the same", Characters.valid(tid) == tid and tback.paint2 == "gold"
		and tback.paint3 == "black" and tback.color_of("hat") == "purple" and tback.color_of("back") == "" and not "green" in tid)
	var odd := CustomCharacter.parse(Characters.valid("custom:n=x|l=templar|t=templar|h=templar|p2=plaid|p3=gold|hat=top_hat.plaid|face=.red|neck=tie.red.blue"))
	_expect("made-up colours are dropped", odd.paint2 == "" and odd.paint3 == "gold" and odd.accessories.hat == "top_hat"
		and odd.color_of("hat") == "" and odd.accessories.face == "" and Characters.valid(odd.to_id()) == odd.to_id())
	var knight := RobotModel.new().build(tid, Color.RED)
	_expect("the Templar's plate takes the main colour", _has_color(knight, "armor", CustomCharacter.paint_color("red")))
	_expect("its surcoat the second and its cross the detail colour", _has_color(knight, "trim", CustomCharacter.paint_color("gold"))
		and _has_color(knight, "mark", CustomCharacter.paint_color("black")))
	_expect("the hat is purple and the cape is as it comes", _tinted(knight, CustomCharacter.paint_color("purple")) == 1 and _tints(knight) == 1)
	_free(knight)
	var knight_team := RobotModel.new().build(tid, Color.RED, false, "pistol", false, Color(0.9, 0.1, 0.1))
	_expect("a team's colour replaces the main colour only", _has_color(knight_team, "armor", Color(0.9, 0.1, 0.1))
		and not _has_color(knight_team, "armor", CustomCharacter.paint_color("red")) and _has_color(knight_team, "trim", CustomCharacter.paint_color("gold")))
	_free(knight_team)
	var plain_team := RobotModel.new().build("templar", Color.RED, false, "pistol", false, Color(0.9, 0.1, 0.1))
	_expect("the plain Templar wears its team's colour too", _painted(plain_team, Color(0.9, 0.1, 0.1)))
	_free(plain_team)
	for robot in Characters.ids():
		var two := CustomCharacter.new()
		two.legs = robot
		two.torso = robot
		two.head = robot
		two.paint = "red"
		two.paint2 = "lime"
		var built := RobotModel.new().build(two.to_id(), Color.RED)
		var arms := RobotModel.new().build(two.to_id(), Color.RED, false, "pistol", true)
		_expect("%s takes a main and a second colour, in first person too" % robot, _has_color(built, "armor", CustomCharacter.paint_color("red"))
			and _has_color(built, "trim", CustomCharacter.paint_color("lime")) and _painted(arms, CustomCharacter.paint_color("red"))
			and (_painted(arms, CustomCharacter.paint_color("lime")) or robot == "templar"))   # (its arms are all plate and mail)
		_free(built)
		_free(arms)
	var spotty := CustomCharacter.new()
	spotty.legs = "frog"
	spotty.torso = "frog"
	spotty.head = "frog"
	spotty.paint2 = "pink"
	spotty.paint3 = "navy"
	var frog := RobotModel.new().build(spotty.to_id(), Color.RED)
	_expect("a frog's belly takes the second colour and its spots the detail", _has_color(frog, "trim", CustomCharacter.paint_color("pink"))
		and _has_color(frog, "mark", CustomCharacter.paint_color("navy")) and RobotModel.shows(spotty, 1) and RobotModel.shows(spotty, 2))
	_free(frog)
	for slot in CustomCharacter.SLOTS:
		var missed := []
		for a in CustomCharacter.ACCESSORIES[slot]:
			if a.id == "":
				continue
			var one := CustomCharacter.new()
			one.accessories[slot] = a.id
			one.colors[slot] = "hotpink"
			var model := RobotModel.new().build(one.to_id(), Color.RED)
			if _tinted(model, CustomCharacter.paint_color("hotpink")) != 1:
				missed.append(a.id)
			_free(model)
		_expect("every %s accessory takes a colour %s" % [slot, missed], missed.is_empty())

	print("Creator")
	# Loaded here, not named: the creator uses the autoloads, which a test script can't.
	var creator: Node = load("res://game/ui/character_creator.gd").new("")
	root.add_child(creator)
	creator.set_part("whole", "frog")
	_expect("the whole-body row sets head, torso and legs", creator.current.head == "frog" and creator.current.torso == "frog" and creator.current.legs == "frog")
	var all := Characters.part_ids()
	creator.step_part("head", 1)
	_expect("a row steps to the next choice", creator.current.head == all[(all.find("frog") + 1) % all.size()] and creator.current.torso == "frog")
	for i in all.size() - 1:
		creator.step_part("head", 1)
	_expect("and comes back round past the robots and the creatures", creator.current.head == "frog")
	creator.step_part("tail", -1)
	_expect("an accessory row steps back from None to the last one", creator.current.accessories.tail == CustomCharacter.ACCESSORIES.tail[-1].id)
	creator.open_list("hat")
	var list: PopupMenu = creator._list
	_expect("a row's name lists every choice (%d hats)" % list.item_count, list.item_count == CustomCharacter.ACCESSORIES.hat.size())
	list.index_pressed.emit(3)
	_expect("and picking one sets it", creator.current.accessories.hat == CustomCharacter.ACCESSORIES.hat[3].id)
	list.hide()
	creator.open_palette("p")
	_expect("a colour button opens the palette (%d paints)" % creator._palette_grid.get_child_count(), creator._palette_grid.get_child_count() == CustomCharacter.PAINTS.size())
	creator._palette_grid.find_child("pick_gold", false, false).pressed.emit()
	creator.pick_color("s", "deep")
	creator.pick_color("p2", "teal")
	_expect("and picking sets the paint, the skin and the second colour", creator.current.paint == "gold" and creator.current.skin == "deep"
		and creator.current.paint2 == "teal" and not creator._palette.visible)
	creator.pick_color("hat", "red")
	_expect("an accessory's colour button sets its colour", creator.current.color_of("hat") == "red" and ".red" in creator.current.to_id())
	creator.set_part("hat", "")
	creator.set_part("hat", "crown")
	_expect("taking the hat off forgets its colour", creator.current.color_of("hat") == "")
	_expect("with no neckwear its colour button is off", (creator.find_child("color_neck", true, false) as Button).disabled
		and not (creator.find_child("color_hat", true, false) as Button).disabled)
	_expect("what the creator made is a valid character", Characters.valid(creator.current.to_id()) == creator.current.to_id())
	creator.queue_free()


## Accessories fitted to the body they are on: two on one bone in one material both
## show; a hat takes the place of the thin bits on top of the head (not a halo), an
## ear hat of the head's own ears, a covering hat of the hair on top; a tail of the
## legs' own tail; the cape and the tails on bones of their own keep off the floor.
func _fitting() -> void:
	var top_hat := _accessory_triangles("vanguard", {"hat": "top_hat"})
	var mask := _accessory_triangles("vanguard", {"face": "bandit_mask"})
	_expect("a top hat and a bandit mask (both silk, both on the head): both of them (%d + %d triangles)" % [top_hat, mask],
		_accessory_triangles("vanguard", {"hat": "top_hat", "face": "bandit_mask"}) == top_hat + mask)
	var needle := _body_triangles("needle", {})
	_expect("a hat hides Needle's antenna", _body_triangles("needle", {"hat": "top_hat"}) < needle)
	_expect("a halo doesn't", _body_triangles("needle", {"hat": "halo"}) == needle)
	var goblin := _body_triangles("goblin", {"hat": "crown"})
	_expect("cat ears hide the Goblin's own ears", _body_triangles("goblin", {"hat": "cat_ears"}) < goblin)
	var dude := _body_triangles("human", {"hat": "crown"})
	_expect("a top hat tucks the Dude's hair in; a crown doesn't", _body_triangles("human", {"hat": "top_hat"}) < dude
		and _body_triangles("human", {"hat": "fez"}) == dude)
	_expect("a tail takes the place of a cat's own", _body_triangles("cat", {"tail": "fox_tail"}) < _body_triangles("cat", {}))
	var f := Accessories.fit(AABB(Vector3(-0.02, 1.5, -0.14), Vector3(0.04, 0.28, 0.28)), AABB(), AABB(Vector3(-0.2, 1.18, -0.14), Vector3(0.4, 0.32, 0.28)), -0.14)
	var hat := Accessories.measured_for("hat", f, "")
	_expect("a hat on the slimmest head is still hat-sized", hat.w >= Accessories.HAT_HALF.x and hat.d <= Accessories.HAT_HALF.y)
	_expect("Rivet's hats sit on its hard hat", Accessories.measured_for("hat", f, "rivet").top > 1.8)
	_expect("a duck's mustache goes over its beak", Accessories.measured_for("face", f, "duck").mouth_z < -0.13)
	# Sliding: the cape trails and the dino tail stays up, above the floor.
	for what in [{"back": "cape"}, {"tail": "dino_tail"}]:
		var one := CustomCharacter.new()
		one.accessories = what.duplicate()
		var model := RobotModel.new().build(one.to_id(), Color.RED)
		root.add_child(model)
		var bone: String = "cape" if what.has("back") else "tail"
		var i := model.skeleton.find_bone(bone)
		var pose: RobotPose = model.rig.new_pose()
		var low := INF
		for k in 4:
			model.rig.sample(pose, "slide", model.rig.length("slide") * k / 4.0)
			pose.apply(model.skeleton)
			model.settle_sway()
			low = minf(low, _lowest(model, bone))
		_expect("%s: a bone of its own (%d), above the floor in a slide (lowest %.2f)" % [what.values()[0], i, low], i >= 0 and low > 0.0)
		_free(model)


## The model's lowest point following `bone` (most strongly), as posed.
func _lowest(model: RobotModel, bone: String) -> float:
	var low := INF
	var skin := model.mesh.skin
	for s in model.mesh.mesh.get_surface_count():
		var arrays := model.mesh.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()
		for v in verts.size():
			var b := bones[v * per]
			if weights[v * per + 1] > weights[v * per]:
				b = bones[v * per + 1]
			if String(skin.get_bind_name(b)) != bone:
				continue
			var at := model.skeleton.get_bone_global_pose(model.skeleton.find_bone(bone)) * skin.get_bind_pose(b) * verts[v]
			low = minf(low, at.y)
	return low


## A Vanguard with this head (or a whole creature) wearing these: its body's own
## triangles (not the accessories').
func _body_triangles(part: String, wearing: Dictionary) -> int:
	var one := CustomCharacter.new()
	one.legs = part
	one.torso = part
	one.head = part
	one.accessories = wearing.duplicate()
	var model := RobotModel.new().build(one.to_id(), Color.RED)
	var n := 0
	for s in model.mesh.mesh.get_surface_count():
		if _from_robot(model, s):
			n += (model.mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_free(model)
	return n


## The accessories' triangles on a robot wearing these.
func _accessory_triangles(robot: String, wearing: Dictionary) -> int:
	var one := CustomCharacter.new()
	one.legs = robot
	one.torso = robot
	one.head = robot
	one.accessories = wearing.duplicate()
	var model := RobotModel.new().build(one.to_id(), Color.RED)
	var n := 0
	for s in model.mesh.mesh.get_surface_count():
		if not _from_robot(model, s):
			var m := model.mesh.mesh.surface_get_material(s)
			if m and not "." in m.resource_name:
				n += model.mesh.mesh.surface_get_array_len(s) / 3
	_free(model)
	return n


func _has_gun(model: RobotModel, gun: String) -> bool:
	for s in model.mesh.mesh.get_surface_count():
		var mat := model.mesh.mesh.surface_get_material(s)
		if mat and mat.resource_name.begins_with(gun + "."):
			return true
	return false


func _triangles(model: RobotModel) -> int:
	var n := 0
	for s in model.mesh.mesh.get_surface_count():
		var arrays := model.mesh.mesh.surface_get_arrays(s)
		n += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_free(model)
	return n


## Triangles following `bone` (by their first corner's strongest bone).
func _bone_triangles(model: RobotModel, bone: String, which: String) -> int:
	var mi := model.view_mesh if which == "view" else model.mesh
	var n := 0
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		for t in range(0, index.size(), 3):
			if String(mi.skin.get_bind_name(bones[index[t] * per])) == bone:
				n += 1
	if which == "":
		_free(model)
	return n


func _surface_bone(model: RobotModel, s: int) -> String:
	var bones: PackedInt32Array = model.mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_BONES]
	return String(model.mesh.skin.get_bind_name(bones[0]))


## A surface from a robot's model file (they have an index; accessories don't).
func _from_robot(model: RobotModel, s: int) -> bool:
	return model.mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] != null


func _has_color(model: RobotModel, kind: String, color: Color) -> bool:
	for s in model.mesh.mesh.get_surface_count():
		var o := model.mesh.get_surface_override_material(s)
		if o is StandardMaterial3D and RobotModel.material_kind(o.resource_name) == kind and o.albedo_color.is_equal_approx(color):
			return true
	return false


## Whether any surface is repainted this colour, whatever it is called.
func _painted(model: RobotModel, color: Color) -> bool:
	for s in model.mesh.mesh.get_surface_count():
		var o := model.mesh.get_surface_override_material(s)
		if o is StandardMaterial3D and o.albedo_color.is_equal_approx(color):
			return true
	return false


## Surfaces painted an accessory's own colour (all of them, or those of `color`).
func _tints(model: RobotModel) -> int:
	var n := 0
	for s in model.mesh.mesh.get_surface_count():
		var mat := model.mesh.mesh.surface_get_material(s)
		if mat and mat.resource_name == "tint":
			n += 1
	return n


func _tinted(model: RobotModel, color: Color) -> int:
	var n := 0
	for s in model.mesh.mesh.get_surface_count():
		var mat := model.mesh.mesh.surface_get_material(s) as StandardMaterial3D
		if mat and mat.resource_name == "tint" and Color(mat.albedo_color, 1.0).is_equal_approx(color):
			n += 1
	return n


## Let go of the materials first (headless Godot grumbles otherwise), then free.
func _free(model: RobotModel) -> void:
	for i in model.mesh.mesh.get_surface_count():
		model.mesh.set_surface_override_material(i, null)
	if model.view_mesh:
		for i in model.view_mesh.mesh.get_surface_count():
			model.view_mesh.set_surface_override_material(i, null)
	model.free()


func _expect(what: String, ok: bool) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1
