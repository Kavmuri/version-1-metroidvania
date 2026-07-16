extends CanvasLayer

signal answered(confirmed: bool)

const SLIDE_DURATION := 0.35
const SAVING_FEEDBACK_TIME := 0.6

@onready var _panel: Control = $Panel
@onready var _yes_button: Button = $Panel/Content/ButtonsRow/YesButton
@onready var _no_button: Button = $Panel/Content/ButtonsRow/NoButton
@onready var _status_label: Label = $Panel/Content/StatusLabel

var _hidden_y: float = 0.0
var _shown_y: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_yes_button.pressed.connect(_on_yes_pressed)
	_no_button.pressed.connect(_on_no_pressed)
	_yes_button.focus_neighbor_right = _no_button.get_path()
	_no_button.focus_neighbor_left = _yes_button.get_path()

func open_dialog() -> void:
	_status_label.text = "Guardar progreso?"
	_yes_button.disabled = false
	_no_button.disabled = false
	await get_tree().process_frame
	_setup_positions()
	_panel.position.y = _hidden_y
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _shown_y, SLIDE_DURATION)
	_yes_button.grab_focus()

func _setup_positions() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position.x = (viewport_size.x - _panel.size.x) * 0.5
	_shown_y = viewport_size.y - _panel.size.y - 12.0
	_hidden_y = viewport_size.y + 12.0

func close_dialog() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _hidden_y, SLIDE_DURATION)
	tween.tween_callback(queue_free)

func _on_yes_pressed() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	_status_label.text = "Guardando..."
	_yes_button.disabled = true
	_no_button.disabled = true
	answered.emit(true)
	await get_tree().create_timer(SAVING_FEEDBACK_TIME).timeout
	close_dialog()

func _on_no_pressed() -> void:
	AudioManager.play_sfx(&"ui_back")
	answered.emit(false)
	close_dialog()
