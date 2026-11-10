class_name AuditCommands
extends RefCounted
## E3 · Gobernanza y auditoría profesional: FRIA y EIPD, auditoría por muestreo con evidencias,
## no conformidades e informe con rúbrica y seguimiento (laboratorio).


static func register(reg: CommandRegistry) -> void:
	var a_arg := func() -> CommandSignature: return CommandSignature.new().pos("auditoria", "expediente de auditoría", "audit")
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "gobernanza").with_signature(sig))
	add.call("audit open", "Abre el expediente de Ayuda-Valle: evaluaciones de impacto, controles, evidencias e informe.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _open(c, a),
		CommandSignature.new().pos("nombre", "nombre del expediente").example("audit open valle"))
	# E3-01
	add.call("audit cases", "Cuatro sistemas de alto riesgo: ¿exigen FRIA (AI Act, art. 27) y EIPD (RGPD, art. 35)?",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _cases(c, a), a_arg.call())
	add.call("audit duty", "Decide si un caso exige FRIA y si exige EIPD.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _duty(c, a),
		a_arg.call().pos("caso", "id del caso").pos("fria", "¿exige FRIA?", "string", true, ["si", "sí", "no"]).pos("eipd", "¿exige EIPD?", "string", true, ["si", "sí", "no"]).example("audit duty valle agua-valle no no"))
	add.call("audit elements", "Elementos de las dos evaluaciones, para decidir a cuál pertenece cada uno.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _elements(c, a), a_arg.call())
	add.call("audit place", "Coloca un elemento en la FRIA, en la EIPD o en ambas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _place(c, a),
		a_arg.call().pos("elemento", "E1 … E10").pos("evaluacion", "fria, eipd o ambas", "string", true, Array(MockAudit.WHERE)).example("audit place valle E3 fria"))
	add.call("audit roles", "Quién hace qué en las dos evaluaciones: tareas y actores.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _roles(c, a), a_arg.call())
	add.call("audit assign", "Asigna una tarea a un actor.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _assign(c, a),
		a_arg.call().pos("tarea", "T1 … T6").pos("actor", "id del actor").example("audit assign valle T3 dpd"))
	add.call("audit timeline", "Cuándo es exigible cada evaluación (fechas verificadas en EUR-Lex).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _timeline(c, a), a_arg.call())
	# E3-02
	add.call("audit controls", "Universo de controles de la auditoría (subcategorías del NIST AI RMF adoptadas en la política POL-IA).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _controls(c, a), a_arg.call())
	add.call("audit sample", "Fija la muestra de controles: una lista de ids o --random n (semilla 42).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _sample(c, a),
		a_arg.call().pos("controles", "ids de los controles", "rest", false).opt("random", "n.º de controles elegidos al azar", "int").example("audit sample valle C01 C05 C07").example("audit sample valle --random 6"))
	add.call("audit plan", "Comprueba el plan: cobertura por función, controles de riesgo alto y tamaño máximo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _plan(c, a), a_arg.call())
	add.call("audit evidence", "Evidencia recogida para un control de la muestra.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _evidence(c, a), a_arg.call().pos("control", "C01 … C12"))
	add.call("audit records", "Muestra aleatoria (semilla 42) de n expedientes de un control.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _records(c, a),
		a_arg.call().pos("control", "control con expedientes").pos("n", "tamaño de la muestra", "int").example("audit records valle C10 10"))
	add.call("audit rate", "Clasifica un control auditado: conforme, nc-mayor, nc-menor u observacion.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _rate(c, a),
		a_arg.call().pos("control", "C01 … C12").pos("clase", "clasificación", "string", true, Array(MockAudit.RATINGS)).example("audit rate valle C07 conforme"))
	# E3-03
	add.call("audit rubric", "Rúbrica del informe de auditoría.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _rubric(c, a), a_arg.call())
	add.call("audit findings", "Hallazgos del informe y las opciones de redacción de cada campo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _findings(c, a), a_arg.call().pos("hallazgo", "H1, H2, H3 o informe", "string", false))
	add.call("audit draft", "Elige la redacción (A, B o C) de un campo de un hallazgo o del informe.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _draft(c, a),
		a_arg.call().pos("hallazgo", "H1, H2, H3 o informe").pos("campo", "campo").pos("opcion", "A, B o C", "string", true, ["A", "B", "C", "a", "b", "c"]).example("audit draft valle H2 criterio C"))
	add.call("audit report", "Genera el informe y lo corrige con la rúbrica.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _report(c, a), a_arg.call())
	add.call("audit followup", "Lo que la organización ha enviado para cerrar un hallazgo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _followup(c, a), a_arg.call().pos("hallazgo", "H1, H2 o H3"))
	add.call("audit close", "Cierra un hallazgo si la evidencia de corrección lo permite.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _close(c, a), a_arg.call().pos("hallazgo", "H1, H2 o H3"))


static func _x(c: CommandContext, a: Dictionary) -> MockAudit:
	return c.world.audits[a["auditoria"]]


static func _yes(v: String) -> bool:
	return v != "no"


static func _open(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := MockAudit.create(a["nombre"])
	c.world.audits[a["nombre"]] = x
	c.emit("audit.opened", {"audit": a["nombre"]})
	var s: Dictionary = x.data["system"]
	var r := CommandResult.new().line("✓ expediente %s abierto: %s, de %s (proveedor: %s)." % [a["nombre"], s["name"], s["deployer"], s["provider"]], "ok")
	r.line(s["text"], "data")
	r.line("Clasificación: " + s["classification"], "data")
	r.line("⚗ Organización, documentos y cifras ficticios; artículos, fechas y subcategorías del NIST reales (consultados el 2026-11-10). No es asesoramiento jurídico.", "muted")
	r.line("Siguiente: audit cases %s" % a["nombre"], "muted")
	return r


static func _cases(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var rows: Array = []
	for k: Dictionary in x.data["cases"]:
		var d: Dictionary = x.duties.get(k["id"], {})
		rows.append([k["id"], k["text"], "—" if d.is_empty() else ("sí" if d["fria"] else "no"), "—" if d.is_empty() else ("sí" if d["eipd"] else "no")])
	var r := CommandResult.new()
	r.line("FRIA (AI Act, art. 27): la hacen los responsables del despliegue que sean organismos de Derecho público o entidades privadas que prestan servicios públicos, y quienes desplieguen sistemas del anexo III, 5.b (solvencia) o 5.c (seguros de vida y salud). Excepción: el anexo III, punto 2 (infraestructuras críticas).", "accent")
	r.line("EIPD (RGPD, art. 35): la hace el responsable del tratamiento cuando un tratamiento de datos personales probablemente entrañe un alto riesgo para los derechos y libertades; el art. 35.3 da tres casos en los que siempre hace falta.", "accent")
	r.table(PackedStringArray(["caso", "descripción", "FRIA", "EIPD"]), rows)
	r.line("Decide: audit duty %s <caso> <si|no> <si|no>" % a["auditoria"], "muted")
	return r


static func _duty(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var k := x.case_of(a["caso"])
	if k.is_empty():
		return CommandResult.error("No existe el caso '%s'. Opciones: %s" % [a["caso"], ", ".join(MockAudit.ids(x.data["cases"]))])
	var ok := x.set_duty(k["id"], _yes(a["fria"]), _yes(a["eipd"]))
	var r := CommandResult.new()
	if ok:
		r.line("✓ %s · %s" % [k["id"], k["why"]], "ok")
	else:
		r.line("✗ %s: no encaja. Mira quién despliega (¿público o privado?), qué punto del anexo III es y si trata datos personales." % k["id"], "warn")
	r.line("Bien decididos: %d/%d" % [x.correct_duties(), x.data["cases"].size()], "muted")
	c.emit("audit.duty", {"audit": a["auditoria"], "case": k["id"], "ok": ok, "correct": x.correct_duties()})
	return r


static func _elements(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var rows: Array = []
	for e: Dictionary in x.data["elements"]:
		rows.append([e["id"], e["text"], x.placed.get(e["id"], "—")])
	var r := CommandResult.new()
	r.line("Borrador de Ayuda-Valle: cada elemento pertenece a la FRIA (AI Act, art. 27), a la EIPD (RGPD, arts. 35 y 36) o a ambas.", "accent")
	r.table(PackedStringArray(["id", "elemento", "evaluación"]), rows)
	r.line("Coloca: audit place %s <E#> <fria|eipd|ambas>" % a["auditoria"], "muted")
	return r


static func _place(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var e := x.element(a["elemento"])
	if e.is_empty():
		return CommandResult.error("No existe el elemento '%s'. Opciones: %s" % [a["elemento"], ", ".join(MockAudit.ids(x.data["elements"]))])
	var ok := x.place(e["id"], a["evaluacion"])
	var r := CommandResult.new()
	if ok:
		r.line("✓ %s → %s (%s)" % [e["id"], a["evaluacion"], e["basis"]], "ok")
	else:
		r.line("✗ %s → %s: no. ¿Habla de datos personales y de su tratamiento, de derechos fundamentales y del uso del sistema, o de las dos cosas?" % [e["id"], a["evaluacion"]], "warn")
	r.line("Bien colocados: %d/%d" % [x.correct_placements(), x.data["elements"].size()], "muted")
	c.emit("audit.placed", {"audit": a["auditoria"], "element": e["id"], "ok": ok, "correct": x.correct_placements()})
	return r


static func _roles(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var r := CommandResult.new()
	r.line("Actores", "accent")
	for ac: Dictionary in x.data["actors"]:
		r.line("  %s · %s" % [ac["id"], ac["text"]], "data")
	var rows: Array = []
	for t: Dictionary in x.data["tasks"]:
		rows.append([t["id"], t["text"], x.assigned.get(t["id"], "—")])
	r.table(PackedStringArray(["tarea", "qué", "actor"]), rows)
	r.line("Asigna: audit assign %s <T#> <actor>" % a["auditoria"], "muted")
	return r


static func _assign(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var t := x.task(a["tarea"])
	if t.is_empty():
		return CommandResult.error("No existe la tarea '%s'. Opciones: %s" % [a["tarea"], ", ".join(MockAudit.ids(x.data["tasks"]))])
	if x.actor(a["actor"]).is_empty():
		return CommandResult.error("No existe el actor '%s'. Opciones: %s" % [a["actor"], ", ".join(MockAudit.ids(x.data["actors"]))])
	var ok := x.assign(t["id"], String(a["actor"]).to_lower())
	var r := CommandResult.new()
	if ok:
		r.line("✓ %s → %s (%s)" % [t["id"], t["actor"], t["basis"]], "ok")
	else:
		r.line("✗ %s → %s: no. Distingue quién usa el sistema, quién lo fabrica, quién asesora y quién supervisa." % [t["id"], a["actor"]], "warn")
	r.line("Bien asignadas: %d/%d" % [x.correct_assignments(), x.data["tasks"].size()], "muted")
	c.emit("audit.assigned", {"audit": a["auditoria"], "task": t["id"], "ok": ok, "correct": x.correct_assignments()})
	return r


static func _timeline(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var r := CommandResult.new().line("Calendario (consultado el 2026-11-10; compruébalo siempre en EUR-Lex)", "accent")
	r.table(PackedStringArray(["fecha", "qué pasa"]), x.data["timeline"])
	r.line("Ayuda-Valle es un sistema nuevo: el periodo transitorio del art. 111.2 para sistemas de autoridades públicas ya introducidos en el mercado (hasta el 2030-08-02) no se aplica.", "muted")
	c.emit("audit.timeline", {"audit": a["auditoria"]})
	return r


static func _controls(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var rows: Array = []
	for k: Dictionary in x.data["controls"]:
		rows.append([k["id"], k["function"], k["ref"], k["risk"], k["text"], "✓" if k["id"] in x.sample else "", x.ratings.get(k["id"], "—")])
	var r := CommandResult.new()
	var au: Dictionary = x.data["audit"]
	r.line("Auditoría interna de Ayuda-Valle · periodo %s · criterios: %s" % [au["period"], au["criteria"]], "accent")
	r.table(PackedStringArray(["id", "función", "NIST AI RMF", "riesgo", "resultado esperado", "muestra", "clase"]), rows)
	r.line("Tiempo para %d controles como máximo. Muestra: audit sample %s <C## …> · o --random <n>" % [au["max_sample"], a["auditoria"]], "muted")
	return r


static func _sample(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var mode := "manual"
	if a["random"] != null:
		mode = "random"
		x.set_sample(x.random_sample(int(a["random"])))
	elif a["controles"] != null:
		var unknown := PackedStringArray()
		for id: String in String(a["controles"]).replace(",", " ").split(" ", false):
			if x.control(id).is_empty():
				unknown.append(id)
		if not unknown.is_empty():
			return CommandResult.error("No existen los controles: %s. Opciones: %s" % [", ".join(unknown), ", ".join(x.control_ids())])
		x.set_sample(String(a["controles"]).replace(",", " ").split(" ", false))
	else:
		return CommandResult.error("Indica los controles (audit sample %s C01 C05 …) o --random <n>." % a["auditoria"])
	var p := x.plan()
	c.emit("audit.sampled", {"audit": a["auditoria"], "mode": mode, "size": p["size"], "valid": p["valid"]})
	return CommandResult.new().line("✓ muestra (%s): %s" % [mode, ", ".join(x.sample)], "ok").line("Compruébala: audit plan %s" % a["auditoria"], "muted")


static func _plan(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var p := x.plan()
	var r := CommandResult.new()
	r.line("Plan: %d de %d controles (máximo %d) · cobertura %d %%" % [p["size"], p["total"], p["max"], roundi(100.0 * p["size"] / p["total"])], "accent")
	var rows: Array = []
	for f in MockAudit.FUNCTIONS:
		rows.append([f, p["by_function"][f]])
	r.table(PackedStringArray(["función", "controles en la muestra"]), rows)
	r.line("Riesgo alto en la muestra: %d/%d" % [p["alta_in"], p["alta_total"]], "data")
	if p["missing_alta"] != "":
		r.line("✗ faltan controles de riesgo alto: %s. Un muestreo al azar no garantiza ver lo que más importa." % p["missing_alta"], "warn")
	if p["uncovered"] != "":
		r.line("✗ funciones sin ningún control: %s" % p["uncovered"], "warn")
	if p["size"] > p["max"]:
		r.line("✗ la muestra no cabe en el tiempo de la auditoría", "warn")
	r.line("✓ plan válido: basado en el riesgo y con todas las funciones." if p["valid"] else "Plan no válido.", "ok" if p["valid"] else "warn")
	c.emit("audit.plan", {"audit": a["auditoria"], "valid": p["valid"], "size": p["size"], "alta_in": p["alta_in"]})
	return r


static func _evidence(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var k := x.control(a["control"])
	if k.is_empty():
		return CommandResult.error("No existe el control '%s'. Opciones: %s" % [a["control"], ", ".join(x.control_ids())])
	if not k["id"] in x.sample:
		return CommandResult.error("%s no está en tu muestra. Cambia la muestra con audit sample." % k["id"])
	x.seen_evidence[k["id"]] = true
	var r := CommandResult.new().line("%s · %s (%s) · %s" % [k["id"], k["ref"], k["function"], k["text"]], "accent")
	for e: String in k["evidence"]:
		r.line("  · " + e, "data")
	r.line("Clasifica: audit rate %s %s <conforme|nc-mayor|nc-menor|observacion>" % [a["auditoria"], k["id"]], "muted")
	c.emit("audit.evidence", {"audit": a["auditoria"], "control": k["id"]})
	return r


static func _records(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var k := x.control(a["control"])
	if k.is_empty() or not k.has("records"):
		return CommandResult.error("'%s' no tiene expedientes que muestrear (solo C10)." % a["control"])
	if not k["id"] in x.sample:
		return CommandResult.error("%s no está en tu muestra." % k["id"])
	var n := int(a["n"])
	if n < 1 or n > int(k["records"]):
		return CommandResult.error("n debe estar entre 1 y %d." % k["records"])
	var s := x.sample_records(k["id"], n)
	var r := CommandResult.new().line("Muestra aleatoria (semilla %d) de %d de los %d expedientes denegados" % [MockAudit.SEED, n, k["records"]], "accent")
	r.line("Revisados: " + ", ".join(PackedStringArray(s["ids"])), "data")
	r.line("Sin firma de revisión humana: %d (%s)" % [s["failing"].size(), ", ".join(PackedStringArray(s["failing"])) if not s["failing"].is_empty() else "ninguno"], "warn" if not s["failing"].is_empty() else "ok")
	if n < MockAudit.MIN_RECORDS:
		r.line("Con menos de %d expedientes la muestra es demasiado pequeña para concluir." % MockAudit.MIN_RECORDS, "warn")
	r.line("Regla de esta auditoría: %s." % x.data["audit"]["systematic_rule"], "muted")
	c.emit("audit.records", {"audit": a["auditoria"], "control": k["id"], "n": n, "fails": s["failing"].size()})
	return r


static func _rate(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var k := x.control(a["control"])
	if k.is_empty():
		return CommandResult.error("No existe el control '%s'. Opciones: %s" % [a["control"], ", ".join(x.control_ids())])
	var why := x.can_rate(k["id"])
	if why != "":
		c.emit("audit.rate_refused", {"audit": a["auditoria"], "control": k["id"]})
		return CommandResult.new().line("✋ " + why, "warn")
	var ok := x.rate(k["id"], a["clase"])
	var s := x.rating_score()
	var r := CommandResult.new()
	if ok:
		r.line("✓ %s: %s · %s" % [k["id"], a["clase"], k["why"]], "ok")
	else:
		r.line("✗ %s: «%s» no encaja. ¿Existe el control? ¿Falla una vez o de forma repetida? ¿Hay ya un incumplimiento o solo un riesgo?" % [k["id"], a["clase"]], "warn")
	r.line("Muestra: %d bien · %d mal · %d sin clasificar" % [s["ok"], s["wrong"], s["pending"]], "muted")
	c.emit("audit.rated", {"audit": a["auditoria"], "control": k["id"], "rating": a["clase"], "ok": ok, "alta_ok": s["alta_ok"], "wrong": s["wrong"], "pending": s["pending"]})
	return r


static func _rubric(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var r := CommandResult.new().line("Rúbrica del informe: cada hallazgo tiene condición (lo que se ha visto) y cinco campos; el informe, alcance y conclusión.", "accent")
	for row: Array in x.data["rubric"]:
		r.line("  %s · %s" % [row[0], row[1]], "data")
	c.emit("audit.rubric", {"audit": a["auditoria"]})
	return r


static func _findings(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var r := CommandResult.new()
	var target: Variant = a["hallazgo"]
	if target == null:
		for f: Dictionary in x.data["findings"]:
			r.line("%s · %s · control %s · campos bien: %d/%d" % [f["id"], f["rating"], f["control"], x.finding_ok(f["id"]), MockAudit.FIELDS.size()], "data")
			r.line("    " + f["condition"], "muted")
		r.line("Detalle y opciones: audit findings %s <H#|informe>" % a["auditoria"], "muted")
		return r
	var fields: Dictionary
	if String(target).to_lower() == "informe":
		fields = x.data["report_fields"]
		r.line("Informe · campos generales", "accent")
	else:
		var f := x.finding(target)
		if f.is_empty():
			return CommandResult.error("No existe el hallazgo '%s'. Opciones: H1, H2, H3, informe" % target)
		fields = f["fields"]
		r.line("%s · %s · %s" % [f["id"], f["rating"], f["condition"]], "accent")
	var key := "informe" if String(target).to_lower() == "informe" else String(x.finding(target)["id"])
	for field: String in fields:
		var chosen: String = x.drafts.get(key, {}).get(field, "—")
		r.line("%s (elegida: %s)" % [field, chosen], "data")
		for letter: String in fields[field]["options"]:
			r.line("    %s) %s" % [letter, fields[field]["options"][letter]], "normal")
	r.line("Elige: audit draft %s %s <campo> <A|B|C>" % [a["auditoria"], key], "muted")
	return r


static func _draft(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var target := String(a["hallazgo"])
	var is_report := target.to_lower() == "informe"
	if not is_report and x.finding(target).is_empty():
		return CommandResult.error("No existe el hallazgo '%s'. Opciones: H1, H2, H3, informe" % target)
	var valid: Array = Array(MockAudit.REPORT_FIELDS) if is_report else Array(MockAudit.FIELDS)
	if not a["campo"] in valid:
		return CommandResult.error("Campo no válido para %s. Opciones: %s" % [target, ", ".join(PackedStringArray(valid))])
	var ok := x.draft(target, a["campo"], a["opcion"])
	var key := "informe" if is_report else String(x.finding(target)["id"])
	var r := CommandResult.new().line("✓ %s.%s = %s" % [key, a["campo"], String(a["opcion"]).to_upper()], "ok")
	r.line("La rúbrica lo corrige al generar el informe: audit report %s" % a["auditoria"], "muted")
	var findings_ok := 0
	for f: Dictionary in x.data["findings"]:
		findings_ok += 1 if x.finding_ok(f["id"]) == MockAudit.FIELDS.size() else 0
	c.emit("audit.drafted", {"audit": a["auditoria"], "target": key, "field": a["campo"], "ok": ok,
		"finding_ok": 0 if is_report else x.finding_ok(key), "findings_ok": findings_ok})
	return r


static func _report(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var rep := x.report()
	var r := CommandResult.new().line("INFORME DE AUDITORÍA INTERNA · Ayuda-Valle · %s" % x.data["audit"]["period"], "accent")
	var order := {"nc-mayor": 0, "nc-menor": 1, "observacion": 2}
	var fs: Array = x.data["findings"].duplicate()
	fs.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return "%d%s" % [order[p["rating"]], p["id"]] < "%d%s" % [order[q["rating"]], q["id"]])
	for f: Dictionary in fs:
		r.line("%s · %s · %s" % [f["id"], f["rating"], f["condition"]], "data")
		for field in MockAudit.FIELDS:
			var letter: String = x.drafts.get(f["id"], {}).get(field, "")
			var good: bool = letter == f["fields"][field]["ok"]
			r.line("   %s %s: %s" % ["✓" if good else "✗", field, f["fields"][field]["options"][letter] if letter != "" else "(sin redactar)"], "ok" if good else "warn")
	for field in MockAudit.REPORT_FIELDS:
		var letter: String = x.drafts.get("informe", {}).get(field, "")
		var good: bool = letter == x.data["report_fields"][field]["ok"]
		r.line("%s %s: %s" % ["✓" if good else "✗", field, x.data["report_fields"][field]["options"][letter] if letter != "" else "(sin redactar)"], "ok" if good else "warn")
	r.line("Rúbrica: %d/%d · hallazgos completos: %d/%d" % [rep["ok"], rep["total"], rep["findings_ok"], x.data["findings"].size()], "ok" if rep["passed"] else "warn")
	if not rep["passed"]:
		r.line("Revisa con audit rubric %s: %s" % [a["auditoria"], ", ".join(rep["failed"])], "muted")
	c.emit("audit.report", {"audit": a["auditoria"], "score": rep["ok"], "total": rep["total"], "findings_ok": rep["findings_ok"], "passed": rep["passed"]})
	return r


static func _followup(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var f := x.finding(a["hallazgo"])
	if f.is_empty():
		return CommandResult.error("No existe el hallazgo '%s'. Opciones: H1, H2, H3" % a["hallazgo"])
	x.followups_seen[f["id"]] = true
	c.emit("audit.followup", {"audit": a["auditoria"], "finding": f["id"]})
	return CommandResult.new().line("Seguimiento de %s (noviembre de 2028)" % f["id"], "accent").line(f["followup"]["text"], "data") \
		.line("¿Hay evidencia de que está corregido, o solo un plan? audit close %s %s" % [a["auditoria"], f["id"]], "muted")


static func _close(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _x(c, a)
	var f := x.finding(a["hallazgo"])
	if f.is_empty():
		return CommandResult.error("No existe el hallazgo '%s'. Opciones: H1, H2, H3" % a["hallazgo"])
	var why := x.close(f["id"])
	if why != "":
		c.emit("audit.close_refused", {"audit": a["auditoria"], "finding": f["id"]})
		return CommandResult.new().line("✋ " + why, "warn")
	c.emit("audit.closed", {"audit": a["auditoria"], "finding": f["id"], "closed": x.closed.size()})
	return CommandResult.new().line("✓ %s cerrado con evidencia. Cerrados: %d/%d" % [f["id"], x.closed.size(), x.data["findings"].size()], "ok")
