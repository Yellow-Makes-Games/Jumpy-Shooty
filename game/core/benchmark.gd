class_name Benchmark
extends Node3D
## The graphics benchmark (Settings > Graphics > Run benchmark, or --benchmark).
##
## Flies a camera over the same three maps every time, on the same path, and times
## every frame. On each map: a few seconds of warm-up (the whole path, fast, so
## shaders compile and the first look at each view is not counted), then the timed
## run: a slow circle high over the map, then a stop at eye height on several spawn
## points, turning right round at each. No players, bots or moving parts: it is the
## cost of drawing the map itself, the part that changes most from map to map.
##
## Vsync and the frame-rate cap are off while it runs (put back after), so the
## numbers show what this PC can do rather than the monitor's refresh rate. The
## window size, fullscreen and other settings stay as the player has them.
##
## Writes two files to user://benchmarks/ (see folder()):
##   benchmark_<date>.txt  the report: this PC, the settings, and for each map and each
##                         part of the path the frame time, 1% low, GPU and CPU time,
##                         draw calls, and whether the GPU or the CPU held it back.
##   benchmark_<date>.csv  every frame, for a spreadsheet.

## The maps, heaviest first: Cirrus (the biggest, about 5,300 blocks), Castle and
## Halcyon (indoors, its own sky). Keep the list the same so runs compare.
const MAPS := ["cirrus", "castle", "halcyon"]
const WARMUP := 4.0       ## seconds of warm-up on each map
const ORBIT_TIME := 14.0  ## seconds for the circle over the map
const STOPS := 6          ## spawn points to stop at
const STOP_TIME := 2.5    ## seconds at each, turning once round
const EYE := 1.6          ## eye height over a spawn point
const FOLDER := "user://benchmarks"

signal finished(report_path: String)

var _map_i := -1
var _map: MapRoot
var _camera: Camera3D
var _center := Vector3.ZERO
var _radius := 40.0
var _stops: Array = []         # [position, yaw] of the spawn points stopped at
var _phase := ""               # "load", "warmup", "run", "done"
var _t := 0.0
var _last_usec := 0
var _frames: Array = []        # one row per timed frame (see _record)
var _results: Array = []       # one per map: {id, name, segments: {name: rows}, frames: rows}
var _overlay: Label
var _ui: CanvasLayer
var _started := ""


static func folder() -> String:
	return ProjectSettings.globalize_path(FOLDER)


func _ready() -> void:
	_started = Time.get_datetime_string_from_system(false, true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_camera = Camera3D.new()
	_camera.far = 800.0   # (as the player's camera)
	_camera.fov = Settings.field_of_view
	add_child(_camera)
	_camera.make_current()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_overlay = Label.new()
	_overlay.position = Vector2(24, 18)
	_overlay.add_theme_font_override("font", HudStyle.font(true))
	_overlay.add_theme_font_size_override("font_size", 18)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 6)
	_ui.add_child(_overlay)
	_next_map()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != "done" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_restore()
		Game.goto_main_menu("Benchmark stopped. Nothing was saved.")


func _next_map() -> void:
	if _map:
		if _map_i >= 0:
			_results.append({"id": MAPS[_map_i], "name": Maps.name_of(MAPS[_map_i]), "frames": _frames})
		remove_child(_map)
		_map.queue_free()
		_map = null
		MapRoot.current = null
	_frames = []
	_map_i += 1
	if _map_i >= MAPS.size():
		_finish()
		return
	_phase = "load"
	_overlay.text = "BENCHMARK  ·  Loading %s (%d of %d)" % [Maps.name_of(MAPS[_map_i]), _map_i + 1, MAPS.size()]
	_load_map.call_deferred()   # (after a frame, so the loading line shows)


func _load_map() -> void:
	await get_tree().process_frame
	_map = Maps.make(MAPS[_map_i])
	add_child(_map)
	_map.build()
	_plan_path()
	_phase = "warmup"
	_t = 0.0
	_last_usec = Time.get_ticks_usec()
	_overlay.text = "BENCHMARK  ·  %s (%d of %d)  ·  warming up  ·  Esc stops" % [Maps.name_of(MAPS[_map_i]), _map_i + 1, MAPS.size()]


