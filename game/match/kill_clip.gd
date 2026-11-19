class_name KillClip
extends RefCounted
## A few seconds of a match, kept so a kill can be watched again from the killer's
## eyes (see Killcam and KillcamView). Not video: for every player, what this copy of
## the game drew for them about 30 times a second (where they were, where they looked,
## what move they were in), plus the shots, rockets and blows that happened.
##
## Times are seconds on this copy's clock, moved back by how late each player's data
## reached us, so they are (roughly) when things really happened. `offsets` then moves
## each player to where the killer saw them: the killer's own screen showed everyone a
## little in the past too.
##
## A death's remains (a ragdoll or giblets, see Remains) are kept too, as Wrecks: where
## each of their bodies went as they fell, so a replay can show the same fall at its
## own speed (slow motion, a video saved frame by frame) without simulating it again.

## One player's frames, oldest first.
class Track:
	var times := PackedFloat64Array()
	## Each frame: see Player.shown_state() (feet, velocity, yaw, pitch, pose, flags,
	## rope on, rope anchor, alive, drawn, eye height, weapon, Grappling Hook 2's rope).
	var frames: Array = []
	var character := ""
	var color := Color.WHITE
	var paint := Color(0, 0, 0, 0)   ## team modes: the team's paint (Teams.paint_for); clear otherwise
	var name := ""

	func push(t: float, frame: Array) -> void:
		if not times.is_empty() and t <= times[-1]:
			t = times[-1] + 0.0001   # the estimate of how late data is drifts; never go back
		times.append(t)
		frames.append(frame)

	## Forget frames older than `before`.
	func trim(before: float) -> void:
		var n := 0
		while n < times.size() - 1 and times[n] < before:
			n += 1
		if n > 0:
			times = times.slice(n)
			frames = frames.slice(n)

	func is_empty() -> bool:
		return times.is_empty()

	## The frames from `from` to `to` (and one either side, to blend into), as a new track.
	func slice(from: float, to: float) -> Track:
		var out := Track.new()
		out.character = character
		out.color = color
		out.paint = paint
		out.name = name
		var a := maxi(_index(from), 0)
		var b := mini(_index(to) + 2, times.size())
		out.times = times.slice(a, b)
		out.frames = frames.slice(a, b)
		return out

	## The last frame at or before t (-1 if t is before the first).
	func _index(t: float) -> int:
		var lo := 0
		var hi := times.size() - 1
		if hi < 0 or t < times[0]:
			return -1
		while lo < hi:
			var mid := (lo + hi + 1) >> 1
			if times[mid] <= t:
				lo = mid
			else:
				hi = mid - 1
		return lo

	## The frame at time t, blended between the two either side (positions and aim
	## blend; the move, flags and weapon come from the earlier one). Holds the first
	## and last frames outside the track. Empty if there are no frames.
	func sample(t: float) -> Array:
		if times.is_empty():
			return []
		var i := _index(t)
		if i < 0:
			return frames[0]
		if i >= times.size() - 1:
			return frames[-1]
		var a: Array = frames[i]
		var b: Array = frames[i + 1]
		var span := maxf(times[i + 1] - times[i], 0.0001)
		var u := clampf((t - times[i]) / span, 0.0, 1.0)
		if a[8] != b[8] or (a[0] as Vector3).distance_to(b[0]) > 4.0:
			return a if u < 0.5 else b   # a death or a respawn: no blending across it
		var out := a.duplicate()
		out[0] = (a[0] as Vector3).lerp(b[0], u)
		out[1] = (a[1] as Vector3).lerp(b[1], u)
		out[2] = lerp_angle(float(a[2]), float(b[2]), u)
		out[3] = lerpf(float(a[3]), float(b[3]), u)
		out[7] = (a[7] as Vector3).lerp(b[7], u) if a[6] and b[6] else a[7]
		out[10] = lerpf(float(a[10]), float(b[10]), u)
		if a.size() > 12 and b.size() > 12 and a[12] != null and b[12] != null:
			out[12] = _blend_hook(a[12], b[12], u, span)
		return out

	## Grappling Hook 2's rope between two frames `span` seconds apart (each [hook,
	## slack, seconds since the shot, seconds since it pulled tight]). The hook and the
	## slack blend; the two clocks run on from the earlier frame, so the rope's ripples
	## and its twang move as smoothly in a replay as they did in the match, and a rope
	## that pulled tight between the two frames twangs from the moment it did.
	static func _blend_hook(a: Array, b: Array, u: float, span: float) -> Array:
		if float(b[2]) < float(a[2]):
			return a if u < 0.5 else b   # a new shot: no blending across it
		var twang := float(b[3]) - (1.0 - u) * span if float(b[3]) >= 0.0 else -1.0
		return [(a[0] as Vector3).lerp(b[0], u), lerpf(float(a[1]), float(b[1]), u), lerpf(float(a[2]), float(b[2]), u),
			twang if twang >= 0.0 else -1.0]

	func first_time() -> float:
		return times[0] if not times.is_empty() else INF

	func last_time() -> float:
		return times[-1] if not times.is_empty() else -INF


