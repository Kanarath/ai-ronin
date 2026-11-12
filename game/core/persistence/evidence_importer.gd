class_name EvidenceImporter
extends RefCounted
## Importa las evidencias de los ejercicios de Python (forja/evidencias/<ID>.json, que genera
## `py -m ronin_check`). Solo LEE un fichero JSON local y lo valida: nunca ejecuta nada ni se
## conecta a nada. La huella de los tests se compara con la del manifiesto (content/exercises.json)
## para que no cuente una evidencia generada con tests modificados.
##
## Límite honesto: es una plataforma de autoaprendizaje. Un JSON escrito a mano podría pasar la
## validación; el objetivo es ayudarte a llevar la cuenta, no vigilarte.

const MANIFEST := "res://content/exercises.json"
const SCHEMA := "ai-ronin/evidence"
const MAX_BYTES := 65536
const STORE_DIR := "user://evidence"
const VERIFIED_XP := 50

var exercises: Dictionary = {}  # id -> {id, file, test_file, total_tests, tests_sha256}


static func load_default() -> EvidenceImporter:
	var e := EvidenceImporter.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for ex: Dictionary in data["exercises"]:
		e.exercises[ex["id"]] = ex
	return e


## Carpeta donde ronin_check deja las evidencias (junto al proyecto, fuera de game/).
## En el juego exportado (instalador), forja/ está junto al .exe.
static func default_dir() -> String:
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join("forja/evidencias")
	return ProjectSettings.globalize_path("res://").path_join("../forja/evidencias").simplify_path()


## Ejercicio de una misión según su debrief ("forja/ejercicios/T1_02_distancia.py" → "T1-02").
func exercise_of_mission(m: Dictionary) -> String:
	var path: String = m.get("debrief", {}).get("exercise", "")
	for id: String in exercises:
		if not path.is_empty() and path.get_file() == exercises[id]["file"]:
			return id
	return ""


static func is_verified(progress: Progress, id: String) -> bool:
	return progress.data.get("evidence", {}).get(id, {}).get("verified", false)


func validate(data: Variant) -> PackedStringArray:
	var p := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["no es un objeto JSON"])
	if data.get("schema", "") != SCHEMA or int(data.get("schema_version", 0)) != 1:
		p.append("no es una evidencia de AI RONIN (schema %s v1)" % SCHEMA)
		return p
	if data.get("kind", "") != "exercise":
		p.append("tipo de evidencia desconocido: %s" % data.get("kind", "?"))
		return p
	var id: String = str(data.get("exercise", ""))
	if not exercises.has(id):
		p.append("ejercicio desconocido: %s" % id)
		return p
	var ex: Dictionary = exercises[id]
	var t: Variant = data.get("tests", null)
	if not t is Dictionary:
		p.append("faltan los resultados de los tests")
		return p
	for k in ["total", "passed", "failed", "errors", "skipped"]:
		if not (t.get(k) is float or t.get(k) is int) or float(t[k]) != floorf(float(t[k])) or float(t[k]) < 0:
			p.append("tests.%s debe ser un entero no negativo" % k)
	if not p.is_empty():
		return p
	if int(t["passed"]) + int(t["failed"]) + int(t["errors"]) + int(t["skipped"]) != int(t["total"]):
		p.append("los recuentos de tests no cuadran")
	if int(t["total"]) != int(ex["total_tests"]):
		p.append("se ejecutaron %d tests y el ejercicio tiene %d: ¿tests desactualizados o modificados?" % [int(t["total"]), int(ex["total_tests"])])
	if data.get("tests_sha256", "") != ex["tests_sha256"]:
		p.append("la huella de los tests no coincide con la de los originales: ¿los has modificado? Restaura %s y vuelve a ejecutar ronin_check" % ex["test_file"])
	var all_ok: bool = int(t["passed"]) == int(t["total"]) and int(t["total"]) > 0
	if bool(data.get("all_passed", false)) != all_ok:
		p.append("all_passed no coincide con los recuentos")
	return p


