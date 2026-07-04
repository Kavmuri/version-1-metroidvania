extends AnimatedSprite2D

func _ready() -> void:
	play(&"death")

func _on_timer_timeout() -> void:
	queue_free()
