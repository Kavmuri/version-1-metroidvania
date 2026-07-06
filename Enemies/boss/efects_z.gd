extends AnimatedSprite2D

func _ready() -> void:
	speed_scale = 0.55
	play("aparicion")
	animation_finished.connect(queue_free)
