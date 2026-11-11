class_name Shell
extends RefCounted
## Intérprete del terminal del Dojo. Solo ejecuta comandos registrados que operan
## sobre el SimWorld. No hay ningún camino hacia el sistema operativo.

signal event_emitted(event: Dictionary)

## Nivel del terminal: 0 básico · 1 flags · 2 pipes · 3 scripts.
var tier: int = 1
var registry := CommandRegistry.new()
var world := SimWorld.new()
var library: ContentLibrary
var history: PackedStringArray = []
## Veces que se ha usado cada comando (alimenta la chuleta).
var usage_count: Dictionary = {}
## Registro de eventos de la sesión (lo consumirá el motor de misiones).
var event_log: Array[Dictionary] = []
## Orquestador del juego (DojoGame) si existe. Referencia DÉBIL: DojoGame ya posee al Shell,
## y una referencia fuerte en los dos sentidos sería un ciclo que nunca se libera.
var _game_ref: WeakRef = null
var _seq: int = 0


func _init(p_library: ContentLibrary = null) -> void:
	library = p_library if p_library != null else ContentLibrary.new()
	CoreCommands.register(registry)
	MlCommands.register(registry)
	ClassicCommands.register(registry)
	VisionCommands.register(registry)
	AlignCommands.register(registry)
	MissionCommands.register(registry)
	OptimCommands.register(registry)
	NnCommands.register(registry)
	LangCommands.register(registry)
	LlmCommands.register(registry)
	SecurityCommands.register(registry)
	RagCommands.register(registry)
	AgentCommands.register(registry)
	McpCommands.register(registry)
	A2aCommands.register(registry)
	SupplyCommands.register(registry)
	SocCommands.register(registry)
	EngagementCommands.register(registry)
	GovCommands.register(registry)
	AuditCommands.register(registry)
	LabCommands.register(registry)
	StudyCommands.register(registry)
	MapCommands.register(registry)
	AkaCommands.register(registry)
	LearnCommands.register(registry)
	LearnCommands.register_explain(registry)
	PyCommands.register(registry)
	EvidenceCommands.register(registry)


func execute(line: String) -> CommandResult:
	var text := line.strip_edges()
	if text.is_empty():
		return CommandResult.new()
	history.append(text)

	var lexed := Lexer.tokenize(text)
	if not lexed["error"].is_empty():
		return CommandResult.error("Error de sintaxis: %s." % lexed["error"])
	var tokens: Array[Dictionary] = lexed["tokens"]

	for t in tokens:
		if t["type"] == Lexer.PIPE and tier < 2:
			return CommandResult.error("Los pipes (|) se desbloquean en el nivel 2 del terminal. De momento, un comando por línea.")

	if not tokens.is_empty() and tokens[-1]["type"] == Lexer.QUESTION:
		tokens.pop_back()
		return contextual_help(tokens)

	var words := _leading_words(tokens)
	var resolved := registry.resolve(words)
	var cmd: Command = resolved["command"]
	if cmd == null:
		return _unknown_command(words)

	var rest: Array[Dictionary] = tokens.slice(resolved["consumed"])
	for t in rest:
		if t["type"] == Lexer.WORD and (t["value"] == "--help" or t["value"] == "-h"):
			return cmd.help_result()

	if cmd.tier > tier:
		return CommandResult.error("🔒 '%s' se desbloquea en el nivel %d del terminal." % [cmd.path, cmd.tier])

	var bound := cmd.signature.bind(rest, world)
	if not bound["ok"]:
		var r := CommandResult.error(bound["error"])
		r.line("Uso: " + cmd.signature.usage(cmd.path), "muted")
		r.line("Más ayuda: %s --help" % cmd.path, "muted")
		emit_event("command.failed", {"path": cmd.path, "error": bound["error"]})
		return r

	var ctx := CommandContext.new()
	ctx.world = world
	ctx.registry = registry
	ctx.library = library
	ctx.shell = self
	var result := cmd.run(ctx, bound["args"])
	usage_count[cmd.path] = usage_count.get(cmd.path, 0) + 1
	emit_event("command.executed", {"path": cmd.path, "ok": result.ok, "line": text})
	return result


