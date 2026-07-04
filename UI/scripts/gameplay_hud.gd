extends CanvasLayer

var player1: Node2D = null
var player1_name := "Kaizen"

@onready var _player1_status: Label = $TopBar/Player1Status

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	visible = player1 != null and is_instance_valid(player1)

func setup(p1: Node2D, _p2: Node2D = null, p1_name: String = "Kaizen") -> void:
	player1 = p1
	player1_name = p1_name
	visible = player1 != null and is_instance_valid(player1)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _player1_status == null:
		return

	if player1 == null or not is_instance_valid(player1):
		player1 = _find_node_by_name(get_tree().current_scene, "Player1")
		visible = player1 != null and is_instance_valid(player1)

	if not visible:
		return

	var current_health := 3
	var max_health := 3
	if player1 != null and is_instance_valid(player1):
		current_health = int(player1.get("health"))
		max_health = int(player1.get("max_health"))

	_player1_status.text = player1_name + "  HP  " + str(current_health) + "/" + str(max_health)

func _find_node_by_name(root: Node, node_name: String) -> Node2D:
	if root == null:
		return null
	if root.name == node_name and root is Node2D:
		return root as Node2D
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null
