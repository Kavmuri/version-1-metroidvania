extends CanvasLayer

signal closed

const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "pause_game"]
const ACTION_LABELS := {
	"move_left": "Mover izquierda",
	"move_right": "Mover derecha",
	"jump": "Saltar",
	"dash": "Dash",
	"pause_game": "Pausa"
}

var _buttons: Dictionary = {}
var _waiting_action: String = ""

@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/Content/Scroll
@onready var _status: Label = $Panel/Content/Status
@onready var _reset_button: Button = $Panel/Content/Actions/ResetButton
@onready var _back_button: Button = $Panel/Content/Actions/BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_cache_buttons()
	_apply_styles()
	_connect_buttons()
	_refresh()
	_center_panel()

func open_menu() -> void:
	_waiting_action = ""
	visible = true
	_refresh()
	_status.text = "Selecciona una accion para reasignarla."
	await get_tree().process_frame
	_reset_scroll()
	_center_panel()
	var first_button = _buttons.get("move_left") as Button
	if first_button != null:
		first_button.grab_focus()

func close_menu() -> void:
	AudioManager.play_sfx(&"ui_back")
	_waiting_action = ""
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _waiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if not GameManager.is_keyboard_action_allowed(_waiting_action, event.physical_keycode):
				_status.text = "Las flechas no se usan. Usa WASD para movimiento."
				get_viewport().set_input_as_handled()
				return
			GameManager.set_keyboard_action(_waiting_action, event.physical_keycode)
			GameManager.save_controls()
			_waiting_action = ""
			_refresh()
			_status.text = "Control guardado."
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		close_menu()
		get_viewport().set_input_as_handled()

func _cache_buttons() -> void:
	_buttons = {
		"move_left": $Panel/Content/Scroll/Rows/MoveLeftRow/ActionButton,
		"move_right": $Panel/Content/Scroll/Rows/MoveRightRow/ActionButton,
		"jump": $Panel/Content/Scroll/Rows/JumpRow/ActionButton,
		"dash": $Panel/Content/Scroll/Rows/DashRow/ActionButton,
		"pause_game": $Panel/Content/Scroll/Rows/PauseRow/ActionButton
	}

func _connect_buttons() -> void:
	for action in ACTIONS:
		var button = _buttons[action] as Button
		button.pressed.connect(_begin_rebind.bind(action))
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close_menu)

func _begin_rebind(action: String) -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_waiting_action = action
	_status.text = "Presiona una tecla para " + ACTION_LABELS[action] + "."
	_refresh()

func _on_reset_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.reset_controls()
	_waiting_action = ""
	_refresh()
	_status.text = "Controles restablecidos."

func _refresh() -> void:
	for action in ACTIONS:
		var button = _buttons.get(action) as Button
		if button == null:
			continue
		if _waiting_action == action:
			button.text = "Esperando tecla..."
		else:
			button.text = GameManager.get_action_display(action)

func _apply_styles() -> void:
	_panel.add_theme_stylebox_override("panel", _panel_style())
	for button in _buttons.values() + [_reset_button, _back_button]:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.1, 0.13)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.17, 0.21)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.08, 0.10)))

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.055, 0.96)
	style.border_color = Color(0.42, 0.78, 0.72, 0.88)
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
	style.border_color = Color(0.36, 0.68, 0.64, 0.8)
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
	_panel.reset_size()
	_panel.position = (viewport_size - _panel.size) * 0.5

func _reset_scroll() -> void:
	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = 0
