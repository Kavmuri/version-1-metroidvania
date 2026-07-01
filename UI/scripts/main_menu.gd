extends Control

@onready var _center: VBoxContainer = $Center
@onready var _play_button: Button = $Center/PlayButton
@onready var _continue_button: Button = $Center/ContinueButton
@onready var _config_button: Button = $Center/ConfigButton
@onready var _soon_button: Button = $Center/SoonButton
@onready var _exit_button: Button = $Center/ExitButton
@onready var _message_panel: PanelContainer = $MessagePanel
@onready var _message_label: Label = $MessagePanel/Content/MessageLabel
@onready var _message_ok_button: Button = $MessagePanel/Content/OkButton
@onready var _mode_panel: PanelContainer = $ModePanel
@onready var _single_button: Button = $ModePanel/Content/SingleButton
@onready var _coop_button: Button = $ModePanel/Content/CoopButton
@onready var _mode_back_button: Button = $ModePanel/Content/BackButton
@onready var _controls_menu: CanvasLayer = $ControlsMenu

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
	await get_tree().process_frame
	_center_content()
	_play_button.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_continue()

func _connect_buttons() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_config_button.pressed.connect(_on_config_pressed)
	_soon_button.pressed.connect(_on_soon_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_message_ok_button.pressed.connect(_close_message)
	_single_button.pressed.connect(_on_single_pressed)
	_coop_button.pressed.connect(_on_coop_pressed)
	_mode_back_button.pressed.connect(_close_mode_panel)
	_controls_menu.closed.connect(func(): _config_button.grab_focus())

func _apply_styles() -> void:
	for button in [_play_button, _continue_button, _config_button, _soon_button, _exit_button, _message_ok_button, _single_button, _coop_button, _mode_back_button]:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.105)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.16, 0.19)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.09)))
		button.add_theme_stylebox_override("disabled", _button_style(Color(0.035, 0.038, 0.045)))
		button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0)))
	_message_panel.add_theme_stylebox_override("panel", _panel_style())
	_mode_panel.add_theme_stylebox_override("panel", _panel_style())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		if _controls_menu.visible:
			return
		if _message_panel.visible:
			_close_message()
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
	GameManager.start_new_game("single")

func _on_coop_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.start_new_game("coop")

func _on_continue_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if not GameManager.continue_game():
		_show_message("No hay partida guardada.")

func _on_config_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_controls_menu.open_menu()

func _on_soon_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_show_message("Proximamente")

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
	_mode_panel.visible = true
	_center_mode_panel()
	get_viewport().gui_release_focus()
	_single_button.grab_focus()

func _close_mode_panel() -> void:
	AudioManager.play_sfx(&"ui_back")
	_mode_panel.visible = false
	_set_main_buttons_focus(true)
	_play_button.grab_focus()

func _center_content() -> void:
	var viewport_size = get_viewport_rect().size
	_center.position = (viewport_size - _center.size) * 0.5 + Vector2(0, -8)
	_center_message()
	_center_mode_panel()

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

func _button_style(_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.8, 0.8, 0.8, 0.5)
	style.draw_center = false
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
	_single_button.focus_neighbor_top = _mode_back_button.get_path()
	_single_button.focus_neighbor_bottom = _coop_button.get_path()
	_coop_button.focus_neighbor_top = _single_button.get_path()
	_coop_button.focus_neighbor_bottom = _mode_back_button.get_path()
	_mode_back_button.focus_neighbor_top = _coop_button.get_path()
	_mode_back_button.focus_neighbor_bottom = _single_button.get_path()

func _set_main_buttons_focus(enabled: bool) -> void:
	var target_focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button in [_play_button, _continue_button, _config_button, _soon_button, _exit_button]:
		button.focus_mode = target_focus_mode
