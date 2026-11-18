@tool
class_name MapHazard
extends MapBlock
## A block that is deadly to touch: molten metal, live wires, energy beams, a
## reactor core. It is drawn like any block (pick a glowing kind from the palette);
## untick Solid (the usual case) so players sink into it rather than stand on it.
##
## In a race it sends the racer back to their last checkpoint (see Race). In an arena
## touching it is a death, handled exactly like falling out of the map (the arena's own
## check: see Arena._physics_process). A box or an upright round shape; in a race map,
## put it inside a MapMover to make it move.
