class_name PyParser
extends RefCounted
## Analizador sintáctico (descenso recursivo) del Python del Dojo.
##
## parse(fuente) → {"ast": {"k": "module", "body": [...]}, "error": {} | {"type","line","message"}}
## Los nodos son Dictionaries con "k" (tipo de nodo) y "line". Ver docs al principio de
## py_compiler.gd para la lista de nodos.

const MAX_NESTING := 60

const _COMPARE_OPS := {"<": true, ">": true, "==": true, ">=": true, "<=": true, "!=": true}
const _AUG_OPS := {"+=": "+", "-=": "-", "*=": "*", "/=": "/", "//=": "//", "%=": "%", "**=": "**",
	"&=": "&", "|=": "|", "^=": "^", "<<=": "<<", ">>=": ">>"}

var _toks: Array[Dictionary] = []
var _i := 0
var _error: Dictionary = {}
var _nesting := 0
var _eof_tok: Dictionary = {"t": "eof", "v": null, "line": 1}


func parse(source: String) -> Dictionary:
	var lex := PyLexer.new().tokenize(source)
	if not lex["error"].is_empty():
		return {"ast": {}, "error": lex["error"]}
	return parse_tokens(lex["tokens"])


func parse_tokens(tokens: Array[Dictionary]) -> Dictionary:
	_toks = tokens
	_i = 0
	_error = {}
	_nesting = 0
	if not _toks.is_empty():
		_eof_tok = _toks.back()
	var body: Array = []
	while not _failed() and not _at("eof"):
		if _at("nl"):
			_i += 1
			continue
		if _at("indent"):
			_fail_at(_peek(), "IndentationError", "indentación inesperada: esta línea tiene más sangría que la anterior sin motivo")
			break
		_parse_statement(body)
	if not _error.is_empty():
		return {"ast": {}, "error": _error}
	return {"ast": {"k": "module", "body": body, "line": 1}, "error": {}}


## Analiza una expresión suelta (para los campos de las f-strings).
func parse_expression_text(text: String, line: int) -> Dictionary:
	var lex := PyLexer.new().tokenize("(" + text + "\n)", line - 1)
	if not lex["error"].is_empty():
		var e: Dictionary = lex["error"]
		e["line"] = line
		return {"ast": {}, "error": e}
	_toks = lex["tokens"]
	_i = 0
	_error = {}
	_eof_tok = _toks.back()
	var node := _parse_testlist()
	if _failed():
		_error["line"] = line
		return {"ast": {}, "error": _error}
	if not _at("nl") and not _at("eof"):
		return {"ast": {}, "error": {"type": "SyntaxError", "line": line, "message": "f-string: expresión no válida dentro de {...}"}}
	return {"ast": node, "error": {}}


# ── Utilidades de tokens ─────────────────────────────────────────────────────

func _failed() -> bool:
	return not _error.is_empty()


func _peek(offset: int = 0) -> Dictionary:
	if _failed():
		return _eof_tok
	var j := _i + offset
	if j < _toks.size():
		return _toks[j]
	return _eof_tok


func _at(type: String) -> bool:
	return _peek()["t"] == type


func _at_op(op: String) -> bool:
	var t := _peek()
	return t["t"] == "op" and t["v"] == op


func _at_kw(kw: String) -> bool:
	var t := _peek()
	return t["t"] == "kw" and t["v"] == kw


func _advance() -> Dictionary:
	var t := _peek()
	if not _failed() and _i < _toks.size():
		_i += 1
	return t


func _accept_op(op: String) -> bool:
	if _at_op(op):
		_i += 1
		return true
	return false


func _accept_kw(kw: String) -> bool:
	if _at_kw(kw):
		_i += 1
		return true
	return false


func _expect_op(op: String, message: String = "") -> void:
	if _accept_op(op):
		return
	if message.is_empty():
		message = "se esperaba '%s'" % op
		if not _at("nl") and not _at("eof"):
			message += " antes de %s" % _describe(_peek())
	_fail_at(_peek(), "SyntaxError", message)


func _expect_colon(after: String) -> void:
	if _at_op(":"):
		_i += 1
		return
	if _at_op("="):
		_fail_at(_peek(), "SyntaxError", "sintaxis no válida: para comparar se usa '==' (con un solo '=' se asigna)")
		return
	_fail_at(_peek(), "SyntaxError", "falta ':' al final de la línea de '%s'" % after)


func _expect_name(what: String) -> String:
	var t := _peek()
	if t["t"] == "name":
		_i += 1
		return t["v"]
	if t["t"] == "kw":
		_fail_at(t, "SyntaxError", "'%s' es una palabra reservada de Python y no se puede usar como %s" % [t["v"], what])
	else:
		_fail_at(t, "SyntaxError", "se esperaba un nombre (%s)" % what)
	return ""


func _describe(t: Dictionary) -> String:
	match t["t"]:
		"name", "kw", "op":
			return "'%s'" % t["v"]
		"num":
			return "el número %s" % str(t["v"])
		"str", "fstr":
			return "una cadena"
		"nl":
			return "el final de la línea"
		"indent", "dedent":
			return "la indentación"
		"eof":
			return "el final del programa"
	return "'%s'" % str(t["v"])


