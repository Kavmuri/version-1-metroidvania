extends AnimatableBody2D

signal jump_performed(player: Node)
signal occupied(player: Node)

@export var hint_flash_color: Color = Color(4.0, 4.0, 4.0, 1.0)
@export var hint_flash_duration: float = 0.12
@export var hint_flash_pause: float = 0.6

@onready var _top_detector: Area2D = get_node_or_null("TopDetector") as Area2D
@onready var _sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
@onready var _wobble_particles: CPUParticles2D = get_node_or_null("WobbleParticles") as CPUParticles2D

var _player_on_top: Node2D = null
var _hint_tween: Tween = null

func _ready() -> void:
	if _top_detector != null:
		_top_detector.body_entered.connect(_on_body_entered)
		_top_detector.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body) or _player_on_top == body:
		return
	_disconnect_current_player()
	_player_on_top = body
	if body.has_signal("jumped"):
		body.jumped.connect(_on_player_jumped)
	occupied.emit(body)

func _on_body_exited(body: Node2D) -> void:
	if body == _player_on_top:
		_disconnect_current_player()

func _disconnect_current_player() -> void:
	if _player_on_top != null and is_instance_valid(_player_on_top) and _player_on_top.has_signal("jumped"):
		if _player_on_top.jumped.is_connected(_on_player_jumped):
			_player_on_top.jumped.disconnect(_on_player_jumped)
	_player_on_top = null

func _on_player_jumped() -> void:
	if _wobble_particles != null:
		_wobble_particles.restart()
		_wobble_particles.emitting = true
	jump_performed.emit(_player_on_top)

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func play_hint_flash(times: int) -> void:
	stop_hint_flash()
	var visual: CanvasItem = _sprite if _sprite != null else self
	var normal_color: Color = visual.modulate
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	for i in times:
		_hint_tween.tween_property(visual, "modulate", hint_flash_color, hint_flash_duration)
		_hint_tween.tween_property(visual, "modulate", normal_color, hint_flash_duration)
	_hint_tween.tween_interval(hint_flash_pause)

func stop_hint_flash() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
	var visual: CanvasItem = _sprite if _sprite != null else self
	visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