## The circle goes round the spawn points' middle, wide enough to see them all; the
## stops are spawn points spread through the map's list.
func _plan_path() -> void:
	var spawns: Array = _map.spawns
	_stops = []
	if spawns.is_empty():
		_center = Vector3.ZERO
		_radius = 40.0
		return
	var sum := Vector3.ZERO
	for s in spawns:
		sum += s[0]
	_center = sum / spawns.size()
	_radius = 20.0
	for s in spawns:
		var d: Vector3 = s[0] - _center
		_radius = maxf(_radius, Vector2(d.x, d.z).length())
	for i in mini(STOPS, spawns.size()):
		_stops.append(spawns[i * spawns.size() / mini(STOPS, spawns.size())])


func _run_length() -> float:
	return ORBIT_TIME + STOP_TIME * _stops.size()


## Where the camera is `s` seconds into the timed run, and which part of the path
## that is.
func _pose(s: float) -> String:
	if s < ORBIT_TIME or _stops.is_empty():
		var a := TAU * s / ORBIT_TIME
		var r := _radius * 1.15
		_camera.position = _center + Vector3(sin(a) * r, _radius * 0.55 + 6.0, cos(a) * r)
		_camera.look_at(_center + Vector3(0, 2, 0))
		return "Overview"
	var k := mini(int((s - ORBIT_TIME) / STOP_TIME), _stops.size() - 1)
	var f := (s - ORBIT_TIME - k * STOP_TIME) / STOP_TIME
	var stop: Array = _stops[k]
	_camera.position = stop[0] + Vector3(0, EYE, 0)
	_camera.rotation = Vector3(deg_to_rad(-6.0), stop[1] + PI + TAU * f, 0)   # (a spawn's yaw faces +z; the camera looks down -z)
	return "Spawn %d" % (k + 1)


func _process(_delta: float) -> void:
	if _phase != "warmup" and _phase != "run":
		return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	if _phase == "warmup":
		_t += frame_ms / 1000.0
		_pose(_t / WARMUP * _run_length())   # the whole path, fast
		if _t >= WARMUP:
			_phase = "run"
			_t = 0.0
			_overlay.text = "BENCHMARK  ·  %s (%d of %d)  ·  Esc stops" % [Maps.name_of(MAPS[_map_i]), _map_i + 1, MAPS.size()]
		return
	# The numbers read now are for the frame that just went (the GPU's lag a frame or
	# two behind, which evens out over a run).
	var segment := _pose(_t)
	_record(segment, frame_ms)
	_t += frame_ms / 1000.0
	if _t >= _run_length():
		_phase = "load"
		_next_map()


## One row: [segment, seconds into the run, frame ms, GPU ms, CPU render ms,
## physics ms, draw calls, objects, primitives].
func _record(segment: String, frame_ms: float) -> void:
	var vp := get_viewport().get_viewport_rid()
	_frames.append([segment, _t, frame_ms,
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])


func _restore() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	Settings.apply()   # vsync and the frame-rate cap back as the player set them


func _finish() -> void:
	_phase = "done"
	_restore()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay.visible = false
	var path := save_report(_results, _started)
	_show_results(path)
	finished.emit(path)


# ---------------------------------------------------------------------------
# The report

## Frame-time numbers for a list of rows (see _record).
static func summarize(rows: Array) -> Dictionary:
	if rows.is_empty():
		return {}
	var times: Array = rows.map(func(r): return r[2])
	times.sort()
	var n := rows.size()
	var total := 0.0
	var sums := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # gpu, cpu render, physics, draws, objects, prims
	var peak_draws := 0
	for r in rows:
		total += r[2]
		for i in 6:
			sums[i] += r[i + 3]
		peak_draws = maxi(peak_draws, r[6])
	var avg := total / n
	# 1% low: the frame rate of the slowest 1% of frames (their average time).
	var slow: Array = times.slice(int(n * 0.99)) if n >= 100 else [times[-1]]
	var slow_ms := 0.0
	for t in slow:
		slow_ms += t
	slow_ms /= slow.size()
	var gpu: float = sums[0] / n
	var cpu: float = (sums[1] + sums[2]) / n   # the CPU's share: setting up the drawing, and physics
	return {
		"frames": n, "seconds": total / 1000.0,
		"avg_ms": avg, "fps": 1000.0 / avg,
		"median_ms": times[n / 2], "p99_ms": times[mini(int(n * 0.99), n - 1)], "max_ms": times[-1],
		"low1_fps": 1000.0 / slow_ms,
		"gpu_ms": gpu, "cpu_ms": cpu, "render_cpu_ms": sums[1] / n, "physics_ms": sums[2] / n,
		"draws": sums[3] / n, "peak_draws": peak_draws, "objects": sums[4] / n, "prims": sums[5] / n,
		"bound": "GPU" if gpu >= cpu else "CPU",
	}