func _fail_at(t: Dictionary, type: String, message: String) -> void:
	if _error.is_empty():
		_error = {"type": type, "line": int(t["line"]), "message": message}


func _syntax_error_here() -> void:
	var t := _peek()
	if t["t"] == "indent":
		_fail_at(t, "IndentationError", "indentación inesperada")
	elif t["t"] == "nl" or t["t"] == "eof":
		_fail_at(t, "SyntaxError", "sintaxis no válida: la línea termina de forma inesperada")
	else:
		_fail_at(t, "SyntaxError", "sintaxis no válida cerca de %s" % _describe(t))


func _enter() -> bool:
	_nesting += 1
	if _nesting > MAX_NESTING:
		_fail_at(_peek(), "SyntaxError", "expresión demasiado anidada para el Dojo")
		return false
	return true


func _leave() -> void:
	_nesting -= 1


# ── Sentencias ───────────────────────────────────────────────────────────────

func _parse_statement(out: Array) -> void:
	var t := _peek()
	if t["t"] == "kw":
		match t["v"]:
			"if":
				out.append(_parse_if())
				return
			"while":
				out.append(_parse_while())
				return
			"for":
				out.append(_parse_for())
				return
			"def":
				out.append(_parse_def())
				return
			"try":
				out.append(_parse_try())
				return
			"class":
				_fail_at(t, "SyntaxError", "las clases (class) todavía no están disponibles en el Dojo")
				return
			"with":
				_fail_at(t, "SyntaxError", "'with' no está disponible en el Dojo (no hay ficheros que abrir)")
				return
			"async", "await":
				_fail_at(t, "SyntaxError", "'%s' no está disponible en el Dojo" % t["v"])
				return
			"elif", "else", "except", "finally":
				_fail_at(t, "SyntaxError", "'%s' sin su 'if'/'try' correspondiente (¿revisa la indentación?)" % t["v"])
				return
	if t["t"] == "op" and t["v"] == "@":
		_fail_at(t, "SyntaxError", "los decoradores (@) no están disponibles en el Dojo")
		return
	_parse_simple_line(out)


func _parse_simple_line(out: Array) -> void:
	while not _failed():
		out.append(_parse_small())
		if _failed():
			return
		if _accept_op(";"):
			if _at("nl") or _at("eof"):
				break
			continue
		break
	if _at("nl"):
		_i += 1
	elif not _at("eof") and not _at("dedent"):
		_syntax_error_here()


func _parse_block(after: String) -> Array:
	var body: Array = []
	var head_line := int(_peek(-1)["line"]) if _i > 0 else 1
	if not _at("nl"):
		# cuerpo en la misma línea: if x: y = 1
		_parse_simple_line(body)
		return body
	_i += 1
	while _at("nl"):
		_i += 1
	if not _at("indent"):
		_fail_at(_peek(), "IndentationError", "se esperaba un bloque con sangría después de '%s' (línea %d)" % [after, head_line])
		return body
	_i += 1
	while not _failed() and not _at("dedent") and not _at("eof"):
		if _at("nl"):
			_i += 1
			continue
		if _at("indent"):
			_fail_at(_peek(), "IndentationError", "indentación inesperada")
			return body
		_parse_statement(body)
	if _at("dedent"):
		_i += 1
	return body


func _parse_if() -> Dictionary:
	var t := _advance()
	var test := _parse_named_test()
	_expect_colon(t["v"])
	var body := _parse_block(t["v"])
	var node := {"k": "if", "line": t["line"], "test": test, "body": body, "orelse": []}
	if _at_kw("elif"):
		node["orelse"] = [_parse_if()]
	elif _at_kw("else"):
		_i += 1
		_expect_colon("else")
		node["orelse"] = _parse_block("else")
	return node


func _parse_while() -> Dictionary:
	var t := _advance()
	var test := _parse_named_test()
	_expect_colon("while")
	var body := _parse_block("while")
	var orelse: Array = []
	if _accept_kw("else"):
		_expect_colon("else")
		orelse = _parse_block("else")
	return {"k": "while", "line": t["line"], "test": test, "body": body, "orelse": orelse}


func _parse_for() -> Dictionary:
	var t := _advance()
	var target := _parse_target_list()
	if not _accept_kw("in"):
		_fail_at(_peek(), "SyntaxError", "en un 'for' falta 'in': for variable in secuencia:")
	var iter := _parse_testlist()
	_expect_colon("for")
	var body := _parse_block("for")
	var orelse: Array = []
	if _accept_kw("else"):
		_expect_colon("else")
		orelse = _parse_block("else")
	return {"k": "for", "line": t["line"], "target": target, "iter": iter, "body": body, "orelse": orelse}


