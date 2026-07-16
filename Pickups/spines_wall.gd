extends Area2D

@export var required_orbs: int = 2
@export var blink_speed: float = 1.5
@export var blink_energy: float = 1.4
@export var branch_pieces: Array[NodePath] = []

@onready var _prompt_panel: Control = get_node_or_null("PromptPanel") as Control
@onready var _count_label: Label = get_node_or_null("PromptPanel/Row/CountLabel") as Label
@onready var _solid_body: StaticBody2D = get_node_or_null("SolidBody") as StaticBody2D
@onready var _blink_light: PointLight2D = get_node_or_null("BlinkLight") as PointLight2D

var _players_in_range: int = 0
var _collected_orbs: int = 0
var _opened := false
var _blink_time: float = 0.0
var _branch_piece_nodes: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt_panel != null:
		_prompt_panel.visible = false
	_update_count_label()
	for path in branch_pieces:
		var piece := get_node_or_null(path)
		if piece != null:
			_branch_piece_nodes.append(piece)

func _process(delta: float) -> void:
	if _opened or _blink_light == null:
		return
	_blink_time += delta
	var pulse: float = (sin(_blink_time * blink_speed) * 0.5) + 0.5
	_blink_light.energy = blink_energy * pow(pulse, 3.0)

func _on_body_entered(body: Node2D) -> void:
	if _opened or not _is_player_body(body):
		return
	_players_in_range += 1
	if _prompt_panel != null:
		_prompt_panel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_in_range = max(_players_in_range - 1, 0)
	if _players_in_range == 0 and _prompt_panel != null:
		_prompt_panel.visible = false

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func register_orb_completed() -> void:
	if _opened:
		return
	_collected_orbs = min(_collected_orbs + 1, required_orbs)
	_update_count_label()
	if _collected_orbs >= required_orbs:
		_open_wall()

func _update_count_label() -> void:
	if _count_label != null:
		_count_label.text = "%d/%d" % [_collected_orbs, required_orbs]

func _open_wall() -> void:
	_opened = true
	if _prompt_panel != null:
		_prompt_panel.visible = false
	set_deferred("monitoring", false)
	if _solid_body != null:
		_solid_body.set_deferred("collision_layer", 0)
	if _blink_light != null:
		_blink_light.visible = false
	for piece in _branch_piece_nodes:
		if piece.has_method("open"):
			piece.open()
