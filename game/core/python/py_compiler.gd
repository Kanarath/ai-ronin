class_name PyCompiler
extends RefCounted
## Traduce el AST de PyParser a PyCode (bytecode de pila).
##
## Nodos de sentencia: expr, assign, augassign, if, while, for, def, try, pass, break,
##   continue, return, global, nonlocal, import, from, raise, assert, del.
## Nodos de expresión: name, const, binop, unary, boolop, compare, ifexp, lambda, call,
##   subscript, slice, attr, tuple, list, dict, set, listcomp, genexp, setcomp, dictcomp,
##   fstring, starred.
##
## Ámbitos: como en Python, un nombre asignado dentro de una función es local salvo que se
## declare global/nonlocal. Los nombres libres se buscan en tiempo de ejecución en la cadena
## de ámbitos donde se definió la función (cierres), luego en los globales y los builtins.

var _error: Dictionary = {}
var _code: PyCode
var _sym: Dictionary = {}
## Pila de "cosas que deshacer" al salir con break/continue/return:
##   {"type": "loop", "is_for": bool, "continue": int, "breaks": Array}
##   {"type": "try"}  {"type": "finally", "body": Array}  {"type": "handler"}
var _unwind: Array = []
var _in_function := false


func compile_module(ast: Dictionary) -> Dictionary:
	_error = {}
	_code = PyCode.new()
	_code.is_module = true
	_code.name = "<module>"
	_sym = {"module": true, "locals": {}, "globals": {}, "nonlocals": {}}
	_unwind = []
	_in_function = false
	_compile_body(ast["body"])
	_code.emit(PyCode.CONST, null, _last_line(ast["body"]))
	_code.emit(PyCode.RETURN, null, _last_line(ast["body"]))
	if not _error.is_empty():
		return {"code": null, "error": _error}
	return {"code": _code, "error": {}}


func _last_line(body: Array) -> int:
	if body.is_empty():
		return 1
	return int(body.back()["line"])


func _fail(line: int, type: String, message: String) -> void:
	if _error.is_empty():
		_error = {"type": type, "line": line, "message": message}


# ── Análisis de nombres ──────────────────────────────────────────────────────

func _collect(body: Array, assigned: Dictionary, globals: Dictionary, nonlocals: Dictionary) -> void:
	for s: Dictionary in body:
		match s["k"]:
			"assign":
				for t: Dictionary in s["targets"]:
					_collect_target(t, assigned)
			"augassign":
				_collect_target(s["target"], assigned)
			"for":
				_collect_target(s["target"], assigned)
				_collect(s["body"], assigned, globals, nonlocals)
				_collect(s["orelse"], assigned, globals, nonlocals)
			"while":
				_collect(s["body"], assigned, globals, nonlocals)
				_collect(s["orelse"], assigned, globals, nonlocals)
			"if":
				_collect(s["body"], assigned, globals, nonlocals)
				_collect(s["orelse"], assigned, globals, nonlocals)
			"try":
				_collect(s["body"], assigned, globals, nonlocals)
				for h: Dictionary in s["handlers"]:
					if not str(h["name"]).is_empty():
						assigned[h["name"]] = true
					_collect(h["body"], assigned, globals, nonlocals)
				_collect(s["orelse"], assigned, globals, nonlocals)
				_collect(s["finalbody"], assigned, globals, nonlocals)
			"def", "class":
				assigned[s["name"]] = true
			"import":
				for item: Array in s["names"]:
					assigned[str(item[1]).split(".")[0]] = true
			"from":
				for item: Array in s["names"]:
					if item[1] != "*":
						assigned[item[1]] = true
			"del":
				for t: Dictionary in s["targets"]:
					_collect_target(t, assigned)
			"global":
				for n: String in s["names"]:
					globals[n] = true
			"nonlocal":
				for n: String in s["names"]:
					nonlocals[n] = true


func _collect_target(t: Dictionary, assigned: Dictionary) -> void:
	match t["k"]:
		"name":
			assigned[t["id"]] = true
		"tuple", "list":
			for e: Dictionary in t["elts"]:
				_collect_target(e, assigned)
		"starred":
			_collect_target(t["e"], assigned)


