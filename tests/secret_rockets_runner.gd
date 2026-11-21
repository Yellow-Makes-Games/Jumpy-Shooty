extends Node
## Secret code checks (see SecretRockets):
##  - the arrow keys: the code unlocks, a wrong key breaks the run, an extra down still
##    counts, keys that are not arrows are ignored;
##  - the Auto Rocket Launcher: a hidden weapon in no picker until unlocked, fully
##    automatic rockets that kill on a direct hit and never hurt you, drawn as the
##    rocket launcher in red, with the explosives;
##  - the host: anyone in the lobby can type it (not mid-match); it is a lobby setting,
##    so everyone has it; the weapon is then allowed for everyone whatever the host
##    allows (death screen too); the match ending takes it away and gives everyone
##    their own weapon back; it is never saved as your weapon;
##  - the lobby page: typing the code with the arrow keys unlocks it, shows the banner,
##    hands the weapon to whoever typed it, and shows its card in the weapon window.
## Started by tests/secret_rockets_test.gd.

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Secret code checks")
	_listener()
	_weapon()
	_host()
	await _lobby_page()
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _type(l: SecretRockets.Listener, keys: Array) -> int:
	var hits := 0
	for k in keys:
		if l.feed(k):
			hits += 1
	return hits


func _listener() -> void:
	print("  the arrow keys")
	var l := SecretRockets.Listener.new()
	_expect(_type(l, SecretRockets.CODE) == 1, "the code unlocks once")
	_expect(_type(l, SecretRockets.CODE) == 1, "...and again (the listener starts over)")
	_expect(_type(l, [KEY_DOWN, KEY_DOWN, KEY_UP, KEY_UP, KEY_UP, KEY_LEFT, KEY_RIGHT]) == 0, "one down short: nothing")
	l = SecretRockets.Listener.new()
	_expect(_type(l, [KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN] + SecretRockets.CODE.slice(3)) == 1, "a fourth down still counts as the start")
	l = SecretRockets.Listener.new()
	_expect(_type(l, [KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_UP, KEY_LEFT] + SecretRockets.CODE) == 1, "a wrong key breaks the run, the next try still works")
	l = SecretRockets.Listener.new()
	var with_others := []
	for k in SecretRockets.CODE:
		with_others += [KEY_A, k]
	_expect(_type(l, with_others) == 1, "keys that are not arrows are ignored")
	_expect(SecretRockets.CODE_TEXT.split(" ").size() == SecretRockets.CODE.size(), "the code as shown has every key")


func _weapon() -> void:
	print("  the Auto Rocket Launcher")
	var id := SecretRockets.WEAPON
	var w := WeaponData.by_id(id)
	var rocket := WeaponData.by_id("rocket_launcher")
	_expect(w.id == id and WeaponData.has(id) and WeaponData.valid(id) == id, "a real weapon")
	_expect(not id in WeaponData.IDS and WeaponData.GROUPS.all(func(g): return not id in g[1]), "in no picker's own list")
	_expect(id in WeaponData.HIDDEN and id in WeaponData.SECRET, "hidden, and a secret one may pick")
	_expect(WeaponData.group_of(id) == WeaponData.group_of("rocket_launcher") and id in WeaponData.group_ids(WeaponData.group_of(id)),
		"shown with the explosives")
	_expect(w.kind == WeaponData.Kind.PROJECTILE and w.automatic and w.explosive, "fully automatic rockets")
	_expect(w.fire_interval <= rocket.fire_interval / 8.0 and w.magazine >= 30, "fires many times faster than the rocket launcher, from a big magazine")
	_expect(w.damage_at(0.0) >= 100.0 and w.splash_radius > rocket.splash_radius and w.self_damage == 0.0,
		"a direct hit kills, bigger blasts, and your own rockets never hurt you")
	_expect(WeaponData.look_of(id) == "rocket_launcher" and w.muzzle_bone == rocket.muzzle_bone and w.paint.a > 0.0,
		"drawn as the rocket launcher, painted")
	_expect(HudStyle.weapon_width(id) == HudStyle.weapon_width("rocket_launcher"), "the rocket launcher's icon")
	_expect(Sound.stream("fire_" + id) == Sound.stream("fire_rocket_launcher") or Sound.stream("fire_" + id) != null, "it has the rocket launcher's sounds")
	var before := Settings.weapon
	Settings.weapon = id
	_expect(Settings.weapon == before, "it is never saved as your weapon")


## Offline, this copy is the host (as in Vs Bots).
func _settings(weapons: Array, game: String = "ffa") -> void:
	var s := Net.match_settings.duplicate()
	s["game"] = game
	s["map"] = Maps.default_id(game)
	s["mode"] = "kills"
	s["weapons"] = weapons
	Net.set_match_settings(s)


