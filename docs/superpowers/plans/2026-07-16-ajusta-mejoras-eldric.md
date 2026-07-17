# Ajusta las mejoras de Eldric Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cambiar el escudo a guardia manual, convertir el golpe perforante en la evolucion del dash y permitir cargar furia con ataques lanzados dentro de `enemy_arena`.

**Architecture:** `Player2/player2.gd` conserva toda la maquina de estados de Eldric y agrega dos estados de contexto: guardia manual y furia debug. `GameManager` registra el clic derecho como accion `shield`; el selector de arena sigue activando el modo debug mediante `set_debug_upgrade_level`. Las pruebas de Eldric ejercitan las APIs reales y los temporizadores sin introducir metodos exclusivos para tests.

**Tech Stack:** Godot 4.6.1, GDScript, escenas `.tscn`, pruebas headless existentes.

## Global Constraints

- El dash se activa con `F`.
- El nivel 2 usa `agacharP2` y no hace dano.
- El nivel 5 usa `golpeaireP2`, golpea y atraviesa.
- El nivel 7 agrega un segundo de planeo despues de un dash iniciado en el aire.
- El escudo usa clic derecho y bloquea los ataques mientras se mantiene la guardia.
- En debug la furia cuenta ataques lanzados, no impactos.
- No crear commits salvo solicitud explicita del usuario.

---

### Task 1: Guardia manual del escudo

**Files:**
- Modify: `tests/eldric_upgrades_test.gd`
- Modify: `Player2/player2.gd`
- Modify: `Scripts/game_manager.gd`

**Interfaces:**
- Consumes: acciones `shield` y `attack`; `recibir_daño(cantidad, fuente_pos)`.
- Produces: propiedad `is_guarding: bool` y metodo `_update_guard_state()`.

- [x] **Step 1: Write the failing test**

Agregar aserciones que comprueben que el escudo no absorbe fuera de guardia, que absorbe durante guardia, que `handle_attack()` no inicia una animacion durante guardia y que la accion `shield` esta vinculada al boton derecho.

- [x] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn`

Expected: FAIL porque `is_guarding` no existe y el escudo todavia absorbe automaticamente.

- [x] **Step 3: Write minimal implementation**

Agregar `is_guarding`, actualizarlo desde `shield`, ocultar el shader fuera de guardia, exigir guardia en `recibir_daño` y retornar temprano desde `handle_attack` mientras se defiende. Registrar `shield` como `InputEventMouseButton` con `MOUSE_BUTTON_RIGHT`.

- [x] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn`

Expected: PASS para guardia, consumo y recarga.

### Task 2: Dash evolutivo

**Files:**
- Modify: `tests/eldric_upgrades_test.gd`
- Modify: `Player2/player2.gd`

**Interfaces:**
- Consumes: `_start_dash(in_air: bool, direction: float)` y niveles 2, 5 y 7.
- Produces: un unico flujo de dash que configura `piercing_timer` y `attack_animation_name` cuando corresponde.

- [x] **Step 1: Write the failing test**

Probar que el nivel 2 inicia un dash no ofensivo con `agacharP2`, que el nivel 5 inicia el componente perforante desde `_start_dash`, y que el nivel 7 planea solamente despues de un dash aereo perforante. Probar que el ataque aereo normal ya no inicia el desplazamiento perforante.

- [x] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn`

Expected: FAIL porque el nivel 5 requiere `_start_piercing_attack` o el boton de ataque.

- [x] **Step 3: Write minimal implementation**

Hacer que `_start_dash` active `piercing_timer`, limpie objetivos y seleccione `golpeaireP2` desde el nivel 5. Eliminar el arranque perforante de `handle_attack`; conservar el planeo en `_advance_upgrade_timers` cuando `dash_started_in_air` y nivel 7.

- [x] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn`

Expected: PASS para los tres niveles del dash.

### Task 3: Furia por ataques lanzados en debug

**Files:**
- Modify: `tests/eldric_upgrades_test.gd`
- Modify: `Player2/player2.gd`

**Interfaces:**
- Consumes: `set_debug_upgrade_level(level: int)`, `handle_attack()` y `_register_fury_hit()`.
- Produces: propiedad `debug_fury_counts_attacks: bool` y registro unico por ataque ofensivo.

- [x] **Step 1: Write the failing test**

Activar nivel 6 mediante `set_debug_upgrade_level`, simular `attack`, llamar `handle_attack` y comprobar una carga sin enemigos. Comprobar que aplicar dano a un enemigo durante ese mismo ataque no duplica la carga.

- [x] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn`

Expected: FAIL porque la furia actual solo aumenta tras un impacto.

- [x] **Step 3: Write minimal implementation**

Marcar el contexto debug desde `set_debug_upgrade_level`, registrar furia al lanzar ataques normales o dash perforante y omitir el registro por impacto cuando el modo debug esta activo.

- [x] **Step 4: Run all verification**

Run:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn
Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_debug_flow_test.tscn
Godot_v4.6.1-stable_win64_console.exe --headless --path . --script tests/single_run_director_test.gd
Godot_v4.6.1-stable_win64_console.exe --headless --path . --script tests/single_scene_smoke_test.gd
```

Expected: todos imprimen `RESULT: PASS` y terminan con codigo 0.
