@tool
class_name MapGrapplePoint
extends Marker3D
## A spot the grappling hook snaps to. Press grapple while your crosshair is close to
## one (within Magnet degrees) and within Reach of it, and the hook catches the point
## itself, even if you weren't aiming exactly at it. It needs nothing solid behind
## it: hang one in open air to make a swing. Something solid between you and the
## point blocks it. The glowing ball is drawn in the game too, so players see it.

const GROUP := "grapple_points"

## How far away (metres, from your eyes) the hook can catch this point.
@export var reach := 55.0
## How far off the crosshair (degrees) you can aim and still snap to it.
@export var magnet := 8.0

var _ring: MeshInstance3D


func _enter_tree() -> void:
	add_to_group(GROUP)
	if _ring != null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.95, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.95, 0.85)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ball := SphereMesh.new()
	ball.radius = 0.35
	ball.height = 0.7
	_ring = MeshInstance3D.new()
	_ring.mesh = ball
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring, false, Node.INTERNAL_MODE_FRONT)


## The best grapple point for an aim ray, or null: the one closest to the crosshair
## (in angle) that is in reach, inside its magnet cone and not blocked.
static func pick(tree: SceneTree, space: PhysicsDirectSpaceState3D, eye: Vector3, from: Vector3,
		dir: Vector3, exclude: Array) -> MapGrapplePoint:
	var best: MapGrapplePoint = null
	var best_angle := INF
	for n in tree.get_nodes_in_group(GROUP):
		var p := n as MapGrapplePoint
		if p == null or not p.is_visible_in_tree():
			continue
		var at := p.global_position
		if eye.distance_to(at) > p.reach:
			continue
		var angle := rad_to_deg(dir.angle_to(at - from))
		if angle > p.magnet or angle >= best_angle:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, at, 1, exclude)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit.position.distance_to(at) > 0.3:
			continue   # a wall in the way
		best = p
		best_angle = angle
	return best
