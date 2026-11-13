class_name PortafolioCommands
extends RefCounted
## Exporta el progreso a un portafolio en Markdown (forja/PORTAFOLIO.md) para enseñar a un
## reclutador: rango, misiones completadas por área, competencias dominadas y evidencias de la
## Forja. Solo recoge lo que has hecho de verdad.
##   portafolio            genera forja/PORTAFOLIO.md y dice dónde está

const AREAS := {
	"T": "Fundamentos de IA",
	"P": "Ingeniería de aplicaciones con LLM (Python)",
	"A": "Seguridad de sistemas de IA: construir, atacar y defender",
	"O": "Metodología de red team y gobernanza",
	"C": "Capstones (laboratorios integradores)",
	"E": "Especializaciones",
}
const AREA_ORDER := ["T", "P", "A", "O", "C", "E"]


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("portafolio", "Exporta tu progreso a forja/PORTAFOLIO.md (para enseñar a un reclutador).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _export(c, a), "ayuda")
		.with_signature(CommandSignature.new().example("portafolio")))


static func _area_of(id: String) -> String:
	return id.substr(0, 1)


static func _export(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g: DojoGame = c.shell.get_game() as DojoGame
	if g == null:
		return CommandResult.error("El portafolio necesita una partida abierta.")
	var done_by_area := {}
	var total := 0
	var done := 0
	for m: Dictionary in g.catalog.missions:
		total += 1
		if g.progress.is_mission_completed(m["id"]):
			done += 1
			var ar := _area_of(m["id"])
			if not done_by_area.has(ar):
				done_by_area[ar] = []
			done_by_area[ar].append(m)
	# Competencias dominadas (prueba de dominio superada).
	var comps := PackedStringArray()
	for cid: String in g.progress.data.get("competencies", {}):
		var st: String = g.progress.data["competencies"][cid].get("state", "")
		if st == "dominada" or st == "transferida":
			comps.append(cid)
	comps.sort()
	# Evidencias reales importadas de la Forja.
	var evid := PackedStringArray()
	var dir := DirAccess.open("user://evidence")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".json"):
				evid.append(f.trim_suffix(".json"))
	evid.sort()

	var rank: Dictionary = g.progress.rank()
	var md := PackedStringArray()
	md.append("# Portafolio · AI RONIN")
	md.append("")
	md.append("**%s %s** (%s) · Nivel %d · %d XP" % [rank["kanji"], rank["name"], rank["es"], g.progress.level(), g.progress.xp()])
	md.append("")
	md.append("_Generado el %s desde el Dojo de AI RONIN (academia de ingeniería y seguridad de IA). Recoge solo lo completado con prueba de dominio._" % Time.get_date_string_from_system())
	md.append("")
	md.append("## Resumen")
	md.append("")
	md.append("- **Misiones completadas:** %d de %d" % [done, total])
	md.append("- **Competencias dominadas:** %d" % comps.size())
	md.append("- **Laboratorios reales de la Forja con evidencia:** %d" % evid.size())
	md.append("")
	md.append("## Lo que puedo demostrar, por área")
	for ar: String in AREA_ORDER:
		if not done_by_area.has(ar):
			continue
		md.append("")
		md.append("### %s" % AREAS.get(ar, ar))
		for m: Dictionary in done_by_area[ar]:
			md.append("- **%s** · %s" % [m["id"], m["title"]])
	if not comps.is_empty():
		md.append("")
		md.append("## Competencias dominadas")
		md.append("")
		md.append(", ".join(comps))
	if not evid.is_empty():
		md.append("")
		md.append("## Evidencias de la Forja (código y mediciones reales)")
		md.append("")
		for e in evid:
			md.append("- %s" % e)
	md.append("")
	md.append("---")
	md.append("")
	md.append("Cada misión se supera **haciendo**, no eligiendo respuestas: se programa en Python, se ataca y se defiende en laboratorios que calculan de verdad, y la prueba de dominio se pasa sin la solución delante. Los laboratorios de la Forja se ejecutan en una máquina real (Python, Docker, un LLM local) y dejan evidencia reproducible.")
	md.append("")

	var forja := ProjectSettings.globalize_path("res://").path_join("../forja").simplify_path()
	DirAccess.make_dir_recursive_absolute(forja)
	var path := forja.path_join("PORTAFOLIO.md")
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return CommandResult.error("No he podido escribir el portafolio en %s." % path)
	out.store_string("\n".join(md))
	out.close()

	var r := CommandResult.new()
	r.line("✓ Portafolio exportado: %d misiones, %d competencias dominadas, %d evidencias." % [done, comps.size(), evid.size()], "ok")
	r.line("Archivo: %s" % path, "accent")
	r.line("Es Markdown: ábrelo, repásalo y enséñalo a un reclutador (o súbelo a tu GitHub).", "muted")
	c.emit("portafolio.exported", {"missions": done, "competencies": comps.size(), "evidence": evid.size(), "path": path})
	return r
