extends StaticBody2D

const BLOCKING_LAYER := 1

@export var start_open: bool = false
@export var fade_duration: float = 0.4

var _is_open := false

func _ready() -> void:
	_is_open = not start_open
	if start_open:
		open()
	else:
		close()

func open() -> void:
	if _is_open:
		return
	_is_open = true
	collision_layer = 0
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.15, fade_duration)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	collision_layer = BLOCKING_LAYER
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate.a = 1.0

func is_open() -> bool:
	return _is_open
