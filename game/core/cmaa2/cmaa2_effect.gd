class_name Cmaa2Effect
extends CompositorEffect
## Intel's CMAA2 (Conservative Morphological Anti-Aliasing 2) as a compositor effect: the
## "CMAA2" Screen-space AA setting (see GraphicsQuality.use_cmaa2, which puts one on each
## viewport's world that wants it).
##
## CMAA2 looks for the stair-steps along hard edges and blends only those pixels, along
## the edge's own direction, so it smooths geometry about as well as SMAA while leaving
## everything else (textures, text, the HUD's lines) as sharp as it was. FXAA softens the
## whole picture a little instead.
##
## It runs after transparent things are drawn and before tonemapping, on the 3D picture at
## its render resolution (before FSR stretches it), in linear HDR colour: so the shader
## (cmaa2.glsl, ported from Intel's reference) keeps the full HDR range in what it stores.
## With MSAA on, Godot resolves the samples first (access_resolved_color) and this works on
## the resolved picture, which is what the tonemapper reads next. The picture is changed in
## place, only where an edge is blended, as the original does: the colour buffer can be
## sampled and written as a storage image, so no copy of it is needed.
##
## Four compute passes, as in the original: find the edges (and the pixels that may be on a
## stair-step), work out each candidate's blend, then put the blended colours back. A small
## fourth pass between them sizes the last two on the GPU (indirect dispatch) from what the
## one before found, so the CPU never waits to read the counts back.
##
## The working buffers are made for one picture size and made again when it changes (a
## window resize, the render scale). Everything is freed with the effect: when the setting
## goes off, GraphicsQuality drops the effect and with it its GPU memory.

const SHADER_FILE := preload("res://game/core/cmaa2/cmaa2.glsl")
const PASSES := ["edges", "args", "process", "apply"]
enum { EDGES, ARGS, PROCESS, APPLY }

const EDGE_KERNEL := 14 * 2                ## pixels each edge-pass group finishes, a side (16 threads less a border, 2x2 pixels each)
const COLOR_FORMAT := RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT   ## Forward+'s HDR colour buffer
const EMPTY_HEAD := 0xFF                   ## every byte of an empty list head (0xFFFFFFFF)

## How many frames it has worked on, and the picture size it has buffers for (for tests).
var frames := 0
var buffer_size := Vector2i.ZERO

var _rd: RenderingDevice
var _shaders: Array[RID] = []
var _pipelines: Array[RID] = []
var _sampler := RID()
var _failed := false

var _edges := RID()          # 4 bits a pixel (2 pixels a byte): which sides have an edge
var _candidates := RID()     # pixels that may be on a stair-step
var _locations := RID()      # 2x2 quads with blended colours waiting
var _items := RID()          # the blended colours, a linked list per quad
var _heads := RID()          # each quad's list head
var _control := RID()        # counters
var _indirect := RID()       # the indirect dispatch's group counts
var _lengths := Vector3i.ZERO   # entries in _candidates, _locations and _items


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true


## Everything it made, freed by the RenderingDevice that made it, on the render thread
## (RenderingServer.free_rid does not free a RenderingDevice's own RIDs: they would leak,
## and Godot crashes on quitting with them still there). A resource being freed cannot
## call its own methods, so the freeing is a static function.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		var rids: Array[RID] = [_edges, _candidates, _locations, _items, _heads, _control, _indirect, _sampler]
		rids.append_array(_shaders)   # (a shader takes its pipeline with it)
		RenderingServer.call_on_render_thread(Cmaa2Effect._free_rids.bind(_rd, rids))


static func _free_rids(rd: RenderingDevice, rids: Array[RID]) -> void:
	for rid in rids:
		if rid.is_valid():
			rd.free_rid(rid)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or _failed:
		return
	var scene_buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if scene_buffers == null:
		return
	var size := scene_buffers.get_internal_size()
	if size.x < 2 or size.y < 2:
		return
	if _shaders.is_empty() and not _make_shaders():
		return
	if size != buffer_size:
		_free_buffers()
		if not _make_buffers(size):
			return
	var push := PackedInt32Array([size.x, size.y, (size.x + 1) / 2, _lengths.x, _lengths.y, _lengths.z, 0, 0]).to_byte_array()
	for view in scene_buffers.get_view_count():
		var color := scene_buffers.get_color_layer(view)
		if frames == 0 and not _color_ok(color):
			return
		_run(color, size, push)
	frames += 1


## The four passes on one view's colour image.
func _run(color: RID, size: Vector2i, push: PackedByteArray) -> void:
	var color_read := _uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 0, [_sampler, color])
	var color_write := _uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 1, [color])
	var edges := _uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 2, [_edges])
	var candidates := _buffer_uniform(3, _candidates)
	var locations := _buffer_uniform(4, _locations)
	var items := _buffer_uniform(5, _items)
	var heads := _buffer_uniform(6, _heads)
	var control := _buffer_uniform(7, _control)
	var indirect := _buffer_uniform(8, _indirect)
	var sets := [
		UniformSetCacheRD.get_cache(_shaders[EDGES], 0, [color_read, edges, candidates, heads, control]),
		UniformSetCacheRD.get_cache(_shaders[ARGS], 0, [candidates, locations, control, indirect]),
		UniformSetCacheRD.get_cache(_shaders[PROCESS], 0, [color_read, edges, candidates, locations, items, heads, control]),
		UniformSetCacheRD.get_cache(_shaders[APPLY], 0, [color_write, locations, items, heads, control]),
	]
	# Each pass is its own compute list, so Godot puts the barriers between them (the
	# indirect dispatches read what the pass before wrote as their group counts).
	# 1. Edges, and the candidates for blending.
	_dispatch(EDGES, sets, push, Vector3i((size.x + EDGE_KERNEL - 1) / EDGE_KERNEL, (size.y + EDGE_KERNEL - 1) / EDGE_KERNEL, 1))
	# 2. Groups for the candidates.
	_dispatch(ARGS, sets, push, Vector3i(2, 1, 1))
	# 3. Each candidate's blends.
	_dispatch(PROCESS, sets, push)
	# 4. Groups for the quads with blends (and the counters reset for next time).
	_dispatch(ARGS, sets, push, Vector3i(1, 2, 1))
	# 5. The blended colours back into the picture.
	_dispatch(APPLY, sets, push)


