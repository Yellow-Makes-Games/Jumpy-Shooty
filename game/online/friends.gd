extends Node
## Friends, for signed-in players (see Account): a unique username to be found by,
## friend requests (accept or decline), what each friend is doing (online, in a lobby,
## in a match, or offline), and a host inviting a friend into their lobby. Signed out,
## all of this is empty and nothing is sent.
##
##   Friends.active()           signed in, with a username: friends can be shown
##   Friends.claim("Name")      take a username (or change yours)
##   Friends.add("Name")        ask someone to be friends
##   Friends.accept(id) / decline(id) / remove(id)
##   Friends.invite(id, code)   the host: ask a friend into the lobby with this code
##   Friends.dismiss(invite)    done with an invite (joined, or not wanted)
##
## Everything goes through the database's functions (supabase/migrations/
## 20261121000000_friends.sql) with Account.call_function. One request does it all:
## friends_heartbeat says what you are doing and brings back the whole state (your
## username, friends, requests, invites), every POLL seconds while signed in, and
## sooner when what you are doing changes. Every change brings the state back too.
## A friend the game has not heard from in ONLINE_FOR seconds is offline.

signal changed                       ## the state came in, or something went wrong
signal invited(invite: Dictionary)   ## a new invite: {from, username, code}

const POLL := 15.0         ## seconds between heartbeats
const ONLINE_FOR := 45.0   ## heard from this recently: online
const STATUSES := ["online", "lobby", "match", "offline"]   ## the order friends are listed in
const STATUS_NAMES := {"online": "Online", "lobby": "In a lobby", "match": "In a match", "offline": "Offline"}
const STATUS_COLORS := {"online": Color(0.4, 0.9, 0.45), "lobby": Color(0.4, 0.9, 1.0),
	"match": Color(1.0, 0.55, 0.2), "offline": Color(0.45, 0.48, 0.55)}
const USERNAME_MIN := 3
const USERNAME_MAX := 16

var username := ""
## [{id, username, status}], online first, then by name.
var friends: Array = []
## Requests to you, and from you: [{id, username}].
var incoming: Array = []
var outgoing: Array = []
## Invites to you, newest first: [{from, username, code}].
var invites: Array = []
## Friends invited from this lobby: id -> true (the lobby shows "Invited").
var invited_ids: Dictionary = {}
var error := ""          ## the last thing that went wrong (a taken username, no such player...)
var loaded := false      ## the state has come in since signing in

## (fn: String, args: Dictionary) -> {code, data}: Account.call_function, or a test's stand-in.
var server: Callable

var _poll_in := 0.0
var _status_sent := ""
var _polling := false
var _seen := {}          ## invites already announced: "from|code" -> true
var _was_signed_in := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	server = Account.call_function
	Account.changed.connect(_on_account_changed)


## Signed in, the state is in, and you have a username: friends can be shown.
func active() -> bool:
	return Account.signed_in() and loaded and username != ""


func _on_account_changed() -> void:
	var now_in := Account.signed_in()
	if now_in == _was_signed_in:
		return
	_was_signed_in = now_in
	clear()
	_poll_in = 0.0   # signed in: ask straight away
	changed.emit()


## Forget everything (signed out).
func clear() -> void:
	username = ""
	friends = []
	incoming = []
	outgoing = []
	invites = []
	invited_ids = {}
	error = ""
	loaded = false
	_seen = {}
	_status_sent = ""


func _process(delta: float) -> void:
	if not Account.available() or not Account.signed_in() or _polling:
		return
	if loaded and username == "":
		return   # nothing to show or be seen by until a username is claimed
	if my_status() != _status_sent:
		_poll_in = minf(_poll_in, 1.0)   # what you are doing changed: tell your friends soon
	_poll_in -= delta
	if _poll_in <= 0.0:
		refresh()


## What you are doing, for your friends: "match", "lobby" or "online".
func my_status() -> String:
	return status_for(Net.is_online, Net.in_match or Net.arena != null)


static func status_for(online: bool, playing: bool) -> String:
	if playing:
		return "match"
	return "lobby" if online else "online"


## A friend's status from what the server says: offline once not heard from in a while.
static func status_of(status: String, seen_ago: float) -> String:
	if seen_ago < 0.0 or seen_ago > ONLINE_FOR:
		return "offline"
	return status if status in ["online", "lobby", "match"] else "online"


## What is wrong with a username ("" if nothing): 3 to 16 letters, digits or _.
static func username_error(wanted: String) -> String:
	var n := wanted.strip_edges()
	var re := RegEx.create_from_string("^[A-Za-z0-9_]{%d,%d}$" % [USERNAME_MIN, USERNAME_MAX])
	if re.search(n) == null:
		return "Usernames are %d to %d letters, digits or _" % [USERNAME_MIN, USERNAME_MAX]
	return ""


## A username made from a display name, to start the claim box with.
static func suggest(display_name: String) -> String:
	var re := RegEx.create_from_string("[^A-Za-z0-9_]")
	var n := re.sub(display_name.strip_edges().replace(" ", "_"), "", true).left(USERNAME_MAX)
	return n if n.length() >= USERNAME_MIN else ""


