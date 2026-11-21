class_name Gtao
extends RefCounted
## GTAO ambient occlusion: a port of Intel's XeGTAO (see LICENSE.md here), the
## "GTAO" Ambient occlusion pick (GraphicsQuality).
##
## It is put on the picture the way ambient occlusion should be: worked out before the
## opaque pass, from the depth prepass, and taken by the map's own surface shader
## (map_surface.gdshader) as its AO, so it darkens only the ambient (sky and bounce)
## light, never the sun or a lamp, the way Godot's own SSAO does. Nothing multiplies
## the finished colour.
##
## Each frame, for each view of a map whose WorldEnvironment carries a GtaoEffect:
##  1. gtao_prefilter.glsl: depths as metres, with smaller copies (MIPs);
##  2. gtao_main.glsl, at half resolution: how open each pixel is to the sky (normals
##     come from the depth too, so the depth prepass need not write Godot's normal
##     buffer, as it must for SSAO);
##  3. gtao_denoise.glsl, twice: smooths the noise without blurring across edges;
##  4. gtao_upsample.glsl: back to full resolution, along surfaces, into the shared
##     texture below, which is then stamped as this view's.
## Then the opaque pass draws the map, which reads it.
##
## One texture for every view: a shader global ("gtao_ao", declared in project.godot)
## can only point at one texture, but a map can be drawn by several views in a frame
## (the game's view, each portal's, a killcam being saved), at different sizes, and some
## views run no GTAO at all (menu pictures in worlds of their own, maps without AO).
## So:
##  - "gtao_ao" is bigger than any view (it grows if one is bigger) and each view
##    writes its AO into its top-left corner; the shader reads it pixel for pixel
##    (FRAGCOORD), which is SCREEN_UV in this view's own pixels.
##  - "gtao_stamp" (one texel) says which view the AO is for: its size, and a flag. It
##    is set after the last GTAO pass, just before this view's opaque pass, and a second effect
##    (GtaoEffect, post-opaque) clears it just after. Views are drawn one after another
##    and the renderer keeps the GPU work in that order (each step waits for the one
##    before that touches the same texture), so the stamp is only ever set while the
##    view it was written for is drawing its opaque pass. Any other view (another size,
##    one without GTAO, a reflection probe, a later frame) finds it clear, or another
##    size, and the shader leaves AO at 1. A stale or mis-sized AO is never used.
##  - While "gtao_ao" is being swapped for a bigger one, no view stamps it.
##
## Robots (StandardMaterial3D) take no AO from this: they still darken the floor round
## them through the floor's own AO, but get no self-occlusion.
##
## Shared by every GtaoEffect (Gtao.shared()); it frees its GPU resources once the last
## one has gone (switching GTAO off). Per-view working textures live in each view's
## render buffers, so Godot frees them when the view is resized or freed.

## XeGTAO's quality: "low" (1 direction, 2 steps each way), "medium" (2, 2), "high"
## (3, 3), "ultra" (9, 3). At half resolution "high" costs under half what Godot's SSAO
## does at "On" (roughly 1.9 ms against 4 ms, depth resolve included, on a Ryzen 5
## 5600U's graphics at 1600x900, 2x MSAA), and its 18 samples a pixel keep the noise
## down. At full resolution "high" costs more than SSAO, "medium" a little less.
## (Read when the shared Gtao is made: set it before GTAO is switched on.)
static var quality := "high"
## Main pass and denoise at half resolution (a quarter of the pixels), then
## gtao_upsample.glsl fills in the rest along surfaces, so edges stay as sharp as the
## picture: no blocks (why the project turned down Godot's half-size SSAO).
static var half_res := true
## Edge-aware blur passes after the main pass (no TAA to smooth the noise over time).
const DENOISE_PASSES := 2

## XeGTAO's tuned constants (XeGTAO.h).
const RADIUS_MULTIPLIER := 1.457
const FALLOFF_RANGE := 0.615
const FINAL_VALUE_POWER := 2.2
const DEPTH_MIP_SAMPLING_OFFSET := 3.3
const DENOISE_BLUR_BETA := 1.2

