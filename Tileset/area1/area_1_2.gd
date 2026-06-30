extends Node2D

@onready var transition_rect = $TransitionLayer/ColorRect
@onready var animation_player = $TransitionLayer/AnimationPlayer

func _ready():
	transition_rect.color.a = 0
	if has_node("TransitionTrigger"):
		$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)

func _on_transition_trigger_entered(body):
	if body.name.begins_with("Player"):
		animation_player.play("fade_to_black")
