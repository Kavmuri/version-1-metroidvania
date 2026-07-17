extends Node2D

@export var player_path: NodePath
@export var flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)
@export var flash_duration: float = 0.12
@export var shake_strength: float = 4.0
@export var shake_duration: float = 0.25

const SEGMENT_NAMES: Array[StringName] = [&"redbar0", &"redbar4", &"redbar3", &"redbar2", &"redbar"]

@onready var _cara: Node2D = get_node_or_null("cara") as Node2D
@onready var _segments: Array[Sprite2D] = _resolve_segments()

var _player: Node = null
var _last_health: int = -1
var _base_position: Vector2 = Vector2.ZERO
var _flash_tween: Tween = null
var _shake_tween: Tween = null

func _ready() -> void:
	_base_position = position
	_player = get_node_or_null(player_path)
	if _player == null:
		_player = _find_player1()
	if _player != null and "health" in _player:
		_last_health = int(_player.health)
	_update_bar()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player1()
		if _player == null:
			return
	if not ("health" in _player):
		return

	var current_health: int = int(_player.health)
	if _last_health >= 0 and current_health < _last_health:
		_play_hurt_feedback()
	_last_health = current_health
	_update_bar()

func _find_player1() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Player1", true, false)

func _resolve_segments() -> Array[Sprite2D]:
	var segments: Array[Sprite2D] = []
	for seg_name in SEGMENT_NAMES:
		var node: Sprite2D = get_node_or_null(String(seg_name)) as Sprite2D
		if node != null:
			segments.append(node)
	return segments

func _update_bar() -> void:
	if _player == null or not ("health" in _player) or not ("max_health" in _player):
		return
	var max_health: int = int(_player.max_health)
	if max_health <= 0 or _segments.is_empty():
		return
	var ratio: float = clampf(float(_player.health) / float(max_health), 0.0, 1.0)
	var visible_count: int = int(ceil(ratio * _segments.size()))
	for i in range(_segments.size()):
		_segments[i].visible = i < visible_count

func _play_hurt_feedback() -> void:
	_flash()
	_shake()

func _flash() -> void:
	if _cara == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_cara.modulate = Color(1, 1, 1, 1)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_cara, "modulate", flash_color, 0.04)
	_flash_tween.tween_property(_cara, "modulate", Color(1, 1, 1, 1), flash_duration)

func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	position = _base_position
	_shake_tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		var offset: Vector2 = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		_shake_tween.tween_property(self, "position", _base_position + offset, shake_duration / float(steps))
	_shake_tween.tween_property(self, "position", _base_position, shake_duration / float(steps))
