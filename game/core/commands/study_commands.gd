class_name StudyCommands
extends RefCounted
## Lecturas: referencias de cada misión y lecturas recomendadas que complementan algunas unidades.
## El Dojo no abre enlaces ni se conecta a nada: muestra la dirección y, como mucho, la copia
## al portapapeles local para que la abras tú en tu navegador.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("lecturas", "Lecturas recomendadas y referencias: sin tema, lista las unidades con lecturas; con tema, sus enlaces.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "ayuda")
		.with_signature(CommandSignature.new()
			.pos("tema", "unidad (O1…), misión (A3-03) o referencia (ref.…)", "string", false)
			.example("lecturas").example("lecturas O3").example("lecturas C1-01")))
	reg.register(Command.new("lecturas hecho", "Marca una lectura recomendada como hecha (desbloquea las que dependen de ella).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _done(c, a), "ayuda")
		.with_signature(CommandSignature.new().pos("unidad", "O1, O2, O3, O4, A5 o C4").example("lecturas hecho O1")))
	reg.register(Command.new("lecturas copiar", "Copia al portapapeles la dirección de una referencia (el Dojo no abre enlaces).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _copy(c, a), "ayuda")
		.with_signature(CommandSignature.new().pos("referencia", "id de la referencia (ref.…)").example("lecturas copiar ref.mitre-atlas")))


static func _game(c: CommandContext) -> DojoGame:
	return c.shell.get_game() as DojoGame


static func ref_lines(r: CommandResult, path: StudyPath, ids: Array) -> void:
	for id: String in ids:
		var ref: Dictionary = path.refs.get(id, {})
		if ref.is_empty():
			continue
		r.line("• %s — %s" % [ref["title"], ref.get("source", ref.get("authors", ""))], "normal")
		if ref.has("url"):
			r.line("  %s  (consultada %s) · lecturas copiar %s" % [ref["url"], ref.get("consulted", "?"), id], "muted")
		else:
			r.line("  sin enlace en línea (libro o publicación impresa)", "muted")


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("Las lecturas necesitan una partida.")
	var path := g.study
	var tema: String = a.get("tema", "") if a.get("tema") != null else ""
	var r := CommandResult.new()
	if tema.is_empty():
		r.line("Lecturas recomendadas: teoría que complementa estas unidades (cada una tiene además su misión)", "accent")
		var data: Array = []
		for u: Dictionary in path.units:
			var st := path.status(g.progress, u["id"])
			var req := ", ".join(path.missing(g.progress, u["id"])) if st == "bloqueada" else ""
			data.append([{"estudiada": "✓", "disponible": "·", "bloqueada": "🔒"}[st] + " " + String(u["id"]), u["title"], st, req])
		r.table(PackedStringArray(["unidad", "título", "estado", "falta"]), data)
		r.line("Detalle y enlaces: lecturas <unidad> · lecturas de una misión: lecturas <misión>", "muted")
		c.emit("study.list", {})
		return r
	var u := path.unit(tema)
	if not u.is_empty():
		var st := path.status(g.progress, u["id"])
		r.line("%s · lectura recomendada (%s)" % [u["title"], st], "accent")
		r.line("Temario: " + String(u["temario"]), "normal")
		var after := PackedStringArray(u["unlock"]["missions"]) + PackedStringArray(u["unlock"]["studies"])
		r.line("Se estudia después de: %s" % (", ".join(after) if not after.is_empty() else "—"), "muted")
		if not u["recommended_before"].is_empty():
			r.line("Recomendada antes de: %s" % ", ".join(PackedStringArray(u["recommended_before"])), "muted")
		if st == "bloqueada":
			r.line("🔒 Antes completa: %s" % ", ".join(path.missing(g.progress, u["id"])), "warn")
			return r
		r.line("No hay misión: lee las referencias a tu ritmo y, cuando lo hayas estudiado, escribe lecturas hecho %s." % u["id"], "muted")
		ref_lines(r, path, u["refs"])
		c.emit("study.viewed", {"unit": u["id"], "status": st})
		return r
	var m := g.catalog.get_mission(tema.to_upper())
	if not m.is_empty():
		r.line("Lecturas de %s · %s" % [m["id"], m["title"]], "accent")
		var ids: Array = m.get("further_reading", [])
		if ids.is_empty():
			r.line("Esta misión no tiene lecturas asociadas.", "muted")
		ref_lines(r, path, ids)
		return r
	if path.refs.has(tema):
		ref_lines(r, path, [tema])
		return r
	return CommandResult.error("No conozco «%s». Prueba: lecturas · lecturas O3 · lecturas A3-03" % tema)


static func _done(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("Las lecturas necesitan una partida.")
	var u := g.study.unit(a["unidad"])
	if u.is_empty():
		return CommandResult.error("No es una unidad con lecturas recomendadas. Lista: lecturas")
	var st := g.study.status(g.progress, u["id"])
	if st == "bloqueada":
		return CommandResult.error("🔒 Antes completa: %s" % ", ".join(g.study.missing(g.progress, u["id"])))
	g.study.mark_studied(g.progress, u["id"])
	g.save()
	var r := CommandResult.new().line("✓ %s marcada como estudiada." % u["title"], "ok")
	for other: Dictionary in g.study.units:
		if u["id"] in other["unlock"]["studies"] and g.study.status(g.progress, other["id"]) == "disponible":
			r.line("Se desbloquea: %s · lecturas %s" % [other["title"], other["id"]], "accent")
	c.emit("study.done", {"unit": u["id"]})
	g.progress_changed.emit()
	return r


static func _copy(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("Las lecturas necesitan una partida.")
	var ref: Dictionary = g.study.refs.get(a["referencia"], {})
	if ref.is_empty():
		return CommandResult.error("No existe la referencia «%s»." % a["referencia"])
	if not ref.has("url"):
		return CommandResult.error("Esa referencia no tiene enlace en línea.")
	# Portapapeles local del sistema: no hay red ni procesos. En modo headless no existe.
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(ref["url"])
		return CommandResult.new().line("✓ Copiado: %s · pégalo en tu navegador." % ref["url"], "ok")
	return CommandResult.new().line(ref["url"], "normal")
