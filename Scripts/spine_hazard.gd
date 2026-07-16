extends StaticBody2D

@export var contact_damage: int = 1

@onready var _contact_area: Area2D = get_node_or_null("ContactArea") as Area2D

func _ready() -> void:
	if _contact_area != null:
		_contact_area.body_entered.connect(_on_contact_body_entered)

func _on_contact_body_entered(body: Node2D) -> void:
	if body.has_method("receive_damage"):
		body.receive_damage(contact_damage, global_position)
