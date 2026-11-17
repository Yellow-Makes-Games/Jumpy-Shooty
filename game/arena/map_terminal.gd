@tool
class_name MapTerminal
extends Node3D
## A console players hold "interact" at to set off a map event (Halcyon's low
## gravity). Stand it on a floor in a map scene and point Event at a MapEvent node
## in the same map (a GravityEvent). The blue disc and label are editor-only; the
## console itself is whatever MapBlocks you put round it.
##
## Rules (the host decides, everyone else is shown what it says):
##  - stand within `range` and hold interact for `channel_time` seconds;
##  - letting go cancels, and so does leaving the range, being knocked out of it
##    or dying. Taking damage does not;
##  - one player at a time: while someone is at it, it is theirs;
##  - it cannot be used while its event is running or cooling down.
##
## All the feedback is in the world, none on the HUD: a ring of light over the
## console pulses gently when it is ready, fills round in blue while someone holds,
## and sits dim while it cannot be used. A hum winds down as the ring fills.
##
## (Like the other map nodes, this reaches the game's autoloads by path, not by
## name, so a map scene still loads in the tests that run without them.)

enum Phase { READY, CHANNEL, BUSY }

const GROUP := "map_terminals"
const SYNC_GAP := 0.25      ## seconds between the host's progress updates while someone holds
const BODY_MIDDLE := 0.9    ## the range is measured from a player's middle...
const FOCUS_HEIGHT := 1.0   ## ...to this high above the terminal's own position
const RING_HEIGHT := 2.75   ## the ring of light, above head height so it shows across a room
const RING_RADIUS := 1.4

## Seconds interact must be held.
@export var channel_time := 2.0
## Metres from the console a player can be (and must stay within).
@warning_ignore("shadowed_global_identifier")
@export var range := 2.0:
	set(v):
		range = v
		_refresh_ghost()
## The event it fires: a MapEvent node in this map (a GravityEvent).
@export_node_path("Node") var event: NodePath

var phase := Phase.READY
## Who is holding it (a peer id), while phase is CHANNEL.
var channeler := 0
## 0..1: how far the hold has got.
var progress := 0.0

var _event: MapEvent
var _holding := {}       # host: peer id -> true for everyone who says they are holding here
var _told := {}          # this copy: peer id -> what we last told the host (our player, and the host's bots)
var _sync := 0.0
var _ring: MeshInstance3D
var _plate: MeshInstance3D
var _material: ShaderMaterial
var _hum: AudioStreamPlayer3D
var _hum_fade := 0.0     # dB per second the hum drops by once nobody is holding
var _time := 0.0
var _glow := 0.0
var _ghost: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_ghost()
		return
	add_to_group(GROUP)
	_event = get_node_or_null(event) as MapEvent
	if DisplayServer.get_name() != "headless":
		_build_screen()


## Which terminal this is in the map (the same number on every copy of the game).
func index() -> int:
	return get_tree().get_nodes_in_group(GROUP).find(self) if is_inside_tree() else -1


## The point players must stay close to.
func focus() -> Vector3:
	return global_position + Vector3(0, FOCUS_HEIGHT, 0)


## Is a player standing at `feet` close enough to use it?
func reaches(feet: Vector3) -> bool:
	return (feet + Vector3(0, BODY_MIDDLE, 0)).distance_to(focus()) <= range


## Could someone start holding it right now?
func ready_to_use() -> bool:
	return phase == Phase.READY and (_event == null or not _event.busy())


# ---------------------------------------------------------------------------
# Every copy: say when our own player (and, on the host, each bot) starts or stops
# holding interact here. The host does the rest.

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var net := _autoload("Net")
	if net == null:
		return
	var arena: Node = net.arena
	if arena != null and is_instance_valid(arena) and arena.get("players_root") != null:
		for player in arena.players_root.get_children():
			if not player.is_local:
				continue
			var want: bool = player.alive and player.input.interact and reaches(player.global_position)
			if want != _told.get(player.peer_id, false):
				_told[player.peer_id] = want
				net.terminal_hold(index(), want, player.peer_id)
	if net.is_host():
		host_step(delta, _where)
	elif phase == Phase.CHANNEL:
		progress = minf(progress + delta / maxf(channel_time, 0.01), 0.999)   # between the host's updates


