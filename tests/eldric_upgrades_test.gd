extends Node

const ELDRIC_SCENE := preload("res://Player2/player_2.tscn")

class FuryTarget extends Node2D:
	var damage_calls := 0

	func receive_damage(_amount: int, _source_pos: Vector2 = Vector2.ZERO) -> void:
		damage_calls += 1

var _failures: Array[String] = []
var _eldric: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_eldric = ELDRIC_SCENE.instantiate()
	add_child(_eldric)
	await get_tree().process_frame

	_check(_eldric.has_method("set_debug_upgrade_level"), "Eldric expone niveles debug")
	_check(_eldric.has_method("get_upgrade_level"), "Eldric informa el nivel actual")
	if not _eldric.has_method("set_debug_upgrade_level") or not _eldric.has_method("get_upgrade_level"):
		await _finish()
		return

	_test_progression_levels()
	_test_linear_progression()
	_test_manual_shield_guard()
	_test_upgrade_state_round_trip()
	_test_dash_and_glide()
	_test_dash_piercing_evolution()
	_test_fury_damage()
	_test_visual_resources()
	await _finish()


func _test_progression_levels() -> void:
	var expectations := [
		{"level": 0, "jump": false, "dash": false, "shield": false, "heart": 2, "piercing": false, "fury": false, "glide": false},
		{"level": 1, "jump": true, "dash": false, "shield": false, "heart": 2, "piercing": false, "fury": false, "glide": false},
		{"level": 2, "jump": true, "dash": true, "shield": false, "heart": 2, "piercing": false, "fury": false, "glide": false},
		{"level": 3, "jump": true, "dash": true, "shield": true, "heart": 2, "piercing": false, "fury": false, "glide": false},
		{"level": 4, "jump": true, "dash": true, "shield": true, "heart": 3, "piercing": false, "fury": false, "glide": false},
		{"level": 5, "jump": true, "dash": true, "shield": true, "heart": 3, "piercing": true, "fury": false, "glide": false},
		{"level": 6, "jump": true, "dash": true, "shield": true, "heart": 3, "piercing": true, "fury": true, "glide": false},
		{"level": 7, "jump": true, "dash": true, "shield": true, "heart": 3, "piercing": true, "fury": true, "glide": true},
	]
	for expected in expectations:
		_eldric.call("set_debug_upgrade_level", int(expected["level"]))
		_check(int(_eldric.call("get_upgrade_level")) == expected["level"], "aplica nivel %d" % expected["level"])
		_check(bool(_eldric.get("tiene_salto_infinito")) == expected["jump"], "nivel %d configura doble salto" % expected["level"])
		_check(bool(_eldric.get("tiene_dash")) == expected["dash"], "nivel %d configura dash" % expected["level"])
		_check(bool(_eldric.get("tiene_escudo")) == expected["shield"], "nivel %d configura escudo" % expected["level"])
		_check(int(_eldric.get("max_hearts")) == expected["heart"], "nivel %d configura corazones" % expected["level"])
		_check(bool(_eldric.get("tiene_golpe_perforante")) == expected["piercing"], "nivel %d configura golpe perforante" % expected["level"])
		_check(bool(_eldric.get("tiene_furia_creciente")) == expected["fury"], "nivel %d configura furia" % expected["level"])
		_check(bool(_eldric.get("tiene_planeo")) == expected["glide"], "nivel %d configura planeo" % expected["level"])


func _test_linear_progression() -> void:
	_eldric.call("set_debug_upgrade_level", 0)
	for expected_level in range(1, 8):
		var result := _eldric.call("apply_next_linear_upgrade") as Dictionary
		_check(bool(result.get("applied", false)), "la mejora lineal %d se aplica" % expected_level)
		_check(int(_eldric.call("get_upgrade_level")) == expected_level, "la progresion avanza a %d" % expected_level)
	var completed := _eldric.call("apply_next_linear_upgrade") as Dictionary
	_check(not bool(completed.get("applied", true)), "la progresion se detiene despues del nivel 7")


