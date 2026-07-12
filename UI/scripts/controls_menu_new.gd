extends CanvasLayer

signal closed

@onready var _back_button: Button = $BackButton
@onready var _editar_button: Button = $EditarButton

var _edit_menu: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_back_button.pressed.connect(close_menu)
	_editar_button.pressed.connect(_open_edit_menu)

func open_menu() -> void:
	visible = true
	_back_button.grab_focus()

func close_menu() -> void:
	AudioManager.play_sfx(&"ui_back")
	visible = false
	closed.emit()

func close_edit_menu() -> void:
	if _edit_menu != null:
		_edit_menu.close_menu()

func _open_edit_menu() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	if _edit_menu == null:
		_edit_menu = preload("res://UI/scripts/edit_controls_menu.gd").new()
		add_child(_edit_menu)
	_edit_menu.open_menu()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _edit_menu != null and _edit_menu.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		close_menu()
		get_viewport().set_input_as_handled()
