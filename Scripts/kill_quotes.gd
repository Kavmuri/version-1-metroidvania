class_name KillQuotes
extends RefCounted

const KAIZEN_QUOTES: Array[String] = [
	"Uno menos. Vamos bien.",
	"Perdón, pero no tenía otra opción.",
	"Eso estuvo casi elegante.",
	"Ojalá todos cayeran así de fácil.",
	"Un paso más cerca de encontrarte, mamá.",
	"La corrupción no te dejó mucho, ¿eh?",
	"Tranquilo. Ya no vas a sentir nada.",
	"Si esto es obra de Agis, tiene muy mal gusto.",
	"Cuando encuentre a Vharok, no va a ser tan fácil.",
	"El Hollow Sun te dejó bastante mal.",
	"No fue personal... bueno, un poco sí.",
	"Uno más, y todavía sin respuestas.",
]

const ELDRIC_QUOTES: Array[String] = [
	"Descansa. Ya no vas a sufrir más.",
	"No fue venganza. Fue piedad.",
	"Mis puños todavía cargan la vieja magia.",
	"El Hollow Sun te condenó antes que yo.",
	"Que la oscuridad no te reclame dos veces.",
	"Otra víctima de Agis. Que descanses en paz.",
	"Si Vharok te envió, dile que voy a llegar.",
	"Madre... espero que esto también te hubiera dolido a ti.",
	"Ni la corrupción te dejó un final digno.",
	"Mi madre hubiera llorado por ti, criatura.",
	"Uno menos entre nosotros y la verdad.",
	"El reino ya perdió demasiado. Tú no le vas a quitar más.",
]

static var _last_kaizen_index := -1
static var _last_eldric_index := -1

static func random_kaizen_quote() -> String:
	var index := _random_index_excluding(KAIZEN_QUOTES.size(), _last_kaizen_index)
	_last_kaizen_index = index
	return KAIZEN_QUOTES[index]

static func random_eldric_quote() -> String:
	var index := _random_index_excluding(ELDRIC_QUOTES.size(), _last_eldric_index)
	_last_eldric_index = index
	return ELDRIC_QUOTES[index]

static func _random_index_excluding(size: int, excluded: int) -> int:
	if size <= 1:
		return 0
	var index := randi_range(0, size - 1)
	while index == excluded:
		index = randi_range(0, size - 1)
	return index
