extends CanvasLayer

var _open := false

@onready var _status: Label = $Status
@onready var _button_continuar: Button = $ButtonContinuar
@onready var _button_controles: Button = $ButtonControles
@onready var _button_salir: Button = $ButtonSalir
@onready var _overlay: ColorRect = $Overlay
@onready var _controls_menu: CanvasLayer = get_node_or_null("ControlsMenu") as CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	visible = false
	_apply_styles()
	_connect_buttons()

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
	if _status:
		_status.text = ""
	if _button_continuar:
		_button_continuar.grab_focus()

func _resume() -> void:
	AudioManager.play_sfx(&"ui_back")
	_open = false
	visible = false
	get_tree().paused = false

func _open_controls() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if _controls_menu != null:
		_controls_menu.open_menu()

func _go_main_menu() -> void:
	AudioManager.play_sfx(&"ui_back")
	force_close()
	GameManager.go_to_main_menu()

func force_close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	if _controls_menu != null:
		_controls_menu.visible = false
		_controls_menu.close_edit_menu()

func _connect_buttons() -> void:
	if _button_continuar:
		_button_continuar.pressed.connect(_resume)
	if _button_controles:
		_button_controles.pressed.connect(_open_controls)
	if _button_salir:
		_button_salir.pressed.connect(_go_main_menu)
	if _controls_menu:
		_controls_menu.closed.connect(func():
			if _button_controles and _button_controles.visible:
				_button_controles.grab_focus()
		)

func _apply_styles() -> void:
	if _button_continuar != null:
		_button_continuar.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.105)))
		_button_continuar.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.16, 0.19)))
		_button_continuar.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.09)))
	if _button_controles != null:
		_button_controles.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.105)))
		_button_controles.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.16, 0.19)))
		_button_controles.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.09)))
	if _button_salir != null:
		_button_salir.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.105)))
		_button_salir.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.16, 0.19)))
		_button_salir.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.09)))

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
