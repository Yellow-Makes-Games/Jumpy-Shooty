@tool
class_name MapLiftWell
extends Node3D
## A tractor-beam lift: a column of rising light that carries anyone inside it straight
## up (Empyrean Tower). Stand the node on the floor where the beam starts; it reaches
## Height metres up its own y axis. Build the emitter rings at its foot and its top from
## MapBlocks round it (the lower one flat enough to walk onto: under 0.25 m).
##
## Rules:
##  - a player inside the beam rises at Speed (9 m/s: a 30 m tier in a little over 3 s),
##    whatever they were doing: walk in off a floor, fall in from above, swing in;
##  - they can look, aim and shoot the whole way;
##  - they leave at any height by steering or flipping out sideways (the beam only
##    changes how fast you go up, never sideways);
##  - over the last Ease Top metres it slows to a hover at the top, so stepping off
##    onto the top landing is easy;
##  - going down needs nothing: step off a floor and fall (there is no fall damage).
##
## Like all movement, each copy of the game moves its own players (you, and the host
## its bots), and everyone else sees it in the snapshots they send: the beam is fixed
## map data, so there is nothing of its own to keep in step. Bots are told about it
## with MapJumpLink nodes set to Lift (one for each floor they may get off at).
##
## The beam is drawn in the game (a glowing column in Color with glyphs climbing it,
## bright enough to read across the tower); it is never solid. The outline is editor-only.

const GROUP := "map_lifts"
const CATCH := 60.0       ## m/s² the beam changes your up-and-down speed by, at most
const FOOT := 0.4         ## it also takes hold this far below its own floor (the pad you stand on)

## How far up the beam reaches (metres).
@export var height := 30.0:
	set(v):
		height = maxf(v, 1.0)
		_rebuild()
## Half the beam's width (metres).
@export var radius := 1.6:
	set(v):
		radius = maxf(v, 0.5)
		_rebuild()
## How fast it lifts (metres a second).
@export var speed := 9.0
## Over this many metres below the top it slows to a hover.
@export var ease_top := 2.5
## The beam's colour (the tier's accent).
@export var color := Color(0.3, 0.9, 1.0):
	set(v):
		color = v
		_rebuild()

var _beam: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
		return
	add_to_group(GROUP)
	process_physics_priority = -5   # before the players' own step, which then moves them at the speed set here
	if DisplayServer.get_name() != "headless":
		_rebuild()


## Is a body whose feet are at `feet` (in the map's frame) in the beam?
func holds(feet: Vector3) -> bool:
	var local := global_transform.affine_inverse() * feet
	return local.y >= -FOOT and local.y <= height and Vector2(local.x, local.z).length() <= radius


## The speed the beam wants a body at `feet` to rise at: Speed, easing to a hover at the top.
func rise_at(feet: Vector3) -> float:
	var local := global_transform.affine_inverse() * feet
	return speed * smoothstep(0.0, 1.0, clampf((height - local.y) / maxf(ease_top, 0.01), 0.0, 1.0))


## One physics step of the beam on one body (before the body's own movement step):
## if it is inside, its up-and-down speed is brought to the beam's. Returns true if it
## was. `motor` is the body's MovementController.
func lift(body: CharacterBody3D, motor: MovementController, delta: float) -> bool:
	if motor == null or not holds(body.global_position):
		return false
	if motor.state == MovementController.State.SLAM or motor.state == MovementController.State.MANTLE \
			or motor.state == MovementController.State.GLIDE or motor.grapple.attached:
		return false   # a ground slam is committed; a climb, a glide and the rope have their own way up or down
	var vel := body.velocity
	vel.y = move_toward(vel.y, rise_at(body.global_position), CATCH * delta)
	# The body's own step takes this step's gravity off again: put it on first, so it
	# rises at exactly the beam's speed.
	vel.y += motor.tuning.gravity * motor.gravity_scale * delta
	body.velocity = vel
	if body.is_on_floor():
		motor.warped = true   # off the floor: no floor snap, no ground friction this step
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var net := get_node_or_null("/root/Net") if is_inside_tree() else null
	if net == null:
		return
	var arena: Node = net.arena
	if arena == null or not is_instance_valid(arena) or arena.get("players_root") == null:
		return
	for player in arena.players_root.get_children():
		# (Each copy lifts the players it runs: you, and on the host the bots.)
		if player.is_local and player.alive and player.motor != null and not player.get("_flying"):
			lift(player, player.motor, delta)


