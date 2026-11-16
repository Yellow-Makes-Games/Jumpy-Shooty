class_name Hud
extends CanvasLayer
## In-game HUD: crosshair and hit marker, health, ammo and weapon, kills, match
## timer, kill feed, death screen with respawn countdown, and the Tab scoreboard.
## Placeholder styling until the UI look is chosen.

const FEED_LIFETIME := 5.0

var _root: Control
var _crosshair: Crosshair
var _health_bar: ProgressBar
var _health_label: Label
var _ammo: Label
var _weapon: Label
var _match_info: Label
var _stats: Label
var _help: Label
var _feed: VBoxContainer
var _death: Label
var _damage_flash: ColorRect
var _scoreboard: PanelContainer
var _score_rows: VBoxContainer

var _respawn_left := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	add_child(_root)

	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_flash)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_root.add_child(_crosshair)

	# Top centre: timer and kill target
	_match_info = _label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER, 24)
	# Top left: your kills, speed, ping
	_stats = _label(Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT, 18)
	# Top right: kill feed
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_feed)

	# Bottom left: health
	var health_box := VBoxContainer.new()
	health_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	health_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(health_box)
	_health_label = Label.new()
	_style(_health_label, 26)
	health_box.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(260, 14)
	_health_bar.show_percentage = false
	_health_bar.max_value = Match.MAX_HEALTH
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.9, 0.45)
	_health_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_health_bar.add_theme_stylebox_override("background", bg)
	health_box.add_child(_health_bar)

	# Bottom right: ammo and weapon
	var ammo_box := VBoxContainer.new()
	ammo_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	ammo_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(ammo_box)
	_ammo = Label.new()
	_style(_ammo, 34)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(_ammo)
	_weapon = Label.new()
	_style(_weapon, 16)
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(_weapon)

	_help = _label(Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER, 15)
	_help.text = "WASD move · Shift sprint · Space jump (again in mid-air: flip) · Ctrl crouch/slide · Q dive · Right-click grapple\nClick shoot · R reload · V camera · Tab scores · Esc menu"
	_help.modulate = Color(1, 1, 1, 0.55)

	_death = _label(Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER, 30)
	_death.visible = false

	_build_scoreboard()

	Match.state_changed.connect(_refresh_scoreboard)
	Match.player_hit.connect(_on_hit)
	Match.player_died.connect(_on_died)
	Match.player_respawned.connect(_on_respawned)


func _label(preset: int, align: int, size: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)
	l.horizontal_alignment = align
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]:
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER]:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset == Control.PRESET_CENTER:
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_style(l, size)
	_root.add_child(l)
	return l


func _style(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)


# ---------------------------------------------------------------------------

func set_players(_players: Dictionary) -> void:
	_refresh_scoreboard()


func update_local(p: Player) -> void:
	var me := p.peer_id
	var delta := get_process_delta_time()
	var hp: float = Match.health.get(me, Match.MAX_HEALTH)
	_health_bar.value = hp
	_health_label.text = "%d" % ceil(hp)
	if p.weapon:
		_weapon.text = p.weapon.data.display_name
		if p.weapon.is_reloading():
			_ammo.text = "Reloading %d%%" % int(p.weapon.reload_progress() * 100)
		else:
			_ammo.text = "%d / %d" % [p.weapon.ammo, p.weapon.data.magazine]

	var parts := PackedStringArray()
	if Match.time_left < 1e8:
		var t := int(ceil(Match.time_left))
		parts.append("%d:%02d" % [t / 60, t % 60])
	if Match.kill_target > 0:
		parts.append("First to %d kills" % Match.kill_target)
	_match_info.text = "    ".join(parts) if not parts.is_empty() else "Practice  ·  %s" % (Net.arena.layout.map_name() if Net.arena else "")

	var g := p.motor.grapple
	if g.attached:
		_crosshair.grapple = Crosshair.GRAPPLE_ON
	elif g.cooldown_left > 0.0:
		_crosshair.grapple = Crosshair.GRAPPLE_COOLING
		_crosshair.cooldown = g.cooldown_left / p.motor.tuning.grapple_cooldown
	elif p.alive and not g.find_target(p, p.input).is_empty():
		_crosshair.grapple = Crosshair.GRAPPLE_IN_RANGE
	else:
		_crosshair.grapple = Crosshair.GRAPPLE_NO_TARGET

	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	var state: String = MovementController.State.keys()[p.motor.state]
	var text := "Kills %d   Deaths %d\nSpeed %4.1f m/s   %s" % [Match.kills(me), Match.deaths(me), speed, state.capitalize()]
	var ping := _ping_ms()
	if ping >= 0:
		text += "\nPing %d ms" % ping
	_stats.text = text

	if _respawn_left > 0.0:
		_respawn_left = max(_respawn_left - delta, 0.0)
		_death.text = "%s\nRespawning in %.1f" % [_death.get_meta("who", ""), _respawn_left]
	_scoreboard.visible = Input.is_action_pressed("scoreboard")
	_damage_flash.color.a = move_toward(_damage_flash.color.a, 0.0, delta * 1.5)

	for row in _feed.get_children():
		row.set_meta("age", row.get_meta("age", 0.0) + delta)
		if row.get_meta("age") > FEED_LIFETIME:
			row.queue_free()