## Writes the report and the per-frame CSV; returns the report's full path.
static func save_report(results: Array, started: String) -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var stamp := started.replace(":", "-").replace(" ", "_")
	var txt_path := "%s/benchmark_%s.txt" % [FOLDER, stamp]
	var csv_path := "%s/benchmark_%s.csv" % [FOLDER, stamp]
	var f := FileAccess.open(txt_path, FileAccess.WRITE)
	if f:
		f.store_string(report_text(results, started, csv_path.get_file()))
		f.close()
	var c := FileAccess.open(csv_path, FileAccess.WRITE)
	if c:
		c.store_line("map,segment,time_s,frame_ms,gpu_ms,cpu_render_ms,physics_ms,draw_calls,objects,primitives")
		for m in results:
			for r in m.frames:
				c.store_line("%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d" % [m.id, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]])
		c.close()
	return ProjectSettings.globalize_path(txt_path)


static func report_text(results: Array, started: String, csv_name: String) -> String:
	var out := PackedStringArray()
	var size := DisplayServer.window_get_size()
	var tree := Engine.get_main_loop() as SceneTree
	var scale := tree.root.scaling_3d_scale if tree else 1.0
	out.append("JUMPY SHOOTY BENCHMARK")
	out.append("======================")
	out.append("Run:        %s" % started)
	out.append("Game:       %s (Godot %s)" % [Game.version_label(), Engine.get_version_info().string])
	out.append("OS:         %s %s" % [OS.get_name(), OS.get_version()])
	out.append("CPU:        %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	out.append("GPU:        %s (%s), %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version()])
	out.append("Renderer:   %s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")))
	out.append("Window:     %d x %d, %s, 3D drawn at %d%%" % [size.x, size.y, "fullscreen" if Settings.fullscreen else "windowed", roundi(scale * 100.0)])
	out.append("Quality:    %s (MSAA %s, %s, render scale %d%%, shadows %s, AO %s, glow %s)" % [GraphicsQuality.QUALITY_NAMES.get(Settings.quality, Settings.quality),
		GraphicsQuality.MSAA_NAMES.get(Settings.msaa, str(Settings.msaa)), Settings.screen_aa.to_upper(), roundi(Settings.render_scale * 100.0),
		Settings.shadows, Settings.ao, "on" if Settings.glow else "off"])
	out.append("During the run vsync and the frame-rate cap were off (your settings: vsync %s)." % ("on" if Settings.vsync else "off"))
	out.append("")
	out.append("Each map: a %s s circle high over it (Overview), then %s s at eye height on each of up to %d spawn points," % [str(ORBIT_TIME), str(STOP_TIME), STOPS])
	out.append("turning once round. No players, bots or moving parts: the cost of drawing the map.")
	out.append("FPS is the average; 1% low is the frame rate of the slowest 1% of frames (stutter).")
	out.append("GPU ms: the graphics card's time per frame. CPU ms: the processor's time setting up the drawing, plus physics.")
	out.append("Limited by: whichever of the two takes longer. Make that one's work smaller first.")
	out.append("")
	var all: Array = []
	for m in results:
		all.append_array(m.frames)
	var t := summarize(all)
	if not t.is_empty():
		out.append("OVERALL: %.0f FPS average (%.1f ms), 1%% low %.0f FPS, slowest frame %.1f ms" % [t.fps, t.avg_ms, t.low1_fps, t.max_ms])
		out.append("")
	out.append("SUMMARY")
	out.append(_row(["Map", "FPS", "1% low", "Frame ms", "GPU ms", "CPU ms", "Draw calls", "Primitives", "Limited by"]))
	for m in results:
		var s := summarize(m.frames)
		if not s.is_empty():
			out.append(_row([m.name, "%.0f" % s.fps, "%.0f" % s.low1_fps, "%.1f" % s.avg_ms, "%.1f" % s.gpu_ms, "%.1f" % s.cpu_ms,
				"%.0f" % s.draws, _big(s.prims), s.bound]))
	for m in results:
		out.append("")
		out.append(m.name.to_upper())
		var segs := {}
		var order := []
		for r in m.frames:
			if not segs.has(r[0]):
				segs[r[0]] = []
				order.append(r[0])
			segs[r[0]].append(r)
		out.append(_row(["Part", "FPS", "1% low", "Frame ms", "GPU ms", "CPU ms", "Draw calls", "Primitives", "Limited by"]))
		var worst := ""
		var worst_ms := 0.0
		for seg in order:
			var s := summarize(segs[seg])
			out.append(_row([seg, "%.0f" % s.fps, "%.0f" % s.low1_fps, "%.1f" % s.avg_ms, "%.1f" % s.gpu_ms, "%.1f" % s.cpu_ms,
				"%.0f" % s.draws, _big(s.prims), s.bound]))
			if s.avg_ms > worst_ms:
				worst_ms = s.avg_ms
				worst = seg
		var s := summarize(m.frames)
		out.append("Slowest part: %s (%.1f ms).  CPU: drawing %.2f ms, physics %.2f ms a frame.  Most draw calls in a frame: %d." % [
			worst, worst_ms, s.render_cpu_ms, s.physics_ms, s.peak_draws])
	out.append("")
	out.append("Every frame is in %s (open it in a spreadsheet)." % csv_name)
	return "\n".join(out) + "\n"


