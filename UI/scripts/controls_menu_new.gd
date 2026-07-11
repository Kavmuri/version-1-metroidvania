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

const GAMEPAD_ICONS := {
	1: "A",
	2: "B",
	3: "X",
	4: "Y",
	5: "LB",
	6: "RB",
	7: "Back",
	8: "Start",
}

var _rebind_dialog: CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _back_button: Button = $Panel/Content/ButtonsRow/BackButton
@onready var _reset_button: Button = $Panel/Content/ButtonsRow/ResetButton
@onready var _keyboard_container: VBoxContainer = $Panel/Content/MainContainer/RightPanel/KeyboardSection/KeyboardContainer
@onready var _gamepad_container: VBoxContainer = $Panel/Content/MainContainer/LeftPanel/GamepadSection/GamepadContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_apply_styles()
	_connect_signals()
	_build_controls_display()

func _build_controls_display() -> void:
	# Limpiar contenedores
	for child in _keyboard_container.get_children():
		child.queue_free()
	for child in _gamepad_container.get_children():
		child.queue_free()

	# Construir filas de controles
	for action in ACTIONS:
		# Fila de teclado
		var keyboard_row = _create_keyboard_row(action)
		_keyboard_container.add_child(keyboard_row)

		# Fila de mando
		var gamepad_row = _create_gamepad_row(action)
		_gamepad_container.add_child(gamepad_row)

func _create_keyboard_row(action: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)
	row.add_theme_constant_override("separation", 12)

	# Label del control
	var label = Label.new()
	label.text = ACTION_LABELS[action]
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)

	# Display de la tecla con icono
	var key_display_container = HBoxContainer.new()
	key_display_container.custom_minimum_size = Vector2(80, 0)
	key_display_container.add_theme_constant_override("separation", 4)

	var key_icon = TextureRect.new()
	key_icon.texture = load("res://UI/Interfaz/controlesUI/kb_dark_all.png")
	key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_icon.custom_minimum_size = Vector2(32, 32)
	key_display_container.add_child(key_icon)

	var key_label = Label.new()
	key_label.text = GameManager.get_action_display(action)
	key_display_container.add_child(key_label)

	row.add_child(key_display_container)

	# Botón Editar
	var edit_button = Button.new()
	edit_button.text = "Editar"
	edit_button.custom_minimum_size = Vector2(70, 32)
	edit_button.pressed.connect(func():
		_open_rebind_dialog(action, "keyboard")
	)
	row.add_child(edit_button)

	return row

func _create_gamepad_row(action: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)
	row.add_theme_constant_override("separation", 12)

	# Label del control
	var label = Label.new()
	label.text = ACTION_LABELS[action]
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)

	# Display del botón del mando con icono
	var button_display_container = HBoxContainer.new()
	button_display_container.custom_minimum_size = Vector2(80, 0)
	button_display_container.add_theme_constant_override("separation", 4)

	var button_icon = TextureRect.new()
	button_icon.texture = load("res://UI/Interfaz/controlesUI/controller_xbox.png")
	button_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	button_icon.custom_minimum_size = Vector2(32, 32)
	button_display_container.add_child(button_icon)

	var button_label = Label.new()
	button_label.text = _get_gamepad_display(action)
	button_display_container.add_child(button_label)

	row.add_child(button_display_container)

	# Botón Editar
	var edit_button = Button.new()
	edit_button.text = "Editar"
	edit_button.custom_minimum_size = Vector2(70, 32)
	edit_button.pressed.connect(func():
		_open_rebind_dialog(action, "gamepad")
	)
	row.add_child(edit_button)

	return row

func _get_gamepad_display(action: String) -> String:
	var gamepad_action = action + "_JOY"
	var events = InputMap.action_get_events(gamepad_action)
	if events.is_empty():
		return "Sin asignar"

	for event in events:
		if event is InputEventJoypadButton:
			return GAMEPAD_ICONS.get(event.button_index, str(event.button_index))

	return "Sin asignar"

func _open_rebind_dialog(action: String, device: String) -> void:
	if _rebind_dialog == null:
		_rebind_dialog = preload("res://UI/scripts/control_rebind_dialog.gd").new()
		_rebind_dialog.rebind_complete.connect(_on_rebind_complete)
		add_child(_rebind_dialog)

	_rebind_dialog.open_rebind_dialog(action, device)

func _on_rebind_complete(action: String, device: String) -> void:
	_build_controls_display()

func _connect_signals() -> void:
	_back_button.pressed.connect(close_menu)
	_reset_button.pressed.connect(_reset_controls)

func open_menu() -> void:
	visible = true
	_center_panel()
	_back_button.grab_focus()

func close_menu() -> void:
	AudioManager.play_sfx(&"ui_back")
	visible = false
	closed.emit()

func _reset_controls() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.reset_controls()
	_build_controls_display()

func _center_panel() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	_panel.position = (viewport_size - _panel.size) * 0.5

func _apply_styles() -> void:
	_panel.add_theme_stylebox_override("panel", _panel_style())

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
