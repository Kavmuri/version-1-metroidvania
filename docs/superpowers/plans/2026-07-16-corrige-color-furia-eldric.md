# Corrige el color de furia de Eldric Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar solamente el fuego azul o cian de los ataques de Eldric por un unico rojo durante la furia.

**Architecture:** `Player2/player2.gd` decide cuando el efecto puede mostrarse y fija un rojo constante para todas las cargas. `Player2/shaders/eldric_attack_palette.gdshader` aplica una mascara estricta por brillo, saturacion y predominio cian para dejar intacto al personaje.

**Tech Stack:** Godot 4.6.1, GDScript, CanvasItem shader y pruebas headless.

## Global Constraints

- La piel y la ropa de Eldric no cambian.
- Solo el fuego azul o cian cambia a rojo.
- Todas las cargas usan el mismo rojo.
- No se crean sprites o texturas nuevos.
- No crear commits salvo solicitud explicita del usuario.

---

### Task 1: Contrato visual de la furia

**Files:**
- Modify: `tests/eldric_upgrades_test.gd`
- Modify: `Player2/player2.gd`
- Modify: `Player2/shaders/eldric_attack_palette.gdshader`

**Interfaces:**
- Consumes: `_register_fury_hit()`, `_sync_attack_palette()` y `current_state`.
- Produces: `replacement_color = Color(1.0, 0.08, 0.04, 1.0)` y `effect_strength` activo solo en estados `Attack` o `Glide`.

- [x] **Step 1: Write the failing test**

Comprobar en `tests/eldric_upgrades_test.gd` que una y cinco cargas producen el mismo rojo, que el efecto queda en cero durante `Idle`, que llega a uno durante `Attack` y que el shader contiene las variables `cyan_dominance`, `source_brightness` y `source_saturation`.

- [x] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn`

Expected: FAIL porque la implementación actual usa azul, morado y naranja y mantiene el efecto activo fuera de ataques.

- [x] **Step 3: Write minimal implementation**

En `_sync_attack_palette()`, fijar el rojo `Color(1.0, 0.08, 0.04, 1.0)` y activar la intensidad solo con cargas en `State.Attack` o `State.Glide`. Llamar `_sync_attack_palette()` al finalizar `update_animations()`. En el shader, multiplicar tres mascaras `smoothstep` para predominio cian, brillo alto y saturacion alta antes de mezclar el rojo.

- [x] **Step 4: Run verification**

Run:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_upgrades_test.tscn
Godot_v4.6.1-stable_win64_console.exe --headless --path . tests/eldric_debug_flow_test.tscn
```

Expected: ambos imprimen `RESULT: PASS` y terminan con codigo 0.