static func _row(cells: Array) -> String:
	var widths := [14, 6, 8, 10, 8, 8, 12, 12, 12]
	var line := ""
	for i in cells.size():
		var c := str(cells[i])
		line += c.rpad(widths[i]) if i == 0 else c.lpad(widths[i])
	return line


static func _big(n: float) -> String:
	return "%.1fM" % (n / 1e6) if n >= 1e6 else ("%.0fk" % (n / 1e3) if n >= 1e3 else "%.0f" % n)


# ---------------------------------------------------------------------------
# The results page

func _show_results(path: String) -> void:
	var root := Control.new()
	root.theme = UiKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	var frame := MenuFrame.new(900)
	root.add_child(frame)
	frame.title("Benchmark", "Settings  /  Graphics  /  results")
	var all: Array = []
	for m in _results:
		all.append_array(m.frames)
	var t := summarize(all)
	if not t.is_empty():
		var big := UiKit.label(frame.body, "%.0f FPS average  ·  1%% low %.0f FPS" % [t.fps, t.low1_fps], false, 26)
		big.add_theme_font_override("font", HudStyle.font(true))
	UiKit.section(frame.body, "Maps")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	frame.body.add_child(grid)
	for h in ["Map", "FPS", "1% low", "GPU ms", "Limited by"]:
		var l := UiKit.label(grid, h, true, 15)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	for m in _results:
		var s := summarize(m.frames)
		if s.is_empty():
			continue
		for c in [m.name, "%.0f" % s.fps, "%.0f" % s.low1_fps, "%.1f" % s.gpu_ms, s.bound]:
			var l := UiKit.label(grid, c, false, 18)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
	UiKit.spacer(frame.body, 6)
	UiKit.label(frame.body, "The full report (every part of the path, this PC and your settings) and every frame as a spreadsheet are saved in:", true, 15)
	var where := UiKit.label(frame.body, path.get_base_dir(), false, 15)
	where.add_theme_color_override("font_color", UiKit.CYAN)
	frame.back_button("Back", func(): Game.goto_main_menu())
	var folder_btn := frame.back_button("Open folder", func(): OS.shell_open(folder()))
	folder_btn.custom_minimum_size.x = 200
	frame.main_button("Open report", func(): OS.shell_open(path)).grab_focus()
