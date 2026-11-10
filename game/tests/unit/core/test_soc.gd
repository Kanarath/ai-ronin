extends TestCase
## Tests de O6: registro de trazas, cobertura forense, detección, contención y misiones.

var game: DojoGame
var finished: Array[Dictionary] = []


func before_each() -> void:
	game = DojoGame.new("")
	finished.clear()
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))


func run(lines: Array) -> void:
	for l: String in lines:
		var r := game.shell.execute(l)
		if not r.ok:
			fail("'%s' → %s" % [l, r.plain_text()])


func _last(event_name: String) -> Dictionary:
	return game.shell.events_named(event_name)[-1]["data"]


const FULL := ["soc log %s tool_args on", "soc log %s retrievals on", "soc log %s identity on", "soc log %s model_version on", "soc log %s redact-pii on"]


func _full(store: String) -> Array:
	var out: Array = ["soc trazas " + store]
	for l: String in FULL:
		out.append(l % store)
	return out


func test_redaccion() -> void:
	assert_eq(MockTraceStore.redact("escribe a jon.ibarra@cliente-uno.example o al 600 000 101"), "escribe a ***@cliente-uno.example o al [teléfono]")
	assert_true(MockTraceStore.has_pii("a@b.example"))
	assert_false(MockTraceStore.has_pii(MockTraceStore.redact("a@b.example")))


func test_cobertura() -> void:
	var s := MockTraceStore.create("t")
	assert_eq(s.coverage()["answered"], 2)
	assert_true(s.coverage()["pii_stored"])
	for f in MockTraceStore.LOG_FIELDS:
		s.logging[f] = true
	s.redact_pii = true
	assert_eq(s.coverage()["answered"], 6)
	assert_false(s.coverage()["pii_stored"])


func test_matriz_de_deteccion() -> void:
	var s := MockTraceStore.create("t")
	s.rules["correlacion"] = true
	assert_eq(s.detect()["recall"], 0.0, "ciega sin retrievals ni tool_args")
	assert_eq(s.blind_rules().size(), 1)
	for f in MockTraceStore.LOG_FIELDS:
		s.logging[f] = true
	s.redact_pii = true
	var expected := {"palabras-clave": [1, 1], "dominio-externo": [2, 1], "instruccion-en-dato": [2, 1], "volumen": [1, 1], "correlacion": [2, 0]}
	for r: String in expected:
		for x in MockTraceStore.RULES:
			s.rules[x] = x == r
		var d := s.detect()
		assert_eq([d["tp"], d["fp"]], expected[r], "regla " + r)
	for x in MockTraceStore.RULES:
		s.rules[x] = true
	assert_eq([s.detect()["precision"], s.detect()["recall"]], [0.5, 1.0])
	s.rules["dominio-externo"] = false
	s.rules["instruccion-en-dato"] = false
	assert_eq([s.detect()["precision"], s.detect()["recall"]], [0.67, 1.0])


func test_contencion() -> void:
	var s := MockTraceStore.create("t")
	var cases := {"": [2, 1.0], "apagar-agente": [0, 0.0], "cuarentena-fuente": [1, 1.0], "bloquear-salida": [0, 1.0]}
	for a: String in cases:
		for x in MockTraceStore.ACTIONS:
			s.actions[x] = x == a
		var r := s.retest()
		assert_eq([r["successes"], r["pass_rate"]], cases[a], "contención " + a)


func test_comandos() -> void:
	run(_full("t") + ["soc show t s04", "soc search t prov-77"])
	assert_eq(_last("soc.viewed")["destinations"], "cdn-estadisticas.example")
	assert_true(_last("soc.viewed")["complete"])
	assert_eq(_last("soc.searched")["sessions"], 2)
	assert_false(game.shell.execute("soc show t S99").ok)
	assert_false(game.shell.execute("soc coverage nada").ok)
	assert_false(game.shell.execute("soc rule t inventada on").ok)


