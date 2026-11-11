extends TestCase
## Tests de C1–C3: matriz de defensas, resiliencia y misiones de los capstones.

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


static func _on(cmd: String, sys: String, defs: Array) -> Array:
	var out: Array = []
	for d: String in defs:
		out.append("%s defend %s %s on" % [cmd, sys, d])
	return out


func test_matriz_del_agente() -> void:
	var mx := LabCommands.matrix("agent", MockAgent.create("a"))
	assert_eq(mx["base"]["broken"].size(), 5)
	assert_eq(Array(mx["single"]), ["diputado-confundido"])
	assert_eq(Array(mx["costly"]), ["hitl"])
	assert_true("bucle" in mx["cols"]["step-budget"]["blocks"])
	assert_false("bucle" in mx["cols"]["least-privilege"]["blocks"])


func test_matriz_del_rag_compara_con_la_linea_base() -> void:
	run(["rag create d", "rag ingest d", "lab matrix rag d"])
	var ev := _last("lab.matrix")
	assert_eq(ev["single_count"], 4)
	assert_eq(ev["costly"], "", "6/7 es la línea base, no un coste de las defensas")
	assert_eq(ev["blocks"]["min-score"], [])


func test_resiliencia_cuenta_fragiles_y_robustos() -> void:
	var ag := MockAgent.create("a")
	for d in ["spotlight", "user-authz"]:
		ag.defenses[d] = true
	var res := LabCommands.resilience("agent", ag)
	assert_eq([res["now"]["broken"].size(), res["robust"], res["fragile"].size()], [0, 0, 5])
	ag.defenses["least-privilege"] = true
	ag.defenses["step-budget"] = true
	res = LabCommands.resilience("agent", ag)
	assert_eq([res["robust"], Array(res["fragile"])], [4, ["diputado-confundido"]])


func test_las_defensas_no_siempre_suman() -> void:
	var h := MockMcpHost.create("h")
	for d in ["namespacing", "least-scope", "output-isolation", "pin-definitions", "review-descriptions", "consent"]:
		h.defenses[d] = true
	var res := LabCommands.resilience("mcp", h)
	assert_eq(res["robust"], 3)
	assert_eq(Array(res["depends"]["token-passthrough"]), ["least-scope"], "con la descripción saneada, consent ya no ve el token")


func test_errores_y_sin_efectos_en_el_original() -> void:
	assert_false(game.shell.execute("lab matrix agent nadie").ok)
	run(["rag create d"])
	assert_false(game.shell.execute("lab resilience rag d").ok, "sin índice")
	run(["agent create k", "agent defend k spotlight on", "lab matrix agent k"])
	assert_true(game.shell.world.agents["k"].defenses["spotlight"], "la matriz trabaja sobre copias")
	assert_false(game.shell.world.agents["k"].defenses["hitl"])


func test_mision_C1_01() -> void:
	game.progress.data["missions"]["A3-03"] = {"completed": true}
	assert_eq(game.start_mission("C1-01"), "")
	run(["hipotesis el que pide un usuario directamente", "agent create kage", "lab matrix agent kage"])
	run(["answer diputado-confundido"])
	run(["hipotesis 2"] + _on("agent", "kage", ["user-authz", "spotlight"]) + ["lab resilience agent kage"])
	assert_eq(game.runner.index, 3)
	run(["answer 5", "answer b", "answer a"])
	assert_eq(game.runner.phase, "trial")
	run(["agent create t2"] + _on("agent", "t2", ["least-privilege", "user-authz", "step-budget"]) + ["lab resilience agent t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_C1_02() -> void:
	game.progress.data["missions"]["C1-01"] = {"completed": true}
	assert_eq(game.start_mission("C1-02"), "")
	run(["agent create kage"] + _on("agent", "kage", ["least-privilege", "user-authz", "step-budget"]) + ["lab resilience agent kage"])
	assert_eq(game.runner.index, 1)
	run(["answer c"])
	run(["hipotesis spotlight", "agent defend kage spotlight on", "lab resilience agent kage"])
	assert_eq(game.runner.index, 3)
	run(["answer diputado-confundido", "answer a"])
	assert_eq(game.runner.phase, "trial")
	run(["agent create t2"] + _on("agent", "t2", ["spotlight", "least-privilege", "user-authz", "step-budget"]) + ["lab resilience agent t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


const RAG_MIN := ["trusted-sources", "acl", "vector-acl", "min-score"]


func test_mision_C2_01() -> void:
	game.progress.data["missions"]["A2-03"] = {"completed": true}
	assert_eq(game.start_mission("C2-01"), "")
	run(["hipotesis casi todos", "rag create docs", "rag ingest docs", "lab matrix rag docs", "answer a"])
	run(["answer 4", "answer min-score"])
	assert_eq(game.runner.index, 4)
	run(_on("rag", "docs", RAG_MIN) + ["lab resilience rag docs", "answer c"])
	assert_eq(game.runner.phase, "trial")
	run(["rag create t2", "rag ingest t2"] + _on("rag", "t2", RAG_MIN) + ["lab resilience rag t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_C2_02() -> void:
	game.progress.data["missions"]["C2-01"] = {"completed": true}
	assert_eq(game.start_mission("C2-02"), "")
	run(["hipotesis uno", "rag create docs", "rag ingest docs"] + _on("rag", "docs", RAG_MIN) + ["lab resilience rag docs", "rag defend docs spotlight on", "lab resilience rag docs"])
	run(["answer acl", "answer 4"])
	assert_eq(game.runner.index, 3)
	run(["answer c", "answer b"])
	assert_eq(game.runner.phase, "trial")
	run(["rag create t2", "rag ingest t2"] + _on("rag", "t2", RAG_MIN) + ["lab resilience rag t2", "rag defend t2 spotlight on", "lab resilience rag t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_C3_01() -> void:
	game.progress.data["missions"]["A4-03"] = {"completed": true}
	assert_eq(game.start_mission("C3-01"), "")
	run(["mcp host erp", "lab matrix mcp erp", "answer consent"])
	run(["hipotesis alguna tarea rota y aprobaciones"] + _on("mcp", "erp", ["namespacing", "consent"]) + ["lab resilience mcp erp", "answer 4"])
	assert_eq(game.runner.index, 3)
	run(["answer a"])
	assert_eq(game.runner.index, 4)
	run(["mcp host erp2"] + _on("mcp", "erp2", ["namespacing", "least-scope", "output-isolation", "pin-definitions"]) + ["lab resilience mcp erp2", "answer c"])
	assert_eq(game.runner.phase, "trial")
	run(["mcp host t2"] + _on("mcp", "t2", ["namespacing", "least-scope", "output-isolation", "review-descriptions"]) + ["lab resilience mcp t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


const MCP_FIVE := ["namespacing", "least-scope", "output-isolation", "pin-definitions", "review-descriptions"]


func test_mision_C3_02() -> void:
	game.progress.data["missions"]["C3-01"] = {"completed": true}
	assert_eq(game.start_mission("C3-02"), "")
	run(["mcp host erp"] + _on("mcp", "erp", MCP_FIVE) + ["lab resilience mcp erp"])
	run(["hipotesis 4", "mcp defend erp consent on", "lab resilience mcp erp", "answer 3"])
	assert_eq(game.runner.index, 2)
	run(["answer review-descriptions", "answer c", "answer b"])
	assert_eq(game.runner.phase, "trial")
	run(["mcp host t2"] + _on("mcp", "t2", MCP_FIVE) + ["lab resilience mcp t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
