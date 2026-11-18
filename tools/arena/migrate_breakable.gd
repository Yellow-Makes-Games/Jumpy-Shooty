extends SceneTree
## Brings a map saved before "Breakable" became an on/off setting up to date, so the
## same walls and floors break as before.
##
## It used to be Default / Yes / No, and Default meant "breaks if its kind is in the
## palette's Breakable list". Now a block breaks only if its Breakable is ticked. This
## ticks it on every block that broke under the old rule (Yes, or Default with a kind
## in the palette's list on a solid, drawn box thin enough to break per cell) and
## clears it on the rest. It edits the scene file as text, a line per block, and marks
## the map's root so a second run leaves it alone.
##
## Run it once on an old map:
##   godot --headless --path . --script tools/arena/migrate_breakable.gd -- res://game/maps/my_map.tscn
## With no map named it does every scene in game/maps.

const MARK := "metadata/breakable_migrated = true"
const BLOCK_SCRIPTS := ["res://game/arena/map_block.gd", "res://game/arena/map_hazard.gd"]


func _init() -> void:
	var files := OS.get_cmdline_user_args()
	if files.is_empty():
		for f in DirAccess.get_files_at("res://game/maps"):
			if f.get_extension() == "tscn":
				files.append("res://game/maps/" + f)
	for f in files:
		_migrate(f)
	quit()


func _migrate(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		print("%s: cannot read" % path)
		return
	if text.contains(MARK):
		print("%s: already done" % path)
		return
	var newline := "\r\n" if text.contains("\r\n") else "\n"
	var lines := Array(text.split(newline))

	# The scripts that are blocks, and the palette, by their ids in this file.
	var paths := {}   # id -> path
	var ext := RegEx.create_from_string("^\\[ext_resource .*path=\"([^\"]+)\".* id=\"([^\"]+)\"\\]")
	for line: String in lines:
		var m := ext.search(line)
		if m:
			paths[m.get_string(2)] = m.get_string(1)
	var table := {}
	var palette_use := RegEx.create_from_string("^palette = ExtResource\\(\"([^\"]+)\"\\)")
	for line: String in lines:
		var m := palette_use.search(line)
		if m:
			var palette := load(paths.get(m.get_string(1), "")) as MapPalette
			if palette:
				table = palette.breakable
			break

	var out := []
	var prop := RegEx.create_from_string("^(\\w+) = (.*)$")
	var ticked := 0
	var cleared := 0
	var i := 0
	var marked := false
	while i < lines.size():
		var line: String = lines[i]
		if not line.begins_with("[node "):
			out.append(line)
			i += 1
			continue
		# One node: its header and the lines up to the next section.
		var section := [line]
		i += 1
		while i < lines.size() and not (lines[i] as String).begins_with("["):
			section.append(lines[i])
			i += 1
		var props := {}
		for s: String in section:
			var m := prop.search(s)
			if m:
				props[m.get_string(1)] = m.get_string(2)
		var script: String = props.get("script", "")
		var is_block := false
		for id in paths:
			if paths[id] in BLOCK_SCRIPTS and script == "ExtResource(\"%s\")" % id:
				is_block = true
		var add := []
		if not marked and not line.contains(" parent="):
			add.append(MARK)
			marked = true
		if is_block:
			var breaks := _breaks(props, table)
			section = section.filter(func(s: String) -> bool: return not s.begins_with("breakable = ") and not s.begins_with("unbreakable = "))
			if breaks:
				add.append("breakable = true")
				ticked += 1
			elif props.has("breakable") or props.has("unbreakable"):
				cleared += 1
		# New lines go after the node's last line that is not blank.
		var last := section.size() - 1
		while last > 0 and (section[last] as String).strip_edges() == "":
			last -= 1
		for n in add.size():
			section.insert(last + 1 + n, add[n])
		out.append_array(section)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(newline.join(PackedStringArray(out)))
	file.close()
	print("%s: Breakable ticked on %d blocks, cleared on %d" % [path, ticked, cleared])


## Did a block with these saved settings break under the old rule?
func _breaks(props: Dictionary, table: Dictionary) -> bool:
	var old: String = props.get("breakable", "")
	if old == "1" or old == "true":
		return true
	if old == "2" or old == "false" or props.get("unbreakable", "") == "true":
		return false
	var kind: String = (props.get("kind", "\"concrete\"") as String).trim_prefix("\"").trim_suffix("\"")
	if not table.has(kind) or props.get("solid", "") == "false" or props.get("drawn", "") == "false":
		return false
	if props.get("shape", "0") != "0":
		return false
	var size := _numbers(props.get("size", "Vector3(1, 1, 1)"))
	var scale := Vector3.ONE
	if props.has("transform"):
		var t := _numbers(props["transform"])
		if t.size() == 12:
			scale = Vector3(Vector3(t[0], t[3], t[6]).length(), Vector3(t[1], t[4], t[7]).length(), Vector3(t[2], t[5], t[8]).length())
	if size.size() != 3:
		return false
	return MapDestruction.thin_enough(MapBlock.Shape.BOX, Vector3(size[0], size[1], size[2]) * scale)


## The numbers in "Vector3(1, 2.5, 3)" or "Transform3D(...)".
func _numbers(value: String) -> PackedFloat64Array:
	var inside := value.get_slice("(", 1).trim_suffix(")")
	var out := PackedFloat64Array()
	for part in inside.split(","):
		out.append(part.strip_edges().to_float())
	return out
