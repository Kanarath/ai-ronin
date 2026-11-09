class_name GovCommands
extends RefCounted
## O5 · Marcos y gobernanza: AI Act, NIST AI RMF e ISO/IEC 42001 aplicados a la forja (laboratorio).


static func register(reg: CommandRegistry) -> void:
	var g_arg := func() -> CommandSignature: return CommandSignature.new().pos("gobernanza", "carpeta de gobernanza", "gov")
	reg.register(Command.new("gov open", "Abre la carpeta de gobernanza de la forja: marcos, hallazgos, sistemas y riesgos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _open(c, a), "gobernanza")
		.with_signature(CommandSignature.new().pos("nombre", "nombre de la carpeta").example("gov open forja")))
	reg.register(Command.new("gov frameworks", "Compara los tres marcos: qué son, si obligan y si se certifican.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _frameworks(c, a), "gobernanza").with_signature(g_arg.call()))
	reg.register(Command.new("gov framework", "Detalle de un marco: qué es, qué NO es y cómo se estructura.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _framework(c, a), "gobernanza")
		.with_signature(g_arg.call().pos("marco", "ai-act, nist-ai-rmf o iso-42001", "string", true, ["ai-act", "nist-ai-rmf", "iso-42001"])))
	reg.register(Command.new("gov findings", "Hallazgos de gobernanza de la forja (de los arcos y del encargo C5).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _findings(c, a), "gobernanza").with_signature(g_arg.call()))
	reg.register(Command.new("gov map", "Asigna un hallazgo a una función del NIST AI RMF o a una cláusula de ISO/IEC 42001.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _map(c, a), "gobernanza")
		.with_signature(g_arg.call().pos("hallazgo", "F1 … F4").pos("marco", "nist o iso", "string", true, ["nist", "iso"]).pos("valor", "función (GOVERN…) o cláusula (4…10)").example("gov map forja F1 nist GOVERN")))
	reg.register(Command.new("gov systems", "Sistemas de IA de la forja (en uso o propuestos) para clasificarlos según el AI Act.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _systems(c, a), "gobernanza").with_signature(g_arg.call()))
	reg.register(Command.new("gov classify", "Clasifica un sistema según el AI Act: prohibido, alto, transparencia o minimo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _classify(c, a), "gobernanza")
		.with_signature(g_arg.call().pos("sistema", "id del sistema").pos("nivel", "nivel de riesgo", "string", true, Array(MockGovernance.LEVELS)).example("gov classify forja chatbot-atencion transparencia")))
	reg.register(Command.new("gov needs", "Necesidades del sistema de alto riesgo, para asignarlas a su artículo del AI Act.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _needs(c, a), "gobernanza").with_signature(g_arg.call()))
	reg.register(Command.new("gov require", "Asigna una necesidad a su artículo del AI Act (9, 10, 11, 12, 13, 14 o 15).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _require(c, a), "gobernanza")
		.with_signature(g_arg.call().pos("necesidad", "N1 … N4").pos("articulo", "número de artículo").example("gov require forja N2 12")))
	reg.register(Command.new("gov risks", "Registro de riesgos: probabilidad × impacto, tratamiento y riesgo residual frente al apetito.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _risks(c, a), "gobernanza").with_signature(g_arg.call()))
	reg.register(Command.new("gov treat", "Elige el tratamiento de un riesgo: mitigar, evitar o aceptar.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _treat(c, a), "gobernanza")
		.with_signature(g_arg.call().pos("riesgo", "R1 … R6").pos("tratamiento", "tratamiento", "string", true, Array(MockGovernance.TREATMENTS)).example("gov treat forja R1 mitigar")))


static func _g(c: CommandContext, a: Dictionary) -> MockGovernance:
	return c.world.governances[a["gobernanza"]]


static func _open(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.governances[a["nombre"]] = MockGovernance.create(a["nombre"])
	c.emit("gov.opened", {"gov": a["nombre"]})
	var r := CommandResult.new().line("✓ carpeta de gobernanza %s abierta: 3 marcos, 4 hallazgos, 4 sistemas y 6 riesgos." % a["nombre"], "ok")
	r.line("⚗ Empresa y cifras ficticias; artículos y fechas reales (consultados el 2026-11-09). No es asesoramiento jurídico.", "muted")
	r.line("Siguiente: gov frameworks %s" % a["nombre"], "muted")
	return r


static func _frameworks(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var rows: Array = []
	for f: Dictionary in g.data["frameworks"]:
		rows.append([f["id"], f["kind"], "sí" if f["mandatory"] else "no", "sí" if f["certifiable"] else "no", f["ref"]])
	var r := CommandResult.new()
	r.table(PackedStringArray(["marco", "qué es", "obliga", "se certifica", "referencia"]), rows)
	r.line("Detalle: gov framework %s <marco>" % a["gobernanza"], "muted")
	c.emit("gov.frameworks", {"gov": a["gobernanza"]})
	return r


static func _framework(c: CommandContext, a: Dictionary) -> CommandResult:
	var f := _g(c, a).framework(a["marco"])
	var r := CommandResult.new()
	r.line("%s · %s" % [f["name"], f["ref"]], "accent")
	r.line("Qué es: " + f["what"], "data")
	r.line("Qué NO es: " + f["not"], "warn")
	r.line("Estructura: " + f["structure"], "data")
	c.emit("gov.framework", {"gov": a["gobernanza"], "framework": f["id"]})
	return r


static func _findings(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var rows: Array = []
	for f: Dictionary in g.data["findings"]:
		rows.append([f["id"], f["text"], g.nist_map.get(f["id"], "—"), g.iso_map.get(f["id"], "—")])
	var r := CommandResult.new()
	r.table(PackedStringArray(["id", "hallazgo", "NIST", "ISO 42001"]), rows)
	r.line("Asígnalos: gov map %s <F#> nist <GOVERN|MAP|MEASURE|MANAGE> · gov map %s <F#> iso <4…10>" % [a["gobernanza"], a["gobernanza"]], "muted")
	return r


static func _map(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	if g.finding(a["hallazgo"]).is_empty():
		return CommandResult.error("No existe el hallazgo '%s'. Opciones: %s" % [a["hallazgo"], ", ".join(MockGovernance.ids(g.data["findings"]))])
	var v := String(a["valor"])
	if a["marco"] == "nist" and not v.to_upper() in MockGovernance.NIST:
		return CommandResult.error("Función del NIST AI RMF no válida. Opciones: GOVERN, MAP, MEASURE, MANAGE")
	if a["marco"] == "iso" and not v.split(".")[0] in ["4", "5", "6", "7", "8", "9", "10"]:
		return CommandResult.error("Cláusula de ISO/IEC 42001 no válida: usa 4 a 10 (las cláusulas con requisitos).")
	var ok := g.map_finding(a["hallazgo"], a["marco"], v)
	var s := g.mapping_score()
	var f := g.finding(a["hallazgo"])
	var r := CommandResult.new()
	if ok:
		r.line("✓ %s → %s %s" % [f["id"], a["marco"], v.to_upper()], "ok")
	else:
		r.line("✗ %s → %s %s: no encaja. Relee el hallazgo y la estructura del marco (gov framework)." % [f["id"], a["marco"], v.to_upper()], "warn")
	r.line("Bien asignados: NIST %d/%d · ISO %d/%d" % [s["nist_ok"], s["total"], s["iso_ok"], s["total"]], "muted")
	c.emit("gov.mapped", {"gov": a["gobernanza"], "finding": f["id"], "framework": a["marco"], "ok": ok, "nist_ok": s["nist_ok"], "iso_ok": s["iso_ok"], "total": s["total"]})
	return r


static func _systems(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var rows: Array = []
	for s: Dictionary in g.data["systems"]:
		rows.append([s["id"], s["text"], g.classified.get(s["id"], "—")])
	var r := CommandResult.new()
	r.table(PackedStringArray(["sistema", "descripción", "clasificación"]), rows)
	r.line("Niveles: prohibido (art. 5) · alto (art. 6 y anexo III) · transparencia (art. 50) · minimo.", "muted")
	return r


static func _classify(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var s := g.system(a["sistema"])
	if s.is_empty():
		return CommandResult.error("No existe el sistema '%s'. Opciones: %s" % [a["sistema"], ", ".join(MockGovernance.ids(g.data["systems"]))])
	g.classified[s["id"]] = a["nivel"]
	var ok: bool = a["nivel"] == s["level"]
	var r := CommandResult.new()
	if ok:
		r.line("✓ %s: %s · %s" % [s["id"], a["nivel"], s["why"]], "ok")
		if s["applies_from"] != "":
			r.line("Se aplica desde: %s (%s)" % [s["applies_from"], "ya en vigor" if s["applies_from"] <= "2026-11-09" else "todavía no, pero hay que prepararse"], "data")
	else:
		r.line("✗ %s: «%s» no encaja. Piensa en qué decide el sistema y sobre quién." % [s["id"], a["nivel"]], "warn")
	r.line("Bien clasificados: %d/%d" % [g.correct_classifications(), g.data["systems"].size()], "muted")
	c.emit("gov.classified", {"gov": a["gobernanza"], "system": s["id"], "level": a["nivel"], "ok": ok, "correct": g.correct_classifications()})
	return r


static func _needs(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var rows: Array = []
	for x: Dictionary in g.data["needs"]:
		rows.append([x["id"], x["text"], g.required.get(x["id"], "—")])
	var r := CommandResult.new()
	r.line("Requisitos del cribado de CV (alto riesgo). Artículos: 9 gestión de riesgos · 10 datos y gobernanza de datos · 11 documentación técnica · 12 registros · 13 transparencia e información a los responsables del despliegue · 14 supervisión humana · 15 precisión, solidez y ciberseguridad", "accent")
	r.table(PackedStringArray(["id", "necesidad", "artículo"]), rows)
	return r


static func _require(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var n := g.need(a["necesidad"])
	if n.is_empty():
		return CommandResult.error("No existe la necesidad '%s'. Opciones: %s" % [a["necesidad"], ", ".join(MockGovernance.ids(g.data["needs"]))])
	var art := String(a["articulo"]).trim_prefix("art.").trim_prefix("art").strip_edges()
	g.required[n["id"]] = art
	var ok: bool = art == n["article"]
	var r := CommandResult.new().line(("✓ %s → art. %s" if ok else "✗ %s → art. %s: no es ese.") % [n["id"], art], "ok" if ok else "warn")
	r.line("Bien asignadas: %d/%d" % [g.correct_requirements(), g.data["needs"].size()], "muted")
	c.emit("gov.required", {"gov": a["gobernanza"], "need": n["id"], "article": art, "ok": ok, "correct": g.correct_requirements()})
	return r


static func _risks(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var reg := g.register()
	var r := CommandResult.new()
	r.line("Registro de riesgos · riesgo = probabilidad × impacto (1–5 cada uno) · apetito: ≤ %d" % reg["appetite"], "accent")
	for x: Dictionary in g.data["risks"]:
		r.line("%s · %s" % [x["id"], x["text"]], "data")
	r.table(PackedStringArray(["riesgo", "sistema", "inherente", "tratamiento", "residual", "apetito"]), reg["rows"])
	r.line("Dentro del apetito: %d/%d · evitados: %s" % [reg["within"], reg["total"], reg["avoided"] if reg["avoided"] != "" else "ninguno"], "ok" if reg["within"] == reg["total"] else "warn")
	if reg["needless_avoid"] > 0:
		r.line("⚠ has evitado %d riesgo(s) que se podían mitigar: la forja pierde ese sistema sin necesidad" % reg["needless_avoid"], "warn")
	c.emit("gov.register", {"gov": a["gobernanza"], "within": reg["within"], "total": reg["total"], "avoided": reg["avoided"], "needless_avoid": reg["needless_avoid"]})
	return r


static func _treat(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _g(c, a)
	var x := g.risk(a["riesgo"])
	if x.is_empty():
		return CommandResult.error("No existe el riesgo '%s'. Opciones: %s" % [a["riesgo"], ", ".join(MockGovernance.ids(g.data["risks"]))])
	var why := g.treat(x["id"], a["tratamiento"])
	if why != "":
		c.emit("gov.treat_refused", {"gov": a["gobernanza"], "risk": x["id"], "treatment": a["tratamiento"]})
		return CommandResult.new().line("✋ " + why, "warn")
	c.emit("gov.treated", {"gov": a["gobernanza"], "risk": x["id"], "treatment": a["tratamiento"], "residual": g.residual(x)})
	var detail := ""
	match a["tratamiento"]:
		"mitigar": detail = "control: " + x["control"]
		"evitar": detail = "la forja no usa (o deja de usar) %s" % x["system"]
		"aceptar": detail = "queda aceptado y documentado"
	return CommandResult.new().line("✓ %s → %s (%s) · residual %d" % [x["id"], a["tratamiento"], detail, g.residual(x)], "ok")
