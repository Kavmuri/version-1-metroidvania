extends CanvasLayer

signal loading_finished

const FADE_DURATION := 0.4

@onready var _bar: AnimatedSprite2D = $AnimatedSprite2D
@onready var _fade: ColorRect = $FadeOverlay

var _reload_current_scene := false
var _continue_from_save := false
var _next_scene_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color = Color(0, 0, 0, 1)
	_bar.animation_finished.connect(_on_bar_finished)
	_fade_in()
	_bar.play(&"default")

func configure_reload_current_scene() -> void:
	_reload_current_scene = true

func configure_continue_from_save() -> void:
	_continue_from_save = true

func configure_target_scene(scene_path: String) -> void:
	_next_scene_path = scene_path

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_DURATION)

func _on_bar_finished() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(_do_scene_change)

func _do_scene_change() -> void:
	get_tree().paused = false
	if _continue_from_save:
		GameManager.continue_game()
	elif _reload_current_scene:
		var current_scene = get_tree().current_scene
		if current_scene != null:
			var scene_path = current_scene.scene_file_path
			if not scene_path.is_empty():
				get_tree().change_scene_to_file(scene_path)
	elif not _next_scene_path.is_empty():
		get_tree().change_scene_to_file(_next_scene_path)
	loading_finished.emit()
	queue_free()
