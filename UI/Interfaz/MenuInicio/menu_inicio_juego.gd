extends Node2D

var _any_button_pressed := false

func _ready() -> void:
	AudioManager.play_menu_music()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if _any_button_pressed:
		return

	# Detectar cualquier botón presionado
	if event is InputEventKey and event.pressed:
		_transition_to_main_menu()
		get_tree().root.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_transition_to_main_menu()
		get_tree().root.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_transition_to_main_menu()
		get_tree().root.set_input_as_handled()

func _transition_to_main_menu() -> void:
	_any_button_pressed = true
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://UI/scenes/main_menu.tscn")
