@tool
class_name MapRoutePoint
extends Marker3D
## One step of the route bots take round a race course (race maps). Put them, in
## running order, under a node called "BotRoute". A bot runs to each point in turn,
## and when it gets there it does the point's Action on its way to the next point.
## The blue figure is only shown in the editor; the line joins it to the next point.

enum Action {
	RUN,         ## just run on to the next point
	JUMP,        ## jump here (a gap, onto something)
	LONG_JUMP,   ## jump, then flip forward at the top for extra distance
	DIVE_JUMP,   ## jump, then dive at the top (longest)
	FLIP_DIVE,   ## jump, flip, then dive (the very longest gaps)
	SLIDE,       ## slide from here until the next point
	CRAWL,       ## dive onto its belly here and slide / crawl until the next point
	WALL_RUN,    ## jump toward the next point, which is along a wall: it wall-runs there
	WALL_JUMP,   ## kick off the wall it is running on, toward the next point
	CHIMNEY,     ## wall-jump up between two close walls until it is level with the next point
	GRAPPLE,     ## hook the spot at Aim (from this point) and swing toward the next point
	WAIT_GROUND, ## wait until there is something to stand on at Aim (a moving platform), then jump
	WAIT_CLEAR,  ## wait until no hazard is near Aim (a press, a sweeper), then run on
	WALK,        ## go to the next point without sprinting (careful footing)
	BOOST_JUMP,  ## jump, then fire the rocket boots forward (tipped up): gaps too long for any jump
	BOOST_UP,    ## jump at a high wall, fire the boots upward and climb onto the ledge at the next point
	FLOAT_JUMP,  ## jump, then float (Shift) at the top of the jump toward the next point
}

@export var action := Action.RUN:
	set(v):
		action = v
		update_gizmos()
## GRAPPLE: the spot to hook. WAIT_GROUND / WAIT_CLEAR: the spot to watch. From this point.
@export var aim := Vector3.ZERO:
	set(v):
		aim = v
		update_gizmos()
## How close (flat) the bot must get for this point to count as reached.
@export var radius := 1.2
## Also fire the rocket boots toward the next point: GRAPPLE (as it lets go of the
## rope) and FLOAT_JUMP (while floating, which sends the float on much faster).
@export var boost := false

var _figure: MeshInstance3D


func _enter_tree() -> void:
	if not Engine.is_editor_hint() or _figure != null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 0.6
	_figure = MeshInstance3D.new()
	_figure.mesh = s
	_figure.position.y = 0.3
	_figure.material_override = mat
	add_child(_figure, false, Node.INTERNAL_MODE_FRONT)
