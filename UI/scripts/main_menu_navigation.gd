extends Node

var buttons: Array[Button] = []
var current_focus_index: int = 0
var parent_control: Control

func _ready() -> void:
	parent_control = get_parent() as Control
	if parent_control == null:
		push_error("NavigationController must be a child of a Control node")
		return

	# Buscar los botones en ButtonsContainer
	var buttons_container = parent_control.get_node_or_null("ButtonsContainer")
	if buttons_container == null:
		push_error("ButtonsContainer not found in main menu")
		return

	# Obtener referencia a los botones
	var play_button = buttons_container.get_node_or_null("PlayButton") as Button
	var continue_button = buttons_container.get_node_or_null("ContinueButton") as Button
	var config_button = buttons_container.get_node_or_null("ConfigButton") as Button
	var exit_button = buttons_container.get_node_or_null("ExitButton") as Button

	# Recopilar botones en orden
	buttons = [play_button, continue_button, config_button, exit_button]

	# Filtrar botones nulos y no visibles
	buttons = buttons.filter(func(b): return b != null and b.visible)

	if buttons.is_empty():
		push_error("No visible buttons found in main menu")
		return

	print("Botones encontrados: ", buttons.size())

	# Ocultar el botón de continuar si no hay guardado
	if continue_button != null and not GameManager.has_save_game():
		continue_button.visible = false
		buttons = buttons.filter(func(b): return b.visible)

	# Conectar señales de botones
	for button in buttons:
		button.focus_entered.connect(_on_button_focus_entered.bindv([button]))
		button.mouse_entered.connect(_on_button_mouse_entered.bindv([button]))

	# Establecer foco inicial
	if buttons.size() > 0:
		current_focus_index = 0
		buttons[0].grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_UP, KEY_W:
				_navigate_up()
				get_tree().root.set_input_as_handled()
			KEY_DOWN, KEY_S:
				_navigate_down()
				get_tree().root.set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				if buttons.size() > 0 and buttons[current_focus_index].has_focus():
					buttons[current_focus_index].emit_signal("pressed")
					get_tree().root.set_input_as_handled()

func _navigate_up() -> void:
	if buttons.is_empty():
		return
	current_focus_index = (current_focus_index - 1) % buttons.size()
	buttons[current_focus_index].grab_focus()

func _navigate_down() -> void:
	if buttons.is_empty():
		return
	current_focus_index = (current_focus_index + 1) % buttons.size()
	buttons[current_focus_index].grab_focus()

func _on_button_focus_entered(button: Button) -> void:
	if button in buttons:
		current_focus_index = buttons.find(button)

func _on_button_mouse_entered(button: Button) -> void:
	button.grab_focus()