## The server's state (friends_state) made safe: every field there and of the right
## kind, friends' statuses worked out and sorted, invites with a bad code dropped.
static func parse_state(d) -> Dictionary:
	var data: Dictionary = d if d is Dictionary else {}
	var out := {"username": str(data.get("username")) if data.get("username") is String else "",
		"friends": [], "incoming": [], "outgoing": [], "invites": []}
	for f in _list(data, "friends"):
		out.friends.append({"id": str(f.get("id", "")), "username": str(f.get("username", "")),
			"status": status_of(str(f.get("status", "")), _num(f.get("seen_ago"), -1.0))})
	out.friends.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := STATUSES.find(a.status)
		var sb := STATUSES.find(b.status)
		if sa != sb:
			return sa < sb
		return a.username.to_lower() < b.username.to_lower())
	for k in ["incoming", "outgoing"]:
		for f in _list(data, k):
			out[k].append({"id": str(f.get("id", "")), "username": str(f.get("username", ""))})
	for i in _list(data, "invites"):
		var code := str(i.get("code", "")).strip_edges()
		if code == "" or LobbyCode.parse(code).error != "":
			continue
		out.invites.append({"from": str(i.get("from", "")), "username": str(i.get("username", "")), "code": code})
	return out


static func _list(d: Dictionary, key: String) -> Array:
	var out := []
	var v = d.get(key)
	for item in v if v is Array else []:
		if item is Dictionary and str(item.get("id", item.get("from", ""))) != "":
			out.append(item)
	return out


static func _num(v, fallback: float) -> float:
	return float(v) if v is float or v is int else fallback


## A server error as a line for the player: the function's own message ("That username
## is taken"), else what went wrong with the request.
static func error_text(r: Dictionary) -> String:
	if r.get("data") is Dictionary and str(r.data.get("code", "")) == "P0001" and r.data.has("message"):
		return str(r.data.message)
	if int(r.get("code", 0)) == 0:
		return "Couldn't reach the server"
	return Account._error_text(r)


## Take a state from the server: announce invites not seen before.
func take(data) -> void:
	var s := parse_state(data)
	username = s.username
	friends = s.friends
	incoming = s.incoming
	outgoing = s.outgoing
	invites = s.invites
	loaded = true
	var seen := {}
	for inv in invites:
		var key := "%s|%s" % [inv.from, inv.code]
		seen[key] = true
		if not _seen.has(key):
			invited.emit(inv)
	_seen = seen
	changed.emit()


## The friend with this id, or {}.
func friend(id: String) -> Dictionary:
	for f in friends:
		if f.id == id:
			return f
	return {}


# ---------------------------------------------------------------------------
# Asking the server (each true if it went through)

## The heartbeat: say what you are doing, get the state back.
func refresh() -> bool:
	_polling = true
	var status := my_status()
	var ok := await _call("friends_heartbeat", {"p_status": status})
	_polling = false
	if ok:
		_status_sent = status
	return ok


func claim(wanted: String) -> bool:
	var bad := username_error(wanted)
	if bad != "":
		return _refuse(bad)
	return await _call("claim_username", {"p_name": wanted.strip_edges()})


func add(wanted: String) -> bool:
	var n := wanted.strip_edges()
	if n == "":
		return _refuse("Type their username")
	if n.to_lower() == username.to_lower():
		return _refuse("That's you")
	return await _call("send_friend_request", {"p_name": n})


func accept(id: String) -> bool:
	return await _call("respond_friend_request", {"p_from": id, "p_accept": true})


func decline(id: String) -> bool:
	return await _call("respond_friend_request", {"p_from": id, "p_accept": false})


## Remove a friend, or take back a request you sent.
func remove(id: String) -> bool:
	invited_ids.erase(id)
	return await _call("remove_friend", {"p_id": id})


func invite(id: String, code: String) -> bool:
	if code == "":
		return _refuse("The lobby has no code yet")
	invited_ids[id] = true
	changed.emit()
	var ok := await _call("invite_friend", {"p_id": id, "p_code": code})
	if not ok:
		invited_ids.erase(id)
		changed.emit()
	return ok


## Done with an invite: it goes from the list now, and from the server.
func dismiss(inv: Dictionary) -> bool:
	invites = invites.filter(func(i): return i.from != inv.get("from"))
	changed.emit()
	return await _call("dismiss_invite", {"p_from": str(inv.get("from", ""))})


func _refuse(why: String) -> bool:
	error = why
	changed.emit()
	return false


func _call(fn: String, args: Dictionary) -> bool:
	if not Account.signed_in() or not server.is_valid():
		return false
	var r = await server.call(fn, args)
	_poll_in = POLL
	if not Account.signed_in():
		return false   # signed out while it was on its way
	if r is Dictionary and int(r.get("code", 0)) == 200 and r.get("data") is Dictionary:
		error = ""
		take(r.data)
		return true
	error = error_text(r if r is Dictionary else {})
	changed.emit()
	return false