## One of the game's autoloads ("Net", "Match", "Sound", "DevArgs"), or null.
func _autoload(which: String) -> Node:
	return get_node_or_null("/root/" + which) if is_inside_tree() else null


## Where a player's feet are, or null if they are dead or gone.
func _where(id: int) -> Variant:
	var net := _autoload("Net")
	var rules := _autoload("Match")
	var arena: Node = net.arena if net else null
	if arena == null or not is_instance_valid(arena) or rules == null or not rules.is_alive(id):
		return null
	var p: Node3D = arena.get_player(id)
	return p.global_position if p != null and p.alive else null


# ---------------------------------------------------------------------------
# Host

## Host: player `id` says they are (or are no longer) holding interact here.
func host_set_holding(id: int, holding: bool) -> void:
	if holding:
		_holding[id] = true
	else:
		_holding.erase(id)


## Host: one step of the rules. `where` is called with a peer id and returns where
## that player's feet are (a Vector3), or null if they are dead or gone.
func host_step(delta: float, where: Callable) -> void:
	match phase:
		Phase.BUSY:
			if _event == null or not _event.busy():
				_enter(Phase.READY, 0, 0.0)
		Phase.READY:
			if _event != null and _event.busy():
				_enter(Phase.BUSY, 0, 0.0)   # something else set the event off
				return
			var ids := _holding.keys()
			ids.sort()
			for id in ids:
				var at: Variant = where.call(id)
				if at is Vector3 and reaches(at):
					_sync = SYNC_GAP
					_enter(Phase.CHANNEL, id, 0.0)
					break
		Phase.CHANNEL:
			var at: Variant = where.call(channeler) if _holding.has(channeler) else null
			if not (at is Vector3 and reaches(at)):
				_enter(Phase.READY, 0, 0.0)   # let go, walked off, knocked away or dead
				return
			progress = minf(progress + delta / maxf(channel_time, 0.01), 1.0)
			if progress >= 1.0:
				var by := channeler
				_enter(Phase.BUSY, 0, 0.0)
				if _event != null:
					_event.host_start(by)
				return
			_sync -= delta
			if _sync <= 0.0:
				_sync = SYNC_GAP
				_tell(phase, channeler, progress)


func _enter(new_phase: Phase, who: int, how_far: float) -> void:
	_tell(new_phase, who, how_far)
	phase = new_phase
	channeler = who
	progress = how_far


func _tell(new_phase: int, who: int, how_far: float) -> void:
	var net := _autoload("Net")
	if net:
		net.send_terminal_state(index(), new_phase, who, how_far)   # reaches apply_state() here too
	else:
		apply_state(new_phase, who, how_far)


## Everyone: the host says what state this terminal is in.
func apply_state(new_phase: int, who: int, how_far: float) -> void:
	var was := phase
	phase = new_phase as Phase
	channeler = who
	progress = how_far
	if phase == Phase.CHANNEL and was != Phase.CHANNEL:
		_start_hum()
	elif phase != Phase.CHANNEL and was == Phase.CHANNEL:
		# Done: the hum hands over to the event's own sound. Cancelled: it just dies away.
		_hum_fade = 14.0 if phase == Phase.BUSY else 60.0


## The terminal with this number in the running map, or null.
static func at(tree: SceneTree, i: int) -> MapTerminal:
	var list := tree.get_nodes_in_group(GROUP)
	return list[i] as MapTerminal if i >= 0 and i < list.size() else null


# ---------------------------------------------------------------------------
# What you see and hear (never on the HUD)

const SCREEN_SHADER := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress = 0.0;   // 0..1: how much of the ring is lit
uniform float glow = 0.0;       // 0 = dim track only, 1 = the whole ring softly lit (ready)
uniform vec3 lit : source_color = vec3(0.2, 0.55, 1.0);
uniform vec3 track : source_color = vec3(0.05, 0.09, 0.2);
void fragment() {
	float across = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float ticks = smoothstep(0.0, 0.08, abs(fract(UV.x * 24.0) - 0.5) * 2.0);
	float filled = 1.0 - smoothstep(progress - 0.004, progress + 0.004, UV.x);
	vec3 colour = track * (0.6 + 0.4 * ticks);
	colour += lit * 0.55 * glow * ticks;
	colour += lit * 2.6 * filled * step(0.0005, progress);
	ALBEDO = colour * across;
}
"


