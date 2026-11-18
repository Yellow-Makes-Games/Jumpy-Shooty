class_name DebugMenu
extends Node
## The debug menu: testing cheats, opened with F1 (or `) during Practice and Vs Bots.
## Online it never opens, and every cheat is off (see Cheats), so it cannot be used
## to cheat in a real match.
##
## The panel sits on the left so you can watch the game while you change things;
## the mouse is free while it is open. The stats readout (FPS, position, speed)
## stays on screen after the menu closes.

signal toggled

const TIME_SCALES := [0.1, 0.25, 0.5, 1.0, 2.0]
const TIME_LABELS := ["0.1x", "0.25x", "0.5x", "1x", "2x"]
const RESET_TEXT := "Reset account progress"

var _menu: CanvasLayer
var _col: VBoxContainer
var _stats_layer: CanvasLayer
var _stats: Label
var _bot_count: Label
var _difficulty := 1
var _saved: Array = []    # [position, yaw, pitch] or empty
var _spawn_pick: OptionButton
var _achievement_pick: OptionButton
var _reset: Button


func _ready() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 19   # under the pause menu
	_menu.visible = false
	add_child(_menu)
	var root := Control.new()
	root.theme = UiKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_bottom = -16
	panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()   # keeps the scroll bar off the switches
	margin.add_theme_constant_override("margin_right", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 8)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_col)

	_stats_layer = CanvasLayer.new()
	_stats_layer.layer = 18
	add_child(_stats_layer)
	_stats = Label.new()
	_stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_stats.offset_left = -360
	_stats.offset_right = -16
	_stats.offset_top = 60
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.add_theme_font_override("font", HudStyle.font(true))
	_stats.add_theme_font_size_override("font_size", 15)
	_stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_stats.add_theme_constant_override("outline_size", 5)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_layer.add_child(_stats)


func is_open() -> bool:
	return _menu.visible


func set_open(on: bool) -> void:
	on = on and Cheats.allowed()
	if on == _menu.visible:
		return
	if on:
		_build()
	_menu.visible = on
	toggled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_menu"):
		if event.is_action_pressed("pause") and _menu.visible:
			set_open(false)   # Esc closes this menu first
			get_viewport().set_input_as_handled()
		return
	var arena := Net.arena
	if arena and arena.pause_menu.visible:
		return
	set_open(not _menu.visible)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var allowed := Cheats.allowed()
	if not MatchEndFade.running:   # (the end of a match runs its own slow motion)
		Engine.time_scale = Cheats.time_scale if allowed else 1.0
	if _menu.visible and not allowed:
		set_open(false)
	_stats.visible = Cheats.show_stats and allowed
	if _stats.visible:
		_stats.text = _stats_text()
	if _menu.visible and _bot_count:
		_bot_count.text = "%d of %d bots" % [_bots().size(), Game.MAX_BOTS]


func _me() -> Player:
	return Net.arena.local_player if Net.arena else null


# ---------------------------------------------------------------------------
# The panel

