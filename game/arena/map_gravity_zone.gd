@tool
class_name MapGravityZone
extends Node3D
## A part of a map with its own gravity: a box, or a round shape standing on the
## node's own y axis (a cylinder, or with Top under 1 a cone cut off flat, for a tower
## that tapers). Inside it, players' gravity is Gravity times normal; everywhere no
## zone covers it is the MapRoot's Gravity Outside. Where zones overlap, the one
## higher in the scene tree decides.
##
## Empyrean Tower uses them the simple way round: Gravity Outside is 0.4 and a zone
## with Gravity 1.0 fills the tower, so the open sky needs no boxes at all. Its
## force-field doorways stand on the zone's edge, which is where the change begins.
##
## Nothing is drawn in the game and nothing is solid: it is only a volume. A body's
## gravity eases from one zone's to the next over WorldGravity.BLEND_TIME (1 s). It
## changes players only (see WorldGravity), never projectiles. The blue outline is
## editor-only.

enum Shape { BOX, ROUND }

@export var shape := Shape.BOX:
	set(v):
		shape = v
		_refresh_ghost()
## Box: width (x), height (y), depth (z). Round: the diameter at its foot (x) and its
## height (y); z is not used.
@export var size := Vector3(10, 10, 10):
	set(v):
		size = v.max(Vector3(0.01, 0.01, 0.01))
		_refresh_ghost()
## Round only: the diameter at the top, as a share of the foot's (1 = a cylinder).
@export_range(0.0, 1.0) var top := 1.0:
	set(v):
		top = v
		_refresh_ghost()
## Gravity inside, as a share of normal (1 = normal, 0.4 = a jump goes 2.5 times as high).
@export_range(0.05, 2.0) var gravity := 1.0

var _ghost: MeshInstance3D


func _enter_tree() -> void:
	_refresh_ghost()


## This zone for WorldGravity, with `xf` where it sits in the map.
func to_zone(xf: Transform3D) -> Dictionary:
	var s := xf.basis.get_scale().abs()
	return {
		"inv": Transform3D(xf.basis.orthonormalized(), xf.origin).affine_inverse(),
		"half": size * s * 0.5, "round": shape == Shape.ROUND, "top": top, "scale": gravity,
	}


func _refresh_ghost() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _ghost == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.55, 1.0, 0.08)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost = MeshInstance3D.new()
		_ghost.material_override = mat
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ghost, false, Node.INTERNAL_MODE_FRONT)
	if shape == Shape.ROUND:
		var c := CylinderMesh.new()
		c.bottom_radius = size.x * 0.5
		c.top_radius = size.x * 0.5 * top
		c.height = size.y
		c.radial_segments = 32
		c.rings = 1
		_ghost.mesh = c
	else:
		var b := BoxMesh.new()
		b.size = size
		_ghost.mesh = b
