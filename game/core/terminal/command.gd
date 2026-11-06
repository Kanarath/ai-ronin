class_name Command
extends RefCounted
## Un comando del terminal. Se define con una ruta («dataset inspect»), su firma y
## un handler: func(ctx: CommandContext, args: Dictionary) -> CommandResult.

var path: String = ""
var summary: String = ""
## Explicación ampliada que muestra --help.
var details: String = ""
var category: String = "general"
## Nivel del terminal necesario: 0 básico · 1 flags · 2 pipes · 3 scripts.
var tier: int = 0
var signature: CommandSignature = CommandSignature.new()
var handler: Callable


func _init(p_path: String, p_summary: String, p_handler: Callable, p_category: String = "general") -> void:
	path = p_path
	summary = p_summary
	handler = p_handler
	category = p_category


func with_signature(sig: CommandSignature) -> Command:
	signature = sig
	return self


func with_details(text: String) -> Command:
	details = text
	return self


func with_tier(t: int) -> Command:
	tier = t
	return self


func run(ctx: CommandContext, args: Dictionary) -> CommandResult:
	return handler.call(ctx, args)


func help_result() -> CommandResult:
	var r := CommandResult.new()
	r.line(path, "accent").line(summary)
	r.line("")
	r.line("Uso: " + signature.usage(path), "data")
	if not signature.positionals.is_empty() or not signature.options.is_empty():
		r.line("")
	for p in signature.positionals:
		var choices: Array = p["choices"]
		var extra := "  (%s)" % ", ".join(PackedStringArray(choices)) if not choices.is_empty() else ""
		r.line("  <%s>  %s%s" % [p["name"], p["help"], extra])
	for o: String in signature.options:
		var spec: Dictionary = signature.options[o]
		var default_txt := "" if spec["default"] == null or spec["type"] == "bool" else "  [por defecto: %s]" % str(spec["default"])
		var choices: Array = spec["choices"]
		var choice_txt := "  (%s)" % ", ".join(PackedStringArray(choices)) if not choices.is_empty() else ""
		r.line("  --%s  %s%s%s" % [o, spec["help"], choice_txt, default_txt])
	if not details.is_empty():
		r.line("")
		r.line(details, "muted")
	if not signature.examples.is_empty():
		r.line("")
		r.line("Ejemplos:", "accent")
		for e in signature.examples:
			r.line("  " + e, "data")
	return r
