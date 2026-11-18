extends Node
## The soundtrack. Autoload at /root/Music.
##
## Plays the songs in game/audio/music/ one after another in a random order (all of
## them before any repeats, never the same one twice running), forever, everywhere:
## menus, lobby and matches. Each song fades into the next: the next one starts
## FADE seconds before the current one ends and the two cross over (an equal-power
## fade, so the loudness stays even).
##
## Online, the host chooses: it decides which song plays and when it started, on
## its own clock, and tells everyone (and anyone who joins later). Each client
## measures how far its clock is from the host's (a few pings when it joins, then
## one every few seconds) and plays the song from the same point, nudging the
## playback back in line if it drifts. So everyone in a session hears the same
## part of the same song at the same moment. Offline (or before joining), each copy
## of the game chooses for itself.
##
## In an online lobby the host can pick the song (LobbySettings "song"): it fades in
## straight away, for everyone, and plays over and over until the host picks another
## (or Shuffle). Once a match starts, the songs shuffle again after it ends.
##
## Plays on the Music bus: the Music slider in Settings sets its volume.

const DIR := "res://game/audio/music/"
const FADE := 4.0            ## seconds the songs overlap while one fades into the next
const DRIFT := 0.25          ## seconds out of line before playback is moved back into place
const PING_GAP := 4.0        ## seconds between clock checks with the host

var _streams: Array[AudioStream] = []
var _names: PackedStringArray = []
var _players: Array[AudioStreamPlayer] = []
## What is playing: up to two songs (the newer one last), each {"i": song, "at": start
## time on the host's clock, "p": the player index playing it, "on": started yet, and
## "end": when it has faded out, if it was cut short (-1 if it plays to its end)}.
var _songs: Array = []
var _bag: Array = []          # songs still to come before any repeats
var _offset := 0.0            # the host's clock minus ours (0 when we choose)
var _best_rtt := INF
var _best_age := 0.0
var _ping_wait := 0.0
var _pings_left := 0
var _drift_wait := 0.0
var _following := false       # online as a client: the host chooses
var _rng := RandomNumberGenerator.new()
## Headless (tests, scripted runs): choose and sync songs as usual but play nothing. A
## song still decoding when a quick scripted run quits is reported as a leak at exit.
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while the game is paused
	_rng.randomize()
	for f in _music_files():
		var s := load(DIR + f) as AudioStream
		if s and s.get_length() > FADE * 2.0:
			if s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = false
			_streams.append(s)
			_names.append(f.get_basename())
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = Sound.BUS_MUSIC
		add_child(p)
		_players.append(p)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(_on_left)
	multiplayer.connection_failed.connect(_on_left)
	multiplayer.peer_connected.connect(_on_peer_connected)


func _music_files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		f = f.trim_suffix(".import")   # exported games keep only the imported copies
		if (f.ends_with(".mp3") or f.ends_with(".ogg") or f.ends_with(".wav")) and not out.has(f):
			out.append(f)
	out.sort()
	return out


## Now, on the clock of whoever chooses the songs.
func host_now() -> float:
	return Net.now() + _offset


## The song playing now (the newer one during a fade), or "".
func current_song() -> String:
	return _names[_songs[-1].i] if not _songs.is_empty() else ""


## Every song's name (its file name without the extension), in the order they are listed.
func song_names() -> PackedStringArray:
	return _names.duplicate()


## A song's name as players see it ("" is Shuffle).
static func title_of(song: String) -> String:
	return "Shuffle" if song == "" else song.capitalize()


## The host, in an online lobby (not in a match): the song it picked to play there,
## as an index, or -1 to shuffle.
func _lobby_song() -> int:
	if not _hosting() or Net.in_match:
		return -1
	var song := str(Net.match_settings.get("song", ""))
	return _names.find(song) if song != "" else -1


func _process(delta: float) -> void:
	if _streams.is_empty():
		return
	_following = _is_client()
	var now := host_now()
	if not _following:
		var want := _lobby_song()
		if _songs.is_empty():
			_start(want if want >= 0 else _pick(), now, true)
		else:
			var last: Dictionary = _songs[-1]
			var ends: float = last.at + _stop_time(last)
			if want >= 0 and last.i != want:
				_fade_out_all(now)   # the host picked a song: it fades in now, over the old one
				_start(want, now, true)
			elif now >= ends - FADE:
				_start(want if want >= 0 else _pick(), ends - FADE, true)
	else:
		_update_clock(delta)
	_mix(now, delta)


## Plays each song from where it should be now, with its fade in or out.
func _mix(now: float, delta: float) -> void:
	_drift_wait -= delta
	var check := _drift_wait <= 0.0
	if check:
		_drift_wait = 2.0
	for s in _songs.duplicate():
		var p: AudioStreamPlayer = _players[s.p]
		var t: float = now - s.at
		var length := _stop_time(s)
		if t >= length:
			p.stop()
			_songs.erase(s)
			continue
		if t < 0.0:
			continue   # starts a moment from now
		if not s.on or not p.playing:
			s.on = true
			if _silent:
				continue
			p.stream = _streams[s.i]
			p.play(t)
		elif check and absf(p.get_playback_position() + AudioServer.get_time_since_last_mix() - t) > DRIFT:
			p.seek(t)   # drifted (or the clock estimate just improved): back in line
		var fade_in := clampf(t / FADE, 0.0, 1.0)
		var fade_out := clampf((length - t) / FADE, 0.0, 1.0)
		var gain := sin(fade_in * PI * 0.5) * sin(fade_out * PI * 0.5)
		p.volume_db = linear_to_db(maxf(gain, 0.0001))


