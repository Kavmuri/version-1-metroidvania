extends Node2D

var viewport_size: Vector2

func _ready() -> void:
	viewport_size = get_viewport_rect().size
	queue_redraw()

func _draw() -> void:
	var width = viewport_size.x
	var height = viewport_size.y

	# Gradiente muy tenue de negro a morado #9f33ff
	# Comienza desde la mitad y se extiende hacia abajo
	var gradient_start_y = height * 0.5
	var gradient_end_y = height
	var gradient_height = gradient_end_y - gradient_start_y

	# Color morado objetivo: #9f33ff
	var morado_r = float(0x9f) / 255.0  # ~159/255 = 0.624
	var morado_g = float(0x33) / 255.0  # ~51/255 = 0.2
	var morado_b = float(0xff) / 255.0  # 255/255 = 1.0

	# Crear gradiente punto por punto con transparencia gradual
	var steps = 40
	for i in range(steps):
		var ratio = float(i) / float(steps)
		var y = gradient_start_y + (gradient_height * ratio)
		var next_y = gradient_start_y + (gradient_height * (float(i + 1) / float(steps)))

		# Interpolación del color y opacidad (muy tenue)
		var alpha = ratio * 0.12  # Máximo 12% de opacidad (muy tenue)
		var current_color = Color(
			morado_r * ratio,
			morado_g * ratio,
			morado_b * ratio,
			alpha
		)

		# Dibujar rectángulo horizontal
		draw_rect(Rect2(0, y, width, next_y - y), current_color)
