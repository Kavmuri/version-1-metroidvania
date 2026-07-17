extends CanvasLayer

@export var player_path: NodePath
@export var target_player_name: String = "Player1"
@export var anchor_to_right_edge: bool = false
@export var right_edge_margin: float = 10.0
@export var anchor_to_bottom_center: bool = false
@export var bottom_center_margin: float = 40.0
@export var anchor_to_top_center: bool = false
@export var top_center_margin: float = 16.0
@export var flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)
@export var flash_duration: float = 0.12
@export var shake_strength: float = 6.0
@export var shake_duration: float = 0.25
@export var upgrade_flash_color: Color = Color(1.2, 2.4, 1.3, 1.0)
@export var upgrade_flash_duration: float = 0.35
@export var enable_health_bar_growth: bool = true

@onready var _hud_root: Node2D = get_node_or_null("HudRoot") as Node2D
@onready var _face_icon: Sprite2D = get_node_or_null("HudRoot/FaceFrame/FaceIcon") as Sprite2D
@onready var _health_fill: Sprite2D = get_node_or_null("HudRoot/HealthFill") as Sprite2D

var _player: Node = null
var _last_health: int = -1
var _last_max_health: int = -1
var _health_fill_full_width: float = 0.0
var _health_per_unit_width: float = 0.0
var _flash_tween: Tween = null
var _shake_tween: Tween = null

func _ready() -> void:
	if _health_fill != null:
		_health_fill_full_width = _health_fill.scale.x
	if anchor_to_right_edge:
		_apply_right_edge_anchor()
	if anchor_to_bottom_center:
		_apply_bottom_center_anchor()
	if anchor_to_top_center:
		_apply_top_center_anchor()
	_player = get_node_or_null(player_path)
	if _player == null:
		_player = _find_target_player()
	if _player != null and "health" in _player:
		_last_health = int(_player.health)
	if _player != null and "max_health" in _player:
		_last_max_health = int(_player.max_health)
		_health_per_unit_width = _health_fill_full_width / float(max(_last_max_health, 1))
	_update_bar()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_target_player()
		if _player == null:
			return
	if not ("health" in _player):
		return

	var current_health: int = int(_player.health)
	if _last_health >= 0 and current_health < _last_health:
		_play_hurt_feedback()
	_last_health = current_health

	if enable_health_bar_growth and "max_health" in _player:
		var current_max_health: int = int(_player.max_health)
		if _last_max_health >= 0 and current_max_health > _last_max_health and _health_per_unit_width > 0.0:
			_grow_health_bar(current_max_health)
		_last_max_health = current_max_health

	_update_bar()

func _grow_health_bar(new_max_health: int) -> void:
	var new_full_width: float = _health_per_unit_width * float(new_max_health)
	if _health_fill != null:
		if anchor_to_right_edge:
			var right_edge: float = _health_fill.position.x + _health_fill_full_width
			_health_fill.position.x = right_edge - new_full_width
		_health_fill_full_width = new_full_width
	_play_upgrade_feedback()

func _apply_right_edge_anchor() -> void:
	if _hud_root == null:
		return
	var face_frame: Sprite2D = _hud_root.get_node_or_null("FaceFrame") as Sprite2D
	if face_frame == null or face_frame.texture == null:
		return
	var frame_width: float = face_frame.texture.get_width() * face_frame.scale.x
	var right_extent: float = (face_frame.position.x + frame_width) * _hud_root.scale.x
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	_hud_root.position.x = viewport_width - right_edge_margin - right_extent

func _apply_bottom_center_anchor() -> void:
	if not _apply_horizontal_center():
		return
	var content_rect: Rect2 = _hud_content_rect()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_hud_root.position.y = viewport_size.y - bottom_center_margin - (content_rect.position.y + content_rect.size.y) * _hud_root.scale.y

func _apply_top_center_anchor() -> void:
	if not _apply_horizontal_center():
		return
	var content_rect: Rect2 = _hud_content_rect()
	_hud_root.position.y = top_center_margin - content_rect.position.y * _hud_root.scale.y

func _apply_horizontal_center() -> bool:
	if _hud_root == null:
		return false
	var content_rect: Rect2 = _hud_content_rect()
	if content_rect.size == Vector2.ZERO:
		return false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_hud_root.position.x = (viewport_size.x - content_rect.size.x * _hud_root.scale.x) * 0.5 - content_rect.position.x * _hud_root.scale.x
	return true

func _hud_content_rect() -> Rect2:
	var rect: Rect2 = Rect2()
	var initialized := false
	for child in _hud_root.get_children():
		if not (child is Sprite2D):
			continue
		var sprite: Sprite2D = child as Sprite2D
		if sprite.texture == null:
			continue
		var size: Vector2 = (sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size()) * sprite.scale
		var top_left: Vector2 = sprite.position if not sprite.centered else sprite.position - size * 0.5
		var sprite_rect := Rect2(top_left, size)
		rect = sprite_rect if not initialized else rect.merge(sprite_rect)
		initialized = true
	return rect

func _find_target_player() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child(target_player_name, true, false)

func _update_bar() -> void:
	if _player == null or _health_fill == null:
		return
	if not ("health" in _player) or not ("max_health" in _player):
		return
	var max_health: int = int(_player.max_health)
	if max_health <= 0:
		return
	var ratio: float = clampf(float(_player.health) / float(max_health), 0.0, 1.0)
	_health_fill.scale.x = _health_fill_full_width * ratio

func _play_hurt_feedback() -> void:
	_flash(flash_color, flash_duration)
	_shake()

func _play_upgrade_feedback() -> void:
	_flash(upgrade_flash_color, upgrade_flash_duration)

func _flash(color: Color, duration: float) -> void:
	if _face_icon == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_face_icon.modulate = Color(1, 1, 1, 1)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_face_icon, "modulate", color, 0.04)
	_flash_tween.tween_property(_face_icon, "modulate", Color(1, 1, 1, 1), duration)

func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	offset = Vector2.ZERO
	_shake_tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		var shake_offset: Vector2 = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		_shake_tween.tween_property(self, "offset", shake_offset, shake_duration / float(steps))
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, shake_duration / float(steps))
