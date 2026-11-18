@tool
extends Node
## The map tools' small windows: Hollow, Mirror, Array, a name for a prefab and a new
## kind for the palette. Each asks its question and calls back with the answer.

var _hollow: ConfirmationDialog
var _hollow_thickness: SpinBox
var _hollow_open: CheckBox
var _hollow_floor: CheckBox
var _hollow_done := Callable()

var _mirror: ConfirmationDialog
var _mirror_axis: OptionButton
var _mirror_about: OptionButton
var _mirror_copy: CheckBox
var _mirror_done := Callable()

var _array: ConfirmationDialog
var _array_shape: OptionButton
var _array_count: SpinBox
var _array_vec: Array[SpinBox] = []
var _array_vec_label: Label
var _array_count_label: Label
var _array_done := Callable()

var _name: ConfirmationDialog
var _name_edit: LineEdit
var _name_done := Callable()

var _kind: ConfirmationDialog
var _kind_edit: LineEdit
var _kind_color: ColorPickerButton
var _kind_done := Callable()

var _message: AcceptDialog


func _init() -> void:
	# Hollow
	_hollow = _dialog("Hollow", func() -> void: _hollow_done.call(_hollow_thickness.value, _hollow_open.button_pressed, _hollow_floor.button_pressed))
	var grid := _grid(_hollow)
	_hollow_thickness = _spin(0.05, 10.0, 0.05, 0.25, "m")
	_row(grid, "Wall thickness", _hollow_thickness)
	_hollow_open = CheckBox.new()
	_row(grid, "Leave the top open", _hollow_open)
	_hollow_floor = CheckBox.new()
	_row(grid, "Leave the floor out", _hollow_floor)

	# Mirror
	_mirror = _dialog("Mirror", func() -> void: _mirror_done.call(_mirror_axis.get_selected_id(), _mirror_about.selected == 1, _mirror_copy.button_pressed))
	grid = _grid(_mirror)
	_mirror_axis = OptionButton.new()
	_mirror_axis.add_item("Left to right (across x)", 0)
	_mirror_axis.add_item("Front to back (across z)", 2)
	_row(grid, "Mirror", _mirror_axis)
	_mirror_about = OptionButton.new()
	_mirror_about.add_item("The middle of the map")
	_mirror_about.add_item("The middle of the selection")
	_row(grid, "About", _mirror_about)
	_mirror_copy = CheckBox.new()
	_mirror_copy.button_pressed = true
	_row(grid, "Keep the original (make a copy)", _mirror_copy)

	# Array
	_array = _dialog("Array", func() -> void: _array_done.call(_array_shape.selected == 1, int(_array_count.value),
		Vector3(_array_vec[0].value, _array_vec[1].value, _array_vec[2].value)))
	grid = _grid(_array)
	_array_shape = OptionButton.new()
	_array_shape.add_item("In a line")
	_array_shape.add_item("Round a circle")
	_array_shape.item_selected.connect(func(_i: int) -> void:
		for s in _array_vec:
			s.value = 0.0   # a spacing is not a middle, nor the other way round
		_array_labels())
	_row(grid, "Copies", _array_shape)
	_array_count = _spin(1, 200, 1, 3, "")
	_array_count_label = _row(grid, "", _array_count)
	var vec := HBoxContainer.new()
	for i in 3:
		var s := _spin(-1000.0, 1000.0, 0.05, 0.0, "")
		s.prefix = ["x", "y", "z"][i]
		_array_vec.append(s)
		vec.add_child(s)
	_array_vec_label = _row(grid, "", vec)
	_array_labels()

	# A name (for a prefab)
	_name = _dialog("Save Selection as Prefab", func() -> void: _name_done.call(_name_edit.text.strip_edges()))
	grid = _grid(_name)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 240
	_row(grid, "Name", _name_edit)
	_name.register_text_enter(_name_edit)

	# A new kind
	_kind = _dialog("Add Kind to the Palette", func() -> void: _kind_done.call(_kind_edit.text.strip_edges(), _kind_color.color))
	grid = _grid(_kind)
	_kind_edit = LineEdit.new()
	_kind_edit.custom_minimum_size.x = 200
	_row(grid, "Name", _kind_edit)
	_kind_color = ColorPickerButton.new()
	_kind_color.custom_minimum_size = Vector2(80, 28)
	_kind_color.color = Color(0.6, 0.6, 0.6)
	_row(grid, "Colour", _kind_color)
	_kind.register_text_enter(_kind_edit)

	_message = AcceptDialog.new()
	_message.title = "Map Tools"
	add_child(_message)


func _dialog(title: String, confirmed: Callable) -> ConfirmationDialog:
	var d := ConfirmationDialog.new()
	d.title = title
	d.confirmed.connect(confirmed)
	add_child(d)
	return d


func _grid(dialog: ConfirmationDialog) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	dialog.add_child(grid)
	return grid


func _row(grid: GridContainer, text: String, control: Control) -> Label:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	grid.add_child(control)
	return label


func _spin(low: float, high: float, step: float, value: float, suffix: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value = value
	s.suffix = suffix
	s.custom_minimum_size.x = 90
	return s


func _array_labels() -> void:
	var ring := _array_shape.selected == 1
	_array_count_label.text = "How many in all, round the circle" if ring else "How many copies"
	_array_vec_label.text = "The circle's middle (in the map)" if ring else "From each to the next (metres)"
	_array_vec[1].editable = not ring


## done(thickness, open_top, no_floor)
func ask_hollow(thickness: float, done: Callable) -> void:
	_hollow_done = done
	_hollow_thickness.value = thickness
	_hollow.popup_centered()


## done(axis (0 or 2), about_selection, copy)
func ask_mirror(done: Callable) -> void:
	_mirror_done = done
	_mirror.popup_centered()


## done(round_a_circle, count, offset or middle)
func ask_array(spacing: float, done: Callable) -> void:
	_array_done = done
	if _array_shape.selected == 0 and _array_vec[0].value == 0.0 and _array_vec[1].value == 0.0 and _array_vec[2].value == 0.0:
		_array_vec[0].value = spacing
	_array.popup_centered()


## done(name)
func ask_name(done: Callable) -> void:
	_name_done = done
	_name_edit.text = ""
	_name.popup_centered()
	_name_edit.grab_focus()


## done(name, colour)
func ask_kind(done: Callable) -> void:
	_kind_done = done
	_kind_edit.text = ""
	_kind.popup_centered()
	_kind_edit.grab_focus()


func tell(text: String) -> void:
	_message.dialog_text = text
	_message.popup_centered()
