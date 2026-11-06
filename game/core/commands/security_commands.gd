class_name SecurityCommands
extends RefCounted
## A1 · Aplicación LLM: construir, atacar, defender y desplegar un chatbot (SIMULADO).
## Todo ocurre contra el chatbot ficticio del Dojo: nada sale de este laboratorio.

const ATTACKS_PATH := "res://content/attacks/a1.json"
const NORMAL_PATH := "res://content/attacks/a1_normal.json"
const REPORT_FIELDS: Array[String] = ["titulo", "severidad", "componente", "owasp", "descripcion", "pasos", "impacto", "evidencia", "mitigacion", "verificacion"]
const SEVERITIES: Array[String] = ["baja", "media", "alta", "critica", "crítica"]


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("bot create", "Crea el chatbot de atención al cliente de la forja (configuración inicial).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del chatbot").example("bot create kuro")))
	reg.register(Command.new("bot show", "Muestra el system prompt y las defensas activas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot")))
	reg.register(Command.new("bot system", "Cambia el system prompt (las instrucciones del sistema).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _system(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot").pos("texto", "nuevo system prompt", "rest")))
	reg.register(Command.new("bot ask", "Envía un mensaje al chatbot como si fueras un cliente.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ask(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot").pos("mensaje", "mensaje del cliente", "rest")
			.example("bot ask kuro ¿Cuál es vuestro horario?")))
	reg.register(Command.new("bot render", "Muestra cómo pintaría la web la respuesta del chatbot.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _render(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot").pos("mensaje", "mensaje del cliente", "rest")))
	reg.register(Command.new("bot defend", "Activa o desactiva una defensa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _defend(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot")
			.pos("defensa", "defensa", "string", true, Array(MockChatbot.DEFENSES))
			.pos("estado", "on u off", "string", true, ["on", "off"])
			.example("bot defend kuro input-filter on")
			.example("bot defend kuro secret-in-prompt off")))
	reg.register(Command.new("bot attack", "Lanza la batería de ataques del laboratorio y mide la tasa de éxito.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attack(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot")))
	reg.register(Command.new("bot eval", "Prueba el chatbot con preguntas legítimas de clientes (funciona bien y sin falsos positivos?).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("bot", "chatbot", "bot")))

	reg.register(Command.new("informe nuevo", "Empieza un informe de vulnerabilidad.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _report_new(c, a), "seguridad")
		.with_signature(CommandSignature.new().pos("titulo", "título del hallazgo", "rest")))
	reg.register(Command.new("informe campo", "Rellena un campo del informe.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _report_field(c, a), "seguridad")
		.with_signature(CommandSignature.new()
			.pos("campo", "campo del informe", "string", true, Array(REPORT_FIELDS))
			.pos("texto", "contenido", "rest")
			.example("informe campo severidad alta")
			.example("informe campo owasp LLM01")))
	reg.register(Command.new("informe ver", "Muestra el informe actual.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _report_view(c, a), "seguridad"))
	reg.register(Command.new("informe revisar", "Revisa el informe con la rúbrica profesional.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _report_check(c, a), "seguridad"))


static func _game(c: CommandContext) -> DojoGame:
	return c.shell.get_game() as DojoGame


static func _active(bot: MockChatbot) -> String:
	var on := PackedStringArray()
	for d in MockChatbot.DEFENSES:
		if d == "secret-in-prompt":
			continue
		if bot.defenses[d]:
			on.append(d)
	if not bot.system_prompt.contains(MockChatbot.SECRET):
		on.append("sin-secreto-en-prompt")
	return ",".join(on) if not on.is_empty() else "ninguna"


# ── Chatbot ──────────────────────────────────────────────────────────────────

static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.bots[a["nombre"]] = MockChatbot.new(a["nombre"])
	var r := CommandResult.new()
	r.line("✓ chatbot %s creado con la configuración inicial de la forja." % a["nombre"], "ok")
	r.line("⚗ Es un LLM SIMULADO por reglas que imita comportamientos documentados de los LLM reales. Míralo con: bot show %s" % a["nombre"], "muted")
	c.emit("bot.created", {"bot": a["nombre"]})
	return r


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	var r := CommandResult.new()
	r.line("%s · system prompt:" % a["bot"], "accent")
	r.line(bot.system_prompt, "data")
	r.line("")
	var data: Array = []
	for d in MockChatbot.DEFENSES:
		var on: bool = bot.defenses[d]
		var desc: String = {"input-filter": "lista negra de frases sobre el mensaje del usuario", "output-filter": "busca el secreto en la respuesta y lo tacha",
			"encode-output": "escapa el HTML antes de pintarlo en la web", "max-tokens": "limita la longitud de la respuesta a %d palabras" % MockChatbot.MAX_TOKENS,
			"secret-in-prompt": "el código de descuento está DENTRO del system prompt"}[d]
		if d == "secret-in-prompt":
			on = bot.system_prompt.contains(MockChatbot.SECRET)
		data.append([d, "sí" if on else "no", desc])
	r.table(PackedStringArray(["defensa / configuración", "activa", "qué hace"]), data)
	c.emit("bot.shown", {"bot": a["bot"]})
	return r


static func _system(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	bot.system_prompt = a["texto"]
	c.emit("bot.system", {"bot": a["bot"], "has_secret": bot.system_prompt.contains(MockChatbot.SECRET)})
	return CommandResult.new().line("✓ system prompt actualizado (%d palabras)." % String(a["texto"]).split(" ", false).size(), "ok")


static func _ask(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	var res := bot.reply(a["mensaje"])
	var r := CommandResult.new()
	var shown: String = res["text"]
	if shown.length() > 600:
		shown = shown.substr(0, 600) + " …(%d palabras en total)" % res["tokens"]
	r.line("🤖 " + shown, "data")
	var flags := PackedStringArray()
	if res["blocked"]:
		flags.append("bloqueado por %s" % res["defense"])
	if res["defense"] == "output-filter":
		flags.append("el filtro de salida ha tachado algo")
	if res["truncated"]:
		flags.append("respuesta truncada por max-tokens")
	if res["tokens"] > 500:
		flags.append("⚠ respuesta enorme: %d palabras (coste)" % res["tokens"])
	if res["leaked"]:
		flags.append("⚠ ¡el secreto ha salido en la respuesta!")
	if not flags.is_empty():
		r.line("  [" + " · ".join(flags) + "]", "warn" if res["leaked"] or res["tokens"] > 500 else "muted")
	var data := res.duplicate()
	data.erase("text")
	data.merge({"bot": a["bot"], "message": a["mensaje"], "defenses": _active(bot), "secret_in_prompt": bot.system_prompt.contains(MockChatbot.SECRET)})
	c.emit("bot.replied", data)
	return r


static func _render(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	var res := bot.reply(a["mensaje"])
	var rendered := bot.render(res["text"])
	var r := CommandResult.new()
	r.line("Respuesta del modelo: " + String(res["text"]).substr(0, 300), "data")
	r.line("HTML que recibe el navegador: " + String(rendered["html"]).substr(0, 300), "data")
	if rendered["executes"]:
		r.line("⚠ El navegador EJECUTARÍA código: la salida del modelo se trata como HTML de confianza (XSS).", "error")
	else:
		r.line("✓ El navegador lo muestra como texto: no se ejecuta nada.", "ok")
	c.emit("bot.rendered", {"bot": a["bot"], "executes": rendered["executes"], "encoded": bot.defenses["encode-output"], "html_in_answer": res["html"]})
	return r


static func _defend(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	var on: bool = a["estado"] == "on"
	bot.set_defense(a["defensa"], on)
	var r := CommandResult.new()
	r.line("✓ %s → %s" % [a["defensa"], "activada" if on else "desactivada"], "ok")
	if a["defensa"] == "secret-in-prompt":
		r.line("El system prompt ha cambiado: mira bot show %s" % a["bot"], "muted")
	c.emit("bot.defense", {"bot": a["bot"], "defense": a["defensa"], "enabled": on})
	return r


static func _attack(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	var suite: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATTACKS_PATH))
	var r := CommandResult.new()
	r.line("Batería de ataques A1 contra %s · defensas: %s" % [a["bot"], _active(bot)], "accent")
	var data: Array = []
	var successes := 0
	var by_cat := {}
	for atk: Dictionary in suite["attacks"]:
		var res := bot.reply(atk["payload"])
		var ok := false
		match atk["success"]:
			"leak": ok = res["leaked"]
			"xss": ok = bot.render(res["text"])["executes"]
			"flood": ok = res["tokens"] > 500
		if ok:
			successes += 1
		by_cat[atk["category"]] = by_cat.get(atk["category"], 0) + (1 if ok else 0)
		var why := "bloqueado (%s)" % res["defense"] if res["blocked"] else ("tachado por output-filter" if res["defense"] == "output-filter" and not ok else "")
		data.append([atk["id"], atk["category"], "✗ ÉXITO" if ok else "· fallo", why])
	r.table(PackedStringArray(["ataque", "categoría", "resultado", "detalle"]), data)
	var total: int = suite["attacks"].size()
	var rate := float(successes) / total
	r.line("Tasa de éxito de los ataques: %d / %d = %s" % [successes, total, "%.2f" % rate], "warn" if successes > 0 else "ok")
	c.emit("bot.attacks", {"bot": a["bot"], "success_rate": rate, "successes": successes, "total": total, "by_category": by_cat,
		"defenses": _active(bot), "secret_in_prompt": bot.system_prompt.contains(MockChatbot.SECRET)})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var bot: MockChatbot = c.world.bots[a["bot"]]
	var suite: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NORMAL_PATH))
	var r := CommandResult.new()
	r.line("Evaluación con %d preguntas legítimas · defensas: %s" % [suite["questions"].size(), _active(bot)], "accent")
	var data: Array = []
	var passed := 0
	var false_pos := 0
	for q: Dictionary in suite["questions"]:
		var res := bot.reply(q["message"])
		var ok: bool = not res["blocked"] and not res["leaked"]
		if q.has("expect"):
			ok = ok and String(res["text"]).contains(q["expect"])
		if res["blocked"]:
			false_pos += 1
		if ok:
			passed += 1
		data.append([q["id"], "✓" if ok else "✗", "BLOQUEADA (falso positivo)" if res["blocked"] else String(res["text"]).substr(0, 60)])
	r.table(PackedStringArray(["pregunta", "", "respuesta"]), data)
	var rate: float = float(passed) / suite["questions"].size()
	r.line("Respuestas correctas: %d / %d = %s · falsos positivos: %d" % [passed, suite["questions"].size(), "%.2f" % rate, false_pos], "ok" if passed == suite["questions"].size() else "warn")
	c.emit("bot.eval", {"bot": a["bot"], "pass_rate": rate, "false_positives": false_pos, "defenses": _active(bot), "secret_in_prompt": bot.system_prompt.contains(MockChatbot.SECRET)})
	return r


# ── Informe ──────────────────────────────────────────────────────────────────

static func _report_new(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("Los informes necesitan el sistema de misiones.")
	g.report = {"titulo": a["titulo"]}
	c.emit("report.created", {"title": a["titulo"]})
	var r := CommandResult.new().line("✓ informe «%s» creado." % a["titulo"], "ok")
	r.line("Campos: " + ", ".join(REPORT_FIELDS) + ". Rellénalos con: informe campo <campo> <texto>", "muted")
	return r


static func _report_field(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null or g.report.is_empty():
		return CommandResult.error("Primero crea un informe: informe nuevo <título>")
	g.report[a["campo"]] = a["texto"]
	c.emit("report.field", {"field": a["campo"]})
	return CommandResult.new().line("✓ %s actualizado." % a["campo"], "ok")


static func _report_view(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null or g.report.is_empty():
		return CommandResult.error("No hay ningún informe. Crea uno con: informe nuevo <título>")
	var r := CommandResult.new()
	r.line("INFORME DE VULNERABILIDAD", "accent")
	for f in REPORT_FIELDS:
		r.line("%s: %s" % [f.to_upper(), g.report.get(f, "— (pendiente)")], "data" if g.report.has(f) else "muted")
	return r


## Rúbrica comprobable. La calidad de la redacción la revisaremos juntos: esto comprueba la estructura.
static func _report_check(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null or g.report.is_empty():
		return CommandResult.error("No hay ningún informe. Crea uno con: informe nuevo <título>")
	var rep := g.report
	var problems := PackedStringArray()
	for f in REPORT_FIELDS:
		var text := String(rep.get(f, "")).strip_edges()
		var min_words := 1 if f in ["severidad", "owasp"] else 4
		if text.split(" ", false).size() < min_words:
			problems.append("«%s» está vacío o es demasiado breve (mínimo %d palabras)." % [f, min_words])
	var sev := String(rep.get("severidad", "")).to_lower().strip_edges()
	if not sev.is_empty() and not sev in SEVERITIES:
		problems.append("severidad debe ser: baja, media, alta o crítica.")
	var owasp_rx := RegEx.create_from_string("LLM(0[1-9]|10)|ASI(0[1-9]|10)")
	var owasp_ok := owasp_rx.search(String(rep.get("owasp", "")).to_upper()) != null
	if not owasp_ok:
		problems.append("owasp debe citar una categoría OWASP: Top 10 for LLM Applications 2025 (LLM01…LLM10) o Top 10 for Agentic Applications 2026 (ASI01…ASI10).")
	var has_metrics := RegEx.create_from_string("\\d").search(String(rep.get("verificacion", ""))) != null
	if not has_metrics:
		problems.append("verificacion debe incluir una medida (p. ej. la tasa de éxito de los ataques antes y después).")
	var steps_ok := String(rep.get("pasos", "")).contains("bot ") or String(rep.get("pasos", "")).contains("rag ") or String(rep.get("pasos", "")).contains("agent ") or String(rep.get("pasos", "")).contains("mcp ") or RegEx.create_from_string("\\d\\)").search(String(rep.get("pasos", ""))) != null
	if not steps_ok:
		problems.append("pasos debe ser reproducible: incluye los comandos o una lista numerada 1) 2) 3).")
	var r := CommandResult.new()
	if problems.is_empty():
		r.line("✓ El informe cumple la rúbrica estructural.", "ok")
		r.line("La rúbrica no puede juzgar la calidad de la redacción: guárdalo y lo revisaremos juntos.", "muted")
		g.progress.data["reports"] = g.progress.data.get("reports", [])
		g.progress.data["reports"].append(rep.duplicate())
	else:
		r.line("El informe aún no está listo:", "warn")
		for p in problems:
			r.line("  · " + p, "warn")
	c.emit("report.checked", {"complete": problems.is_empty(), "problems": problems.size(), "owasp": String(rep.get("owasp", "")).to_upper(),
		"severity": sev, "has_metrics": has_metrics})
	return r