## How a map's SSAO tuning carries over (see GtaoEffect.tune()): GTAO's radius is the
## map's ssao_radius times this (both are metres; XeGTAO multiplies it again by
## RADIUS_MULTIPLIER, and its falloff starts well inside the radius)...
const RADIUS_SCALE := 0.6
## ...and its strength is XeGTAO's final power scaled by ssao_intensity over Godot's
## default intensity (2): a map tuned softer than the default is softer here too.
const SSAO_DEFAULT_INTENSITY := 2.0

## Like Godot's SSAO (GraphicsQuality.apply_global): fades out from 50 m to 300 m.
const FADE_FROM := 50.0
const FADE_TO := 300.0

## Godot's depth correction (Projection.set_depth_correction(true, true, true)): flips y,
## and maps z -1..1 to depth 1..0.
const VULKAN_CORRECTION := Projection(Vector4(1, 0, 0, 0), Vector4(0, -1, 0, 0), Vector4(0, 0, -0.5, 0), Vector4(0, 0, 0.5, 1))

const CONTEXT := &"gtao"
const GLOBAL_AO := &"gtao_ao"
const GLOBAL_STAMP := &"gtao_stamp"

static var _current: WeakRef

var _rd: RenderingDevice
var _ready := false
var _sampler := RID()
var _shaders: Array[RID] = []
var _prefilter := RID()
var _prefilter_pipe := RID()
var _main := RID()
var _main_pipe := RID()
var _denoise := RID()
var _denoise_pipe := RID()
var _final := RID()
var _final_pipe := RID()
var _upsample := RID()
var _upsample_pipe := RID()
var _atlas := RID()
var _atlas_size := Vector2i.ZERO
var _stamp := RID()
## The atlas the "gtao_ao" global shows now (set on the main thread once it is bound).
var _bound := RID()
var _retired: Array[RID] = []
var _ao_tex: Texture2DRD
var _stamp_tex: Texture2DRD


## The one in use, made when the first GtaoEffect needs it.
static func shared() -> Gtao:
	var g: Gtao = _current.get_ref() if _current else null
	if g == null:
		g = Gtao.new()
		_current = weakref(g)
	return g


## Puts GTAO on (or takes it off) a map's WorldEnvironment: a GtaoEffect pair in its
## Compositor, which every view of that world runs. Any other effects in the Compositor
## stay. The effect takes the map's own SSAO tuning (radius, intensity).
static func use(world: WorldEnvironment, on: bool) -> void:
	var comp := world.compositor
	var effects: Array[CompositorEffect] = []
	var mine: Array[GtaoEffect] = []
	if comp:
		for e in comp.compositor_effects:
			if e is GtaoEffect:
				mine.append(e)
			else:
				effects.append(e)
	if on:
		if mine.is_empty():
			if comp == null:
				comp = Compositor.new()
				world.compositor = comp
				world.set_meta("gtao_compositor", true)   # ours: taken away again when off
			mine = [GtaoEffect.new(), GtaoEffect.new(true)]
			effects.append_array(mine)
			comp.compositor_effects = effects
		for e in mine:
			e.tune(world.environment)
	elif not mine.is_empty():
		comp.compositor_effects = effects
		if effects.is_empty() and world.get_meta("gtao_compositor", false):
			world.compositor = null
			world.remove_meta("gtao_compositor")


## Is GTAO on this WorldEnvironment?
static func is_on(world: WorldEnvironment) -> bool:
	if world.compositor == null:
		return false
	for e in world.compositor.compositor_effects:
		if e is GtaoEffect:
			return true
	return false


func _init() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return   # no RenderingDevice (a headless run, the Compatibility renderer): nothing to do
	var spirv := {
		"prefilter": (load("res://game/core/gtao/gtao_prefilter.glsl") as RDShaderFile).get_spirv(),
		"main": (load("res://game/core/gtao/gtao_main.glsl") as RDShaderFile).get_spirv(StringName(quality)),
		"denoise": (load("res://game/core/gtao/gtao_denoise.glsl") as RDShaderFile).get_spirv(&"pass"),
		"final": (load("res://game/core/gtao/gtao_denoise.glsl") as RDShaderFile).get_spirv(&"final"),
		"upsample": (load("res://game/core/gtao/gtao_upsample.glsl") as RDShaderFile).get_spirv(),
	}
	RenderingServer.call_on_render_thread(_create.bind(spirv, _start_size()))


