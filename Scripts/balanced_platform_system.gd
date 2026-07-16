extends Node2D

@export var platform_left_pos: Vector2 = Vector2(-100, 0)
@export var platform_right_pos: Vector2 = Vector2(100, 0)
@export var move_speed: float = 150.0
@export var max_offset: float = 100.0
@export var platform_width: float = 80.0
@export var platform_height: float = 20.0

var platform_left: AnimatableBody2D
var platform_right: AnimatableBody2D

func _ready() -> void:
	_create_platform_left()
	_create_platform_right()
	_connect_platforms()

const PLATFORM_TEXTURE := preload("res://Tileset/area1/GAME_TILESET1.png")
const PLATFORM_REGION := Rect2(32, 16, 80, 16)
const GLOW_TEXTURE := preload("res://Assets/Fx/light_glow.png")

@export var glow_energy: float = 0.9
@export var glow_scale: float = 1.2

func _add_glow(body: AnimatableBody2D) -> void:
	var light := PointLight2D.new()
	light.name = "GlowLight"
	light.texture = GLOW_TEXTURE
	light.color = Color(1.0, 1.0, 1.0, 1.0)
	light.energy = glow_energy
	light.texture_scale = glow_scale
	body.add_child(light)

func _create_platform_left() -> void:
	platform_left = AnimatableBody2D.new()

	# Script (assigned BEFORE add_child so _ready() actually runs with it attached)
	var script = load("res://Scripts/balanced_platform_single.gd")
	platform_left.set_script(script)
	platform_left.move_speed = move_speed
	platform_left.max_offset = max_offset
	platform_left.sync_to_physics = true
	platform_left.collision_layer = 1
	platform_left.collision_mask = 0
	platform_left.position = platform_left_pos

	# Collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(platform_width, platform_height)
	collision.shape = shape
	platform_left.add_child(collision)

	# Visual
	var visual = Sprite2D.new()
	visual.texture = PLATFORM_TEXTURE
	visual.region_enabled = true
	visual.region_rect = PLATFORM_REGION
	platform_left.add_child(visual)

	# Detection area
	var detection = Area2D.new()
	detection.name = "DetectionArea"
	detection.collision_layer = 0
	detection.collision_mask = 2
	platform_left.add_child(detection)

	var det_shape = RectangleShape2D.new()
	det_shape.size = Vector2(platform_width - 4.0, platform_height + 16.0)
	var det_collision = CollisionShape2D.new()
	det_collision.shape = det_shape
	det_collision.position = Vector2(0.0, -8.0)
	detection.add_child(det_collision)

	_add_glow(platform_left)
	add_child(platform_left)

func _create_platform_right() -> void:
	platform_right = AnimatableBody2D.new()

	# Script (assigned BEFORE add_child so _ready() actually runs with it attached)
	var script = load("res://Scripts/balanced_platform_single.gd")
	platform_right.set_script(script)
	platform_right.move_speed = move_speed
	platform_right.max_offset = max_offset
	platform_right.sync_to_physics = true
	platform_right.collision_layer = 1
	platform_right.collision_mask = 0
	platform_right.position = platform_right_pos

	# Collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(platform_width, platform_height)
	collision.shape = shape
	platform_right.add_child(collision)

	# Visual
	var visual = Sprite2D.new()
	visual.texture = PLATFORM_TEXTURE
	visual.region_enabled = true
	visual.region_rect = PLATFORM_REGION
	platform_right.add_child(visual)

	# Detection area
	var detection = Area2D.new()
	detection.name = "DetectionArea"
	detection.collision_layer = 0
	detection.collision_mask = 2
	platform_right.add_child(detection)

	var det_shape = RectangleShape2D.new()
	det_shape.size = Vector2(platform_width - 4.0, platform_height + 16.0)
	var det_collision = CollisionShape2D.new()
	det_collision.shape = det_shape
	det_collision.position = Vector2(0.0, -8.0)
	detection.add_child(det_collision)

	_add_glow(platform_right)
	add_child(platform_right)

func _connect_platforms() -> void:
	# Asignar referencias cruzadas
	platform_left.paired_platform = platform_right
	platform_right.paired_platform = platform_left

	# Conectar señales de detección
	var left_detection = platform_left.get_node("DetectionArea")
	var right_detection = platform_right.get_node("DetectionArea")

	left_detection.body_entered.connect(func(body): platform_left._on_body_entered(body))
	left_detection.body_exited.connect(func(body): platform_left._on_body_exited(body))

	right_detection.body_entered.connect(func(body): platform_right._on_body_entered(body))
	right_detection.body_exited.connect(func(body): platform_right._on_body_exited(body))