func _scope_of(name: String) -> String:
	if _sym["module"]:
		return "global"
	if _sym["globals"].has(name):
		return "global"
	if _sym["nonlocals"].has(name):
		return "deref"
	if _sym["locals"].has(name):
		return "local"
	return "deref"


func _emit_load(name: String, line: int) -> void:
	match _scope_of(name):
		"global":
			_code.emit(PyCode.LOAD_GLOBAL, name, line)
		"local":
			_code.emit(PyCode.LOAD_LOCAL, name, line)
		_:
			_code.emit(PyCode.LOAD_DEREF, name, line)


func _emit_store(name: String, line: int) -> void:
	match _scope_of(name):
		"global":
			_code.emit(PyCode.STORE_GLOBAL, name, line)
		"local":
			_code.emit(PyCode.STORE_LOCAL, name, line)
		_:
			_code.emit(PyCode.STORE_DEREF, name, line)


func _emit_del(name: String, line: int) -> void:
	match _scope_of(name):
		"global":
			_code.emit(PyCode.DEL_GLOBAL, name, line)
		"local":
			_code.emit(PyCode.DEL_LOCAL, name, line)
		_:
			_code.emit(PyCode.DEL_DEREF, name, line)


# ── Sentencias ───────────────────────────────────────────────────────────────

func _compile_body(body: Array) -> void:
	for s: Dictionary in body:
		if not _error.is_empty():
			return
		_compile_stmt(s)