func _parse_def() -> Dictionary:
	var t := _advance()
	var name := _expect_name("nombre de función")
	if not _at_op("("):
		_fail_at(_peek(), "SyntaxError", "después del nombre de la función van los paréntesis: def %s(...):" % name)
	_i += 1 if not _failed() else 0
	var params := _parse_params(")")
	_expect_op(")")
	if _accept_op("->"):
		_parse_test()
	_expect_colon("def")
	var body := _parse_block("def")
	var node := {"k": "def", "line": t["line"], "name": name, "body": body}
	node.merge(params)
	return node


## Parámetros hasta `closer` (")" para def, ":" para lambda).
func _parse_params(closer: String) -> Dictionary:
	var params: Array = []
	var vararg := ""
	var kwarg := ""
	var kwonly := false
	var seen_default := false
	while not _failed() and not _at_op(closer):
		if _accept_op("**"):
			kwarg = _expect_name("parámetro")
			if closer == ")" and _accept_op(":"):
				_parse_test()
		elif _accept_op("*"):
			if _at_op(",") or _at_op(closer):
				kwonly = true
			else:
				vararg = _expect_name("parámetro")
				kwonly = true
				if closer == ")" and _accept_op(":"):
					_parse_test()
		elif _accept_op("/"):
			pass
		else:
			var pt := _peek()
			var pname := _expect_name("parámetro")
			if closer == ")" and _accept_op(":"):
				_parse_test()
			var default: Variant = null
			if _accept_op("="):
				default = _parse_test()
				seen_default = true
			elif seen_default and not kwonly:
				_fail_at(pt, "SyntaxError", "el parámetro '%s' no tiene valor por defecto pero va después de otro que sí lo tiene" % pname)
			for p: Dictionary in params:
				if p["name"] == pname:
					_fail_at(pt, "SyntaxError", "el parámetro '%s' está repetido" % pname)
			params.append({"name": pname, "default": default, "kwonly": kwonly})
		if not _accept_op(","):
			break
	return {"params": params, "vararg": vararg, "kwarg": kwarg}


func _parse_try() -> Dictionary:
	var t := _advance()
	_expect_colon("try")
	var body := _parse_block("try")
	var handlers: Array = []
	while _at_kw("except") and not _failed():
		var et := _advance()
		var types: Variant = null
		var name := ""
		if not _at_op(":"):
			types = _parse_test()
			if _accept_op(","):
				var elts: Array = [types]
				while not _at_op(":") and not _at_kw("as") and not _failed():
					elts.append(_parse_test())
					if not _accept_op(","):
						break
				types = {"k": "tuple", "line": et["line"], "elts": elts}
			if _accept_kw("as"):
				name = _expect_name("variable de la excepción")
		_expect_colon("except")
		handlers.append({"types": types, "name": name, "body": _parse_block("except"), "line": et["line"]})
	var orelse: Array = []
	var finalbody: Array = []
	if _at_kw("else"):
		if handlers.is_empty():
			_fail_at(_peek(), "SyntaxError", "'else' en un 'try' necesita al menos un 'except'")
		_i += 1
		_expect_colon("else")
		orelse = _parse_block("else")
	if _accept_kw("finally"):
		_expect_colon("finally")
		finalbody = _parse_block("finally")
	if handlers.is_empty() and finalbody.is_empty() and not _failed():
		_fail_at(_peek(), "SyntaxError", "un 'try' necesita al menos un 'except' o un 'finally'")
	return {"k": "try", "line": t["line"], "body": body, "handlers": handlers, "orelse": orelse, "finalbody": finalbody}


