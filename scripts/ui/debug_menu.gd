class_name DebugMenu
extends Control
## In-game editor for the session's GameConfig, its cards and its events.
## Fields are generated from exported properties, so new tuning values show
## up automatically. Edits apply to the next run and last until the game
## closes (see GameSession).

signal closed

const NOTE := "Changes apply to the next run and last until the game closes. data/GameConfig.tres is not modified."
const INVALID_COLOR := Color(1, 0.45, 0.4, 1)

## "section/property" -> editor control, e.g. "config/start_energy",
## "card/study/gloom_delta", "event/exam/check_min". Used by tests.
var fields: Dictionary[String, Control] = {}

var _list: VBoxContainer
var reset_button: Button
var close_button: Button


func _ready() -> void:
	_build_chrome()
	hide()


func open() -> void:
	rebuild()
	show()


func rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	fields.clear()
	var config := GameSession.config()
	_add_section("Game config", config, "config")
	for card: CardData in config.cards:
		_add_section("Card: %s" % card.display_name, card, "card/%s" % card.id)
	for event: EventData in config.events:
		_add_section("Event: %s" % event.display_name, event, "event/%s" % event.id)


# --- Building ---------------------------------------------------------------

func _build_chrome() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "DEBUG: GAME CONFIG"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	layout.add_child(title)

	var note := Label.new()
	note.text = NOTE
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
	layout.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	reset_button = _button("Reset to defaults")
	reset_button.pressed.connect(_on_reset)
	buttons.add_child(reset_button)
	close_button = _button("Done")
	close_button.pressed.connect(_on_close)
	buttons.add_child(close_button)


func _add_section(title: String, res: Resource, key: String) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.55, 0.75, 1, 1))
	_list.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)

	for prop: Dictionary in res.get_property_list():
		var usage: int = prop.usage
		if not (usage & PROPERTY_USAGE_EDITOR) or not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var editor := _editor_for(res, prop)
		if editor == null:
			continue
		var label := Label.new()
		label.text = String(prop.name).capitalize()
		label.custom_minimum_size = Vector2(230, 0)
		grid.add_child(label)
		editor.custom_minimum_size = Vector2(220, 0)
		grid.add_child(editor)
		fields["%s/%s" % [key, prop.name]] = editor


func _editor_for(res: Resource, prop: Dictionary) -> Control:
	var prop_name: StringName = prop.name
	var value: Variant = res.get(prop_name)
	match prop.type:
		TYPE_INT:
			if prop.hint == PROPERTY_HINT_ENUM:
				return null  # structural (event kind, checked stat), not a tuning number
			return _int_editor(res, prop_name, value)
		TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = value
			check.toggled.connect(func(on: bool) -> void: res.set(prop_name, on))
			return check
		TYPE_ARRAY:
			if value is Array and (value as Array).get_typed_builtin() == TYPE_INT:
				return _int_array_editor(res, prop_name, value)
		TYPE_OBJECT:
			if res is GameConfig and prop_name == &"final_day_event":
				return _final_event_editor(res as GameConfig)
	return null


func _int_editor(res: Resource, prop_name: StringName, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.step = 1
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = -1000
	spin.max_value = 1000
	spin.value = value
	spin.value_changed.connect(func(v: float) -> void: res.set(prop_name, int(v)))
	return spin


func _int_array_editor(res: Resource, prop_name: StringName, value: Array) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = ", ".join(value.map(func(v: int) -> String: return str(v)))
	edit.placeholder_text = "comma-separated whole numbers"
	edit.text_changed.connect(func(text: String) -> void:
		var parsed: Array[int] = []
		for part in text.split(",", false):
			var trimmed := part.strip_edges()
			if not trimmed.is_valid_int():
				edit.add_theme_color_override("font_color", INVALID_COLOR)
				return
			parsed.append(trimmed.to_int())
		edit.remove_theme_color_override("font_color")
		res.set(prop_name, parsed))
	return edit


func _final_event_editor(config: GameConfig) -> OptionButton:
	var option := OptionButton.new()
	option.add_item("(none)")
	var choices: Array[EventData] = [null]
	for event: EventData in config.check_events():
		option.add_item(event.display_name)
		choices.append(event)
	option.selected = maxi(choices.find(config.final_day_event), 0)
	option.item_selected.connect(func(i: int) -> void: config.final_day_event = choices[i])
	return option


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	return button


# --- Actions ------------------------------------------------------------------

func _on_reset() -> void:
	GameSession.reset()
	rebuild()


func _on_close() -> void:
	hide()
	closed.emit()
