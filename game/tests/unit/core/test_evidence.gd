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
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var files := PackedStringArray()
	for name in DirAccess.get_files_at(root.path_join("forja/ejercicios")):
		if name.begins_with("test_") and name.get_extension() == "py":
			files.append("forja/ejercicios/" + name)
	for lab in DirAccess.get_directories_at(root.path_join("forja/labs")):
		for name in DirAccess.get_files_at(root.path_join("forja/labs").path_join(lab)):
			if name.begins_with("test_") and name.get_extension() == "py":
				files.append("forja/labs/%s/%s" % [lab, name])
	assert_eq(game.evidence.exercises.size(), files.size(), "un ejercicio por fichero de tests")
	for id: String in game.evidence.exercises:
		var ex: Dictionary = game.evidence.exercises[id]
		assert_true(ex["test_path"] in files, "%s: no existe %s" % [id, ex["test_path"]])
		assert_eq(_sha256_normalized(root.path_join(ex["test_path"])), ex["tests_sha256"],
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


func test_mision_P0_01() -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	game.progress.data["missions"]["T6-02"] = {"completed": true}
	assert_eq(game.start_mission("P0-01"), "")
	assert_true(game.import_evidence(_write("P0-01.json", _evidence("P0-01", 1)))["ok"])
	assert_eq(game.runner.index, 1)
	game.import_evidence(_write("P0-01.json", _evidence("P0-01", 17)))
	assert_eq(game.runner.index, 2)
	for l in ["hipotesis entre 2 y 4", "reflexion " + "con temperatura alta salieron respuestas distintas y con temperatura cero y semilla fija salio siempre la misma ".repeat(4),
			"reflexion " + "en cero cero cero cero cualquiera de la red podria usar el modelo y gastar mi cpu y los errores internos revelan rutas ".repeat(3)]:
		var res := game.shell.execute(l)
		assert_true(res.ok, res.plain_text())
	assert_eq(finished.size(), 1)


func _measurement(configs: Array, lab: String = "A1-05") -> Dictionary:
	return {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": lab, "created": "2026-11-10T09:00:00+00:00",
		"modelo": "llama3.2:1b", "temperatura": 0.7, "repeticiones": 3, "bateria_sha256": game.evidence.exercises[lab]["battery_sha256"],
		"configuraciones": configs}


static func _cfg(defensas: String, exitos: int, legit_ok: int = 15) -> Dictionary:
	return {"defensas": defensas, "ataques_n": 18, "ataques_exitos": exitos, "fugas_crudas": exitos, "legitimas_n": 15, "legitimas_ok": legit_ok}


func test_medicion_valida() -> void:
	var res := game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 12), _cfg("salida", 0), _cfg("sin-secreto", 0, 14)])))
	assert_true(res["ok"], str(res["errors"]))
	var ev: Dictionary = game.shell.events_named("evidence.measured")[-1]["data"]
	assert_eq([ev["lab"], ev["configs"], ev["has_baseline"]], ["A1-05", 3, true])
	assert_almost_eq(ev["baseline_rate"], 12.0 / 18.0, 0.0001)
	assert_eq(ev["best_rate"], 0.0)
	assert_true(game.shell.execute("evidence list").plain_text().contains("ninguna 12/18"))


func test_medicion_rechazos() -> void:
	var bad := _measurement([_cfg("ninguna", 5)])
	bad["bateria_sha256"] = "0".repeat(64)
	assert_true("; ".join(game.import_evidence(_write("m.json", bad))["errors"]).contains("batería"))
	assert_false(game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 19)])))["ok"], "más éxitos que intentos")
	assert_false(game.import_evidence(_write("m.json", _measurement([])))["ok"])
	bad = _measurement([_cfg("ninguna", 5)])
	bad["lab"] = "P0-01"
	assert_false(game.import_evidence(_write("m.json", bad))["ok"], "P0-01 no tiene batería")
	assert_eq(game.progress.data.get("measurements", {}).size(), 0)


