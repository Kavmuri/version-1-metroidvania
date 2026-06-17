extends Area2D

@export var tipo_arma: String = "espada"   # "espada" o "pistola"
@export var color_placeholder: Color = Color(0.9, 0.6, 0.1)

func _ready():
	_construir_placeholder()
	body_entered.connect(_on_body_entered)
	# Flotación
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - 5, 0.7).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y, 0.7).set_ease(Tween.EASE_IN_OUT)

func _construir_placeholder():
	var rect = ColorRect.new()
	rect.size = Vector2(20, 20)
	rect.position = Vector2(-10, -10)
	rect.color = color_placeholder
	add_child(rect)

	var label = Label.new()
	label.text = "⚔" if tipo_arma == "espada" else "🔫"
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(-8, -30)
	add_child(label)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	col.shape = shape
	add_child(col)

func _on_body_entered(body: Node):
	if body.has_method("otorgar_arma"):
		body.otorgar_arma(tipo_arma)
		queue_free()
