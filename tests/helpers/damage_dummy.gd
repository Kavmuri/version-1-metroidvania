extends CharacterBody2D

var damage_received: int = 0


func receive_damage(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	damage_received += amount
