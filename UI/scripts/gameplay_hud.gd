extends CanvasLayer

var player1: Node2D = null
var player2: Node2D = null
var boss: Node2D = null

@onready var _p1_container = $TopBar/HBox/Player1Container
@onready var _p1_name = $TopBar/HBox/Player1Container/Player1Name
@onready var _p1_health = $TopBar/HBox/Player1Container/Player1Health

@onready var _p2_container = $TopBar/HBox/Player2Container
@onready var _p2_name = $TopBar/HBox/Player2Container/Player2Name
@onready var _p2_health = $TopBar/HBox/Player2Container/Player2Health

@onready var _boss_container = $BossContainer
@onready var _boss_name = $BossContainer/BossName
@onready var _boss_health = $BossContainer/BossHealth

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	visible = true

func _process(_delta: float) -> void:
	_update_players()
	_update_boss()

func _update_players() -> void:
	if player1 == null or not is_instance_valid(player1):
		player1 = GameManager.current_player1

	if player2 == null or not is_instance_valid(player2):
		player2 = GameManager.current_player2

	if player1 != null and is_instance_valid(player1):
		_p1_container.visible = true
		_p1_health.max_value = player1.get("max_health")
		_p1_health.value = player1.get("health")
	else:
		_p1_container.visible = false

	if player2 != null and is_instance_valid(player2):
		_p2_container.visible = true
		_p2_health.max_value = player2.get("max_health")
		_p2_health.value = player2.get("health")
	else:
		_p2_container.visible = false

func _update_boss() -> void:
	if boss == null or not is_instance_valid(boss):
		_boss_container.visible = false
		return

	_boss_container.visible = true
	_boss_name.text = boss.get("boss_name") if boss.get("boss_name") else "Boss"
	_boss_health.max_value = boss.get("max_health")
	_boss_health.value = boss.get("health")

func set_boss(new_boss: Node2D) -> void:
	boss = new_boss