func test_mision_A1_05() -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m in ["A1-04", "P0-01"]:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission("A1-05"), "")
	game.import_evidence(_write("a.json", _evidence("A1-05", 19)))
	assert_eq(game.runner.index, 1)
	assert_true(game.shell.execute("hipotesis a veces").ok)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("entrada", 6)])))
	assert_eq(game.runner.index, 1, "hacen falta 3 configuraciones")
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("entrada", 6), _cfg("sin-secreto", 0)])))
	assert_eq(game.runner.index, 2)
	for l in ["reflexion " + "sin defensas se filtro la mitad de las veces y el intervalo era ancho porque hay pocas repeticiones ".repeat(4),
			"reflexion " + "sin el secreto en el prompt el modelo no puede filtrarlo y el filtro de salida no ve traducciones ".repeat(3)]:
		var r := game.shell.execute(l)
		assert_true(r.ok, r.plain_text())
	assert_eq(finished.size(), 1)


func test_mision_A2_04() -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m in ["A2-03", "A1-05"]:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission("A2-04"), "")
	game.import_evidence(_write("a.json", _evidence("A2-04", 20)))
	assert_eq(game.runner.index, 1)
	assert_true(game.shell.execute("hipotesis lo frena a veces").ok)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("acl", 6), _cfg("acl,procedencia,spotlight", 0)], "A1-05")))
	assert_eq(game.runner.index, 1, "la medición de A1-05 no vale para A2-04")
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("acl", 6), _cfg("acl,procedencia,spotlight", 0)], "A2-04")))
	assert_eq(game.runner.index, 2)
	for l in ["reflexion " + "la busqueda hibrida recupero mejor y acl dejo la fuga a cero porque el documento interno no llego al contexto ".repeat(4),
			"reflexion " + "el rol sale del token porque el cliente puede escribir cualquier cosa y la firma prueba integridad no verdad ".repeat(3)]:
		var r := game.shell.execute(l)
		assert_true(r.ok, r.plain_text())
	assert_eq(finished.size(), 1)



## Misiones P0-02…P0-05 (ejercicios de clases, NumPy, Unicode y generadores): bloqueadas sin
## sus requisitos; después, evidencia, evidencia completa y las órdenes del terminal `lineas`.
func _run_p0(id: String, previas: Array, lineas: Array) -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	assert_ne(game.start_mission(id), "", "%s bloqueada sin sus requisitos" % id)
	for m: String in previas:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission(id), "")
	assert_eq(game.evidence.exercise_of_mission(game.catalog.get_mission(id)), id)
	assert_true(game.import_evidence(_write("p.json", _evidence(id, 0)))["ok"])
	assert_eq(game.runner.index, 1)
	game.import_evidence(_write("p.json", _evidence(id, game.evidence.exercises[id]["total_tests"])))
	assert_eq(game.runner.index, 2)
	for l: String in lineas:
		var res := game.shell.execute(l)
		assert_true(res.ok, "%s: %s" % [l, res.plain_text()])
	assert_eq(finished.size(), 1, id)


func test_mision_P0_02() -> void:
	_run_p0("P0-02", ["T4-01"], ["answer 0.871", "hipotesis más de 50 veces", "reflexion " +
		"con doscientas cuarenta filas numpy fue doce veces mas rapido y con doce mil setenta veces porque el coste fijo de cada llamada se reparte entre mas filas mientras python puro paga cada multiplicacion ".repeat(2)])


func test_mision_P0_03() -> void:
	_run_p0("P0-03", ["T4-02", "P0-02"], ["answer 0.0024", "reflexion " +
		"el bucle para cada ejemplo de t4 02 esta ahora dentro de los productos de matrices la forma n por h guarda una fila por ejemplo y sum axis cero suma los gradientes de los sesgos ".repeat(2)])


func test_mision_P0_04() -> void:
	_run_p0("P0-04", ["T5-01"], ["hipotesis 8", "answer 17", "reflexion " +
		"sin nfc el filtro no veria la palabra escrita con el acento suelto y sin el decodificador incremental la ñ partida daria un error de decodificacion ".repeat(2)])


