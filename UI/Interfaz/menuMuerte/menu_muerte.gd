extends CanvasLayer

const LOADING_SCREEN := preload("res://UI/Interfaz/PantalladeCarga/pantallaCarga.tscn")

@onready var _si_button: Button = $SI
@onready var _no_button: Button = $NO

var _buttons: Array[Button] = []
var _current_index := 0
var _arrow: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buttons = [_si_button, _no_button]

	_si_button.pressed.connect(_on_si_pressed)
	_no_button.pressed.connect(_on_no_pressed)

	for button in _buttons:
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))

	_build_arrow()
	_select_button(0)

func _build_arrow() -> void:
	_arrow = Label.new()
	_arrow.text = "▶"
	_arrow.add_theme_font_size_override("font_size", 16)
	add_child(_arrow)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.physical_keycode:
		KEY_LEFT:
			_select_button((_current_index - 1 + _buttons.size()) % _buttons.size())
		KEY_RIGHT:
			_select_button((_current_index + 1) % _buttons.size())
		KEY_ENTER, KEY_SPACE:
			_buttons[_current_index].emit_signal("pressed")

func _select_button(index: int) -> void:
	_current_index = index
	_buttons[_current_index].grab_focus()
	_position_arrow()

func _position_arrow() -> void:
	var button := _buttons[_current_index]
	_arrow.reset_size()
	_arrow.position = Vector2(
		button.position.x - _arrow.size.x - 6,
		button.position.y + button.size.y * 0.5 - _arrow.size.y * 0.5
	)

func _on_button_mouse_entered(button: Button) -> void:
	_select_button(_buttons.find(button))

func _on_si_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	var loading := LOADING_SCREEN.instantiate()
	if GameManager.has_save_game():
		loading.configure_continue_from_save()
	else:
		loading.configure_reload_current_scene()
	get_tree().root.add_child(loading)
	queue_free()

func _on_no_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	get_tree().paused = false
	GameManager.go_to_main_menu()