## Big enough for a full-screen view on any screen, so it rarely has to grow.
static func _start_size() -> Vector2i:
	var s := Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless":
		for i in DisplayServer.get_screen_count():
			s = s.max(DisplayServer.screen_get_size(i))
	return s


func _create(spirv: Dictionary, size: Vector2i) -> void:
	for k in spirv:
		var err := (spirv[k] as RDShaderSPIRV).compile_error_compute
		if err != "":
			push_error("GTAO: the %s shader did not compile: %s" % [k, err])
			return
	var storage := RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	for f in [RenderingDevice.DATA_FORMAT_R8_UNORM, RenderingDevice.DATA_FORMAT_R16_SFLOAT, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT]:
		if not _rd.texture_is_format_supported_for_usage(f, storage):
			push_warning("GTAO: this graphics card cannot write a texture format it needs; GTAO is off")
			return
	_prefilter = _rd.shader_create_from_spirv(spirv.prefilter)
	_main = _rd.shader_create_from_spirv(spirv.main)
	_denoise = _rd.shader_create_from_spirv(spirv.denoise)
	_final = _rd.shader_create_from_spirv(spirv.final)
	_upsample = _rd.shader_create_from_spirv(spirv.upsample)
	_shaders = [_prefilter, _main, _denoise, _final, _upsample]
	_prefilter_pipe = _rd.compute_pipeline_create(_prefilter)
	_main_pipe = _rd.compute_pipeline_create(_main)
	_denoise_pipe = _rd.compute_pipeline_create(_denoise)
	_final_pipe = _rd.compute_pipeline_create(_final)
	_upsample_pipe = _rd.compute_pipeline_create(_upsample)
	var ss := RDSamplerState.new()
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _rd.sampler_create(ss)
	_atlas = _make_atlas(size)
	var tf := RDTextureFormat.new()
	tf.width = 1
	tf.height = 1
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.usage_bits = storage | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_stamp = _rd.texture_create(tf, RDTextureView.new())
	_rd.texture_clear(_stamp, Color(0, 0, 0, 0), 0, 1, 0, 1)
	_ready = true
	_bind.call_deferred()


func _make_atlas(size: Vector2i) -> RID:
	_atlas_size = size
	var tf := RDTextureFormat.new()
	tf.width = size.x
	tf.height = size.y
	tf.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	return _rd.texture_create(tf, RDTextureView.new())


## (Main thread.) Points the shader globals at the textures.
func _bind() -> void:
	if not _ready:
		return
	if _ao_tex == null:
		_ao_tex = Texture2DRD.new()
		_stamp_tex = Texture2DRD.new()
		_stamp_tex.texture_rd_rid = _stamp
		RenderingServer.global_shader_parameter_set(GLOBAL_STAMP, _stamp_tex)
	_ao_tex.texture_rd_rid = _atlas
	RenderingServer.global_shader_parameter_set(GLOBAL_AO, _ao_tex)
	_bound = _atlas
	if not _retired.is_empty():
		RenderingServer.call_on_render_thread(Gtao._free_rids.bind(_rd, _retired.duplicate(), []))
		_retired.clear()


## (Render thread.) A view bigger than the atlas: a bigger one, bound on the main
## thread after this frame. Until then no view stamps it (see render()).
func _grow(size: Vector2i) -> void:
	if _atlas != _bound:
		return   # already growing
	_retired.append(_atlas)
	_atlas = _make_atlas(size.max(_atlas_size))
	_bind.call_deferred()


