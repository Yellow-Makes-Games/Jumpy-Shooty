class_name BlockBreakable
extends RefCounted
## The ready-made ways a MapBlock can break: the choices in its "Break Settings"
## dropdown (shown when its Breakable is ticked). Nobody writes their own; to offer
## another, add a line to PRESETS.
##
## Each says how it breaks and how tough it is:
##  - mode "cell": a thin wall or floor is cut into ~2 m pieces that break one at a
##    time (shots punch holes). Only thin walls and floors can break this way.
##  - mode "whole": the block has one pool of health and goes all at once, whatever
##    its size or shape (crates, pillars, barricades). What rests on it stays put.
##  - health: the damage it takes, per piece or for the whole block. 0 = the kind's
##    toughness from the map's palette (or DEFAULT_HEALTH if the palette has none).
##    A pistol shot does 25, a rifle round 13.
## A block's own Break Health, if set, is used in place of the health here.

const DEFAULT_HEALTH := 100.0

## The one a block has until another is picked.
const DEFAULT := "Per Cell"

const PRESETS := {
	"Per Cell": {"mode": "cell", "health": 0.0},
	"Per Cell, Fragile": {"mode": "cell", "health": 25.0},
	"Per Cell, Tough": {"mode": "cell", "health": 300.0},
	"Whole Block": {"mode": "whole", "health": 0.0},
	"Whole Block, Fragile": {"mode": "whole", "health": 25.0},
	"Whole Block, Tough": {"mode": "whole", "health": 300.0},
}


## The choices, in the order the dropdown lists them.
static func names() -> PackedStringArray:
	return PackedStringArray(PRESETS.keys())


## "cell" or "whole". A name that is not in the list breaks like DEFAULT.
static func mode_of(preset: String) -> String:
	return PRESETS.get(preset, PRESETS[DEFAULT]).mode


## The health a preset gives, or 0 if it leaves that to the kind.
static func health_of(preset: String) -> float:
	return PRESETS.get(preset, PRESETS[DEFAULT]).health
