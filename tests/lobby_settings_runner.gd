extends Node
## Lobby settings checks (see LobbySettings):
##  - stored values are cleaned (unknown weapons dropped, all of them is "any");
##  - the host keeps everyone to the allowed weapons: its own pick, a player who joins
##    with a weapon that is not allowed, a later pick of one, a change of the setting,
##    and bots (at random or --bot-weapon); lifting it gives the host its pick back;
##  - one gun: everyone has it and there is nothing to pick;
##  - Gun Game and a Deathmatch ignore the setting;
##  - the death screen's keys and scroll go through the allowed weapons only;
##  - the weapon pickers: the lobby's offers only allowed weapons (and gives way to a
##    note with one gun), the host's control changes the setting, the pause menu's
##    Loadout offers only allowed weapons (none with one gun).
## Started by tests/lobby_settings_test.gd.

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Lobby settings checks")
	_cleaning()
	_host_enforces()
	_bots()
	_other_modes()
	_death_pick()
	_host_control()
	await _lobby_menu()
	await _loadout_menu()
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


## Offline, this copy is the host (as in Vs Bots); a shoot-out with `weapons` allowed.
func _settings(weapons: Array, game: String = "ffa", mode: String = "kills") -> void:
	var s := Net.match_settings.duplicate()
	s["game"] = game
	s["map"] = Maps.default_id(game)
	s["mode"] = mode
	s["weapons"] = weapons
	Net.set_match_settings(s)


func _cleaning() -> void:
	print("  stored values")
	_expect(LobbySettings.clean({}).get("weapons") == [], "a missing setting is filled in with its default (any weapon)")
	_expect(LobbySettings.normalized_weapons(["sniper", "nonsense", "pistol", "sniper"]) == ["pistol", "sniper"],
		"unknown weapons are dropped and each is listed once, in the pickers' order")
	_expect(LobbySettings.normalized_weapons(WeaponData.IDS) == [], "allowing every weapon is stored as any weapon")
	_expect(LobbySettings.normalized_weapons("rifle") == [], "a value that is not a list means any weapon")
	_expect(Net.match_settings.has("weapons"), "the lobby's settings have the weapons setting from the start")


func _host_enforces() -> void:
	print("  the host enforces it")
	Net.start_offline("Host", "needle", "sniper")
	_settings(["shotgun", "rifle"])
	_expect(Net.match_settings.weapons == ["shotgun", "rifle"], "the setting is kept in the match settings everyone is sent")
	_expect(Net.player_loadout_weapon(1) == "shotgun", "the host's saved sniper is not allowed, so it gets the first allowed weapon")
	_expect(Net.pending_weapon() == "shotgun", "the pause menu would show the allowed weapon")
	Net.set_my_weapon("sniper")
	_expect(Net.player_loadout_weapon(1) == "shotgun", "picking a weapon that is not allowed changes nothing")
	Net.set_my_weapon("rifle")
	_expect(Net.player_loadout_weapon(1) == "rifle", "picking an allowed weapon works")
	Net.host_add_player(2, "Client", "orbit", "railgun")
	_expect(Net.player_loadout_weapon(2) == "shotgun", "a player who joins with a weapon that is not allowed gets an allowed one")
	Net._apply_weapon(2, "rocket_launcher")
	_expect(Net.player_loadout_weapon(2) == "shotgun", "a client asking for a weapon that is not allowed is refused")
	Net._apply_weapon(2, "rifle")
	_expect(Net.player_loadout_weapon(2) == "rifle", "a client asking for an allowed weapon gets it")
	_settings(["railgun"])
	_expect(Net.player_loadout_weapon(1) == "railgun" and Net.player_loadout_weapon(2) == "railgun",
		"one gun: when the host sets it, everyone is given that gun")
	_expect(LobbySettings.only_weapon() == "railgun", "one gun: it is the only weapon")
	Net.players[2]["weapon"] = "sniper"   # however it got there...
	Net.host_fit_loadouts()               # ...nobody starts the match with it
	_expect(Net.player_loadout_weapon(2) == "railgun", "starting the match swaps out any weapon that is not allowed")
	_settings([])
	_expect(Net.player_loadout_weapon(1) == "rifle", "when every weapon is allowed again, the host gets back the one it picked")
	_expect(LobbySettings.only_weapon() == "" and LobbySettings.allowed_weapons().size() == WeaponData.IDS.size(),
		"any weapon: every weapon is allowed")


func _bots() -> void:
	print("  bots")
	Net.start_offline("Host", "needle", "pistol")
	_settings(["spear", "bat"])
	var ok := true
	for i in 12:
		var id := Net.add_bot(1)
		ok = ok and Net.player_loadout_weapon(id) in ["spear", "bat"]
		Net.remove_bot(id)
	_expect(ok, "bots take a gun at random from the allowed ones")
	var forced := Net.add_bot(1, "sniper")
	_expect(Net.player_loadout_weapon(forced) == "spear", "a --bot-weapon that is not allowed gives way to an allowed one")
	Net.remove_bot(forced)
	var fine := Net.add_bot(1, "bat")
	_expect(Net.player_loadout_weapon(fine) == "bat", "a --bot-weapon that is allowed is kept")