## The lift whose beam holds `feet`, or null.
static func at(tree: SceneTree, feet: Vector3) -> MapLiftWell:
	for n in tree.get_nodes_in_group(GROUP):
		var well := n as MapLiftWell
		if well != null and well.holds(feet):
			return well
	return null


# ---------------------------------------------------------------------------
# What you see

const BEAM_SHADER := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.3, 0.9, 1.0);
uniform float tall = 30.0;
uniform float around = 10.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// UV.x once round the beam, UV.y from the top (0) to the foot (1).
	float up = (1.0 - UV.y) * tall;
	// Soft streaks of light climbing, steadily (nothing flashes).
	float streak = 0.55 + 0.45 * sin(UV.x * 37.7 + sin(up * 0.35 - TIME * 1.6) * 1.5);
	// Rune glyphs: little marks in a grid that climbs faster than you do.
	vec2 cell = vec2(UV.x * around / 0.7, (up - TIME * 5.0) / 1.1);
	vec2 id = floor(cell);
	vec2 in_cell = fract(cell) - 0.5;
	float pick = hash(id);
	float glyph = 0.0;
	if (pick > 0.72) {
		float a = step(abs(in_cell.x), 0.07) * step(abs(in_cell.y), 0.3);
		float b = step(abs(in_cell.y - (pick - 0.86) * 1.6), 0.06) * step(abs(in_cell.x), 0.26);
		float c = step(abs(abs(in_cell.x) - 0.2), 0.05) * step(abs(in_cell.y + 0.12), 0.16) * step(0.88, pick);
		glyph = clamp(a + b + c, 0.0, 1.0);
	}
	// Brighter toward its foot and its top (the emitter rings), fading out at the very ends.
	float ends = smoothstep(0.0, 0.03, UV.y) * smoothstep(1.0, 0.985, UV.y);
	float rings = 0.3 * (smoothstep(0.9, 1.0, UV.y) + smoothstep(0.1, 0.0, UV.y));
	// Seen edge-on the column is thicker: brighter at its sides.
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = tint * ((0.16 + 0.1 * streak + rings + rim * 0.35) + glyph * 0.9) * ends;
}
"


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _beam == null:
		var shader := Shader.new()
		shader.code = BEAM_SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
		_beam = MeshInstance3D.new()
		_beam.name = "Beam"
		_beam.material_override = _material
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam, false, Node.INTERNAL_MODE_FRONT)
	_beam.mesh = _column(radius, height)
	_material.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	_material.set_shader_parameter("tall", height)
	_material.set_shader_parameter("around", TAU * radius)


## The beam's skin: an open tube with UV.x once round and UV.y from the top (0) to the foot (1).
static func _column(r: float, tall: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var steps := 24
	for i in steps:
		var u0 := float(i) / steps
		var u1 := float(i + 1) / steps
		var d0 := Vector3(sin(u0 * TAU), 0, cos(u0 * TAU))
		var d1 := Vector3(sin(u1 * TAU), 0, cos(u1 * TAU))
		var corners := [[d0, 0.0], [d1, 0.0], [d1, 1.0], [d0, 0.0], [d1, 1.0], [d0, 1.0]]
		for c in corners:
			var dir: Vector3 = c[0]
			var v: float = c[1]
			verts.append(dir * r + Vector3(0, tall * (1.0 - v), 0))
			normals.append(dir)
			uvs.append(Vector2(u0 if dir == d0 else u1, v))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
