class_name IsoCommands
extends RefCounted
## E5 · Auditor de ISO/IEC 42001 (content/iso/forja_42001.json).
##   iso context                     alcance, sistemas de IA y terceros de la forja
##   iso soa                         declaración de aplicabilidad (SoA) del Anexo A
##   iso check <objetivo>            un objetivo del Anexo A: justificación y evidencias
##   iso flag <objetivo> <tipo>      correcto, exclusion-injustificada o sin-evidencia
##   iso findings                    hallazgos de la auditoría de etapa 2
##   iso grade <hallazgo> <grado>    mayor, menor u observacion
##   iso decide <decisión>           recomendar, recomendar-con-plan o aplazar

const PATH := "res://content/iso/forja_42001.json"
const FLAGS := ["correcto", "exclusion-injustificada", "sin-evidencia"]
const GRADES := ["mayor", "menor", "observacion"]
const DECISIONS := ["recomendar", "recomendar-con-plan", "aplazar"]
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "gobernanza").with_signature(sig))
	add.call("iso context", "Contexto de la auditoría ISO/IEC 42001: alcance, sistemas de IA y terceros.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _context(c, a), CommandSignature.new())
	add.call("iso soa", "Declaración de aplicabilidad (SoA) de la forja: los objetivos del Anexo A.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _soa(c, a), CommandSignature.new())
	add.call("iso check", "Revisa un objetivo del Anexo A: si aplica, por qué y con qué evidencias.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _check(c, a),
		CommandSignature.new().pos("objetivo", "A.2 … A.10").example("iso check A.10"))
	add.call("iso flag", "Dictamen del auditor sobre un objetivo de la SoA.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _flag(c, a),
		CommandSignature.new().pos("objetivo", "A.2 … A.10").pos("tipo", "correcto, exclusion-injustificada o sin-evidencia", "string", true, FLAGS).example("iso flag A.2 correcto"))
	add.call("iso findings", "Hallazgos de la auditoría de certificación (etapa 2).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _findings(c, a), CommandSignature.new())
	add.call("iso grade", "Clasifica un hallazgo: no conformidad mayor, menor u observación.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _grade(c, a),
		CommandSignature.new().pos("hallazgo", "H1 … H6").pos("grado", "mayor, menor u observacion", "string", true, GRADES).example("iso grade H4 observacion"))
	add.call("iso decide", "Recomendación del equipo auditor sobre la certificación.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _decide(c, a),
		CommandSignature.new().pos("decision", "recomendar, recomendar-con-plan o aplazar", "string", true, DECISIONS).example("iso decide recomendar-con-plan"))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _norm(id: String) -> String:
	var u := id.strip_edges().to_upper()
	if u.begins_with("A") and not u.begins_with("A."):
		u = "A." + u.substr(1)
	return u


static func _soa_item(id: String) -> Dictionary:
	for x: Dictionary in data()["soa"]:
		if x["id"] == _norm(id):
			return x
	return {}


static func _finding(id: String) -> Dictionary:
	for x: Dictionary in data()["hallazgos"]:
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _context(c: CommandContext, _a: Dictionary) -> CommandResult:
	var ctx: Dictionary = data()["contexto"]
	var r := CommandResult.new()
	r.line("Auditoría ISO/IEC 42001 de la forja · " + ctx["etapa"], "accent")
	r.line("Alcance: " + ctx["alcance"], "normal")
	r.line("Sistemas de IA:", "normal")
	for s: String in ctx["sistemas"]:
		r.line("  · " + s, "data")
	r.line("Terceros de los que depende:", "normal")
	for s: String in ctx["terceros"]:
		r.line("  · " + s, "data")
	c.emit("iso.context", {})
	return r


static func _soa(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Declaración de aplicabilidad (SoA) · Anexo A de ISO/IEC 42001:2023, por objetivos", "accent")
	var rows: Array = []
	var flags: Dictionary = c.world.iso["flags"]
	for x: Dictionary in data()["soa"]:
		rows.append([x["id"], x["titulo"], "sí" if x["aplica"] else "NO", str((x["evidencias"] as Array).size()), str(flags.get(x["id"], "·"))])
	r.table(PackedStringArray(["objetivo", "título", "aplica", "evidencias", "tu dictamen"]), rows)
	r.line("Detalle: iso check <objetivo> · contrasta con el contexto: iso context · dictamen: iso flag <objetivo> <tipo>", "muted")
	c.emit("iso.soa", {})
	return r


static func _check(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _soa_item(a["objetivo"])
	if x.is_empty():
		return CommandResult.error("Objetivos: A.2 … A.10 (iso soa)")
	var r := CommandResult.new()
	r.line("%s · %s · %s" % [x["id"], x["titulo"], "aplica" if x["aplica"] else "EXCLUIDO"], "accent")
	r.line("Justificación: " + x["justificacion"], "normal")
	if (x["evidencias"] as Array).is_empty():
		r.line("Evidencias: ninguna" + (" · " + str(x["nota"]) if x.has("nota") else ""), "warn")
	else:
		for e: String in x["evidencias"]:
			r.line("  📎 " + e, "data")
	c.emit("iso.checked", {"objective": x["id"]})
	return r


static func _flag(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _soa_item(a["objetivo"])
	if x.is_empty():
		return CommandResult.error("Objetivos: A.2 … A.10 (iso soa)")
	var ok: bool = a["tipo"] == x["real"]
	var r := CommandResult.new()
	if ok:
		c.world.iso["flags"][x["id"]] = a["tipo"]
		var why: String = data()["por_que"].get(x["id"], "Justificación coherente con el contexto y evidencias que la sostienen.")
		r.line("✓ %s: %s. %s" % [x["id"], a["tipo"], why], "ok")
	else:
		r.line("✗ No se sostiene: revisa la justificación de %s contra el contexto (iso context) y mira si hay evidencias (iso check %s)." % [x["id"], x["id"]], "warn")
	var problems := 0
	var found := 0
	for s: Dictionary in data()["soa"]:
		if s["real"] != "correcto":
			problems += 1
			if c.world.iso["flags"].get(s["id"], "") == s["real"]:
				found += 1
	r.line("Problemas de la SoA encontrados: %d" % found, "muted")
	c.emit("iso.flagged", {"objective": x["id"], "type": a["tipo"], "correct": ok, "problems_found": found})
	return r


static func _findings(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Hallazgos de la etapa 2 · clasifícalos: iso grade <hallazgo> <mayor|menor|observacion>", "accent")
	for g: String in GRADES:
		r.line("  %s: %s" % [g, data()["grados"][g]], "muted")
	var grades: Dictionary = c.world.iso["grades"]
	for x: Dictionary in data()["hallazgos"]:
		r.line("%s  [%s]  %s · %s" % [x["id"], str(grades.get(x["id"], "·")), x["requisito"], x["texto"]], "data")
	c.emit("iso.findings", {})
	return r


static func _graded_ok(c: CommandContext) -> int:
	var n := 0
	for x: Dictionary in data()["hallazgos"]:
		if c.world.iso["grades"].get(x["id"], "") == x["grado"]:
			n += 1
	return n


static func _grade(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _finding(a["hallazgo"])
	if x.is_empty():
		return CommandResult.error("Hallazgos: H1 … H6 (iso findings)")
	var ok: bool = a["grado"] == x["grado"]
	var r := CommandResult.new()
	if ok:
		c.world.iso["grades"][x["id"]] = a["grado"]
		r.line("✓ %s → %s. %s" % [x["id"], a["grado"], x["por_que"]], "ok")
	else:
		r.line("✗ %s no es %s. Pregúntate: ¿falta el requisito entero, o funciona con un fallo puntual, o no hay incumplimiento?" % [x["id"], a["grado"]], "warn")
	var n := _graded_ok(c)
	r.line("Hallazgos bien clasificados: %d/%d" % [n, data()["hallazgos"].size()], "muted")
	c.emit("iso.graded", {"finding": x["id"], "grade": a["grado"], "correct": ok, "correct_count": n})
	return r


## La decisión que se sigue de los grados: alguna mayor → aplazar; alguna menor → con plan.
static func expected_decision(grades: Array) -> String:
	if "mayor" in grades:
		return "aplazar"
	if "menor" in grades:
		return "recomendar-con-plan"
	return "recomendar"


static func _decide(c: CommandContext, a: Dictionary) -> CommandResult:
	var all_graded: bool = _graded_ok(c) == data()["hallazgos"].size()
	var r := CommandResult.new()
	if not all_graded:
		r.line("Antes de decidir, clasifica bien todos los hallazgos (iso findings).", "warn")
		c.emit("iso.decided", {"decision": a["decision"], "correct": false, "graded_all": false})
		return r
	var grades: Array = data()["hallazgos"].map(func(x: Dictionary) -> String: return x["grado"])
	var exp := expected_decision(grades)
	var ok: bool = a["decision"] == exp
	if ok:
		r.line("✓ %s: %s" % [a["decision"], data()["decisiones"][a["decision"]]], "ok")
	else:
		r.line("✗ Con estos hallazgos, «%s» no se sostiene ante el comité de certificación. ¿Qué exige una no conformidad mayor?" % a["decision"], "warn")
	c.emit("iso.decided", {"decision": a["decision"], "correct": ok, "graded_all": true})
	return r
