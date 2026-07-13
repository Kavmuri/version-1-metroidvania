extends Button

@export var gradient_fade_speed: float = 0.2

var _gradient_overlay: Control
var _gradient_tween: Tween

func _ready() -> void:
	# Buscar el nodo Gradient hermano o hijo
	_gradient_overlay = find_child("Gradient", true, false)
	if not _gradient_overlay:
		# Buscar por patrón de nombre que termine en "Gradient"
		for child in get_children():
			if "Gradient" in child.name:
				_gradient_overlay = child
				break

	if _gradient_overlay:
		_gradient_overlay.modulate = Color(1, 1, 1, 0)
	else:
		push_warning("No gradient overlay found for button: " + name)

func _on_focus_entered() -> void:
	if _gradient_overlay:
		if _gradient_tween:
			_gradient_tween.kill()
		_gradient_tween = create_tween()
		_gradient_tween.set_ease(Tween.EASE_OUT)
		_gradient_tween.set_trans(Tween.TRANS_QUAD)
		_gradient_tween.tween_property(_gradient_overlay, "modulate", Color(1, 1, 1, 0.7), gradient_fade_speed)
		AudioManager.play_sfx(&"ui_confirm")

func _on_focus_exited() -> void:
	if _gradient_overlay:
		if _gradient_tween:
			_gradient_tween.kill()
		_gradient_tween = create_tween()
		_gradient_tween.set_ease(Tween.EASE_OUT)
		_gradient_tween.set_trans(Tween.TRANS_QUAD)
		_gradient_tween.tween_property(_gradient_overlay, "modulate", Color(1, 1, 1, 0), gradient_fade_speed)
