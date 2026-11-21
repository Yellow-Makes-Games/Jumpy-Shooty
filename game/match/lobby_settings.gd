class_name LobbySettings
extends RefCounted
## Settings the host picks in the lobby that change how a match is played, beyond the
## mode, map and win condition. In Vs Bots you are the host, so you pick them there.
## They live in Net.match_settings with the others, so they reach every copy (players
## who join later too) the same way; the host enforces them.
##
## Today: which weapons are allowed in a shoot-out ("weapons"), which mobility tools
## are allowed in any fight ("mobility"), how many players the lobby takes
## ("max_players"), the Killcam mode's points to win and time limit
## ("killcam_points", "killcam_minutes"; see KillcamMode), a random map and the maps
## it may pick from ("random_map", "map_pool"), and the song the lobby plays ("song";
## see Music), the movement variant everyone plays with ("movement"; see
## MovementTuning.VARIANTS, for A/B testing how movement feels), and how far everyone's
## zoom goes ("zoom": A or B, see ZOOMS), and whether the secret code has unlocked the
## Auto Rocket Launcher for the next match ("auto_rockets", see SecretRockets).
##
## To add a setting: give it a key and a default in DEFAULTS, make clean() keep only
## sensible values for it, put its rules here, and add a control for the host in the
## lobby (and the Vs Bots page) next to the weapons one.

## key -> the value when the host has not changed it.
## weapons: the ids (from WeaponData) a player may pick; [] means every weapon. One
##   id is a single gun for everyone.
## mobility: the ids (from Mobility) a player may pick; [] means every tool. One id is
##   the same tool for everyone.
## max_players: how many players the online lobby takes, MIN_PLAYERS to MAX_PLAYERS.
## killcam_points, killcam_minutes: Killcam mode: first to this many points, or the most
##   after this many minutes.
## random_map: the host picks the map as the match starts, from the pool. "map" then
##   holds the map last picked (the one being played, once the match is on).
## map_pool: the map ids (from Maps.random_ids, any kind of game) Random may pick; []
##   means every one. Only the ones for the game set up count (see pool_for).
## song: the song (a name from Music.song_names) the lobby plays, over and over, until
##   the host picks another; "" shuffles them as usual.
## movement: the movement variant (an id from MovementTuning.VARIANTS) every player
##   runs, in every kind of game; it takes effect when the match starts.
## zoom: how far the zoom button narrows every player's view ("a" or "b", see ZOOMS).
## auto_rockets: the secret code was typed: everyone may pick the Auto Rocket Launcher
##   this match (see SecretRockets). The host turns it off when the match ends.
const DEFAULTS := {"weapons": [], "mobility": [], "max_players": 16,
	"killcam_points": KillcamMode.POINTS_TO_WIN, "killcam_minutes": KillcamMode.MINUTES,
	"random_map": false, "map_pool": [], "song": "", "movement": MovementTuning.DEFAULT_VARIANT, "zoom": "a",
	"auto_rockets": false}
## The zoom (see CameraRig.zoom), A or B: degrees off each player's own field of view.
const ZOOMS := {"a": 30.0, "b": 45.0}
const MIN_PLAYERS := 2
const MAX_PLAYERS := 16   ## the same as Net.MAX_PLAYERS (Net builds its settings with clean(), before it is there to ask)


## `settings` with every lobby setting present and valid (unknown weapons dropped,
## each listed once, in the pickers' order; all of them is the same as []).
static func clean(settings: Dictionary) -> Dictionary:
	var s := settings.duplicate()
	for key in DEFAULTS:
		if not s.has(key):
			s[key] = DEFAULTS[key].duplicate() if DEFAULTS[key] is Array else DEFAULTS[key]
	s["weapons"] = normalized_weapons(s.get("weapons", []))
	s["max_players"] = clampi(int(s.get("max_players", MAX_PLAYERS)), MIN_PLAYERS, MAX_PLAYERS)
	s["mobility"] = normalized_mobility(s.get("mobility", []))
	s["killcam_points"] = KillcamMode.clean_points(s.get("killcam_points"))
	s["killcam_minutes"] = KillcamMode.clean_minutes(s.get("killcam_minutes"))
	s["random_map"] = s.get("random_map") is bool and s.random_map
	s["map_pool"] = normalized_pool(s.get("map_pool", []))
	s["song"] = str(s.song) if s.get("song") is String else ""
	s["movement"] = MovementTuning.valid_variant(s.get("movement"))
	s["zoom"] = valid_zoom(s.get("zoom"))
	s["auto_rockets"] = s.get("auto_rockets") is bool and s.auto_rockets
	return s


static func valid_zoom(value) -> String:
	return str(value) if ZOOMS.has(str(value)) else "a"


## The zoom the match is set up with ("a" or "b"; A where nobody has picked: Practice).
static func zoom() -> String:
	return valid_zoom(Net.match_settings.get("zoom"))


## How many degrees the zoom takes off a player's field of view in this match.
static func zoom_degrees() -> float:
	return ZOOMS[zoom()]


## A list of ids from `every` as stored: known ids only, in `every`'s order; [] for all.
static func _normalized(ids, every: Array) -> Array:
	if not ids is Array:
		return []
	var out := every.filter(func(w): return w in ids)
	return [] if out.size() == every.size() else out


## A list of weapon ids as stored: known ids only, in WeaponData.IDS order; [] for all.
static func normalized_weapons(ids) -> Array:
	return _normalized(ids, WeaponData.IDS)


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
## setting does not apply). With the secret code typed (SecretRockets), the Auto Rocket
## Launcher too, last, whatever the host allows.
static func allowed_weapons() -> Array:
	var out := WeaponData.IDS.duplicate() if not weapons_apply() else weapons_from(Net.match_settings.get("weapons", []))
	if SecretRockets.active():
		out.append(SecretRockets.WEAPON)
	return out


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
	for i in WeaponData.GROUPS.size():
		var ids: Array = WeaponData.group_ids(i).filter(func(w): return w in allowed)
		if not ids.is_empty():
			out.append([WeaponData.GROUPS[i][0], ids])
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