func _compile_stmt(s: Dictionary) -> void:
	var line: int = s["line"]
	match s["k"]:
		"expr":
			_compile_expr(s["e"])
			_code.emit(PyCode.POP, null, line)
		"assign":
			_compile_expr(s["value"])
			var targets: Array = s["targets"]
			for i in targets.size():
				if i < targets.size() - 1:
					_code.emit(PyCode.DUP, null, line)
				_compile_store(targets[i])
		"augassign":
			_compile_augassign(s)
		"pass":
			pass
		"if":
			_compile_expr(s["test"])
			var jf := _code.emit(PyCode.POP_JUMP_IF_FALSE, -1, line)
			_compile_body(s["body"])
			if s["orelse"].is_empty():
				_code.patch(jf, _code.here())
			else:
				var je := _code.emit(PyCode.JUMP, -1, line)
				_code.patch(jf, _code.here())
				_compile_body(s["orelse"])
				_code.patch(je, _code.here())
		"while":
			var start := _code.here()
			_compile_expr(s["test"])
			var jf := _code.emit(PyCode.POP_JUMP_IF_FALSE, -1, line)
			var loop := {"type": "loop", "is_for": false, "continue": start, "breaks": []}
			_unwind.append(loop)
			_compile_body(s["body"])
			_unwind.pop_back()
			_code.emit(PyCode.JUMP, start, line)
			_code.patch(jf, _code.here())
			_compile_body(s["orelse"])
			for b: int in loop["breaks"]:
				_code.patch(b, _code.here())
		"for":
			_compile_expr(s["iter"])
			_code.emit(PyCode.GET_ITER, null, line)
			var start := _code.here()
			var fi := _code.emit(PyCode.FOR_ITER, -1, line)
			_compile_store(s["target"])
			var loop := {"type": "loop", "is_for": true, "continue": start, "breaks": []}
			_unwind.append(loop)
			_compile_body(s["body"])
			_unwind.pop_back()
			_code.emit(PyCode.JUMP, start, line)
			_code.patch(fi, _code.here())
			_compile_body(s["orelse"])
			for b: int in loop["breaks"]:
				_code.patch(b, _code.here())
		"break", "continue":
			var idx := _find_loop()
			if idx < 0:
				_fail(line, "SyntaxError", "'%s' fuera de un bucle: solo se puede usar dentro de un for o un while" % s["k"])
				return
			_emit_unwind(idx + 1, line)
			var loop: Dictionary = _unwind[idx]
			if s["k"] == "continue":
				_code.emit(PyCode.JUMP, loop["continue"], line)
			else:
				if loop["is_for"]:
					_code.emit(PyCode.POP, null, line)
				loop["breaks"].append(_code.emit(PyCode.JUMP, -1, line))
		"return":
			if not _in_function:
				_fail(line, "SyntaxError", "'return' fuera de una función")
				return
			if s["value"] == null:
				_code.emit(PyCode.CONST, null, line)
			else:
				_compile_expr(s["value"])
			_emit_unwind(0, line, true)
			_code.emit(PyCode.RETURN, null, line)
		"def":
			_compile_function_def(s)
			_emit_store(s["name"], line)
		"class":
			if s["base"] != null:
				_compile_expr(s["base"])
			else:
				_code.emit(PyCode.CONST, null, line)
			var names: Array = []
			for mem: Dictionary in s["members"]:
				if mem.has("value"):
					_compile_expr(mem["value"])
				else:
					_compile_function_def(mem["node"])
				names.append(mem["name"])
			_code.emit(PyCode.BUILD_CLASS, {"name": s["name"], "names": names}, line)
			_emit_store(s["name"], line)
		"global":
			pass
		"nonlocal":
			if not _in_function:
				_fail(line, "SyntaxError", "'nonlocal' solo tiene sentido dentro de una función anidada")
		"import":
			for item: Array in s["names"]:
				_code.emit(PyCode.IMPORT, item[0], line)
				_emit_store(str(item[1]).split(".")[0], line)
		"from":
			_code.emit(PyCode.IMPORT, s["module"], line)
			for item: Array in s["names"]:
				if item[0] == "*":
					if _in_function:
						_fail(line, "SyntaxError", "'from ... import *' solo se permite fuera de las funciones")
						return
					_code.emit(PyCode.IMPORT_STAR, null, line)
					return
				_code.emit(PyCode.DUP, null, line)
				_code.emit(PyCode.IMPORT_FROM, item[0], line)
				_emit_store(item[1], line)
			_code.emit(PyCode.POP, null, line)
		"raise":
			if s["exc"] == null:
				_code.emit(PyCode.RAISE, 0, line)
			else:
				_compile_expr(s["exc"])
				_code.emit(PyCode.RAISE, 1, line)
		"assert":
			_compile_expr(s["test"])
			var jt := _code.emit(PyCode.POP_JUMP_IF_TRUE, -1, line)
			if s["msg"] == null:
				_code.emit(PyCode.CONST, null, line)
				_code.emit(PyCode.RAISE_ASSERT, false, line)
			else:
				_compile_expr(s["msg"])
				_code.emit(PyCode.RAISE_ASSERT, true, line)
			_code.patch(jt, _code.here())
		"del":
			for t: Dictionary in s["targets"]:
				_compile_del(t)
		"try":
			_compile_try(s)
		_:
			_fail(line, "SyntaxError", "sentencia no soportada: %s" % s["k"])


func _find_loop() -> int:
	var i := _unwind.size() - 1
	while i >= 0:
		var e: Dictionary = _unwind[i]
		if e["type"] == "loop":
			return i
		i -= 1
	return -1


## Deshace los bloques de _unwind[from_index..] (de dentro afuera) antes de saltar fuera.
func _emit_unwind(from_index: int, line: int, is_return: bool = false) -> void:
	var i := _unwind.size() - 1
	while i >= from_index:
		var e: Dictionary = _unwind[i]
		match e["type"]:
			"try":
				if not is_return:
					_code.emit(PyCode.POP_BLOCK, null, line)
			"handler":
				if not is_return:
					_code.emit(PyCode.POP_EXCEPT, null, line)
			"finally":
				_code.emit(PyCode.POP_BLOCK, null, line)
				var saved := _unwind
				_unwind = _unwind.slice(0, i)
				_compile_body(e["body"])
				_unwind = saved
		i -= 1


