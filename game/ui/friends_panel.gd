class_name FriendsPanel
extends VBoxContainer
## Your friends (see Friends), as a section's body. Two ways:
##  - the Profile page's (invite_code empty): claim a username, add a friend by theirs,
##    answer requests, see what each friend is doing, remove one;
##  - the lobby's invite window (invite_code: a Callable giving the lobby code): your
##    friends and what they are doing, Invite beside each one online.
## Signed out, a line saying to sign in stands in its place.

const ROW_H := 34.0
const MAX_ROWS := 7   ## past this many the list scrolls

var _inviting: Callable
var _kind := ""   ## what the top shows: "signed_out", "loading", "claim" or "ready"
var _top: VBoxContainer
var _note: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _edit: LineEdit


## invite_code: for the lobby, () -> String, the code to invite friends with.
func _init(invite_code: Callable = Callable()) -> void:
	_inviting = invite_code
	add_theme_constant_override("separation", 6)
	_top = VBoxContainer.new()
	_top.add_theme_constant_override("separation", 6)
	add_child(_top)
	_note = UiKit.label(self, "", true, 13)
	_note.name = "note"
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "list"
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	Friends.changed.connect(show_state)
	show_state()


## A username is being typed in it.
func typing() -> bool:
	return _edit != null and is_instance_valid(_edit) and _edit.has_focus()


func _inviting_mode() -> bool:
	return _inviting.is_valid()


## Draw it from Friends as it is now.
func show_state() -> void:
	if not is_instance_valid(_top):
		return
	var kind := "ready"
	if not Account.signed_in():
		kind = "signed_out"
	elif not Friends.loaded:
		kind = "loading"
	elif Friends.username == "":
		kind = "claim"
	if kind != _kind:   # (kept otherwise, so a name being typed stays)
		_kind = kind
		_build_top()
	_note.text = Friends.error
	_note.visible = Friends.error != ""
	_fill_list()


func _build_top() -> void:
	UiKit.clear(_top)
	_edit = null
	match _kind:
		"signed_out":
			UiKit.label(_top, "Sign in on the Profile page to invite friends" if _inviting_mode() else "Sign in to add friends",
				true, 15).name = "sign_in"
		"loading":
			UiKit.label(_top, "...", true, 15).name = "loading"
		"claim":
			if _inviting_mode():
				UiKit.label(_top, "Pick a username on the Profile page to invite friends", true, 15).name = "claim"
			else:
				_entry("claim", "Pick a username", Friends.suggest(Settings.player_name), "Claim", Friends.claim)
		"ready":
			if not _inviting_mode():
				var me := UiKit.label(_top, "@" + Friends.username, false, 15)
				me.name = "me"
				me.add_theme_color_override("font_color", UiKit.CYAN)
				_entry("add", "Add by username", "", "Add", func(n: String) -> bool:
					var ok: bool = await Friends.add(n)
					if ok and _edit:
						_edit.text = ""
					return ok)


## A box and a button beside it that sends what is typed (Enter does too).
func _entry(id: String, placeholder: String, value: String, text: String, send: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = id
	row.add_theme_constant_override("separation", 8)
	_top.add_child(row)
	_edit = UiKit.line_edit(row, placeholder, value)
	_edit.name = "edit"
	_edit.max_length = 24
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var go := func():
		if _edit and _edit.text.strip_edges() != "":
			send.call(_edit.text)
	_edit.text_submitted.connect(func(_t: String): go.call())
	var b := UiKit.button(row, text, go)
	b.name = "send"


func _fill_list() -> void:
	UiKit.clear(_list)
	var rows := 0
	if _kind == "ready":
		if not _inviting_mode():
			for r in Friends.incoming:
				_row(r.username, "Wants to be friends", UiKit.ACCENT,
					[["Accept", Friends.accept.bind(r.id), true], ["Decline", Friends.decline.bind(r.id), false]]).name = "incoming_" + r.username
				rows += 1
		for f in Friends.friends:
			var actions := []
			if _inviting_mode():
				var invited: bool = Friends.invited_ids.has(f.id)
				var can: bool = f.status != "offline" and not invited and str(_inviting.call()) != ""
				actions.append(["Invited" if invited else "Invite", func(): Friends.invite(f.id, str(_inviting.call())), can])
			else:
				actions.append(["Remove", Friends.remove.bind(f.id), false])
			_row(f.username, Friends.STATUS_NAMES[f.status], Friends.STATUS_COLORS[f.status], actions).name = "friend_" + f.username
			rows += 1
		if not _inviting_mode():
			for r in Friends.outgoing:
				_row(r.username, "Request sent", Friends.STATUS_COLORS.offline, [["Cancel", Friends.remove.bind(r.id), false]]).name = "outgoing_" + r.username
				rows += 1
		if rows == 0:
			UiKit.label(_list, "No friends yet", true, 14).name = "none"
			rows = 1
	_scroll.visible = rows > 0
	_scroll.custom_minimum_size.y = minf(rows, MAX_ROWS) * (ROW_H + 4.0)


## A friend's row: a dot in their status's colour, their name, what they are doing,
## and buttons ([text, on_press, lit]; Invite lit is one that can be pressed).
func _row(who: String, what: String, color: Color, actions: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_H
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var name_label := UiKit.label(row, who, false, 15)
	name_label.name = "name"
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var state := UiKit.label(row, what, true, 13)
	state.name = "status"
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.clip_text = true
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for a in actions:
		var b := UiKit.button(row, str(a[0]), a[1])
		b.name = str(a[0]).to_lower()
		b.theme_type_variation = "Chip"
		b.custom_minimum_size = Vector2(0, ROW_H - 4.0)
		b.add_theme_font_size_override("font_size", 13)
		if _inviting_mode():
			b.disabled = not bool(a[2])
	return row