func _test_manual_shield_guard() -> void:
	_eldric.call("set_debug_upgrade_level", 3)
	_eldric.set("input_mode", "both")
	_eldric.set("health", int(_eldric.get("max_health")))
	var full_health := int(_eldric.get("health"))
	_check(bool(_eldric.get("shield_ready")), "el escudo comienza cargado")
	_check("is_guarding" in _eldric, "Eldric expone el estado de guardia manual")
	_check(_has_right_mouse_shield_binding(), "el escudo esta vinculado al clic derecho")
	_eldric.call("recibir_daño", 7, Vector2.ZERO)
	_check(int(_eldric.get("health")) == full_health - 7, "el escudo no protege fuera de guardia")
	_check(bool(_eldric.get("shield_ready")), "recibir dano fuera de guardia conserva la carga")
	_eldric.set("invulnerability_timer", 0.0)
	if InputMap.has_action(&"shield") and _eldric.has_method("_update_guard_state"):
		Input.action_press(&"shield")
		_eldric.call("_update_guard_state")
		_check(bool(_eldric.get("is_guarding")), "clic derecho activa la guardia")
		_eldric.set("attack_timer", 0.0)
		_eldric.set("attack_animation_timer", 0.0)
		Input.action_press(&"attack")
		_eldric.call("handle_attack")
		Input.action_release(&"attack")
		_check(is_zero_approx(float(_eldric.get("attack_animation_timer"))), "Eldric no puede atacar mientras se defiende")
		var guarded_health := int(_eldric.get("health"))
		_eldric.call("recibir_daño", 7, Vector2.ZERO)
		_check(int(_eldric.get("health")) == guarded_health, "la guardia absorbe un golpe")
		_check(not bool(_eldric.get("shield_ready")), "la guardia consume la carga")
		Input.action_release(&"shield")
		_eldric.call("_update_guard_state")
	_eldric.call("recibir_daño", 7, Vector2.ZERO)
	_check(int(_eldric.get("health")) < full_health, "sin carga el siguiente golpe reduce vida")
	_eldric.call("_advance_upgrade_timers", 11.9)
	_check(not bool(_eldric.get("shield_ready")), "el escudo no vuelve antes de 12 segundos")
	_eldric.call("_advance_upgrade_timers", 0.1)
	_check(bool(_eldric.get("shield_ready")), "el escudo se recarga a los 12 segundos")


func _test_upgrade_state_round_trip() -> void:
	_eldric.call("set_debug_upgrade_level", 7)
	var state := _eldric.call("get_upgrade_state") as Dictionary
	_check(int(state.get("eldric_upgrade_level", -1)) == 7, "el guardado conserva el nivel de Eldric")
	_eldric.call("set_debug_upgrade_level", 0)
	_eldric.call("apply_upgrade_state", state)
	_check(int(_eldric.call("get_upgrade_level")) == 7, "la carga restaura el nivel de Eldric")


func _test_dash_and_glide() -> void:
	_check(_eldric.has_method("_start_dash"), "Eldric implementa el dash")
	if not _eldric.has_method("_start_dash"):
		return
	_eldric.call("set_debug_upgrade_level", 2)
	_eldric.call("_start_dash", false, 1.0)
	_check(float(_eldric.get("dash_timer")) > 0.0, "el nivel 2 inicia el dash")
	_check(is_zero_approx(float(_eldric.get("piercing_timer"))), "el dash de nivel 2 no golpea")
	_check(float((_eldric as CharacterBody2D).velocity.x) > 0.0, "el dash desplaza hacia la direccion elegida")
	_eldric.call("update_state")
	_eldric.call("update_animations")
	_check((_eldric.get_node("AnimatedSprite2D") as AnimatedSprite2D).animation == &"agacharP2", "el dash usa agacharP2")

	_eldric.call("set_debug_upgrade_level", 7)
	_eldric.call("_start_dash", true, -1.0)
	_eldric.call("_advance_upgrade_timers", 0.2)
	_check(is_zero_approx(float(_eldric.get("glide_timer"))), "el planeo espera a que termine el golpe perforante")
	_eldric.call("_advance_upgrade_timers", 0.081)
	_check(is_equal_approx(float(_eldric.get("glide_timer")), 1.0), "el dash aereo activa un segundo completo de planeo")
	_check(is_zero_approx((_eldric as CharacterBody2D).velocity.y), "el planeo elimina la caida")
	_eldric.call("update_state")
	_eldric.call("update_animations")
	_check((_eldric.get_node("AnimatedSprite2D") as AnimatedSprite2D).animation == &"golpeaireP2", "el planeo usa golpeaireP2")
	_eldric.call("apply_gravity", 0.2)
	_check(is_zero_approx((_eldric as CharacterBody2D).velocity.y), "la gravedad no actua durante el planeo")
	_eldric.call("_advance_upgrade_timers", 1.0)
	_eldric.call("apply_gravity", 0.1)
	_check(float((_eldric as CharacterBody2D).velocity.y) > 0.0, "la gravedad vuelve despues de un segundo")


