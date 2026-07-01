extends CanvasLayer

signal continue_requested
signal exit_requested

const COUNTDOWN_SECONDS := 10.0

@onready var _counter_label: Label = $Overlay/Panel/Content/CounterLabel
@onready var _continue_button: Button = $Overlay/Panel/Content/Buttons/ContinueButton
@onready var _exit_button: Button = $Overlay/Panel/Content/Buttons/ExitButton

var _remaining_time := COUNTDOWN_SECONDS
var _finished := false
var _retry_requested := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	_continue_button.pressed.connect(_on_continue_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_update_counter()
	_continue_button.grab_focus()

func _process(delta: float) -> void:
	if _finished:
		return
	_remaining_time = max(_remaining_time - delta, 0.0)
	_update_counter()
	if _remaining_time <= 0.0:
		_finished = true
		if _retry_requested:
			continue_requested.emit()
		else:
			exit_requested.emit()

func _on_continue_pressed() -> void:
	if _finished or _retry_requested:
		return
	_retry_requested = true
	_continue_button.disabled = true
	_exit_button.disabled = true
	AudioManager.play_sfx(&"death_retry")

func _on_exit_pressed() -> void:
	if _finished:
		return
	_finished = true
	exit_requested.emit()

func _update_counter() -> void:
	_counter_label.text = "%0.3f" % _remaining_time