func _host() -> void:
	print("  the host")
	Settings.weapon = "sniper"
	Net.start_offline("Host", "needle", "sniper")
	_settings(["sniper", "shotgun"])
	var id := SecretRockets.WEAPON
	_expect(not SecretRockets.active() and not LobbySettings.is_allowed(id), "locked to start with")
	Net.set_my_weapon(id)
	_expect(Net.player_loadout_weapon(1) != id, "nobody can pick it before the code")
	Net.host_add_player(2, "Client", "orbit", "shotgun")
	var heard := []
	var on_code := func(by: int, by_name: String): heard.append([by, by_name])
	Net.secret_code_entered.connect(on_code)
	Net.in_match = true
	Net._host_secret_code(2)
	_expect(not SecretRockets.active() and heard.is_empty(), "not mid-match")
	Net.in_match = false
	Net._host_secret_code(99)
	_expect(not SecretRockets.active(), "not by someone who is not in the lobby")
	Net._host_secret_code(2)   # (a client typed it: the host hears _ask_secret_code)
	_expect(SecretRockets.active() and Net.match_settings.get(SecretRockets.SETTING) == true, "a client's code unlocks it, in the settings everyone is sent")
	_expect(heard == [[2, "Client"]], "everyone hears who typed it (%s)" % [heard])
	_expect(LobbySettings.is_allowed(id) and LobbySettings.only_weapon() == "", "allowed for everyone, whatever the host allows")
	_expect(LobbySettings.clean(Net.match_settings).get(SecretRockets.SETTING) == true and LobbySettings.clean({}).get(SecretRockets.SETTING) == false,
		"the setting survives cleaning, and is off by default")
	Net._apply_weapon(2, id)
	_expect(Net.player_loadout_weapon(2) == id, "a client may pick it now")
	Net._apply_weapon(2, "shotgun")
	_expect(Net.player_loadout_weapon(2) == "shotgun", "...and put it down again")
	Net._apply_weapon(2, id)
	Net.set_my_weapon(id)
	_expect(Net.player_loadout_weapon(1) == id, "the host may pick it")
	var group: Array = LobbySettings.weapon_groups().filter(func(g): return id in g[1])
	_expect(not group.is_empty() and group[0][0] == "Explosives", "the death screen offers it with the explosives")
	_expect(LobbySettings.death_pick("sniper", -1, 1) == id, "scrolling on the death screen reaches it")
	Net.host_fit_loadouts()
	_expect(Net.player_loadout_weapon(1) == id and Net.player_loadout_weapon(2) == id, "the match starts with it")
	_settings(["sniper"])
	_expect(SecretRockets.active() and Net.player_loadout_weapon(2) == id, "the host changing the lobby keeps it unlocked")
	Net._host_secret_code(1)
	_expect(heard.size() == 2 and SecretRockets.active(), "typing it again just says so again")
	Net.host_end_secret_rockets()
	_expect(not SecretRockets.active() and not LobbySettings.is_allowed(id), "the match ending locks it again")
	_expect(Net.player_loadout_weapon(1) == "sniper" and Net.player_loadout_weapon(2) == "sniper",
		"everyone is back on a weapon the lobby allows (the host: its own)")
	Net.secret_code_entered.disconnect(on_code)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _lobby_page() -> void:
	print("  the lobby page")
	Settings.weapon = "sniper"
	Net.start_offline("Host", "needle", "sniper")
	_settings([])
	var lobby: Control = load("res://game/ui/lobby_menu.tscn").instantiate()
	get_tree().root.add_child(lobby)
	await get_tree().process_frame
	var picker: WeaponPicker = lobby._weapon
	var card: WeaponPicker.Card = picker._cards.get(SecretRockets.WEAPON)
	_expect(card != null and card.modulate.a == 0.0 and card.disabled and card.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"its card is there but unseen until the code")
	_expect(not lobby._rockets_note.visible, "no note about it yet")
	for k in SecretRockets.CODE:
		lobby._input(_key(k))
	await get_tree().process_frame
	_expect(SecretRockets.active(), "typing the code with the arrow keys unlocks it")
	_expect(lobby._banner != null and is_instance_valid(lobby._banner) and lobby._banner.is_inside_tree(), "a banner says so")
	_expect(Net.player_loadout_weapon(1) == SecretRockets.WEAPON and lobby._weapon_card.id == SecretRockets.WEAPON,
		"whoever typed it is handed it")
	_expect(card.modulate.a == 1.0 and not card.disabled, "its card shows in the weapon window")
	_expect(lobby._rockets_note.visible, "a note says it is unlocked")
	_expect(Settings.weapon == "sniper", "your saved weapon is still your own")
	Net.host_end_secret_rockets()
	await get_tree().process_frame
	_expect(card.modulate.a == 0.0 and Net.player_loadout_weapon(1) == "sniper" and not lobby._rockets_note.visible,
		"locked again: the card is gone and you have your own weapon back")
	lobby.queue_free()
	await get_tree().process_frame
