extends Node
## The checks for tests/friends_test.gd.

var _fails: Array = []
var _calls: Array = []        ## [fn, args] the stand-in server was asked
var _reply: Dictionary = {}   ## what it answers next ({} : the state below)
var _state: Dictionary = {}
var _announced: Array = []


func run() -> void:
	var code := LobbyCode.encode("203.0.113.7")
	var code2 := LobbyCode.encode("203.0.113.8")

	# Statuses and usernames.
	_expect(Friends.status_for(false, false) == "online" and Friends.status_for(true, false) == "lobby"
		and Friends.status_for(true, true) == "match" and Friends.status_for(false, true) == "match",
		"you are online, in a lobby, or in a match (Vs Bots and Practice too)")
	_expect(Friends.status_of("lobby", 10.0) == "lobby" and Friends.status_of("lobby", Friends.ONLINE_FOR + 1.0) == "offline",
		"a friend not heard from in a while is offline")
	_expect(Friends.status_of("dancing", 5.0) == "online" and Friends.status_of("match", -1.0) == "offline",
		"an unknown status is online; never heard from is offline")
	_expect(Friends.username_error("Bolt_99") == "" and Friends.username_error("ab") != ""
		and Friends.username_error("has space") != "" and Friends.username_error("x".repeat(17)) != "",
		"usernames: 3 to 16 letters, digits or _")
	_expect(Friends.suggest("Sir Bolt!") == "Sir_Bolt" and Friends.suggest("!!") == "", "a username is suggested from your name")

	# The server's state, read safely.
	var s := Friends.parse_state({"username": "Me",
		"friends": [{"id": "z", "username": "zed", "status": "online", "seen_ago": 999},
			{"id": "b", "username": "Bea", "status": "match", "seen_ago": 3},
			{"id": "a", "username": "amy", "status": "online", "seen_ago": 3.5},
			{"id": "c", "username": "Cal", "status": "lobby", "seen_ago": 3},
			{"username": "no id"}, "junk"],
		"incoming": [{"id": "i", "username": "Ivy"}], "outgoing": [{"id": "o", "username": "Oz"}],
		"invites": [{"from": "c", "username": "Cal", "code": code}, {"from": "b", "username": "Bea", "code": "nope"}]})
	var order: Array = s.friends.map(func(f): return f.username)
	_expect(order == ["amy", "Cal", "Bea", "zed"], "friends listed online, in a lobby, in a match, offline, then by name (%s)" % [order])
	_expect(s.friends[3].status == "offline", "an old heartbeat reads as offline")
	_expect(s.incoming == [{"id": "i", "username": "Ivy"}] and s.outgoing == [{"id": "o", "username": "Oz"}], "requests both ways")
	_expect(s.invites.size() == 1 and s.invites[0].code == code, "an invite without a real lobby code is dropped")
	var empty := Friends.parse_state(null)
	_expect(empty.username == "" and empty.friends.is_empty() and Friends.parse_state({"friends": "x", "username": 5}).friends.is_empty(),
		"nonsense from the server is empty, not a crash")
	_expect(Friends.error_text({"code": 400, "data": {"code": "P0001", "message": "That username is taken"}}) == "That username is taken"
		and Friends.error_text({"code": 0, "data": null}) != "", "errors: the server's own words, or that it couldn't be reached")

	# Signed out: nothing is sent.
	Friends.server = _fake
	Friends.invited.connect(func(inv): _announced.append(inv))
	_expect(not await Friends.add("Bob") and _calls.is_empty() and not Friends.active(), "signed out, nothing is sent")

	# Signing in: the first heartbeat brings the state; no username yet.
	_sign_in(true)
	_expect(not Friends.loaded and Friends.friends.is_empty(), "signing in starts empty")
	_state = {"username": null, "friends": [], "incoming": [], "outgoing": [], "invites": []}
	_expect(await Friends.refresh() and _last() == ["friends_heartbeat", {"p_status": "online"}], "the heartbeat says what you are doing")
	_expect(Friends.loaded and Friends.username == "" and not Friends.active(), "no username yet: nothing to show")

	# Claiming a username.
	_expect(not await Friends.claim("a!") and _calls.size() == 1 and Friends.error != "", "a bad username is refused here, not sent")
	_reply = {"code": 400, "data": {"code": "P0001", "message": "That username is taken"}}
	_expect(not await Friends.claim("Taken") and _last()[0] == "claim_username" and Friends.error == "That username is taken",
		"a taken one: the server says so")
	_state.username = "Mel"
	_expect(await Friends.claim(" Mel ") and _last() == ["claim_username", {"p_name": "Mel"}] and Friends.username == "Mel"
		and Friends.error == "" and Friends.active(), "claimed: the state comes back with it")

	# Friends and requests.
	var n := _calls.size()
	_expect(not await Friends.add("  ") and not await Friends.add("mel") and _calls.size() == n, "adding nobody, or yourself, is refused here")
	await Friends.add(" Bob ")
	_expect(_last() == ["send_friend_request", {"p_name": "Bob"}], "a request goes by username")
	await Friends.accept("i")
	_expect(_last() == ["respond_friend_request", {"p_from": "i", "p_accept": true}], "accepting")
	await Friends.decline("i")
	_expect(_last() == ["respond_friend_request", {"p_from": "i", "p_accept": false}], "declining")
	await Friends.remove("o")
	_expect(_last() == ["remove_friend", {"p_id": "o"}], "removing a friend, or taking back a request")

	# Invites: sent with the lobby code; a new one is announced once.
	_state.friends = [{"id": "f1", "username": "Fay", "status": "online", "seen_ago": 2},
		{"id": "f2", "username": "Gus", "status": "online", "seen_ago": 400}]
	await Friends.refresh()
	_expect(await Friends.invite("f1", code) and _last() == ["invite_friend", {"p_id": "f1", "p_code": code}] and Friends.invited_ids.has("f1"),
		"inviting a friend sends the lobby code")
	_reply = {"code": 400, "data": {"code": "P0001", "message": "You can only invite friends"}}
	_expect(not await Friends.invite("f2", code) and not Friends.invited_ids.has("f2") and Friends.error == "You can only invite friends",
		"a refused invite is not shown as sent")
	_state.invites = [{"from": "f1", "username": "Fay", "code": code, "age": 1}]
	await Friends.refresh()
	await Friends.refresh()
	_expect(_announced.size() == 1 and _announced[0].code == code and Friends.invites.size() == 1, "a new invite is announced once")
	_state.invites = [{"from": "f1", "username": "Fay", "code": code2, "age": 0}]
	await Friends.refresh()
	_expect(_announced.size() == 2 and Friends.invites[0].code == code2, "a fresh invite (a new code) is announced again")

	# The Profile page's panel.
	var panel := FriendsPanel.new()
	add_child(panel)
	_expect(panel.find_child("add", true, false) != null and panel.find_child("me", true, false) != null, "Profile: your username and Add")
	var fay := panel.find_child("friend_Fay", true, false)
	var gus := panel.find_child("friend_Gus", true, false)
	_expect(fay != null and (fay.find_child("status", true, false) as Label).text == "Online"
		and gus != null and (gus.find_child("status", true, false) as Label).text == "Offline", "friends with what they are doing")
	_state.incoming = [{"id": "i", "username": "Ivy"}]
	await Friends.refresh()
	var ivy := panel.find_child("incoming_Ivy", true, false)
	_expect(ivy != null and ivy.find_child("accept", true, false) != null and ivy.find_child("decline", true, false) != null,
		"a request to you: Accept or Decline")
	(ivy.find_child("accept", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_expect(_last() == ["respond_friend_request", {"p_from": "i", "p_accept": true}], "Accept accepts")
	var edit := panel.find_child("edit", true, false) as LineEdit
	edit.text = "Hal"
	(panel.find_child("send", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_expect(_last() == ["send_friend_request", {"p_name": "Hal"}], "Add sends a request")
	panel.queue_free()

	# The lobby's invite window.
	var lobby_code := code
	var invite_panel := FriendsPanel.new(func(): return lobby_code)
	add_child(invite_panel)
	Friends.invited_ids.clear()
	invite_panel.show_state()
	var fay_invite: Button = invite_panel.find_child("friend_Fay", true, false).find_child("invite", true, false) as Button
	var gus_invite: Button = invite_panel.find_child("friend_Gus", true, false).find_child("invite", true, false) as Button
	_expect(fay_invite != null and not fay_invite.disabled and gus_invite != null and gus_invite.disabled,
		"the lobby: Invite beside a friend online, not one offline")
	_expect(invite_panel.find_child("add", true, false) == null and invite_panel.find_child("incoming_Ivy", true, false) == null,
		"and nothing else")
	fay_invite.pressed.emit()
	await get_tree().process_frame
	var invited: Button = invite_panel.find_child("friend_Fay", true, false).find_child("invited", true, false) as Button
	_expect(_last() == ["invite_friend", {"p_id": "f1", "p_code": code}] and invited != null and invited.disabled, "Invite invites, then says so")
	invite_panel.queue_free()

	# The main menu's invite note: the newest invite, Join, and a cross that dismisses it.
	var menu: Control = load("res://game/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var note := menu.find_child("InviteNote", true, false) as Control
	_expect(note != null and note.visible and (note.find_child("who", true, false) as Label).text == "Fay invited you"
		and note.find_child("join", true, false) != null, "the main menu shows the invite with Join")
	_expect(menu.call("join_code", "not a code") != "Connecting...", "Join goes through the lobby code join (a bad code is refused)")
	_state.invites = []   # (the server has let it go)
	(note.find_child("dismiss", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_expect(Friends.invites.is_empty() and not note.visible and _last() == ["dismiss_invite", {"p_from": "f1"}],
		"the cross dismisses it, here and on the server")
	menu.queue_free()

	# Signing out forgets it all, and the panel asks you to sign in.
	_sign_in(false)
	_expect(Friends.friends.is_empty() and Friends.username == "" and not Friends.loaded and Friends.invited_ids.is_empty(),
		"signing out forgets your friends")
	var out_panel := FriendsPanel.new()
	add_child(out_panel)
	_expect(out_panel.find_child("sign_in", true, false) != null and out_panel.find_child("friend_Fay", true, false) == null,
		"signed out: a sign-in line in its place")
	out_panel.queue_free()
	n = _calls.size()
	await Friends.refresh()
	_expect(_calls.size() == n, "and nothing more is sent")

	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


## The stand-in server: notes the call, answers with _reply once, else the state.
func _fake(fn: String, args: Dictionary) -> Dictionary:
	_calls.append([fn, args])
	if not _reply.is_empty():
		var r := _reply
		_reply = {}
		return r
	return {"code": 200, "data": _state.duplicate(true)}


func _last() -> Array:
	return _calls[-1] if not _calls.is_empty() else []


func _sign_in(yes: bool) -> void:
	Account.user_id = "me-id" if yes else ""
	Account._refresh = "r" if yes else ""
	Account.changed.emit()


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