func _build() -> void:
	UiKit.clear(_col)
	_bot_count = null
	UiKit.title(_col, "Debug", 30)
	UiKit.label(_col, "Practice and offline only. F1 or Esc to close.", true, 14)

	UiKit.section(_col, "Cheats")
	_toggle("God mode (no damage from shots)", Cheats.god, func(v): Cheats.god = v)
	_toggle("Infinite ammo", Cheats.infinite_ammo, func(v): Cheats.infinite_ammo = v)
	_toggle("No cooldowns (grapple, dive, slide boost, rocket boots)", Cheats.no_cooldowns, func(v): Cheats.no_cooldowns = v)
	_toggle("Noclip: fly (Space up, Ctrl down, Shift fast)", Cheats.noclip, func(v): Cheats.noclip = v)
	var row := _row()
	_small_button(row, "Full health", func(): Match.host_heal(Net.my_id()))
	_small_button(row, "Kill self", func():
		Match.request_fell(Net.my_id())
		set_open(false))

	UiKit.section(_col, "Game speed")
	UiKit.segmented(_col, TIME_LABELS, maxi(TIME_SCALES.find(Cheats.time_scale), 0), func(i): Cheats.time_scale = TIME_SCALES[i])

	UiKit.section(_col, "Teleport")
	row = _row()
	_small_button(row, "To crosshair", _teleport_to_crosshair)
	_small_button(row, "Save spot", _save_spot)
	_small_button(row, "Back to saved", _load_spot)
	row = _row()
	_spawn_pick = OptionButton.new()
	_spawn_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var places := _places()
	for p in places:
		_spawn_pick.add_item(p[0])
	row.add_child(_spawn_pick)
	_small_button(row, "Go", func():
		if _spawn_pick.selected >= 0:
			_go(places[_spawn_pick.selected]))

	UiKit.section(_col, "Robot and gun")
	var robot := OptionButton.new()
	var ids := Characters.ids()
	for id in ids:
		robot.add_item(Characters.name_of(id))
	robot.select(ids.find(Net.player_character(Net.my_id())))
	robot.item_selected.connect(func(i): _set_loadout("character", ids[i]))
	_col.add_child(robot)
	var gun := OptionButton.new()   # too many weapons for a row of buttons
	for g in WeaponData.IDS:
		gun.add_item(WeaponData.by_id(g).display_name)
	gun.select(WeaponData.IDS.find(Net.player_weapon(Net.my_id())))
	gun.item_selected.connect(func(i): _set_loadout("weapon", WeaponData.IDS[i]))
	_col.add_child(gun)

	UiKit.section(_col, "Bots")
	UiKit.segmented(_col, BotDifficulty.NAMES, _difficulty, func(i): _difficulty = i)
	row = _row()
	_small_button(row, "Add bot", _add_bot)
	_small_button(row, "Remove one", func(): _remove_bots(1))
	_small_button(row, "Remove all", func(): _remove_bots(Game.MAX_BOTS))
	_bot_count = UiKit.label(_col, "", true, 14)
	_toggle("Freeze bots (stand still, hold fire)", Cheats.freeze_bots, func(v): Cheats.freeze_bots = v)

	UiKit.section(_col, "Achievements and unlocks")
	var items := Achievements.item_counts()
	UiKit.label(_col, "%d of %d achievements done  ·  %d of %d rewards unlocked" % [Achievements.done_count(),
		Achievements.LIST.size(), items[0], items[1]], true, 14).name = "account"
	row = _row()
	var open: Array = Achievements.LIST.filter(func(a): return not Achievements.done(a.id))
	_achievement_pick = OptionButton.new()
	_achievement_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_pick.clip_text = true
	_achievement_pick.fit_to_longest_item = false
	for a in open:
		_achievement_pick.add_item("%s: %s" % [a.name, a.what])
	_achievement_pick.disabled = open.is_empty()
	row.add_child(_achievement_pick)
	var complete := _small_button(row, "Complete", func():
		if _achievement_pick.selected >= 0 and _achievement_pick.selected < open.size():
			_account(Achievements.complete.bind(open[_achievement_pick.selected].id)))
	complete.size_flags_horizontal = Control.SIZE_SHRINK_END
	complete.disabled = open.is_empty()
	row = _row()
	_small_button(row, "Complete all", func(): _account(Achievements.complete_all))
	_small_button(row, "Unlock cosmetics", func(): _account(Achievements.unlock_items.bind(false)))
	_small_button(row, "Unlock cards, icons", func(): _account(Achievements.unlock_items.bind(true)))
	UiKit.label(_col, "Saved like real progress, so the unlocks carry into online matches.", true, 13)
	# Resetting cannot be undone, so it takes a second press.
	_reset = UiKit.button(_col, RESET_TEXT, func():
		if _reset.text == RESET_TEXT:
			_reset.text = "Sure? Press again to wipe achievements, medals and unlocks"
		else:
			_account(_reset_account))
	_reset.name = "reset"

	UiKit.section(_col, "Display")
	_toggle("Show FPS, position and speed", Cheats.show_stats, func(v): Cheats.show_stats = v)

	UiKit.spacer(_col, 4)
	UiKit.button(_col, "Turn every cheat off", func():
		Cheats.reset()
		_build())
	UiKit.primary_button(_col, "Close", func(): set_open(false))


## Change the account (see Achievements), then show the new counts.
func _account(change: Callable) -> void:
	change.call()
	_build()


