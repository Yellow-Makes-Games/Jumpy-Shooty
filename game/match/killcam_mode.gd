class_name KillcamMode
extends RefCounted
## Killcam: a free-for-all where style wins. Everyone has the sniper rifle and nothing
## else, and every kill scores its killcam points (KillScore: range, headshots,
## momentum, flicks, trickshots...), not just 1. First to POINTS_TO_WIN, or the most
## points when the TIME_LIMIT runs out. When the match ends, whoever has the match's
## best killcam (the #1 shown on the results screen) gets BEST_BONUS on top, which
## can change the winner. Arena maps only.
##
## The host adds the points (Match.scores "points", see Match._host_kill) from the
## same score it already sends with each death, so every copy agrees.

const WEAPON := "sniper"
const POINTS_TO_WIN := 10000
const TIME_LIMIT := 10.0 * 60.0   ## seconds
const BEST_BONUS := 1500          ## for the match's #1 killcam (about three good kills)


## Is the match set up (or running) as Killcam?
static func active() -> bool:
	return str(Net.match_settings.get("mode", "")) == "killcam" and Net.game_kind() == "ffa"


## The points to win this match (--points=N overrides it, for tests).
static func target() -> int:
	return DevArgs.points_target if DevArgs.points_target > 0 else POINTS_TO_WIN


## 12,345
static func format(points: int) -> String:
	var s := str(absi(points))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if points < 0 else "") + s + out
