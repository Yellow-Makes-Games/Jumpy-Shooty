extends Node
## Plays a match against bots and prints what a frame costs the CPU (see bot_load.gd).
var map_id := "empyrean"
var bots := 4
var seconds := 30

func run() -> void:
	if bots > 0:
		Game.start_bot(2, 99, map_id, bots)
	else:
		Game.start_practice(map_id)
	for i in 240:
		await get_tree().process_frame
	var proc := 0.0
	var phys := 0.0
	var worst := 0.0
	var n := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000:
		await get_tree().process_frame
		var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var q := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += p
		phys += q
		worst = maxf(worst, p + q)
		n += 1
	print("PERF %s: process %.2f ms, physics step %.2f ms (x%d a second), worst frame %.1f ms, %d frames, %d nodes" % [map_id, proc / n, phys / n, Engine.physics_ticks_per_second, worst, n, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit()
