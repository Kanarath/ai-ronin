class_name CommandSignature
extends RefCounted
## Firma de un comando: argumentos posicionales y opciones (--nombre valor).
##
## Tipos: "string", "int", "float", "bool" (opción sin valor),
##        "dataset" y "model" (nombres que deben existir en el SimWorld),
##        "rest" (último posicional: recoge todas las palabras restantes).

var positionals: Array[Dictionary] = []
var options: Dictionary = {}
var examples: PackedStringArray = []


func pos(p_name: String, help: String, type: String = "string", required: bool = true, choices: Array = []) -> CommandSignature:
	positionals.append({"name": p_name, "help": help, "type": type, "required": required, "choices": choices})
	return self


func opt(p_name: String, help: String, type: String = "string", default: Variant = null, choices: Array = []) -> CommandSignature:
	options[p_name] = {"help": help, "type": type, "default": default, "choices": choices}
	return self


func example(text: String) -> CommandSignature:
	examples.append(text)
	return self


func usage(path: String) -> String:
	var parts := PackedStringArray([path])
	for p in positionals:
		parts.append(("<%s>" if p["required"] else "[%s]") % p["name"])
	for o: String in options:
		var spec: Dictionary = options[o]
		parts.append("[--%s]" % o if spec["type"] == "bool" else "[--%s <%s>]" % [o, spec["type"]])
	return " ".join(parts)


## Asocia los tokens a la firma. Devuelve {"ok", "args", "error"}.
## world se usa para validar los tipos "dataset" y "model" (puede ser null).
func bind(tokens: Array[Dictionary], world: Object) -> Dictionary:
	var args := {}
	for o: String in options:
		args[o] = options[o]["default"]
	var pos_values: Array[String] = []
	var i := 0
	while i < tokens.size():
		var value: String = tokens[i]["value"]
		# Un comando sin opciones trata «--algo» como texto normal (p. ej. un informe que cita un comando).
		var is_flag: bool = tokens[i]["type"] == Lexer.WORD and value.begins_with("--") and value.length() > 2 and not options.is_empty()
		if is_flag:
			var flag := value.substr(2)
			var inline_value := ""
			var has_inline := flag.contains("=")
			if has_inline:
				inline_value = flag.get_slice("=", 1)
				flag = flag.get_slice("=", 0)
			if not options.has(flag):
				var known := PackedStringArray()
				for o: String in options:
					known.append("--" + o)
				var hint := " Opciones válidas: %s." % ", ".join(known) if not known.is_empty() else " Este comando no tiene opciones."
				return _err("opción desconocida --%s.%s" % [flag, hint])
			var spec: Dictionary = options[flag]
			if spec["type"] == "bool":
				args[flag] = true
				i += 1
				continue
			if not has_inline:
				if i + 1 >= tokens.size():
					return _err("la opción --%s necesita un valor (%s)." % [flag, spec["type"]])
				inline_value = tokens[i + 1]["value"]
				i += 1
			var conv := _convert(inline_value, spec, "--" + flag, world)
			if conv.has("error"):
				return _err(conv["error"])
			args[flag] = conv["value"]
		else:
			pos_values.append(value)
		i += 1
	var has_rest: bool = not positionals.is_empty() and positionals[-1]["type"] == "rest"
	if pos_values.size() > positionals.size() and not has_rest:
		return _err("sobran argumentos: %s" % " ".join(PackedStringArray(pos_values.slice(positionals.size()))))
	for p_i in positionals.size():
		var p: Dictionary = positionals[p_i]
		if p["type"] == "rest":
			var rest := PackedStringArray(pos_values.slice(p_i))
			if rest.is_empty() and p["required"]:
				return _err("falta el argumento <%s>: %s" % [p["name"], p["help"]])
			args[p["name"]] = " ".join(rest) if not rest.is_empty() else null
			break
		if p_i >= pos_values.size():
			if p["required"]:
				return _err("falta el argumento <%s>: %s" % [p["name"], p["help"]])
			args[p["name"]] = null
			continue
		var conv := _convert(pos_values[p_i], p, "<%s>" % p["name"], world)
		if conv.has("error"):
			return _err(conv["error"])
		args[p["name"]] = conv["value"]
	return {"ok": true, "args": args, "error": ""}


func _convert(raw: String, spec: Dictionary, label: String, world: Object) -> Dictionary:
	var choices: Array = spec.get("choices", [])
	if not choices.is_empty() and not raw in choices:
		return {"error": "%s debe ser uno de: %s (recibido '%s')." % [label, ", ".join(PackedStringArray(choices)), raw]}
	match spec["type"]:
		"int":
			if not raw.is_valid_int():
				return {"error": "%s debe ser un número entero (recibido '%s')." % [label, raw]}
			return {"value": raw.to_int()}
		"float":
			if not raw.is_valid_float():
				return {"error": "%s debe ser un número (recibido '%s'). Usa punto decimal: 0.3" % [label, raw]}
			return {"value": raw.to_float()}
		"dataset", "model", "regressor", "network", "tokenizer", "lm", "bot", "rag", "agent", "mcp", "mesh":
			if world != null:
				var names: PackedStringArray = world.call("names_of", spec["type"])
				if not raw in names:
					var what: String = SimWorld.KIND_NAMES.get(spec["type"], spec["type"])
					var suggestion := TextUtils.closest(raw, names)
					var extra := " ¿Quisiste decir '%s'?" % suggestion if not suggestion.is_empty() else ""
					return {"error": "no existe el %s '%s'.%s Disponibles: %s" % [what, raw, extra, ", ".join(names) if not names.is_empty() else "(ninguno)"]}
			return {"value": raw}
		_:
			return {"value": raw}


func _err(message: String) -> Dictionary:
	return {"ok": false, "args": {}, "error": message}
