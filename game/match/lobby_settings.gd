class_name LobbySettings
extends RefCounted
## Settings the host picks in the lobby that change how a match is played, beyond the
## mode, map and win condition. In Vs Bots you are the host, so you pick them there.
## They live in Net.match_settings with the others, so they reach every copy (players
## who join later too) the same way; the host enforces them.
##
## Today there is one: which weapons are allowed in a shoot-out ("weapons").
##
## To add a setting: give it a key and a default in DEFAULTS, make clean() keep only
## sensible values for it, put its rules here, and add a control for the host in the
## lobby (and the Vs Bots page) next to the weapons one.

## key -> the value when the host has not changed it.
## weapons: the ids (from WeaponData) a player may pick; [] means every weapon. One
##   id is a single gun for everyone.
const DEFAULTS := {"weapons": []}


## `settings` with every lobby setting present and valid (unknown weapons dropped,
## each listed once, in the pickers' order; all of them is the same as []).
static func clean(settings: Dictionary) -> Dictionary:
	var s := settings.duplicate()
	for key in DEFAULTS:
		if not s.has(key):
			s[key] = DEFAULTS[key].duplicate() if DEFAULTS[key] is Array else DEFAULTS[key]
	s["weapons"] = normalized_weapons(s.get("weapons", []))
	return s


## A list of weapon ids as stored: known ids only, in WeaponData.IDS order; [] for all.
static func normalized_weapons(ids) -> Array:
	if not ids is Array:
		return []
	var out := WeaponData.IDS.filter(func(w): return w in ids)
	return [] if out.size() == WeaponData.IDS.size() else out


## The weapons a stored list allows ([] allows every weapon).
static func weapons_from(ids) -> Array:
	var out := normalized_weapons(ids)
	return WeaponData.IDS.duplicate() if out.is_empty() else out


# ---------------------------------------------------------------------------
# Allowed weapons. They apply to a shoot-out (free-for-all, 1v1), where everyone
# picks their own weapon. Gun Game hands out a fixed ladder and a Deathmatch puts
# weapons on the map, so both ignore the setting; a race has no weapons.

## Does the allowed-weapons setting apply to the game that is set up?
static func weapons_apply() -> bool:
	return Net.game_kind() == "ffa" and not GunGame.active() and not KillcamMode.active()


## The weapons a player may pick now, in the pickers' order (every weapon when the
## setting does not apply).
static func allowed_weapons() -> Array:
	if not weapons_apply():
		return WeaponData.IDS.duplicate()
	return weapons_from(Net.match_settings.get("weapons", []))


static func is_allowed(weapon_id: String) -> bool:
	return weapon_id in allowed_weapons()


## `weapon_id` if it may be used, otherwise the first weapon that may.
static func fit_weapon(weapon_id: String) -> String:
	var allowed := allowed_weapons()
	return weapon_id if weapon_id in allowed else str(allowed[0])


## The one gun everyone uses, or "" when there is a choice.
static func only_weapon() -> String:
	var allowed := allowed_weapons()
	return str(allowed[0]) if allowed.size() == 1 else ""


## WeaponData.GROUPS with only the allowed weapons, and no empty groups (the number
## keys on the death screen go through these).
static func weapon_groups() -> Array:
	var allowed := allowed_weapons()
	var out := []
	for g in WeaponData.GROUPS:
		var ids: Array = g[1].filter(func(w): return w in allowed)
		if not ids.is_empty():
			out.append([g[0], ids])
	return out


## The death screen's pick: number key `group` (0 = the first group shown; again goes on
## through it), or the mouse wheel by `step` (+1 / -1) through every allowed weapon.
## Returns the weapon to come back with ("" when there is nothing to change).
static func death_pick(current: String, group: int, step: int) -> String:
	var ids := allowed_weapons()
	if ids.size() <= 1:
		return ""
	var at := ids.find(current)
	var pick := ""
	var groups := weapon_groups()
	if group >= 0 and group < groups.size():
		var list: Array = groups[group][1]
		var in_group := list.find(current)
		pick = list[(in_group + 1) % list.size()] if in_group >= 0 else list[0]
	elif step != 0:
		pick = ids[(at + step + ids.size()) % ids.size()] if at >= 0 else ids[0]
	return pick if pick != current else ""


## A line for the lobby: what the host allows.
static func weapons_summary(ids) -> String:
	var allowed := weapons_from(ids)
	if allowed.size() == WeaponData.IDS.size():
		return "Any weapon"
	if allowed.size() == 1:
		return "One gun for everyone: %s" % WeaponData.name_of(allowed[0])
	return "%d of %d weapons" % [allowed.size(), WeaponData.IDS.size()]