func _reset_account() -> void:
	Achievements.reset_progress()
	if Achievements.wear_unlocked():   # the card or icon you had on is locked again
		Settings.save_settings()
		if Net.players.has(Net.my_id()):
			Net.set_my_card(Settings.calling_card, Settings.icon)


func _toggle(text: String, value: bool, setter: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 16)
	c.toggled.connect(setter)
	_col.add_child(c)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_col.add_child(row)
	return row


func _small_button(row: HBoxContainer, text: String, on_press: Callable) -> Button:
	var b := UiKit.button(row, text, on_press)
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	return b


# ---------------------------------------------------------------------------
# Actions

## [name, position, yaw] of every place the Teleport list offers: the spawn points,
## and a spot facing each target dummy from 10 m away.
func _places() -> Array:
	var out := []
	if not Net.arena:
		return out
	var spawns: Array = Net.arena.layout.spawns
	for i in spawns.size():
		out.append(["Spawn %d" % (i + 1), spawns[i][0], spawns[i][1]])
	for d in Net.arena.dummies:
		var dummy: TargetDummy = d
		var facing := Basis(Vector3.UP, dummy.yaw) * Vector3.FORWARD
		var label := "Target dummy %d" % (dummy.index + 1)
		if dummy.caption != "":
			label += " (%s)" % dummy.caption
		out.append([label, dummy.global_position + facing * 10.0, dummy.yaw + PI])   # looking back at it
	return out


func _go(place: Array) -> void:
	var me := _me()
	if me:
		me.teleport(place[1], place[2])


func _teleport_to_crosshair() -> void:
	var me := _me()
	if not me:
		return
	var eye := me.eye_position()
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + me.aim_forward() * 1000.0, 1)
	var hit := me.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit:
		return
	var n: Vector3 = hit.normal
	var pos: Vector3 = hit.position + n * (0.05 if n.y > 0.6 else Player.CAPSULE_RADIUS + 0.2)
	if n.y <= 0.6:
		pos.y -= 1.0   # against a wall or ceiling: put your eyes about where you pointed
	var pitch := me.input.pitch
	me.teleport(pos, me.input.yaw)
	me.input.pitch = pitch


func _save_spot() -> void:
	var me := _me()
	if me:
		_saved = [me.global_position, me.input.yaw, me.input.pitch]


func _load_spot() -> void:
	var me := _me()
	if me and not _saved.is_empty():
		me.teleport(_saved[0], _saved[1])
		me.input.pitch = _saved[2]


## Changes your robot or gun on the spot (this match only; the saved choice stays).
func _set_loadout(key: String, value: String) -> void:
	var id := Net.my_id()
	if not Net.players.has(id) or not Net.arena:
		return
	Net.players[id][key] = value
	Net.arena.rebuild_player(id)


func _bots() -> Array:
	return Net.players.keys().filter(func(id): return Net.is_bot(id))


func _add_bot() -> void:
	if _bots().size() >= Game.MAX_BOTS or not Net.arena:
		return
	Net.arena.ensure_navigation()
	Net.add_bot(_difficulty, DevArgs.bot_weapon, DevArgs.bot_mobility)


func _remove_bots(count: int) -> void:
	var bots := _bots()
	bots.sort()
	for i in mini(count, bots.size()):
		Net.remove_bot(bots[bots.size() - 1 - i])


func _stats_text() -> String:
	var fps := Engine.get_frames_per_second()
	var lines := ["%d FPS  ·  %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]]
	var me := _me()
	if me:
		var p := me.global_position
		lines.append("%.1f, %.1f, %.1f" % [p.x, p.y, p.z])
		lines.append("%.1f m/s  ·  %s" % [Vector2(me.velocity.x, me.velocity.z).length(),
			"NOCLIP" if Cheats.flying() else MovementController.State.keys()[me.motor.state].replace("_", " ")])
	if not is_equal_approx(Engine.time_scale, 1.0):
		lines.append("Speed %sx" % String.num(Engine.time_scale))
	var on := []
	for c in [[Cheats.god, "GOD"], [Cheats.infinite_ammo, "AMMO"], [Cheats.no_cooldowns, "NO CD"], [Cheats.freeze_bots, "BOTS FROZEN"]]:
		if c[0]:
			on.append(c[1])
	if not on.is_empty():
		lines.append("  ".join(on))
	return "\n".join(lines)
