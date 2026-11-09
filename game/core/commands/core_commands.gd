class_name CoreCommands
extends RefCounted
## Comandos de ayuda y del propio terminal. Están SIEMPRE disponibles.

const CATEGORY_NAMES := {
	"ayuda": "Ayuda",
	"terminal": "Terminal",
	"datos": "Datos",
	"modelos": "Modelos",
	"misiones": "Misiones y progreso",
	"optimizacion": "Optimización y métricas",
	"redes": "Redes neuronales",
	"lenguaje": "Texto, tokens y LLM",
	"seguridad": "Seguridad de aplicaciones LLM",
	"rag": "RAG y bases vectoriales",
	"agentes": "Agentes con herramientas",
	"mcp": "MCP y superficies de herramientas",
	"multiagente": "Sistemas multiagente (A2A)",
	"supply": "Supply chain e infraestructura de IA",
	"deteccion": "Detección y respuesta (blue team de IA)",
	"encargo": "Encargo de red team (prueba final C5)",
	"gobernanza": "Marcos y gobernanza de la IA",
	"laboratorio": "Laboratorios integradores (capstones)",
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

	reg.register(Command.new("forja setup", "Cómo preparar tu equipo para los ejercicios en Python (instalar Python).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _forja_setup(c, a), "ayuda")
		.with_signature(CommandSignature.new()
			.opt("os", "sistema operativo", "string", "windows", ["windows", "macos", "linux"])
			.example("forja setup")
			.example("forja setup --os macos"))
		.with_details("El Dojo está aislado: no puede comprobar ni instalar nada en tu equipo. Este comando solo te explica los pasos para que los hagas tú."))

	reg.register(Command.new("history","Historial de comandos de esta sesión.",
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
	for cat: String in ["misiones", "mentor", "datos", "modelos", "optimizacion", "redes", "lenguaje", "seguridad", "rag", "agentes", "mcp", "multiagente", "supply", "deteccion", "gobernanza", "laboratorio", "encargo", "ayuda", "terminal"]:
		if not by_cat.has(cat):
			continue
		r.line("")
		r.line(CATEGORY_NAMES.get(cat, cat), "accent")
		for cmd: Command in by_cat[cat]:
			var lock := "  🔒" if cmd.tier > ctx.shell.tier else ""
			r.line("  %s %s%s" % [cmd.path.rpad(22), cmd.summary, lock], "data")
	r.line("")
	r.line("Trucos: Tab autocompleta · ↑↓ historial · termina una línea con « ?» (espacio e interrogación) para ver opciones · <comando> --help", "muted")
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
	r.line("Ayuda: help <cmd> · <cmd> --help · man <tema> · explain <término> · línea terminada en « ?»", "muted")
	r.line("✓ = ya lo has usado", "muted")
	return r


static func _forja_setup(ctx: CommandContext, a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("PREPARAR LA FORJA · Python para los ejercicios 🛠", "accent")
	r.line("El Dojo no ejecuta nada en tu equipo (está aislado), así que estos pasos los haces tú en una terminal de tu sistema.", "muted")
	r.line("")
	r.line("1. Instalar Python 3.12 o superior", "accent")
	match String(a["os"]):
		"macos":
			r.line("  Opción A (Homebrew):  brew install python", "data")
			r.line("  Opción B: instalador oficial de https://www.python.org/downloads/", "data")
			r.line("  Comprueba: python3 --version", "data")
		"linux":
			r.line("  Debian/Ubuntu:  sudo apt install python3", "data")
			r.line("  Fedora:         sudo dnf install python3", "data")
			r.line("  Comprueba: python3 --version", "data")
		_:
			r.line("  Opción A (PowerShell):  winget install --id Python.Python.3.13 -e", "data")
			r.line("  Opción B: instalador oficial de https://www.python.org/downloads/", "data")
			r.line("            ⚠ marca «Add python.exe to PATH» en la primera pantalla.", "warn")
			r.line("  Cierra y abre la terminal. Comprueba: python --version", "data")
			r.line("  Si se abre la Microsoft Store: Configuración → Aplicaciones → Configuración avanzada", "muted")
			r.line("  → Alias de ejecución de aplicaciones → desactiva python.exe y python3.exe.", "muted")
	r.line("")
	r.line("2. No hace falta instalar nada más", "accent")
	r.line("  Los tests usan unittest, que viene con Python. Sin pip, sin librerías.", "muted")
	r.line("")
	r.line("3. Ejecutar un ejercicio (desde la carpeta forja/ejercicios del proyecto)", "accent")
	var py := "python3" if String(a["os"]) != "windows" else "python"
	r.line("  %s -m unittest -v test_T1_01_estadisticas" % py, "data")
	r.line("")
	r.line("¿Sin Python ni permisos para instalarlo? Puedes seguir con todas las misiones del Dojo; los ejercicios 🛠 quedan pendientes y no bloquean tu progreso.", "muted")
	r.line("Más: man python · forja setup --os macos|linux", "muted")
	ctx.emit("help.forja_setup", {"os": a["os"]})
	return r


static func _history(ctx: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	var h := ctx.shell.history
	for i in h.size():
		r.line("%4d  %s" % [i + 1, h[i]], "data")
	return r
