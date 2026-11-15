class_name Hud
extends CanvasLayer
## In-game HUD. Phase 0: crosshair, players present, speed, connection info and
## controls. Health, ammo, weapon and kill count arrive with combat in phase 1.

var _crosshair: Control
var _players: Label
var _stats: Label
var _help: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_crosshair)

	_players = _corner_label(root, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_stats = _corner_label(root, Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_help = _corner_label(root, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_help.text = "WASD move  ·  Shift sprint  ·  Space jump  ·  V first/third person  ·  Esc menu"
	_help.modulate = Color(1, 1, 1, 0.6)


func _corner_label(root: Control, preset: int, align: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	if preset == Control.PRESET_TOP_RIGHT:
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if preset == Control.PRESET_BOTTOM_LEFT:
		l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(l)
	return l


func set_players(players: Dictionary) -> void:
	var ids := players.keys()
	ids.sort()
	var lines := PackedStringArray()
	for id in ids:
		var tag: String = " (host)" if id == Net.host_id() else ""
		lines.append("%s%s" % [players[id].name, tag])
	_players.text = "\n".join(lines)


func update_local(p: Player) -> void:
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	var state: String = MovementController.State.keys()[p.motor.state]
	var text := "Speed %4.1f m/s   %s" % [speed, state.capitalize()]
	var ping := _ping_ms()
	if ping >= 0:
		text += "\nPing %d ms" % ping
	_stats.text = text


func _ping_ms() -> int:
	var peer := Net.multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and not Net.is_host():
		var host_peer: ENetPacketPeer = peer.get_peer(1)
		if host_peer:
			return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return -1


class Crosshair extends Control:
	func _draw() -> void:
		var c := Color(1, 1, 1, 0.9)
		var gap := 5.0
		var len := 9.0
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * gap, d * (gap + len), Color.BLACK, 4.0)
			draw_line(d * gap, d * (gap + len), c, 2.0)
		draw_circle(Vector2.ZERO, 1.5, c)
