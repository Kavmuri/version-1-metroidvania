extends Control

const ENEMY_ARENA_HOLD_SECONDS := 1.0

@onready var _center: VBoxContainer = $Center
@onready var _play_button: Button = $Center/PlayButton
@onready var _continue_button: Button = $Center/ContinueButton
@onready var _config_button: Button = $Center/ConfigButton
@onready var _exit_button: Button = $Center/ExitButton
@onready var _message_panel: PanelContainer = $MessagePanel
@onready var _message_label: Label = $MessagePanel/Content/MessageLabel
@onready var _message_ok_button: Button = $MessagePanel/Content/OkButton
@onready var _mode_panel: Control = $ModePanel
@onready var _single_button: Button = $ModePanel/Content/Options/SingleButton
@onready var _coop_button: Button = $ModePanel/Content/Options/CoopButton
@onready var _online_button: Button = $ModePanel/Content/Options/OnlineButton
@onready var _mode_back_button: Button = $ModePanel/Content/BackRow/BackButton
@onready var _character_panel: Control = $CharacterPanel
@onready var _player1_button: Button = $CharacterPanel/Content/Options/Player1Button
@onready var _player2_button: Button = $CharacterPanel/Content/Options/Player2Button
@onready var _character_back_button: Button = $CharacterPanel/Content/BackRow/BackButton
@onready var _character_start_button: Button = $CharacterPanel/Content/BackRow/StartButton
@onready var _controls_menu: CanvasLayer = $ControlsMenu

var _enemy_arena_hold_time := 0.0
var _enemy_arena_opened := false
var _online_hold_active := false
var _selected_character := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	AudioManager.play_menu_music()
	GameManager.load_controls()
	_apply_styles()
	_configure_mode_focus()
	_connect_buttons()
	_refresh_continue()
	_message_panel.visible = false
	_mode_panel.visible = false
	_character_panel.visible = false
	_character_start_button.visible = false
	await get_tree().process_frame
	_center_content()
	_play_button.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_continue()

func _process(delta: float) -> void:
	if _enemy_arena_opened:
		return
	if _online_hold_active:
		_enemy_arena_hold_time += delta
		if _enemy_arena_hold_time >= ENEMY_ARENA_HOLD_SECONDS:
			_enemy_arena_opened = true
			GameManager.open_enemy_arena()
		return
	if _message_panel.visible or _controls_menu.visible:
		_enemy_arena_hold_time = 0.0
		return
	_enemy_arena_hold_time = 0.0

func _connect_buttons() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_config_button.pressed.connect(_on_config_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_message_ok_button.pressed.connect(_close_message)
	_single_button.pressed.connect(_on_single_pressed)
	_coop_button.pressed.connect(_on_coop_pressed)
	_online_button.pressed.connect(_on_online_pressed)
	_online_button.button_down.connect(_on_online_button_down)
	_online_button.button_up.connect(_on_online_button_up)
	_mode_back_button.pressed.connect(_close_mode_panel)
	_player1_button.pressed.connect(_on_player1_pressed)
	_player2_button.pressed.connect(_on_player2_pressed)
	_character_back_button.pressed.connect(_close_character_panel)
	_character_start_button.pressed.connect(_on_character_start_pressed)
	_controls_menu.closed.connect(func(): _config_button.grab_focus())

func _apply_styles() -> void:
	for button in [_play_button, _continue_button, _config_button, _exit_button, _message_ok_button, _mode_back_button, _character_back_button, _character_start_button]:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.105)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.16, 0.19)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.09)))
		button.add_theme_stylebox_override("disabled", _button_style(Color(0.035, 0.038, 0.045)))
		button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0)))
	_apply_mode_button_styles(_single_button, Color(0.10, 0.11, 0.16, 0.94), false)
	_apply_mode_button_styles(_coop_button, Color(0.10, 0.14, 0.13, 0.94), false)
	_apply_mode_button_styles(_online_button, Color(0.08, 0.08, 0.09, 0.82), true)
	_apply_mode_button_styles(_player1_button, Color(0.10, 0.11, 0.16, 0.94), false)
	_apply_mode_button_styles(_player2_button, Color(0.10, 0.14, 0.13, 0.94), false)
	_message_panel.add_theme_stylebox_override("panel", _panel_style())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		if _controls_menu.visible:
			return
		if _message_panel.visible:
			_close_message()
			get_viewport().set_input_as_handled()
		elif _character_panel.visible:
			_close_character_panel()
			get_viewport().set_input_as_handled()
		elif _mode_panel.visible:
			_close_mode_panel()
			get_viewport().set_input_as_handled()

func _refresh_continue() -> void:
	if _continue_button == null:
		return
	_continue_button.disabled = not GameManager.has_save_game()

func _on_play_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_open_mode_panel()

func _on_single_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_open_character_panel()

func _on_player1_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_select_character("player1")

func _on_player2_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_select_character("player2")

func _on_character_start_pressed() -> void:
	if _selected_character.is_empty():
		return
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.start_new_game("single", _selected_character)

func _on_coop_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.start_new_game("coop")

func _on_online_pressed() -> void:
	pass

func _on_online_button_down() -> void:
	_online_hold_active = true
	_enemy_arena_hold_time = 0.0

func _on_online_button_up() -> void:
	_online_hold_active = false
	_enemy_arena_hold_time = 0.0