func test_mision_P0_05() -> void:
	_run_p0("P0-05", ["T6-01", "P0-04"], ["hipotesis no", "answer paciencia", "reflexion " +
		"el generador entrega cada token en cuanto existe y si el usuario para el modelo deja de trabajar el limite va en el servidor porque el cliente puede pedir lo que quiera ".repeat(2)])
func test_mision_A3_04() -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m in ["A3-03", "A2-04"]:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission("A3-04"), "")
	game.import_evidence(_write("a.json", _evidence("A3-04", 27)))
	assert_eq(game.runner.index, 0, "con un test sin pasar no se avanza")
	game.import_evidence(_write("a.json", _evidence("A3-04", 28)))
	assert_eq(game.runner.index, 1)
	assert_true(game.shell.execute("hipotesis más o menos las mismas").ok)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("permisos", 6), _cfg("aprobacion,permisos", 2)], "A2-04")))
	assert_eq(game.runner.index, 1, "la medición de A2-04 no vale para A3-04")
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("permisos", 6),
		_cfg("aprobacion,exfiltracion,limites,permisos,spotlight", 0, 13)], "A3-04")))
	assert_eq(game.runner.index, 2)
	for l in ["reflexion " + "el modelo siguio pidiendo reembolsos con permisos y aprobacion pero no se ejecutaron y la fuga de memoria solo la paro el detector ".repeat(4),
			"reflexion " + "la accion aprobada la ejecuta el servicio porque el modelo podria cambiarla y un humano no aprueba lo que el rol no permite ".repeat(3)]:
func test_mision_A4_04() -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m in ["A4-03", "P0-01"]:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission("A4-04"), "")
	game.import_evidence(_write("a.json", _evidence("A4-04", 28)))
	assert_eq(game.runner.index, 1)
	assert_true(game.shell.execute("hipotesis la revision en el host").ok)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 6), _cfg("scopes", 3), _cfg("scopes,validacion,rutas,audiencia,pinning,revision", 0)], "A2-04")))
	assert_eq(game.runner.index, 1, "la medición de A2-04 no vale para A4-04")
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 6), _cfg("scopes", 3), _cfg("scopes,validacion,rutas,audiencia,pinning,revision", 0)], "A4-04")))
	assert_eq(game.runner.index, 2)
	for l in ["reflexion " + "las defensas del host paran el ataque antes de que el modelo vea la descripcion y las del servidor lo rechazan cuando la llamada ya llego ".repeat(3),
			"reflexion " + "el servidor comprueba la audiencia del token para no aceptar uno emitido para otro servidor y exige los scopes minimos ".repeat(3)]:
func test_mision_A6_04() -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m in ["A6-03", "P0-01"]:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission("A6-04"), "")
	game.import_evidence(_write("a.json", _evidence("A6-04", 26)))
	assert_eq(game.runner.index, 0, "faltan tests por pasar")
	game.import_evidence(_write("a.json", _evidence("A6-04", 27)))
	assert_eq(game.runner.index, 1)
	assert_true(game.shell.execute("hipotesis no detecta ninguno").ok)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 18), _cfg("bom", 16), _cfg("bom,deps,docker,pickle,safetensors", 1)], "A2-04")))
	assert_eq(game.runner.index, 1, "la medición de A2-04 no vale para A6-04")
	var cfgs := [{"defensas": "ninguna", "ataques_n": 22, "ataques_exitos": 22, "fugas_crudas": 5, "legitimas_n": 11, "legitimas_ok": 11},
		{"defensas": "bom", "ataques_n": 22, "ataques_exitos": 20, "fugas_crudas": 5, "legitimas_n": 11, "legitimas_ok": 11},
		{"defensas": "bom,deps,docker,pickle,safetensors", "ataques_n": 22, "ataques_exitos": 1, "fugas_crudas": 0, "legitimas_n": 11, "legitimas_ok": 11}]
	var res := game.import_evidence(_write("m.json", _measurement(cfgs, "A6-04")))
	assert_true(res["ok"], str(res["errors"]))
	assert_eq(game.runner.index, 2)
	game.shell.execute("answer 2")
	assert_eq(game.runner.index, 2, "con todos los controles se escapa uno")
	assert_true(game.shell.execute("answer 1").ok)
	assert_eq(game.runner.index, 3)
	for l in ["reflexion " + "el bom solo compara huellas y el pickle malicioso estaba declarado con su huella correcta asi que paso el modo estricto rompe el tokenizador ".repeat(4),
			"reflexion " + "cargar un pickle es ejecutarlo la huella prueba que no cambio y la firma prueba quien lo publico y un nombre inventado se puede registrar ".repeat(3)]:
		var r := game.shell.execute(l)
		assert_true(r.ok, r.plain_text())
	assert_eq(finished.size(), 1)
