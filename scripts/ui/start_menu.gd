class_name StartMenu
extends Control
## Title screen: Play, Settings (with the debug config menu in debug builds),
## Quit.

const GAME_SCENE := "res://scenes/main.tscn"

## Tests turn this off so pressing Play doesn't swap out the test scene.
var navigate: bool = true

@onready var main_panel: Control = %MainPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var debug_button: Button = %DebugButton
@onready var no_settings_label: Label = %NoSettingsLabel
@onready var back_button: Button = %BackButton
@onready var debug_menu: DebugMenu = %DebugMenu


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(show_settings)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	back_button.pressed.connect(show_main)
	debug_button.pressed.connect(debug_menu.open)
	var debug := GameSession.debug_tools_enabled()
	debug_button.visible = debug
	no_settings_label.visible = not debug
	show_main()


func show_main() -> void:
	main_panel.show()
	settings_panel.hide()


func show_settings() -> void:
	main_panel.hide()
	settings_panel.show()


func _on_play() -> void:
	if navigate:
		get_tree().change_scene_to_file(GAME_SCENE)