func _on_hit(shooter: int, target: int, _damage: float, headshot: bool) -> void:
	if shooter == Net.my_id() and target != shooter:
		_crosshair.flash_hit(false, headshot)
	if target == Net.my_id():
		_damage_flash.color.a = 0.35


func _on_died(victim: int, killer: int) -> void:
	var text := ""
	if killer == 0:
		text = "%s fell" % Net.player_name(victim)
	else:
		text = "%s  >  %s" % [Net.player_name(killer), Net.player_name(victim)]
	var l := Label.new()
	l.text = text
	_style(l, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if victim == Net.my_id() or killer == Net.my_id():
		l.add_theme_color_override("font_color", UiKit.ACCENT)
	_feed.add_child(l)
	while _feed.get_child_count() > 5:
		_feed.get_child(0).free()
	if killer == Net.my_id() and victim != killer:
		_crosshair.flash_hit(true)
	if victim == Net.my_id():
		_respawn_left = Match.RESPAWN_DELAY
		_death.set_meta("who", "You fell" if killer == 0 else "Killed by %s" % Net.player_name(killer))
		_death.visible = true
		_crosshair.visible = false


func _on_respawned(id: int, _spawn_index: int) -> void:
	if id == Net.my_id():
		_respawn_left = 0.0
		_death.visible = false
		_crosshair.visible = true


func _ping_ms() -> int:
	var peer := Net.multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and not Net.is_host():
		var host_peer: ENetPacketPeer = peer.get_peer(1)
		if host_peer:
			return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return -1


# ---------------------------------------------------------------------------
# Scoreboard (hold Tab)

func _build_scoreboard() -> void:
	_scoreboard = PanelContainer.new()
	_scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_scoreboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_scoreboard.grow_vertical = Control.GROW_DIRECTION_BOTH
	_scoreboard.custom_minimum_size = Vector2(520, 0)
	_scoreboard.visible = false
	_root.add_child(_scoreboard)
	_score_rows = VBoxContainer.new()
	_scoreboard.add_child(_score_rows)


func _refresh_scoreboard() -> void:
	if not _score_rows:
		return
	UiKit.clear(_score_rows)
	ResultsTable.build(_score_rows, Match.build_results())


class Crosshair extends Control:
	enum { GRAPPLE_NO_TARGET, GRAPPLE_IN_RANGE, GRAPPLE_COOLING, GRAPPLE_ON }
	var grapple := GRAPPLE_NO_TARGET
	var cooldown := 0.0  ## 1 = just let go, 0 = ready
	var _hit_time := 0.0
	var _kill := false
	var _head := false

	func flash_hit(kill: bool = false, head: bool = false) -> void:
		_hit_time = 0.35 if kill else 0.18
		_kill = kill
		_head = head

	func _process(delta: float) -> void:
		if _hit_time > 0.0:
			_hit_time -= delta
		queue_redraw()

	func _draw() -> void:
		var c := Color(1, 1, 1, 0.9)
		var gap := 5.0
		var len := 9.0
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * gap, d * (gap + len), Color.BLACK, 4.0)
			draw_line(d * gap, d * (gap + len), c, 2.0)
		draw_circle(Vector2.ZERO, 1.5, c)
		# Grapple ring: bright when something is in reach, filling back up during the cooldown.
		var ring := 22.0
		match grapple:
			GRAPPLE_IN_RANGE:
				draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(0.4, 0.9, 1.0, 0.85), 2.0)
			GRAPPLE_ON:
				draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(1.0, 0.75, 0.2, 0.9), 2.5)
			GRAPPLE_COOLING:
				draw_arc(Vector2.ZERO, ring, -PI / 2, -PI / 2 + TAU * (1.0 - cooldown), 40, Color(1, 1, 1, 0.35), 2.0)
			_:
				draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 1.5)
		if _hit_time > 0.0:
			# White = hit, yellow and larger = headshot, red = kill.
			var hc := Color(1, 0.25, 0.2) if _kill else (Color(1, 0.85, 0.2) if _head else Color(1, 1, 1))
			var reach := 20.0 if _head else 16.0
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(d.normalized() * 8.0, d.normalized() * reach, hc, 2.5)
