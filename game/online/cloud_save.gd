class_name CloudSave
extends RefCounted
## A player's data as one JSON-safe Dictionary, for an account's cloud save (see
## Account): the profile (name, characters, calling card and icon, picks, tracked
## achievements) and the progress (every count, unlock, best time and top speed, and
## when each achievement was completed, which is where level and XP come from too).
##
##   var mine := CloudSave.capture()             # what this computer has
##   var both := CloudSave.merge(mine, cloud)    # put two copies together
##   CloudSave.restore(both)                     # make it this computer's
##
## How two copies are put together (merge):
##  - Progress only ever goes up, so nothing earned anywhere is lost: each count keeps
##    the bigger of the two, unlocks, weapons used and courses finished are joined, best
##    race times keep the quicker, top speeds the faster, and an achievement's date the
##    earlier.
##  - The profile is one choice, not a count: the copy changed most recently wins it
##    whole (name, character, card, icon, picks, tracked achievements). Custom
##    characters are joined by name, the newer copy's version first, up to the limit.
##
## Counts take the bigger copy rather than adding the two, so the same kill is never
## counted twice. The cost: playing signed out on two computers and then signing in on
## both keeps the bigger of the two counts, not their sum.

const VERSION := 1


## This computer's data.
static func capture() -> Dictionary:
	var s := Settings
	return {
		"version": VERSION,
		"profile": {
			"updated_at": s.profile_updated_at,
			"player_name": s.player_name,
			"character": s.character,
			"player_color": s.player_color,
			"calling_card": s.calling_card,
			"icon": s.icon,
			"weapon": s.weapon,
			"mobility": s.mobility,
			"custom_characters": s.custom_characters.duplicate(),
			"tracked": s.tracked_achievements.duplicate(),
		},
		"progress": Achievements.snapshot(),
	}


## Two copies put together (see the top of this file). Either may be empty.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty():
		return b.duplicate(true)
	if b.is_empty():
		return a.duplicate(true)
	return {"version": VERSION, "profile": merge_profile(_dict(a, "profile"), _dict(b, "profile")),
		"progress": merge_progress(_dict(a, "progress"), _dict(b, "progress"))}


static func merge_profile(a: Dictionary, b: Dictionary) -> Dictionary:
	var a_newer := float(a.get("updated_at", 0.0)) >= float(b.get("updated_at", 0.0))
	var new: Dictionary = a if a_newer else b
	var old: Dictionary = b if a_newer else a
	if new.is_empty():
		return old.duplicate(true)
	var out := new.duplicate(true)
	var names := {}
	var chars := []
	for list in [new.get("custom_characters", []), old.get("custom_characters", [])]:
		for id in list if list is Array else []:
			var n := CustomCharacter.parse(str(id)).name
			if not names.has(n) and chars.size() < Settings.MAX_CUSTOM:
				names[n] = true
				chars.append(str(id))
	out["custom_characters"] = chars
	return out


static func merge_progress(a: Dictionary, b: Dictionary) -> Dictionary:
	var stats := _dict(a, "stats").duplicate()
	var b_stats := _dict(b, "stats")
	for k in b_stats:
		stats[k] = maxi(int(stats.get(k, 0)), int(b_stats[k]))
	var owned := _union(a.get("owned", []), b.get("owned", []))
	var sets := {}
	for src in [_dict(a, "sets"), _dict(b, "sets")]:
		for k in src:
			sets[k] = _union(sets.get(k, []), src[k])
	var times := _dict(a, "times").duplicate()
	var b_times := _dict(b, "times")
	for k in b_times:
		var t := float(b_times[k])
		if t > 0.0 and (not times.has(k) or float(times[k]) <= 0.0 or t < float(times[k])):
			times[k] = t
	for set_name in Achievements.SET_STATS:   # a set's count is its size, whatever a copy says
		if stats.has(Achievements.SET_STATS[set_name]) or sets.has(set_name):
			stats[Achievements.SET_STATS[set_name]] = (sets.get(set_name, []) as Array).size()
	var best := _dict(a, "best").duplicate()
	var b_best := _dict(b, "best")
	for k in b_best:
		best[k] = maxf(float(best.get(k, 0.0)), float(b_best[k]))
	var when := _dict(a, "completed").duplicate()
	var b_when := _dict(b, "completed")
	for k in b_when:
		var at := float(b_when[k])
		if at > 0.0 and (not when.has(k) or float(when[k]) <= 0.0 or at < float(when[k])):
			when[k] = at
	return {"stats": stats, "owned": owned, "sets": sets, "times": times, "best": best, "completed": when}


## Make `data` this computer's: the progress is taken in (it only adds, see
## Achievements.absorb) and the profile replaces this one's, each field checked.
## `keep`: write the settings file (tests leave it alone).
static func restore(data: Dictionary, keep := true) -> void:
	Achievements.absorb(_dict(data, "progress"))
	var p := _dict(data, "profile")
	if p.is_empty():
		return
	var s := Settings
	s.player_name = str(p.get("player_name", s.player_name)).strip_edges()
	var chars := []
	for id in p.get("custom_characters", []) if p.get("custom_characters") is Array else []:
		if Characters.is_custom(str(id)) and chars.size() < Settings.MAX_CUSTOM:
			chars.append(Characters.valid(str(id)))
	s.custom_characters.assign(chars)
	s.character = Characters.valid(str(p.get("character", s.character)))
	s.player_color = clampi(int(p.get("player_color", s.player_color)), -1, 15)
	s.calling_card = CallingCard.valid_card(str(p.get("calling_card", s.calling_card)))
	s.icon = CallingCard.valid_icon(str(p.get("icon", s.icon)))
	s.weapon = WeaponData.valid(str(p.get("weapon", s.weapon)))
	s.mobility = Mobility.valid(str(p.get("mobility", s.mobility)))
	var tracked := []
	for id in p.get("tracked", []) if p.get("tracked") is Array else []:
		if not str(id) in tracked:
			tracked.append(str(id))
	s.tracked_achievements.assign(tracked)
	Achievements.keep_saved()
	s.adopt_profile(float(p.get("updated_at", 0.0)))
	if keep:
		s.save_settings()


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v = d.get(key, {})
	return v if v is Dictionary else {}


static func _union(a, b) -> Array:
	var seen := {}
	var out := []
	for list in [a, b]:
		for v in list if list is Array else []:
			if not seen.has(str(v)):
				seen[str(v)] = true
				out.append(str(v))
	return out
