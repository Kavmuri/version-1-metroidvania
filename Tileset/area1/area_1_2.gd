extends Node2D

@onready var transition_rect = $TransitionLayer/ColorRect
@onready var animation_player = $TransitionLayer/AnimationPlayer
@onready var player = $Player1

func _ready():
	transition_rect.color.a = 0
	$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)

func _on_transition_trigger_entered(body):
	# Using 'Player' class name if it exists, otherwise checking for group or script
	if body.name.begins_with("Player"):
		animation_player.play("fade_to_black")
