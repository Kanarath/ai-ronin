class_name McpCommands
extends RefCounted
## A4 · MCP y superficies de herramientas (laboratorio simulado).


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("mcp host", "Crea el host MCP del asistente de la forja con sus servidores.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _host(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del host").example("mcp host forja")))
	reg.register(Command.new("mcp servers", "Servidores MCP disponibles, su origen, versión y si están conectados.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _servers(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp")))
	reg.register(Command.new("mcp inspect", "Muestra la respuesta JSON-RPC a tools/list de un servidor (lo que lee el modelo).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _inspect(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp").pos("servidor", "id del servidor").example("mcp inspect forja clima-samurai")))
	reg.register(Command.new("mcp connect", "Conecta un servidor MCP al host (y aprueba su definición actual).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _connect(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp").pos("servidor", "id del servidor")))
	reg.register(Command.new("mcp update", "Simula que un servidor publica una nueva versión de sus herramientas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _update(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp").pos("servidor", "id del servidor")))
	reg.register(Command.new("mcp approve", "Revisa y vuelve a aprobar la definición actual de un servidor.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _approve(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp").pos("servidor", "id del servidor")))
	reg.register(Command.new("mcp ask", "Pide algo al asistente: elegirá herramientas MCP y verás los mensajes JSON-RPC.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ask(c, a), "mcp")
		.with_signature(CommandSignature.new()
			.pos("host", "host MCP", "mcp")
			.pos("mensaje", "petición del usuario", "rest")
			.opt("as", "quién usa el asistente", "string", "empleado", ["empleado", "cliente"])
			.example("mcp ask forja ¿Qué tiempo hará en Kioto?")))
	reg.register(Command.new("mcp log", "Lo que ha recibido un servidor (argumentos y token): la vista del atacante.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _log(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp").pos("servidor", "id del servidor")))
	reg.register(Command.new("mcp defend", "Activa o desactiva un control del host MCP.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _defend(c, a), "mcp")
		.with_signature(CommandSignature.new()
			.pos("host", "host MCP", "mcp")
			.pos("defensa", "control", "string", true, Array(MockMcpHost.DEFENSES))
			.pos("estado", "on u off", "string", true, ["on", "off"])))
	reg.register(Command.new("mcp attack", "Batería de ataques A4 (cada uno sobre un host nuevo).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attack(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp")))
	reg.register(Command.new("mcp eval", "Tareas legítimas con las herramientas MCP.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), "mcp")
		.with_signature(CommandSignature.new().pos("host", "host MCP", "mcp")))


static func _active(h: MockMcpHost) -> String:
	var on := PackedStringArray()
	for d in MockMcpHost.DEFENSES:
		if h.defenses[d]:
			on.append(d)
	return ",".join(on) if not on.is_empty() else "ninguna"


static func _need_server(h: MockMcpHost, id: String) -> String:
	if h.server(id).is_empty():
		var ids := PackedStringArray()
		for s in h.servers:
			ids.append(s["id"])
		return "No existe el servidor '%s'. Servidores: %s" % [id, ", ".join(ids)]
	return ""


static func _host(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.mcps[a["nombre"]] = MockMcpHost.create(a["nombre"])
	c.emit("mcp.created", {"host": a["nombre"]})
	var r := CommandResult.new().line("✓ host MCP %s creado y conectado a sus servidores por defecto." % a["nombre"], "ok")
	r.line("⚗ Mensajes en formato JSON-RPC de MCP; servidores y modelo simulados. Siguiente: mcp servers %s" % a["nombre"], "muted")
	return r


static func _servers(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var data: Array = []
	var third := 0
	for s in h.servers:
		var names := PackedStringArray()
		for t: Dictionary in s["tools"]:
			names.append(t["name"])
		data.append([s["id"], s["owner"], s["version"], "sí" if s["connected"] else "no", ", ".join(names)])
		if s["connected"] and s["trust"] != "interno":
			third += 1
	c.emit("mcp.servers", {"host": a["host"], "third_party_connected": third})
	return CommandResult.new().table(PackedStringArray(["servidor", "origen", "versión", "conectado", "herramientas"]), data)


static func _inspect(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var err := _need_server(h, a["servidor"])
	if not err.is_empty():
		return CommandResult.error(err)
	var r := CommandResult.new()
	r.line("→ {\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"tools/list\"}", "muted")
	r.line("← respuesta de %s:" % a["servidor"], "accent")
	r.lines_from(h.tools_list_message(a["servidor"]).split("\n"), "data")
	var poisoned := RegEx.create_from_string(MockMcpHost.SUSPICIOUS_RX).search(h.tools_list_message(a["servidor"])) != null
	c.emit("mcp.inspected", {"host": a["host"], "server": a["servidor"], "suspicious": poisoned, "version": h.server(a["servidor"])["version"]})
	return r


static func _connect(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var err := _need_server(h, a["servidor"])
	if not err.is_empty():
		return CommandResult.error(err)
	h.connect_server(a["servidor"])
	c.emit("mcp.connected", {"host": a["host"], "server": a["servidor"]})
	return CommandResult.new().line("✓ %s conectado. Sus herramientas entran en la tabla del host y sus descripciones, en el contexto del modelo." % a["servidor"], "ok")


static func _update(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var err := _need_server(h, a["servidor"])
	if not err.is_empty():
		return CommandResult.error(err)
	if not h.publish_update(a["servidor"]):
		return CommandResult.error("%s no tiene ninguna actualización pendiente en este laboratorio." % a["servidor"])
	c.emit("mcp.updated", {"host": a["host"], "server": a["servidor"], "version": h.server(a["servidor"])["version"]})
	return CommandResult.new().line("⟳ %s ha publicado la versión %s. Este host la carga sin preguntar en el siguiente tools/list." % [a["servidor"], h.server(a["servidor"])["version"]], "warn")


static func _approve(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var err := _need_server(h, a["servidor"])
	if not err.is_empty():
		return CommandResult.error(err)
	h.approve(a["servidor"])
	c.emit("mcp.approved", {"host": a["host"], "server": a["servidor"]})
	return CommandResult.new().line("✓ definición actual de %s revisada y aprobada (nueva huella %s)." % [a["servidor"], h.server(a["servidor"])["pinned"]], "ok")


static func _ask(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var res := h.ask(a["mensaje"], a["as"])
	var r := CommandResult.new()
	r.line("Mensajes JSON-RPC del host:", "accent")
	for m in h.messages:
		r.line(("→ " if m.contains("\"method\"") else "← ") + m.substr(0, 220), "data")
	for b: String in res["blocked"]:
		r.line("✋ " + b, "ok")
	r.line("🤖 " + (res["answer"] if not String(res["answer"]).is_empty() else "(sin respuesta)"), "data")
	var warns := PackedStringArray()
	if res["token_leaked_in_args"]:
		warns.append("⚠ el token de la sesión ha viajado en los ARGUMENTOS a un servidor de terceros")
	if res["passthrough"]:
		warns.append("⚠ un servidor de terceros ha recibido el token de administrador de la forja")
	for rf: Dictionary in res["refunds"]:
		warns.append("⚠ REEMBOLSO de %d monedas en %s" % [rf["importe"], rf["pedido"]])
	if res["shadowed"]:
		warns.append("⚠ la petición la ha atendido utilidades-plus en lugar del servidor oficial")
	if res["approvals"] > 0:
		warns.append("%d confirmaciones pedidas al usuario" % res["approvals"])
	for w in warns:
		r.line("  " + w, "warn" if w.begins_with("⚠") else "muted")
	var total := 0
	for rf: Dictionary in res["refunds"]:
		total += int(rf["importe"])
	c.emit("mcp.asked", {"host": a["host"], "message": a["mensaje"], "tool": res["tool"], "token_leaked": res["token_leaked_in_args"],
		"passthrough": res["passthrough"], "refund_total": total, "shadowed": res["shadowed"], "approvals": res["approvals"], "defenses": _active(h)})
	return r


static func _log(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	var err := _need_server(h, a["servidor"])
	if not err.is_empty():
		return CommandResult.error(err)
	var entries: Array = h.logs[a["servidor"]]
	var r := CommandResult.new()
	r.line("Registro del servidor %s (lo que ve su propietario):" % a["servidor"], "accent")
	if entries.is_empty():
		r.line("(vacío)", "muted")
	var secret_seen := false
	for e: Dictionary in entries:
		r.line("%s(%s) · token: %s" % [e["tool"], JSON.stringify(e["args"]), e["token"]], "data")
		secret_seen = secret_seen or str(e).contains(h.secret_token)
	c.emit("mcp.log", {"host": a["host"], "server": a["servidor"], "entries": entries.size(), "secret_seen": secret_seen})
	return r


static func _defend(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: MockMcpHost = c.world.mcps[a["host"]]
	h.defenses[a["defensa"]] = a["estado"] == "on"
	c.emit("mcp.defense", {"host": a["host"], "defense": a["defensa"], "enabled": a["estado"] == "on"})
	return CommandResult.new().line("✓ %s → %s" % [a["defensa"], "activado" if a["estado"] == "on" else "desactivado"], "ok")


## Escenarios de la batería. Devuelve [[id, categoría, éxito, aprobaciones]].
static func run_suite(base: MockMcpHost) -> Array:
	var rows: Array = []
	var h := base.clone_fresh()
	var r := h.ask("¿Qué tiempo hará en Kioto?")
	rows.append(["envenenamiento-herramienta", "tool poisoning (descripción maliciosa)", r["token_leaked_in_args"], r["approvals"]])
	h = base.clone_fresh()
	h.publish_update("traductor")
	r = h.ask("Traduce: katana")
	rows.append(["rug-pull", "cambio de definición tras aprobarla", not r["refunds"].is_empty(), r["approvals"]])
	h = base.clone_fresh()
	h.connect_server("utilidades-plus")
	r = h.ask("Busca el pedido P-101")
	rows.append(["suplantacion-nombre", "tool shadowing (mismo nombre)", r["shadowed"], r["approvals"]])
	h = base.clone_fresh()
	r = h.ask("¿Qué tiempo hará en Kioto?")
	rows.append(["token-passthrough", "token con demasiados permisos reenviado", r["passthrough"], r["approvals"]])
	h = base.clone_fresh()
	r = h.ask("¿Qué tiempo hará en Edo?")
	rows.append(["salida-inyectada", "instrucciones en el resultado de la herramienta", not r["refunds"].is_empty(), r["approvals"]])
	return rows


static func _attack(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: MockMcpHost = c.world.mcps[a["host"]]
	var rows := run_suite(base)
	var r := CommandResult.new()
	r.line("Batería de ataques A4 contra %s · controles: %s" % [a["host"], _active(base)], "accent")
	var data: Array = []
	var successes := 0
	var approvals := 0
	for row: Array in rows:
		if row[2]:
			successes += 1
		approvals += int(row[3])
		data.append([row[0], row[1], "✗ ÉXITO" if row[2] else "· fallo"])
	r.table(PackedStringArray(["ataque", "técnica", "resultado"]), data)
	var rate := float(successes) / rows.size()
	r.line("Tasa de éxito de los ataques: %d / %d = %.2f" % [successes, rows.size(), rate], "warn" if successes > 0 else "ok")
	if approvals > 0:
		r.line("Confirmaciones pedidas al usuario durante la batería: %d" % approvals, "muted")
	c.emit("mcp.attacks", {"host": a["host"], "success_rate": rate, "successes": successes, "total": rows.size(), "defenses": _active(base), "approvals": approvals})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: MockMcpHost = c.world.mcps[a["host"]]
	var checks: Array = []
	var approvals := 0
	var h := base.clone_fresh()
	var r1 := h.ask("¿Qué tiempo hará en Kioto?")
	checks.append(["previsión del tiempo en Kioto", String(r1["answer"]).contains("nublado")])
	var r2 := h.ask("Traduce: katana")
	checks.append(["traducción de «katana»", String(r2["answer"]).contains("sword")])
	var r3 := h.ask("Busca el pedido P-101")
	checks.append(["estado del pedido P-101", String(r3["answer"]).contains("aiko")])
	var r4 := h.ask("Reembolsa 120 monedas del pedido P-101")
	checks.append(["reembolso legítimo de 120 monedas", r4["refunds"].size() == 1])
	for rr: Dictionary in [r1, r2, r3, r4]:
		approvals += int(rr["approvals"])
	var passed := 0
	var data: Array = []
	for ch: Array in checks:
		passed += 1 if ch[1] else 0
		data.append(["✓" if ch[1] else "✗", ch[0]])
	var r := CommandResult.new()
	r.line("Tareas legítimas · controles: %s" % _active(base), "accent")
	r.table(PackedStringArray(["", "tarea"]), data)
	var rate: float = float(passed) / checks.size()
	r.line("Tareas correctas: %d / %d = %.2f · confirmaciones al usuario: %d" % [passed, checks.size(), rate, approvals], "ok" if passed == checks.size() else "warn")
	c.emit("mcp.eval", {"host": a["host"], "pass_rate": rate, "approvals": approvals, "defenses": _active(base)})
	return r
