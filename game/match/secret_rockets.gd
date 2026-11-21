class_name SecretRockets
extends RefCounted
## The secret code: type CODE with the arrow keys on the lobby screen (online or Vs
## Bots) and the whole lobby gets the Auto Rocket Launcher (WeaponData "auto_rocket",
## a fully automatic rocket launcher) for the next match. Anyone in the lobby can type
## it, not only the host.
##
## The code is down three times then up three times (crouch, crouch, crouch, launch),
## then left, right: ↓ ↓ ↓ ↑ ↑ ↑ ← →.
##
## The unlock is a lobby setting ("auto_rockets" in Net.match_settings, see
## LobbySettings), so it reaches every copy the same way, players who join later too.
## A player who types the code asks the host (Net.enter_secret_code); the host turns it
## on, tells everyone who found it (Net.secret_code_entered: the lobby's banner), and
## turns it off again when the match ends (Net.host_end_secret_rockets). Whoever typed
## it is handed the weapon by the host at once (so a quick Ready cannot beat it there).
##
## While it is on, the weapon is in the pickers (with the explosives) and on the death
## screen for everyone, whatever weapons the host allows; in a Deathmatch every Rocket
## Launcher on the map is an Auto Rocket Launcher instead.

const WEAPON := "auto_rocket"
const SETTING := "auto_rockets"
const CODE := [KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_UP, KEY_UP, KEY_UP, KEY_LEFT, KEY_RIGHT]
## The code as it is shown (and told to players).
const CODE_TEXT := "↓ ↓ ↓ ↑ ↑ ↑ ← →"


## Is the Auto Rocket Launcher unlocked for this lobby's match?
static func active() -> bool:
	return bool(Net.match_settings.get(SETTING, false))


## Does the match set up let players pick their own weapon in the lobby? Then whoever
## types the code is handed the weapon at once. (Not in a race, Gun Game, Killcam or a
## Deathmatch, which has every Rocket Launcher on the map fire full auto instead.)
static func handed_out() -> bool:
	return Net.game_kind() != "race" and not GunGame.active() and not KillcamMode.active() and not Net.is_deathmatch()


## Follows the arrow keys pressed, to spot the code. feed() each key press; it says
## when the code has just been completed. Any other arrow breaks the run (though it may
## start a new one); keys that are not arrows are ignored.
class Listener extends RefCounted:
	var _at := 0   # how many keys of the code are in so far

	## True when `key` finishes the code.
	func feed(key: Key) -> bool:
		if not key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			return false
		if key == CODE[_at]:
			_at += 1
		else:
			# The longest start of the code that the keys so far end with (the code
			# starts with three downs, so a fourth down still counts as three).
			var tail: Array = CODE.slice(0, _at) + [key]
			_at = 0
			for n in range(mini(tail.size(), CODE.size() - 1), 0, -1):
				if tail.slice(tail.size() - n) == CODE.slice(0, n):
					_at = n
					break
		if _at == CODE.size():
			_at = 0
			return true
		return false

	## How many keys of the code are in so far.
	func progress() -> int:
		return _at
