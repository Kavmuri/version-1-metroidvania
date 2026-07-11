extends Button
class_name StyledButton

@export var banner_texture: Texture2D
@export var gradient_height: float = 12.0
@export var gradient_width: float = 140.0
@export var gradient_opacity: float = 0.6

var _sprite: Sprite2D
var _gradient_node: Node2D
var _gradient_alpha: float = 0.0
var _is_focused := false

func _ready() -> void:
	modulate = Color.WHITE
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	# Crear sprite de fondo
	_sprite = Sprite2D.new()
	_sprite.texture = banner_texture
	_sprite.centered = true
	_sprite.z_index = -1
	add_child(_sprite)
	move_child(_sprite, 0)

	# Crear nodo para el degradé
	_gradient_node = Node2D.new()
	_gradient_node.z_index = -2
	add_child(_gradient_node)
	move_child(_gradient_node, 1)

	# Conectar dibujo personalizado
	_gradient_node.draw.connect(_on_gradient_draw)

	# Actualizar posiciones
	await get_tree().process_frame
	_gradient_node.queue_redraw()

func _on_focus_entered() -> void:
	_is_focused = true
	_animate_gradient_in()
	AudioManager.play_sfx(&"ui_confirm")

func _on_focus_exited() -> void:
	_is_focused = false
	_animate_gradient_out()

func _animate_gradient_in() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "_gradient_alpha", gradient_opacity, 0.15)
	await tween.finished
	_gradient_node.queue_redraw()

func _animate_gradient_out() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "_gradient_alpha", 0.0, 0.15)
	await tween.finished
	_gradient_node.queue_redraw()

func _on_gradient_draw() -> void:
	if _gradient_alpha <= 0.0:
		return

	var size = get_rect().size
	var gradient_x = (size.x - gradient_width) / 2.0
	var gradient_y = size.y - gradient_height + 4

	# Dibujar degradé blanco de izquierda a derecha
	var steps = int(gradient_width)
	for i in range(steps):
		var ratio = float(i) / float(steps)
		# Degradé: más opaco en el centro, más transparente en los bordes
		var center_distance = abs(ratio - 0.5) * 2.0  # 0 en el centro, 1 en los bordes
		var alpha = (1.0 - center_distance) * _gradient_alpha
		var color = Color(1.0, 1.0, 1.0, alpha)

		# Dibujar línea vertical
		_gradient_node.draw_line(
			Vector2(gradient_x + i, gradient_y),
			Vector2(gradient_x + i, gradient_y + gradient_height),
			color
		)