func _test_dash_piercing_evolution() -> void:
	_eldric.call("set_debug_upgrade_level", 5)
	_eldric.call("_start_dash", false, 1.0)
	_check(float(_eldric.get("piercing_timer")) > 0.0, "el dash de nivel 5 inicia el golpe perforante")
	_check((_eldric as CharacterBody2D).velocity.x > 0.0, "el dash perforante impulsa a Eldric")
	_check(StringName(_eldric.get("attack_animation_name")) == &"golpeaireP2", "el golpe perforante usa golpeaireP2")
	_eldric.call("update_state")
	_eldric.call("update_animations")
	_check((_eldric.get_node("AnimatedSprite2D") as AnimatedSprite2D).animation == &"golpeaireP2", "el dash perforante reproduce golpeaireP2")

	_eldric.set("dash_timer", 0.0)
	_eldric.set("piercing_timer", 0.0)
	_eldric.set("dash_cooldown_timer", 0.0)
	_eldric.set("attack_timer", 0.0)
	_eldric.set("attack_animation_timer", 0.0)
	(_eldric as CharacterBody2D).velocity = Vector2.ZERO
	Input.action_press(&"attack")
	_eldric.call("handle_attack")
	Input.action_release(&"attack")
	_check(is_zero_approx(float(_eldric.get("piercing_timer"))), "el boton de ataque ya no inicia el golpe perforante")
	_check(is_zero_approx((_eldric as CharacterBody2D).velocity.x), "el ataque aereo normal no desplaza a Eldric")


func _test_fury_damage() -> void:
	_check(_eldric.has_method("get_current_melee_damage") and _eldric.has_method("_register_fury_hit"), "Eldric implementa la furia creciente")
	if not _eldric.has_method("get_current_melee_damage") or not _eldric.has_method("_register_fury_hit"):
		return
	_eldric.call("set_debug_upgrade_level", 6)
	_eldric.set("input_mode", "both")
	var base_damage := int(_eldric.get("attack_damage"))
	_check(int(_eldric.call("get_current_melee_damage")) == base_damage, "la furia comienza con dano base")
	_eldric.set("fury_hits", 0)
	_eldric.set("attack_timer", 0.0)
	_eldric.set("attack_animation_timer", 0.0)
	Input.action_press(&"attack")
	_eldric.call("handle_attack")
	Input.action_release(&"attack")
	_check(int(_eldric.get("fury_hits")) == 1, "en debug un ataque lanzado carga la furia sin enemigo")

	var target := FuryTarget.new()
	add_child(target)
	target.add_to_group(&"enemy")
	target.global_position = (_eldric as Node2D).global_position + Vector2(24.0, -10.0)
	_eldric.call("_apply_melee_damage")
	_check(target.damage_calls == 1, "el ataque debug puede golpear al enemigo")
	_check(int(_eldric.get("fury_hits")) == 1, "el impacto no duplica la carga del ataque debug")
	target.queue_free()

	_eldric.set("fury_hits", 0)
	for hit_index in range(10):
		_eldric.call("_register_fury_hit")
	_check(int(_eldric.get("fury_hits")) == 5, "la furia se limita a cinco cargas")
	_check(int(_eldric.call("get_current_melee_damage")) == base_damage * 2, "cinco cargas duplican el dano")
	_eldric.call("_advance_upgrade_timers", 2.1)
	_check(int(_eldric.get("fury_hits")) == 0, "la furia se pierde al terminar el combo")


