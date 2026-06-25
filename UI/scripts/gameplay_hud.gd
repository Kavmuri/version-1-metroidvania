extends CanvasLayer

var player1: Node2D = null
var player2: Node2D = null

@onready var _player1_label: Label = $Row/Player1Label
@onready var _player2_label: Label = $Row/Player2Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_player1_label.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.03, 0.04, 0.72)))
	_player2_label.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.03, 0.04, 0.72)))
	_refresh()

func setup(p1: Node2D, p2: Node2D = null) -> void:
	player1 = p1
	player2 = p2
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _player2_label == null:
		return

	if player2 == null or not is_instance_valid(player2):
		player2 = _find_node_by_name(get_tree().current_scene, "Player2")

	_player2_label.visible = player2 != null and is_instance_valid(player2)

func _find_node_by_name(root: Node, node_name: String) -> Node2D:
	if root == null:
		return null
	if root.name == node_name and root is Node2D:
		return root as Node2D
	for child in root.get_children():
		var found = _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null

func _panel_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.42, 0.78, 0.72, 0.75)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
