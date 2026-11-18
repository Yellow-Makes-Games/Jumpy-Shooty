extends SceneTree
## Headless checks on the Character Creator's characters (CustomCharacter,
## Accessories, RobotModel.build).
## Run: godot --headless --path . --script tests/custom_character_test.gd
##
## An id survives the trip to text and back, and one with made-up parts, a long
## name or separators in it comes back safe (so a lobby can take one from anyone).
## A custom character's model takes each region's triangles from the robot named
## for it, every accessory adds triangles on the right bone, and the first-person
## body still leaves the head (and so a hat) out.

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
	var junk := "custom:n=A|very=long:name|l=dragon|t=../../x|h=rivet|p=plaid|hat=sombrero|face=shades|zz=1"
	var fixed := Characters.valid(junk)
	var f := CustomCharacter.parse(fixed)
	_expect("unknown parts become the default robot", f.legs == Characters.default_id() and f.torso == Characters.default_id() and f.head == "rivet")
	_expect("unknown paint and accessories are dropped", f.paint == "" and f.accessories.hat == "" and f.accessories.face == "shades")
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
			for torso in ["needle", "bulwark", "templar"]:
				var one := CustomCharacter.new()
				one.legs = "vanguard"
				one.torso = torso
				one.head = torso
				one.accessories[slot] = a.id
				var model := RobotModel.new().build(one.to_id(), Color.RED)
				var extra := 0
				for s in model.mesh.mesh.get_surface_count():
					var m := model.mesh.mesh.surface_get_material(s)
					if m and m.resource_name in Accessories.MATERIALS and _surface_bone(model, s) == Accessories.SLOT_BONE[slot] and not _from_robot(model, s):
						extra += model.mesh.mesh.surface_get_array_len(s) / 3
				_expect("%s (%s) on %s: %d triangles on the %s" % [a.name, slot, torso, extra, Accessories.SLOT_BONE[slot]], extra >= 8)
				_free(model)
	# A hat is on the head bone, so the first-person body (no head) leaves it out.
	var hatted := CustomCharacter.parse(id)
	var m := RobotModel.new().build(hatted.to_id(), Color.RED)
	m.add_view_mesh(4)
	_expect("first person: no head, so no hat", _bone_triangles(m, "head", "view") == 0)
	_expect("first person: the cape and chain are still on the chest", _bone_triangles(m, "chest", "view") > _bone_triangles(
		RobotModel.new().setup(Characters.body("templar"), Color.RED), "chest", ""))
	_free(m)


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
	if which != "view":
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