func test_mision_O6_01() -> void:
	game.progress.data["missions"]["A3-03"] = {"completed": true}
	assert_eq(game.start_mission("O6-01"), "")
	run(["soc trazas taller", "soc coverage taller", "answer 2"])
	run(["soc show taller S04", "answer http_get"])
	run(["soc log taller tool_args on", "soc show taller S04", "answer cdn-estadisticas.example"])
	assert_eq(game.runner.index, 3)
	run(["answer b"])
	assert_eq(game.runner.index, 4)
	run(["hipotesis el registro guarda datos personales de clientes", "soc log taller retrievals on", "soc log taller identity on", "soc log taller model_version on",
		"soc coverage taller", "soc log taller redact-pii on", "soc coverage taller", "answer b"])
	assert_eq(game.runner.phase, "trial")
	run(_full("t2") + ["soc coverage t2", "soc show t2 S07"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_O6_02() -> void:
	game.progress.data["missions"]["O6-01"] = {"completed": true}
	assert_eq(game.start_mission("O6-02"), "")
	run(["soc trazas taller", "soc rule taller correlacion on", "soc detect taller"])
	assert_eq(game.runner.index, 1)
	run(_full("taller").slice(1) + ["soc rule taller correlacion off", "soc rule taller palabras-clave on", "soc detect taller", "answer 0,25", "answer a"])
	var on: Array = ["hipotesis veré todos los ataques y muchas falsas alarmas"]
	for r in MockTraceStore.RULES:
		on.append("soc rule taller %s on" % r)
	run(on + ["soc detect taller", "answer 0,5"])
	assert_eq(game.runner.index, 4)
	_solve_py(PY_PRECISION)
	assert_eq(game.runner.index, 5)
	run(["soc rule taller dominio-externo off", "soc rule taller instruccion-en-dato off", "soc detect taller", "answer a"])
	assert_eq(game.runner.phase, "trial")
	run(_full("t2") + ["soc rule t2 palabras-clave on", "soc rule t2 volumen on", "soc rule t2 correlacion on", "soc detect t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_O6_03() -> void:
	game.progress.data["missions"]["O6-02"] = {"completed": true}
	assert_eq(game.start_mission("O6-03"), "")
	run(_full("taller") + ["soc show taller S04", "answer prov-77-informe.pdf"])
	run(["soc search taller prov-77", "answer 2"])
	run(["hipotesis frena los ataques y para todo el trabajo", "soc contain taller apagar-agente on", "soc retest taller", "answer 0"])
	assert_eq(game.runner.index, 3)
	run(["soc contain taller apagar-agente off", "soc contain taller cuarentena-fuente on", "soc retest taller", "answer 1", "answer b"])
	run(["soc contain taller bloquear-salida on", "soc contain taller notificar-dpd on", "soc retest taller"])
	assert_eq(game.runner.index, 6)
	run(["informe nuevo Inyección indirecta en prov-77-informe.pdf exfiltra la lista de clientes", "informe campo severidad alta", "informe campo owasp LLM01",
		"informe campo componente asistente-taller con el índice de documentos de proveedores", "informe campo descripcion un documento con texto oculto ordena al asistente enviar la lista de clientes fuera",
		"informe campo pasos 1) soc trazas taller 2) soc show taller S04 3) soc search taller prov-77",
		"informe campo impacto datos de 212 clientes enviados a un dominio externo en dos sesiones", "informe campo evidencia http_get a cdn-estadisticas.example en S04 y S07",
		"informe campo mitigacion bloquear la salida a dominios no permitidos y poner el documento en cuarentena", "informe campo verificacion el retest da 0 de 2 ataques y 4 de 4 tareas",
		"informe revisar", "answer b"])
	assert_eq(game.runner.phase, "trial")
	run(_full("t2") + ["soc show t2 S07", "soc search t2 prov-77", "soc contain t2 bloquear-salida on", "soc contain t2 notificar-dpd on", "soc retest t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


# --- O/C/E ---

## Paso de Python de una misión: abre el editor, escribe la solución y la comprueba.
func _solve_py(code: String) -> void:
	run(["py"])
	game.py_code = code
	run(["py check"])


const PY_PRECISION := "def precision(vp, fp):
    if vp + fp == 0:
        return 0.0
    return vp / (vp + fp)
"


func test_O6_02_python_precision_starter_falla() -> void:
	var ex: Dictionary = game.catalog.get_mission("O6-02")["objectives"][4]["py_exercise"]
	assert_eq(ex["id"], "O6-02-precision")
	var r := PyExercise.check(ex["starter"], ex)
	assert_true(r["ok"], "el código inicial se ejecuta")
	assert_true(r["passed"] < r["total"], "el código inicial no pasa")
	r = PyExercise.check(PY_PRECISION, ex)
	assert_eq(r["passed"], r["total"])


func test_O6_comprobacion_explica_el_error() -> void:
	var mentor: Array[String] = []
	game.runner.mentor_message.connect(func(t: String, _k: String) -> void: mentor.append(t))
	game.progress.data["missions"]["O6-02"] = {"completed": true}
	game.start_mission("O6-03")
	run(_full("taller") + ["soc show taller S04", "answer prov-77-informe.pdf", "soc search taller prov-77", "answer 2",
		"hipotesis frena los ataques y para todo el trabajo", "soc contain taller apagar-agente on", "soc retest taller", "answer 0",
		"soc contain taller apagar-agente off", "soc contain taller cuarentena-fuente on", "soc retest taller", "answer 1"])
	assert_eq(game.runner.current_objective()["id"], "c1")
	run(["answer a"])
	assert_eq(game.runner.current_objective()["id"], "c1", "una opción incorrecta no avanza")
	assert_true(mentor.any(func(t: String) -> bool: return t.contains("La cuarentena lo ha sacado")), "explica por qué no")
