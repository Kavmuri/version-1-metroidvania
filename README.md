# Version1Metroidvania

Prototipo de metroidvania 2D hecho en Godot 4.6. El proyecto combina movimiento de plataformas, combate, enemigos, UI de juego, audio y un mundo modular generado a partir de habitaciones conectadas.

El concepto jugable base es **ASHENBOUND**: una aventura de accion y exploracion donde Kaizen y Eldric recorren un mundo oscuro con habilidades distintas. El proyecto puede iniciarse en modo individual o cooperativo local desde el menu principal.

## Estado actual

El repositorio contiene un prototipo funcional con estos sistemas integrados:

- Menu principal con nueva partida, continuar, opciones, controles, arena de enemigos y salida.
- Modo singleplayer con seleccion de personaje y modo cooperativo local con dos jugadores.
- Generacion procedural/modular de habitaciones usando plantillas, puertas, spawns y dead ends.
- Movimiento de plataformas con salto, gravedad, friccion, estados de animacion y camara.
- Kaizen con ataque de proyectil, disparo horizontal/vertical, dash y salto extendido desbloqueable por debug.
- Eldric con ataque cuerpo a cuerpo, variantes de animacion segun postura y dano por rango.
- Sistema de vida, dano, invulnerabilidad temporal, muerte y pantalla de continuar.
- HUD de vida, menu de pausa, menu de controles y mapa UI.
- Enemigos basicos y bosses organizados en carpetas separadas.
- Arena de prueba para cambiar jugador/enemigo y validar comportamiento de combate.
- Guardado y carga de partida con posicion, modo de juego, personaje seleccionado y semilla del mundo.
- Audio centralizado para musica, ambiente, UI, jugador y enemigos.

## Historia o contexto

La historia ocurre en Hollowreach, un reino antiguo afectado por una corrupcion que altero sus ruinas, cuevas, castillos y zonas subterraneas. Kaizen y Eldric buscan a su madre desaparecida mientras descubren que sus caminos estan conectados por una tragedia familiar y por el dominio de fuerzas hostiles dentro del reino.

La narrativa esta pensada para revelarse mediante fragmentos de memoria, escritos antiguos, NPCs y eventos dentro del mundo. El prototipo actual se enfoca en la base jugable; la integracion narrativa completa queda como parte del desarrollo siguiente.

## Gameplay

El loop principal del prototipo es:

1. Iniciar partida desde el menu principal.
2. Seleccionar modo individual o cooperativo local.
3. Aparecer en una sala inicial generada por el sistema procedural.
4. Explorar habitaciones conectadas y buscar rutas disponibles.
5. Superar obstaculos mediante movimiento, salto, dash, combate y lectura del mapa.
6. Combatir enemigos activos en salas cercanas.
7. Guardar o continuar la partida con el sistema de juego.
8. Reintentar desde la pantalla de muerte si el personaje cae.

La mecanica central actual es la generacion modular del mapa. El generador coloca una sala inicial, conecta habitaciones compatibles por puertas, evita colisiones entre salas y cierra salidas abiertas con habitaciones dead end cuando corresponde.

## Personajes

**Kaizen** es el personaje orientado a ataque a distancia y movilidad. Usa proyectiles, puede apuntar hacia arriba, tiene dash y cuenta con variables listas para activar habilidades desbloqueables.

**Eldric** es el personaje orientado a combate cercano. Usa ataques cuerpo a cuerpo con rango, cooldown y animaciones distintas para ataque normal, ataque agachado, ataque aereo y ataque hacia arriba.

## Enemigos

Los enemigos estan organizados por rol dentro de `Enemies/`:

```text
Enemies/basic/   Enemigos comunes y variantes de combate.
Enemies/boss/    Encuentros principales configurados como bosses.
Enemies/assets/  Sprites y hojas de animacion.
Enemies/scripts/ Logica compartida, comportamiento y state machine.
```

Enemigos comunes disponibles:

- Crab
- Flying Eye Demon
- Ghost
- Hell Hound Fire
- Mutant Toad
- Nightmare
- Demon Boss
- Dragon
- Hell Beast Fire

Bosses disponibles:

- Ogre
- Agis
- Boss Cinder Demon

La arena de enemigos permite probar estos enemigos desde `res://Levels/test_levels/enemy_arena.tscn`.

## Progresion y mejoras

El proyecto todavia no tiene un sistema completo de pickups o reliquias, pero ya tiene variables que permiten integrarlo con poco cambio:

