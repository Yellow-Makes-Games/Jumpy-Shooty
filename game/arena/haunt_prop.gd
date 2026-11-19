@tool
class_name HauntProp
extends MapIsland
## A piece of a haunted house that will not keep still (the Haunted House). Put MapBlocks
## under it like under any group: in the game they become one body that the map's
## HauntEvent moves, carrying whoever stands on it (a MapIsland underneath).
##
## Three things it can do, all of them worked out from the HauntEvent's clock alone, so
## it is in the same place on every copy of the game, also for someone who joins late:
##  - Float: it bobs up and down (Bob metres, once every Bob Period seconds), sways to
##    and fro about its own y axis (Sway degrees) or keeps turning (Twirl degrees a
##    second: for drawn-only things, books circling a reading lamp).
##  - Shift: the house has a few layouts (the HauntEvent's Layouts). For each one, Moves
##    says where it stands then (metres from where the scene has it) and Turns how far it
##    is turned (degrees, anticlockwise seen from above, about its own origin). When the
##    house shifts it glides from one to the next. Left empty: it stays home.
##  - Vanish: Shown says, for each layout, whether it is there (1) or gone (0). A
##    doorway that comes and goes is a wall panel (Door ticked) that fills the hole:
##    when it is gone the doorway is open; when it comes back it fades in, turns solid
##    only once it is all there, and puts whoever stands in it out on the nearer side.
## A layout past the end of a list uses the list from the start again (layout % size).

@export_group("Float")
## Metres it rises and falls (0: it does not bob).
@export var bob := 0.0
## Seconds for one bob up and down.
@export var bob_period := 5.0
## 0..1: where in its bob (and sway) it starts, so neighbours are out of step.
@export_range(0.0, 1.0) var bob_phase := 0.0
## Degrees it turns to and fro about its own y axis while it floats.
@export var sway := 0.0
## Degrees a second it keeps turning about its own y axis (keep this for drawn-only things).
@export var twirl := 0.0

# (Typed arrays, not packed ones: an export drops a packed array from a scene node whose
# script is not a @tool script, and keeps a typed one. See docs/DEVELOPMENT.md.)
@export_group("Layouts")
## For each layout: metres from where the scene has it.
@export var moves: Array[Vector3] = []
## For each layout: degrees it is turned about its own origin.
@export var turns: Array[float] = []
## For each layout: 1 there, 0 gone.
@export var shown: Array[int] = []
## A panel that seals a doorway: whoever stands in it when it comes back is put out of it.
@export var door := false

## Where the haunting has it just now: a turn about its own origin (in the map's frame)
## and a shift from its home. The HauntEvent sets this.
var haunt := Transform3D.IDENTITY
## 0..1: how much of it is there (the HauntEvent sets it through set_presence()).
var presence := 1.0
## Is it solid just now (also false while it is fading in or out)?
var solid_now := true

var _fade_mats := {}   # MeshInstance3D -> its own see-through material


func offset_at(_t: float) -> Transform3D:
	var base := _base_xf()
	var at := Transform3D(haunt.basis * base.basis, base.origin + haunt.origin)
	return base.affine_inverse() * at


## Where it stands in layout `layout`: (metres from home, degrees turned).
func spot(layout: int) -> Vector3:
	return moves[posmod(layout, moves.size())] if not moves.is_empty() else Vector3.ZERO


func turn(layout: int) -> float:
	return turns[posmod(layout, turns.size())] if not turns.is_empty() else 0.0


func is_shown(layout: int) -> bool:
	return shown.is_empty() or shown[posmod(layout, shown.size())] != 0


## Does it go anywhere, turn, or come and go, between layout `a` and layout `b`?
func changes(a: int, b: int) -> bool:
	return not spot(a).is_equal_approx(spot(b)) or not is_equal_approx(turn(a), turn(b)) or is_shown(a) != is_shown(b)


## Does it ever move, turn or vanish?
func shifts() -> bool:
	return not moves.is_empty() or not turns.is_empty() or not shown.is_empty()


## How much of it is there (0..1) and whether it is solid. Partly there, it is drawn see
## through with a pale glow, and is never solid.
func set_presence(amount: float, solid: bool) -> void:
	amount = clampf(amount, 0.0, 1.0)
	solid = solid and amount >= 0.999
	if _body == null:
		presence = amount
		solid_now = solid
		return
	if is_equal_approx(amount, presence) and solid == solid_now and (amount < 0.999) == not _fade_mats.is_empty():
		return
	presence = amount
	solid_now = solid
	_body.visible = amount > 0.004
	if _body is CollisionObject3D:
		(_body as CollisionObject3D).collision_layer = 1 if solid else 0
	var map := MapRoot.of(self)
	for child in _body.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.has_meta("kind"):
			continue
		var kind: String = mesh.get_meta("kind")
		if amount >= 0.999:
			if _fade_mats.has(mesh):
				mesh.material_override = map.riding_material_for(kind) if map else null
			continue
		if not _fade_mats.has(mesh):
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.55, 0.85, 1.0)
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_fade_mats[mesh] = mat
			mesh.material_override = mat
		var own: StandardMaterial3D = _fade_mats[mesh]
		var col: Color = map.palette.colors.get(kind, Color.WHITE) if map and map.palette else Color.WHITE
		col = col.lerp(Color(0.7, 0.9, 1.0), 0.45 * (1.0 - amount))
		col.a = amount * 0.85
		own.albedo_color = col
		own.emission_energy_multiplier = 0.9 * (1.0 - amount) + 0.1
	if amount >= 0.999:
		_fade_mats.clear()


## The box a door panel fills, in the map's frame (its solid blocks, at home): the
## HauntEvent puts anyone inside it out of it.
func door_box() -> AABB:
	var map := MapRoot.of(self)
	if map == null:
		return AABB()
	for m in map.movers:
		if m.node == self:
			return _base_xf() * (m.bounds as AABB)
	return AABB()
