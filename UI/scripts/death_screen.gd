extends CanvasLayer

signal continue_requested
signal exit_requested

const RETRY_SOUND_DELAY := 0.45

@onready var _continue_button: Button = $Overlay/Panel/Content/Buttons/ContinueButton
@onready var _exit_button: Button = $Overlay/Panel/Content/Buttons/ExitButton

var _finished := false
var _retry_requested := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	_continue_button.pressed.connect(_on_continue_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_continue_button.grab_focus()

func _on_continue_pressed() -> void:
	if _finished or _retry_requested:
		return
	_retry_requested = true
	_continue_button.disabled = true
	_exit_button.disabled = true
	AudioManager.play_sfx(&"death_retry")
	await get_tree().create_timer(RETRY_SOUND_DELAY, true, false, true).timeout
	if _finished:
		return
	_finished = true
	continue_requested.emit()

func _on_exit_pressed() -> void:
	if _finished:
		return
	_finished = true
	exit_requested.emit()