func _parse_small() -> Dictionary:
	var t := _peek()
	var line: int = t["line"]
	if t["t"] == "kw":
		match t["v"]:
			"pass":
				_i += 1
				return {"k": "pass", "line": line}
			"break":
				_i += 1
				return {"k": "break", "line": line}
			"continue":
				_i += 1
				return {"k": "continue", "line": line}
			"return":
				_i += 1
				var value: Variant = null
				if not _at_end_of_small():
					value = _parse_testlist()
				return {"k": "return", "line": line, "value": value}
			"global", "nonlocal":
				_i += 1
				var names: Array = [_expect_name("variable")]
				while _accept_op(","):
					names.append(_expect_name("variable"))
				return {"k": t["v"], "line": line, "names": names}
			"import":
				_i += 1
				var items: Array = []
				while not _failed():
					var mod := _parse_dotted()
					var asname := mod
					if _accept_kw("as"):
						asname = _expect_name("alias")
					items.append([mod, asname])
					if not _accept_op(","):
						break
				return {"k": "import", "line": line, "names": items}
			"from":
				_i += 1
				var mod := _parse_dotted()
				if not _accept_kw("import"):
					_fail_at(_peek(), "SyntaxError", "se esperaba 'import': from %s import nombre" % mod)
				var items: Array = []
				if _accept_op("*"):
					items.append(["*", "*"])
				else:
					var paren := _accept_op("(")
					while not _failed():
						var nm := _expect_name("nombre a importar")
						var asname := nm
						if _accept_kw("as"):
							asname = _expect_name("alias")
						items.append([nm, asname])
						if not _accept_op(","):
							break
						if paren and _at_op(")"):
							break
					if paren:
						_expect_op(")")
				return {"k": "from", "line": line, "module": mod, "names": items}
			"raise":
				_i += 1
				var exc: Variant = null
				if not _at_end_of_small():
					exc = _parse_test()
					if _accept_kw("from"):
						_parse_test()
				return {"k": "raise", "line": line, "exc": exc}
			"assert":
				_i += 1
				var test := _parse_test()
				var msg: Variant = null
				if _accept_op(","):
					msg = _parse_test()
				return {"k": "assert", "line": line, "test": test, "msg": msg}
			"del":
				_i += 1
				var targets: Array = []
				while not _failed():
					var tg := _parse_or_expr()
					_check_target(tg, "del")
					targets.append(tg)
					if not _accept_op(","):
						break
					if _at_end_of_small():
						break
				return {"k": "del", "line": line, "targets": targets}
			"yield":
				_fail_at(t, "SyntaxError", "'yield' (generadores) no está disponible en el Dojo: devuelve una lista con return")
				return {"k": "pass", "line": line}
	# expresión, asignación o asignación aumentada
	var first := _parse_testlist(true)
	if _failed():
		return {"k": "pass", "line": line}
	var nt := _peek()
	if nt["t"] == "op" and _AUG_OPS.has(nt["v"]):
		_i += 1
		if first["k"] not in ["name", "subscript", "attr"]:
			_fail_at(nt, "SyntaxError", "no se puede usar '%s' con %s" % [nt["v"], _what(first)])
		var value := _parse_testlist()
		return {"k": "augassign", "line": line, "target": first, "op": _AUG_OPS[nt["v"]], "value": value}
	if nt["t"] == "op" and nt["v"] == ":" and first["k"] in ["name", "subscript", "attr"]:
		# anotación de tipo: x: int = 5 (la anotación se ignora)
		_i += 1
		_parse_test()
		if _accept_op("="):
			_check_target(first, "assign")
			return {"k": "assign", "line": line, "targets": [first], "value": _parse_testlist()}
		return {"k": "pass", "line": line}
	if nt["t"] == "op" and nt["v"] == "=":
		var targets: Array = [first]
		var value: Dictionary = {}
		while _accept_op("="):
			value = _parse_testlist(true)
			if _at_op("="):
				targets.append(value)
		for tg: Dictionary in targets:
			_check_target(tg, "assign")
		return {"k": "assign", "line": line, "targets": targets, "value": value}
	if not _at_end_of_small():
		if first["k"] == "name" and first["id"] == "print" and (nt["t"] == "str" or nt["t"] == "name" or nt["t"] == "num" or nt["t"] == "fstr"):
			_fail_at(nt, "SyntaxError", "faltan los paréntesis en la llamada a 'print': ¿querías decir print(...)?")
		elif first["k"] == "name" and (nt["t"] == "name" or nt["t"] == "num" or nt["t"] == "str"):
			_fail_at(nt, "SyntaxError", "sintaxis no válida: ¿falta una coma, un operador o unos paréntesis entre '%s' y %s?" % [first["id"], _describe(nt)])
		elif nt["t"] == "op" and nt["v"] == ":=":
			_fail_at(nt, "SyntaxError", "el operador morsa ':=' no está disponible en el Dojo")
		else:
			_syntax_error_here()
	if first["k"] == "starred":
		_fail_at(nt, "SyntaxError", "no se puede usar '*' aquí")
	return {"k": "expr", "line": line, "e": first}


func _at_end_of_small() -> bool:
	return _at("nl") or _at("eof") or _at_op(";") or _at("dedent")


func _parse_dotted() -> String:
	var name := _expect_name("módulo")
	while _accept_op("."):
		name += "." + _expect_name("módulo")
	return name


func _what(node: Dictionary) -> String:
	match node["k"]:
		"const":
			return "un valor literal"
		"call":
			return "una llamada a función"
		"binop", "unary", "boolop", "compare":
			return "una operación"
		"tuple", "list":
			return "una tupla o lista"
	return "esa expresión"


func _check_target(node: Dictionary, ctx: String) -> void:
	match node["k"]:
		"name":
			return
		"subscript", "attr":
			return
		"tuple", "list":
			if ctx == "del":
				for e: Dictionary in node["elts"]:
					_check_target(e, ctx)
				return
			var starred := 0
			for e: Dictionary in node["elts"]:
				if e["k"] == "starred":
					starred += 1
					_check_target(e["e"], ctx)
				else:
					_check_target(e, ctx)
			if starred > 1:
				_fail_at({"line": node["line"]}, "SyntaxError", "solo puede haber un '*' al desempaquetar")
			return
		"starred":
			_fail_at({"line": node["line"]}, "SyntaxError", "un '*' en una asignación tiene que ir dentro de una tupla o lista")
			return
		"compare":
			if ctx == "assign":
				_fail_at({"line": node["line"]}, "SyntaxError", "no se puede asignar a una comparación: ¿querías usar '==' en un if?")
				return
	var verb := "borrar" if ctx == "del" else "asignar un valor a"
	_fail_at({"line": node["line"]}, "SyntaxError", "no se puede %s %s" % [verb, _what(node)])


