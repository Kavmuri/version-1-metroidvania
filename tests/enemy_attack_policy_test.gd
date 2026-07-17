extends SceneTree

const DUMMY_SCRIPT := preload("res://tests/helpers/damage_dummy.gd")
const ATTACK_ENEMIES: Array[String] = [
	"res://Enemies/basic/enemy_bat.tscn",
	"res://Enemies/basic/enemy_skeleton_sword_white.tscn",
	"res://Enemies/basic/enemy_skeleton_sword_yellow.tscn",
	"res://Enemies/basic/enemy_mutant_toad.tscn",
	"res://Enemies/basic/enemy_dragon.tscn",
	"res://Enemies/basic/enemy_hell_beast_fire.tscn",
	"res://Enemies/basic/enemy_demon_boss.tscn",
]
const CONTACT_ENEMIES: Array[String] = [
	"res://Enemies/basic/enemy_ghost.tscn",
	"res://Enemies/basic/enemy_flying_eye_demon.tscn",
	"res://Enemies/basic/enemy_hell_hound_fire.tscn",
	"res://Enemies/basic/enemy_nightmare.tscn",
]
const CRAB_SCENE := "res://Enemies/basic/enemy_crab.tscn"

var _failures: Array[String] = []
var _world: Node2D
var _dummy: CharacterBody2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_dummy = DUMMY_SCRIPT.new() as CharacterBody2D
	_dummy.name = "Player1"
	_dummy.add_to_group(&"Player")
	_world.add_child(_dummy)

	for scene_path in ATTACK_ENEMIES:
		_test_attack_enemy(scene_path)
	for scene_path in CONTACT_ENEMIES:
		_test_contact_enemy(scene_path)
	_test_crab()
	_test_nightmare_has_no_invisible_melee()

	_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
		return
	print("RESULT: FAIL (", _failures.size(), ")")
	quit(1)


func _test_attack_enemy(scene_path: String) -> void:
	var enemy := _spawn_enemy(scene_path)
	var label := scene_path.get_file().get_basename()
	var sprite := enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(enemy.has_method("has_attack_animation"), "%s expone su politica de ataque" % label)
	_check(not bool(enemy.get("contact_damage_enabled")), "%s no hace dano por contacto" % label)
	_check(sprite.sprite_frames.has_animation(&"attack"), "%s tiene animacion attack" % label)
	_check(not sprite.sprite_frames.get_animation_loop(&"attack"), "%s reproduce attack una sola vez" % label)

	_dummy.damage_received = 0
	if scene_path.ends_with("enemy_mutant_toad.tscn"):
		_check(bool(enemy.call("_can_start_close_attack")), "%s detecta al jugador para sacar la lengua" % label)
	_start_enemy_attack(enemy, scene_path)
	_check(sprite.animation == &"attack" and sprite.is_playing(), "%s reproduce su animacion attack" % label)
	_finish_enemy_attack(enemy, scene_path)
	_check(_dummy.damage_received > 0, "%s aplica dano durante attack" % label)
	_remove_enemy(enemy)


func _test_contact_enemy(scene_path: String) -> void:
	var enemy := _spawn_enemy(scene_path)
	var label := scene_path.get_file().get_basename()
	var sprite := enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(not sprite.sprite_frames.has_animation(&"attack"), "%s no finge una animacion attack" % label)
	_check(bool(enemy.get("contact_damage_enabled")), "%s conserva dano por contacto" % label)
	_remove_enemy(enemy)


func _test_crab() -> void:
	var crab := _spawn_enemy(CRAB_SCENE)
	_check(not bool(crab.get("contact_damage_enabled")), "Crab permanece sin dano")
	_check(crab.get_node_or_null("ContactArea") == null, "Crab no tiene area de contacto danina")
	_remove_enemy(crab)


func _test_nightmare_has_no_invisible_melee() -> void:
	var nightmare := _spawn_enemy("res://Enemies/basic/enemy_nightmare.tscn")
	nightmare.call("_physics_process", 0.016)
	var state_machine := nightmare.get_node("StateMachine")
	_check(StringName(state_machine.get("current_state_name")) != &"meleeattack", "Nightmare usa contacto y no un golpe invisible")
	_remove_enemy(nightmare)


func _spawn_enemy(scene_path: String) -> CharacterBody2D:
	var packed := load(scene_path) as PackedScene
	var enemy := packed.instantiate() as CharacterBody2D
	if _has_property(enemy, "initial_think_time"):
		enemy.set("initial_think_time", 0.0)
	enemy.global_position = Vector2.ZERO
	_dummy.global_position = Vector2(24, 0)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set("player", _dummy)
	enemy.call("set_player_in_attack_area", true)
	return enemy


func _start_enemy_attack(enemy: CharacterBody2D, scene_path: String) -> void:
	if scene_path.ends_with("enemy_mutant_toad.tscn"):
		enemy.call("_start_close_attack", Vector2.RIGHT)
		return
	enemy.call("_physics_process", 0.016)


func _finish_enemy_attack(enemy: CharacterBody2D, scene_path: String) -> void:
	if scene_path.ends_with("enemy_mutant_toad.tscn"):
		enemy.call("_update_close_attack", 1.0)
		return
	if enemy.has_method("_update_attack"):
		enemy.call("_update_attack", 1.0)
		return
	_check(false, "%s tiene una ventana de golpe" % scene_path.get_file().get_basename())


func _remove_enemy(enemy: Node) -> void:
	if is_instance_valid(enemy):
		enemy.free()


func _has_property(object: Object, property_name: String) -> bool:
	for property_data in object.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: " + message)