func _length(i: int) -> float:
	return _streams[i].get_length()


## How long a song plays from its start: to its end, or until it has faded out if it
## was cut short.
func _stop_time(s: Dictionary) -> float:
	var length := _length(s.i)
	var end: float = s.get("end", -1.0)
	return minf(length, end - float(s.at)) if end >= 0.0 else length


## Everything playing fades out over FADE seconds from host time `now`.
func _fade_out_all(now: float) -> void:
	for s in _songs:
		var end: float = s.get("end", -1.0)
		s.end = now + FADE if end < 0.0 else minf(end, now + FADE)


## The next song: from a shuffled bag of all of them, never the one just played.
func _pick() -> int:
	if _bag.is_empty():
		for i in _streams.size():
			_bag.append(i)
		_bag.shuffle()
		var last: int = _songs[-1].i if not _songs.is_empty() else -1
		if _bag.size() > 1 and _bag[-1] == last:
			_bag.reverse()
	return _bag.pop_back()


## Song i starts at host time `at`. The chooser tells everyone.
func _start(i: int, at: float, tell: bool) -> void:
	while _songs.size() >= 2:
		_players[_songs[0].p].stop()
		_songs.pop_front()
	var free := 0
	if not _songs.is_empty():
		free = 1 - int(_songs[0].p)
	_players[free].stop()
	_songs.append({"i": i, "at": at, "p": free, "on": false, "end": -1.0})
	if DevArgs.sync_log:
		print("MUSIC %d %s %.3f" % [Net.my_id(), _names[i], at])
	if tell and _hosting():
		_play.rpc(_state())


## What is playing, to send: [[song, start, end], ...] (the older one first; end is -1
## unless it was cut short).
func _state() -> Array:
	var out := []
	for s in _songs:
		out.append([s.i, s.at, s.get("end", -1.0)])
	return out


@rpc("authority", "call_remote", "reliable")
func _play(state: Array) -> void:
	# The host's choice replaces ours. Keep a song that is already playing in the same place.
	var keep := {}
	for s in _songs:
		keep["%d:%.3f" % [s.i, s.at]] = s
	var players_used := []
	var next := []
	for entry in state:
		var i := int(entry[0])
		if i < 0 or i >= _streams.size():
			continue
		var key := "%d:%.3f" % [i, float(entry[1])]
		var end := float(entry[2]) if entry.size() > 2 else -1.0
		if keep.has(key):
			keep[key].end = end
			next.append(keep[key])
			players_used.append(keep[key].p)
		else:
			next.append({"i": i, "at": float(entry[1]), "p": -1, "on": false, "end": end})
	for s in _songs:
		if not next.has(s):
			_players[s.p].stop()
	for s in next:
		if s.p < 0:
			s.p = 0 if not players_used.has(0) else 1
			players_used.append(s.p)
	_songs = next
	if DevArgs.sync_log and not _songs.is_empty():
		print("MUSIC SEEN %d %s %.3f" % [Net.my_id(), _names[_songs[-1].i], _songs[-1].at])


# ---------------------------------------------------------------------------
# Online: who chooses, and the host's clock

func _hosting() -> bool:
	return Net.is_online and multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _is_client() -> bool:
	if not Net.is_online or not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Someone joined our lobby: tell them what is playing.
func _on_peer_connected(id: int) -> void:
	if _hosting() and not _songs.is_empty():
		_play.rpc_id(id, _state())


## Joined a host: measure our clocks against each other straight away.
func _on_connected() -> void:
	_best_rtt = INF
	_pings_left = 6
	_ping_wait = 0.0


## Back on our own: carry on with what was playing, on our own clock.
func _on_left() -> void:
	for s in _songs:
		s.at -= _offset
		if s.get("end", -1.0) >= 0.0:
			s.end -= _offset
	_offset = 0.0
	_best_rtt = INF


func _update_clock(delta: float) -> void:
	_best_age += delta
	_ping_wait -= delta
	if _ping_wait > 0.0:
		return
	_ping_wait = 0.25 if _pings_left > 0 else PING_GAP
	_pings_left = maxi(_pings_left - 1, 0)
	if Net.connected_to_host():   # (not while joining: the version check comes first)
		_ping.rpc_id(1, Net.now())


@rpc("any_peer", "call_remote", "unreliable")
func _ping(sent: float) -> void:
	if multiplayer.is_server():
		_pong.rpc_id(multiplayer.get_remote_sender_id(), sent, Net.now())


@rpc("authority", "call_remote", "unreliable")
func _pong(sent: float, host_time: float) -> void:
	var now := Net.now()
	var rtt := now - sent
	if rtt < 0.0:
		return
	# The quickest round trip gives the best estimate. An old best slowly stops
	# counting, so the estimate follows the clocks if they drift apart.
	if rtt <= _best_rtt * 1.25 or _best_age > 30.0:
		var was := _offset
		_best_rtt = minf(rtt, _best_rtt) if _best_age <= 30.0 else rtt
		_best_age = 0.0
		_offset = host_time + rtt * 0.5 - now
		if DevArgs.sync_log and absf(_offset - was) > 0.01:
			print("MUSIC CLOCK %d offset %.4f rtt %.4f" % [Net.my_id(), _offset, rtt])


func _exit_tree() -> void:
	for p in _players:   # let go of the songs so nothing is left loaded at exit
		p.stop()
		p.stream = null
	_streams.clear()
