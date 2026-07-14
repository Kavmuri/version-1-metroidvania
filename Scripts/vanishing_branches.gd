extends Node2D

signal branches_vanished

@export var fade_duration: float = 2.0
@export var branches_to_fade: Array[Node2D] = []

var _is_fading: bool = false

func _ready() -> void:
	if branches_to_fade.is_empty():
		push_error("VanishingBranches: No branches assigned to fade!")

func start_vanishing() -> void:
	if not _is_fading:
		_fade_out()

func _fade_out() -> void:
	_is_fading = true

	if branches_to_fade.is_empty():
		push_error("VanishingBranches: No branches to fade!")
		return

	var tween = create_tween()
	tween.set_parallel(true)

	# Animar la desaparición de todas las ramas
	for branch in branches_to_fade:
		if is_instance_valid(branch):
			# Si tiene un material con shader, animar el parámetro alpha
			if branch.material != null and branch.material is ShaderMaterial:
				tween.tween_property(branch.material, "shader_parameter/alpha", 0.0, fade_duration)
			else:
				# Alternativa: usar modulate alpha
				tween.tween_property(branch, "modulate:a", 0.0, fade_duration)

	# Cuando termina el fade
	tween.tween_callback(func():
		branches_vanished.emit()
		# Opcional: eliminar las ramas
		for branch in branches_to_fade:
			if is_instance_valid(branch):
				branch.queue_free()
	)