## (Render thread, before the opaque pass.) GTAO for the view being drawn.
## `radius`: XeGTAO's effect radius, metres; `power`: its final value power.
func render(data: RenderData, radius: float, power: float) -> void:
	if not _ready:
		return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null or buffers.get_view_count() != 1:
		return
	var size := buffers.get_internal_size()
	if size.x < 8 or size.y < 8:
		return
	if size.x > _atlas_size.x or size.y > _atlas_size.y:
		_grow(size)
	if _atlas != _bound:
		return
	var proj := data.get_render_scene_data().get_cam_projection()
	if proj.is_orthogonal():
		return   # the depth maths here is for a perspective camera; the game has no other
	var stride := 2 if half_res else 1
	var work := (size + Vector2i(stride - 1, stride - 1)) / stride   # the AO's own size
	var ctx := StringName("%s_%d" % [CONTEXT, stride])
	_make_view_textures(buffers, ctx, size, work)

	var depth := buffers.get_depth_layer(0)
	var mips := buffers.get_texture(ctx, &"depth")
	var ao_a := buffers.get_texture(ctx, &"ao_a")
	var ao_b := buffers.get_texture(ctx, &"ao_b")
	var edges := buffers.get_texture(ctx, &"edges")

	# The projection as the GPU used it: Vulkan's clip space (y down) with reversed depth
	# (1 near, 0 far). Godot 4.7 hands it over like that already; an OpenGL-style one
	# (z -1..1, y up) is corrected the way Godot does it.
	if proj[2][2] < -0.5:
		proj = VULKAN_CORRECTION * proj
	# depth = p32 / distance - p22, so distance = -p32 / (-p22 - depth). Screen to view:
	# x = distance * (2u - 1 + p20) / p00, and the same for y with v. An off-centre
	# frustum (a portal's camera) has p20 and p21; a flipped y has a negative p11.
	var depth_unpack := Vector2(-proj[3][2], -proj[2][2])
	var px := Vector2(1.0 / size.x, 1.0 / size.y)
	var ndc_mul := Vector2(2.0 / proj[0][0], 2.0 / proj[1][1])
	var ndc_add := Vector2((proj[2][0] - 1.0) / proj[0][0], (proj[2][1] - 1.0) / proj[1][1])
	var effect_radius := radius * RADIUS_MULTIPLIER

	# 1. Depth MIPs (always at full resolution: the main pass samples them).
	var u: Array[RDUniform] = [_tex(0, depth)]
	for m in 5:
		u.append(_image(m + 1, buffers.get_texture_slice(ctx, &"depth", 0, m, 1, 1)))
	var pc := _push([size.x, size.y], [depth_unpack.x, depth_unpack.y, effect_radius, FALLOFF_RANGE, 0.0, 0.0])
	_dispatch(_prefilter, _prefilter_pipe, u, pc, Vector2i((size.x + 15) / 16, (size.y + 15) / 16))

	# 2. The main pass.
	u = [_tex(0, depth), _tex(1, mips), _image(2, ao_a), _image(3, edges)]
	pc = _push([size.x, size.y], [px.x, px.y, depth_unpack.x, depth_unpack.y, ndc_mul.x, ndc_mul.y, ndc_add.x, ndc_add.y,
		ndc_mul.x * px.x, ndc_mul.y * px.y, effect_radius, FALLOFF_RANGE, float(stride), 0.0,
		power, DEPTH_MIP_SAMPLING_OFFSET, FADE_FROM, FADE_TO])
	_dispatch(_main, _main_pipe, u, pc, Vector2i((work.x + 7) / 8, (work.y + 7) / 8))

	# 3. Denoise. At full resolution the last pass writes straight into the shared texture.
	var groups := Vector2i(((work.x + 1) / 2 + 7) / 8, (work.y + 7) / 8)
	pc = _push([work.x, work.y], [1.0 / work.x, 1.0 / work.y, DENOISE_BLUR_BETA, 0.0, 0.0, 0.0])
	var src := ao_a
	for i in DENOISE_PASSES - 1:
		var dst := ao_b if src == ao_a else ao_a
		_dispatch(_denoise, _denoise_pipe, [_tex(0, src), _tex(1, edges), _image(2, dst)], pc, groups)
		src = dst
	var last := _atlas if stride == 1 else (ao_b if src == ao_a else ao_a)
	_dispatch(_final, _final_pipe, [_tex(0, src), _tex(1, edges), _image(2, last)], pc, groups)

	# 4. At half resolution: every pixel, along surfaces, into the shared texture.
	if stride > 1:
		pc = _push([size.x, size.y, work.x, work.y], [0.0, 0.0, 0.0, 0.0])
		var depth0 := buffers.get_texture_slice(ctx, &"depth", 0, 0, 1, 1)
		_dispatch(_upsample, _upsample_pipe, [_tex(0, depth0), _tex(1, last), _image(2, _atlas)], pc, Vector2i((work.x + 7) / 8, (work.y + 7) / 8))

	# The stamp: the AO in the shared texture is this view's, until close_view().
	_rd.texture_update(_stamp, 0, PackedFloat32Array([size.x, size.y, 1.0, 0.0]).to_byte_array())


