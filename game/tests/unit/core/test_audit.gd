extends TestCase
## Tests de E3: evaluaciones de impacto, auditoría por muestreo, informe con rúbrica y misiones.

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


const DUTIES := {"ayuda-valle": "si si", "cribado-cv": "no si", "solvencia-caja": "si si", "agua-valle": "no no"}
const PLACES := {"E1": "eipd", "E2": "eipd", "E3": "fria", "E4": "fria", "E5": "fria", "E6": "fria", "E7": "eipd", "E8": "ambas", "E9": "fria", "E10": "eipd"}
const ROLES := {"T1": "ayuntamiento", "T2": "ayuntamiento", "T3": "dpd", "T4": "proveedor", "T5": "autoridad-mercado", "T6": "autoridad-control"}
const RATES := {"C01": "conforme", "C05": "nc-menor", "C07": "conforme", "C08": "nc-mayor", "C10": "nc-mayor"}
const DRAFTS := {
	"H1": {"criterio": "B", "evidencia": "B", "riesgo": "B", "recomendacion": "A", "seguimiento": "C"},
	"H2": {"criterio": "C", "evidencia": "A", "riesgo": "B", "recomendacion": "B", "seguimiento": "A"},
	"H3": {"criterio": "A", "evidencia": "A", "riesgo": "C", "recomendacion": "A", "seguimiento": "B"},
	"informe": {"alcance": "B", "conclusion": "C"},
}
const R40 := "reflexion la eipd mira el tratamiento de datos personales y la fria mira el uso del sistema sobre los derechos de las personas la hace quien despliega si es publico o presta servicios publicos y hacerlas juntas evita duplicar el analisis de riesgos que comparten las dos"


func _impact(a: String) -> Array:
	var out: Array = []
	for k: String in DUTIES:
		out.append("audit duty %s %s %s" % [a, k, DUTIES[k]])
	for e: String in PLACES:
		out.append("audit place %s %s %s" % [a, e, PLACES[e]])
	for t: String in ROLES:
		out.append("audit assign %s %s %s" % [a, t, ROLES[t]])
	return out


func _fieldwork(a: String) -> Array:
	var out: Array = ["audit sample %s C01 C05 C07 C08 C10" % a, "audit plan %s" % a, "audit records %s C10 10" % a]
	for c: String in RATES:
		out.append("audit evidence %s %s" % [a, c])
		out.append("audit rate %s %s %s" % [a, c, RATES[c]])
	return out


func _drafts(a: String, only: Array = []) -> Array:
	var out: Array = []
	for h: String in DRAFTS:
		if not only.is_empty() and not h in only:
			continue
		for field: String in DRAFTS[h]:
			out.append("audit draft %s %s %s %s" % [a, h, field, DRAFTS[h][field]])
	return out


func _closures(a: String) -> Array:
	return ["audit followup %s H1" % a, "audit close %s H1" % a, "audit followup %s H2" % a, "audit close %s H2" % a, "audit followup %s H3" % a, "audit close %s H3" % a]


func test_evaluaciones_de_impacto() -> void:
	var x := MockAudit.create("t")
	assert_true(x.set_duty("agua-valle", false, false), "infraestructura crítica: sin FRIA aunque sea pública")
	assert_false(x.set_duty("cribado-cv", true, true), "empresa privada con el anexo III 4: sin FRIA")
	assert_true(x.set_duty("solvencia-caja", true, true), "anexo III 5.b: FRIA aunque sea privada")
	assert_eq(x.correct_duties(), 2)
	assert_true(x.place("E8", "ambas"))
	assert_false(x.place("E2", "fria"), "necesidad y proporcionalidad: solo EIPD")
	assert_false(x.assign("T1", "proveedor"), "la FRIA la hace quien despliega")
	run(["audit open t"])
	assert_false(game.shell.execute("audit duty t nada si si").ok)
	assert_false(game.shell.execute("audit place t E1 rgpd").ok)
	assert_false(game.shell.execute("audit assign t T1 alcalde").ok)
	run(["audit duty t cribado-cv no sí"])
	assert_true(_last("audit.duty")["ok"], "acepta «sí» con tilde")