## One pass: `groups`, or (left out) as many as the indirect buffer says.
func _dispatch(pass_id: int, sets: Array, push: PackedByteArray, groups := Vector3i.ZERO) -> void:
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipelines[pass_id])
	_rd.compute_list_bind_uniform_set(list, sets[pass_id], 0)
	_rd.compute_list_set_push_constant(list, push, push.size())
	if groups == Vector3i.ZERO:
		_rd.compute_list_dispatch_indirect(list, _indirect, 0)
	else:
		_rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
	_rd.compute_list_end()


func _uniform(type: int, binding: int, ids: Array) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = type
	u.binding = binding
	for id in ids:
		u.add_id(id)
	return u


func _buffer_uniform(binding: int, buffer: RID) -> RDUniform:
	return _uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, binding, [buffer])


## The shaders, their pipelines and the sampler (once, on the render thread).
func _make_shaders() -> bool:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return _fail("no RenderingDevice (CMAA2 needs Forward+ or Mobile)")
	if not _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R8_UINT, RenderingDevice.TEXTURE_USAGE_STORAGE_BIT):
		return _fail("this GPU cannot write R8_UINT storage images")
	for pass_name in PASSES:
		var spirv: RDShaderSPIRV = SHADER_FILE.get_spirv(pass_name)
		if spirv == null or spirv.compile_error_compute != "":
			return _fail("the %s shader did not compile: %s" % [pass_name, spirv.compile_error_compute if spirv else "missing"])
		var shader := _rd.shader_create_from_spirv(spirv, "CMAA2 " + pass_name)
		if not shader.is_valid():
			return _fail("could not make the %s shader" % pass_name)
		_shaders.append(shader)
		_pipelines.append(_rd.compute_pipeline_create(shader))
	var state := RDSamplerState.new()   # (only texelFetch reads it: no filtering)
	state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _rd.sampler_create(state)
	return true


## The colour image is what the shaders expect: an RGBA16F image they can sample and write.
func _color_ok(color: RID) -> bool:
	var format := _rd.texture_get_format(color)
	if format == null:
		return _fail("could not read the colour buffer's format")
	var need := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	if format.format != COLOR_FORMAT or (format.usage_bits & need) != need:
		return _fail("the colour buffer is format %d, usage %d: not an RGBA16F storage image" % [format.format, format.usage_bits])
	return true


## The working buffers for a picture this size. The sizes are the original's "99.99% safe"
## ones: in the rare frame that needs more, some edges are left as they are.
func _make_buffers(size: Vector2i) -> bool:
	var pixels := size.x * size.y
	var edge_format := RDTextureFormat.new()
	edge_format.format = RenderingDevice.DATA_FORMAT_R8_UINT
	edge_format.width = (size.x + 1) / 2
	edge_format.height = size.y
	edge_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	_edges = _rd.texture_create(edge_format, RDTextureView.new())
	_lengths = Vector3i(maxi(pixels / 4, 1), maxi((pixels + 3) / 6, 1), maxi(pixels / 2, 1))
	_candidates = _rd.storage_buffer_create(_lengths.x * 4)
	_locations = _rd.storage_buffer_create(_lengths.y * 4)
	_items = _rd.storage_buffer_create(_lengths.z * 3 * 4)   # 3 uints an item: next, rg, ba
	var heads := PackedByteArray()
	heads.resize(((size.x + 1) / 2) * ((size.y + 1) / 2) * 4)
	heads.fill(EMPTY_HEAD)
	_heads = _rd.storage_buffer_create(heads.size(), heads)
	var zeros := PackedByteArray()
	zeros.resize(16 * 4)
	_control = _rd.storage_buffer_create(zeros.size(), zeros)
	_indirect = _rd.storage_buffer_create(16, PackedByteArray(), RenderingDevice.STORAGE_BUFFER_USAGE_DISPATCH_INDIRECT)
	for rid in [_edges, _candidates, _locations, _items, _heads, _control, _indirect]:
		if not rid.is_valid():
			_free_buffers()
			return _fail("could not make the working buffers for %s" % size)
	buffer_size = size
	return true


## The working buffers gone (on the render thread, for a new size).
func _free_buffers() -> void:
	for rid in [_edges, _candidates, _locations, _items, _heads, _control, _indirect]:
		if rid.is_valid():
			_rd.free_rid(rid)   # (and the cached uniform sets that use it)
	_edges = RID()
	_candidates = RID()
	_locations = RID()
	_items = RID()
	_heads = RID()
	_control = RID()
	_indirect = RID()
	buffer_size = Vector2i.ZERO


## Stops for good (with the reason in the log once) rather than drawing something wrong.
func _fail(why: String) -> bool:
	if not _failed:
		push_warning("CMAA2 is off: " + why)
	_failed = true
	return false