- `max_health` y `health` para aumentos de vida.
- `attack_damage` para mejorar dano de proyectil o melee.
- `attack_cooldown` para mejorar velocidad de ataque.
- `projectile_scene` y `bullet.gd` para extender el disparo de Kaizen.
- `tiene_dash` y `tiene_salto_infinito` para desbloquear habilidades de movilidad.

La forma mas directa de implementar progresion es crear objetos recolectables que modifiquen esas variables al tocarlos. Las mejoras mas viables para el estado actual son aumento de vida maxima, aumento de dano, reduccion de cooldown, activacion de dash/salto extendido y un escudo simple basado en cargas o bloqueo del siguiente golpe.

## Controles

Controles principales configurados por defecto:

| Accion | Teclado / mouse | Mando |
| --- | --- | --- |
| Mover izquierda | A | Stick izquierdo izquierda / D-pad izquierda |
| Mover derecha | D | Stick izquierdo derecha / D-pad derecha |
| Saltar | Espacio | Boton 1 |
| Agacharse | S | D-pad abajo |
| Apuntar arriba | W | D-pad arriba |
| Atacar | Click izquierdo | Boton 2 |
| Dash | F | No asignado por defecto |
| Pausa | Esc | Boton 6 |
| Navegacion UI | W, A, S, D, Enter, Espacio, Esc | Acciones UI del mando |

El menu de controles permite cambiar las teclas principales y restaurar la configuracion por defecto.

## Como abrir el proyecto

1. Abre Godot 4.6.
2. Importa o abre esta carpeta como proyecto.
3. Ejecuta la escena principal configurada en `project.godot`.

La escena principal actual es:

```text
res://UI/scenes/main_menu.tscn
```

El proyecto usa `Forward Plus`, ventana base de `642x360` y escalado por viewport.

## Estructura principal

```text
Audio/       Musica, ambiente, efectos de sonido y trazabilidad de audio usado.
Background/  Fondos y escena de parallax.
Enemies/     Enemigos basicos, bosses, assets, scripts y state machine.
Levels/      Mundo procedural, niveles de prueba y plantillas de salas.
Player1/     Kaizen, proyectil, impacto y sprites.
Player2/     Eldric, scripts, escena y sprites.
Scripts/     GameManager, generacion, spawn, mapa, debug y gestion de enemigos.
Tileset/     Tilesets y assets de escenarios.
UI/          Menus, HUD, pausa, controles, pantalla de muerte y tema visual.
```

## Sistemas destacados

- `Scripts/game_manager.gd`: controla inicio de partida, continuacion, guardado, modo de juego, seleccion de personaje, pantalla de muerte y controles.
- `Scripts/generacion_procedural.gd`: genera la mazmorra modular y administra habitaciones, puertas y cierres.
- `Scripts/spawn_player.gd`: instancia jugadores, camara, HUD, pausa, mapa UI y gestor de enemigos.
- `Scripts/gestor_enemigos.gd`: activa enemigos en la habitacion actual y habitaciones vecinas.
- `Player1/player1.gd`: controla movimiento, dash, salto, disparo, dano, muerte y animaciones de Kaizen.
- `Player1/bullet.gd`: controla velocidad, direccion, dano, lifetime e impacto del proyectil.
- `Player2/player2.gd`: controla movimiento, ataque melee, dano, muerte y animaciones de Eldric.
- `Enemies/scripts/enemy_base.gd`: base compartida de vida, dano, muerte, contacto y deteccion de proyectiles.
- `Audio/audio_manager.gd`: reproduce musica, ambiente y efectos de sonido.

## Direccion visual

La direccion visual actual usa pixel art 2D con fantasia oscura, escenarios de cuevas, zonas de lava, castillos, ruinas y fondos parallax. El proyecto combina assets de personajes, enemigos sobrenaturales, tilesets de areas y UI pixel art.

Los assets principales estan distribuidos en `Player1/`, `Player2/`, `Enemies/assets/`, `Tileset/`, `Background/` y `UI/`.

## Audio

El proyecto incluye musica de menu, musica de gameplay, ambiente de cueva y efectos para UI, salto, disparo, dash, dano, muerte de enemigos y reintento. La trazabilidad de los archivos usados esta documentada en:

```text
Audio/USED_AUDIO.md
```

## Alcance pendiente

- Implementar pickups/reliquias de mejora usando las variables ya existentes.
- Integrar fragmentos de memoria, NPCs o eventos narrativos dentro del mapa.
- Completar progresion por regiones y rutas bloqueadas por habilidades.
- Pulir balance de enemigos, bosses, dano, vida y recompensas.
- Ampliar puzzles cooperativos y rutas exclusivas para dos jugadores.
- Revisar consistencia visual final entre areas, personajes, enemigos y UI.