func _compile_try(s: Dictionary) -> void:
	var line: int = s["line"]
	var has_final: bool = not s["finalbody"].is_empty()
	var fin_setup := -1
	if has_final:
		fin_setup = _code.emit(PyCode.SETUP_EXCEPT, -1, line)
		_unwind.append({"type": "finally", "body": s["finalbody"]})
	if not s["handlers"].is_empty():
		var setup := _code.emit(PyCode.SETUP_EXCEPT, -1, line)
		_unwind.append({"type": "try"})
		_compile_body(s["body"])
		_unwind.pop_back()
		_code.emit(PyCode.POP_BLOCK, null, line)
		_compile_body(s["orelse"])
		var end_jumps: Array[int] = [_code.emit(PyCode.JUMP, -1, line)]
		_code.patch(setup, _code.here())
		_unwind.append({"type": "handler"})
		for h: Dictionary in s["handlers"]:
			var hline: int = h["line"]
			var next_jump := -1
			if h["types"] != null:
				_code.emit(PyCode.DUP, null, hline)
				_compile_expr(h["types"])
				_code.emit(PyCode.EXC_MATCH, null, hline)
				next_jump = _code.emit(PyCode.POP_JUMP_IF_FALSE, -1, hline)
			if str(h["name"]).is_empty():
				_code.emit(PyCode.POP, null, hline)
			else:
				_emit_store(h["name"], hline)
			_compile_body(h["body"])
			_code.emit(PyCode.POP_EXCEPT, null, hline)
			end_jumps.append(_code.emit(PyCode.JUMP, -1, hline))
			if next_jump >= 0:
				_code.patch(next_jump, _code.here())
		_unwind.pop_back()
		_code.emit(PyCode.RERAISE, null, line)
		for j in end_jumps:
			_code.patch(j, _code.here())
	else:
		_compile_body(s["body"])
	if has_final:
		_unwind.pop_back()
		_code.emit(PyCode.POP_BLOCK, null, line)
		_compile_body(s["finalbody"])
		var je := _code.emit(PyCode.JUMP, -1, line)
		_code.patch(fin_setup, _code.here())
		_compile_body(s["finalbody"])
		_code.emit(PyCode.RERAISE, null, line)
		_code.patch(je, _code.here())


func _compile_store(t: Dictionary) -> void:
	var line: int = t["line"]
	match t["k"]:
		"name":
			_emit_store(t["id"], line)
		"subscript":
			_compile_expr(t["value"])
			_compile_index(t["index"])
			_code.emit(PyCode.STORE_SUBSCR, null, line)
		"attr":
			_compile_expr(t["value"])
			_code.emit(PyCode.STORE_ATTR, t["name"], line)
		"tuple", "list":
			var elts: Array = t["elts"]
			var star := -1
			for i in elts.size():
				if elts[i]["k"] == "starred":
					star = i
			if star < 0:
				_code.emit(PyCode.UNPACK, elts.size(), line)
				for e: Dictionary in elts:
					_compile_store(e)
			else:
				_code.emit(PyCode.UNPACK_EX, [star, elts.size() - star - 1], line)
				for e: Dictionary in elts:
					_compile_store(e["e"] if e["k"] == "starred" else e)
		_:
			_fail(line, "SyntaxError", "no se puede asignar a esa expresión")


func _compile_del(t: Dictionary) -> void:
	var line: int = t["line"]
	match t["k"]:
		"name":
			_emit_del(t["id"], line)
		"subscript":
			_compile_expr(t["value"])
			_compile_index(t["index"])
			_code.emit(PyCode.DEL_SUBSCR, null, line)
		"tuple", "list":
			for e: Dictionary in t["elts"]:
				_compile_del(e)
		_:
			_fail(line, "SyntaxError", "no se puede borrar esa expresión")


