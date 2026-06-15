extends Area2D

@onready var forma = $CollisionShape2D

func _ready():
	# Conectamos la señal cuando algo (el jugador) entra en esta zona
	body_entered.connect(_on_body_entered)
	# Comprobamos si el jugador ya está dentro al aparecer la sala
	# Esperamos un frame para que el motor de física se active
	await get_tree().process_frame
	for body in get_overlapping_bodies():
		if body.name == "player":
			_on_body_entered(body)

func _on_body_entered(body):
	# Verificamos que el que entró fue el jugador
	if body.name == "player":
		# Conseguimos la cámara del jugador (asumiendo que es su hijo)
		var camara = body.get_node("Camera2D") 
		if camara:
			# Calculamos el tamaño real basado en la forma de colisión
			var rect_forma = forma.shape.get_rect()
			var limites_globales = Rect2(global_position + rect_forma.position, rect_forma.size)
			
			camara.actualizar_limites_camara(limites_globales)
