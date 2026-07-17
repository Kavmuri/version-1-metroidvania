extends SceneTree

const CURRENT_ROOMS: Array[String] = [
	"res://Levels/single/Tileset/area1/area_1_2.tscn",
	"res://Levels/single/Tileset/area1/area_1_3.tscn",
]
const DISABLED_ROOM := "res://Levels/single/rooms/area1_variants/room_area1_5.tscn"
const SOURCE_TO_VARIANT := {
	"res://Tileset/area1/Area1.tscn": "res://Levels/single/rooms/area1_variants/room_area1.tscn",
	"res://Tileset/area1/area_1_2.tscn": "res://Levels/single/rooms/area1_variants/room_area1_2.tscn",
	"res://Tileset/area1/area_1_3.tscn": "res://Levels/single/rooms/area1_variants/room_area1_3.tscn",
	"res://Tileset/area1/area_1_4.tscn": "res://Levels/single/rooms/area1_variants/room_area1_4.tscn",
	"res://Tileset/area1/area_1_4_1.tscn": "res://Levels/single/rooms/area1_variants/room_area1_4_1.tscn",
}

var _failures: Array[String] = []
var _game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_manager = root.get_node_or_null("GameManager")
	_check(_game_manager != null, "existe el autoload GameManager")
	_test_active_room_pool()
	for source_path in SOURCE_TO_VARIANT:
		_test_copied_variant(source_path, SOURCE_TO_VARIANT[source_path])
	for room_path in CURRENT_ROOMS:
		_test_room_content(room_path, false)

	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
		return
	print("RESULT: FAIL (", _failures.size(), ")")
	quit(1)


func _test_active_room_pool() -> void:
	_check(_game_manager != null and _game_manager.has_method("get_single_room_scenes"), "GameManager expone las salas single")
	var rooms: Array[String] = []
	if _game_manager != null and _game_manager.has_method("get_single_room_scenes"):
		rooms = _game_manager.call("get_single_room_scenes")
	_check(rooms.size() == 7, "el selector contiene exactamente siete salas")
	_check(not rooms.has(DISABLED_ROOM), "room_area1_5 queda fuera de la rotacion")
	for room_path in CURRENT_ROOMS:
		_check(rooms.has(room_path), "el selector conserva %s" % room_path.get_file())
	for variant_path in SOURCE_TO_VARIANT.values():
		_check(rooms.has(variant_path), "el selector incluye %s" % str(variant_path).get_file())
	for room_path in rooms:
		_check(room_path.begins_with("res://Levels/single/"), "la sala activa permanece dentro de Levels/single")


func _test_copied_variant(source_path: String, variant_path: String) -> void:
	var label := variant_path.get_file()
	_check(FileAccess.file_exists(variant_path), "%s existe como copia fisica" % label)
	if not FileAccess.file_exists(variant_path):
		return
	_check(_layout_signature(source_path) == _layout_signature(variant_path), "%s conserva el layout original" % label)
	_check(_scene_uid(source_path) != _scene_uid(variant_path), "%s usa una cedula distinta" % label)
	_test_room_content(variant_path, true)


func _test_room_content(room_path: String, is_variant: bool) -> void:
	var packed := load(room_path) as PackedScene
	_check(packed != null, "carga %s" % room_path.get_file())
	if packed == null:
		return
	var room := packed.instantiate()
	_check(room.find_child("PlayerSpawn", true, false) is Marker2D, "%s tiene PlayerSpawn" % room_path.get_file())
	_check(_count_enemy_spawns(room) >= 3, "%s tiene al menos tres EnemySpawn" % room_path.get_file())
	_check(_has_linear_upgrade(room), "%s tiene un power-up lineal" % room_path.get_file())
	if is_variant:
		_check(room.find_child("GameplayHUD", true, false) == null, "%s deja que el controlador cree un solo HUD" % room_path.get_file())
		_check(room.find_child("Player1", true, false) == null, "%s no incrusta Player1" % room_path.get_file())
		_check(room.find_child("Player2", true, false) == null, "%s no incrusta Player2" % room_path.get_file())
		_check(room.find_child("SingleExitTrigger", true, false) is Area2D, "%s tiene salida single" % room_path.get_file())
		_check(not _contains_agis_or_boss_script(room), "%s no contiene a Agis ni logica de jefe" % room_path.get_file())
		var script := room.get_script() as Script
		var script_path := script.resource_path if script != null else ""
		_check(script_path.begins_with("res://Levels/single/"), "%s usa logica dentro de Levels/single" % room_path.get_file())
	room.free()


func _count_enemy_spawns(node: Node) -> int:
	var count := 1 if node is Marker2D and node.name.begins_with("EnemySpawn") else 0
	for child in node.get_children():
		count += _count_enemy_spawns(child)
	return count


func _has_linear_upgrade(node: Node) -> bool:
	var script := node.get_script() as Script
	if script != null and script.resource_path == "res://Pickups/upgrade_pickup.gd":
		return bool(node.get("use_linear_progression"))
	for child in node.get_children():
		if _has_linear_upgrade(child):
			return true
	return false


func _contains_agis_or_boss_script(node: Node) -> bool:
	if "agis" in node.name.to_lower():
		return true
	var script := node.get_script() as Script
	if script != null and "boss" in script.resource_path.to_lower():
		return true
	for child in node.get_children():
		if _contains_agis_or_boss_script(child):
			return true
	return false


func _layout_signature(scene_path: String) -> int:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return 0
	var tile_lines: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("tile_map_data = "):
			tile_lines.append(line)
	return hash("\n".join(tile_lines))


func _scene_uid(scene_path: String) -> String:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return ""
	var first_line := file.get_line()
	var uid_regex := RegEx.new()
	uid_regex.compile('uid="([^"]+)"')
	var result := uid_regex.search(first_line)
	return result.get_string(1) if result != null else ""


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: " + message)
