extends CanvasLayer

var player1: Node2D = null
var _open := false

@onready var _panel: PanelContainer = $Panel
@onready var _status: Label = $Panel/Content/Status
@onready var _resume_button: Button = $Panel/Content/ResumeButton
@onready var _save_button: Button = $Panel/Content/SaveButton
@onready var _config_button: Button = $Panel/Content/ConfigButton
@onready var _main_menu_button: Button = $Panel/Content/MainMenuButton
@onready var _controls_menu: CanvasLayer = $ControlsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	visible = false
	_apply_styles()
	_connect_buttons()
	_center_panel()

func setup(p1: Node2D) -> void:
	player1 = p1

func _input(event: InputEvent) -> void:
	if _controls_menu != null and _controls_menu.visible:
		return
	if event.is_action_pressed("pause_game"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if _open:
		_resume()
	else:
		_open_menu()

func _open_menu() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_open = true
	visible = true
	get_tree().paused = true
	_status.text = ""
	_center_panel()
	_resume_button.grab_focus()

func _resume() -> void:
	AudioManager.play_sfx(&"ui_back")
	_open = false
	visible = false
	get_tree().paused = false

func _save_game() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if GameManager.save_game():
		_status.text = "Partida guardada."
	else:
		_status.text = "No se pudo guardar."

func _open_controls() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_controls_menu.open_menu()

func _go_main_menu() -> void:
	AudioManager.play_sfx(&"ui_back")
	get_tree().paused = false
	GameManager.go_to_main_menu()

func _connect_buttons() -> void:
	_resume_button.pressed.connect(_resume)
	_save_button.pressed.connect(_save_game)
	_config_button.pressed.connect(_open_controls)
	_main_menu_button.pressed.connect(_go_main_menu)
	_controls_menu.closed.connect(func(): _config_button.grab_focus())

func _apply_styles() -> void:
	_panel.add_theme_stylebox_override("panel", _panel_style())
	for button in [_resume_button, _save_button, _config_button, _main_menu_button]:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.105)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.16, 0.19)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.09)))

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.055, 0.97)
	style.border_color = Color(0.42, 0.78, 0.72, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _button_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.35, 0.67, 0.63, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _center_panel() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	_panel.position = (viewport_size - _panel.size) * 0.5
