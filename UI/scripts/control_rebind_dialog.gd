extends CanvasLayer

signal rebind_complete(action: String, device: String)

var _action_to_rebind: String = ""
var _device_type: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	visible = false

func open_rebind_dialog(action: String, device: String) -> void:
	_action_to_rebind = action
	_device_type = device
	visible = true

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _device_type == "keyboard" and event is InputEventKey and event.pressed:
		_rebind_keyboard(event)
		get_tree().root.set_input_as_handled()
	elif _device_type == "gamepad" and event is InputEventJoypadButton and event.pressed:
		_rebind_gamepad(event)
		get_tree().root.set_input_as_handled()

func _rebind_keyboard(event: InputEventKey) -> void:
	GameManager.set_keyboard_action(_action_to_rebind, event.physical_keycode)
	await get_tree().create_timer(0.5).timeout
	_close_dialog()

func _rebind_gamepad(event: InputEventJoypadButton) -> void:
	GameManager.set_gamepad_action(_action_to_rebind, event.button_index)
	await get_tree().create_timer(0.5).timeout
	_close_dialog()

func _close_dialog() -> void:
	visible = false
	rebind_complete.emit(_action_to_rebind, _device_type)