func _compile_augassign(s: Dictionary) -> void:
	var t: Dictionary = s["target"]
	var line: int = s["line"]
	match t["k"]:
		"name":
			_emit_load(t["id"], line)
			_compile_expr(s["value"])
			_code.emit(PyCode.INPLACE, s["op"], line)
			_emit_store(t["id"], line)
		"subscript":
			_compile_expr(t["value"])
			_compile_index(t["index"])
			_code.emit(PyCode.DUP2, null, line)
			_code.emit(PyCode.SUBSCR, null, line)
			_compile_expr(s["value"])
			_code.emit(PyCode.INPLACE, s["op"], line)
			_code.emit(PyCode.ROT3, null, line)
			_code.emit(PyCode.STORE_SUBSCR, null, line)
		"attr":
			_compile_expr(t["value"])
			_code.emit(PyCode.DUP, null, line)
			_code.emit(PyCode.LOAD_ATTR, t["name"], line)
			_compile_expr(s["value"])
			_code.emit(PyCode.INPLACE, s["op"], line)
			_code.emit(PyCode.ROT2, null, line)
			_code.emit(PyCode.STORE_ATTR, t["name"], line)


# ── Funciones ────────────────────────────────────────────────────────────────

## Compila un def o lambda y deja la función en la pila.
func _compile_function_def(s: Dictionary) -> void:
	var line: int = s["line"]
	var kw_default_names: Array = []
	var n_defaults := 0
	for p: Dictionary in s["params"]:
		if p["default"] != null and not p["kwonly"]:
			_compile_expr(p["default"])
			n_defaults += 1
	for p: Dictionary in s["params"]:
		if p["default"] != null and p["kwonly"]:
			_compile_expr(p["default"])
			kw_default_names.append(p["name"])
	var is_lambda: bool = s["k"] == "lambda"
	var body: Array = s["body"] if not is_lambda else [{"k": "return", "line": line, "value": s["body"]}]
	var code := _compile_function_code(s.get("name", "<lambda>"), s["params"], s["vararg"], s["kwarg"], body)
	_code.emit(PyCode.MAKE_FUNCTION, {"code": code, "n_defaults": n_defaults, "kw_defaults": kw_default_names}, line)


func _compile_function_code(fname: String, params: Array, vararg: String, kwarg: String, body: Array) -> PyCode:
	var saved_code := _code
	var saved_sym := _sym
	var saved_unwind := _unwind
	var saved_in_fn := _in_function
	var code := PyCode.new()
	code.name = fname
	for p: Dictionary in params:
		if p["kwonly"]:
			code.kwonly.append(p["name"])
		else:
			code.params.append(p["name"])
	code.vararg = vararg
	code.kwarg = kwarg
	var assigned := {}
	var globals := {}
	var nonlocals := {}
	_collect(body, assigned, globals, nonlocals)
	for p: Dictionary in params:
		assigned[p["name"]] = true
	if not vararg.is_empty():
		assigned[vararg] = true
	if not kwarg.is_empty():
		assigned[kwarg] = true
	for g: String in globals:
		assigned.erase(g)
	for n: String in nonlocals:
		assigned.erase(n)
	_code = code
	_sym = {"module": false, "locals": assigned, "globals": globals, "nonlocals": nonlocals}
	_unwind = []
	_in_function = true
	_compile_body(body)
	var last := _last_line(body)
	code.emit(PyCode.CONST, null, last)
	code.emit(PyCode.RETURN, null, last)
	_code = saved_code
	_sym = saved_sym
	_unwind = saved_unwind
	_in_function = saved_in_fn
	return code


