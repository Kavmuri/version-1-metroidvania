# Mejoras de Eldric Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Autor:** ALFREDO RUIZ

**Goal:** Implementar siete niveles acumulativos de mejoras para Eldric y un flujo de `enemy_arena` que permita probar los niveles 0 a 7 con el personaje elegido desde el selector singleplayer.

**Architecture:** `Player2/player2.gd` será la autoridad de progresión y expondrá `set_debug_upgrade_level(level)`. Los efectos visuales vivirán como materiales separados en `Player2/player_2.tscn`; el selector de menú solo transportará el personaje elegido a `GameManager`, y `enemy_arena` aplicará el nivel seleccionado al personaje ya fijado.

**Tech Stack:** Godot 4.6.1, GDScript, escenas `.tscn`, shaders `canvas_item`, pruebas `SceneTree` ejecutadas en modo headless.

## Global Constraints

- La progresión de Eldric es: 1 doble salto, 2 dash, 3 escudo, 4 corazón adicional, 5 golpe perforante, 6 furia creciente, 7 planeo.
- El dash usa `agacharP2`; el golpe perforante y el planeo usan `golpeaireP2`.
- El planeo comienza después de un dash aéreo, anula la caída durante 1 segundo y no causa daño.
- El escudo absorbe un golpe, desaparece y se recarga después de 12 segundos.
- No se crean sprites nuevos: escudo y cambio del fuego se resuelven con shaders.
- No se realiza commit sin una petición explícita del usuario.

---

### Task 1: Progresión acumulativa y defensa

**Files:**
- Modify: `Player2/player2.gd`
- Test: `tests/eldric_upgrades_test.gd`

**Interfaces:**
- Produces: `set_debug_upgrade_level(level: int) -> void`, `get_upgrade_level() -> int`, `apply_next_linear_upgrade() -> Dictionary`.
- Produces state: `tiene_dash`, `tiene_escudo`, `tiene_golpe_perforante`, `tiene_furia_creciente`, `tiene_planeo`, `shield_ready`.

- [ ] Escribir una prueba que instancie `player_2.tscn`, aplique cada nivel y compruebe flags, doble salto, corazón extra, reinicio y absorción del escudo.
- [ ] Ejecutar `Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tests/eldric_upgrades_test.gd` y confirmar que falla porque falta `set_debug_upgrade_level`.
- [ ] Implementar la progresión mínima, compatibilidad de guardado y consumo/recarga del escudo.
- [ ] Repetir la prueba hasta obtener `RESULT: PASS`.

### Task 2: Dash, golpe perforante, furia y planeo

**Files:**
- Modify: `Player2/player2.gd`
- Test: `tests/eldric_upgrades_test.gd`

**Interfaces:**
- Produces runtime methods: `_start_dash(in_air: bool, direction: float) -> void`, `_start_piercing_attack(direction: float) -> void`, `_register_fury_hit() -> void`, `_advance_upgrade_timers(delta: float) -> void`.
- Las pruebas llaman estas mismas funciones de producción mediante `call`, sin añadir adaptadores exclusivos para testing.

- [ ] Extender la prueba para comprobar duración, dirección, transición dash a planeo, animaciones y multiplicador limitado de furia.
- [ ] Ejecutar la prueba y confirmar fallos por comportamiento ausente.
- [ ] Implementar dash horizontal, golpe aéreo perforante, combo creciente y planeo de 1 segundo.
- [ ] Repetir la prueba hasta obtener `RESULT: PASS`.

### Task 3: Shader de escudo y paleta de ataques

**Files:**
- Create: `Player2/shaders/eldric_shield.gdshader`
- Create: `Player2/shaders/eldric_attack_palette.gdshader`
- Modify: `Player2/player_2.tscn`
- Test: `tests/eldric_upgrades_test.gd`

**Interfaces:**
- `ShieldVisual` expone parámetros `strength` y `hit_flash`.
- El material de `AnimatedSprite2D` expone `effect_strength` y `replacement_color`.

- [ ] Añadir comprobaciones de nodos, materiales y parámetros al test.
- [ ] Ejecutar la prueba y confirmar que falla por recursos visuales ausentes.
- [ ] Crear ambos shaders y conectarlos a la escena sin modificar los PNG.
- [ ] Repetir la prueba hasta obtener `RESULT: PASS`.

### Task 4: Acceso debug y selector de nivel

**Files:**
- Modify: `UI/scripts/main_menu.gd`
- Modify: `Scripts/game_manager.gd`
- Modify: `Levels/test_levels/enemy_arena.gd`
- Modify: `Levels/test_levels/enemy_arena.tscn`
- Test: `tests/eldric_debug_flow_test.gd`

**Interfaces:**
- Produces: `GameManager.open_enemy_arena(selected_player: String = "player1")` y `GameManager.debug_arena_player`.
- `enemy_arena` consume `debug_arena_player` y ofrece `UpgradeSelector` con niveles 0 a 7.

- [ ] Escribir una prueba que cargue `enemy_arena`, confirme el personaje prefijado y cambie niveles con `UpgradeSelector`.
- [ ] Ejecutar la prueba y confirmar que falla porque todavía existe `PlayerSelector`.
- [ ] Mover la pulsación larga de `Coop online` a las tarjetas Kaizen/Eldric y reemplazar el selector de personaje de la arena.
- [ ] Ejecutar ambas pruebas nuevas y las pruebas singleplayer existentes.

### Task 5: Verificación integral

**Files:**
- Verify: todos los archivos anteriores

- [ ] Ejecutar `eldric_upgrades_test.gd` y `eldric_debug_flow_test.gd` desde cero.
- [ ] Ejecutar `single_run_director_test.gd` y `single_scene_smoke_test.gd` para detectar regresiones.
- [ ] Cargar `Levels/test_levels/enemy_arena.tscn` en headless y comprobar ausencia de errores de parseo/recursos.
- [ ] Revisar `git diff --check`, `git status --short` y el diff limitado a los archivos de esta funcionalidad.
