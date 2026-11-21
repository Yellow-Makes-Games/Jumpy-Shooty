class_name GtaoEffect
extends CompositorEffect
## GTAO on a map's WorldEnvironment (see Gtao, which does the work). Comes in a pair:
## the opening effect runs GTAO just before the opaque pass, so the map's surfaces can
## read it while they are drawn; the closing one (`closing`) runs just after and clears
## the stamp, so no other view can mistake this view's AO for its own.

## XeGTAO's effect radius before its multiplier (metres) and final value power: set from
## the map's SSAO tuning by tune().
var radius := Gtao.RADIUS_SCALE
var power := Gtao.FINAL_VALUE_POWER
var closing := false
var _gtao: Gtao


func _init(close: bool = false) -> void:
	closing = close
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE if close else EFFECT_CALLBACK_TYPE_PRE_OPAQUE
	# With MSAA the depth prepass is multisampled: this has Godot resolve it first.
	access_resolved_depth = not close
	_gtao = Gtao.shared()


## Takes the map's own SSAO tuning across. ssao_radius is metres, as GTAO's radius is,
## but GTAO's falloff starts inside its radius and XeGTAO multiplies it up (see
## Gtao.RADIUS_SCALE). ssao_intensity scales the strength (XeGTAO's final power) against
## Godot's default intensity, so a map tuned lighter or darker than the default stays so.
func tune(env: Environment) -> void:
	if env == null:
		return
	radius = env.ssao_radius * Gtao.RADIUS_SCALE
	power = Gtao.FINAL_VALUE_POWER * env.ssao_intensity / Gtao.SSAO_DEFAULT_INTENSITY


func _render_callback(type: int, data: RenderData) -> void:
	if type == EFFECT_CALLBACK_TYPE_PRE_OPAQUE:
		_gtao.render(data, radius, power)
	elif type == EFFECT_CALLBACK_TYPE_POST_OPAQUE:
		_gtao.close_view()