## (Render thread, after the opaque pass.) The AO is no longer for anyone.
func close_view() -> void:
	if _ready:
		_rd.texture_clear(_stamp, Color(0, 0, 0, 0), 0, 1, 0, 1)


## This view's working textures, in its own render buffers (Godot drops them when the
## view changes size, and they are made again here). `work`: the AO's size.
func _make_view_textures(buffers: RenderSceneBuffersRD, ctx: StringName, size: Vector2i, work: Vector2i) -> void:
	if buffers.has_texture(ctx, &"depth"):
		return
	var usage := RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var one := RenderingDevice.TEXTURE_SAMPLES_1
	buffers.create_texture(ctx, &"depth", RenderingDevice.DATA_FORMAT_R16_SFLOAT, usage, one, size, 1, 5, true, false)
	buffers.create_texture(ctx, &"ao_a", RenderingDevice.DATA_FORMAT_R8_UNORM, usage, one, work, 1, 1, true, false)
	buffers.create_texture(ctx, &"ao_b", RenderingDevice.DATA_FORMAT_R8_UNORM, usage, one, work, 1, 1, true, false)
	buffers.create_texture(ctx, &"edges", RenderingDevice.DATA_FORMAT_R8_UNORM, usage, one, work, 1, 1, true, false)


func _tex(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_sampler)
	u.add_id(tex)
	return u


func _image(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


## Push constants: some ints, then floats, padded to 16 bytes.
static func _push(ints: Array, floats: Array) -> PackedByteArray:
	var n := ints.size() + floats.size()
	var b := PackedByteArray()
	b.resize(ceili(n / 4.0) * 16)
	var at := 0
	for i in ints:
		b.encode_s32(at, int(i))
		at += 4
	for f in floats:
		b.encode_float(at, float(f))
		at += 4
	return b


func _dispatch(shader: RID, pipe: RID, uniforms: Array, pc: PackedByteArray, groups: Vector2i) -> void:
	var set := UniformSetCacheRD.get_cache(shader, 0, uniforms)
	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, pipe)
	_rd.compute_list_bind_uniform_set(cl, set, 0)
	_rd.compute_list_set_push_constant(cl, pc, pc.size())
	_rd.compute_list_dispatch(cl, groups.x, groups.y, 1)
	_rd.compute_list_end()


static func _free_rids(rd: RenderingDevice, textures: Array, others: Array) -> void:
	for r in textures:
		# (It may have gone already, with the Texture2DRD that showed it.)
		if r.is_valid() and rd.texture_is_valid(r):
			rd.free_rid(r)
	for r in others:
		if r.is_valid():
			rd.free_rid(r)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _rd == null:
		return
	# Off: the globals stop showing these textures before they go.
	if _ao_tex:
		RenderingServer.global_shader_parameter_set(GLOBAL_AO, null)
		RenderingServer.global_shader_parameter_set(GLOBAL_STAMP, null)
	_ao_tex = null
	_stamp_tex = null
	var textures: Array = _retired.duplicate()
	textures.append_array([_atlas, _stamp])
	var others: Array = [_sampler]
	others.append_array(_shaders)   # (freeing a shader frees its pipeline)
	RenderingServer.call_on_render_thread(Gtao._free_rids.bind(_rd, textures, others))
