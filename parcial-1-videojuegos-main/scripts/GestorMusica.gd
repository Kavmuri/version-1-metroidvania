extends Node

# ── Arrastra aquí tus AudioStream (.ogg / .mp3) desde el Inspector ────────────
@export var bandas_sonoras: Array[AudioStream] = []

@export var volumen_db: float = -10.0   # ajusta desde el Inspector

var _player: AudioStreamPlayer
var _banda_actual: int = -1

# ─────────────────────────────────────────────────────
func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"        # usa el bus "Music" si lo tienes, si no cae al Master
	_player.volume_db = volumen_db
	add_child(_player)

	if bandas_sonoras.is_empty():
		push_warning("GestorMusica: no hay bandas sonoras asignadas en el Inspector.")
		return

	_elegir_y_reproducir()

# ─────────────────────────────────────────────────────
func _elegir_y_reproducir() -> void:
	# Elige un índice distinto al anterior para no repetir la misma dos veces seguidas
	var opciones = range(bandas_sonoras.size())
	if opciones.size() > 1:
		opciones.erase(_banda_actual)

	_banda_actual = opciones[randi() % opciones.size()]
	_player.stream = bandas_sonoras[_banda_actual]
	_player.play()
	print("GestorMusica: reproduciendo banda ", _banda_actual + 1, " de ", bandas_sonoras.size())

# ─────────────────────────────────────────────────────
# Llamadas opcionales desde otros scripts

func detener() -> void:
	_player.stop()

func siguiente() -> void:
	_elegir_y_reproducir()

func set_volumen(db: float) -> void:
	volumen_db = db
	_player.volume_db = db
