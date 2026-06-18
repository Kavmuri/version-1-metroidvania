extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_construir_ui()

func _construir_ui():
	# Fondo oscuro
	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.82)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	# Panel central
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(320, 180)
	panel.position -= panel.size / 2
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	panel.add_child(vbox)

	# Texto "Derrota"
	var titulo = Label.new()
	titulo.text = "DERROTA"
	titulo.add_theme_font_size_override("font_size", 42)
	titulo.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)

	# Subtítulo
	var sub = Label.new()
	sub.text = "Intentar de nuevo"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	# Botón reiniciar
	var boton = Button.new()
	boton.text = "reiniciar"
	boton.custom_minimum_size = Vector2(160, 44)
	boton.pressed.connect(_reiniciar)
	vbox.add_child(boton)

func mostrar():
	visible = true
	if get_tree():
		get_tree().paused = true

func _input(event: InputEvent):
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_reiniciar()

func _reiniciar():
	get_tree().paused = false
	queue_free()
	get_tree().reload_current_scene()
