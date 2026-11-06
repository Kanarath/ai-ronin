class_name CommandRegistry
extends RefCounted
## Registro de comandos. Resuelve la ruta más larga que coincide con las palabras
## escritas: «dataset inspect katanas» → comando «dataset inspect», resto = argumentos.

var _commands: Dictionary = {}  # path -> Command


func register(cmd: Command) -> void:
	assert(not _commands.has(cmd.path), "Comando duplicado: " + cmd.path)
	_commands[cmd.path] = cmd


func has(path: String) -> bool:
	return _commands.has(path)


func get_command(path: String) -> Command:
	return _commands.get(path)


func all() -> Array[Command]:
	var out: Array[Command] = []
	var keys := _commands.keys()
	keys.sort()
	for k: String in keys:
		out.append(_commands[k])
	return out


func paths() -> PackedStringArray:
	var out := PackedStringArray(_commands.keys())
	out.sort()
	return out


## Primeras palabras de todas las rutas (dataset, model, help…).
func roots() -> PackedStringArray:
	var seen := {}
	for p: String in _commands:
		seen[p.get_slice(" ", 0)] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## Subcomandos directos de un prefijo («model» → model create, model train…).
func children(prefix: String) -> Array[Command]:
	var out: Array[Command] = []
	for cmd in all():
		if cmd.path.begins_with(prefix + " "):
			out.append(cmd)
	return out


## Devuelve {"command": Command|null, "consumed": int}.
func resolve(words: PackedStringArray) -> Dictionary:
	for n in range(words.size(), 0, -1):
		var candidate := " ".join(words.slice(0, n))
		if _commands.has(candidate):
			return {"command": _commands[candidate], "consumed": n}
	return {"command": null, "consumed": 0}
