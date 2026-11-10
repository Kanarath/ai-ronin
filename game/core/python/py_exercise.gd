class_name PyExercise
extends RefCounted
## Corrector de ejercicios de Python del Dojo.
##
## spec = {
##   "function": "rango",                       # función que debe definir el alumno
##   "cases": [{"args": [[3, 9, 4]], "expected": 6, "tolerance": 0.0}],
##   "tolerance": 0.0,                          # opcional: tolerancia por defecto para floats
##   "max_steps": 200000,                       # opcional: límite de pasos por ejecución
## }
## Cada caso admite también "kwargs": {"nombre": valor}.
##
## check() devuelve:
##   {"ok": bool (el programa se pudo ejecutar), "passed": int, "total": int,
##    "results": [{"args", "expected", "got", "ok", "error", "output"}],
##    "error": {} | {"type", "line", "message"}, "output": PackedStringArray,
##    "missing_function": bool}
## Las comparaciones son profundas (listas y diccionarios) y los números se comparan con
## tolerancia; 6 y 6.0 se consideran iguales, pero True no es igual a 1.


static func check(source: String, spec: Dictionary) -> Dictionary:
	var fname := str(spec.get("function", ""))
	var cases: Array = spec.get("cases", [])
	var max_steps := int(spec.get("max_steps", 200000))
	var default_tol := float(spec.get("tolerance", 0.0))
	var vm := PyInterpreter.new()
	var run := vm.run(source, max_steps)
	var out := {
		"ok": run["ok"], "passed": 0, "total": cases.size(), "results": [],
		"error": run["error"], "output": run["output"], "missing_function": false,
	}
	if not run["ok"]:
		var why := "tu programa no se ha podido ejecutar: %s" % _describe_error(run["error"])
		for c: Dictionary in cases:
			out["results"].append(_result(c, null, false, {"type": run["error"]["type"], "line": run["error"]["line"], "message": why}, PackedStringArray()))
		vm.reset()
		return out
	if not vm.has_function(fname):
		var exists := vm.has_global(fname)
		var msg := ""
		if exists:
			msg = "'%s' existe pero no es una función: defínela con def %s(...):" % [fname, fname]
		else:
			msg = "no has definido la función '%s': escribe def %s(...): con ese nombre exacto" % [fname, fname]
		out["missing_function"] = true
		out["error"] = {"type": "NameError", "line": 0, "message": msg}
		for c: Dictionary in cases:
			out["results"].append(_result(c, null, false, out["error"], PackedStringArray()))
		vm.reset()
		return out
	var passed := 0
	for c: Dictionary in cases:
		var args: Array = c.get("args", [])
		var tol := float(c.get("tolerance", default_tol))
		var cr: Dictionary
		if c.has("kwargs") and not (c["kwargs"] as Dictionary).is_empty():
			cr = _call_with_kwargs(vm, fname, args, c["kwargs"], max_steps)
		else:
			cr = vm.call_function(fname, args.duplicate(true), max_steps)
		if not cr["ok"]:
			out["results"].append(_result(c, null, false, cr["error"], cr["output"]))
			continue
		var same := values_match(cr["value"], c.get("expected"), tol)
		if same:
			passed += 1
		out["results"].append(_result(c, cr["value"], same, {}, cr["output"]))
	out["passed"] = passed
	vm.reset()
	return out


static func _call_with_kwargs(vm: PyInterpreter, fname: String, args: Array, kwargs: Dictionary, max_steps: int) -> Dictionary:
	# Se llama desde Python para pasar argumentos con nombre: __dojo_kw__ es un global temporal.
	var names := PackedStringArray()
	var kw_py := {}
	for k: Variant in kwargs:
		if not str(k).is_valid_ascii_identifier():
			return {"ok": false, "output": PackedStringArray(), "value": null,
				"error": {"type": "ValueError", "line": 0, "message": "nombre de argumento no válido en el ejercicio: '%s'" % str(k)}}
		names.append("%s=__dojo_kw__[%s]" % [str(k), PyInterpreter.str_repr(str(k))])
		kw_py[str(k)] = kwargs[k]
	vm._globals.vars["__dojo_args__"] = vm.from_plain(args.duplicate(true))
	vm._globals.vars["__dojo_kw__"] = vm.from_plain(kw_py)
	var r := vm.run("__dojo_res__ = %s(*__dojo_args__, %s)" % [fname, ", ".join(names)], max_steps)
	var res := {"ok": r["ok"], "output": r["output"], "error": r["error"], "value": null}
	if r["ok"]:
		res["value"] = vm.get_global("__dojo_res__")
	for tmp: String in ["__dojo_args__", "__dojo_kw__", "__dojo_res__"]:
		vm._globals.vars.erase(tmp)
	return res


static func _result(c: Dictionary, got: Variant, ok: bool, error: Dictionary, output: PackedStringArray) -> Dictionary:
	return {"args": c.get("args", []), "expected": c.get("expected"), "got": got, "ok": ok, "error": error, "output": output}


static func _describe_error(e: Dictionary) -> String:
	if e.is_empty():
		return ""
	var where := " (línea %d)" % int(e["line"]) if int(e.get("line", 0)) > 0 else ""
	return "%s%s: %s" % [e["type"], where, e["message"]]


## Comparación profunda de datos de GDScript con tolerancia numérica.
static func values_match(got: Variant, expected: Variant, tolerance: float = 0.0, depth: int = 0) -> bool:
	if depth > 60:
		return false
	var tg := typeof(got)
	var te := typeof(expected)
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if tg in numeric and te in numeric:
		var a := float(got)
		var b := float(expected)
		if is_nan(a) or is_nan(b):
			return is_nan(a) and is_nan(b)
		if tolerance > 0.0:
			return absf(a - b) <= tolerance
		if tg == TYPE_INT and te == TYPE_INT:
			return got == expected
		return a == b
	if tg != te:
		if (tg == TYPE_STRING and te == TYPE_STRING_NAME) or (tg == TYPE_STRING_NAME and te == TYPE_STRING):
			return str(got) == str(expected)
		if tg == TYPE_ARRAY and te >= TYPE_PACKED_BYTE_ARRAY and te <= TYPE_PACKED_VECTOR4_ARRAY:
			return values_match(got, Array(expected), tolerance, depth)
		return false
	match tg:
		TYPE_NIL:
			return true
		TYPE_BOOL, TYPE_STRING:
			return got == expected
		TYPE_ARRAY:
			var a: Array = got
			var b: Array = expected
			if a.size() != b.size():
				return false
			for i in a.size():
				if not values_match(a[i], b[i], tolerance, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var a: Dictionary = got
			var b: Dictionary = expected
			if a.size() != b.size():
				return false
			for k: Variant in b:
				var found := false
				var match_key: Variant = null
				if a.has(k):
					found = true
					match_key = k
				else:
					for ka: Variant in a:
						if values_match(ka, k, 0.0, depth + 1):
							found = true
							match_key = ka
							break
				if not found or not values_match(a[match_key], b[k], tolerance, depth + 1):
					return false
			return true
	return false
