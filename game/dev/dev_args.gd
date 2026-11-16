extends Node
## Developer command-line options, used by tools/run_local and the automated tests.
## Pass them after a "--" on the Godot command line, for example:
##   godot --path . -- --host --name=Austin --autostart=2
##
## --host               Host a direct-IP lobby straight away.
## --join=ADDRESS       Join a direct-IP lobby straight away (ADDRESS may include :PORT).
## --port=PORT         Host only: port to listen on (default 24680).
## --name=NAME          Player name for this copy of the game.
## --autostart=N        Host only: start the match once N players are in the lobby.
## --character=ID      Play as this robot (needle, vanguard) without changing the saved choice.
## --switch-character  Online: pick the next robot each time you come back to the lobby after a match (tests).
## --weapon=ID          Take this gun (pistol, shotgun, rifle, sniper) without changing the saved choice.
## --bot-weapon=ID      Every bot takes this gun (instead of one at random).
## --switch-weapon      Online: pick the next gun each time you come back to the lobby after a match (tests).
## --practice           Skip the menus and drop into the arena alone.
## --map=ID             Which map to play: construction_site, office or testing_grounds (host, practice and bot).
## --bot=LEVEL          Skip the menus and start a 1v1 against a bot (0 Easy, 1 Normal, 2 Hard, 3 Expert).
## --bots=N             With --bot: play against N bots (1 to 4) in a free-for-all instead of one.
## --scripted-input     The local player moves on its own (for sync tests).
## --sync-log           Print position samples used by tests/check_sync.py.
## --quit-after=SECONDS Quit automatically after this many seconds.
## --net-sim=L,J,P     Simulate a bad connection: L ms latency, up to J ms extra jitter,
##                      P percent of movement packets lost (incoming, this copy only).
## --scripted-fire     With --scripted-input: aim at the nearest opponent and shoot.
## --rules=kills:N | time:MINUTES  Host only: set the lobby's win condition.
## --kill-target=N      Host only: override the kill target for this match.
## --time-limit=SECONDS Host only: override the match length (safety cap in tests).
## --auto-return       Leave the results screen after 2 seconds (lobby online, rematch vs a bot).
## --menu=PAGE          Open the main menu on this page: play, practice, bot, multiplayer, settings.
## --third-person      Start in third-person view (not saved to settings).
## --screenshot=SEC:PATH Save a screenshot SEC seconds after start (repeatable).
## --press=SEC:ACTION   Press an input action (e.g. toggle_camera) SEC seconds after start (repeatable).
## --hold=SEC:ACTION:DURATION  Hold an input action down for DURATION seconds, starting SEC seconds after start (repeatable).
## --spawn=X,Y,Z,YAW[,PITCH]  Start the local player here (degrees), e.g. to look at the training yard.
## --game-clock        Count the SEC of the options below in game time instead of real time. With Godot's own
##                      --fixed-fps 60 (before the "--") a scripted run plays out the same however slowly it renders.
## --look=SEC:YAW,PITCH  Turn the local player's view by YAW and to PITCH (degrees) SEC seconds after start (repeatable).
## --window=X,Y,W,H     Window position and size, so several copies can sit side by side.

var host := false
var join_address := ""
var player_name := ""
var port := 0
var autostart := 0
var practice := false
var character := ""
var switch_character := false
var weapon := ""
var bot_weapon := ""
var switch_weapon := false
var map := ""
var bot := -1
var bots := 1
var scripted_input := false
var sync_log := false
var scripted_fire := false
var auto_return := false
var kill_target := 0
var rules := ""
var time_limit := 0.0
var quit_after := 0.0
var menu := ""
var window_rect := Rect2i()
var net_sim_latency := 0.0
var net_sim_jitter := 0.0
var net_sim_loss := 0.0
var screenshots: Array = []  # [seconds, path]
var presses: Array = []      # [seconds, action]
var holds: Array = []        # [start seconds, action, end seconds, is down]
var spawn: Array = []        # [Vector3 position, yaw, pitch] in radians, or empty
var looks: Array = []        # [seconds, yaw turn, pitch] in radians
var drives_keys := false     # --hold or --press was given: the player listens even if the mouse is not captured

var _start_ticks := 0
var _fixed_step := false     # --game-clock: count game time, so slow rendering does not shift the script
var _game_time := 0.0