func _other_modes() -> void:
	print("  Gun Game and Deathmatch")
	Net.start_offline("Host", "needle", "pistol")
	_settings(["sniper"], "ffa", "gungame")
	_expect(not LobbySettings.weapons_apply() and LobbySettings.allowed_weapons().size() == WeaponData.IDS.size(),
		"Gun Game ignores the setting (it has its own ladder)")
	_settings(["sniper"], "dm")
	_expect(not LobbySettings.weapons_apply() and LobbySettings.only_weapon() == "", "a Deathmatch ignores the setting (weapons are on the map)")
	_expect(Net.match_settings.weapons == ["sniper"], "the setting is kept for when the host goes back to a shoot-out")
	_settings(["sniper"], "ffa")
	_expect(LobbySettings.only_weapon() == "sniper", "back in a shoot-out it applies again")


func _death_pick() -> void:
	print("  death screen pick")
	Net.start_offline("Host", "needle", "pistol")
	_settings(["pistol", "revolver", "shotgun", "sniper"])
	var groups := LobbySettings.weapon_groups()
	_expect(groups.map(func(g): return g[0]) == ["Sidearms", "Shotguns", "Marksman"], "only the classes with allowed weapons are listed (%s)" % [groups])
	_expect(groups[0][1] == ["pistol", "revolver"], "a class lists only its allowed weapons")
	_expect(LobbySettings.death_pick("pistol", 0, 0) == "revolver", "key 1 goes on through the allowed sidearms")
	_expect(LobbySettings.death_pick("revolver", 0, 0) == "pistol", "...and round again")
	_expect(LobbySettings.death_pick("pistol", 2, 0) == "sniper", "key 3 is the third class shown (marksman: the sniper)")
	_expect(LobbySettings.death_pick("pistol", 5, 0) == "", "a key past the classes shown does nothing")
	_expect(LobbySettings.death_pick("sniper", -1, 1) == "pistol", "scrolling on from the last allowed weapon goes back to the first")
	_expect(LobbySettings.death_pick("pistol", -1, -1) == "sniper", "scrolling back goes through the allowed weapons only")
	_expect(LobbySettings.death_pick("smg", -1, 1) == "pistol", "from a weapon that is not allowed, scrolling gives the first allowed one")
	_settings(["sniper"])
	_expect(LobbySettings.death_pick("sniper", 0, 0) == "" and LobbySettings.death_pick("sniper", -1, 1) == "",
		"one gun: the keys and the wheel pick nothing")


func _host_control() -> void:
	print("  the host's control")
	var c := AllowedWeaponsPicker.new([])
	var got := []
	c.changed.connect(func(ids: Array): got.append(ids))
	c._on_chip("pistol")
	_expect(c.value().size() == WeaponData.IDS.size() - 1 and not "pistol" in c.value(), "unticking a weapon leaves the rest allowed")
	c.preferred = "sniper"
	c._set_single(true)
	_expect(c.value() == ["sniper"], "One gun starts on your own weapon")
	c._on_chip("rifle")
	_expect(c.value() == ["rifle"], "One gun: pressing another weapon makes that the one")
	c._set_single(false)
	c._on_chip("rifle")
	_expect(c.value() == ["rifle"], "the last allowed weapon cannot be unticked")
	c._on_chip("smg")
	_expect(c.value() == ["smg", "rifle"], "Any mix: ticking adds a weapon")
	c._all.pressed.emit()
	_expect(c.value() == [] and got.size() == 5, "Allow all goes back to any weapon; every change was reported (%d)" % got.size())
	c.free()


func _lobby_menu() -> void:
	print("  lobby")
	Net.start_offline("Host", "needle", "sniper")
	_settings(["shotgun", "rifle", "sniper"])
	var lobby: Control = load("res://game/ui/lobby_menu.tscn").instantiate()
	get_tree().root.add_child(lobby)
	await get_tree().process_frame
	var picker: WeaponPicker = lobby.find_children("*", "WeaponPicker", true, false)[0]
	var control: AllowedWeaponsPicker = lobby.find_children("*", "AllowedWeaponsPicker", true, false)[0]
	_expect(picker.allowed() == ["shotgun", "rifle", "sniper"], "the lobby's weapon cards offer only the allowed weapons")
	_expect(picker._cards["pistol"].disabled and not picker._cards["sniper"].disabled, "weapons that are not allowed are greyed out")
	_expect(control.is_visible_in_tree() and control._edit.visible, "the host sees the Weapons allowed control and can change it")
	control._set_single(true)
	await get_tree().process_frame
	_expect(Net.match_settings.weapons == ["sniper"], "the host's control changes the lobby setting (one gun: its own sniper)")
	_expect(not picker.is_visible_in_tree(), "one gun: the weapon cards give way to a note")
	_settings([], "dm")
	await get_tree().process_frame
	_expect(not control.is_visible_in_tree(), "a Deathmatch does not show the setting")
	lobby.queue_free()
	await get_tree().process_frame


func _loadout_menu() -> void:
	print("  pause menu loadout")
	Net.start_offline("Host", "needle", "sniper")
	for weapons in [["shotgun", "rifle"], ["bat"]]:
		_settings(weapons)
		Net.in_match = true
		var menu := PauseMenu.new()
		get_tree().root.add_child(menu)
		await get_tree().process_frame
		menu.call("_show_loadout")
		await get_tree().process_frame
		var guns := menu.find_children("*", "WeaponPicker", true, false)
		if weapons.size() > 1:
			_expect(guns.size() == 1 and (guns[0] as WeaponPicker).allowed() == weapons, "the Loadout offers only the allowed weapons")
			_expect(guns.size() == 1 and (guns[0] as WeaponPicker).current == "shotgun", "...starting on an allowed one (the saved sniper is not)")
		else:
			_expect(guns.is_empty(), "one gun: the Loadout has no weapon to pick")
		menu.queue_free()
		Net.in_match = false
		await get_tree().process_frame