func _compile_comprehension(e: Dictionary) -> void:
	var line: int = e["line"]
	var gens: Array = e["gens"]
	var saved_code := _code
	var saved_sym := _sym
	var saved_unwind := _unwind
	var saved_in_fn := _in_function
	var code := PyCode.new()
	code.name = "<" + str(e["k"]) + ">"
	code.params.append(".0")
	var assigned := {".0": true, ".r": true}
	for g: Dictionary in gens:
		_collect_target(g["target"], assigned)
	_code = code
	_sym = {"module": false, "locals": assigned, "globals": {}, "nonlocals": {}}
	_unwind = []
	_in_function = true
	match e["k"]:
		"dictcomp":
			code.emit(PyCode.BUILD_DICT, 0, line)
		"setcomp":
			code.emit(PyCode.BUILD_SET, 0, line)
		_:
			code.emit(PyCode.BUILD_LIST, 0, line)
	code.emit(PyCode.STORE_LOCAL, ".r", line)
	_compile_comp_gen(e, 0)
	code.emit(PyCode.LOAD_LOCAL, ".r", line)
	code.emit(PyCode.RETURN, null, line)
	_code = saved_code
	_sym = saved_sym
	_unwind = saved_unwind
	_in_function = saved_in_fn
	_code.emit(PyCode.MAKE_FUNCTION, {"code": code, "n_defaults": 0, "kw_defaults": []}, line)
	_compile_expr(gens[0]["iter"])
	_code.emit(PyCode.GET_ITER, null, line)
	_code.emit(PyCode.CALL, [1, [], false, false], line)


func _compile_comp_gen(e: Dictionary, idx: int) -> void:
	var g: Dictionary = e["gens"][idx]
	var line: int = e["line"]
	if idx == 0:
		_code.emit(PyCode.LOAD_LOCAL, ".0", line)
	else:
		_compile_expr(g["iter"])
		_code.emit(PyCode.GET_ITER, null, line)
	var start := _code.here()
	var fi := _code.emit(PyCode.FOR_ITER, -1, line)
	_compile_store(g["target"])
	for cond: Dictionary in g["ifs"]:
		_compile_expr(cond)
		_code.emit(PyCode.POP_JUMP_IF_FALSE, start, line)
	if idx + 1 < e["gens"].size():
		_compile_comp_gen(e, idx + 1)
	else:
		_code.emit(PyCode.LOAD_LOCAL, ".r", line)
		match e["k"]:
			"dictcomp":
				_compile_expr(e["elt"])
				_compile_expr(e["value"])
				_code.emit(PyCode.DICT_SET, null, line)
			"setcomp":
				_compile_expr(e["elt"])
				_code.emit(PyCode.SET_ADD, null, line)
			_:
				_compile_expr(e["elt"])
				_code.emit(PyCode.LIST_APPEND, null, line)
	_code.emit(PyCode.JUMP, start, line)
	_code.patch(fi, _code.here())


# ── Expresiones ──────────────────────────────────────────────────────────────

