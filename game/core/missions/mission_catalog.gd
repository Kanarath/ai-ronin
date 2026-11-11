class_name MissionCatalog
extends RefCounted
## Carga y valida las misiones de res://content/missions/*.json.
## Una misión con errores se descarta y el error queda en `errors` (lo comprueba un test).

const MISSIONS_DIR := "res://content/missions"
const REQUIRED := ["id", "title", "unit", "difficulty", "briefing", "objectives", "competencies", "debrief"]
const VALIDATOR_TYPES := ["event", "sequence", "all", "any", "not", "answer", "hypothesis", "reflection"]
const DIFFICULTY_NAMES := ["", "Initiate", "Apprentice", "Engineer", "Specialist", "Master"]

var missions: Array[Dictionary] = []
var errors: PackedStringArray = []


static func load_default() -> MissionCatalog:
	var cat := MissionCatalog.new()
	cat.load_dir(MISSIONS_DIR)
	cat._sort()
	return cat


func load_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("no existe " + dir_path)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var path := dir_path.path_join(f)
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			errors.append("%s:%d %s" % [f, json.get_error_line(), json.get_error_message()])
			continue
		if not json.data is Dictionary:
			errors.append(f + ": la raíz debe ser un objeto")
			continue
		var problems := validate(json.data)
		if problems.is_empty():
			missions.append(json.data)
		else:
			for p in problems:
				errors.append("%s: %s" % [f, p])


## Orden del currículo: primero el tronco común (T…), después la pista de Python (P…, que se
## abre al terminar T6), los arcos (A…), luego el resto y, al final, las especializaciones (E…).
func _sort() -> void:
	# Si existe el mapa del curso, manda su orden de unidades (el pedagógico: T7 va tras T3, T8
	# tras T4…); las unidades que no estén en el mapa van detrás, con la regla de siempre.
	var map_order: Array = []
	if FileAccess.file_exists("res://content/mapa.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/mapa.json"))
		if d is Dictionary:
			for x: Dictionary in d.get("unidades", []):
				map_order.append(str(x["unit"]))
	var rank := func(m: Dictionary) -> String:
		var u: String = m["unit"]
		var num := int(String(m["id"]).get_slice("-", 1))
		var pos := map_order.find(u)
		if pos >= 0:
			return "0%03d%03d" % [pos, num]
		var group := "1" if u.begins_with("T") else ("2" if u.begins_with("P") else ("3" if u.begins_with("A") else ("5" if u.begins_with("E") else "4")))
		return group + String(m["id"])
	missions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return rank.call(a) < rank.call(b))


func get_mission(id: String) -> Dictionary:
	for m in missions:
		if m["id"] == id:
			return m
	return {}


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for m in missions:
		out.append(m["id"])
	return out


static func validate(m: Dictionary) -> PackedStringArray:
	var p := PackedStringArray()
	for key: String in REQUIRED:
		if not m.has(key):
			p.append("falta el campo '%s'" % key)
	if not p.is_empty():
		return p
	var all_objectives: Array = m["objectives"].duplicate()
	all_objectives.append_array(m.get("mastery_trial", {}).get("objectives", []))
	var seen := {}
	for o: Dictionary in all_objectives:
		var oid: String = o.get("id", "?")
		for key in ["id", "text", "validator", "hints"]:
			if not o.has(key):
				p.append("objetivo %s: falta '%s'" % [oid, key])
		if o.has("hints") and (o["hints"].size() < 1 or o["hints"].size() > 5):
			p.append("objetivo %s: debe tener entre 1 y 5 pistas" % oid)
		if o.has("validator"):
			_validate_validator(o["validator"], "objetivo %s" % oid, p)
		for d: Dictionary in o.get("diagnostics", []):
			if not d.has("when") or not d.has("message"):
				p.append("objetivo %s: diagnóstico sin 'when' o 'message'" % oid)
			else:
				_validate_validator(d["when"], "diagnóstico de %s" % oid, p)
		seen[oid] = true
	return p


static func _validate_validator(v: Variant, where: String, p: PackedStringArray) -> void:
	if not v is Dictionary or not v.get("type", "") in VALIDATOR_TYPES:
		p.append("%s: validador con tipo desconocido (%s)" % [where, str(v)])
		return
	match v["type"]:
		"event":
			if not v.has("event"):
				p.append("%s: validador 'event' sin 'event'" % where)
		"sequence":
			for s in v.get("steps", []):
				_validate_validator(s, where, p)
		"all", "any":
			for s in v.get("of", []):
				_validate_validator(s, where, p)
		"not":
			_validate_validator(v.get("of"), where, p)
		"answer":
			if not v.has("expected"):
				p.append("%s: validador 'answer' sin 'expected'" % where)
