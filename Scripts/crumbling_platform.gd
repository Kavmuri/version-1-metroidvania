extends AnimatableBody2D

@export var wobble_amplitude: float = 2.0
@export var wobble_speed: float = 14.0
@export var warning_flash_duration: float = 0.35
@export var flash_blinks: int = 2
@export var flash_duration: float = 0.06
@export var flash_color: Color = Color(2.5, 2.5, 2.5, 1.0)
@export var fall_distance: float = 200.0
@export var fall_duration: float = 1.2

@onready var _top_detector: Area2D = get_node_or_null("TopDetector") as Area2D
@onready var _sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var _wobble_particles: CPUParticles2D = get_node_or_null("WobbleParticles") as CPUParticles2D
@onready var _collapse_particles: CPUParticles2D = get_node_or_null("CollapseParticles") as CPUParticles2D

var _players_on_top: Dictionary = {}
var _collapsing := false
var _wobble_time: float = 0.0
var _initial_position: Vector2
var _warning_tween: Tween = null

func _ready() -> void:
	sync_to_physics = true
	_initial_position = position
	if _top_detector != null:
		_top_detector.body_entered.connect(_on_top_body_entered)
		_top_detector.body_exited.connect(_on_top_body_exited)

func _physics_process(delta: float) -> void:
	if _collapsing or _players_on_top.is_empty():
		return
	_wobble_time += delta
	var offset: float = sin(_wobble_time * wobble_speed) * wobble_amplitude
	position = _initial_position + Vector2(offset, 0.0)

func _on_top_body_entered(body: Node2D) -> void:
	if _collapsing or not _is_player_body(body):
		return
	_players_on_top[body.get_instance_id()] = true
	if _wobble_particles != null:
		_wobble_particles.emitting = true
	if _players_on_top.size() >= 2:
		_stop_warning_flash()
		_start_collapse()
	elif _players_on_top.size() == 1:
		_start_warning_flash()

func _on_top_body_exited(body: Node2D) -> void:
	_players_on_top.erase(body.get_instance_id())
	if _players_on_top.is_empty():
		if _wobble_particles != null:
			_wobble_particles.emitting = false
		_stop_warning_flash()

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func _start_warning_flash() -> void:
	if _collapsing:
		return
	var visual: CanvasItem = _sprite if _sprite != null else self
	var normal_color: Color = visual.modulate
	_warning_tween = create_tween()
	_warning_tween.set_loops()
	_warning_tween.tween_property(visual, "modulate", flash_color, warning_flash_duration)
	_warning_tween.tween_property(visual, "modulate", normal_color, warning_flash_duration)

func _stop_warning_flash() -> void:
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_tween = null
	var visual: CanvasItem = _sprite if _sprite != null else self
	visual.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _start_collapse() -> void:
	_collapsing = true
	position = _initial_position
	if _wobble_particles != null:
		_wobble_particles.emitting = false

	var visual: CanvasItem = _sprite if _sprite != null else self
	var normal_color: Color = visual.modulate
	var tween := create_tween()
	for i in flash_blinks:
		tween.tween_property(visual, "modulate", flash_color, flash_duration)
		tween.tween_property(visual, "modulate", normal_color, flash_duration)
	tween.tween_callback(_do_fall)

func _do_fall() -> void:
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _collapse_particles != null:
		_collapse_particles.emitting = true

	var visual: CanvasItem = _sprite if _sprite != null else self
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + fall_distance, fall_duration)
	tween.tween_property(visual, "modulate:a", 0.0, fall_duration)
	tween.chain().tween_callback(queue_free)