func _test_visual_resources() -> void:
	_check(ResourceLoader.exists("res://Player2/shaders/eldric_shield.gdshader"), "existe el shader del escudo")
	_check(ResourceLoader.exists("res://Player2/shaders/eldric_attack_palette.gdshader"), "existe el shader de paleta de ataques")
	var shield_visual := _eldric.get_node_or_null("ShieldVisual") as ColorRect
	_check(shield_visual != null, "la escena contiene ShieldVisual separado")
	if shield_visual != null:
		var shield_material := shield_visual.material as ShaderMaterial
		_check(shield_material != null and shield_material.shader != null, "ShieldVisual usa ShaderMaterial")
		_eldric.call("set_debug_upgrade_level", 3)
		_check(not shield_visual.visible, "el escudo permanece oculto fuera de guardia")
		if InputMap.has_action(&"shield") and _eldric.has_method("_update_guard_state"):
			Input.action_press(&"shield")
			_eldric.call("_update_guard_state")
			_check(shield_visual.visible, "el shader aparece al mantener clic derecho")
			if shield_material != null:
				_check(float(shield_material.get_shader_parameter("strength")) > 0.99, "la guardia cargada tiene fuerza completa")
			Input.action_release(&"shield")
			_eldric.call("_update_guard_state")
			_check(not shield_visual.visible, "el shader desaparece al soltar clic derecho")

	var attack_material := (_eldric.get_node("AnimatedSprite2D") as AnimatedSprite2D).material as ShaderMaterial
	_check(attack_material != null and attack_material.shader != null, "los ataques usan shader de paleta")
	if attack_material != null:
		_eldric.call("set_debug_upgrade_level", 6)
		_eldric.set("current_state", 0)
		_eldric.call("_register_fury_hit")
		_eldric.call("_sync_attack_palette")
		_check(is_zero_approx(float(attack_material.get_shader_parameter("effect_strength"))), "la furia no recolorea a Eldric fuera de ataques")

		attack_material.set_shader_parameter("effect_strength", 0.0)
		_eldric.set("current_state", 5)
		_eldric.call("update_animations")
		_check(is_equal_approx(float(attack_material.get_shader_parameter("effect_strength")), 1.0), "la furia recolorea el fuego durante ataques")
		var expected_red := Color(1.0, 0.08, 0.04, 1.0)
		var first_charge_color := attack_material.get_shader_parameter("replacement_color") as Color
		_check(_colors_are_close(first_charge_color, expected_red), "la primera carga cambia el fuego de azul a rojo")

		for charge_index in range(4):
			_eldric.call("_register_fury_hit")
		var fifth_charge_color := attack_material.get_shader_parameter("replacement_color") as Color
		_check(_colors_are_close(fifth_charge_color, expected_red), "la quinta carga conserva el mismo rojo")

		attack_material.set_shader_parameter("effect_strength", 1.0)
		_eldric.set("current_state", 0)
		_eldric.call("update_animations")
		_check(is_zero_approx(float(attack_material.get_shader_parameter("effect_strength"))), "la paleta se apaga al terminar el ataque")

	var palette_shader_source := FileAccess.get_file_as_string("res://Player2/shaders/eldric_attack_palette.gdshader")
	_check("cyan_dominance" in palette_shader_source, "el shader filtra por predominio cian")
	_check("source_brightness" in palette_shader_source, "el shader filtra por brillo del fuego")
	_check("source_saturation" in palette_shader_source, "el shader filtra por saturacion del fuego")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: " + message)


func _has_right_mouse_shield_binding() -> bool:
	if not InputMap.has_action(&"shield"):
		return false
	for event in InputMap.action_get_events(&"shield"):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			return true
	return false


func _colors_are_close(left: Color, right: Color) -> bool:
	return (
		is_equal_approx(left.r, right.r)
		and is_equal_approx(left.g, right.g)
		and is_equal_approx(left.b, right.b)
		and is_equal_approx(left.a, right.a)
	)


func _finish() -> void:
	if is_instance_valid(_eldric):
		_eldric.queue_free()
	await get_tree().process_frame
	_cleanup_audio()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if _failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
		return
	print("RESULT: FAIL (", _failures.size(), ")")
	get_tree().quit(1)


func _cleanup_audio() -> void:
	var audio_manager := get_tree().root.get_node_or_null("AudioManager")
	if audio_manager == null:
		return
	for child in audio_manager.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