func set_game(g: RefCounted) -> void:
	_game_ref = weakref(g)


func get_game() -> RefCounted:
	return _game_ref.get_ref() if _game_ref != null else null


func emit_event(event_name: String, data: Dictionary = {}) -> void:
	_seq += 1
	var event := {"name": event_name, "data": data, "seq": _seq}
	event_log.append(event)
	event_emitted.emit(event)


func events_named(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in event_log:
		if e["name"] == event_name:
			out.append(e)
	return out


## Ayuda contextual: «?» al final de la línea.
func contextual_help(tokens: Array[Dictionary]) -> CommandResult:
	var words := _leading_words(tokens)
	var r := CommandResult.new()
	if words.is_empty():
		r.line("Comandos disponibles:", "accent")
		r.line("  " + "  ".join(registry.roots()), "data")
		return r
	var resolved := registry.resolve(words)
	var cmd: Command = resolved["command"]
	if cmd != null and resolved["consumed"] == words.size():
		r.line(cmd.summary)
		r.line("Uso: " + cmd.signature.usage(cmd.path), "data")
		for p in cmd.signature.positionals:
			if p["type"] in SimWorld.KINDS:
				var names := world.names_of(p["type"])
				r.line("  <%s> disponibles: %s" % [p["name"], ", ".join(names) if not names.is_empty() else "(ninguno todavía)"], "muted")
		return r
	var prefix := " ".join(words)
	var kids := registry.children(prefix)
	if not kids.is_empty():
		r.line("Subcomandos de '%s':" % prefix, "accent")
		for k in kids:
			r.line("  %s  — %s" % [k.path, k.summary], "data")
		return r
	return _unknown_command(words)


## Autocompletado (Tab). Devuelve los candidatos para la última palabra.
func complete(line: String) -> PackedStringArray:
	var ends_with_space := line.ends_with(" ")
	var words := line.strip_edges().split(" ", false)
	var partial := "" if ends_with_space or words.is_empty() else words[-1]
	var prior := words if ends_with_space else words.slice(0, maxi(words.size() - 1, 0))
	var candidates := PackedStringArray()
	if prior.is_empty():
		candidates = registry.roots()
	else:
		var prefix := " ".join(prior)
		var resolved := registry.resolve(prior)
		var cmd: Command = resolved["command"]
		if cmd != null:
			if partial.begins_with("-"):
				for o: String in cmd.signature.options:
					candidates.append("--" + o)
			else:
				var pos_index: int = prior.size() - resolved["consumed"]
				if pos_index < cmd.signature.positionals.size():
					var p: Dictionary = cmd.signature.positionals[pos_index]
					if p["type"] in SimWorld.KINDS:
						candidates = world.names_of(p["type"])
					else:
						candidates = PackedStringArray(p["choices"])
		else:
			for k in registry.children(prefix):
				candidates.append(k.path.substr(prefix.length() + 1).get_slice(" ", 0))
	var out := PackedStringArray()
	for c in candidates:
		if c.begins_with(partial) and not c in out:
			out.append(c)
	out.sort()
	return out


func _leading_words(tokens: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for t in tokens:
		if t["type"] != Lexer.WORD or String(t["value"]).begins_with("-"):
			break
		out.append(t["value"])
	return out


func _unknown_command(words: PackedStringArray) -> CommandResult:
	if words.is_empty():
		return CommandResult.error("Escribe un comando. Prueba 'help'.")
	var kids := registry.children(words[0])
	if not kids.is_empty():
		var msg := "'%s' necesita un subcomando:" % words[0]
		if words.size() > 1:
			msg = "'%s' no es un subcomando de '%s'. Subcomandos:" % [words[1], words[0]]
		var r := CommandResult.error(msg)
		for k in kids:
			r.line("  %s  — %s" % [k.path, k.summary], "data")
		return r
	var suggestion := TextUtils.closest(words[0], registry.roots())
	var r := CommandResult.error("Comando desconocido: '%s'." % words[0])
	if not suggestion.is_empty():
		r.line("¿Quisiste decir '%s'?" % suggestion, "warn")
	r.line("Escribe 'help' para ver los comandos, o termina una línea con ' ?' (espacio e interrogación) para ver opciones.", "muted")
	return r
