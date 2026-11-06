class_name CoreCommands
extends RefCounted
## Comandos de ayuda y del propio terminal. Están SIEMPRE disponibles.

const CATEGORY_NAMES := {
	"ayuda": "Ayuda",
	"terminal": "Terminal",
	"datos": "Datos",
	"modelos": "Modelos",
	"misiones": "Misiones y progreso",
	"mentor": "Mentor RONIN",
}


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("help", "Lista de comandos o ayuda de uno concreto.",
		func(ctx: CommandContext, a: Dictionary) -> CommandResult: return _help(ctx, a), "ayuda")
		.with_signature(CommandSignature.new()
			.pos("tema", "comando o tema del manual", "rest", false)
			.example("help")
			.example("help dataset inspect")
			.example("help knn")))

	reg.register(Command.new("man", "Manual conceptual: explica un tema a fondo.",
		func(ctx: CommandContext, a: Dictionary) -> CommandResult: return _man(ctx, a), "ayuda")
		.with_signature(CommandSignature.new()
			.pos("tema", "tema del manual", "string", false)
			.example("man")
			.example("man normalizacion")))

	reg.register(Command.new("explain", "Definición de un término del glosario.",
		func(ctx: CommandContext, a: Dictionary) -> CommandResult: return _explain(ctx, a), "ayuda")
		.with_signature(CommandSignature.new()
			.pos("termino", "término a explicar", "rest", false)
			.example("explain overfitting")
			.example("explain fuga de datos")))

	reg.register(Command.new("cheatsheet", "Chuleta: comandos disponibles con ejemplos y conceptos.",
		func(ctx: CommandContext, a: Dictionary) -> CommandResult: return _cheatsheet(ctx, a), "ayuda"))

	reg.register(Command.new("history", "Historial de comandos de esta sesión.",
		func(ctx: CommandContext, a: Dictionary) -> CommandResult: return _history(ctx, a), "terminal"))

	reg.register(Command.new("clear", "Limpia la pantalla del terminal.",
		func(_ctx: CommandContext, _a: Dictionary) -> CommandResult: return _clear(), "terminal"))


static func _clear() -> CommandResult:
	var r := CommandResult.new()
	r.action = "clear"
	return r


static func _help(ctx: CommandContext, a: Dictionary) -> CommandResult:
	var topic: Variant = a.get("tema")
	if topic == null:
		return _help_overview(ctx)
	var t := String(topic)
	var cmd := ctx.registry.get_command(t)
	if cmd != null:
		return cmd.help_result()
	var kids := ctx.registry.children(t)
	if not kids.is_empty():
		var r := CommandResult.new().line("Subcomandos de '%s':" % t, "accent")
		for k in kids:
			r.line("  %s  — %s" % [k.path.rpad(22), k.summary], "data")
		r.line("Detalle: help <subcomando>  ·  Ejemplo: help %s" % kids[0].path, "muted")
		return r
	if ctx.library.topics.has(t):
		return _man(ctx, {"tema": t})
	if not ctx.library.find_term(t).is_empty():
		return _explain(ctx, {"termino": t})
	var r := CommandResult.error("No hay ayuda para '%s'." % t)
	var pool := ctx.registry.paths()
	pool.append_array(ctx.library.topic_ids())
	var s := TextUtils.closest(t, pool)
	if not s.is_empty():
		r.line("¿Quisiste decir '%s'?" % s, "warn")
	return r


static func _help_overview(ctx: CommandContext) -> CommandResult:
	var r := CommandResult.new()
	r.line("COMANDOS DEL DOJO", "accent")
	var by_cat := {}
	for cmd in ctx.registry.all():
		if not by_cat.has(cmd.category):
			by_cat[cmd.category] = []
		by_cat[cmd.category].append(cmd)
	for cat: String in ["misiones", "mentor", "datos", "modelos", "ayuda", "terminal"]:
		if not by_cat.has(cat):
			continue
		r.line("")
		r.line(CATEGORY_NAMES.get(cat, cat), "accent")
		for cmd: Command in by_cat[cat]:
			var lock := "  🔒" if cmd.tier > ctx.shell.tier else ""
			r.line("  %s %s%s" % [cmd.path.rpad(22), cmd.summary, lock], "data")
	r.line("")
	r.line("Trucos: Tab autocompleta · ↑↓ historial · termina una línea con ? para ver opciones · <comando> --help", "muted")
	return r


