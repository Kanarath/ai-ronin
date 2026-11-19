extends TestCase
## Tests de la prueba final C5: encargo, alcance, evidencias, retest y misiones.

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


const LAB := ["bot create kuro", "rag create docs", "rag ingest docs", "agent create taller", "mcp host erp", "supply forja pipe"]
const OBJ := {"A-01": "kuro", "A-02": "docs", "A-03": "taller", "A-04": "erp", "A-05": "pipe"}
const CAT := {"A-01": "LLM07", "A-02": "LLM01", "A-03": "ASI01", "A-04": "ASI04", "A-05": "LLM03"}
const ATTACK := {"A-01": "bot attack kuro", "A-02": "rag attack docs", "A-03": "agent attack taller", "A-04": "mcp attack erp", "A-05": "supply attack pipe"}
const FIX := {
	"A-01": ["bot defend kuro secret-in-prompt off", "bot defend kuro encode-output on", "bot defend kuro max-tokens on", "bot attack kuro", "bot eval kuro"],
	"A-02": ["rag defend docs acl on", "rag defend docs trusted-sources on", "rag defend docs spotlight on", "rag defend docs vector-acl on", "rag defend docs min-score on", "rag attack docs", "rag eval docs"],
	"A-03": ["agent defend taller least-privilege on", "agent defend taller user-authz on", "agent defend taller step-budget on", "agent attack taller", "agent eval taller"],
	"A-04": ["mcp defend erp pin-definitions on", "mcp defend erp namespacing on", "mcp defend erp least-scope on", "mcp defend erp output-isolation on", "mcp attack erp", "mcp eval erp"],
}


func _pipeline_controls() -> Array:
	var out: Array = []
	for d in MockMlPipeline.DEFENSES:
		out.append("supply defend pipe %s on" % d)
	return out


func _setup(e: String, assets: Array) -> Array:
	var out: Array = ["engagement start " + e] + LAB
	for id: String in assets:
		out.append("engagement bind %s %s %s" % [e, id, OBJ[id]])
	return out


func _findings(e: String, assets: Array) -> Array:
	var out: Array = []
	for id: String in assets:
		out.append(ATTACK[id])
		out.append("engagement finding %s %s %s" % [e, id, CAT[id]])
	return out


func test_alcance() -> void:
	run(["engagement start f", "engagement scope f A-06", "engagement bind f A-07 kuro"])
	assert_false(_last("engagement.scoped")["in_scope"])
	assert_eq(game.shell.events_named("engagement.out_of_scope").size(), 1)
	assert_false(game.shell.execute("engagement bind f A-01 nadie").ok, "el objeto debe existir")
	assert_false(game.shell.execute("engagement scope f A-99").ok)
	assert_false(game.shell.execute("engagement threat f A-01 XSS").ok)


func test_hallazgo_exige_evidencia() -> void:
	run(_setup("f", ["A-05"]) + ["engagement finding f A-05 LLM03"])
	assert_eq(game.shell.events_named("engagement.finding_rejected").size(), 1, "sin batería")
	run(["engagement finding f A-05 LLM09"])
	assert_eq(game.shell.events_named("engagement.finding_rejected").size(), 2, "no encaja")
	run(["supply attack pipe", "engagement finding f A-05 LLM03"])
	assert_eq(_last("engagement.finding")["baseline"], 7)


func test_retest_exige_ataques_y_tareas() -> void:
	run(_setup("f", ["A-05"]) + _findings("f", ["A-05"]) + ["engagement retest f"])
	assert_eq(_last("engagement.retest")["open"], 1)
	run(_pipeline_controls() + ["supply attack pipe", "supply eval pipe", "engagement retest f"])
	assert_eq(_last("engagement.retest")["broken"], 1, "0 ataques pero tareas a 0,75")
	run(["supply convert pipe clasificador-acero", "supply attack pipe", "supply eval pipe", "engagement retest f"])
	assert_true(_last("engagement.retest")["all_fixed"])


func test_cinco_activos_cerrados() -> void:
	var ids := ["A-01", "A-02", "A-03", "A-04", "A-05"]
	run(_setup("f", ids) + _findings("f", ids) + ["engagement summary f"])
	assert_eq(_last("engagement.summary")["worst"], "A-01")
	var lines: Array = []
	for id: String in FIX:
		lines += FIX[id]
	run(lines + _pipeline_controls() + ["supply convert pipe clasificador-acero", "supply attack pipe", "supply eval pipe", "engagement retest f", "engagement summary f"])
	assert_true(_last("engagement.retest")["all_fixed"])
	assert_true(_last("engagement.summary")["all_fixed"])


