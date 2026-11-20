class_name Podium
extends RefCounted
## Who stands on the results page's stage (ResultsStage) and how: worked out from a
## match's results alone, so every copy shows the same.
##
## A free-for-all: the top three, the winner in the middle and a step forward in a
## victory pose, second and third either side with a nod (a good sport's). A team
## mode: the winning team's top three scorers, all in victory poses, the best in the
## middle; a draw: each team's top scorer standing easy. A race: the first three by
## finishing order, those who ran out of time standing easy. Nobody scored: nobody
## poses.
##
##   for who in Podium.lineup(Match.last_results):
##       who.id, who.name, who.place, who.spot, who.pose, who.label
##       who.character, who.color, who.weapon   # as the match ended ("" if the row has none)

## The poses (see VictoryPoser). The first VICTORIES are the victory poses.
enum { RAISE, PUMP, HIP, PRESENT, SPORT, EASY }
const VICTORIES := 4
const NAMES := ["raise", "pump", "hip", "present", "sport", "easy"]

## Where each stands: the middle, to its left as you look at it, to its right.
enum { MIDDLE, LEFT, RIGHT }

const MOST := 3   ## this many on the stage at most


## The stage for these results (an Array of Dictionaries, the middle first; see above).
static func lineup(results: Array) -> Array:
	if results.is_empty():
		return []
	var first: Dictionary = results[0]
	var pose := victory(results)
	var out: Array = []
	if first.get("race", false):
		for i in mini(results.size(), MOST):
			var row: Dictionary = results[i]
			var done: bool = row.get("finished", false)
			out.append(_entry(row, i, (pose if i == 0 else SPORT) if done else EASY, _ordinal(i + 1) if done else "Out of time"))
		return out
	if str(first.get("teams", "")) != "":
		var scores: Array = first.get("scores", [0, 0])
		if int(scores[0]) == int(scores[1]):
			# A draw: the top scorer of each team (the rows come a team at a time, its best first).
			var seen := {}
			for row in results:
				var team := int(row.get("team", -1))
				if team < 0 or seen.has(team):
					continue
				seen[team] = true
				out.append(_entry(row, out.size(), EASY, _team_name(team)))
			if out.size() == 2:   # two, side by side: nobody in the middle
				out[0].spot = LEFT
				out[1].spot = RIGHT
			return out
		var winner := 0 if int(scores[0]) > int(scores[1]) else 1
		for row in results:
			if int(row.get("team", -1)) != winner or out.size() >= MOST:
				continue
			var n := out.size()
			out.append(_entry(row, n, (pose + n) % VICTORIES, "Top scorer" if n == 0 else _team_name(winner)))
		return out
	# A free-for-all. Nobody scored at all: nobody won.
	var scored: bool = int(first.get("kills", 0)) > 0 or int(first.get("points", 0)) > 0 or int(first.get("level", 0)) > 0
	for i in mini(results.size(), MOST):
		out.append(_entry(results[i], i, EASY if not scored else (pose if i == 0 else SPORT), _ordinal(i + 1)))
	return out


## Which victory pose this match's winner strikes: one of the four, the same on every
## copy (from the results themselves) and as good as random from one match to the next.
static func victory(results: Array) -> int:
	var mix := 17
	for row in results:
		mix = mix * 31 + int(row.get("id", 0)) * 7 + int(row.get("kills", 0)) * 13 + int(row.get("deaths", 0)) * 5 \
			+ int(row.get("points", 0)) + int(roundf(float(row.get("time", 0.0)) * 100.0))
		mix &= 0x7fffffff
	return mix % VICTORIES


static func _entry(row: Dictionary, n: int, pose: int, label: String) -> Dictionary:
	var color: Variant = row.get("color", null)
	return {"id": int(row.get("id", 0)), "name": str(row.get("name", "?")), "place": n + 1, "spot": [MIDDLE, LEFT, RIGHT][n],
		"pose": pose, "label": label, "character": str(row.get("character", "")),
		"color": Color.html(str(color)) if color is String and Color.html_is_valid(str(color)) else null,
		"weapon": str(row.get("weapon", ""))}


static func _ordinal(n: int) -> String:
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n, "th")]


static func _team_name(team: int) -> String:
	return "Red team" if team == 0 else "Blue team"
