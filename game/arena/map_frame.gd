@tool
class_name MapFrame
extends Node3D
## A building that can come down (see MapCollapse): a frame of columns on a grid, with a
## floor at each level. Put one in a map with fine destruction, at the map's origin, and
## say where the frame is; the blocks under `parts` are the building. Blow out the
## columns under a bay (the square of floor between four columns) and that bay, and
## everything above it, falls.

## The parts of the map that are the building (its floors, walls, columns and what
## stands on them): only blocks under these can fall.
@export var parts: Array[NodePath] = []
## Where the lines of columns are, along x and along z (metres, in the map).
@export var lines_x := PackedFloat32Array()
@export var lines_z := PackedFloat32Array()
## The top of each floor, lowest first. The ground is not one: nothing on it falls.
@export var floor_tops := PackedFloat32Array()
## How far the floors reach out past the outermost lines of columns.
@export var overhang := 0.9
## How far below a floor's top what belongs to that floor starts (its slab, and what hangs under it).
@export var slab := 0.45
## The kind of block the columns are made of: tall blocks of it on the grid are the columns.
@export var column_kind := "concrete"
## What stands whatever happens (a lift core): a bay it stands in never falls.
@export var core := AABB()
## How much damage one storey of a column takes before it is blown out, and how hard a
## single hit has to be to do it any (small arms only mark it).
@export var column_health := 600.0
@export var column_armour := 60.0
