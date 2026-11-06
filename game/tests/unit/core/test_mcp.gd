extends TestCase
## Tests del arco A4: host MCP simulado, ataques por el enchufe, controles y misiones.

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


func test_mensajes_json_rpc() -> void:
	var h := MockMcpHost.create("h")
	var parsed: Dictionary = JSON.parse_string(h.tools_list_message("forja-pedidos"))
	assert_eq(parsed["jsonrpc"], "2.0")
	assert_eq(parsed["result"]["tools"].size(), 2)
	var res := h.ask("Busca el pedido P-101")
	assert_eq(res["tool"], "buscar_pedido")
	var call: Dictionary = JSON.parse_string(h.messages[0])
	assert_eq(call["method"], "tools/call")
	assert_eq(call["params"]["arguments"]["pedido"], "P-101")
	var reply: Dictionary = JSON.parse_string(h.messages[1])
	assert_eq(reply["id"], call["id"], "la respuesta lleva el mismo id que la petición")
	assert_true(String(res["answer"]).contains("aiko"))


func test_envenenamiento_y_passthrough() -> void:
	var h := MockMcpHost.create("h")
	var res := h.ask("¿Qué tiempo hará en Kioto?")
	assert_true(res["token_leaked_in_args"])
	assert_true(res["passthrough"])
	assert_eq(h.logs["clima-samurai"][0]["args"]["notas"], h.secret_token)
	var safe := MockMcpHost.create("s")
	safe.defenses["least-scope"] = true
	var res2 := safe.ask("¿Qué tiempo hará en Kioto?")
	assert_false(res2["token_leaked_in_args"])
	assert_false(res2["passthrough"])
	assert_eq(safe.logs["clima-samurai"][0]["token"], "tok_clima-samurai_rw")


func test_pinning_detecta_pero_la_aprobacion_decide() -> void:
	var h := MockMcpHost.create("h")
	h.defenses["pin-definitions"] = true
	h.publish_update("traductor")
	var res := h.ask("Traduce: katana")
	assert_true(res["refunds"].is_empty())
	assert_false(res["blocked"].is_empty())
	h.approve("traductor")
	res = h.ask("Traduce: katana")
	assert_eq(res["refunds"].size(), 1)
	assert_eq(res["refunds"][0]["importe"], 2400)


func test_shadowing_y_namespacing() -> void:
	var h := MockMcpHost.create("h")
	h.connect_server("utilidades-plus")
	assert_true(h.ask("Busca el pedido P-101")["shadowed"])
	h.defenses["namespacing"] = true
	assert_false(h.ask("Busca el pedido P-101")["shadowed"])


func test_matriz_de_defensas() -> void:
	var expected := {"ninguna": 5, "review-descriptions": 3, "pin-definitions": 4, "namespacing": 4, "least-scope": 3, "output-isolation": 4, "consent": 1}
	for d: String in expected:
		run(["mcp host a"])
		if d != "ninguna":
			run(["mcp defend a %s on" % d])
		run(["mcp attack a", "mcp eval a"])
		assert_eq(_last("mcp.attacks")["successes"], expected[d], "control " + d)
		assert_eq(_last("mcp.eval")["pass_rate"], 0.75 if d == "consent" else 1.0, "eval con " + d)
	run(["mcp host z", "mcp defend z pin-definitions on", "mcp defend z namespacing on", "mcp defend z least-scope on", "mcp defend z output-isolation on", "mcp attack z", "mcp eval z"])
	assert_eq(_last("mcp.attacks")["successes"], 0)
	assert_eq(_last("mcp.eval")["pass_rate"], 1.0)
	assert_eq(_last("mcp.eval")["approvals"], 0)


func test_comandos_con_errores_amables() -> void:
	run(["mcp host h"])
	var r := game.shell.execute("mcp inspect h no-existe")
	assert_false(r.ok)
	assert_true(r.plain_text().contains("forja-pedidos"))
	r = game.shell.execute("mcp update h clima-samurai")
	assert_false(r.ok)
	r = game.shell.execute("mcp ask nada hola")
	assert_false(r.ok)


