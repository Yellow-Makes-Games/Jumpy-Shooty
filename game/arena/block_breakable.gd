@tool
class_name BlockBreakable
extends Resource
## How one MapBlock breaks, when its Breakable is set to Yes (or Default with a
## breakable kind). Attach one to a block's "Break Settings"; leave it empty to use
## the kind's numbers from the palette, broken cell by cell.
##
## Several blocks can share one of these (save it as a .tres): change it once and
## they all change. New break settings go here, not on MapBlock.

enum Mode { PER_CELL, WHOLE_BLOCK }

## How much damage it takes to break. 0 = the kind's toughness from the palette
## (or DEFAULT_HEALTH if the palette has none). A pistol shot does 25, a rifle round 13.
## Per cell: each ~2 m piece has this much. Whole block: the whole block has this much.
@export_range(0.0, 5000.0, 1.0, "or_greater") var block_health := 0.0:
	set(v):
		block_health = maxf(v, 0.0)
		emit_changed()

## Per cell: a thin wall or floor is cut into ~2 m pieces that break one at a time
## (shots punch holes). Only thin walls and floors can break this way.
## Whole block: the block has one pool of health and goes all at once, whatever
## its size or shape (crates, pillars, barricades). Whatever rests on it stays where
## it is.
@export var break_mode := Mode.PER_CELL:
	set(v):
		break_mode = v
		emit_changed()

const DEFAULT_HEALTH := 100.0
const MODE_NAMES := ["cell", "whole"]


## The health to use, given the kind's toughness from the palette (0 if none).
func health_for(kind_toughness: float) -> float:
	if block_health > 0.0:
		return block_health
	return kind_toughness if kind_toughness > 0.0 else DEFAULT_HEALTH
