extends CanvasLayer

var player1: Node2D = null
var player2: Node2D = null
var boss: Node2D = null
var player1_name := "Kaizen"
var player2_name := "Eldric"
var _heart_full_texture: Texture2D
var _heart_two_thirds_texture: Texture2D
var _heart_one_third_texture: Texture2D
var _heart_empty_texture: Texture2D
var _upgrade_message_label: Label
var _upgrade_message_timer := 0.0

@onready var _p1_container = _find_required_node(["TopBar/Player1Container", "TopBar/HBox/Player1Container"]) as VBoxContainer
@onready var _p1_name = _find_required_node(["TopBar/Player1Container/Player1Header/Player1Name", "TopBar/HBox/Player1Container/Player1Header/Player1Name", "TopBar/HBox/Player1Container/Player1Name"]) as Label
@onready var _p1_powerup_icon = _find_required_node(["TopBar/Player1Container/PowerupSlot/PowerupIcon", "TopBar/HBox/Player1Container/PowerupSlot/PowerupIcon", "TopBar/HBox/Player1Container/Player1Header/PowerupSlot/PowerupIcon"]) as TextureRect
@onready var _p1_hearts = _find_required_node(["TopBar/Player1Container/Player1Hearts", "TopBar/HBox/Player1Container/Player1Hearts"]) as HBoxContainer
@onready var _p1_health = _find_required_node(["TopBar/Player1Container/Player1Health", "TopBar/HBox/Player1Container/Player1Health"]) as Range

@onready var _p2_container = _find_required_node(["TopBar/Player2Container", "TopBar/HBox/Player2Container"]) as VBoxContainer
@onready var _p2_name = _find_required_node(["TopBar/Player2Container/Player2Name", "TopBar/HBox/Player2Container/Player2Name"]) as Label
@onready var _p2_hearts = _find_required_node(["TopBar/Player2Container/Player2Hearts", "TopBar/HBox/Player2Container/Player2Hearts"]) as HBoxContainer
@onready var _p2_health = _find_required_node(["TopBar/Player2Container/Player2Health", "TopBar/HBox/Player2Container/Player2Health"]) as Range

@onready var _boss_container = $BossContainer
@onready var _boss_name = $BossContainer/BossName
@onready var _boss_health = $BossContainer/BossHealth

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	visible = false
	_ensure_player1_hud_nodes()
	_ensure_upgrade_message_label()
	_setup_heart_textures()

func _process(delta: float) -> void:
	_update_players()
	_update_boss()
	_update_upgrade_message(delta)

func setup(p1: Node2D = null, p2: Node2D = null, p1_name: String = "", p2_name: String = "") -> void:
	player1 = p1
	player2 = p2
	player1_name = p1_name if not p1_name.is_empty() else _display_name_for_player(player1, "Kaizen")
	player2_name = p2_name if not p2_name.is_empty() else _display_name_for_player(player2, "Eldric")
	_update_players()

func show_combat_hud() -> void:
	visible = true
	_update_players()
	_update_boss()

func _update_players() -> void:
	if player1 == null or not is_instance_valid(player1):
		player1 = GameManager.current_player1
	if player1 == null or not is_instance_valid(player1):
		player1 = _find_player_by_name("Player1")

	if player2 == null or not is_instance_valid(player2):
		player2 = GameManager.current_player2
	if player2 == null or not is_instance_valid(player2):
		player2 = _find_player_by_name("Player2")

	if player1 != null and is_instance_valid(player1):
		_p1_container.visible = true
		if _p1_name != null:
			_p1_name.text = player1_name
		_update_player1_hearts()
	else:
		_p1_container.visible = false

	if player2 != null and is_instance_valid(player2):
		_p2_container.visible = true
		_p2_name.text = "Eldric"
		_update_player_hearts(player2, _p2_hearts, _p2_health, true)
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

func set_player1_powerup_icon(texture_path: String, flip_h: bool = false) -> void:
	if _p1_powerup_icon == null:
		return
	_p1_powerup_icon.flip_h = flip_h
	if texture_path.is_empty():
		_p1_powerup_icon.texture = null
		_p1_powerup_icon.visible = false
		return
	var texture := load(texture_path) as Texture2D
	_p1_powerup_icon.texture = texture
	_p1_powerup_icon.visible = texture != null

func show_upgrade_text(text: String) -> void:
	_ensure_upgrade_message_label()
	if _upgrade_message_label == null:
		return
	_upgrade_message_label.text = text
	_upgrade_message_label.visible = true
	_upgrade_message_timer = 2.5

