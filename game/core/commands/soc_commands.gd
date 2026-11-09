class_name SocCommands
extends RefCounted
## O6 · Detección y respuesta (blue team de IA) sobre trazas simuladas de un agente.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("soc trazas", "Abre el registro de trazas del asistente del taller (12 sesiones ficticias).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del registro").example("soc trazas taller")))
	reg.register(Command.new("soc coverage", "Qué preguntas forenses se pueden responder con lo que se registra, y si se guardan datos personales.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _coverage(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("registro", "registro de trazas", "soc")))
	reg.register(Command.new("soc log", "Activa o desactiva qué se registra de cada sesión (o la redacción de datos personales).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _log(c, a), "deteccion")
		.with_signature(CommandSignature.new()
			.pos("registro", "registro de trazas", "soc")
			.pos("campo", "qué registrar", "string", true, Array(MockTraceStore.LOG_FIELDS) + ["redact-pii"])
			.pos("estado", "on u off", "string", true, ["on", "off"])
			.example("soc log taller tool_args on")))
	reg.register(Command.new("soc show", "Muestra una sesión tal como quedó registrada (línea de tiempo).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("registro", "registro de trazas", "soc").pos("sesion", "S01 … S12").example("soc show taller S04")))
	reg.register(Command.new("soc rule", "Activa o desactiva una regla de detección.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _rule(c, a), "deteccion")
		.with_signature(CommandSignature.new()
			.pos("registro", "registro de trazas", "soc")
			.pos("regla", "regla de detección", "string", true, Array(MockTraceStore.RULES))
			.pos("estado", "on u off", "string", true, ["on", "off"])))
	reg.register(Command.new("soc detect", "Pasa las reglas activas por todas las sesiones y mide precision y recall contra las etiquetas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _detect(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("registro", "registro de trazas", "soc")))
	reg.register(Command.new("soc search", "Busca un texto en las trazas registradas (alcance de un incidente).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _search(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("registro", "registro de trazas", "soc").pos("texto", "texto a buscar").example("soc search taller prov-77")))
	reg.register(Command.new("soc contain", "Activa o desactiva una acción de contención del incidente.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _contain(c, a), "deteccion")
		.with_signature(CommandSignature.new()
			.pos("registro", "registro de trazas", "soc")
			.pos("accion", "acción de contención", "string", true, Array(MockTraceStore.ACTIONS))
			.pos("estado", "on u off", "string", true, ["on", "off"])))
	reg.register(Command.new("soc retest", "Repite el ataque (y una variante) y las tareas legítimas con la contención actual.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _retest(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("registro", "registro de trazas", "soc")))


static func _logging(s: MockTraceStore) -> String:
	var l := s.active(s.logging, Array(MockTraceStore.LOG_FIELDS))
	return l + (" + redact-pii" if s.redact_pii else "")


static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	var s := MockTraceStore.create(a["nombre"])
	c.world.traces[a["nombre"]] = s
	c.emit("soc.created", {"store": a["nombre"]})
	var r := CommandResult.new().line("✓ registro %s abierto: %d sesiones de %s (13–16 oct 2026)." % [a["nombre"], s.sessions.size(), s.data["agent"]], "ok")
	r.line("Se registra ahora: %s. ⚗ Sesiones, personas y dominios ficticios (.example)." % _logging(s), "muted")
	r.line("Siguiente: soc coverage %s" % a["nombre"], "muted")
	return r


static func _coverage(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	var cov := s.coverage()
	var data: Array = []
	for row: Array in cov["rows"]:
		data.append(["✓" if row[2] else "✗", row[0], row[1]])
	var r := CommandResult.new()
	r.line("Preguntas forenses · se registra: %s" % _logging(s), "accent")
	r.table(PackedStringArray(["", "pregunta", "campo necesario"]), data)
	r.line("Respondibles: %d / %d" % [cov["answered"], cov["total"]], "ok" if cov["answered"] == cov["total"] else "warn")
	if cov["pii_stored"]:
		r.line("⚠ el registro guarda datos personales en claro (correos o teléfonos)", "warn")
	else:
		r.line("✓ sin datos personales en claro en el registro", "ok")
	c.emit("soc.coverage", {"store": a["registro"], "answered": cov["answered"], "total": cov["total"], "pii_stored": cov["pii_stored"], "logging": _logging(s)})
	return r


static func _log(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	var on: bool = a["estado"] == "on"
	if a["campo"] == "redact-pii":
		s.redact_pii = on
	else:
		s.logging[a["campo"]] = on
	c.emit("soc.logging", {"store": a["registro"], "field": a["campo"], "enabled": on, "logging": _logging(s)})
	var r := CommandResult.new().line("✓ %s → %s" % [a["campo"], "activado" if on else "desactivado"], "ok")
	r.line("⚗ En el laboratorio el cambio se aplica también a las sesiones pasadas; en la realidad, lo que no se registró se ha perdido.", "muted")
	return r


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	var sess := s.session(a["sesion"])
	if sess.is_empty():
		return CommandResult.error("No existe la sesión '%s'. Opciones: %s" % [a["sesion"], ", ".join(s.session_ids())])
	var v := s.view(sess)
	var r := CommandResult.new()
	r.line("Sesión %s · usuario: %s · modelo: %s" % [v["id"], v["user"], v["model_version"]], "accent")
	var destinations := PackedStringArray()
	var sources := PackedStringArray()
	for e: Dictionary in v["events"]:
		var hhmm := String(e["ts"]).substr(11, 8)
		match e["type"]:
			"prompt":
				r.line("%s  usuario › %s" % [hhmm, e["text"]], "data")
			"response":
				r.line("%s  asistente › %s" % [hhmm, e["text"]], "data")
			"retrieval":
				r.line("%s  recupera %s: «%s»" % [hhmm, e["source"], e["content"]], "data")
				sources.append(e["source"])
			"tool":
				var times := " ×%d" % e["repeat"] if int(e["repeat"]) > 1 else ""
				if e.has("args"):
					r.line("%s  herramienta %s(%s) → %s%s" % [hhmm, e["tool"], e["args"], e["result"], times], "data")
					var d := MockTraceStore._domain(e["args"])
					if d != "":
						destinations.append(d)
				else:
					r.line("%s  herramienta %s(…)%s" % [hhmm, e["tool"], times], "data")
	var missing := PackedStringArray()
	for f in MockTraceStore.LOG_FIELDS:
		if not s.logging[f]:
			missing.append(f)
	if not missing.is_empty():
		r.line("No registrado: %s" % ", ".join(missing), "muted")
	c.emit("soc.viewed", {"store": a["registro"], "session": v["id"], "complete": missing.is_empty(),
		"destinations": ",".join(destinations), "sources": ",".join(sources), "events": v["events"].size()})
	return r


static func _rule(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	s.rules[a["regla"]] = a["estado"] == "on"
	c.emit("soc.rule", {"store": a["registro"], "rule": a["regla"], "enabled": a["estado"] == "on"})
	return CommandResult.new().line("✓ regla %s → %s (%s)" % [a["regla"], "activada" if a["estado"] == "on" else "desactivada", MockTraceStore.RULE_TEXT[a["regla"]]], "ok")


static func _detect(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	var res := s.detect()
	var rules := s.active(s.rules, Array(MockTraceStore.RULES))
	var r := CommandResult.new()
	r.line("Detección · reglas: %s · se registra: %s" % [rules, _logging(s)], "accent")
	for b: String in res["blind"]:
		var need := PackedStringArray()
		for f: String in MockTraceStore.RULE_NEEDS[b]:
			if not s.logging[f]:
				need.append(f)
		r.line("⚠ regla %s ciega: necesita registrar %s" % [b, ", ".join(need)], "warn")
	r.table(PackedStringArray(["sesión", "reglas que saltan", "etiqueta", "resultado"]), res["rows"])
	r.line("VP %d · FP %d · FN %d · precision %.2f · recall %.2f" % [res["tp"], res["fp"], res["fn"], res["precision"], res["recall"]], "ok" if res["fn"] == 0 and res["fp"] == 0 else "data")
	c.emit("soc.detected", {"store": a["registro"], "rules": rules, "tp": res["tp"], "fp": res["fp"], "fn": res["fn"],
		"precision": res["precision"], "recall": res["recall"], "blind": res["blind"].size()})
	return r


static func _search(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	var hits := s.search(a["texto"])
	var r := CommandResult.new()
	if hits.is_empty():
		r.line("Sin resultados para «%s» en lo registrado (se registra: %s)." % [a["texto"], _logging(s)], "warn")
	else:
		r.line("«%s» aparece en %d sesiones: %s" % [a["texto"], hits.size(), ", ".join(hits)], "ok")
	c.emit("soc.searched", {"store": a["registro"], "query": a["texto"], "sessions": hits.size(), "ids": ",".join(hits)})
	return r


static func _contain(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	s.actions[a["accion"]] = a["estado"] == "on"
	var acts := s.active(s.actions, Array(MockTraceStore.ACTIONS))
	c.emit("soc.contained", {"store": a["registro"], "action": a["accion"], "enabled": a["estado"] == "on", "actions": acts})
	var what := {
		"apagar-agente": "el asistente deja de responder a todo el taller",
		"cuarentena-fuente": "%s sale del índice de documentos" % s.data["poisoned_source"],
		"bloquear-salida": "http_get y enviar_correo solo pueden ir a: %s" % ", ".join(s.data["allowed_domains"]),
		"notificar-dpd": "el delegado de protección de datos recibe el informe para evaluar la notificación a la autoridad",
	}
	return CommandResult.new().line("✓ %s → %s: %s" % [a["accion"], "activada" if a["estado"] == "on" else "desactivada", what[a["accion"]]], "ok")


static func _retest(c: CommandContext, a: Dictionary) -> CommandResult:
	var s: MockTraceStore = c.world.traces[a["registro"]]
	var res := s.retest()
	var acts := s.active(s.actions, Array(MockTraceStore.ACTIONS))
	var r := CommandResult.new()
	r.line("Retest · contención: %s" % acts, "accent")
	var rows: Array = []
	for at: Array in res["attacks"]:
		rows.append([at[0], at[1], "✗ ÉXITO" if at[2] else "· frenado"])
	r.table(PackedStringArray(["ataque", "escenario", "resultado"]), rows)
	rows = []
	for t: Array in res["tasks"]:
		rows.append(["✓" if t[1] else "✗", t[0]])
	r.table(PackedStringArray(["", "tarea legítima"]), rows)
	r.line("Ataques con éxito: %d / %d · tareas correctas: %.2f" % [res["successes"], res["total"], res["pass_rate"]], "ok" if res["successes"] == 0 and res["pass_rate"] == 1.0 else "warn")
	if not res["notified"]:
		r.line("Pendiente: hubo datos personales de clientes enviados fuera (S04, S07). Nadie lo ha notificado todavía.", "warn")
	c.emit("soc.retest", {"store": a["registro"], "successes": res["successes"], "total": res["total"], "success_rate": float(res["successes"]) / res["total"],
		"pass_rate": res["pass_rate"], "actions": acts, "notified": res["notified"]})
	return r
