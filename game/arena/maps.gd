class_name Maps
extends RefCounted
## The list of maps. Each map is a scene in game/maps/ whose root is a MapRoot
## (open it in the Godot editor to change it). The first one is the default; "dev"
## maps are for testing and are listed last in the menus.

const LIST := [
	{"id": "construction_site", "name": "Construction Site", "scene": "res://game/maps/construction_site.tscn", "dev": false},
	{"id": "office", "name": "Office", "scene": "res://game/maps/office.tscn", "dev": false},
	{"id": "testing_grounds", "name": "Testing Grounds", "scene": "res://game/maps/testing_grounds.tscn", "dev": true},
]


static func default_id() -> String:
	return LIST[0].id


static func ids() -> Array:
	return LIST.map(func(m): return m.id)


## A listed map's id, or the res:// path of a map scene (so a new map can be
## tried before it is listed: --map=res://game/maps/my_map.tscn, or F6 in the editor).
static func has(id: String) -> bool:
	return id in ids() or (id.begins_with("res://") and id.ends_with(".tscn") and ResourceLoader.exists(id))


## The name shown in menus ("Testing Grounds (test map)" for dev maps).
static func label(id: String) -> String:
	if id.begins_with("res://"):
		return name_of(id)
	for m in LIST:
		if m.id == id:
			return "%s (test map)" % m.name if m.dev else m.name
	return label(default_id())


## The map's name, as players see it.
static func name_of(id: String) -> String:
	if id.begins_with("res://"):
		return id.get_file().get_basename().capitalize()
	for m in LIST:
		if m.id == id:
			return m.name
	return name_of(default_id())


## A fresh copy of the map with this id (the default map if the id is unknown).
## Add it to the scene, then call build() on it.
static func make(id: String) -> MapRoot:
	if has(id) and id.begins_with("res://"):
		return (load(id) as PackedScene).instantiate() as MapRoot
	for m in LIST:
		if m.id == id:
			return (load(m.scene) as PackedScene).instantiate() as MapRoot
	return make(default_id())


## Fills a drop-down with every map and selects `current`.
static func fill(pick: OptionButton, current: String) -> void:
	pick.clear()
	for i in LIST.size():
		pick.add_item(label(LIST[i].id), i)
		if LIST[i].id == current:
			pick.select(i)