func _update_upgrade_message(delta: float) -> void:
	if _upgrade_message_timer <= 0.0:
		return
	_upgrade_message_timer = max(_upgrade_message_timer - delta, 0.0)
	if _upgrade_message_timer <= 0.0 and _upgrade_message_label != null:
		_upgrade_message_label.visible = false

func _update_player1_hearts() -> void:
	_update_player_hearts(player1, _p1_hearts, _p1_health)

func _update_player_hearts(player: Node2D, hearts_row: HBoxContainer, health_bar: Range, reverse_order: bool = false) -> void:
	var max_health := int(player.get("max_health")) if player.get("max_health") != null else 100
	var health := clampi(int(player.get("health")) if player.get("health") != null else max_health, 0, max_health)
	health_bar.max_value = max_health
	health_bar.value = health
	if hearts_row == null:
		return
	var max_hearts := clampi(int(player.get("max_hearts")) if player.get("max_hearts") != null else hearts_row.get_child_count(), 1, hearts_row.get_child_count())
	var hearts := clampi(int(player.get("hearts")) if player.get("hearts") != null else max_hearts, 0, max_hearts)

	for index in hearts_row.get_child_count():
		var heart := hearts_row.get_child(index) as TextureRect
		if heart == null:
			continue
		heart.visible = index < max_hearts
		var heart_number := max_hearts - index if reverse_order else index + 1
		heart.modulate = Color.WHITE
		if heart_number < hearts:
			heart.texture = _heart_full_texture
		elif heart_number == hearts:
			heart.texture = _heart_texture_for_health(health, max_health)
		else:
			heart.texture = _heart_empty_texture

func _setup_heart_textures() -> void:
	var gui_texture := load("res://UI/CrimsonFantasyGUI/GUISprite.png") as Texture2D
	_heart_full_texture = _make_atlas_texture(gui_texture, Rect2(16, 16, 16, 16))
	_heart_two_thirds_texture = _make_atlas_texture(gui_texture, Rect2(32, 16, 16, 16))
	_heart_one_third_texture = _make_atlas_texture(gui_texture, Rect2(48, 16, 16, 16))
	_heart_empty_texture = _make_atlas_texture(gui_texture, Rect2(64, 16, 16, 16))

func _make_atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = region
	return atlas_texture

func _heart_texture_for_health(health: int, max_health: int) -> Texture2D:
	if health <= 0 or max_health <= 0:
		return _heart_empty_texture
	var ratio := float(health) / float(max_health)
	if ratio <= 0.33:
		return _heart_one_third_texture
	if ratio <= 0.66:
		return _heart_two_thirds_texture
	return _heart_full_texture

func _find_required_node(paths: Array[String]) -> Node:
	for path in paths:
		var node := get_node_or_null(path)
		if node != null:
			return node
	return null

func _display_name_for_player(player: Node2D, fallback_name: String) -> String:
	if player == null:
		return fallback_name
	var node_name := str(player.name)
	if node_name == "Player2" or node_name == "Eldric":
		return "Eldric"
	if node_name == "Player1" or node_name == "Kaizen":
		return "Kaizen"
	return node_name if not node_name.is_empty() else fallback_name

func _ensure_player1_hud_nodes() -> void:
	if _p1_container == null:
		return
	if _p1_hearts == null:
		var hearts_row := HBoxContainer.new()
		hearts_row.name = "Player1Hearts"
		hearts_row.add_theme_constant_override("separation", 2)
		_p1_container.add_child(hearts_row)
		_p1_container.move_child(hearts_row, max(_p1_health.get_index(), 0))
		for heart_index in range(4):
			var heart := TextureRect.new()
			heart.name = "Heart" + str(heart_index + 1)
			heart.custom_minimum_size = Vector2(24, 24)
			heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hearts_row.add_child(heart)
		_p1_hearts = hearts_row

func _ensure_upgrade_message_label() -> void:
	if _upgrade_message_label != null and is_instance_valid(_upgrade_message_label):
		return
	_upgrade_message_label = Label.new()
	_upgrade_message_label.name = "UpgradeMessage"
	_upgrade_message_label.visible = false
	_upgrade_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_message_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_upgrade_message_label.offset_top = 112
	_upgrade_message_label.offset_bottom = 168
	_upgrade_message_label.add_theme_font_size_override("font_size", 18)
	_upgrade_message_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62))
	_upgrade_message_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_upgrade_message_label.add_theme_constant_override("shadow_offset_x", 2)
	_upgrade_message_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_upgrade_message_label)

func _find_player_by_name(player_name: String) -> Node2D:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child(player_name, true, false) as Node2D
