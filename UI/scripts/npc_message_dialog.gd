extends CanvasLayer

signal page_shown(index: int)
signal closed

const SLIDE_DURATION := 0.3

@onready var _panel: Control = $Panel
@onready var _message_label: Label = $Panel/Content/MessageLabel

var _hidden_y: float = 0.0
var _shown_y: float = 0.0
var _closing: bool = false
var _pages: Array = []
var _page_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_panel.gui_input.connect(_on_panel_gui_input)

func open_dialog(pages: Array) -> void:
	GameManager.dialogue_open = true
	_pages = pages
	_page_index = -1
	_closing = false
	await get_tree().process_frame
	_setup_positions()
	_panel.position.y = _hidden_y
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _shown_y, SLIDE_DURATION)
	_show_next_page()

func _show_next_page() -> void:
	_page_index += 1
	if _page_index >= _pages.size():
		_close_dialog()
		return
	_message_label.text = str(_pages[_page_index])
	page_shown.emit(_page_index)

func _setup_positions() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position.x = (viewport_size.x - _panel.size.x) * 0.5
	_shown_y = viewport_size.y - _panel.size.y - 12.0
	_hidden_y = viewport_size.y + 12.0

func _on_panel_gui_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()

func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	var triggered := false
	if event.is_action_pressed("ui_accept"):
		triggered = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		triggered = true

	if triggered:
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_show_next_page()

func _close_dialog() -> void:
	_closing = true
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _hidden_y, SLIDE_DURATION)
	tween.tween_callback(_on_closed)

func _on_closed() -> void:
	GameManager.dialogue_open = false
	closed.emit()
	queue_free()
