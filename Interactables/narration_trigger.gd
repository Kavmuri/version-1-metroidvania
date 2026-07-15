extends Area2D

@export_multiline var narration_text: String = ""
@export var duration: float = 3.5
@export var one_shot: bool = true

var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if narration_text.is_empty() or body == null:
		return
	if one_shot and _triggered:
		return
	if not _is_valid_player(body):
		return
	var hud := _find_gameplay_hud()
	if hud != null and hud.has_method("show_narration"):
		hud.show_narration(narration_text, duration)
	_triggered = true

func _is_valid_player(body: Node2D) -> bool:
	return body.is_in_group(&"Player") or body.is_in_group(&"player") or body.name.begins_with("Player")

func _find_gameplay_hud() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	var named_hud := current_scene.find_child("GameplayHUD", true, false)
	if named_hud != null:
		return named_hud
	return _find_node_with_method(current_scene, "show_narration")

func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null