func _compile_expr(e: Dictionary) -> void:
	if not _error.is_empty():
		return
	var line: int = e["line"]
	match e["k"]:
		"const":
			_code.emit(PyCode.CONST, e["v"], line)
		"name":
			_emit_load(e["id"], line)
		"binop":
			_compile_expr(e["l"])
			_compile_expr(e["r"])
			_code.emit(PyCode.BINARY, e["op"], line)
		"unary":
			_compile_expr(e["e"])
			_code.emit(PyCode.UNARY, e["op"], line)
		"boolop":
			_compile_expr(e["l"])
			var op := PyCode.JUMP_IF_FALSE_OR_POP if e["op"] == "and" else PyCode.JUMP_IF_TRUE_OR_POP
			var j := _code.emit(op, -1, line)
			_compile_expr(e["r"])
			_code.patch(j, _code.here())
		"compare":
			_compile_compare(e)
		"ifexp":
			_compile_expr(e["test"])
			var jf := _code.emit(PyCode.POP_JUMP_IF_FALSE, -1, line)
			_compile_expr(e["body"])
			var je := _code.emit(PyCode.JUMP, -1, line)
			_code.patch(jf, _code.here())
			_compile_expr(e["orelse"])
			_code.patch(je, _code.here())
		"lambda":
			_compile_function_def(e)
		"call":
			_compile_expr(e["func"])
			for a: Dictionary in e["args"]:
				if a["k"] == "starred":
					_compile_expr(a["e"])
					_code.emit(PyCode.STAR, null, int(a["line"]))
				else:
					_compile_expr(a)
			var names: Array = []
			for kw: Array in e["kwargs"]:
				_compile_expr(kw[1])
				names.append(kw[0])
			var dstar: bool = e["dstar"] != null
			if dstar:
				_compile_expr(e["dstar"])
			var has_star := false
			for a: Dictionary in e["args"]:
				if a["k"] == "starred":
					has_star = true
			# [n posicionales, nombres de los argumentos con nombre, hay **, hay *]
			_code.emit(PyCode.CALL, [e["args"].size(), names, dstar, has_star], line)
		"subscript":
			_compile_expr(e["value"])
			_compile_index(e["index"])
			_code.emit(PyCode.SUBSCR, null, line)
		"attr":
			_compile_expr(e["value"])
			_code.emit(PyCode.LOAD_ATTR, e["name"], line)
		"tuple", "list", "set":
			for x: Dictionary in e["elts"]:
				if x["k"] == "starred":
					_compile_expr(x["e"])
					_code.emit(PyCode.STAR, null, int(x["line"]))
				else:
					_compile_expr(x)
			var op := {"tuple": PyCode.BUILD_TUPLE, "list": PyCode.BUILD_LIST, "set": PyCode.BUILD_SET}[e["k"]] as int
			_code.emit(op, e["elts"].size(), line)
		"dict":
			for i in e["keys"].size():
				_compile_expr(e["keys"][i])
				_compile_expr(e["values"][i])
			_code.emit(PyCode.BUILD_DICT, e["keys"].size(), line)
		"listcomp", "genexp", "setcomp", "dictcomp":
			_compile_comprehension(e)
		"fstring":
			var n := 0
			for p: Variant in e["parts"]:
				if p is String:
					_code.emit(PyCode.CONST, p, line)
				else:
					var field: Dictionary = p
					_compile_expr(field["e"])
					var has_spec: bool = field["spec"] != null
					if has_spec:
						_compile_expr(field["spec"])
					_code.emit(PyCode.FORMAT, {"conv": field["conv"], "spec": has_spec}, line)
				n += 1
			_code.emit(PyCode.BUILD_STRING, n, line)
		"starred":
			_fail(line, "SyntaxError", "no se puede usar '*' aquí")
		"slice":
			_fail(line, "SyntaxError", "los ':' de un slice solo pueden ir dentro de [ ]")
		_:
			_fail(line, "SyntaxError", "expresión no soportada: %s" % e["k"])


func _compile_index(index: Dictionary) -> void:
	if index["k"] == "slice":
		for part: String in ["lo", "hi", "step"]:
			if index[part] == null:
				_code.emit(PyCode.CONST, null, int(index["line"]))
			else:
				_compile_expr(index[part])
		_code.emit(PyCode.BUILD_SLICE, null, int(index["line"]))
	elif index["k"] == "tuple":
		for x: Dictionary in index["elts"]:
			_compile_index(x)
		_code.emit(PyCode.BUILD_TUPLE, index["elts"].size(), int(index["line"]))
	else:
		_compile_expr(index)


func _compile_compare(e: Dictionary) -> void:
	var line: int = e["line"]
	var ops: Array = e["ops"]
	var rest: Array = e["rest"]
	_compile_expr(e["first"])
	if ops.size() == 1:
		_compile_expr(rest[0])
		_code.emit(PyCode.COMPARE, ops[0], line)
		return
	var cleanups: Array[int] = []
	for i in ops.size() - 1:
		_compile_expr(rest[i])
		_code.emit(PyCode.DUP, null, line)
		_code.emit(PyCode.ROT3, null, line)
		_code.emit(PyCode.COMPARE, ops[i], line)
		cleanups.append(_code.emit(PyCode.JUMP_IF_FALSE_OR_POP, -1, line))
	_compile_expr(rest[ops.size() - 1])
	_code.emit(PyCode.COMPARE, ops[ops.size() - 1], line)
	var je := _code.emit(PyCode.JUMP, -1, line)
	for c in cleanups:
		_code.patch(c, _code.here())
	_code.emit(PyCode.ROT2, null, line)
	_code.emit(PyCode.POP, null, line)
	_code.patch(je, _code.here())
