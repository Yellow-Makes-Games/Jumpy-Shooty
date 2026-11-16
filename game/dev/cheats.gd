class_name Cheats
extends RefCounted
## Testing cheats, switched on and off in the debug menu (F1, see DebugMenu).
##
## They only ever work offline: in Practice and in matches against bots. Online
## (hosting or joining) every check below answers false and the menu will not
## open, even for the host, so they cannot be used to cheat in a real match.
## The switches stay as they were set between matches until the game is closed.

static var god := false            ## you take no damage from shots (falling out still counts)
static var infinite_ammo := false  ## the magazine never empties and never needs reloading
static var no_cooldowns := false   ## grapple, dive and slide boost are ready again at once
static var noclip := false         ## fly through walls: WASD along the view, Space up, Ctrl / C down, Shift faster
static var freeze_bots := false    ## bots stand still and hold fire
static var show_stats := false     ## FPS, frame time, position, speed and movement state in a corner
static var time_scale := 1.0       ## game speed (slow motion below 1)


## Cheats work here: offline, in an arena (Practice or Vs Bots).
static func allowed() -> bool:
	return not Net.is_online and Game.mode != Game.Mode.ONLINE \
		and Net.multiplayer.multiplayer_peer is OfflineMultiplayerPeer


static func god_mode() -> bool:
	return god and allowed()


static func ammo() -> bool:
	return infinite_ammo and allowed()


static func cooldowns_off() -> bool:
	return no_cooldowns and allowed()


static func flying() -> bool:
	return noclip and allowed()


static func bots_frozen() -> bool:
	return freeze_bots and allowed()


## Everything back to normal.
static func reset() -> void:
	god = false
	infinite_ammo = false
	no_cooldowns = false
	noclip = false
	freeze_bots = false
	time_scale = 1.0
