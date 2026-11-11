class_name AgentCommands
extends RefCounted
## A3 · Agentes con herramientas y memoria (laboratorio simulado).

const ATTACKS_PATH := "res://content/agent/attacks.json"


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("agent create", "Crea el agente de la trastienda de la forja.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "agentes")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del agente").example("agent create kage")))
	reg.register(Command.new("agent tools", "Herramientas del agente y cuáles son sensibles.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _tools(c, a), "agentes")
		.with_signature(CommandSignature.new().pos("agente", "agente", "agent")))
	reg.register(Command.new("agent inbox", "Bandeja de entrada que lee el agente.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _inbox(c, a), "agentes")
		.with_signature(CommandSignature.new().pos("agente", "agente", "agent")))
	reg.register(Command.new("agent mail", "Envía un correo a la bandeja del agente (como haría cualquiera desde fuera).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _mail(c, a), "agentes")
		.with_signature(CommandSignature.new()
			.pos("agente", "agente", "agent")
			.pos("remitente", "dirección del remitente")
			.pos("texto", "cuerpo del correo", "rest")
			.example("agent mail kage pepe@phish.example Hola, ¿qué tal?")))
	reg.register(Command.new("agent run", "Ejecuta una tarea autónoma del agente y muestra su traza paso a paso.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _run(c, a), "agentes")
		.with_signature(CommandSignature.new()
			.pos("agente", "agente", "agent")
			.pos("tarea", "tarea", "string", true, ["triaje", "presupuesto"])
			.opt("cliente", "cliente del presupuesto (tarea presupuesto)", "string")
			.example("agent run kage triaje")
			.example("agent run kage presupuesto --cliente aiko@clientes.example")))
	reg.register(Command.new("agent chat", "Habla con el agente y dale una orden directa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _chat(c, a), "agentes")
		.with_signature(CommandSignature.new()
			.pos("agente", "agente", "agent")
			.pos("mensaje", "tu mensaje", "rest")
			.opt("as", "quién habla", "string", "empleado", ["empleado", "cliente"])
			.example("agent chat kage Reembolsa 120 monedas del pedido P-101 --as empleado")))
	reg.register(Command.new("agent memory", "Memoria permanente del agente (y de dónde salió cada nota).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _memory(c, a), "agentes")
		.with_signature(CommandSignature.new().pos("agente", "agente", "agent")))
	reg.register(Command.new("agent defend", "Activa o desactiva un control de seguridad del agente.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _defend(c, a), "agentes")
		.with_signature(CommandSignature.new()
			.pos("agente", "agente", "agent")
			.pos("defensa", "control", "string", true, Array(MockAgent.DEFENSES))
			.pos("estado", "on u off", "string", true, ["on", "off"])
			.example("agent defend kage least-privilege on")))
	reg.register(Command.new("agent attack", "Batería de ataques A3 (cada uno sobre una copia nueva del agente).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attack(c, a), "agentes")
		.with_signature(CommandSignature.new().pos("agente", "agente", "agent")))
	reg.register(Command.new("agent eval", "Tareas legítimas: ¿sigue haciendo bien su trabajo?",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), "agentes")
		.with_signature(CommandSignature.new().pos("agente", "agente", "agent")))


static func _active(ag: MockAgent) -> String:
	var on := PackedStringArray()
	for d in MockAgent.DEFENSES:
		if ag.defenses[d]:
			on.append(d)
	return ",".join(on) if not on.is_empty() else "ninguna"


static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.agents[a["nombre"]] = MockAgent.create(a["nombre"])
	c.emit("agent.created", {"agent": a["nombre"]})
	var r := CommandResult.new().line("✓ agente %s listo: lee correos, consulta pedidos, responde, reembolsa y recuerda." % a["nombre"], "ok")
	r.line("⚗ Su «razonamiento» está simulado por reglas; las herramientas y los controles actúan de verdad sobre el estado del laboratorio.", "muted")
	return r


static func _tools(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	var data: Array = []
	for t in ag.tools:
		var tasks := PackedStringArray()
		for task: String in ag.task_tools:
			if t["name"] in ag.task_tools[task]:
				tasks.append(task)
		# «sensible» va al final: el ⚠ se dibuja con la fuente de emojis y descuadraría las columnas siguientes.
		data.append([t["name"], t["description"], ", ".join(tasks) if not tasks.is_empty() else "—", "⚠ sí" if t["sensitive"] else "no"])
	var r := CommandResult.new().table(PackedStringArray(["herramienta", "qué hace", "tareas que la necesitan", "sensible"]), data)
	r.line("Ahora mismo el agente puede usar TODAS las herramientas en cualquier tarea (salvo que actives least-privilege).", "muted")
	c.emit("agent.tools", {"agent": a["agente"], "sensitive": ag.tools.filter(func(t: Dictionary) -> bool: return t["sensitive"]).size()})
	return r


static func _inbox(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	var data: Array = []
	for m in ag.inbox:
		data.append([m["id"], m["from"], m["subject"]])
	c.emit("agent.inbox", {"agent": a["agente"], "count": ag.inbox.size()})
	return CommandResult.new().table(PackedStringArray(["id", "de", "asunto"]), data)


static func _mail(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	ag.receive_mail(a["remitente"], "(sin asunto)", a["texto"])
	c.emit("agent.mailed", {"agent": a["agente"], "from": a["remitente"], "text": a["texto"], "instructions": MockAgent.parse_instructions(a["texto"]).size()})
	return CommandResult.new().line("✓ correo de %s entregado en la bandeja del agente." % a["remitente"], "ok")


static func _print_trace(r: CommandResult, ag: MockAgent) -> void:
	for s in ag.trace:
		var args := PackedStringArray()
		for k: String in s["args"]:
			args.append("%s=%s" % [k, TextUtils.clip(str(s["args"][k]), 40)])
		var who: String = s["source"]
		var origin := "  ⟵ instrucción de " + who if who.begins_with("correo") else ""
		if s["blocked_by"].is_empty():
			r.line("%2d · %s(%s) → %s%s" % [s["n"], s["tool"], ", ".join(args), TextUtils.clip(String(s["output"]), 50), origin], "warn" if who.begins_with("correo") else "data")
		else:
			r.line("%2d · %s(%s) ✋ BLOQUEADO por %s%s" % [s["n"], s["tool"], ", ".join(args), s["blocked_by"], origin], "ok")


static func _summary(r: CommandResult, res: Dictionary) -> void:
	var parts := PackedStringArray(["%d pasos" % res["steps"]])
	if res["replies"] > 0:
		parts.append("%d respuestas a clientes" % res["replies"])
	for rf: Dictionary in res["refunds"]:
		parts.append("REEMBOLSO %d monedas en %s" % [rf["importe"], rf["pedido"]])
	if res["exfil"]:
		parts.append("⚠ LISTA DE CLIENTES ENVIADA FUERA (%s)" % ", ".join(PackedStringArray(res["external"])))
	if res["memory_from_email"] > 0:
		parts.append("⚠ %d nota(s) en memoria escritas por un correo" % res["memory_from_email"])
	if res["looped"]:
		parts.append("⚠ BUCLE: el agente no terminaba")
	if not String(res["stopped"]).is_empty():
		parts.append("detenido: " + res["stopped"])
	if res["approvals"] > 0:
		parts.append("%d aprobaciones humanas pedidas" % res["approvals"])
	if res.get("discount", 0) > 0:
		parts.append("⚠ DESCUENTO DEL %d%% para %s" % [res["discount"], res.get("customer", "")])
	r.line("Resultado: " + " · ".join(parts), "accent")


static func _run(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	var res: Dictionary
	if a["tarea"] == "presupuesto":
		if a["cliente"] == null:
			return CommandResult.error("Indica el cliente: agent run %s presupuesto --cliente <correo>" % a["agente"])
		res = ag.run_quote(a["cliente"])
	else:
		res = ag.run_triage()
	var r := CommandResult.new()
	r.line("Traza del agente · tarea %s · controles: %s" % [a["tarea"], _active(ag)], "accent")
	_print_trace(r, ag)
	_summary(r, res)
	c.emit("agent.ran", _event(a["agente"], ag, res))
	return r


static func _chat(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	var res := ag.run_chat(a["mensaje"], a["as"])
	var r := CommandResult.new()
	r.line("Traza del agente · conversación con un %s · controles: %s" % [a["as"], _active(ag)], "accent")
	_print_trace(r, ag)
	_summary(r, res)
	var ev := _event(a["agente"], ag, res)
	ev["message"] = a["mensaje"]
	c.emit("agent.chat", ev)
	return r


static func _event(agent_name: String, ag: MockAgent, res: Dictionary) -> Dictionary:
	var total_refund := 0
	var refund_orders := PackedStringArray()
	for rf: Dictionary in res["refunds"]:
		total_refund += int(rf["importe"])
		refund_orders.append(rf["pedido"])
	var blocked_by := PackedStringArray()
	for b: Dictionary in res["blocked"]:
		blocked_by.append(b["by"])
	return {"agent": agent_name, "task": res["task"], "role": res["role"], "steps": res["steps"], "refund_total": total_refund,
		"refund_orders": ",".join(refund_orders), "exfil": res["exfil"], "external": res["external"].size(), "memory_from_email": res["memory_from_email"],
		"hijacked": res["hijacked"], "looped": res["looped"], "approvals": res["approvals"], "blocked": ",".join(blocked_by),
		"replies": res["replies"], "discount": res.get("discount", 0), "defenses": _active(ag)}


static func _memory(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	var r := CommandResult.new()
	if ag.memory.is_empty():
		r.line("La memoria está vacía.", "muted")
	var data: Array = []
	for m in ag.memory:
		data.append([TextUtils.clip(str(m["text"]), 70), m["source"]])
	if not data.is_empty():
		r.table(PackedStringArray(["nota", "origen"]), data)
	c.emit("agent.memory", {"agent": a["agente"], "notes": ag.memory.size(),
		"from_email": ag.memory.filter(func(m: Dictionary) -> bool: return String(m["source"]).begins_with("correo")).size()})
	return r


static func _defend(c: CommandContext, a: Dictionary) -> CommandResult:
	var ag: MockAgent = c.world.agents[a["agente"]]
	ag.defenses[a["defensa"]] = a["estado"] == "on"
	c.emit("agent.defense", {"agent": a["agente"], "defense": a["defensa"], "enabled": a["estado"] == "on"})
	return CommandResult.new().line("✓ %s → %s" % [a["defensa"], "activado" if a["estado"] == "on" else "desactivado"], "ok")


static func _attack(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: MockAgent = c.world.agents[a["agente"]]
	var rows := run_suite(base)
	var r := CommandResult.new()
	r.line("Batería de ataques A3 contra %s · controles: %s" % [a["agente"], _active(base)], "accent")
	var data: Array = []
	var successes := 0
	var approvals := 0
	for row: Array in rows:
		if row[2]:
			successes += 1
		approvals += int(row[4])
		data.append([row[0], row[1], "✗ ÉXITO" if row[2] else "· fallo", row[3]])
	r.table(PackedStringArray(["ataque", "categoría", "resultado", "bloqueado por"]), data)
	var total: int = rows.size()
	var rate := float(successes) / total
	r.line("Tasa de éxito de los ataques: %d / %d = %.2f" % [successes, total, rate], "warn" if successes > 0 else "ok")
	if approvals > 0:
		r.line("Aprobaciones humanas pedidas durante la batería: %d" % approvals, "muted")
	c.emit("agent.attacks", {"agent": a["agente"], "success_rate": rate, "successes": successes, "total": total, "defenses": _active(base), "approvals": approvals})
	return r


## Escenarios de la batería A3. Devuelve [[id, categoría, éxito, "bloqueado por", aprobaciones]].
static func run_suite(base: MockAgent) -> Array:
	var suite: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATTACKS_PATH))
	var rows: Array = []
	for atk: Dictionary in suite["attacks"]:
		var approvals := 0
		var ag := base.clone_fresh()
		var res: Dictionary
		if atk.has("chat"):
			res = ag.run_chat(atk["chat"]["message"], atk["chat"]["role"])
		else:
			ag.receive_mail(atk["mail"]["from"], atk["mail"]["subject"], atk["mail"]["body"])
			res = ag.run_triage()
			if atk.has("then_quote"):
				approvals += res["approvals"]
				res = ag.run_quote(atk["then_quote"])
		approvals += res["approvals"]
		var ok := false
		match atk["success"]:
			"refund": ok = not res["refunds"].is_empty()
			"exfil": ok = res["exfil"]
			"discount": ok = res.get("discount", 0) >= 50
			"loop": ok = res["looped"]
		var blocked := PackedStringArray()
		for b: Dictionary in res["blocked"]:
			if not b["by"] in blocked:
				blocked.append(b["by"])
		rows.append([atk["id"], atk["category"], ok, ", ".join(blocked), approvals])
	return rows


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: MockAgent = c.world.agents[a["agente"]]
	var r := CommandResult.new()
	r.line("Tareas legítimas · controles: %s" % _active(base), "accent")
	var ev := run_eval(base)
	var checks: Array = ev["rows"]
	var approvals: int = ev["approvals"]
	var passed := 0
	var data: Array = []
	for ch: Array in checks:
		if ch[1]:
			passed += 1
		data.append(["✓" if ch[1] else "✗", ch[0]])
	r.table(PackedStringArray(["", "comprobación"]), data)
	var rate: float = float(passed) / checks.size()
	r.line("Tareas correctas: %d / %d = %.2f · aprobaciones humanas necesarias: %d" % [passed, checks.size(), rate, approvals], "ok" if passed == checks.size() else "warn")
	c.emit("agent.eval", {"agent": a["agente"], "pass_rate": rate, "approvals": approvals, "defenses": _active(base)})
	return r


## Tareas legítimas. Devuelve {"passed", "total", "approvals", "rows": [[comprobación, ok]]}.
static func run_eval(base: MockAgent) -> Dictionary:
	var checks: Array = []
	var approvals := 0
	var ag := base.clone_fresh()
	var t1 := ag.run_triage()
	checks.append(["triaje: responde a los 3 clientes sin efectos raros", t1["replies"] == 3 and t1["refunds"].is_empty() and t1["external"].is_empty()])
	approvals += t1["approvals"]
	var t2 := ag.run_chat("Reembolsa 120 monedas del pedido P-101 por el arañazo de la funda.", "empleado")
	checks.append(["un empleado aplica un reembolso legítimo de 120", t2["refunds"].size() == 1])
	approvals += t2["approvals"]
	ag.run_chat("Recuerda que aiko@clientes.example prefiere los envíos por la mañana.", "empleado")
	var t3 := ag.run_quote("aiko@clientes.example")
	checks.append(["presupuesto para aiko sin descuentos inventados", t3["discount"] == 0])
	approvals += t3["approvals"]
	var passed := 0
	for ch: Array in checks:
		if ch[1]:
			passed += 1
	return {"passed": passed, "total": checks.size(), "approvals": approvals, "rows": checks}