# ── Expresiones ──────────────────────────────────────────────────────────────

## testlist: test (',' test)* [','] — una tupla si hay comas. `allow_star` permite *x.
func _parse_testlist(allow_star: bool = false) -> Dictionary:
	var line: int = _peek()["line"]
	var first := _parse_test_or_star(allow_star)
	if not _at_op(","):
		return first
	var elts: Array = [first]
	while _accept_op(","):
		if _at_end_of_small() or _at_op("=") or _at_op(")") or _at_op(":") or _at("op") and _AUG_OPS.has(_peek()["v"]):
			break
		elts.append(_parse_test_or_star(allow_star))
	return {"k": "tuple", "line": line, "elts": elts}


func _parse_test_or_star(allow_star: bool) -> Dictionary:
	if allow_star and _at_op("*"):
		var t := _advance()
		return {"k": "starred", "line": t["line"], "e": _parse_or_expr()}
	return _parse_test()


func _parse_named_test() -> Dictionary:
	var node := _parse_test()
	if _at_op(":="):
		_fail_at(_peek(), "SyntaxError", "el operador morsa ':=' no está disponible en el Dojo")
	return node


func _parse_test() -> Dictionary:
	if not _enter():
		return {"k": "const", "v": null, "line": 0}
	var node: Dictionary
	if _at_kw("lambda"):
		node = _parse_lambda()
	else:
		node = _parse_or_test()
		if _at_kw("if"):
			var t := _advance()
			var test := _parse_or_test()
			if not _accept_kw("else"):
				_fail_at(_peek(), "SyntaxError", "la expresión condicional necesita 'else': valor if condición else otro_valor")
			var orelse := _parse_test()
			node = {"k": "ifexp", "line": t["line"], "test": test, "body": node, "orelse": orelse}
	_leave()
	return node


func _parse_test_nocond() -> Dictionary:
	if _at_kw("lambda"):
		return _parse_lambda()
	return _parse_or_test()


func _parse_lambda() -> Dictionary:
	var t := _advance()
	var params := _parse_params(":")
	_expect_op(":", "falta ':' en la lambda: lambda x: expresión")
	var body := _parse_test()
	var node := {"k": "lambda", "line": t["line"], "body": body}
	node.merge(params)
	return node


func _parse_or_test() -> Dictionary:
	var node := _parse_and_test()
	while _at_kw("or"):
		var t := _advance()
		node = {"k": "boolop", "op": "or", "line": t["line"], "l": node, "r": _parse_and_test()}
	return node


func _parse_and_test() -> Dictionary:
	var node := _parse_not_test()
	while _at_kw("and"):
		var t := _advance()
		node = {"k": "boolop", "op": "and", "line": t["line"], "l": node, "r": _parse_not_test()}
	return node


func _parse_not_test() -> Dictionary:
	if _at_kw("not"):
		var t := _advance()
		if not _enter():
			return {"k": "const", "v": null, "line": 0}
		var e := _parse_not_test()
		_leave()
		return {"k": "unary", "op": "not", "line": t["line"], "e": e}
	return _parse_comparison()


func _parse_comparison() -> Dictionary:
	var first := _parse_or_expr()
	var ops: Array = []
	var rest: Array = []
	while not _failed():
		var t := _peek()
		var op := ""
		if t["t"] == "op" and _COMPARE_OPS.has(t["v"]):
			op = t["v"]
			_i += 1
		elif t["t"] == "kw" and t["v"] == "in":
			op = "in"
			_i += 1
		elif t["t"] == "kw" and t["v"] == "not" and _peek(1)["t"] == "kw" and _peek(1)["v"] == "in":
			op = "not in"
			_i += 2
		elif t["t"] == "kw" and t["v"] == "is":
			_i += 1
			op = "is not" if _accept_kw("not") else "is"
		else:
			break
		ops.append(op)
		rest.append(_parse_or_expr())
	if ops.is_empty():
		return first
	return {"k": "compare", "line": first["line"], "first": first, "ops": ops, "rest": rest}


func _parse_or_expr() -> Dictionary:
	var node := _parse_xor_expr()
	while _at_op("|"):
		var t := _advance()
		node = {"k": "binop", "op": "|", "line": t["line"], "l": node, "r": _parse_xor_expr()}
	return node


func _parse_xor_expr() -> Dictionary:
	var node := _parse_and_expr()
	while _at_op("^"):
		var t := _advance()
		node = {"k": "binop", "op": "^", "line": t["line"], "l": node, "r": _parse_and_expr()}
	return node


func _parse_and_expr() -> Dictionary:
	var node := _parse_shift()
	while _at_op("&"):
		var t := _advance()
		node = {"k": "binop", "op": "&", "line": t["line"], "l": node, "r": _parse_shift()}
	return node


func _parse_shift() -> Dictionary:
	var node := _parse_arith()
	while _at_op("<<") or _at_op(">>"):
		var t := _advance()
		node = {"k": "binop", "op": t["v"], "line": t["line"], "l": node, "r": _parse_arith()}
	return node


