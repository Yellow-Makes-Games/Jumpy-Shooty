class_name RaceGate
extends RefCounted
## How a race checkpoint looks: two posts, a bar across the top with its number,
## and a faint light curtain across the opening. The finish line is chequered.
## Used in the game and for the editor preview of MapCheckpoint.

const POST := 0.35
const GATE_COLOR := Color(0.2, 0.85, 1.0)
const FINISH_COLOR := Color(1.0, 0.82, 0.25)
const DONE_COLOR := Color(0.35, 0.95, 0.45)

static var _mats := {}


static func make(opening: Vector2, finish: bool, number: int, editor: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Gate"
	var color := FINISH_COLOR if finish else GATE_COLOR
	var w := opening.x
	var h := opening.y
	for side in [-1.0, 1.0]:
		_box(root, Vector3(POST, h + 0.4, POST), Vector3(side * (w * 0.5 + POST * 0.5), (h + 0.4) * 0.5, 0), _mat("post", Color(0.12, 0.13, 0.15)))
		_box(root, Vector3(POST + 0.04, h * 0.7, POST * 0.4), Vector3(side * (w * 0.5 + POST * 0.5), h * 0.45, POST * 0.35), _mat("glow", color, 2.5))
	_box(root, Vector3(w + POST * 2.0, 0.7, POST), Vector3(0, h + 0.4 + 0.35, 0), _mat("post", Color(0.12, 0.13, 0.15)))
	if finish:
		var n := int(w / 0.7)
		for i in n:
			for j in 2:
				var c := Color(0.95, 0.95, 0.95) if (i + j) % 2 == 0 else Color(0.08, 0.08, 0.1)
				_box(root, Vector3(w / n, 0.33, 0.06), Vector3(-w * 0.5 + (i + 0.5) * w / n, h + 0.4 + 0.18 + j * 0.34, POST * 0.55),
					_mat("chk%d" % ((i + j) % 2), c, 0.3))
	else:
		_box(root, Vector3(w, 0.12, 0.06), Vector3(0, h + 0.4 + 0.05, POST * 0.55), _mat("glow", color, 2.5))
	var curtain := MeshInstance3D.new()
	curtain.name = "Curtain"
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	curtain.mesh = q
	curtain.position = Vector3(0, h * 0.5, 0)
	curtain.material_override = _curtain(color)
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(curtain)
	var label := Label3D.new()
	label.name = "Label"
	label.text = "FINISH" if finish else str(number)
	label.font_size = 96 if finish else 120
	label.pixel_size = 0.006
	label.outline_size = 18
	label.modulate = Color.WHITE if finish else color.lightened(0.4)
	label.position = Vector3(0, h + 0.4 + 0.35, POST * 0.6 + 0.02) if not finish else Vector3(0, h + 1.45, 0)
	label.double_sided = true
	root.add_child(label)
	if editor:   # an arrow on the floor: the way racers run through
		_box(root, Vector3(0.25, 0.05, 1.6), Vector3(0, 0.05, -0.8), _mat("arrow", color, 1.0))
	return root


## Tints a gate: dim once you are through it, bright when it is your next one.
static func set_state(gate: Node3D, next: bool, passed: bool) -> void:
	var curtain := gate.get_node_or_null("Curtain") as MeshInstance3D
	if curtain:
		curtain.visible = not passed
		(curtain.material_override as StandardMaterial3D).albedo_color.a = 0.16 if next else 0.05
	var label := gate.get_node_or_null("Label") as Label3D
	if label:
		label.modulate.a = 1.0 if next or not passed else 0.35


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = at
	m.material_override = mat
	parent.add_child(m)


static func _mat(key: String, c: Color, glow: float = 0.0) -> Material:
	var k := "%s%s" % [key, c.to_html()]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[k] = m
	return _mats[k]


static func _curtain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()   # one each, so gates can be tinted one at a time
	m.albedo_color = Color(c, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
