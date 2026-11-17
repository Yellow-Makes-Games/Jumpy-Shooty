@tool
class_name MapHazard
extends MapBlock
## A block that sends racers back to their last checkpoint when they touch it:
## molten metal, live wires, energy beams (race maps). It is drawn like any block
## (pick a glowing kind from the palette); untick Solid (the usual case) so racers
## sink into it rather than stand on it. Put it inside a MapMover to make it move.
