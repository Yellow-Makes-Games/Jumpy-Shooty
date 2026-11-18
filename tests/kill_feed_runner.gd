extends Node
## Kill feed icons and the death screen's "how" (see tests/kill_feed_test.gd).
## Started by tests/kill_feed_test.gd (this is a Node, so it can use the autoloads).

var _fails: Array[String] = []
var _drawn := false


func run() -> void:
	# Draw every icon on a real canvas item, the way the feed does.
	var canvas := Control.new()
	canvas.size = Vector2(400, 100)
	canvas.draw.connect(_draw_icons.bind(canvas))
	add_child(canvas)
	canvas.queue_redraw()
	for i in 5:
		await get_tree().process_frame
	_check(_drawn, "every icon drew to the end (no errors)")

	# How the death screen tells it.
	var cases := [
		["kick", "kick", "Kick"],
		["flying_kick", "kick", "Flying kick"],
		["kick", "slam", "Kicked into a wall"],
		["flying_kick", "slam", "Kicked into a wall"],
		["rope", "slam", "Reeled into a wall"],
		["rocket_launcher", "slam", "Rocket Launcher into a wall"],
		["", "slam", "Smashed into a wall"],
		["shotgun", "", "Shotgun"],
		["none", "", "Bare feet"],
	]
	for c in cases:
		var said := Hud.death_how(c[0], c[1])
		_check(said == c[2], "death screen, %s (%s): \"%s\" (got \"%s\")" % [c[0], c[1], c[2], said])

	if _fails.is_empty():
		print("PASS kill feed icons and the death screen's how")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _draw_icons(ci: Control) -> void:
	var x := 0.0
	for with in ["kick", "flying_kick", "rope", "none", "rocket_launcher"]:
		var want := HudStyle.kill_icon_width(with)
		var got := HudStyle.kill_icon(ci, with, Vector2(x, 40), Color.WHITE, 1.0)
		_check(got > 10.0, "%s: an icon with a width (%.1f)" % [with, got])
		_check(absf(got - want) < 1.5, "%s: drawn as wide as the feed makes room for (%.1f, room %.1f)" % [with, got, want])
		x += got + 8.0
	# The new icons, at the feed's size too: as wide as their stated widths.
	for s in [1.0, 1.1]:
		for icon in [["the wall", HudStyle.wall_impact, HudStyle.WALL_W], ["the flying kick", HudStyle.flying_kick, HudStyle.FLYING_KICK_W],
				["the hook", HudStyle.grapple_hook, HudStyle.HOOK_W]]:
			var got: float = (icon[1] as Callable).call(ci, Vector2(x, 40), Color.WHITE, s)
			_check(absf(got - icon[2] * s) < 1.0, "%s: %.1f wide at size %.1f (stated %.1f)" % [icon[0], got, s, icon[2] * s])
			x += got + 8.0
	_check(HudStyle.kill_icon_width("kick") == HudStyle.weapon_width("none"), "a kick is the boot")
	_drawn = true


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print(("  ok    " if ok else "  FAIL  ") + what)
