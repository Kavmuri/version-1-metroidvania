# Version1Metroidvania

Prototipo de metroidvania 2D hecho en Godot. El proyecto combina movimiento de plataformas, combate con proyectiles, enemigos, UI de juego y una mazmorra generada proceduralmente a partir de salas conectadas.

El concepto narrativo provisional del juego es **ASHENBOUND**: una aventura cooperativa local sobre dos personajes con habilidades complementarias que exploran un mundo oscuro, combaten enemigos y desbloquean rutas que no siempre podrian superar por separado.

El juego arranca desde un menu principal y permite iniciar una partida nueva en modo individual o cooperativo local, continuar una partida guardada, configurar controles y entrar al mundo procedural.

## Estado actual

El repositorio contiene un prototipo funcional con estos sistemas ya integrados:

- Menu principal con opciones de jugar, continuar, configuracion y salida.
- Modo individual y modo cooperativo local con un segundo jugador.
- Generacion procedural de habitaciones usando plantillas de salas, spawns y dead ends.
- Movimiento basico del jugador: desplazamiento, salto, gravedad, friccion y estados de animacion.
- Habilidad de dash y salto extendido/desbloqueable desde la UI de debug.
- Ataque con proyectiles, cooldown y dano a enemigos.
- Enemigos con escenas, scripts base y spawneo por habitacion.
- HUD de vida, menu de pausa y pantalla de muerte con opcion de continuar.
- Guardado y carga de partida con posicion, modo de juego y semilla del mundo.
- Musica, ambiente y efectos de sonido para menu, gameplay, jugador, UI y enemigos.
- Assets visuales para jugadores, enemigos, tilesets, fondos, UI y escenarios.

## Historia o contexto

La historia ocurre en Hollowreach, un reino que antes mantenia el equilibrio entre la vida y la muerte gracias a una energia antigua llamada The Hollow Sun. Esa fuerza fue corrompida por Dark Sun Agis, y desde las profundidades surgio Infernum Abyss, dominio de Vharok, The Ashen King.

Los protagonistas son dos jovenes separados desde pequenos que buscan a su madre desaparecida. Al encontrarse dentro de Hollowreach, descubren que sus caminos estan conectados y que en realidad son hermanos. La aventura gira alrededor de reconstruir ese pasado, enfrentar la corrupcion del mundo y entender que la desaparicion de su madre esta ligada a la caida del reino.

La narrativa esta pensada para revelarse mediante fragmentos de memoria, escritos antiguos, NPCs y eventos dentro del mundo.

## Scope principal

El alcance actual del repositorio es un prototipo funcional de metroidvania modular/procedural. El foco esta en demostrar el movimiento base, el flujo de menu a partida, la generacion de salas, combate basico, enemigos, UI, audio, guardado y soporte inicial para cooperativo local.

Implementado actualmente:

- Menu principal, pausa, HUD, pantalla de muerte y configuracion de controles.
- Modo singleplayer y modo cooperativo local inicial.
- Jugador principal, segundo jugador, spawn, camara y mapa UI.
- Movimiento, salto, dash, ataque con proyectil, dano y muerte.
- Generacion procedural/modular de habitaciones conectadas.
- Enemigos instanciados por habitacion y arena de prueba de enemigos.
- Audio de menu, gameplay, ambiente y efectos.
- Assets visuales organizados por jugadores, enemigos, tilesets, fondos y UI.

Planeado o incompleto:

- Jefes completos por zona.
- Zonas completas con progresion final.
- Puzzles cooperativos completos.
- Historia integrada directamente dentro del gameplay.
- Coleccionables, checkpoints narrativos y final del juego.
- Pulido final de balance, visuales, audio y bugs.

## Gameplay

El loop principal del prototipo es:

1. Iniciar una partida desde el menu.
2. Aparecer en una sala inicial generada por el sistema procedural.
3. Explorar habitaciones conectadas y buscar nuevas rutas.
4. Superar obstaculos mediante movimiento, salto, ataque y habilidades.
5. Combatir enemigos en salas activas.
6. Obtener mejoras o informacion narrativa en versiones futuras.
7. Desbloquear nuevos caminos y continuar la exploracion.
8. Guardar o continuar la partida desde el sistema de juego.
9. Si el jugador muere, aparece una pantalla de muerte con opcion de reintentar/continuar.

La mecanica central actual es la generacion procedural del mapa. El generador coloca una sala inicial, conecta habitaciones compatibles por puertas, evita colisiones entre salas y cierra salidas abiertas con habitaciones dead end cuando corresponde.

## Controles

Controles principales configurados en el proyecto:

| Accion | Teclado |
| --- | --- |
| Mover izquierda | A |
| Mover derecha | D |
| Saltar | Espacio |
| Dash | F |
| Atacar | Click izquierdo |
| Pausa / cancelar | Esc |
| Navegacion UI | W, A, S, D, Enter, Espacio, Esc |

El proyecto tambien incluye acciones para control en el segundo jugador, como movimiento horizontal y salto por joypad.

## Como abrir el proyecto

1. Abre Godot.
2. Importa o abre esta carpeta como proyecto.
3. Ejecuta la escena principal configurada en `project.godot`.

La escena principal actual es:

```text
res://UI/scenes/main_menu.tscn
```

El proyecto esta configurado con Godot 4.6 y usa `Forward Plus`.

## Estructura principal

```text
Audio/       Musica, ambiente, efectos de sonido y trazabilidad de audio usado.
Background/  Fondos y escena de parallax.
Enemies/     Escenas, scripts y sprites de enemigos.
Levels/      Mundo procedural, niveles de prueba y plantillas de salas.
Player1/     Jugador principal, proyectil y sprites.
Player2/     Segundo jugador y sprites.
Scripts/     Sistemas generales: GameManager, generacion, spawn, mapa, enemigos.
Tileset/     Tilesets y assets de escenarios.
UI/          Menus, HUD, pausa, controles, pantalla de muerte y tema visual.
```

## Sistemas destacados

- `Scripts/game_manager.gd`: controla inicio de partida, continuacion, guardado, modo de juego, pantalla de muerte y controles.
- `Scripts/generacion_procedural.gd`: genera la mazmorra procedural y administra habitaciones, puertas y cierres.
- `Scripts/spawn_player.gd`: instancia jugador, camara, HUD, pausa, mapa UI, segundo jugador y gestor de enemigos.
- `Scripts/gestor_enemigos.gd`: activa enemigos en la habitacion actual y habitaciones vecinas.
- `Player1/player1.gd`: movimiento, salto, dash, ataque, dano, muerte y animaciones del jugador.
- `Audio/audio_manager.gd`: reproduce musica, ambiente y SFX.

## Direccion visual

La direccion visual actual usa pixel art 2D con fantasia oscura, inspiracion tipo Hollow Knight y Castlevania, escenarios de bosque, cuevas, zonas de lava/corrupcion y castillos. El proyecto tambien conserva algunos elementos sci-fi en assets y personajes, especialmente para reforzar la diferencia entre protagonistas.

Los assets estan distribuidos principalmente en `Player1/`, `Player2/`, `Enemies/assets/`, `Tileset/`, `Background/` y `UI/`.

## Audio

El proyecto incluye musica de menu, musica de gameplay, ambiente de mundo y efectos para UI, salto, disparo, dash, dano, muerte de enemigos y reintento. La trazabilidad de los archivos usados esta documentada en:

```text
Audio/USED_AUDIO.md
```
