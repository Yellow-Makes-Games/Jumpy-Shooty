class_name EmotePicker
extends HBoxContainer
## The Emotes page's body (main menu > Profile > Emotes): your character on a stage
## trying on whatever the mouse is over, the six slots of your emote wheel (pick a slot,
## then the emote to put in it: one already on the wheel changes places), every emote,
## and the victory pose you strike on the results page (Random by default). Your picks
## are saved, and the pose is sent to the lobby if you are in one.

signal picked   ## a slot or the victory pose was changed

const STAGE := Vector2(380, 470)
const SLOT_NAMES := ["Top", "Upper right", "Lower right", "Bottom", "Lower left", "Upper left"]

var status: Label            ## what to do, or what was just picked
var saves := true            ## write the picks to the settings file (tests: false)
var slot := 0                ## the slot an emote goes into next

var _preview: RobotPreview
var _poser: EmotePoser
var _slots: Array = []       # the six slot buttons
var _emotes := {}            # emote id -> its button
var _poses := {}             # victory pose choice (a name, or Podium.RANDOM) -> its button
var _hover := ""             # what the mouse is over: "emote:wave", "pose:raise", or ""


func _init() -> void:
	add_theme_constant_override("separation", 28)
	_preview = RobotPreview.new(STAGE, 1.0, true)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_preview)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	add_child(side)

	UiKit.section(side, "Your wheel")
	var wheel := GridContainer.new()
	wheel.columns = 3
	wheel.add_theme_constant_override("h_separation", 8)
	wheel.add_theme_constant_override("v_separation", 8)
	side.add_child(wheel)
	for i in Emote.SLOTS:
		var b := _button(wheel, "", func(): choose_slot(i))
		b.name = "slot_%d" % i
		b.toggle_mode = true
		b.mouse_entered.connect(func(): _hover = "emote:" + str(Emote.wheel(Settings.emote_wheel)[i]))
		b.mouse_exited.connect(func(): _hover = "")
		_slots.append(b)
	UiKit.section(side, "Emotes")
	var all := GridContainer.new()
	all.columns = 4
	all.add_theme_constant_override("h_separation", 8)
	all.add_theme_constant_override("v_separation", 8)
	side.add_child(all)
	for id in Emote.LIST:
		var b := _button(all, Emote.name_of(id), func(): put(id))
		b.name = "emote_" + id
		b.mouse_entered.connect(func(): _hover = "emote:" + id)
		b.mouse_exited.connect(func(): _hover = "")
		_emotes[id] = b
	UiKit.section(side, "Victory pose")
	var poses := GridContainer.new()
	poses.columns = 5
	poses.add_theme_constant_override("h_separation", 8)
	side.add_child(poses)
	for choice in [Podium.RANDOM] + Podium.NAMES.slice(0, Podium.VICTORIES):
		var title: String = "Random" if choice == Podium.RANDOM else Podium.TITLES[Podium.NAMES.find(choice)]
		var b := _button(poses, title, func(): choose_pose(choice))
		b.name = "pose_" + choice
		b.toggle_mode = true
		b.mouse_entered.connect(func(): _hover = "pose:" + choice)
		b.mouse_exited.connect(func(): _hover = "")
		_poses[choice] = b
	status = UiKit.label(side, "", true, 15)
	_refresh()
	_say("Hold %s in a match for the wheel. Pick a slot, then the emote to put in it." % _key())


func _ready() -> void:
	_preview.show_robot(Game.local_character(), Net.menu_color(), Game.local_weapon())
	_poser = EmotePoser.new(_preview.robot(), _preview.fx())
	_preview.set_poser(_poser)


## The slot the next emote picked goes into.
func choose_slot(i: int) -> void:
	slot = clampi(i, 0, Emote.SLOTS - 1)
	_refresh()
	_say("%s slot: now pick the emote to put in it." % SLOT_NAMES[slot])


## Put an emote in the chosen slot. One already on the wheel changes places with what
## was there (the wheel never holds the same one twice).
func put(id: String) -> void:
	if not Emote.valid(id):
		return
	var wheel := Emote.wheel(Settings.emote_wheel)
	var was := wheel.find(id)
	if was >= 0:
		wheel[was] = wheel[slot]
	wheel[slot] = id
	Settings.emote_wheel = wheel
	if saves:
		Settings.save_settings()
	_refresh()
	_say("%s is on the %s slot." % [Emote.name_of(id), SLOT_NAMES[slot].to_lower()])
	picked.emit()


## The victory pose you strike when you win (a name from Podium.NAMES, or Podium.RANDOM).
func choose_pose(choice: String) -> void:
	Settings.victory_pose = Podium.valid_choice(choice)
	if saves:
		Settings.save_settings()
	if Net.players.has(Net.my_id()):
		Net.set_my_victory(Settings.victory_pose)
	_refresh()
	_say("Victory pose: %s." % (_poses[Settings.victory_pose] as Button).text.to_lower())
	picked.emit()


func _process(_delta: float) -> void:
	if _poser == null:
		return
	# The stage shows what the mouse is over; otherwise the emote in the chosen slot.
	var show := _hover if _hover != "" else "emote:" + str(Emote.wheel(Settings.emote_wheel)[slot])
	if show.begins_with("pose:"):
		var kind := Podium.NAMES.find(show.trim_prefix("pose:"))
		if kind >= 0:
			_poser.show_pose(kind)
		else:
			_poser.show_nothing()   # (Random: it could be any of them)
	else:
		_poser.show_emote(show.trim_prefix("emote:"))
	var robot := _preview.robot()
	if robot != null:
		robot.rotation.y = _poser.spin()


func _refresh() -> void:
	var wheel := Emote.wheel(Settings.emote_wheel)
	for i in _slots.size():
		var b: Button = _slots[i]
		b.text = "%s\n%s" % [SLOT_NAMES[i].to_upper(), Emote.name_of(wheel[i])]
		b.set_pressed_no_signal(i == slot)
	for id in _emotes:
		(_emotes[id] as Button).modulate = Color.WHITE if id in wheel else Color(1, 1, 1, 0.62)
		(_emotes[id] as Button).tooltip_text = "On your wheel" if id in wheel else "Not on your wheel"
	for choice in _poses:
		(_poses[choice] as Button).set_pressed_no_signal(choice == Podium.valid_choice(Settings.victory_pose))


func _say(words: String) -> void:
	status.text = words


func _button(parent: Node, words: String, on_press: Callable) -> Button:
	var b := UiKit.button(parent, words, on_press)
	b.custom_minimum_size = Vector2(150, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.set_meta("sfx", "select")
	return b


## The key the wheel is on, as the Controls tab names it.
static func _key() -> String:
	var bound: Array = Settings.bindings.get("emote", [])
	return Settings.binding_text(str(bound[0])) if not bound.is_empty() else "the emote key"
