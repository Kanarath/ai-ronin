extends TestCase
## Tests de O5: marcos, clasificación según el AI Act, registro de riesgos y misiones.

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


const NIST := {"F1": "GOVERN", "F2": "MAP", "F3": "MEASURE", "F4": "MANAGE"}
const ISO := {"F1": "5", "F2": "4", "F3": "9", "F4": "10"}
const LEVELS := {"chatbot-atencion": "transparencia", "cribado-cv": "alto", "monitor-emociones": "prohibido", "inspeccion-acero": "minimo"}
const ARTS := {"N1": "10", "N2": "12", "N3": "14", "N4": "15"}


func _maps(g: String) -> Array:
	var out: Array = []
	for f: String in NIST:
		out.append("gov map %s %s nist %s" % [g, f, NIST[f]])
	for f: String in ISO:
		out.append("gov map %s %s iso %s" % [g, f, ISO[f]])
	return out


func _classify(g: String) -> Array:
	var out: Array = []
	for s: String in LEVELS:
		out.append("gov classify %s %s %s" % [g, s, LEVELS[s]])
	return out


func _require(g: String) -> Array:
	var out: Array = []
	for n: String in ARTS:
		out.append("gov require %s %s %s" % [g, n, ARTS[n]])
	return out


func _treat_ok(g: String) -> Array:
	return ["gov treat %s R1 mitigar" % g, "gov treat %s R2 mitigar" % g, "gov treat %s R3 mitigar" % g, "gov treat %s R4 mitigar" % g,
		"gov treat %s R5 mitigar" % g, "gov treat %s R6 evitar" % g, "gov risks %s" % g]


func test_registro_de_riesgos() -> void:
	var g := MockGovernance.create("t")
	assert_eq(g.register()["within"], 0)
	assert_ne(g.treat("R6", "mitigar"), "", "prohibido: no se mitiga")
	assert_ne(g.treat("R1", "aceptar"), "", "8 > apetito")
	for r in ["R1", "R2", "R3", "R4", "R5"]:
		assert_eq(g.treat(r, "mitigar"), "")
	assert_eq(g.treat("R6", "evitar"), "")
	var reg := g.register()
	assert_eq([reg["within"], reg["needless_avoid"]], [6, 0])
	g.treat("R1", "evitar")
	assert_eq(g.register()["needless_avoid"], 1)


func test_mapeos_y_clasificacion() -> void:
	var g := MockGovernance.create("t")
	assert_true(g.map_finding("F4", "iso", "6.1.3"), "6.1.3 cuenta como cláusula 6")
	assert_false(g.map_finding("F1", "nist", "MAP"))
	assert_true(g.map_finding("f1", "nist", "govern"))
	run(["gov open t"])
	assert_false(game.shell.execute("gov map t F9 nist GOVERN").ok)
	assert_false(game.shell.execute("gov map t F1 nist PROTECT").ok)
	assert_false(game.shell.execute("gov map t F1 iso 3").ok)
	assert_false(game.shell.execute("gov classify t nada alto").ok)
	run(["gov require t N2 art.12"])
	assert_true(_last("gov.required")["ok"])


func test_mision_O5_01() -> void:
	game.progress.data["missions"]["O6-03"] = {"completed": true}
	assert_eq(game.start_mission("O5-01"), "")
	run(["gov open forja", "gov frameworks forja", "answer iso-42001", "answer c"])
	run(["hipotesis no, una certifica la gestión y la otra impone obligaciones legales concretas", "gov framework forja iso-42001", "gov framework forja ai-act", "answer no"])
	assert_eq(game.runner.index, 3)
	run(_maps("forja") + ["answer b"])
	assert_eq(game.runner.phase, "trial")
	run(["gov open t2"] + _maps("t2"))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_O5_02() -> void:
	game.progress.data["missions"]["O5-01"] = {"completed": true}
	assert_eq(game.start_mission("O5-02"), "")
	run(["hipotesis prohibido", "gov open forja", "gov systems forja"] + _classify("forja"))
	assert_eq(game.runner.index, 1)
	run(["answer a"])
	assert_eq(game.runner.index, 2)
	run(["answer 2027-12-02"])
	assert_eq(game.runner.index, 3, "o2 acepta la fecha sin volver a clasificar el cribado")
	run(["gov needs forja"] + _require("forja"))
	assert_eq(game.runner.index, 4)
	run(["answer b"])
	assert_eq(game.runner.phase, "trial")
	run(["gov open t2"] + _classify("t2") + _require("t2"))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_O5_03() -> void:
	game.progress.data["missions"]["O5-02"] = {"completed": true}
	assert_eq(game.start_mission("O5-03"), "")
	run(["gov open forja", "gov risks forja", "answer R6"])
	assert_eq(game.runner.index, 1)
	_solve_py(PY_APETITO)
	assert_eq(game.runner.index, 2)
	run(["hipotesis no, el uso está prohibido", "gov treat forja R6 mitigar", "gov treat forja R6 evitar"])
	run(["gov treat forja R1 aceptar"])
	assert_eq(game.runner.index, 4)
	run(["answer c"])
	assert_eq(game.runner.index, 5)
	run(_treat_ok("forja") + ["answer a"])
	assert_eq(game.runner.phase, "trial")
	run(["gov open t2"] + _treat_ok("t2"))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


# --- O/C/E ---

## Paso de Python de una misión: abre el editor, escribe la solución y la comprueba.
func _solve_py(code: String) -> void:
	run(["py"])
	game.py_code = code
	run(["py check"])


const PY_APETITO := "def dentro_del_apetito(probabilidad, impacto, apetito):\n    riesgo = probabilidad * impacto\n    return riesgo <= apetito\n"


func test_O5_03_python_apetito_starter_falla() -> void:
	var ex: Dictionary = game.catalog.get_mission("O5-03")["objectives"][1]["py_exercise"]
	assert_eq(ex["id"], "O5-03-apetito")
	var r := PyExercise.check(ex["starter"], ex)
	assert_true(r["ok"], "el código inicial se ejecuta")
	assert_true(r["passed"] < r["total"], "el código inicial no pasa")
	r = PyExercise.check(PY_APETITO, ex)
	assert_eq(r["passed"], r["total"])


func test_O5_comprobacion_no_avanza_con_error() -> void:
	game.progress.data["missions"]["O6-03"] = {"completed": true}
	game.start_mission("O5-01")
	run(["gov open forja", "gov frameworks forja", "answer iso-42001", "answer a"])
	assert_eq(game.runner.current_objective()["id"], "c1")
	run(["answer c"])
	assert_eq(game.runner.current_objective()["id"], "o2")
