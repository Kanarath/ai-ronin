class_name EngagementCommands
extends RefCounted
## C5 · AI Red Team Assessment: encargo completo sobre la Forja del Norte (ficticia).


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("engagement start", "Abre el encargo de red team: cliente, ventana y reglas de enfrentamiento.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _start(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del encargo").example("engagement start final")))
	reg.register(Command.new("engagement recon", "Inventario de activos de IA del cliente: exposición, alcance y cómo reproducirlos en el laboratorio.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _recon(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement")))
	reg.register(Command.new("engagement scope", "¿Se puede probar este activo? Lo comprueba contra el contrato.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _scope(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement").pos("activo", "A-01 … A-07").example("engagement scope final A-06")))
	reg.register(Command.new("engagement bind", "Vincula un activo en alcance con su copia en el laboratorio (bot, rag, agente, host MCP o pipeline).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _bind(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement").pos("activo", "A-01 … A-05").pos("objeto", "nombre del objeto del laboratorio").example("engagement bind final A-01 kuro")))
	reg.register(Command.new("engagement threat", "Añade una amenaza al modelo de amenazas: activo y categoría OWASP.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _threat(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement").pos("activo", "A-01 … A-05").pos("categoria", "LLM01…LLM10 o ASI01…ASI10").example("engagement threat final A-01 LLM07")))
	reg.register(Command.new("engagement finding", "Registra un hallazgo si hay evidencia: una batería con éxitos sobre el objeto vinculado.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _finding(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement").pos("activo", "A-01 … A-05").pos("categoria", "categoría OWASP").example("engagement finding final A-01 LLM07")))
	reg.register(Command.new("engagement retest", "Comprueba cada hallazgo: batería posterior a 0 éxitos y tareas legítimas a 1,0.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _retest(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement")))
	reg.register(Command.new("engagement summary", "Resumen ejecutivo del encargo: alcance, amenazas, hallazgos y estado.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _summary(c, a), "encargo")
		.with_signature(CommandSignature.new().pos("encargo", "encargo", "engagement")))


static func _start(c: CommandContext, a: Dictionary) -> CommandResult:
	var e := MockEngagement.create(a["nombre"])
	c.world.engagements[a["nombre"]] = e
	var r := CommandResult.new()
	r.line("✓ encargo %s · cliente: %s" % [a["nombre"], e.data["client"]], "ok")
	r.line("Autoriza: %s · ventana: %s" % [e.data["sponsor"], e.data["window"]], "data")
	r.line("Reglas de enfrentamiento:", "accent")
	for rule: String in e.data["rules"]:
		r.line("  · " + rule, "data")
	r.line("⚗ Empresa y sistemas ficticios; todo se prueba sobre las simulaciones del Dojo. Siguiente: engagement recon %s" % a["nombre"], "muted")
	c.emit("engagement.created", {"engagement": a["nombre"]})
	return r


static func _recon(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	var rows: Array = []
	var copies := PackedStringArray()
	for x: Dictionary in e.data["assets"]:
		# La exposición (el texto más largo) va al final para que la tabla no se descuadre.
		rows.append([x["id"], x["name"], "sí" if x["in_scope"] else "NO", x["exposure"]])
		if x["lab"] != "":
			copies.append("  %s → %s" % [x["id"], x["lab"]])
	var r := CommandResult.new()
	r.line("Activos de IA de %s:" % e.data["client"], "accent")
	r.lines_from(TextUtils.table_wrapped(PackedStringArray(["id", "activo", "en alcance", "exposición"]), rows, 90), "data")
	if not copies.is_empty():
		r.line("Copia en el laboratorio de cada activo en alcance:", "muted")
		r.lines_from(copies, "data")
	r.line("En alcance: %d de %d. Antes de tocar nada: engagement scope %s <activo>" % [e.in_scope_count(), rows.size(), a["encargo"]], "muted")
	c.emit("engagement.recon", {"engagement": a["encargo"], "assets": rows.size(), "in_scope": e.in_scope_count()})
	return r


static func _need_asset(e: MockEngagement, id: String) -> String:
	return "" if not e.asset(id).is_empty() else "No existe el activo '%s'. Opciones: %s" % [id, ", ".join(e.asset_ids())]


static func _scope(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	var err := _need_asset(e, a["activo"])
	if err != "":
		return CommandResult.error(err)
	var x := e.asset(a["activo"])
	var r := CommandResult.new()
	if x["in_scope"]:
		r.line("✓ %s (%s) está en alcance. Se prueba en su copia de laboratorio: %s" % [x["id"], x["name"], x["lab"]], "ok")
	else:
		r.line("✋ %s (%s) está FUERA de alcance: %s." % [x["id"], x["name"], x["exposure"]], "warn")
		r.line("Si una prueba lo necesitara, se para y se pide autorización por escrito a quien pueda darla.", "muted")
	c.emit("engagement.scoped", {"engagement": a["encargo"], "asset": x["id"], "in_scope": x["in_scope"]})
	return r


static func _bind(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	var err := _need_asset(e, a["activo"])
	if err != "":
		return CommandResult.error(err)
	var x := e.asset(a["activo"])
	if not x["in_scope"]:
		c.emit("engagement.out_of_scope", {"engagement": a["encargo"], "asset": x["id"]})
		return CommandResult.new().line("✋ %s está fuera de alcance: no se vincula ni se prueba." % x["id"], "warn")
	if not c.world.store_of(x["kind"]).has(a["objeto"]):
		return CommandResult.error("No hay ningún %s llamado '%s' en el laboratorio. Créalo con: %s" % [SimWorld.KIND_NAMES[x["kind"]], a["objeto"], x["lab"]])
	e.bindings[x["id"]] = a["objeto"]
	c.emit("engagement.bound", {"engagement": a["encargo"], "asset": x["id"], "object": a["objeto"], "bound": e.bindings.size()})
	return CommandResult.new().line("✓ %s → %s %s (%d de %d activos vinculados)" % [x["id"], SimWorld.KIND_NAMES[x["kind"]], a["objeto"], e.bindings.size(), e.in_scope_count()], "ok")


static func _threat(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	var err := _need_asset(e, a["activo"])
	if err != "":
		return CommandResult.error(err)
	var cat := String(a["categoria"]).to_upper()
	if RegEx.create_from_string("^(LLM(0[1-9]|10)|ASI(0[1-9]|10))$").search(cat) == null:
		return CommandResult.error("Categoría no válida: usa LLM01…LLM10 (OWASP LLM 2025) o ASI01…ASI10 (OWASP Agentic 2026).")
	var x := e.asset(a["activo"])
	if not x["in_scope"]:
		return CommandResult.new().line("✋ %s está fuera de alcance: no entra en el modelo de amenazas de este encargo." % x["id"], "warn")
	var relevant := e.add_threat(x["id"], cat)
	var r := CommandResult.new()
	if relevant:
		r.line("✓ %s · %s añadida al modelo de amenazas." % [x["id"], cat], "ok")
	else:
		r.line("· %s · %s añadida, pero con lo que sabes de este activo es poco probable. Encajan mejor: %s" % [x["id"], cat, ", ".join(x["threats"])], "warn")
	r.line("Activos con al menos una amenaza que encaja: %d de %d" % [e.covered_assets(), e.in_scope_count()], "muted")
	c.emit("engagement.threat", {"engagement": a["encargo"], "asset": x["id"], "category": cat, "relevant": relevant, "covered": e.covered_assets()})
	return r


static func _finding(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	var err := _need_asset(e, a["activo"])
	if err != "":
		return CommandResult.error(err)
	var x := e.asset(a["activo"])
	if not x["in_scope"]:
		return CommandResult.new().line("✋ %s está fuera de alcance." % x["id"], "warn")
	var cat := String(a["categoria"]).to_upper()
	var why := e.add_finding(c.shell, x["id"], cat)
	if why != "":
		c.emit("engagement.finding_rejected", {"engagement": a["encargo"], "asset": x["id"], "category": cat})
		return CommandResult.new().line("✋ Hallazgo rechazado: " + why, "warn")
	var f: Dictionary = e.findings[-1]
	c.emit("engagement.finding", {"engagement": a["encargo"], "asset": x["id"], "category": cat, "baseline": f["baseline"],
		"findings": e.findings.size(), "assets": e.findings_assets()})
	return CommandResult.new().line("✓ hallazgo %s en %s · evidencia: %d / %d ataques con éxito sobre %s (%d hallazgos en %d activos)" % [cat, x["id"], f["baseline"], f["total"], f["object"], e.findings.size(), e.findings_assets()], "ok")


static func _retest(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	if e.findings.is_empty():
		return CommandResult.error("No hay hallazgos que comprobar: engagement finding %s <activo> <categoría>" % a["encargo"])
	var rows := e.retest(c.shell)
	var data: Array = []
	var fixed := 0
	var broken := 0
	for row in rows:
		fixed += 1 if row["status"] == "corregido" else 0
		broken += 1 if row["now"] == 0 and row["pass_rate"] >= 0.0 and row["pass_rate"] < 0.999 else 0
		data.append([row["asset"], row["owasp"], "%d/%d" % [row["baseline"], row["total"]], "—" if row["now"] < 0 else str(row["now"]),
			"—" if row["pass_rate"] < 0 else "%.2f" % row["pass_rate"], ("✓ " if row["status"] == "corregido" else "✗ ") + row["status"], row["why"]])
	var r := CommandResult.new()
	r.line("Retest del encargo %s:" % a["encargo"], "accent")
	r.table(PackedStringArray(["activo", "categoría", "antes", "ahora", "tareas", "estado", "motivo"]), data)
	r.line("Corregidos: %d de %d" % [fixed, rows.size()], "ok" if fixed == rows.size() else "warn")
	c.emit("engagement.retest", {"engagement": a["encargo"], "findings": rows.size(), "fixed": fixed, "open": rows.size() - fixed, "broken": broken, "all_fixed": fixed == rows.size()})
	return r


static func _summary(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: MockEngagement = c.world.engagements[a["encargo"]]
	var r := CommandResult.new()
	r.line("Resumen ejecutivo · %s · %s" % [e.data["client"], e.data["window"]], "accent")
	var n_threats := 0
	for id: String in e.threats:
		n_threats += e.threats[id].size()
	r.line("Alcance: %d activos de IA probados en laboratorio; %d fuera de alcance por contrato." % [e.in_scope_count(), e.data["assets"].size() - e.in_scope_count()], "data")
	# Cada misión empieza con un laboratorio nuevo: en C5-02 y C5-03 el modelo de amenazas de
	# C5-01 no está en este encargo. Con 0 amenazas no se presenta como un fallo.
	if n_threats > 0:
		r.line("Modelo de amenazas: %d amenazas; %d de %d activos cubiertos." % [n_threats, e.covered_assets(), e.in_scope_count()], "data")
	else:
		r.line("Modelo de amenazas: no registrado en este encargo (se construye con engagement threat, como en C5-01).", "muted")
	var fixed := 0
	var total_baseline := 0
	var worst := ""
	var worst_n := -1
	var rows: Array = e.retest(c.shell) if not e.findings.is_empty() else []
	for row: Dictionary in rows:
		fixed += 1 if row["status"] == "corregido" else 0
		total_baseline += int(row["baseline"])
		if int(row["baseline"]) > worst_n:
			worst_n = row["baseline"]
			worst = row["asset"]
		r.line("  %s %s · %s · %d ataques con éxito al inicio · %s" % ["✓" if row["status"] == "corregido" else "✗", row["asset"], row["owasp"], row["baseline"], row["status"]], "data")
	r.line("Hallazgos: %d en %d activos · corregidos y verificados: %d." % [e.findings.size(), e.findings_assets(), fixed], "ok" if fixed == e.findings.size() and fixed > 0 else "warn")
	if worst != "":
		r.line("Activo con más ataques con éxito al inicio: %s (%d)." % [worst, worst_n], "data")
	c.emit("engagement.summary", {"engagement": a["encargo"], "findings": e.findings.size(), "assets": e.findings_assets(), "fixed": fixed,
		"covered": e.covered_assets(), "worst": worst, "baseline_total": total_baseline, "all_fixed": fixed == e.findings.size() and fixed > 0})
	return r
