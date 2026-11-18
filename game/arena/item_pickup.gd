class_name ItemPickup
extends Node3D
## Deathmatch: a power-up floating over its spot (placed in a map with a MapItemSpawn),
## bobbing and turning over a glowing pad, like a WeaponPickup. Walk through it and the
## host applies it (Match._host_items); it vanishes and comes back after its kind's
## respawn time. It is only a picture: the host decides who took it.
##
## Kinds:
##  - "damage": everything you deal does double damage for DAMAGE_BOOST_TIME seconds.
##  - "health_small": +25 health, up to Match.MAX_HEALTH.
##  - "health_medium": +50 health, up to Match.MAX_HEALTH.
##  - "uber": +100 health, past Match.MAX_HEALTH up to Match.MAX_OVERHEAL.

const KINDS := ["damage", "health_small", "health_medium", "uber"]
const DAMAGE_BOOST_TIME := 30.0
const DAMAGE_BOOST_MULTIPLIER := 2.0

## kind -> [label, colour, health given, may overheal, respawn seconds]
const INFO := {
	"damage": ["2× DAMAGE", Color(1.0, 0.25, 0.3), 0.0, false, 45.0],
	"health_small": ["+25", Color(0.35, 1.0, 0.45), 25.0, false, 10.0],
	"health_medium": ["+50", Color(0.35, 1.0, 0.45), 50.0, false, 15.0],
	"uber": ["UBER +100", Color(0.4, 0.85, 1.0), 100.0, true, 40.0],
}

const HOVER := 0.9
const BOB_HEIGHT := 0.15
const BOB_SPEED := 2.4
const SPIN_SPEED := 1.6

var index := 0
var kind := "health_small"
var spot := Vector3.ZERO

var _float: Node3D
var _pad_material: StandardMaterial3D
var _t := 0.0
var _taken := false


static func valid(k: String) -> String:
	return k if INFO.has(k) else "health_small"


static func heal_amount(k: String) -> float:
	return INFO[valid(k)][2]


static func overheals(k: String) -> bool:
	return INFO[valid(k)][3]


static func respawn_time(k: String) -> float:
	return INFO[valid(k)][4]


static func make(i: int, pos: Vector3, k: String) -> ItemPickup:
	var p := ItemPickup.new()
	p.index = i
	p.kind = valid(k)
	p.name = "Item_%d_%s" % [i, p.kind]
	p.position = pos
	p.spot = pos + Vector3(0, HOVER, 0)
	p._t = float(i) * 1.3
	return p


## Its spot has moved (it sits on an island that is under way: see MapIsland).
func move_to(pos: Vector3) -> void:
	if position.is_equal_approx(pos):
		return
	position = pos
	spot = pos + Vector3(0, HOVER, 0)


func _ready() -> void:
	var glow: Color = INFO[kind][1]
	_float = Node3D.new()
	_float.name = "Float"
	add_child(_float)
	var body := StandardMaterial3D.new()
	body.albedo_color = glow
	body.emission_enabled = true
	body.emission = glow
	body.emission_energy_multiplier = 1.3
	body.roughness = 0.3
	match kind:
		"damage":
			var m := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.45, 0.55, 0.2)
			m.mesh = prism
			m.material_override = body
			_float.add_child(m)
			var m2 := m.duplicate() as MeshInstance3D
			m2.rotation.z = PI
			m2.position.y = -0.3
			_float.add_child(m2)
		_:
			var s := {"health_small": 0.28, "health_medium": 0.4, "uber": 0.5}[kind] as float
			for bar in [Vector3(s, s * 0.34, s * 0.34), Vector3(s * 0.34, s, s * 0.34)]:
				var m := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = bar
				m.mesh = box
				m.material_override = body
				_float.add_child(m)
	_pad_material = StandardMaterial3D.new()
	_pad_material.albedo_color = Color(glow, 0.5)
	_pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.03
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = disc
	pad.position.y = 0.04
	pad.material_override = _pad_material
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pad)
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.shadow_enabled = false
	_float.add_child(light)
	var label := Label3D.new()
	label.text = INFO[kind][0]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.005
	label.outline_size = 10
	label.modulate = Color(1, 1, 1, 0.9)
	label.position.y = 0.5
	_float.add_child(label)
	set_taken(Match.items_taken.has(index))
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	_float.position.y = HOVER + sin(_t * BOB_SPEED) * BOB_HEIGHT
	_float.rotation.y = _t * SPIN_SPEED


func set_taken(taken: bool) -> void:
	_taken = taken
	_float.visible = not taken
	_pad_material.albedo_color = Color(INFO[kind][1], 0.15 if taken else 0.5)


func is_taken() -> bool:
	return _taken