## What a player left when knocked out, as this copy saw it fall: a Ragdoll's bones or
## Gibs' bodies, each frame every one's place in the world (see their capture()), from
## the moment of the death (on the same clock as the player's Track) for the first
## Killcam.WRECK_FOR seconds. Shared, not copied, by the clips that show it.
class Wreck extends Track:
	var who := 0
	var kind := "ragdoll"     ## or "gibs"
	var fx: Dictionary = {}   ## how the blow fell (Match.death_fx)
	var weapon := ""
	var scrap := 0            ## gibs: how many of the bodies are scrap

	## A new recording of `remains` (a Ragdoll or Gibs), as it was at the death, `at`.
	static func of(remains: Node3D, at: float) -> Wreck:
		var w := Wreck.new()
		w.who = int(remains.get("who"))
		w.kind = "gibs" if remains is Gibs else "ragdoll"
		w.fx = remains.get("blow")
		w.character = str(remains.get("character"))
		w.color = remains.get("body_color")
		w.paint = Teams.paint_for(w.who)   # (the team they died on)
		w.weapon = str(remains.get("weapon"))
		if remains is Gibs:
			w.scrap = (remains as Gibs).scrap_count()
		w.push(at, remains.call("start_pose"))
		return w

	## Every body's place at time t, blended between the frames either side (the first
	## and last held outside the recording).
	func pose_at(t: float) -> Array:
		var i := _index(t)
		if i < 0:
			return frames[0]
		if i >= times.size() - 1:
			return frames[-1]
		var a: Array = frames[i]
		var b: Array = frames[i + 1]
		var u := clampf((t - times[i]) / maxf(times[i + 1] - times[i], 0.0001), 0.0, 1.0)
		var out := []
		for k in mini(a.size(), b.size()):
			out.append((a[k] as Transform3D).interpolate_with(b[k], u))
		return out


## Player id -> Track.
var tracks: Dictionary = {}
## What happened, oldest first: {t, kind ("shot", "projectile", "boom", "melee"), who, ...}.
var events: Array = []
## What deaths left (Wreck), oldest first: any still lying about during the clip.
var wrecks: Array = []
## The kill (see Match.kill_info).
var info: Dictionary = {}
var killer := 0
var victim := 0
## When the killer landed the blow, and the stretch to watch.
var kill_time := 0.0
var start := 0.0
var end := 0.0
## Player id -> seconds to add to the killer's time to sample them (minus how far in
## the past the killer's screen showed them). 0 for the killer.
var offsets: Dictionary = {}
## Player id -> seconds to add to an event's time: when the killer saw it.
var event_offsets: Dictionary = {}
var map := ""


## The time to sample player `id` at, for killer time t.
func time_for(id: int, t: float) -> float:
	return t + float(offsets.get(id, 0.0))


## When the killer saw event `e`.
func event_time(e: Dictionary) -> float:
	return float(e.t) + float(event_offsets.get(int(e.who), 0.0))


## A copy holding only what is needed to watch [start - margin, end + margin].
func cut(margin: float = 0.6) -> KillClip:
	var out := KillClip.new()
	out.info = info
	out.killer = killer
	out.victim = victim
	out.kill_time = kill_time
	out.start = start
	out.end = end
	out.offsets = offsets.duplicate()
	out.event_offsets = event_offsets.duplicate()
	out.map = map
	for id in tracks:
		var off := float(offsets.get(id, 0.0))
		var part: Track = (tracks[id] as Track).slice(start + off - margin, end + off + margin)
		if not part.is_empty():
			out.tracks[id] = part
	for e in events:
		var et := event_time(e)
		if et >= start - margin and et <= end + margin:
			out.events.append(e)
	for w: Wreck in wrecks:   # any lying about during the clip (each holds its last frame once it has settled)
		var off := float(offsets.get(w.who, 0.0))
		if w.first_time() <= end + off + margin and w.first_time() + Remains.LIFETIME >= start + off - margin:
			out.wrecks.append(w)
	return out


## Whether there is enough of the killer to watch: their recording reaches back at
## least `lead` seconds before the kill. A clip starts no earlier than that recording.
func has_killer(lead: float = 0.0) -> bool:
	var t: Track = tracks.get(killer)
	if t == null or t.is_empty() or t.first_time() > kill_time - lead or t.last_time() < start:
		return false
	start = maxf(start, t.first_time())
	return true
