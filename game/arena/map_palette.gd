@tool
class_name MapPalette
extends Resource
## The colours a map is painted with. Every MapBlock names a "kind" (concrete,
## steel, plank...), and the kind's colour comes from here. Change a colour and
## every block of that kind changes with it, in the editor and in the game.

## kind -> colour. An alpha below 1 makes the kind see-through (glass you look out of).
@export var colors: Dictionary[String, Color] = {}:
	set(v):
		colors = v
		emit_changed()

## kind -> how brightly it shines (0 = not at all). For lamp faces and lit signs.
@export var glow: Dictionary[String, float] = {}:
	set(v):
		glow = v
		emit_changed()

## kind -> a pattern drawn on every surface of that kind, with no extra blocks: panel
## seams on walls, tiles on floors, grating, hazard stripes... (the names are in
## MapScenery.SURFACES). Leave a kind out and it is one flat colour. Not for kinds
## that glow or are see-through.
@export var surface: Dictionary[String, String] = {}:
	set(v):
		surface = v
		emit_changed()

## How rough (matte) every surface is: 1 = no shine at all.
@export_range(0.0, 1.0) var roughness := 0.85:
	set(v):
		roughness = v
		emit_changed()

## kind -> how much damage a piece of it (about 2 m square) takes to break. Only thin
## walls and floors of these kinds break, and only in arena matches (see
## MapDestruction). A pistol shot does 25, a rifle round 13; leave a kind out and
## it never breaks. Below 50 (glass) a whole pane shatters at once.
@export var breakable: Dictionary[String, float] = {}:
	set(v):
		breakable = v
		emit_changed()

## kind -> what it is made of (the names are in BlockMaterials.TABLE: concrete,
## metal, wood, glass...): its footsteps and how it breaks. Leave a kind out and it
## is guessed from the kind's name. A block's own Material Type wins over this.
@export var material: Dictionary[String, String] = {}:
	set(v):
		material = v
		emit_changed()
