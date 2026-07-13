extends CanvasLayer

const KEYBOARD_ACTIONS: Array[String] = ["move_left", "move_right", "jump", "crouch", "aim_up", "dash", "pause_game"]
const GAMEPAD_ACTIONS: Array[String] = ["jump", "attack", "crouch", "aim_up"]

const ACTION_LABELS := {
	"move_left": "Mover izquierda",
	"move_right": "Mover derecha",
	"jump": "Saltar",
	"crouch": "Agacharse",
	"aim_up": "Apuntar arriba",
	"dash": "Dash",
	"attack": "Atacar",
	"pause_game": "Pausa"
}

const GAMEPAD_ICONS := {
	0: "A", 1: "B", 2: "X", 3: "Y",
	4: "Back", 5: "Guide", 6: "Start",
	7: "L3", 8: "R3", 9: "LB", 10: "RB",
	11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"
}

var _device := "keyboard"
var _waiting_action := ""

var _panel: PanelContainer
var _status: Label
var _keyboard_tab: Button
var _gamepad_tab: Button
var _actions_list: VBoxContainer
var _reset_button: Button
var _back_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	visible = false
	_build_ui()
	_keyboard_tab.pressed.connect(func(): _set_device("keyboard"))
	_gamepad_tab.pressed.connect(func(): _set_device("gamepad"))
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close_menu)
	_set_device("keyboard")

func open_menu() -> void:
	visible = true
	_waiting_action = ""
	_refresh_rows()
	_center_panel()
	_back_button.grab_focus()

func close_menu() -> void:
	visible = false
	_waiting_action = ""

func _set_device(device: String) -> void:
	_device = device
	_waiting_action = ""
	_keyboard_tab.button_pressed = device == "keyboard"
	_gamepad_tab.button_pressed = device == "gamepad"
	_status.text = "Selecciona una accion para reasignar."
	_refresh_rows()

func _actions_for_device() -> Array[String]:
	return KEYBOARD_ACTIONS if _device == "keyboard" else GAMEPAD_ACTIONS

func _refresh_rows() -> void:
	for child in _actions_list.get_children():
		child.queue_free()

	for action in _actions_for_device():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 36)
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(160, 0)
		row.add_child(label)

		var binding_label := Label.new()
		binding_label.text = _binding_text(action)
		binding_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(binding_label)

		var assign_button := Button.new()
		assign_button.text = "Asignar"
		assign_button.custom_minimum_size = Vector2(90, 28)
		assign_button.pressed.connect(func(): _begin_waiting(action))
		row.add_child(assign_button)

		_actions_list.add_child(row)

func _binding_text(action: String) -> String:
	if _device == "keyboard":
		return GameManager.get_action_display(action)
	var events = InputMap.action_get_events(action + "_JOY")
	for event in events:
		if event is InputEventJoypadButton:
			return GAMEPAD_ICONS.get(event.button_index, "Boton " + str(event.button_index))
	return "Sin asignar"

func _begin_waiting(action: String) -> void:
	_waiting_action = action
	var device_text := "una tecla" if _device == "keyboard" else "un boton del mando"
	_status.text = "Presiona " + device_text + " para: " + ACTION_LABELS.get(action, action)

func _on_reset_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.reset_controls()
	_status.text = "Controles de teclado reseteados."
	_refresh_rows()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _waiting_action == "":
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
			close_menu()
			get_viewport().set_input_as_handled()
		return

	if _device == "keyboard" and event is InputEventKey and event.pressed:
		var keycode: int = event.physical_keycode
		if GameManager.is_keyboard_action_allowed(_waiting_action, keycode):
			GameManager.set_keyboard_action(_waiting_action, keycode)
			GameManager.save_controls()
			_status.text = ACTION_LABELS.get(_waiting_action, _waiting_action) + " asignado."
			_waiting_action = ""
			_refresh_rows()
		else:
			_status.text = "Tecla no permitida para esta accion."
		get_viewport().set_input_as_handled()
	elif _device == "gamepad" and event is InputEventJoypadButton and event.pressed:
		GameManager.set_gamepad_action(_waiting_action, event.button_index)
		_status.text = ACTION_LABELS.get(_waiting_action, _waiting_action) + " asignado."
		_waiting_action = ""
		_refresh_rows()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 320)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	var title := Label.new()
	title.text = "Editar Controles"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)

	var device_row := HBoxContainer.new()
	device_row.alignment = BoxContainer.ALIGNMENT_CENTER
	device_row.add_theme_constant_override("separation", 8)
	content.add_child(device_row)

	_keyboard_tab = Button.new()
	_keyboard_tab.text = "Teclado"
	_keyboard_tab.toggle_mode = true
	_keyboard_tab.custom_minimum_size = Vector2(120, 32)
	device_row.add_child(_keyboard_tab)

	_gamepad_tab = Button.new()
	_gamepad_tab.text = "Mando"
	_gamepad_tab.toggle_mode = true
	_gamepad_tab.custom_minimum_size = Vector2(120, 32)
	device_row.add_child(_gamepad_tab)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	content.add_child(scroll)

	_actions_list = VBoxContainer.new()
	_actions_list.add_theme_constant_override("separation", 6)
	_actions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_actions_list)

	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 12)
	content.add_child(buttons_row)

	_reset_button = Button.new()
	_reset_button.text = "Resetear"
	_reset_button.custom_minimum_size = Vector2(120, 32)
	buttons_row.add_child(_reset_button)

	_back_button = Button.new()
	_back_button.text = "Volver"
	_back_button.custom_minimum_size = Vector2(120, 32)
	buttons_row.add_child(_back_button)

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

func _center_panel() -> void:
	_panel.reset_size()
	var viewport_size = get_viewport().get_visible_rect().size
	_panel.position = (viewport_size - _panel.size) * 0.5