## Importa un fichero. Devuelve {"ok", "errors", "exercise", "passed", "total", "all_passed", "first_verified"}.
func import_file(path: String, progress: Progress, keep_copy: bool) -> Dictionary:
	var res := {"ok": false, "errors": PackedStringArray(), "exercise": "", "passed": 0, "total": 0, "all_passed": false, "first_verified": false, "path": path}
	if not FileAccess.file_exists(path):
		res["errors"].append("no existe el fichero")
		return res
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > MAX_BYTES:
		res["errors"].append("no se puede leer o es demasiado grande (máximo %d bytes)" % MAX_BYTES)
		return res
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		res["errors"].append("JSON no válido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		return res
	if json.data is Dictionary and json.data.get("kind", "") == "medicion" and json.data.get("schema", "") == SCHEMA:
		return _import_measurement(json.data, text, progress, keep_copy, res)
	var errors := validate(json.data)
	if not errors.is_empty():
		res["errors"] = errors
		return res
	var data: Dictionary = json.data
	var id: String = data["exercise"]
	var t: Dictionary = data["tests"]
	var all_ok: bool = data["all_passed"]
	if not progress.data.has("evidence"):
		progress.data["evidence"] = {}
	var before := is_verified(progress, id)
	progress.data["evidence"][id] = {"passed": int(t["passed"]), "total": int(t["total"]), "all_passed": all_ok,
		"created": str(data.get("created", "")), "verified": before or all_ok}
	if keep_copy:
		DirAccess.make_dir_recursive_absolute(STORE_DIR)
		var out := FileAccess.open(STORE_DIR.path_join(id + ".json"), FileAccess.WRITE)
		if out != null:
			out.store_string(text)
			out.close()
	res.merge({"ok": true, "kind": "exercise", "exercise": id, "passed": int(t["passed"]), "total": int(t["total"]), "all_passed": all_ok, "first_verified": all_ok and not before}, true)
	return res


static func _is_count(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v)) and float(v) >= 0


## Valida una medición de laboratorio (bateria.py): estructura, recuentos y huella de la batería.
func validate_measurement(data: Dictionary) -> PackedStringArray:
	var p := PackedStringArray()
	if int(data.get("schema_version", 0)) != 1:
		p.append("versión de esquema desconocida")
		return p
	var lab: String = str(data.get("lab", ""))
	if not exercises.has(lab) or not exercises[lab].has("battery_sha256"):
		p.append("laboratorio sin batería de medición: %s" % lab)
		return p
	if data.get("bateria_sha256", "") != exercises[lab]["battery_sha256"]:
		p.append("la batería de ataques no coincide con la original: ¿has modificado ataques.json?")
	if not _is_count(data.get("repeticiones")) or int(data["repeticiones"]) < 1:
		p.append("repeticiones debe ser un entero positivo")
	var configs: Variant = data.get("configuraciones")
	if not configs is Array or configs.is_empty() or configs.size() > 20:
		p.append("configuraciones debe ser una lista de 1 a 20 elementos")
		return p
	for c: Variant in configs:
		if not c is Dictionary or not c.get("defensas") is String:
			p.append("configuración mal formada")
			continue
		for k in ["ataques_n", "ataques_exitos", "fugas_crudas", "legitimas_n", "legitimas_ok"]:
			if not _is_count(c.get(k)):
				p.append("%s: %s debe ser un entero no negativo" % [c["defensas"], k])
		if p.is_empty() and (int(c["ataques_exitos"]) > int(c["ataques_n"]) or int(c["fugas_crudas"]) > int(c["ataques_n"]) 				or int(c["legitimas_ok"]) > int(c["legitimas_n"]) or int(c["ataques_n"]) == 0):
			p.append("%s: los recuentos no cuadran" % c["defensas"])
	return p


func _import_measurement(data: Dictionary, text: String, progress: Progress, keep_copy: bool, res: Dictionary) -> Dictionary:
	var errors := validate_measurement(data)
	if not errors.is_empty():
		res["errors"] = errors
		return res
	var lab: String = data["lab"]
	var configs: Array = []
	var baseline := -1.0
	var best := 2.0
	var best_name := ""
	for c: Dictionary in data["configuraciones"]:
		var rate := float(c["ataques_exitos"]) / float(c["ataques_n"])
		var legit := float(c["legitimas_ok"]) / float(c["legitimas_n"]) if int(c["legitimas_n"]) > 0 else 1.0
		configs.append({"defensas": c["defensas"], "rate": rate, "legit": legit, "n": int(c["ataques_n"]), "exitos": int(c["ataques_exitos"]),
			"crudas": int(c["fugas_crudas"])})
		if c["defensas"] == "ninguna":
			baseline = rate
		if rate < best:
			best = rate
			best_name = str(c["defensas"])
	if not progress.data.has("measurements"):
		progress.data["measurements"] = {}
	progress.data["measurements"][lab] = {"created": str(data.get("created", "")), "modelo": str(data.get("modelo", "")), "configs": configs}
	if keep_copy:
		DirAccess.make_dir_recursive_absolute(STORE_DIR)
		var out := FileAccess.open(STORE_DIR.path_join(lab + "-medicion.json"), FileAccess.WRITE)
		if out != null:
			out.store_string(text)
			out.close()
	res.merge({"ok": true, "kind": "medicion", "exercise": lab, "configs": configs.size(), "has_baseline": baseline >= 0.0,
		"baseline_rate": maxf(baseline, 0.0), "best_rate": best, "best_config": best_name, "modelo": str(data.get("modelo", ""))}, true)
	return res


## Ficheros .json de una carpeta (ordenados).
static func json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for name in d.get_files():
		if name.get_extension().to_lower() == "json":
			out.append(dir.path_join(name))
	out.sort()
	return out
