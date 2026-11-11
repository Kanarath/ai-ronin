class_name EvidenceCommands
extends RefCounted
## Evidencias de los ejercicios de Python: importar los JSON que genera `python -m ronin_check`
## y ver qué ejercicios están verificados. Solo se leen ficheros locales; no se ejecuta nada.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("evidence import", "Importa evidencias de tus ejercicios de Python (sin ruta: todas las de forja/evidencias).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _import(c, a), "misiones")
		.with_signature(CommandSignature.new()
			.pos("ruta", "fichero .json o carpeta (entre comillas si tiene espacios)", "string", false)
			.example("evidence import").example("evidence import \"C:/ruta/T1-02.json\"")))
	reg.register(Command.new("evidence list", "Tus ejercicios de Python: cuáles has verificado y en qué misiones se usan.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), "misiones"))


static func _game(c: CommandContext) -> DojoGame:
	return c.shell.get_game() as DojoGame


static func _missions_of(g: DojoGame, id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m: Dictionary in g.catalog.missions:
		if g.evidence.exercise_of_mission(m) == id:
			out.append(m["id"])
	return out


static func _import(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("Las evidencias necesitan una partida.")
	var ruta: String = a.get("ruta", "") if a.get("ruta") != null else ""
	if ruta.is_empty():
		ruta = EvidenceImporter.default_dir()
	var files := PackedStringArray([ruta]) if ruta.get_extension().to_lower() == "json" else EvidenceImporter.json_files(ruta)
	if files.is_empty():
		return CommandResult.error("No hay evidencias en %s. Genera una desde forja/ejercicios con: python -m ronin_check T1-02" % ruta)
	var r := CommandResult.new()
	r.line("Importando %d evidencia(s) de %s" % [files.size(), ruta.get_base_dir() if files.size() == 1 else ruta], "accent")
	var data: Array = []
	var meas: Array = []
	var bonus := 0
	for f in files:
		var res := g.import_evidence(f)
		if res["ok"] and res["kind"] == "medicion":
			meas.append([res["exercise"], "%d configuraciones · %s" % [res["configs"], res["modelo"]], measurement_summary(res)])
		elif res["ok"]:
			var state := "✓ verificado" if res["all_passed"] else "%d / %d tests" % [res["passed"], res["total"]]
			if res["first_verified"]:
				state += "  +%d XP" % EvidenceImporter.VERIFIED_XP
				bonus += EvidenceImporter.VERIFIED_XP
			data.append([res["exercise"], state, ", ".join(_missions_of(g, res["exercise"]))])
			if not res["all_passed"]:
				var missing := int(res["total"]) - int(res["passed"])
				g.runner.mentor_message.emit("%s %d %s de %s: el objetivo pide los %d/%d." % ["Falta" if missing == 1 else "Faltan", missing,
					"test" if missing == 1 else "tests", res["exercise"], int(res["total"]), int(res["total"])], "warn")
		else:
			data.append([f.get_file(), "✗ rechazada", "; ".join(res["errors"])])
	if not data.is_empty():
		r.table(PackedStringArray(["ejercicio", "estado", "misiones / motivo"]), data)
	if not meas.is_empty():
		r.table(PackedStringArray(["medición", "configuraciones · modelo", "resultado"]), meas)
	if bonus > 0:
		r.line("Ejercicios verificados: buen trabajo. El código es tuyo; el Dojo solo ha leído el resultado de los tests.", "ok")
	return r


## Qué cuenta «ataques_exitos» en cada laboratorio y cómo se llama su configuración base
## («ninguna»): no todas las mediciones son ataques contra defensas (A1-06 mide un juez,
## E4-01 el abuso que llega al modelo…).
const MEASURE_LABELS := {
	"A1-05": ["fugas del secreto", "sin defensas"],
	"A1-06": ["juez engañado", "sin mitigaciones"],
	"A1-07": ["ataques que pasan", "sin guardianes"],
	"A2-06": ["documento del tercero en primer lugar", "sin reranking"],
	"A6-04": ["artefactos maliciosos aceptados", "sin controles"],
	"E2-01": ["ataques con éxito sin detectar", "sin defensas"],
	"E2-02": ["acuerdo del modelo extraído", "sin defensas"],
	"E2-03": ["aciertos del ataque de pertenencia", "sin defensas"],
	"E4-01": ["abuso que llega al modelo", "sin defensas"],
	"E4-02": ["fugas al fichero de trazas", "sin defensas"],
	"E4-03": ["ataques admitidos por la política", "sin reglas"],
}


## Resumen de una medición importada con la etiqueta de su laboratorio.
static func measurement_summary(res: Dictionary) -> String:
	var lab: Array = MEASURE_LABELS.get(res["exercise"], ["éxito de los ataques", "sin defensas"])
	var best := "mejor %s" % _pct(res["best_rate"])
	if str(res.get("best_config", "")) != "":
		best += " (%s)" % res["best_config"]
	if not res["has_baseline"]:
		return "%s: %s" % [lab[0], best]
	return "%s: %s %s · %s" % [lab[0], lab[1], _pct(res["baseline_rate"]), best]


static func _pct(rate: float) -> String:
	return "%.0f\u00a0%%" % (rate * 100.0)


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("Las evidencias necesitan una partida.")
	var r := CommandResult.new()
	r.line("Ejercicios de Python (forja/ejercicios)", "accent")
	var data: Array = []
	var ok := 0
	var ids: Array = g.evidence.exercises.keys()
	ids.sort()
	for id: String in ids:
		var ev: Dictionary = g.progress.data.get("evidence", {}).get(id, {})
		var state := "sin evidencia"
		if ev.get("verified", false):
			state = "✓ verificado"
			ok += 1
		elif not ev.is_empty():
			state = "%d / %d tests" % [ev["passed"], ev["total"]]
		data.append([id, g.evidence.exercises[id]["file"], state, ", ".join(_missions_of(g, id))])
	r.table(PackedStringArray(["ejercicio", "fichero", "estado", "misiones"]), data)
	var meas: Dictionary = g.progress.data.get("measurements", {})
	for lab: String in meas:
		r.line("Medición %s (%s): %s" % [lab, meas[lab]["modelo"], " · ".join(PackedStringArray(meas[lab]["configs"].map(
			func(c: Dictionary) -> String: return "%s %d/%d" % [c["defensas"], c["exitos"], c["n"]])))], "normal")
	r.line("%d de %d verificados. Para verificar uno: python -m ronin_check <ID> (desde forja/ejercicios) y después evidence import." % [ok, ids.size()], "muted")
	return r
