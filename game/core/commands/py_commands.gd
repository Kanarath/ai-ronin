class_name PyCommands
extends RefCounted
## Python dentro del Dojo: un editor y un intérprete propio de un subconjunto de Python
## (PyInterpreter). El código del alumno se ejecuta de verdad, pero sin acceso a nada del
## ordenador: ni ficheros, ni red, ni el motor del juego.
##
##   py          abre el editor (con el ejercicio del paso actual, si lo hay)
##   py run      ejecuta el código y enseña lo que imprime
##   py check    ejecuta los tests del ejercicio del paso actual
##   py reset    vuelve al código inicial del ejercicio
##   py close    cierra el editor

const MAX_STEPS := 200000


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("py", "Abre el editor de Python del Dojo (con el ejercicio del paso actual, si lo hay).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _open(c, a), "python"))
	reg.register(Command.new("py run", "Ejecuta tu código de Python y enseña lo que imprime.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _run(c, a), "python"))
	reg.register(Command.new("py check", "Comprueba tu código con los tests del ejercicio del paso actual.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _check(c, a), "python"))
	reg.register(Command.new("py reset", "Vuelve al código inicial del ejercicio (pierdes tus cambios).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _reset(c, a), "python"))
	reg.register(Command.new("py close", "Cierra el editor de Python (tu código se guarda).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _close(c, a), "python"))


static func _game(c: CommandContext) -> DojoGame:
	return c.shell.get_game() as DojoGame


## Ejercicio de Python del objetivo actual (o {}).
static func current_exercise(g: DojoGame) -> Dictionary:
	return g.runner.current_objective().get("py_exercise", {})


static func _open(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El editor de Python necesita una partida.")
	var ex := current_exercise(g)
	var r := CommandResult.new()
	if not ex.is_empty() and g.py_exercise_id != ex["id"]:
		g.py_exercise_id = ex["id"]
		g.py_code = g.saved_py_code(ex["id"], ex.get("starter", ""))
	r.action = "py_open"
	r.line("Editor de Python abierto arriba, en el laboratorio. Haz clic en él para escribir.", "accent")
	if not ex.is_empty():
		r.line("Ejercicio: %s" % ex.get("title", ex["id"]), "normal")
	r.line("py run ejecuta tu código · py check lo comprueba · py close cierra el editor (Ctrl+Enter también ejecuta).", "muted")
	return r


static func _run(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El editor de Python necesita una partida.")
	if g.py_code.strip_edges().is_empty():
		return CommandResult.error("No hay código que ejecutar. Abre el editor con py y escribe algo.")
	g.store_py_code()
	var interp := PyInterpreter.new()
	var res: Dictionary = interp.run(g.py_code, MAX_STEPS)
	var r := CommandResult.new()
	r.line("Ejecutando tu código…", "muted")
	for l: String in res.get("output", PackedStringArray()):
		r.line(l, "data")
	if not res.get("ok", false):
		_error_lines(r, res.get("error", {}))
	elif res.get("output", PackedStringArray()).is_empty():
		r.line("(tu código no ha impreso nada: usa print(...) para ver resultados)", "muted")
	c.emit("py.ran", {"ok": res.get("ok", false), "exercise": g.py_exercise_id})
	return r


static func _check(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El editor de Python necesita una partida.")
	var ex := current_exercise(g)
	if ex.is_empty():
		return CommandResult.error("El paso actual no tiene ejercicio de Python. Puedes usar py y py run para practicar libremente.")
	if g.py_exercise_id != ex["id"]:
		g.py_exercise_id = ex["id"]
		g.py_code = g.saved_py_code(ex["id"], ex.get("starter", ""))
	g.store_py_code()
	var res: Dictionary = PyExercise.check(g.py_code, _int_spec(ex))
	var r := CommandResult.new()
	if not res.get("ok", false):
		r.line("Tu código no llega a ejecutarse:", "warn")
		_error_lines(r, res.get("error", {}))
		c.emit("py.checked", {"exercise": ex["id"], "passed": 0, "total": int(res.get("total", 0)), "all_passed": false})
		return r
	if res.get("missing_function", false):
		r.line(str(res.get("error", {}).get("message", "No has definido la función %s." % ex["function"])), "warn")
		r.line("Comprueba que la línea empieza por def %s( y que el nombre está bien escrito." % ex["function"], "muted")
		c.emit("py.checked", {"exercise": ex["id"], "passed": 0, "total": int(res.get("total", 0)), "all_passed": false})
		return r
	var rows: Array = []
	for t: Dictionary in res.get("results", []):
		var got := _show(t.get("got")) if t.get("error", {}).is_empty() else "error: " + str(t["error"].get("message", ""))
		# ✓ y × ocupan una celda de la fuente monoespaciada (✗ es más ancho y descuadra la fila).
		rows.append(["✓" if t.get("ok", false) else "×", "%s(%s)" % [ex["function"], _args(t.get("args", []))], _show(t.get("expected")), got])
	r.line("Comprobando %s() con %d casos" % [ex["function"], int(res.get("total", 0))], "accent")
	r.table(PackedStringArray(["", "llamada", "esperado", "tu resultado"]), rows)
	var passed := int(res.get("passed", 0))
	var total := int(res.get("total", 0))
	var all_ok := passed == total and total > 0
	r.line("%d de %d casos correctos." % [passed, total], "ok" if all_ok else "warn")
	if all_ok:
		# El editor se cierra solo para dejar sitio a la consola; py lo vuelve a abrir.
		r.action = "py_close"
		r.line("Editor cerrado: tu código está guardado y py lo vuelve a abrir.", "muted")
	else:
		r.line("Cambia la línea marcada con ← y vuelve a probar con py check." if g.py_code.contains("←") else "Corrige tu función y vuelve a probar con py check.", "muted")
	c.emit("py.checked", {"exercise": ex["id"], "passed": passed, "total": total, "all_passed": all_ok})
	return r


static func _reset(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El editor de Python necesita una partida.")
	var ex := current_exercise(g)
	if ex.is_empty():
		return CommandResult.error("El paso actual no tiene ejercicio de Python que reiniciar.")
	g.py_exercise_id = ex["id"]
	g.py_code = ex.get("starter", "")
	g.store_py_code()
	var r := CommandResult.new()
	r.action = "py_open"
	r.line("Código inicial restaurado.", "muted")
	return r


static func _close(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g != null:
		g.store_py_code()
	var r := CommandResult.new()
	r.action = "py_close"
	r.line("Editor cerrado. Tu código está guardado: py lo vuelve a abrir.", "muted")
	return r


static func _error_lines(r: CommandResult, err: Dictionary) -> void:
	if err.is_empty():
		r.line("Error desconocido al ejecutar.", "error")
		return
	var where := " (línea %d)" % int(err["line"]) if int(err.get("line", 0)) > 0 else ""
	r.line("%s%s: %s" % [err.get("type", "Error"), where, err.get("message", "")], "error")


## El JSON no distingue 760 de 760.0: los números enteros de los casos pasan a int, como
## los escribiría el alumno en Python (rango([5]) devuelve 0, no 0.0).
static func _int_spec(ex: Dictionary) -> Dictionary:
	var spec := ex.duplicate(true)
	var cases: Array = []
	for cs: Dictionary in spec.get("cases", []):
		var c := cs.duplicate(true)
		c["args"] = _ints(c.get("args", []))
		if c.has("expected"):
			c["expected"] = _ints(c["expected"])
		cases.append(c)
	spec["cases"] = cases
	return spec


static func _ints(v: Variant) -> Variant:
	if v is float and is_finite(v) and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		return v.map(func(x: Variant) -> Variant: return _ints(x))
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[k] = _ints(v[k])
		return d
	return v


static func _args(args: Array) -> String:
	return ", ".join(PackedStringArray(args.map(func(v: Variant) -> String: return _show(v))))


## Valor en notación de Python (para las tablas de resultados).
static func _show(v: Variant) -> String:
	if v == null:
		return "None"
	if v is bool:
		return "True" if v else "False"
	if v is String:
		return "'%s'" % v
	if v is float:
		return str(snappedf(v, 0.000001))
	if v is Array:
		return "[" + ", ".join(PackedStringArray(v.map(func(x: Variant) -> String: return _show(x)))) + "]"
	if v is Dictionary:
		var parts := PackedStringArray()
		for k: Variant in v:
			parts.append("%s: %s" % [_show(k), _show(v[k])])
		return "{" + ", ".join(parts) + "}"
	return str(v)