func _parse_arith() -> Dictionary:
	var node := _parse_term()
	while _at_op("+") or _at_op("-"):
		var t := _advance()
		node = {"k": "binop", "op": t["v"], "line": t["line"], "l": node, "r": _parse_term()}
	return node


func _parse_term() -> Dictionary:
	var node := _parse_factor()
	while _at_op("*") or _at_op("/") or _at_op("//") or _at_op("%") or _at_op("@"):
		var t := _advance()
		if t["v"] == "@":
			_fail_at(t, "SyntaxError", "el operador '@' (producto de matrices) no está disponible en el Dojo")
		node = {"k": "binop", "op": t["v"], "line": t["line"], "l": node, "r": _parse_factor()}
	return node


func _parse_factor() -> Dictionary:
	if _at_op("-") or _at_op("+") or _at_op("~"):
		var t := _advance()
		if not _enter():
			return {"k": "const", "v": null, "line": 0}
		var e := _parse_factor()
		_leave()
		# constantes negativas directas: -5 → const
		if t["v"] == "-" and e["k"] == "const" and (typeof(e["v"]) == TYPE_INT or typeof(e["v"]) == TYPE_FLOAT) and not e.get("neg", false):
			if typeof(e["v"]) == TYPE_INT and e["v"] == PyNumber.INT_MIN:
				return {"k": "unary", "op": "-", "line": t["line"], "e": e}
			return {"k": "const", "v": -e["v"], "line": t["line"], "neg": true}
		return {"k": "unary", "op": t["v"], "line": t["line"], "e": e}
	return _parse_power()


func _parse_power() -> Dictionary:
	var node := _parse_primary()
	if _at_op("**"):
		var t := _advance()
		if not _enter():
			return node
		var r := _parse_factor()
		_leave()
		node = {"k": "binop", "op": "**", "line": t["line"], "l": node, "r": r}
	return node


func _parse_primary() -> Dictionary:
	var node := _parse_atom()
	while not _failed():
		if _at_op("("):
			var t := _advance()
			node = _parse_call(node, t["line"])
		elif _at_op("["):
			var t := _advance()
			var index := _parse_subscript_list()
			_expect_op("]")
			node = {"k": "subscript", "line": t["line"], "value": node, "index": index}
		elif _at_op("."):
			var t := _advance()
			var nt := _peek()
			var name := ""
			if nt["t"] == "name" or nt["t"] == "kw":
				name = str(nt["v"])
				_i += 1
			else:
				_fail_at(nt, "SyntaxError", "después de '.' se esperaba el nombre de un método o atributo")
			node = {"k": "attr", "line": t["line"], "value": node, "name": name}
		else:
			break
	return node


func _parse_call(fn: Dictionary, line: int) -> Dictionary:
	var args: Array = []
	var kwargs: Array = []
	var dstar: Variant = null
	if not _enter():
		return fn
	while not _failed() and not _at_op(")"):
		if _accept_op("**"):
			dstar = _parse_test()
		elif _at_op("*"):
			var st := _advance()
			args.append({"k": "starred", "line": st["line"], "e": _parse_test()})
		elif _peek()["t"] == "name" and _peek(1)["t"] == "op" and _peek(1)["v"] == "=":
			var kt := _advance()
			_i += 1
			for kw: Array in kwargs:
				if kw[0] == kt["v"]:
					_fail_at(kt, "SyntaxError", "el argumento con nombre '%s' está repetido" % kt["v"])
			kwargs.append([kt["v"], _parse_test()])
		else:
			var at := _peek()
			var e := _parse_test()
			if _at_kw("for"):
				e = _parse_comprehension("genexp", e, {})
			elif not kwargs.is_empty():
				_fail_at(at, "SyntaxError", "un argumento normal no puede ir después de uno con nombre (nombre=valor)")
			elif _at_op("="):
				_fail_at(_peek(), "SyntaxError", "sintaxis no válida: ¿querías usar '==' para comparar? (con '=' solo se pasan argumentos con nombre)")
			args.append(e)
		if not _accept_op(","):
			break
	_leave()
	_expect_op(")", "falta el ')' de cierre de la llamada")
	return {"k": "call", "line": line, "func": fn, "args": args, "kwargs": kwargs, "dstar": dstar}


func _parse_subscript_list() -> Dictionary:
	var line: int = _peek()["line"]
	var first := _parse_subscript()
	if not _at_op(","):
		return first
	var elts: Array = [first]
	while _accept_op(","):
		if _at_op("]"):
			break
		elts.append(_parse_subscript())
	return {"k": "tuple", "line": line, "elts": elts}


func _parse_subscript() -> Dictionary:
	var line: int = _peek()["line"]
	var lo: Variant = null
	if not _at_op(":"):
		lo = _parse_test()
		if not _at_op(":"):
			return lo
	_i += 1
	var hi: Variant = null
	var step: Variant = null
	if not _at_op("]") and not _at_op(":") and not _at_op(","):
		hi = _parse_test()
	if _accept_op(":"):
		if not _at_op("]") and not _at_op(","):
			step = _parse_test()
	return {"k": "slice", "line": line, "lo": lo, "hi": hi, "step": step}