func _ready() -> void:
	_start_ticks = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		var key: String = arg
		var value := ""
		if "=" in arg:
			key = arg.get_slice("=", 0)
			value = arg.substr(key.length() + 1)
		match key:
			"--host": host = true
			"--join": join_address = value
			"--name": player_name = value
			"--port": port = int(value)
			"--autostart": autostart = int(value)
			"--practice": practice = true
			"--character":
				if Characters.has(value):
					character = value
				else:
					push_warning("Unknown character: %s (characters: %s)" % [value, ", ".join(Characters.ids())])
			"--switch-character": switch_character = true
			"--weapon", "--bot-weapon":
				if WeaponData.has(value):
					if key == "--weapon":
						weapon = value
					else:
						bot_weapon = value
				else:
					push_warning("Unknown weapon: %s (weapons: %s)" % [value, ", ".join(WeaponData.IDS)])
			"--switch-weapon": switch_weapon = true
			"--map":
				if Maps.has(value):
					map = value
				else:
					push_warning("Unknown map: %s (maps: %s)" % [value, ", ".join(Maps.ids())])
			"--bot": bot = clampi(int(value), 0, 3)
			"--bots": bots = clampi(int(value), 1, 4)
			"--scripted-input": scripted_input = true
			"--sync-log": sync_log = true
			"--scripted-fire": scripted_fire = true
			"--auto-return": auto_return = true
			"--menu": menu = value
			"--kill-target": kill_target = int(value)
			"--rules": rules = value
			"--time-limit": time_limit = float(value)
			"--third-person": Settings.third_person = true
			"--quit-after": quit_after = float(value)
			"--net-sim":
				var q := value.split(",")
				net_sim_latency = float(q[0]) if q.size() > 0 else 0.0
				net_sim_jitter = float(q[1]) if q.size() > 1 else 0.0
				net_sim_loss = float(q[2]) if q.size() > 2 else 0.0
			"--press":
				drives_keys = true
				presses.append([float(value.get_slice(":", 0)), value.substr(value.find(":") + 1)])
			"--hold":
				var h := value.split(":")
				if h.size() == 3:
					drives_keys = true
					holds.append([float(h[0]), h[1], float(h[0]) + float(h[2]), false])
			"--screenshot":
				screenshots.append([float(value.get_slice(":", 0)), value.substr(value.find(":") + 1)])
			"--game-clock": _fixed_step = true
			"--look":
				var l := value.get_slice(":", 1).split(",")
				if l.size() == 2:
					looks.append([float(value.get_slice(":", 0)), deg_to_rad(float(l[0])), deg_to_rad(float(l[1]))])
			"--spawn":
				var c := value.split(",")
				spawn = [Vector3(float(c[0]), float(c[1]), float(c[2])),
					deg_to_rad(float(c[3])) if c.size() > 3 else 0.0,
					deg_to_rad(float(c[4])) if c.size() > 4 else 0.0]
			"--window":
				var p := value.split(",")
				if p.size() == 4:
					window_rect = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
			_: push_warning("Unknown dev argument: %s" % arg)
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60  # several headless copies share the CPU in tests
	if window_rect.size != Vector2i.ZERO and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(window_rect.size)
		DisplayServer.window_set_position(window_rect.position)


func net_sim_enabled() -> bool:
	return net_sim_latency > 0.0 or net_sim_jitter > 0.0 or net_sim_loss > 0.0


func any() -> bool:
	return host or join_address != "" or practice or bot >= 0


func _elapsed() -> float:
	return _game_time if _fixed_step else (Time.get_ticks_msec() - _start_ticks) / 1000.0


## Held actions change on a physics step (before the players run theirs), so the
## step that reads them sees the key go down.
func _physics_process(_delta: float) -> void:
	var elapsed := _elapsed()
	for hold in holds.duplicate():
		if not hold[3] and elapsed >= hold[0]:
			hold[3] = true
			Input.action_press(hold[1])
			print("[dev] holding: %s at %.2f" % [hold[1], elapsed])
		elif hold[3] and elapsed >= hold[2]:
			holds.erase(hold)
			Input.action_release(hold[1])


func _process(delta: float) -> void:
	_game_time += delta
	var elapsed := _elapsed()
	for press in presses.duplicate():
		if elapsed >= press[0]:
			presses.erase(press)
			for down in [true, false]:
				var ev := InputEventAction.new()
				ev.action = press[1]
				ev.pressed = down
				Input.parse_input_event(ev)
			print("[dev] pressed: %s" % press[1])
	for look in looks.duplicate():
		if elapsed >= look[0]:
			looks.erase(look)
			var me: Player = Net.arena.local_player if Net.arena else null
			if me:
				me.input.yaw += look[1]
				me.input.pitch = look[2]
	for shot in screenshots.duplicate():
		if elapsed >= shot[0]:
			screenshots.erase(shot)
			var img := get_viewport().get_texture().get_image()
			img.save_png(shot[1])
			print("[dev] screenshot saved: %s at %.2f" % [shot[1], elapsed])
	if quit_after > 0.0 and elapsed >= quit_after:
		print("[dev] quit-after reached")
		quit_after = 0.0
		Net.leave()
		get_tree().quit()