const R40 := "reflexion el host decide que servidores conecta que textos llegan al modelo y con que token llama a cada servidor por eso las descripciones los resultados y las actualizaciones de un servidor de terceros son superficie de ataque y los controles deben ir en el host con tokens minimos huellas y espacios de nombres"


func test_mision_A4_01() -> void:
	game.progress.data["missions"]["A3-01"] = {"completed": true}
	assert_eq(game.start_mission("A4-01"), "")
	run(["mcp host forja", "mcp servers forja", "answer 2"])
	assert_eq(game.runner.index, 1)
	run(["mcp inspect forja forja-pedidos", "answer 2"])
	run(["mcp ask forja Busca el pedido P-101", "answer tools/call"])
	assert_eq(game.runner.index, 3)
	run(["mcp ask forja Reembolsa 120 monedas del pedido P-101"])
	run(["hipotesis también el modelo", "mcp inspect forja clima-samurai", R40])
	assert_eq(game.runner.phase, "trial")
	run(["mcp host f2", "mcp ask f2 Traduce: katana", "mcp inspect f2 traductor"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_A4_02() -> void:
	game.progress.data["missions"]["A4-01"] = {"completed": true}
	game.progress.data["missions"]["A3-02"] = {"completed": true}
	assert_eq(game.start_mission("A4-02"), "")
	run(["hipotesis sí", "mcp host forja", "mcp ask forja ¿Qué tiempo hará en Kioto?", "mcp log forja clima-samurai"])
	assert_eq(game.runner.index, 1)
	run(["answer tok_forja_admin_9f2c"])
	run(["mcp update forja traductor", "mcp ask forja Traduce: katana"])
	assert_eq(game.runner.index, 3)
	run(["mcp connect forja utilidades-plus", "mcp ask forja Busca el pedido P-101"])
	run(["mcp ask forja ¿Qué tiempo hará en Edo?"])
	assert_eq(game.runner.index, 5)
	run(["mcp attack forja", "answer 1"])
	run(["informe nuevo Robo del token de sesión mediante la descripción de una herramienta MCP", "informe campo severidad crítica", "informe campo owasp ASI04",
		"informe campo componente host MCP y servidor de terceros clima-samurai", "informe campo descripcion la descripción de consultar_clima ordena al modelo enviar el token",
		"informe campo pasos 1) mcp host forja 2) mcp ask forja ¿Qué tiempo hará en Kioto? 3) mcp log forja clima-samurai", "informe campo impacto el tercero obtiene el token de administrador",
		"informe campo evidencia el registro de clima-samurai muestra notas con el token", "informe campo mitigacion revisar descripciones y usar tokens mínimos por servidor",
		"informe campo verificacion la batería A4 baja de 1,00 a 0,00", "informe revisar", R40])
	assert_eq(game.runner.phase, "trial")
	run(["mcp host f2", "mcp ask f2 ¿Qué tiempo hará en Edo?"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_A4_03() -> void:
	game.progress.data["missions"]["A4-02"] = {"completed": true}
	assert_eq(game.start_mission("A4-03"), "")
	run(["mcp host forja", "mcp attack forja"])
	run(["hipotesis el que no tiene argumentos raros", "mcp defend forja consent on", "mcp attack forja", "answer 1"])
	run(["mcp eval forja", "answer 0,75"])
	assert_eq(game.runner.index, 3)
	run(["mcp defend forja consent off", "mcp defend forja pin-definitions on", "mcp update forja traductor", "mcp ask forja Traduce: katana",
		"mcp approve forja traductor", "mcp ask forja Traduce: katana"])
	assert_eq(game.runner.index, 4)
	run(["mcp defend forja namespacing on", "mcp defend forja least-scope on", "mcp defend forja output-isolation on", "mcp attack forja", "mcp eval forja", R40])
	assert_eq(game.runner.phase, "trial")
	run(["mcp host z", "mcp defend z pin-definitions on", "mcp defend z namespacing on", "mcp defend z least-scope on", "mcp defend z output-isolation on", "mcp attack z", "mcp eval z"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