static func _man(ctx: CommandContext, a: Dictionary) -> CommandResult:
	var topic: Variant = a.get("tema")
	var r := CommandResult.new()
	if topic == null:
		r.line("TEMAS DEL MANUAL", "accent")
		for id in ctx.library.topic_ids():
			r.line("  %s  %s" % [id.rpad(18), ctx.library.topics[id]["title"]], "data")
		r.line("Uso: man <tema>", "muted")
		return r
	var t := String(topic).to_lower()
	if not ctx.library.topics.has(t):
		r.fail("No existe el tema '%s' en el manual." % t)
		var s := TextUtils.closest(t, ctx.library.topic_ids())
		if not s.is_empty():
			r.line("¿Quisiste decir '%s'?" % s, "warn")
		r.line("Lista de temas: man", "muted")
		return r
	var entry: Dictionary = ctx.library.topics[t]
	r.line(String(entry["title"]).to_upper(), "accent")
	r.line("")
	for paragraph: String in entry["body"]:
		r.line(paragraph)
		r.line("")
	var see: Array = entry.get("see_also", [])
	if not see.is_empty():
		r.line("Ver también: " + ", ".join(PackedStringArray(see)), "muted")
	ctx.emit("help.man", {"topic": t})
	return r


static func _explain(ctx: CommandContext, a: Dictionary) -> CommandResult:
	var q: Variant = a.get("termino")
	var r := CommandResult.new()
	if q == null:
		r.line("TÉRMINOS DEL GLOSARIO", "accent")
		var names := PackedStringArray()
		for t in ctx.library.terms:
			names.append(t["term"])
		names.sort()
		r.line("  " + "  ·  ".join(names), "data")
		r.line("Uso: explain <término>", "muted")
		return r
	var entry := ctx.library.find_term(String(q))
	if entry.is_empty():
		r.fail("'%s' no está en el glosario." % q)
		var s := TextUtils.closest(String(q), ctx.library.term_keys())
		if not s.is_empty():
			r.line("¿Quisiste decir '%s'?" % s, "warn")
		return r
	r.line(entry["term"], "accent")
	r.line(entry["short"])
	r.line("")
	r.line(entry["body"])
	r.line("")
	r.line("Tipo de conocimiento: " + ctx.library.epistemic_label(entry["epistemic"]), "muted")
	var aliases: Array = entry.get("aliases", [])
	if not aliases.is_empty():
		r.line("También: " + ", ".join(PackedStringArray(aliases)), "muted")
	ctx.emit("help.explain", {"term": entry["id"]})
	return r


static func _cheatsheet(ctx: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("CHULETA", "accent")
	for cmd in ctx.registry.all():
		if cmd.tier > ctx.shell.tier or cmd.category == "ayuda" or cmd.category == "terminal":
			continue
		var used: bool = ctx.shell.usage_count.get(cmd.path, 0) > 0
		var mark := "✓" if used else "·"
		r.line("%s %s" % [mark, cmd.signature.usage(cmd.path)], "data")
		if not cmd.signature.examples.is_empty():
			r.line("    p. ej.: " + cmd.signature.examples[0], "muted")
	r.line("")
	r.line("Ayuda: help <cmd> · <cmd> --help · man <tema> · explain <término> · línea terminada en ?", "muted")
	r.line("✓ = ya lo has usado", "muted")
	return r


static func _history(ctx: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	var h := ctx.shell.history
	for i in h.size():
		r.line("%4d  %s" % [i + 1, h[i]], "data")
	return r
