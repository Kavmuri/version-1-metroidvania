extends Node

# ── Rutas ─────────────────────────────────────────────
const ESCENA_CARGA = "res://escenas/Interfaces/pantalla_carga.tscn"

# ── Música ────────────────────────────────────────────
@export var musica_menu: AudioStream   # arrastra tu .ogg aquí en el Inspector
@export var volumen_menu_db: float = -10.0
var _music_player: AudioStreamPlayer

# ── Colores ───────────────────────────────────────────
const C_FONDO    = Color(0.04, 0.04, 0.08)
const C_TITULO   = Color(0.85, 0.95, 1.00)
const C_SUBTIT   = Color(0.40, 0.75, 0.90)
const C_BTN_BG   = Color(0.08, 0.08, 0.16)
const C_BTN_BOR  = Color(0.25, 0.55, 0.80)
const C_BTN_HOV  = Color(0.14, 0.20, 0.35)
const C_BTN_TXT  = Color(0.85, 0.95, 1.00)
const C_VERSION  = Color(0.30, 0.30, 0.40)

# ─────────────────────────────────────────────────────
func _ready() -> void:
	_iniciar_musica()
	_construir_ui()

func _iniciar_musica() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = volumen_menu_db
	add_child(_music_player)
	if musica_menu != null:
		_music_player.stream = musica_menu
		_music_player.play()
	else:
		push_warning("MenuInicio: no hay musica_menu asignada en el Inspector.")

func _construir_ui() -> void:
	# Fondo sólido oscuro
	var fondo = ColorRect.new()
	fondo.color = C_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	# Líneas decorativas de fondo (estética sci-fi)
	var lineas = _crear_lineas_decorativas()
	add_child(lineas)

	# Contenedor central vertical
	var centro = VBoxContainer.new()
	centro.set_anchors_preset(Control.PRESET_CENTER)
	centro.custom_minimum_size = Vector2(400, 0)
	centro.add_theme_constant_override("separation", 16)
	# Se reposiciona tras un frame para tener tamaño real
	centro.set_meta("centrar", true)
	add_child(centro)

	# Título
	var titulo = Label.new()
	titulo.text = "PARCIAL 1"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 36)
	titulo.add_theme_color_override("font_color", C_TITULO)
	centro.add_child(titulo)

	# Subtítulo / tipo de juego
	var subtit = Label.new()
	subtit.text = "Metroidvania · Roguelite"
	subtit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtit.add_theme_font_size_override("font_size", 14)
	subtit.add_theme_color_override("font_color", C_SUBTIT)
	centro.add_child(subtit)

	# Espacio
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	centro.add_child(spacer)

	# Botones
	centro.add_child(_boton("JUGAR",  _on_jugar))
	centro.add_child(_boton("SALIR",  _on_salir))

	# Versión en esquina inferior derecha
	var version = Label.new()
	version.text = "v0.1  —  Prototipo"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position -= Vector2(160, 28)
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", C_VERSION)
	add_child(version)

	# Centrar el vbox después de un frame
	await get_tree().process_frame
	var vp = get_viewport().get_visible_rect().size
	centro.position = Vector2(
		(vp.x - centro.size.x) / 2.0,
		(vp.y - centro.size.y) / 2.0
	)

# ─────────────────────────────────────────────────────
func _crear_lineas_decorativas() -> Node2D:
	var n = Node2D.new()
	n.z_index = 0
	# Las líneas se dibujan en _draw — usamos un Control con draw manual
	var _rect = ColorRect.new()
	# Línea horizontal superior
	var l1 = ColorRect.new()
	l1.color = Color(C_BTN_BOR, 0.25)
	l1.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l1.custom_minimum_size = Vector2(0, 1)
	l1.position.y = 80
	# Línea horizontal inferior
	var l2 = ColorRect.new()
	l2.color = Color(C_BTN_BOR, 0.25)
	l2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l2.custom_minimum_size = Vector2(0, 1)
	l2.position.y = -80
	add_child(l1)
	add_child(l2)
	return n

# ─────────────────────────────────────────────────────
func _boton(texto: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(320, 48)
	btn.focus_mode = Control.FOCUS_NONE

	var s_normal = _estilo_boton(C_BTN_BG, C_BTN_BOR)
	var s_hover  = _estilo_boton(C_BTN_HOV, C_BTN_BOR.lightened(0.3))
	var s_press  = _estilo_boton(C_BTN_BOR.darkened(0.5), C_BTN_BOR)
	btn.add_theme_stylebox_override("normal",   s_normal)
	btn.add_theme_stylebox_override("hover",    s_hover)
	btn.add_theme_stylebox_override("pressed",  s_press)
	btn.add_theme_color_override("font_color",  C_BTN_TXT)
	btn.add_theme_font_size_override("font_size", 16)

	btn.pressed.connect(callback)
	return btn

func _estilo_boton(bg: Color, borde: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = borde
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left   = 16
	s.content_margin_right  = 16
	s.content_margin_top    = 10
	s.content_margin_bottom = 10
	return s

# ─────────────────────────────────────────────────────
func _on_jugar() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()
	get_tree().change_scene_to_file(ESCENA_CARGA)

func _on_salir() -> void:
	get_tree().quit()
