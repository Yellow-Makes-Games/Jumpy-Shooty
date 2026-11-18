class_name GunGame
extends RefCounted
## Gun Game: everyone starts with the same weapon, and every kill moves you on to the
## next one on the ladder. The first player to get a kill with the last weapon (brass
## knuckles) wins. The ladder runs from the sprayers down to the sidearms: machine guns
## and rifles, shotguns, marksman rifles, explosives, then pistols and the knuckles. Being kicked to death sends you back one weapon. Arena maps only.
##
## The host keeps each player's place on the ladder in Match.scores ("level") and
## hands out the weapons (Net.host_set_weapon), so it works the same online and with bots.

const LADDER := ["minigun", "smg", "laser_rifle", "rifle", "burst_rifle", "battle_rifle", "lmg",
	"auto_shotgun", "shotgun", "break_action", "slug_shotgun", "lever_action", "crossbow", "bolt_action",
	"sniper", "anti_materiel", "railgun", "rocket_launcher", "plasma_cannon", "grenade_launcher", "nail_gun",
	"machine_pistol", "akimbo", "plasma_pistol", "revolver", "pistol", "derringer", "brass_knuckles"]
const TIME_LIMIT := 20.0 * 60.0   ## seconds; if nobody finishes, the furthest along wins


## Is the match set up (or running) Gun Game?
static func active() -> bool:
	return str(Net.match_settings.get("mode", "")) == "gungame" and Net.game_kind() == "ffa"


static func steps() -> int:
	return LADDER.size()


## The weapon for a place on the ladder (0 = the first).
static func weapon_at(level: int) -> String:
	return LADDER[clampi(level, 0, LADDER.size() - 1)]


# ---------------------------------------------------------------------------
# The menus' mode switch: Shoot-out, Gun Game, Killcam, Search and Destroy, Capture the
# Flag, Deathmatch or Race. Gun Game, Killcam and the two team modes are played on the
# arenas ("ffa" maps) with their own rules (match_settings.mode = "gungame", "killcam",
# "snd" or "ctf", see KillcamMode and Teams); Deathmatch is a game of its own ("dm", on
# the arenas with weapon pickups).

const MODES := ["ffa", "gungame", "killcam", "snd", "ctf", "dm", "race"]
const MODE_LABELS := ["Shoot-out", "Gun Game", "Killcam", "Search & Destroy", "Capture the Flag", "Deathmatch", "Race"]
## The arena modes with rules of their own (match_settings.mode).
const RULES := ["gungame", "killcam", "snd", "ctf"]


## Which of MODES these match settings are.
static func mode_of(settings: Dictionary) -> String:
	if Maps.game_of(str(settings.get("map", ""))) == "race" or str(settings.get("game", "")) == "race":
		return "race"
	if str(settings.get("game", "")) == "dm" and Maps.fits(str(settings.get("map", "")), "dm"):
		return "dm"
	var rules := str(settings.get("mode", ""))
	return rules if rules in RULES else "ffa"


## The kind of game a mode is ("ffa", "dm" or "race"; Gun Game and Killcam are kinds of "ffa").
static func game_of_mode(mode: String) -> String:
	return mode if mode in ["race", "dm"] else "ffa"


## Match settings switched to `mode` (the map changes only if it does not fit).
static func with_mode(settings: Dictionary, mode: String, map_for_game: String) -> Dictionary:
	var s := settings.duplicate()
	var game := game_of_mode(mode)
	if not Maps.fits(str(s.get("map", "")), game):
		s["map"] = map_for_game
	s["game"] = game
	if mode in RULES:
		s["mode"] = mode
	elif str(s.get("mode", "")) in RULES:
		s["mode"] = "kills"
	return s
