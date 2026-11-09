extends TestCase
## Tests del arco A5: taller multiagente simulado (estructura A2A), controles y calibración.

var game: DojoGame


func before_each() -> void:
	game = DojoGame.new("")


func run(lines: Array) -> void:
	for l: String in lines:
		var r := game.shell.execute(l)
		if not r.ok:
			fail("'%s' → %s" % [l, r.plain_text()])


func _last(event_name: String) -> Dictionary:
	return game.shell.events_named(event_name)[-1]["data"]


func test_mensajes_send_message() -> void:
	var m := MockAgentMesh.create("t")
	var res := m.ask("¿Dónde está mi pedido P-101?", "cliente")
	assert_true(String(res["answer"]).contains("entregado"))
	var msg: Dictionary = JSON.parse_string(m.messages[0])
	assert_eq(msg["jsonrpc"], "2.0")
	assert_eq(msg["method"], "SendMessage")
	assert_eq(msg["params"]["metadata"]["para"], "recepcion")


func test_tarjeta_publicada() -> void:
	var m := MockAgentMesh.create("t")
	var card: Dictionary = JSON.parse_string(m.card_json(m.agent("contable")))
	assert_eq(card["url"], "https://contable.kurogane.example")
	assert_true(card.has("signatures"), "las tarjetas internas van firmadas")


func test_card_verification_rechaza_tarjeta_sin_firma() -> void:
	var m := MockAgentMesh.create("t")
	assert_eq(m.discover("acero-norte.example"), "")
	m.defenses["card-verification"] = true
	assert_true(m.discover("acero-veloz.example").contains("card-verification"))
	assert_true(m.agent("acero-veloz").is_empty())
	assert_false(m.discover("no-existe.example").is_empty())


func test_context_minimization_no_comparte_correos() -> void:
	var m := MockAgentMesh.create("t")
	m.discover("acero-norte.example")
	assert_true(m.ask("Pide a acero un presupuesto para P-103")["leaked"])
	var safe := MockAgentMesh.create("s")
	safe.defenses["context-minimization"] = true
	safe.discover("acero-norte.example")
	var res := safe.ask("Pide a acero un presupuesto para P-103")
	assert_false(res["leaked"])
	assert_eq(res["routed_to"], "acero-norte")


func test_matriz_de_defensas() -> void:
	var expected := {"ninguna": 6, "message-auth": 5, "delegated-authz": 4, "card-verification": 5,
		"hop-limit": 5, "context-minimization": 5, "monitor": 4}
	for d: String in expected:
		run(["a2a taller a"])
		if d != "ninguna":
			run(["a2a defend a %s on" % d])
		run(["a2a attack a", "a2a eval a"])
		assert_eq(_last("a2a.attacks")["successes"], expected[d], "control " + d)
		assert_eq(_last("a2a.eval")["pass_rate"], 0.75 if d == "monitor" else 1.0, "eval con " + d)
	var all_but_monitor := ["message-auth", "delegated-authz", "card-verification", "hop-limit", "context-minimization"]
	run(["a2a taller z"])
	for d: String in all_but_monitor:
		run(["a2a defend z %s on" % d])
	run(["a2a attack z", "a2a eval z"])
	assert_eq(_last("a2a.attacks")["successes"], 0)
	assert_eq(_last("a2a.eval")["pass_rate"], 1.0)


func test_comandos_con_errores_amables() -> void:
	run(["a2a taller t"])
	var r := game.shell.execute("a2a card t no-existe")
	assert_false(r.ok)
	r = game.shell.execute("a2a ask nada hola")
	assert_false(r.ok)
	r = game.shell.execute("a2a defend t inventado on")
	assert_false(r.ok)
