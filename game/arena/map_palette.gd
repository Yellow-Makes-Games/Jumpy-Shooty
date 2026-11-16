@tool
class_name MapPalette
extends Resource
## The colours a map is painted with. Every MapBlock names a "kind" (concrete,
## steel, plank...), and the kind's colour comes from here. Change a colour and
## every block of that kind changes with it, in the editor and in the game.

## kind -> colour.
@export var colors: Dictionary[String, Color] = {}:
	set(v):
		colors = v
		emit_changed()

## kind -> how brightly it shines (0 = not at all). For lamp faces and lit signs.
@export var glow: Dictionary[String, float] = {}:
	set(v):
		glow = v
		emit_changed()

## How rough (matte) every surface is: 1 = no shine at all.
@export_range(0.0, 1.0) var roughness := 0.85:
	set(v):
		roughness = v
		emit_changed()
