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
static func default_dir() -> String:
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
	res.merge({"ok": true, "exercise": id, "passed": int(t["passed"]), "total": int(t["total"]), "all_passed": all_ok, "first_verified": all_ok and not before}, true)
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