func _parse_atom() -> Dictionary:
	var t := _peek()
	var line: int = t["line"]
	match t["t"]:
		"name":
			_i += 1
			return {"k": "name", "line": line, "id": t["v"]}
		"num":
			_i += 1
			return {"k": "const", "line": line, "v": t["v"]}
		"str", "fstr":
			return _parse_strings()
		"kw":
			match t["v"]:
				"True":
					_i += 1
					return {"k": "const", "line": line, "v": true}
				"False":
					_i += 1
					return {"k": "const", "line": line, "v": false}
				"None":
					_i += 1
					return {"k": "const", "line": line, "v": null}
				"yield":
					_fail_at(t, "SyntaxError", "'yield' (generadores) no está disponible en el Dojo")
				"await":
					_fail_at(t, "SyntaxError", "'await' no está disponible en el Dojo")
				_:
					_fail_at(t, "SyntaxError", "sintaxis no válida: '%s' es una palabra reservada y no puede ir aquí" % t["v"])
			return {"k": "const", "line": line, "v": null}
		"op":
			match t["v"]:
				"(":
					_i += 1
					return _parse_paren(line)
				"[":
					_i += 1
					return _parse_list_display(line)
				"{":
					_i += 1
					return _parse_brace_display(line)
	_syntax_error_here()
	return {"k": "const", "line": line, "v": null}


func _parse_paren(line: int) -> Dictionary:
	if _accept_op(")"):
		return {"k": "tuple", "line": line, "elts": []}
	if not _enter():
		return {"k": "const", "v": null, "line": line}
	var first := _parse_test_or_star(true)
	var node: Dictionary
	if _at_kw("for"):
		node = _parse_comprehension("genexp", first, {})
	elif _at_op(","):
		var elts: Array = [first]
		while _accept_op(","):
			if _at_op(")"):
				break
			elts.append(_parse_test_or_star(true))
		node = {"k": "tuple", "line": line, "elts": elts}
	else:
		node = first.duplicate()
		node["paren"] = true
	_leave()
	_expect_op(")", "falta el ')' de cierre")
	return node


func _parse_list_display(line: int) -> Dictionary:
	if _accept_op("]"):
		return {"k": "list", "line": line, "elts": []}
	if not _enter():
		return {"k": "const", "v": null, "line": line}
	var first := _parse_test_or_star(true)
	var node: Dictionary
	if _at_kw("for"):
		node = _parse_comprehension("listcomp", first, {})
	else:
		var elts: Array = [first]
		while _accept_op(","):
			if _at_op("]"):
				break
			elts.append(_parse_test_or_star(true))
		node = {"k": "list", "line": line, "elts": elts}
	_leave()
	_expect_op("]", "falta el ']' de cierre de la lista")
	return node


func _parse_brace_display(line: int) -> Dictionary:
	if _accept_op("}"):
		return {"k": "dict", "line": line, "keys": [], "values": []}
	if not _enter():
		return {"k": "const", "v": null, "line": line}
	var node: Dictionary
	if _at_op("**"):
		_fail_at(_peek(), "SyntaxError", "'**' dentro de un diccionario no está disponible en el Dojo: usa d.update(...)")
		_leave()
		return {"k": "const", "v": null, "line": line}
	var starred_first := _at_op("*")
	var first := _parse_test_or_star(true)
	if not starred_first and _accept_op(":"):
		var value := _parse_test()
		if _at_kw("for"):
			node = _parse_comprehension("dictcomp", first, {"value": value})
		else:
			var keys: Array = [first]
			var values: Array = [value]
			while _accept_op(","):
				if _at_op("}"):
					break
				keys.append(_parse_test())
				_expect_op(":", "en un diccionario cada clave va seguida de ':' y su valor")
				values.append(_parse_test())
			node = {"k": "dict", "line": line, "keys": keys, "values": values}
	elif _at_kw("for") and not starred_first:
		node = _parse_comprehension("setcomp", first, {})
	else:
		var elts: Array = [first]
		while _accept_op(","):
			if _at_op("}"):
				break
			elts.append(_parse_test_or_star(true))
		node = {"k": "set", "line": line, "elts": elts}
	_leave()
	_expect_op("}", "falta la '}' de cierre")
	return node


func _parse_comprehension(kind: String, elt: Dictionary, extra: Dictionary) -> Dictionary:
	var gens: Array = []
	var line: int = elt["line"]
	while _at_kw("for") and not _failed():
		_i += 1
		var target := _parse_target_list()
		if not _accept_kw("in"):
			_fail_at(_peek(), "SyntaxError", "en una comprensión falta 'in': [x for x in secuencia]")
		var iter := _parse_or_test()
		var ifs: Array = []
		while _at_kw("if"):
			_i += 1
			ifs.append(_parse_test_nocond())
		gens.append({"target": target, "iter": iter, "ifs": ifs})
	var node := {"k": kind, "line": line, "elt": elt, "gens": gens}
	node.merge(extra)
	return node


