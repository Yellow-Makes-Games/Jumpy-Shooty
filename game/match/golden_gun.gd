class_name GoldenGun
extends RefCounted
## Golden Gun: a free-for-all where one player at a time holds the Golden Gun (WeaponData
## "golden_gun": the revolver in gold, one round, and whoever it hits dies). Everyone
## else has the weapon they picked (as the host allows, see LobbySettings). Kill the
## holder and the Golden Gun is yours. A kill with it loads the next round at once;
## a miss means a slow reload. First to the kill target wins (the host sets it).
##
## Who holds it is simply whose weapon is the Golden Gun (Net.players), so every copy,
## and anyone who joins later, already knows. The host decides (Match._host_give_golden):
## a random player at the start; then whoever kills the holder; a random other player
## if the holder dies with nobody to credit (a fall, a crash) or leaves.

const WEAPON := "golden_gun"


## Is the match set up (or running) as Golden Gun?
static func active() -> bool:
	return str(Net.match_settings.get("mode", "")) == "golden" and Net.game_kind() == "ffa"


## Who holds the Golden Gun now (0 for nobody).
static func holder() -> int:
	for id in Net.players:
		if str(Net.players[id].get("weapon", "")) == WEAPON:
			return id
	return 0


## Host: who gets the Golden Gun when `from` loses it with nobody to credit: a random
## other player, one who is alive if there is one (0 if nobody else is here).
static func pick_next(from: int) -> int:
	var others: Array = Net.players.keys().filter(func(id): return id != from)
	if others.is_empty():
		return 0
	var alive := others.filter(func(id): return Match.is_alive(id))
	var pool: Array = alive if not alive.is_empty() else others
	return pool[randi() % pool.size()]
