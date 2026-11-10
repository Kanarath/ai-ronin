extends TestCase
## Tests de las evidencias de los ejercicios de Python (ronin_check → evidence import).

const TMP := "user://test_evidence"

var game: DojoGame


func before_each() -> void:
	game = DojoGame.new("")
	DirAccess.make_dir_recursive_absolute(TMP)
	for f in EvidenceImporter.json_files(TMP):
		DirAccess.remove_absolute(f)


## Evidencia como la que escribiría ronin_check para `id` con `passed` tests correctos.
func _evidence(id: String, passed: int) -> Dictionary:
	var ex: Dictionary = game.evidence.exercises[id]
	var total: int = ex["total_tests"]
	return {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "exercise", "exercise": id, "file": ex["file"],
		"created": "2026-11-10T08:00:00+00:00", "python": "3.13.17",
		"tests": {"total": total, "passed": passed, "failed": 0, "errors": total - passed, "skipped": 0, "not_implemented": total - passed},
		"all_passed": passed == total, "failing": [], "tests_sha256": ex["tests_sha256"]}


func _write(name: String, data: Variant) -> String:
	var path := TMP.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data) if not data is String else data)
	f.close()
	return path


static func _sha256_normalized(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8().replace("\r\n", "\n")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


func test_manifiesto_al_dia_con_los_ficheros_de_tests() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../forja/ejercicios").simplify_path()
	var files := PackedStringArray()
	for name in DirAccess.get_files_at(dir):
		if name.begins_with("test_") and name.get_extension() == "py":
			files.append(name)
	assert_eq(game.evidence.exercises.size(), files.size(), "un ejercicio por fichero de tests")
	for id: String in game.evidence.exercises:
		var ex: Dictionary = game.evidence.exercises[id]
		assert_true(ex["test_file"] in files, "%s: no existe %s" % [id, ex["test_file"]])
		assert_eq(_sha256_normalized(dir.path_join(ex["test_file"])), ex["tests_sha256"],
			"%s: tests cambiados; regenera el manifiesto con py -m ronin_check --manifiesto" % id)


func test_cada_mision_apunta_a_un_ejercicio_que_existe() -> void:
	for m: Dictionary in game.catalog.missions:
		var path: String = m.get("debrief", {}).get("exercise", "")
		if not path.is_empty():
			assert_ne(game.evidence.exercise_of_mission(m), "", "%s: %s no está en el manifiesto" % [m["id"], path])


func test_importar_verificado_da_xp_una_vez() -> void:
	var xp := game.progress.xp()
	var res := game.import_evidence(_write("T1-02.json", _evidence("T1-02", 12)))
	assert_true(res["ok"], str(res["errors"]))
	assert_true(res["first_verified"])
	assert_eq(game.progress.xp(), xp + EvidenceImporter.VERIFIED_XP)
	assert_true(EvidenceImporter.is_verified(game.progress, "T1-02"))
	res = game.import_evidence(_write("T1-02.json", _evidence("T1-02", 12)))
	assert_false(res["first_verified"])
	assert_eq(game.progress.xp(), xp + EvidenceImporter.VERIFIED_XP, "no se repite el XP")
	assert_eq(game.shell.events_named("evidence.imported")[-1]["data"]["all_passed"], true)


func test_parcial_no_verifica_y_no_quita_lo_ganado() -> void:
	assert_true(game.import_evidence(_write("a.json", _evidence("T2-01", 5)))["ok"])
	assert_false(EvidenceImporter.is_verified(game.progress, "T2-01"))
	game.import_evidence(_write("a.json", _evidence("T2-01", 12)))
	game.import_evidence(_write("a.json", _evidence("T2-01", 3)))
	assert_true(EvidenceImporter.is_verified(game.progress, "T2-01"), "una vez verificado, se queda")


func test_rechazos() -> void:
	var bad := _evidence("T1-02", 12)
	bad["tests_sha256"] = "0".repeat(64)
	assert_true("; ".join(game.import_evidence(_write("b.json", bad))["errors"]).contains("huella"))
	bad = _evidence("T1-02", 12)
	bad["tests"]["total"] = 3
	bad["tests"]["passed"] = 3
	bad["tests"]["errors"] = 0
	assert_false(game.import_evidence(_write("b.json", bad))["ok"], "tests de menos")
	bad = _evidence("T1-02", 5)
	bad["all_passed"] = true
	assert_false(game.import_evidence(_write("b.json", bad))["ok"], "all_passed mentiroso")
	bad = _evidence("T1-02", 12)
	bad["exercise"] = "Z9-99"
	assert_false(game.import_evidence(_write("b.json", bad))["ok"])
	assert_false(game.import_evidence(_write("b.json", "{no es json"))["ok"])
	assert_false(game.import_evidence(_write("b.json", {"hola": 1}))["ok"])
	assert_false(game.import_evidence(TMP.path_join("no-existe.json"))["ok"])
	assert_eq(game.progress.data.get("evidence", {}).size(), 0, "nada rechazado queda guardado")


func test_comandos() -> void:
	_write("T3-02.json", _evidence("T3-02", 6))
	_write("basura.json", "{}")
	var r := game.shell.execute("evidence import \"%s\"" % ProjectSettings.globalize_path(TMP))
	assert_true(r.ok, r.plain_text())
	assert_true(r.plain_text().contains("✓ verificado"))
	assert_true(r.plain_text().contains("✗ rechazada"))
	r = game.shell.execute("evidence list")
	assert_true(r.plain_text().contains("1 de %d verificados" % game.evidence.exercises.size()))
	assert_true(r.plain_text().contains("T3-02"))
	assert_false(game.shell.execute("evidence import \"%s\"" % ProjectSettings.globalize_path(TMP.path_join("vacia"))).ok)


func test_el_mentor_recuerda_el_ejercicio() -> void:
	var said: Array[String] = []
	game.runner.mentor_message.connect(func(t: String, _k: String) -> void: said.append(t))
	game.progress.data["missions"]["T1-01"] = {"completed": true}
	assert_eq(game.start_mission("T1-02"), "")
	game.runner._finish(false)
	assert_true(said.any(func(t: String) -> bool: return t.contains("py -m ronin_check T1-02")))
