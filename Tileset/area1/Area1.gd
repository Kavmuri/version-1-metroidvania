extends Node2D

@onready var transition_rect = $TransitionLayer/ColorRect
@onready var animation_player = $TransitionLayer/AnimationPlayer
@onready var parallax_bg = $ParallaxBackground2
@onready var parallax_bg3 = $ParallaxBackground3
@onready var player = $Player1

const MAP_END_X = 1632
var _parallax_stopped = false

func _ready():
	transition_rect.color.a = 0
	$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)

func _process(_delta):
	if not _parallax_stopped and player.global_position.x >= MAP_END_X - 100:
		_stop_parallax()

func _on_transition_trigger_entered(body):
	if body is Player:
		animation_player.play("fade_to_black")
		if not _parallax_stopped:
			_stop_parallax()

func _stop_parallax():
	_parallax_stopped = true
	# Disabling mirroring
	# Check existence of background nodes to avoid crashes if they don't exist
	var backgrounds = []
	if has_node("ParallaxBackground2"):
		backgrounds.append(parallax_bg)
	if has_node("ParallaxBackground3"):
		backgrounds.append(parallax_bg3)

	for bg in backgrounds:
		for child in bg.get_children():
			if child is ParallaxLayer:
				child.motion_mirroring = Vector2.ZERO