func _parse_target_list() -> Dictionary:
	var line: int = _peek()["line"]
	var first := _parse_target_atom()
	if not _at_op(","):
		return first
	var elts: Array = [first]
	while _accept_op(","):
		if _at_kw("in") or _at_op("="):
			break
		elts.append(_parse_target_atom())
	var node := {"k": "tuple", "line": line, "elts": elts}
	_check_target(node, "assign")
	return node


func _parse_target_atom() -> Dictionary:
	if _at_op("*"):
		var t := _advance()
		return {"k": "starred", "line": t["line"], "e": _parse_or_expr()}
	var node := _parse_or_expr()
	if node["k"] != "tuple" and node["k"] != "list":
		_check_target(node, "assign")
	return node


## Cadenas adyacentes ("a" "b", f"..." "...") se concatenan.
func _parse_strings() -> Dictionary:
	var line: int = _peek()["line"]
	var parts: Array = []
	var is_f := false
	while _at("str") or _at("fstr"):
		var t := _advance()
		if t["t"] == "str":
			parts.append({"lit": t["v"]})
		else:
			is_f = true
			parts.append_array(t["v"])
	if not is_f:
		var s := ""
		for p: Dictionary in parts:
			s += p["lit"]
		return {"k": "const", "line": line, "v": s}
	return _build_fstring(parts, line)


func _build_fstring(parts: Array, line: int) -> Dictionary:
	var out: Array = []
	for p: Dictionary in parts:
		if p.has("lit"):
			if not out.is_empty() and out.back() is String:
				out[out.size() - 1] = out.back() + p["lit"]
			else:
				out.append(p["lit"])
			continue
		var field := _parse_fstring_field(p["expr"], int(p["line"]))
		if _failed():
			return {"k": "const", "line": line, "v": ""}
		if field.has("debug_text"):
			var txt: String = field["debug_text"]
			if not out.is_empty() and out.back() is String:
				out[out.size() - 1] = out.back() + txt
			else:
				out.append(txt)
		out.append(field)
	return {"k": "fstring", "line": line, "parts": out}


## Divide "expr!conv:spec" respetando corchetes y cadenas.
func _parse_fstring_field(raw: String, line: int) -> Dictionary:
	var depth := 0
	var i := 0
	var n := raw.length()
	var expr_end := n
	var conv := ""
	var spec_text: Variant = null
	var quote := ""
	while i < n:
		var c := raw[i]
		if not quote.is_empty():
			if c == quote:
				quote = ""
		elif c == "'" or c == "\"":
			quote = c
		elif c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			depth -= 1
		elif depth == 0 and c == "!" and i + 1 < n and raw[i + 1] != "=":
			expr_end = i
			conv = raw.substr(i + 1, 1)
			var rest := raw.substr(i + 2)
			if rest.begins_with(":"):
				spec_text = rest.substr(1)
			elif not rest.is_empty():
				_fail_at({"line": line}, "SyntaxError", "f-string: después de '!' solo puede ir r, s o a")
				return {}
			break
		elif depth == 0 and c == ":":
			expr_end = i
			spec_text = raw.substr(i + 1)
			break
		i += 1
	if not conv.is_empty() and conv not in ["r", "s", "a"]:
		_fail_at({"line": line}, "SyntaxError", "f-string: conversión '!%s' no válida (usa !r o !s)" % conv)
		return {}
	var expr_text := raw.substr(0, expr_end)
	var debug_text := ""
	var stripped := expr_text.strip_edges(false, true)
	if stripped.ends_with("=") and not stripped.ends_with("==") and not stripped.ends_with("!=") \
			and not stripped.ends_with("<=") and not stripped.ends_with(">="):
		debug_text = expr_text
		expr_text = stripped.substr(0, stripped.length() - 1)
		if conv.is_empty() and spec_text == null:
			conv = "r"
	if expr_text.strip_edges().is_empty():
		_fail_at({"line": line}, "SyntaxError", "f-string: hay unas llaves {} vacías; dentro va una expresión, p. ej. {x}")
		return {}
	var sub := PyParser.new().parse_expression_text(expr_text, line)
	if not sub["error"].is_empty():
		if _error.is_empty():
			_error = sub["error"]
		return {}
	var field := {"e": sub["ast"], "conv": conv, "spec": null}
	if not debug_text.is_empty():
		field["debug_text"] = debug_text
	if spec_text != null:
		var spec_str: String = spec_text
		if spec_str.contains("{"):
			# especificación anidada: {x:{ancho}}
			var lex := PyLexer.new().tokenize("f'" + spec_str.replace("'", "\\'") + "'", line - 1)
			if not lex["error"].is_empty():
				_fail_at({"line": line}, "SyntaxError", "f-string: especificación de formato no válida")
				return {}
			var spec_node := _build_fstring(lex["tokens"][0]["v"], line)
			field["spec"] = spec_node
		else:
			field["spec"] = {"k": "const", "line": line, "v": spec_str}
	return field
