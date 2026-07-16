# Ajustes de las mejoras de Eldric

Autor: ALFREDO RUIZ

## Objetivo

Ajustar el escudo, la furia creciente y el dash para que sus controles y su progresion coincidan con el diseño aprobado.

## Escudo espectral

- Se desbloquea en el nivel 3, pero no se mantiene activo automaticamente.
- Eldric entra en guardia mientras el jugador mantiene presionado el clic derecho.
- El shader del escudo solo se muestra durante la guardia y si la carga esta disponible.
- Mientras Eldric esta en guardia no puede lanzar ataques.
- Un golpe recibido durante la guardia consume la carga sin quitar vida.
- Un golpe recibido fuera de la guardia causa dano aunque la carga este disponible.
- La carga consumida se recupera automaticamente despues de 12 segundos.

## Dash evolutivo

- Nivel 2: `F` ejecuta el dash normal, usa `agacharP2`, desplaza y no hace dano.
- Nivel 5: el mismo `F` convierte el dash en golpe perforante, usa `golpeaireP2`, desplaza, golpea y atraviesa enemigos.
- Nivel 7: el dash conserva el golpe perforante y, si se inicio en el aire, termina en un planeo de un segundo sin gravedad usando `golpeaireP2`.
- El boton de ataque deja de iniciar el golpe perforante; esa evolucion pertenece exclusivamente al dash.

## Furia creciente en debug

- En una partida normal, las cargas siguen dependiendo de golpes que alcanzan enemigos.
- En `enemy_arena`, cada ataque ofensivo lanzado suma una carga aunque no alcance un enemigo.
- Un ataque lanzado solo puede sumar una carga, incluso si atraviesa varios enemigos.
- El maximo sigue siendo cinco cargas, con 20 % adicional por carga y el doble de dano al maximo.
- El temporizador de dos segundos y la perdida de cargas al recibir dano se conservan.

## Verificacion

- Pruebas automatizadas para guardia manual, dano sin guardia, bloqueo de ataques y recarga.
- Pruebas de los tres estados del dash y sus animaciones.
- Pruebas de furia en debug sin enemigos y sin cargas dobles al golpear.
- Regresiones del selector de mejoras y del flujo singleplayer.
