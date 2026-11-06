class_name ContentLibrary
extends RefCounted
## Glosario y manual cargados desde res://content (JSON).

const GLOSSARY_PATH := "res://content/glossary.json"
const MANUAL_PATH := "res://content/manual.json"
const EPISTEMIC_LABELS := {
	"consolidado": "concepto consolidado",
	"practica-industria": "práctica de la industria",
	"emergente": "técnica emergente",
	"experimental": "investigación experimental",
	"modelo-simplificado": "modelo simplificado ⚗",
	"recomendacion-propia": "recomendación propia",
}

var terms: Array[Dictionary] = []
var topics: Dictionary = {}  # id -> {title, body, see_also}
var errors: PackedStringArray = []
var _index: Dictionary = {}  # clave en minúsculas (término o alias) -> entrada


static func load_default() -> ContentLibrary:
	var lib := ContentLibrary.new()
	lib.load_from(GLOSSARY_PATH, MANUAL_PATH)
	return lib


func load_from(glossary_path: String, manual_path: String) -> void:
	var g: Variant = _read_json(glossary_path)
	if g is Dictionary:
		for t: Dictionary in g.get("terms", []):
			add_term(t)
	var m: Variant = _read_json(manual_path)
	if m is Dictionary:
		for t: Dictionary in m.get("topics", []):
			topics[t["id"]] = t


func add_term(t: Dictionary) -> void:
	for key in ["id", "term", "short", "body", "epistemic"]:
		if not t.has(key):
			errors.append("glosario: falta '%s' en %s" % [key, str(t.get("id", "?"))])
			return
	terms.append(t)
	_index[String(t["term"]).to_lower()] = t
	_index[String(t["id"]).to_lower()] = t
	for alias: String in t.get("aliases", []):
		_index[alias.to_lower()] = t


func find_term(query: String) -> Dictionary:
	return _index.get(query.strip_edges().to_lower(), {})


func term_keys() -> PackedStringArray:
	return PackedStringArray(_index.keys())


func topic_ids() -> PackedStringArray:
	var out := PackedStringArray(topics.keys())
	out.sort()
	return out


func epistemic_label(tag: String) -> String:
	return EPISTEMIC_LABELS.get(tag, tag)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("no existe " + path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