# ---------------------------------------------------------------------------
# Allowed mobility tools. They apply to every fight (shoot-out, Gun Game, Deathmatch,
# Killcam): a race ignores them, because it always uses the grapple.

## A list of mobility ids as stored: known ids only (an old id as it is called now:
## Mobility.RENAMED), in Mobility.IDS order; [] for all.
static func normalized_mobility(ids) -> Array:
	if ids is Array:
		ids = ids.map(func(m): return Mobility.canonical(str(m)))
	return _normalized(ids, Mobility.IDS)


## The mobility tools a stored list allows ([] allows every one).
static func mobility_from(ids) -> Array:
	var out := normalized_mobility(ids)
	return Mobility.IDS.duplicate() if out.is_empty() else out


## Does the allowed-mobility setting apply to the game that is set up?
static func mobility_apply() -> bool:
	return Net.game_kind() != "race"


## The mobility tools a player may pick now (every one when the setting does not apply).
static func allowed_mobility() -> Array:
	if not mobility_apply():
		return Mobility.IDS.duplicate()
	return mobility_from(Net.match_settings.get("mobility", []))


## `id` if it may be used, otherwise the first tool that may.
static func fit_mobility(id: String) -> String:
	var allowed := allowed_mobility()
	return id if id in allowed else str(allowed[0])


## The one mobility tool everyone has, or "" when there is a choice.
static func only_mobility() -> String:
	var allowed := allowed_mobility()
	return str(allowed[0]) if allowed.size() == 1 else ""


## The death screen's mobility button: the next allowed tool after `current`.
static func next_mobility(current: String) -> String:
	var allowed := allowed_mobility()
	var at := allowed.find(current)
	return str(allowed[(at + 1) % allowed.size()])


## A line for the lobby: what the host allows.
static func mobility_summary(ids) -> String:
	var allowed := mobility_from(ids)
	if allowed.size() == Mobility.IDS.size():
		return "Any mobility tool"
	if allowed.size() == 1:
		return "Everyone has the %s" % Mobility.name_of(allowed[0])
	return ", ".join(allowed.map(func(m): return Mobility.short_name(m)))


# ---------------------------------------------------------------------------
# Movement variant (A/B testing): everyone in the match moves the same way. Each copy
# builds its own players' and bots' movement from it as they spawn (see Player).

## The movement variant the match is set up with.
static func movement() -> String:
	return MovementTuning.valid_variant(Net.match_settings.get("movement"))


# ---------------------------------------------------------------------------
# Lobby size: the host refuses anyone who would make the lobby bigger than this.
# Lowering it never removes anyone already in (the host can kick them).

## How many players the lobby takes.
static func max_players() -> int:
	return clampi(int(Net.match_settings.get("max_players", MAX_PLAYERS)), MIN_PLAYERS, MAX_PLAYERS)


# ---------------------------------------------------------------------------
# Random map: the host ticks the maps it may pick from (only maps for the game set up;
# at least one always stays ticked) and picks one of them as the match starts. Everyone
# plays the map picked: it goes out in match_settings.map like any map the host chose,
# so players who join later get it too.

## A pool as stored: known ids from Maps.random_ids (any kind of game), in Maps.LIST
## order; [] for every one.
static func normalized_pool(ids) -> Array:
	return _normalized(ids, _every_random_map())


static func _every_random_map() -> Array:
	return Maps.LIST.filter(func(m): return not m.dev).map(func(m): return m.id)


## The maps Random may pick for `game` from a stored pool: the pool's maps for that
## game, or every one (a pool of [], or one with none for this game).
static func pool_for(ids, game: String) -> Array:
	var every := Maps.random_ids(game)
	var stored := normalized_pool(ids)
	var out := every.filter(func(m): return m in stored)
	return every if out.is_empty() else out


## The maps Random may pick for the game set up.
static func map_pool() -> Array:
	return pool_for(Net.match_settings.get("map_pool", []), Net.game_kind())


## The stored pool with `id` ticked or unticked for `game` (the other games' maps stay
## as they were). Unticking the last map ticked for a game leaves the pool as it was.
static func pool_toggled(ids, game: String, id: String) -> Array:
	var stored := normalized_pool(ids)
	var here := Maps.random_ids(game)
	if not id in here:
		return stored
	var ticked := pool_for(stored, game)
	if id in ticked:
		if ticked.size() == 1:
			return stored
		ticked.erase(id)
	else:
		ticked.append(id)
	var others := (stored if not stored.is_empty() else _every_random_map()).filter(func(m): return not m in here)
	return normalized_pool(others + ticked)


## One map from the pool for `game`: not `last` (the map just played) if the pool has another.
static func pick_map(ids, game: String, last: String = "") -> String:
	var pool := pool_for(ids, game)
	if pool.size() > 1:
		pool.erase(last)
	return str(pool[randi() % pool.size()])


## A line for the lobby: what Random picks from.
static func pool_summary(ids, game: String) -> String:
	var pool := pool_for(ids, game)
	var every := Maps.random_ids(game)
	if pool.size() == every.size():
		return "Random from all %d maps" % every.size()
	if pool.size() == 1:
		return "Random, but only %s is ticked" % Maps.name_of(pool[0])
	return "Random from %d: %s" % [pool.size(), ", ".join(pool.map(func(m): return Maps.name_of(m)))]
