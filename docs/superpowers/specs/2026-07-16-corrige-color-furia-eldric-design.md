# Correccion del color de furia de Eldric

Autor: ALFREDO RUIZ

## Objetivo

Evitar que la furia cambie la apariencia de Eldric y reemplazar solamente el fuego azul o cian de sus ataques por rojo.

## Diseño aprobado

- La piel, la ropa y los colores normales de Eldric permanecen intactos.
- El efecto de paleta se habilita solo durante animaciones ofensivas o el planeo ofensivo.
- El shader selecciona unicamente pixeles brillantes con predominio simultaneo de verde y azul sobre rojo; esto excluye los tonos de piel y ropa.
- Desde la primera carga hasta la quinta, el unico color de reemplazo es rojo.
- Al perder las cargas, el fuego vuelve a su azul original.
- No se crean texturas ni sprites alternativos.

## Verificacion

- La primera y la quinta carga producen exactamente el mismo rojo.
- Fuera de una animacion ofensiva, la intensidad del shader es cero aunque existan cargas.
- Durante un ataque con cargas, la intensidad es completa.
- El shader conserva una mascara de brillo, saturacion y predominio cian antes de reemplazar el color.