func test_mision_C5_01() -> void:
	for m in ["A4-03", "A6-03", "O6-03", "C1-02", "C2-02", "C3-02", "O3-01", "C4-02"]:
		game.progress.data["missions"][m] = {"completed": true}
	assert_eq(game.start_mission("C5-01"), "")
	run(["engagement start final", "engagement recon final", "answer 5"])
	run(["hipotesis no, es de un tercero y la forja no puede autorizarlo", "engagement scope final A-06", "answer A-06"])
	assert_eq(game.runner.index, 2)
	var lines: Array = LAB.duplicate()
	for id: String in OBJ:
		lines.append("engagement bind final %s %s" % [id, OBJ[id]])
	run(lines)
	assert_eq(game.runner.index, 3)
	lines = []
	for id: String in CAT:
		lines.append("engagement threat final %s %s" % [id, CAT[id]])
	run(lines + ["answer a", "answer b"])
	assert_eq(game.runner.phase, "trial")
	lines = ["engagement start t2"]
	for id: String in OBJ:
		lines.append("engagement bind t2 %s %s" % [id, OBJ[id]])
	for id: String in CAT:
		lines.append("engagement threat t2 %s %s" % [id, CAT[id]])
	run(lines)
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_C5_02() -> void:
	game.progress.data["missions"]["C5-01"] = {"completed": true}
	game.progress.data["missions"]["O4-01"] = {"completed": true}
	assert_eq(game.start_mission("C5-02"), "")
	var ids := ["A-01", "A-02", "A-03", "A-04", "A-05"]
	run(_setup("final", ids))
	assert_eq(game.runner.index, 1)
	run(["hipotesis no, LLM09 no encaja con un pipeline de entrenamiento y serving", "engagement finding final A-05 LLM09"])
	run(_findings("final", ids))
	assert_eq(game.runner.index, 3)
	run(["engagement summary final", "answer A-01", "answer c"])
	run(["informe nuevo Modelo pickle con código cargado sin control en el pipeline", "informe campo severidad crítica", "informe campo owasp LLM03",
		"informe campo componente pipeline de modelos de inspección A-05", "informe campo descripcion el servidor carga un pickle de un hub público que ejecuta código",
		"informe campo pasos 1) engagement start final 2) supply forja pipe 3) supply attack pipe",
		"informe campo impacto ejecución de código en el servidor de modelos de la forja", "informe campo evidencia la batería A6 da 7 de 7 éxitos sobre la copia pipe",
		"informe campo mitigacion safetensors firmas lockfile non-root segmentación y gestor de secretos", "informe campo verificacion hoy 7 de 7 ataques; tras corregir, retest con 0 de 7 y tareas a 1,0",
		"informe revisar", "answer b"])
	assert_eq(game.runner.phase, "trial")
	run(_setup("t2", ["A-01", "A-03", "A-05"]) + _findings("t2", ["A-01", "A-03", "A-05"]))
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_C5_03() -> void:
	game.progress.data["missions"]["C5-02"] = {"completed": true}
	assert_eq(game.start_mission("C5-03"), "")
	var ids := ["A-01", "A-03", "A-05"]
	run(_setup("final", ids) + _findings("final", ids))
	assert_eq(game.runner.index, 1)
	run(["hipotesis no, falta algo más"] + _pipeline_controls() + ["supply attack pipe", "supply eval pipe", "engagement retest final"])
	assert_eq(game.runner.index, 2)
	run(["answer a"])
	run(FIX["A-01"] + FIX["A-03"] + ["supply convert pipe clasificador-acero", "supply attack pipe", "supply eval pipe", "engagement retest final"])
	assert_eq(game.runner.index, 4)
	run(["engagement summary final", "answer b"])
	assert_eq(game.runner.phase, "trial")
	run(_setup("t2", ["A-01", "A-03"]) + _findings("t2", ["A-01", "A-03"]) + FIX["A-01"] + FIX["A-03"] + ["engagement retest t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_fingerprint_revela_la_huella_de_un_activo_en_alcance() -> void:
	run(["engagement start norte", "engagement fingerprint norte A-01"])
	var ev := _last("engagement.fingerprinted")
	assert_eq(ev["asset"], "A-01")
	assert_true(int(ev["leaks"]) >= 1, "revela al menos una fuga de metadatos")


func test_fingerprint_no_sondea_un_activo_fuera_de_alcance() -> void:
	run(["engagement start norte"])
	var r := game.shell.execute("engagement fingerprint norte A-06")
	assert_true(r.plain_text().contains("fuera de alcance"), r.plain_text())
	assert_eq(game.shell.events_named("engagement.fingerprinted").size(), 0, "no emite huella de algo fuera de alcance")
