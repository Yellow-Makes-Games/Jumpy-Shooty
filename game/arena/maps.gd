class_name Maps
extends RefCounted
## The list of maps. Each map is a scene in game/maps/ whose root is a MapRoot
## (open it in the Godot editor to change it). "dev" maps are for testing. The list
## is kept in alphabetical order (by name, within each kind of game), which is the
## order every menu shows them in.
##
## Every map belongs to one kind of game: "ffa" maps (arenas for free-for-all and
## 1v1 fights) or "race" maps (obstacle courses with checkpoints). A map can also
## be played in other kinds of game, listed in "also": the arenas with weapon
## pickups on them (MapWeaponSpawn nodes) host "dm", Deathmatch, where everyone
## starts unarmed and picks weapons up off the map. The menus only offer the maps
## that fit the game being set up, with "Random map" first and picked to begin with.

const GAMES := ["ffa", "dm", "race"]
const GAME_NAMES := {"ffa": "Free-for-all", "dm": "Deathmatch", "race": "Race"}

const LIST := [
	{"id": "castle", "name": "Castle", "scene": "res://game/maps/castle_v2.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "cirrus", "name": "Cirrus", "scene": "res://game/maps/cirrus.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "construction_site", "name": "Construction Site", "scene": "res://game/maps/construction_site.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "empyrean", "name": "Empyrean Tower", "scene": "res://game/maps/empyrean.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "halcyon", "name": "Halcyon", "scene": "res://game/maps/halcyon.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "haunted_house", "name": "Haunted House", "scene": "res://game/maps/haunted_house.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "kilnworks", "name": "Kilnworks", "scene": "res://game/maps/kilnworks.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "lost_temple", "name": "Lost Temple", "scene": "res://game/maps/lost_temple.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "neon_arcade", "name": "Neon Arcade", "scene": "res://game/maps/neon_arcade.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "office", "name": "Office", "scene": "res://game/maps/office.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "rail_yard", "name": "Rail Yard", "scene": "res://game/maps/rail_yard.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "sky_island", "name": "Sky Islands", "scene": "res://game/maps/sky_island.tscn", "dev": false, "game": "ffa", "also": ["dm"]},
	{"id": "testing_grounds", "name": "Testing Grounds", "scene": "res://game/maps/testing_grounds.tscn", "dev": true, "game": "ffa"},
	{"id": "foundry", "name": "Foundry", "scene": "res://game/maps/foundry.tscn", "dev": false, "game": "race"},
	{"id": "rooftop_run", "name": "Rooftop Run", "scene": "res://game/maps/rooftop_run.tscn", "dev": false, "game": "race"},
	{"id": "sky_ruins", "name": "Sky Ruins", "scene": "res://game/maps/sky_ruins.tscn", "dev": false, "game": "race"},
	{"id": "summit_plunge", "name": "Summit Plunge", "scene": "res://game/maps/summit_plunge.tscn", "dev": false, "game": "race"},
]

## Ids of maps that were dropped or folded into another, and the map they now mean, so
## an old killcam clip, --map=ID or a lobby from an older build still finds a map. The
## first Castle was replaced by its refresh (castle_v2, now "castle"); Sky Island's grey
## block-out (sky_island_layout) was dropped in favour of the finished Sky Islands.
const RENAMED := {"castle_v2": "castle", "sky_island_layout": "sky_island"}

## The map each kind of game falls back to when none is set (the menus themselves start
## on "Random map").
const DEFAULTS := {"ffa": "construction_site", "dm": "construction_site", "race": "rooftop_run"}


## The id a map goes by now (see RENAMED); any other id as it is.
static func current(id: String) -> String:
	return RENAMED.get(id, id)


static func _entry(id: String) -> Dictionary:
	id = current(id)
	for m in LIST:
		if m.id == id:
			return m
	return {}


## The default map for a kind of game ("ffa" when not given).
static func default_id(game: String = "ffa") -> String:
	return DEFAULTS.get(valid_game(game), LIST[0].id)


static func _games(m: Dictionary) -> Array:
	return [m.game] + m.get("also", [])


## Every kind of game a map can be played in, its own kind first.
static func games_of(id: String) -> Array:
	var m := _entry(id)
	return _games(m) if not m.is_empty() else [game_of(id)]


static func ids() -> Array:
	return LIST.map(func(m): return m.id)


## The ids of the maps for one kind of game, in menu order.
static func ids_for(game: String) -> Array:
	return LIST.filter(func(m): return valid_game(game) in _games(m)).map(func(m): return m.id)


## "ffa" or "race" (anything else counts as "ffa").
static func valid_game(game: String) -> String:
	return game if game in GAMES else "ffa"


## Which kind of game a map is for. A map scene given by path counts as a race map
## if it has checkpoints in it.
static func game_of(id: String) -> String:
	var m := _entry(id)
	if not m.is_empty():
		return m.game
	if id.begins_with("res://") and ResourceLoader.exists(id):
		var text := FileAccess.get_file_as_string(id)
		return "race" if "map_checkpoint.gd" in text else "ffa"
	return "ffa"


## Can this map be played in this kind of game?
static func fits(id: String, game: String) -> bool:
	return has(id) and valid_game(game) in games_of(id)


## A listed map's id, or the res:// path of a map scene (so a new map can be
## tried before it is listed: --map=res://game/maps/my_map.tscn, or F6 in the editor).
static func has(id: String) -> bool:
	return current(id) in ids() or (id.begins_with("res://") and id.ends_with(".tscn") and ResourceLoader.exists(id))


## The name shown in menus ("Testing Grounds (test map)" for dev maps).
static func label(id: String) -> String:
	if id.begins_with("res://"):
		return name_of(id)
	var m := _entry(id)
	if m.is_empty():
		return label(default_id())
	return "%s (test map)" % m.name if m.dev else m.name


## The map's name, as players see it.
static func name_of(id: String) -> String:
	if id.begins_with("res://"):
		return id.get_file().get_basename().capitalize()
	var m := _entry(id)
	return m.name if not m.is_empty() else name_of(default_id())


## A fresh copy of the map with this id (the default map if the id is unknown).
## Add it to the scene, then call build() on it.
## The scene file of the map with this id (the default map's if the id is unknown).
static func scene_path(id: String) -> String:
	if has(id) and id.begins_with("res://"):
		return id
	var m := _entry(id)
	return scene_path(default_id()) if m.is_empty() else str(m.scene)


static func make(id: String) -> MapRoot:
	if has(id) and id.begins_with("res://"):
		return (load(id) as PackedScene).instantiate() as MapRoot
	var m := _entry(id)
	if m.is_empty():
		return make(default_id())
	return (load(m.scene) as PackedScene).instantiate() as MapRoot


## The "Random" choice in a map drop-down: the host picks one of the maps the lobby's
## pool allows when the match starts (see LobbySettings.pick_map).
const RANDOM := "random"


## The maps Random may pick from for one kind of game: its real maps (not test maps),
## in menu order.
static func random_ids(game: String) -> Array:
	return LIST.filter(func(m): return not m.dev and valid_game(game) in _games(m)).map(func(m): return m.id)


## Fills a drop-down with the maps for one kind of game and selects `chosen` (or
## the first item, if `chosen` is not one of them). Each item's metadata is its map id.
## random: a "Random map" choice first (its metadata is RANDOM), then a separator.
static func fill(pick: OptionButton, chosen: String, game: String = "ffa", random: bool = false) -> void:
	pick.clear()
	if random:
		pick.add_item("Random map", 0)
		pick.set_item_metadata(0, RANDOM)
		pick.add_separator()
	var first := pick.item_count
	var list := ids_for(game)
	for i in list.size():
		pick.add_item(label(list[i]), first + i)
		pick.set_item_metadata(pick.item_count - 1, list[i])
	var at := list.find(current(chosen))
	if random and chosen == RANDOM:
		pick.select(0)
	else:
		pick.select(first + at if at >= 0 else 0)


## The map id picked in a drop-down filled by fill().
static func picked(pick: OptionButton) -> String:
	if pick.selected < 0:
		return default_id()
	return str(pick.get_item_metadata(pick.selected))