func _on_continue_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if not GameManager.continue_game():
		_show_message("No hay partida guardada.")

func _on_config_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_controls_menu.open_menu()

func _on_exit_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	get_tree().quit()

func _show_message(text: String) -> void:
	_message_label.text = text
	_message_panel.visible = true
	_center_message()
	_message_ok_button.grab_focus()

func _close_message() -> void:
	AudioManager.play_sfx(&"ui_back")
	_message_panel.visible = false
	_play_button.grab_focus()

func _open_mode_panel() -> void:
	_set_main_buttons_focus(false)
	_center.visible = false
	_character_panel.visible = false
	_mode_panel.visible = true
	_center_mode_panel()
	get_viewport().gui_release_focus()

func _close_mode_panel() -> void:
	AudioManager.play_sfx(&"ui_back")
	_online_hold_active = false
	_enemy_arena_hold_time = 0.0
	_mode_panel.visible = false
	_character_panel.visible = false
	_center.visible = true
	_set_main_buttons_focus(true)
	_play_button.grab_focus()

func _open_character_panel() -> void:
	_online_hold_active = false
	_enemy_arena_hold_time = 0.0
	_selected_character = ""
	_character_start_button.visible = false
	_mode_panel.visible = false
	_character_panel.visible = true
	_center_character_panel()
	get_viewport().gui_release_focus()

func _close_character_panel() -> void:
	_selected_character = ""
	_character_start_button.visible = false
	_character_panel.visible = false
	_mode_panel.visible = true
	_center_mode_panel()
	get_viewport().gui_release_focus()

func _select_character(character_id: String) -> void:
	_selected_character = character_id
	_character_start_button.visible = true
	_apply_mode_button_styles(_player1_button, Color(0.10, 0.11, 0.16, 0.94), false)
	_apply_mode_button_styles(_player2_button, Color(0.10, 0.14, 0.13, 0.94), false)
	var selected_button := _player1_button if character_id == "player1" else _player2_button
	selected_button.add_theme_stylebox_override("normal", _mode_button_style(Color(0.14, 0.13, 0.10, 0.96), Color(0.95, 0.79, 0.34, 1.0), 3))
	_character_start_button.grab_focus()

func _center_content() -> void:
	var viewport_size = get_viewport_rect().size
	_center.position = (viewport_size - _center.size) * 0.5 + Vector2(0, -8)
	_center_message()
	_center_mode_panel()
	_center_character_panel()

func _center_message() -> void:
	if _message_panel == null:
		return
	var viewport_size = get_viewport_rect().size
	_message_panel.position = (viewport_size - _message_panel.size) * 0.5

func _center_mode_panel() -> void:
	if _mode_panel == null:
		return
	var viewport_size = get_viewport_rect().size
	_mode_panel.position = (viewport_size - _mode_panel.size) * 0.5

func _center_character_panel() -> void:
	if _character_panel == null:
		return
	var viewport_size = get_viewport_rect().size
	_character_panel.position = (viewport_size - _character_panel.size) * 0.5

func _button_style(_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.8, 0.8, 0.8, 0.5)
	style.draw_center = false
	return style

func _apply_mode_button_styles(button: Button, base_color: Color, muted: bool) -> void:
	var normal_border := Color(0.55, 0.50, 0.64, 0.75)
	var selected_border := Color(0.95, 0.79, 0.34, 1.0)
	if muted:
		normal_border = Color(0.25, 0.25, 0.28, 0.70)
		selected_border = Color(0.55, 0.55, 0.62, 1.0)
	button.add_theme_stylebox_override("normal", _mode_button_style(base_color, normal_border, 1))
	button.add_theme_stylebox_override("hover", _mode_button_style(base_color.lightened(0.08), selected_border, 3))
	button.add_theme_stylebox_override("pressed", _mode_button_style(base_color.darkened(0.05), selected_border, 3))
	button.add_theme_stylebox_override("focus", _mode_button_style(Color(0, 0, 0, 0), selected_border, 3))

func _mode_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.border_color = Color(1, 1, 1, 0.6)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _configure_mode_focus() -> void:
	_single_button.focus_neighbor_right = _coop_button.get_path()
	_coop_button.focus_neighbor_left = _single_button.get_path()
	_coop_button.focus_neighbor_right = _online_button.get_path()
	_online_button.focus_neighbor_left = _coop_button.get_path()
	_online_button.focus_neighbor_bottom = _mode_back_button.get_path()
	_mode_back_button.focus_neighbor_top = _online_button.get_path()
	_mode_back_button.focus_neighbor_bottom = _single_button.get_path()
	_player1_button.focus_neighbor_right = _player2_button.get_path()
	_player2_button.focus_neighbor_left = _player1_button.get_path()
	_player2_button.focus_neighbor_bottom = _character_back_button.get_path()
	_character_back_button.focus_neighbor_top = _player2_button.get_path()
	_character_back_button.focus_neighbor_right = _character_start_button.get_path()
	_character_start_button.focus_neighbor_left = _character_back_button.get_path()
	_character_start_button.focus_neighbor_top = _player2_button.get_path()

func _set_main_buttons_focus(enabled: bool) -> void:
	var target_focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button in [_play_button, _continue_button, _config_button, _exit_button]:
		button.focus_mode = target_focus_mode
