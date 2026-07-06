extends AnimatedSprite2D

func _ready() -> void:
	play("aparicion")
	animation_finished.connect(queue_free)
