class_name Maps
extends RefCounted
## The list of maps. The first one is the default; "dev" maps are for testing and
## are listed last in the menus.

const LIST := [
	{"id": "construction_site", "name": "Construction Site", "script": "res://game/arena/construction_site.gd", "dev": false},
	{"id": "testing_grounds", "name": "Testing Grounds", "script": "res://game/arena/testing_grounds.gd", "dev": true},
]


static func default_id() -> String:
	return LIST[0].id


static func ids() -> Array:
	return LIST.map(func(m): return m.id)


static func has(id: String) -> bool:
	return id in ids()


## The name shown in menus ("Testing Grounds (test map)" for dev maps).
static func label(id: String) -> String:
	for m in LIST:
		if m.id == id:
			return "%s (test map)" % m.name if m.dev else m.name
	return label(default_id())


## Builds the map with this id (the default map if the id is unknown).
static func make(id: String) -> MapLayout:
	for m in LIST:
		if m.id == id:
			return (load(m.script) as GDScript).new().build()
	return make(default_id())


## Fills a drop-down with every map and selects `current`.
static func fill(pick: OptionButton, current: String) -> void:
	pick.clear()
	for i in LIST.size():
		pick.add_item(label(LIST[i].id), i)
		if LIST[i].id == current:
			pick.select(i)