## E1 (investigación ML): evidencia de los tests del laboratorio, hipótesis y dos reflexiones.
func _mision_E1(id: String, requisitos: Array, tests: int, hipotesis: String) -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m: String in requisitos:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission(id), "", id)
	game.import_evidence(_write("e.json", _evidence(id, tests - 1)))
	assert_eq(game.runner.index, 0, "%s: con un test sin pasar no avanza" % id)
	game.import_evidence(_write("e.json", _evidence(id, tests)))
	assert_eq(game.runner.index, 1, id)
	assert_true(game.shell.execute("hipotesis " + hipotesis).ok, hipotesis)
	for l in ["reflexion " + "mi bucle coincidio con generate y la cuantizacion por bloques casi no cambio la perplejidad del modelo pequeno ".repeat(5),
			"reflexion " + "entrenar de verdad necesita gradientes y estados del optimizador por cada peso y eso no cabe en mi portatil sin gpu ".repeat(4)]:
## Las tres misiones de E2 siguen el mismo patrón: evidencia de tests → predicción → medición → dos reflexiones.
func _mision_E2(id: String, requires: Array, tests: int, prediction: String) -> void:
	var finished: Array = []
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))
	for m: String in requires:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission(id), "")
	game.import_evidence(_write("a.json", _evidence(id, tests)))
	assert_eq(game.runner.index, 1, id)
	assert_true(game.shell.execute("hipotesis " + prediction).ok)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("otra", 6)], id)))
	assert_eq(game.runner.index, 1, "%s: hacen falta 3 configuraciones" % id)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("otra", 6), _cfg("dos", 3)], "A2-04")))
	assert_eq(game.runner.index, 1, "%s: la medición de otro laboratorio no vale" % id)
	game.import_evidence(_write("m.json", _measurement([_cfg("ninguna", 9), _cfg("otra", 6), _cfg("dos", 3)], id)))
	assert_eq(game.runner.index, 2, id)
	for l in ["reflexion " + "sin defensas el ataque funciono casi siempre y la defensa redujo la tasa pero costo precision en los datos limpios ".repeat(4),
			"reflexion " + "un atacante adaptativo conoce la defensa y la incorpora a su ataque asi que medir sin el no demuestra nada ".repeat(3)]:
		var r := game.shell.execute(l)
		assert_true(r.ok, r.plain_text())
	assert_eq(finished.size(), 1, id)


func test_mision_E1_01() -> void:
	assert_false(game.start_mission("E1-01").is_empty(), "bloqueada sin T6-02 ni P0-01")
	_mision_E1("E1-01", ["T6-02", "P0-01"], 17, "más de 3 veces")


func test_mision_E1_02() -> void:
	_mision_E1("E1-02", ["E1-01"], 12, "menos de un 1 %")


func test_mision_E1_03() -> void:
	_mision_E1("E1-03", ["E1-02"], 15, "hacia la mitad")
func test_mision_E2_01() -> void:
	_mision_E2("E2-01", ["T4-02", "A2-03"], 16, "unos 20 puntos")


func test_mision_E2_02() -> void:
	_mision_E2("E2-02", ["E2-01"], 13, "una copia casi perfecta")


func test_mision_E2_03() -> void:
	_mision_E2("E2-03", ["E2-01"], 14, "pequeña pero clara")