func test_muestreo_y_clasificacion() -> void:
	var x := MockAudit.create("t")
	x.set_sample(x.random_sample(6))
	var p := x.plan()
	assert_false(p["valid"], "la muestra al azar deja fuera controles de riesgo alto")
	assert_ne(p["missing_alta"], "")
	x.set_sample(PackedStringArray(["C05", "C07", "C08", "C10"]))
	assert_eq(x.plan()["uncovered"], "GOVERN")
	x.set_sample(PackedStringArray(["C01", "C02", "C05", "C07", "C08", "C10", "C11"]))
	assert_false(x.plan()["valid"], "siete no caben")
	x.set_sample(PackedStringArray(["c01", "C05", "C07", "C08", "C10", "C10"]))
	assert_true(x.plan()["valid"])
	assert_eq(x.sample.size(), 5)
	assert_ne(x.can_rate("C10"), "", "sin evidencia no se concluye")
	x.seen_evidence["C10"] = true
	assert_ne(x.can_rate("C10"), "", "sin muestra de expedientes no se concluye")
	var s := x.sample_records("C10", 10)
	assert_eq(s["ids"].size(), 10)
	assert_true(s["failing"].size() >= 2, "la muestra de 10 tiene que mostrar el fallo sistemático")
	assert_eq(x.sample_records("C10", 10), s, "semilla fija: misma muestra")
	assert_eq(x.can_rate("C10"), "")
	assert_ne(x.can_rate("C02"), "", "fuera de la muestra")


func test_informe_y_cierre() -> void:
	run(["audit open t"] + _drafts("t", ["H2"]))
	assert_eq(_last("audit.drafted")["finding_ok"], 5)
	run(["audit report t"])
	assert_false(_last("audit.report")["passed"])
	run(_drafts("t") + ["audit draft t informe conclusion A", "audit report t"])
	assert_false(_last("audit.report")["passed"], "«cumple el AI Act» no pasa la rúbrica")
	run(["audit draft t informe conclusion c", "audit report t"])
	assert_true(_last("audit.report")["passed"])
	assert_false(game.shell.execute("audit draft t H1 conclusion A").ok, "campo del informe en un hallazgo")
	run(["audit close t H2"])
	assert_eq(game.shell.events_named("audit.closed").size(), 0, "sin revisar el seguimiento no se cierra")
	run(_closures("t"))
	assert_eq(_last("audit.closed")["closed"], 2)
	assert_eq(_last("audit.close_refused")["finding"], "H1")


func test_mision_E3_01() -> void:
	game.progress.data["missions"]["O5-03"] = {"completed": true}
	assert_eq(game.start_mission("E3-01"), "")
	run(["hipotesis no, el art. 27 no obliga a una empresa privada con ese uso", "audit open valle", "audit cases valle"] + _impact("valle").slice(0, 4))
	assert_eq(game.runner.index, 1)
	run(["audit elements valle"] + _impact("valle").slice(4, 14))
	assert_eq(game.runner.index, 2)
	run(["audit roles valle"] + _impact("valle").slice(14))
	run(["audit timeline valle", "answer eipd", R40])
	assert_eq(game.runner.phase, "trial")
	run(["audit open t2"] + _impact("t2"))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_E3_02() -> void:
	game.progress.data["missions"]["E3-01"] = {"completed": true}
	assert_eq(game.start_mission("E3-02"), "")
	run(["audit open valle", "audit controls valle", "hipotesis seguramente no todos: el azar no mira el riesgo", "audit sample valle --random 6", "audit plan valle"])
	assert_eq(game.runner.index, 1)
	run(["audit sample valle C01 C05 C07 C08 C10", "audit plan valle"])
	assert_eq(game.runner.index, 2)
	run(["audit evidence valle C10", "audit rate valle C10 nc-mayor"])
	assert_eq(game.runner.index, 2, "sin muestra de expedientes no se puede clasificar C10")
	run(["audit records valle C10 10", "audit rate valle C10 nc-mayor"])
	assert_eq(game.runner.index, 3)
	run(_fieldwork("valle").slice(3) + [R40])
	assert_eq(game.runner.phase, "trial")
	run(["audit open t2"] + _fieldwork("t2"))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_E3_03() -> void:
	game.progress.data["missions"]["E3-02"] = {"completed": true}
	assert_eq(game.start_mission("E3-03"), "")
	run(["audit open valle", "audit rubric valle", "hipotesis el 26.2: encomendar la supervisión a personas con competencia y autoridad", "audit findings valle H2"] + _drafts("valle", ["H2"]))
	assert_eq(game.runner.index, 1)
	run(_drafts("valle", ["H1", "H3"]))
	assert_eq(game.runner.index, 2)
	run(_drafts("valle", ["informe"]) + ["audit report valle"])
	assert_eq(game.runner.index, 3)
	run(_closures("valle") + [R40])
	assert_eq(game.runner.phase, "trial")
	run(["audit open t2"] + _drafts("t2") + ["audit report t2"] + _closures("t2"))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
