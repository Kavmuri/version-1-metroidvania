extends Area2D

@export var target_gate_path: NodePath
@export var one_shot: bool = true
@export var toggles: bool = false

var _activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body == null or not _is_valid_player(body):
		return
	if one_shot and _activated:
		return

	var gate := get_node_or_null(target_gate_path)
	if gate != null:
		if toggles and gate.has_method("is_open") and gate.has_method("close"):
			if gate.is_open():
				gate.close()
			else:
				gate.open()
		elif gate.has_method("open"):
			gate.open()

	AudioManager.play_sfx(&"ui_confirm")
	_activated = true
	_play_activated_visual()

func _is_valid_player(body: Node2D) -> bool:
	return body.is_in_group(&"Player") or body.is_in_group(&"player") or body.name.begins_with("Player")

func _play_activated_visual() -> void:
	var sprite := get_node_or_null("Sprite") as CanvasItem
	if sprite != null:
		sprite.modulate = Color(0.55, 1.0, 0.55)
