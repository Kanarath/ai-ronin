class_name StudyPath
extends RefCounted
## Unidades del temario que se estudian FUERA del Dojo (sin misión): cuándo se desbloquean,
## qué preparan y qué referencias leer. El progreso se guarda en progress.data["studies"].

const PATH := "res://content/study_path.json"
const REFS_PATH := "res://content/references.json"

var units: Array = []
var refs: Dictionary = {}  # id -> referencia


static func load_default() -> StudyPath:
	var s := StudyPath.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	s.units = data["units"]
	var rdata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFS_PATH))
	for r: Dictionary in rdata["references"]:
		s.refs[r["id"]] = r
	return s


func unit(id: String) -> Dictionary:
	for u: Dictionary in units:
		if String(u["id"]).to_lower() == id.to_lower():
			return u
	return {}


static func is_studied(progress: Progress, id: String) -> bool:
	return progress.data.get("studies", {}).get(id, {}).get("done", false)


## "estudiada", "disponible" o "bloqueada".
func status(progress: Progress, id: String) -> String:
	var u := unit(id)
	if u.is_empty():
		return ""
	if is_studied(progress, u["id"]):
		return "estudiada"
	return "disponible" if missing(progress, id).is_empty() else "bloqueada"


## Requisitos que faltan (misiones o estudios).
func missing(progress: Progress, id: String) -> PackedStringArray:
	var u := unit(id)
	var out := PackedStringArray()
	for m: String in u["unlock"]["missions"]:
		if not progress.is_mission_completed(m):
			out.append(m)
	for s: String in u["unlock"]["studies"]:
		if not is_studied(progress, s):
			out.append(s)
	return out


func mark_studied(progress: Progress, id: String) -> void:
	if not progress.data.has("studies"):
		progress.data["studies"] = {}
	progress.data["studies"][unit(id)["id"]] = {"done": true}


## Dónde va una unidad en el temario: tras la unidad de su última misión requisito o,
## si solo depende de estudios, tras la última unidad de estudio requisito.
func anchor_of(u: Dictionary, catalog: MissionCatalog) -> String:
	var missions: Array = u["unlock"]["missions"]
	if not missions.is_empty():
		return catalog.get_mission(missions[-1]).get("unit", "")
	var studies: Array = u["unlock"]["studies"]
	return studies[-1] if not studies.is_empty() else ""


## Unidades que se desbloquean justo al completar `mission_id` (y no lo estaban antes).
func unlocked_by(progress: Progress, mission_id: String) -> Array:
	var out: Array = []
	for u: Dictionary in units:
		if mission_id in u["unlock"]["missions"] and status(progress, u["id"]) == "disponible":
			out.append(u)
	return out


## Unidades recomendadas antes de `mission_id` que aún no se han estudiado.
func pending_before(progress: Progress, mission_id: String) -> Array:
	var out: Array = []
	for u: Dictionary in units:
		if mission_id in u["recommended_before"] and not is_studied(progress, u["id"]):
			out.append(u)
	return out
