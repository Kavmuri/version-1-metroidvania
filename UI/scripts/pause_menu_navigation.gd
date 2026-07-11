extends Node

var buttons: Array[Button] = []
var current_focus_index: int = 0
var parent_menu: CanvasLayer

func _ready() -> void:
	parent_menu = get_parent() as CanvasLayer
	if parent_menu == null:
		push_error("PauseMenuNavigation must be a child of PauseMenu CanvasLayer")
		return

	# Obtener referencia a los botones
	var button_continuar = parent_menu.get_node_or_null("ButtonContinuar") as Button
	var button_controles = parent_menu.get_node_or_null("ButtonControles") as Button
	var button_salir = parent_menu.get_node_or_null("ButtonSalir") as Button

	# Recopilar botones en orden
	buttons = [button_continuar, button_controles, button_salir]

	# Filtrar botones nulos y visibles
	buttons = buttons.filter(func(b): return b != null and b.visible)

	if buttons.is_empty():
		push_error("No visible buttons found in pause menu")
		return

	# Conectar señales de botones
	for button in buttons:
		button.focus_entered.connect(_on_button_focus_entered.bindv([button]))
		button.mouse_entered.connect(_on_button_mouse_entered.bindv([button]))

	# Establecer foco inicial
	if buttons.size() > 0:
		current_focus_index = 0
		buttons[0].grab_focus()

func _input(event: InputEvent) -> void:
	if parent_menu == null or not parent_menu.visible:
		return

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
