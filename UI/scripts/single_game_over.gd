extends CanvasLayer

@onready var _title: Label = $Center/Panel/Margin/Content/Title
@onready var _subtitle: Label = $Center/Panel/Margin/Content/Subtitle
@onready var _score: Label = $Center/Panel/Margin/Content/Score
@onready var _record: Label = $Center/Panel/Margin/Content/Record
@onready var _message: Label = $Center/Panel/Margin/Content/Message
@onready var _retry_button: Button = $Center/Panel/Margin/Content/Buttons/Retry
@onready var _menu_button: Button = $Center/Panel/Margin/Content/Buttons/MainMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_main_menu_pressed)
	_retry_button.grab_focus()


func setup(rooms_completed: int, best_record: int, is_new_record: bool, _selected_player: String) -> void:
	_title.text = "TIEMPO AGOTADO"
	_subtitle.text = ""
	_subtitle.hide()
	_score.text = "Salas completadas: %d" % rooms_completed
	_record.text = "Mejor marca: %d" % best_record
	if is_new_record:
		_message.text = "¡NUEVO RÉCORD! ¿Hasta dónde llegarás ahora?"
		_message.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1.0))
	elif rooms_completed == 0:
		_message.text = "Ya conoces el peligro. La próxima sala es tuya."
	else:
		_message.text = "Estuviste cerca. Vuelve y supera tu marca."


func _on_retry_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	GameManager.retry_single_run()


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	GameManager.go_to_main_menu()