func _build_screen() -> void:
	var shader := Shader.new()
	shader.code = SCREEN_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = _band(RING_RADIUS, RING_RADIUS, 0.0, 0.5)   # an upright band, seen from every side
	_ring.position.y = RING_HEIGHT
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_plate = MeshInstance3D.new()
	_plate.name = "Plate"
	_plate.mesh = _band(0.22, 0.42, 0.0, 0.0)   # the same ring lying flat on the console top
	_plate.position.y = 1.13
	_plate.material_override = _material
	_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_plate)


## A strip bent round a full circle: from radius r0 at height y0 to radius r1 at
## height y1, with UV.x running once round and UV.y across the strip.
static func _band(r0: float, r1: float, y0: float, y1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var steps := 72
	for i in steps:
		var u0 := float(i) / steps
		var u1 := float(i + 1) / steps
		var d0 := Vector3(sin(u0 * TAU), 0, -cos(u0 * TAU))   # starts at the back, runs clockwise from above
		var d1 := Vector3(sin(u1 * TAU), 0, -cos(u1 * TAU))
		var a := d0 * r0 + Vector3(0, y0, 0)
		var b := d1 * r0 + Vector3(0, y0, 0)
		var c := d1 * r1 + Vector3(0, y1, 0)
		var d := d0 * r1 + Vector3(0, y1, 0)
		for v in [[a, Vector2(u0, 0)], [b, Vector2(u1, 0)], [c, Vector2(u1, 1)], [a, Vector2(u0, 0)], [c, Vector2(u1, 1)], [d, Vector2(u0, 1)]]:
			verts.append(v[0])
			uvs.append(v[1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if _material:
		# Ready: a slow, gentle pulse. Busy or cooling down: only the dim track.
		var want := (0.55 + 0.45 * sin(_time * 2.2)) if phase == Phase.READY and ready_to_use() else 0.0
		_glow = move_toward(_glow, want, delta * 1.5)
		_material.set_shader_parameter("glow", _glow)
		_material.set_shader_parameter("progress", progress if phase == Phase.CHANNEL else 0.0)
	if _hum and _hum.playing:
		if phase == Phase.CHANNEL:
			# A turbine winding down: the pitch sinks as the sound grows.
			_hum.volume_db = lerpf(-16.0, 0.0, progress) + SfxList.VOLUME.get("terminal_hum", -8.0)
			_hum.pitch_scale = lerpf(1.26, 1.0, progress)
		else:
			_hum.volume_db -= _hum_fade * delta
			if _hum.volume_db < -50.0:
				_hum.stop()


func _start_hum() -> void:
	var dev := _autoload("DevArgs")
	var sound := _autoload("Sound")
	if sound == null:
		return
	if dev and dev.sound_log:
		print("SFX3D terminal_hum %.1f" % focus().distance_to(sound.listener_position()))
	if sound.silent:
		return
	if _hum == null:
		var stream: AudioStream = sound.stream("terminal_hum")
		if stream == null:
			return
		stream = stream.duplicate()
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = stream
		_hum.bus = sound.BUS_SFX
		_hum.unit_size = 14.0
		_hum.max_distance = 90.0
		_hum.position.y = FOCUS_HEIGHT
		add_child(_hum)
	_hum.volume_db = -16.0 + SfxList.VOLUME.get("terminal_hum", -8.0)
	_hum.pitch_scale = 1.26
	_hum.play()


# ---------------------------------------------------------------------------
# Editor only: a disc showing the range, and a label

func _refresh_ghost() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _ghost == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.6, 1.0, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost = MeshInstance3D.new()
		_ghost.material_override = mat
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ghost, false, Node.INTERNAL_MODE_FRONT)
		_label = Label3D.new()
		_label.text = "TERMINAL"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 48
		_label.pixel_size = 0.006
		_label.modulate = Color(0.55, 0.8, 1.0)
		_label.position.y = 2.6
		add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	var disc := CylinderMesh.new()
	disc.top_radius = range
	disc.bottom_radius = range
	disc.height = 0.04
	_ghost.mesh = disc
	_ghost.position.y = 0.03


func _get_configuration_warnings() -> PackedStringArray:
	return [] if not event.is_empty() else ["Point Event at a MapEvent node in this map (a GravityEvent), or holding it does nothing."]
