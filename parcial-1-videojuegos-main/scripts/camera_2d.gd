extends Camera2D

@export var velocidad_movimiento: float = 600.0
@export var suavizado_asomo: float = 4.0
var offset_asomo: Vector2 = Vector2.ZERO

func _process(delta):
	# Interpolamos el offset actual hacia el objetivo definido por el jugador
	offset = offset.lerp(offset_asomo, suavizado_asomo * delta)

func actualizar_limites_camara(area_habitacion: Rect2):
	# 1. Definimos la duración y el estilo de la transición
	var duracion = 1 # Tiempo en segundos (ajústalo a tu gusto)
	
	# 2. Creamos un Tween que moverá los 4 límites al mismo tiempo
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Animamos cada límite desde su valor actual al nuevo
	tween.tween_property(self, "limit_left", int(area_habitacion.position.x), duracion)
	tween.tween_property(self, "limit_top", int(area_habitacion.position.y), duracion)
	tween.tween_property(self, "limit_right", int(area_habitacion.position.x + area_habitacion.size.x), duracion)
	tween.tween_property(self, "limit_bottom", int(area_habitacion.position.y + area_habitacion.size.y), duracion)
	
	# 4. También podemos suavizar el cambio de zoom si lo usas
	var tamano_pantalla = get_viewport_rect().size
	var zoom_x = tamano_pantalla.x / area_habitacion.size.x
	var zoom_y = tamano_pantalla.y / area_habitacion.size.y
	var zoom_objetivo = max(1.0, max(zoom_x, zoom_y))
	
	tween.tween_property(self, "zoom", Vector2(zoom_objetivo, zoom_objetivo), duracion)

	position_smoothing_enabled = true
	
	# Al cambiar de sala, reseteamos el asomo para evitar tirones
	offset_asomo = Vector2.ZERO
