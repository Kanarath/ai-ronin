class_name PyLexer
extends RefCounted
## Analizador léxico del Python del Dojo.
##
## tokenize(fuente) → {"tokens": Array[Dictionary], "error": {} | {"type","line","message"}}
## Cada token: {"t": tipo, "v": valor, "line": línea}
##   tipos: "name", "kw", "num", "str", "fstr", "op", "nl", "indent", "dedent", "eof"
##   "fstr" lleva en "v" un Array de partes: {"lit": String} o {"expr": String, "line": int}

const KEYWORDS := {
	"False": true, "None": true, "True": true, "and": true, "as": true, "assert": true,
	"async": true, "await": true, "break": true, "class": true, "continue": true,
	"def": true, "del": true, "elif": true, "else": true, "except": true, "finally": true,
	"for": true, "from": true, "global": true, "if": true, "import": true, "in": true,
	"is": true, "lambda": true, "nonlocal": true, "not": true, "or": true, "pass": true,
	"raise": true, "return": true, "try": true, "while": true, "with": true, "yield": true,
}

const OPERATORS: Array[String] = [
	"**=", "//=", ">>=", "<<=", "...",
	"**", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=",
	"->", "<<", ">>", ":=",
	"+", "-", "*", "/", "%", "<", ">", "=", "(", ")", "[", "]", "{", "}", ",", ":", ".",
	";", "@", "&", "|", "^", "~",
]

const _CLOSERS := {")": "(", "]": "[", "}": "{"}

var _src := ""
var _pos := 0
var _line := 1
var _tokens: Array[Dictionary] = []
var _error: Dictionary = {}
var _parens: Array = []  # [char, line]
var _line_offset := 0


## `line_offset` desplaza los números de línea (para expresiones dentro de f-strings).
func tokenize(source: String, line_offset: int = 0) -> Dictionary:
	_src = source.replace("\r\n", "\n").replace("\r", "\n")
	_pos = 0
	_line = 1 + line_offset
	_line_offset = line_offset
	_tokens = []
	_error = {}
	_parens = []
	var indents: Array[String] = [""]
	var at_line_start := true
	var n := _src.length()
	while _pos < n and _error.is_empty():
		if at_line_start and _parens.is_empty():
			at_line_start = false
			var ws_start := _pos
			while _pos < n and (_src[_pos] == " " or _src[_pos] == "\t" or _src[_pos] == "\f"):
				_pos += 1
			if _pos >= n:
				break
			var c0 := _src[_pos]
			if c0 == "\n" or c0 == "#":
				# línea vacía o solo comentario: no afecta a la indentación
				while _pos < n and _src[_pos] != "\n":
					_pos += 1
				if _pos < n:
					_pos += 1
					_line += 1
				at_line_start = true
				continue
			var ws := _src.substr(ws_start, _pos - ws_start).replace("\f", "")
			var top: String = indents.back()
			if ws != top:
				if ws.length() > top.length() and ws.begins_with(top):
					indents.append(ws)
					_emit("indent", null)
				else:
					while indents.size() > 1 and ws != indents.back():
						var t: String = indents.back()
						if not t.begins_with(ws):
							break
						indents.pop_back()
						_emit("dedent", null)
					if ws != indents.back():
						if _mixes_tabs(ws, indents.back()):
							_fail("IndentationError", "la indentación mezcla tabuladores y espacios de forma incoherente: usa solo espacios (4 por nivel)")
						else:
							_fail("IndentationError", "la indentación de esta línea no coincide con ningún nivel anterior")
						break
			continue
		var c := _src[_pos]
		if c == " " or c == "\t" or c == "\f":
			_pos += 1
		elif c == "#":
			while _pos < n and _src[_pos] != "\n":
				_pos += 1
		elif c == "\n":
			if _parens.is_empty():
				_emit("nl", null)
				at_line_start = true
			_pos += 1
			_line += 1
		elif c == "\\":
			if _pos + 1 < n and _src[_pos + 1] == "\n":
				_pos += 2
				_line += 1
			else:
				_fail("SyntaxError", "carácter '\\' inesperado fuera de una cadena")
		elif _is_ident_start(c):
			_lex_name_or_prefixed_string()
		elif _is_digit(c) or (c == "." and _pos + 1 < n and _is_digit(_src[_pos + 1])):
			_lex_number()
		elif c == "'" or c == "\"":
			_lex_string("")
		else:
			_lex_operator()
	if _error.is_empty() and not _parens.is_empty():
		var open_p: Array = _parens.back()
		var closer := {"(": ")", "[": "]", "{": "}"}[open_p[0]] as String
		_error = {"type": "SyntaxError", "line": open_p[1],
			"message": "el '%s' de la línea %d nunca se cerró: falta un '%s'" % [open_p[0], open_p[1], closer]}
	if _error.is_empty():
		if not _tokens.is_empty() and _tokens.back()["t"] != "nl" and _tokens.back()["t"] != "dedent":
			_emit("nl", null)
		while indents.size() > 1:
			indents.pop_back()
			_emit("dedent", null)
		_emit("eof", null)
	return {"tokens": _tokens, "error": _error}


func _mixes_tabs(a: String, b: String) -> bool:
	return (a.contains("\t") or b.contains("\t")) and (a.contains(" ") or b.contains(" ") or a.contains("\t") != b.contains("\t"))


func _emit(type: String, value: Variant) -> void:
	_tokens.append({"t": type, "v": value, "line": _line})


func _fail(type: String, message: String, line: int = -1) -> void:
	if _error.is_empty():
		_error = {"type": type, "line": _line if line < 0 else line, "message": message}


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_ident_start(c: String) -> bool:
	var u := c.unicode_at(0)
	return (u >= 65 and u <= 90) or (u >= 97 and u <= 122) or u == 95 or (u >= 128 and _is_unicode_letter(c))


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or _is_digit(c)


static func _is_unicode_letter(c: String) -> bool:
	# Letras acentuadas, ñ, etc.: lo que tenga mayúscula/minúscula o sea alfabético común.
	return c.to_upper() != c.to_lower() or c.unicode_at(0) >= 0x3040


func _lex_name_or_prefixed_string() -> void:
	var start := _pos
	var n := _src.length()
	while _pos < n and _is_ident_char(_src[_pos]):
		_pos += 1
	var word := _src.substr(start, _pos - start)
	if _pos < n and (_src[_pos] == "'" or _src[_pos] == "\"") and word.length() <= 2:
		var prefix := word.to_lower()
		if prefix in ["f", "r", "rf", "fr", "u"]:
			_lex_string(prefix)
			return
		if prefix in ["b", "br", "rb"]:
			_fail("SyntaxError", "las cadenas de bytes (b'...') no están disponibles en el Dojo")
			return
	if KEYWORDS.has(word):
		_emit("kw", word)
	else:
		_emit("name", word)


func _lex_number() -> void:
	var start := _pos
	var n := _src.length()
	var line := _line
	if _src[_pos] == "0" and _pos + 1 < n and _src[_pos + 1].to_lower() in ["x", "o", "b"]:
		var base := {"x": 16, "o": 8, "b": 2}[_src[_pos + 1].to_lower()] as int
		_pos += 2
		while _pos < n and (_is_ident_char(_src[_pos])):
			_pos += 1
		var text := _src.substr(start, _pos - start)
		var r: Array = PyNumber.parse_int(text, base)
		if r[0] == 1:
			_fail("SyntaxError", "número no válido: '%s'" % text, line)
		elif r[0] == 2:
			_fail("OverflowError", "el número %s es demasiado grande para el Dojo (máximo 9223372036854775807)" % text, line)
		else:
			_tokens.append({"t": "num", "v": r[1], "line": line})
		return
	var is_float := false
	while _pos < n and (_is_digit(_src[_pos]) or _src[_pos] == "_"):
		_pos += 1
	if _pos < n and _src[_pos] == "." and not (_pos + 1 < n and _src[_pos + 1] == "."):
		is_float = true
		_pos += 1
		while _pos < n and (_is_digit(_src[_pos]) or _src[_pos] == "_"):
			_pos += 1
	if _pos < n and _src[_pos].to_lower() == "e":
		var save := _pos
		_pos += 1
		if _pos < n and (_src[_pos] == "+" or _src[_pos] == "-"):
			_pos += 1
		if _pos < n and _is_digit(_src[_pos]):
			is_float = true
			while _pos < n and (_is_digit(_src[_pos]) or _src[_pos] == "_"):
				_pos += 1
		else:
			_pos = save
	if _pos < n and _src[_pos].to_lower() == "j":
		_fail("SyntaxError", "los números complejos no están disponibles en el Dojo", line)
		return
	if _pos < n and _is_ident_start(_src[_pos]):
		_fail("SyntaxError", "número mal escrito: después de un número no puede ir una letra pegada", line)
		return
	var text := _src.substr(start, _pos - start)
	if text.ends_with("_") or text.contains("__") or text.contains("_.") or text.contains("._"):
		_fail("SyntaxError", "número no válido: '%s'" % text, line)
		return
	if is_float:
		var f: Array = PyNumber.parse_float(text)
		if not f[0]:
			_fail("SyntaxError", "número decimal no válido: '%s'" % text, line)
			return
		_tokens.append({"t": "num", "v": f[1], "line": line})
		return
	var clean := text.replace("_", "")
	if clean.length() > 1 and clean.begins_with("0") and clean.replace("0", "") != "":
		_fail("SyntaxError", "los enteros no pueden empezar por 0 (por ejemplo, escribe 7 en vez de 07)", line)
		return
	var ri: Array = PyNumber.parse_int(clean, 10)
	if ri[0] == 2:
		_fail("OverflowError", "el número %s es demasiado grande para el Dojo (máximo 9223372036854775807)" % text, line)
		return
	_tokens.append({"t": "num", "v": ri[1], "line": line})


func _lex_operator() -> void:
	for op in OPERATORS:
		if _src.substr(_pos, op.length()) == op:
			if op == "...":
				_fail("SyntaxError", "'...' (Ellipsis) no está disponible en el Dojo")
				return
			if op in ["(", "[", "{"]:
				_parens.append([op, _line])
			elif _CLOSERS.has(op):
				if _parens.is_empty():
					_fail("SyntaxError", "hay un '%s' de cierre que no se abrió antes" % op)
					return
				var open_p: Array = _parens.back()
				if open_p[0] != _CLOSERS[op]:
					_fail("SyntaxError", "el '%s' de cierre no corresponde al '%s' abierto en la línea %d" % [op, open_p[0], open_p[1]])
					return
				_parens.pop_back()
			_emit("op", op)
			_pos += op.length()
			return
	var c := _src[_pos]
	if c == "!":
		_fail("SyntaxError", "'!' no es un operador de Python: para negar usa 'not' y para 'distinto de' usa '!='")
	elif c == "$" or c == "?" or c == "`":
		_fail("SyntaxError", "carácter no válido en Python: '%s'" % c)
	else:
		_fail("SyntaxError", "carácter no válido en Python: '%s'" % c)


## Lee una cadena (con prefijo "", "r", "f", "rf", "u").
func _lex_string(prefix: String) -> void:
	var raw := prefix.contains("r")
	var is_f := prefix.contains("f")
	var n := _src.length()
	var q := _src[_pos]
	var start_line := _line
	var triple := _src.substr(_pos, 3) == q.repeat(3)
	_pos += 3 if triple else 1
	var parts: Array = []
	var lit := ""
	var closed := false
	while _pos < n:
		var c := _src[_pos]
		if triple:
			if _src.substr(_pos, 3) == q.repeat(3):
				_pos += 3
				closed = true
				break
		elif c == q:
			_pos += 1
			closed = true
			break
		if c == "\n":
			if not triple:
				break
			_line += 1
			lit += c
			_pos += 1
			continue
		if c == "\\":
			if raw:
				lit += c
				if _pos + 1 < n:
					if _src[_pos + 1] == "\n":
						_line += 1
					lit += _src[_pos + 1]
				_pos += 2
				continue
			var esc := _read_escape()
			if not _error.is_empty():
				return
			lit += esc
			continue
		if is_f and c == "{":
			if _src.substr(_pos, 2) == "{{":
				lit += "{"
				_pos += 2
				continue
			if not lit.is_empty():
				parts.append({"lit": lit})
				lit = ""
			var expr_line := _line
			var expr := _read_fstring_field(q, triple)
			if not _error.is_empty():
				return
			parts.append({"expr": expr, "line": expr_line})
			continue
		if is_f and c == "}":
			if _src.substr(_pos, 2) == "}}":
				lit += "}"
				_pos += 2
				continue
			_fail("SyntaxError", "en una f-string, una '}' suelta debe escribirse '}}'")
			return
		lit += c
		_pos += 1
	if not closed:
		if triple:
			_fail("SyntaxError", "la cadena con triples comillas de la línea %d nunca se cerró" % start_line, start_line)
		else:
			_fail("SyntaxError", "cadena sin cerrar: falta la comilla de cierre %s" % q, start_line)
		return
	if is_f:
		if not lit.is_empty():
			parts.append({"lit": lit})
		_tokens.append({"t": "fstr", "v": parts, "line": start_line})
	else:
		_tokens.append({"t": "str", "v": lit, "line": start_line})


func _read_escape() -> String:
	# _src[_pos] == "\\"
	var n := _src.length()
	if _pos + 1 >= n:
		_pos += 1
		return "\\"
	var e := _src[_pos + 1]
	_pos += 2
	match e:
		"n": return "\n"
		"t": return "\t"
		"r": return "\r"
		"\\": return "\\"
		"'": return "'"
		"\"": return "\""
		"0":
			return String.chr(0)
		"a": return String.chr(7)
		"b": return String.chr(8)
		"f": return String.chr(12)
		"v": return String.chr(11)
		"\n":
			_line += 1
			return ""
		"x", "u", "U":
			var count := {"x": 2, "u": 4, "U": 8}[e] as int
			var hex := _src.substr(_pos, count)
			if hex.length() != count or not hex.is_valid_hex_number():
				_fail("SyntaxError", "secuencia de escape \\%s mal formada" % e)
				return ""
			_pos += count
			return String.chr(hex.hex_to_int())
	return "\\" + e


## Lee el campo {…} de una f-string y devuelve su texto (sin las llaves).
func _read_fstring_field(q: String, triple: bool) -> String:
	var n := _src.length()
	var start := _pos + 1
	var line := _line
	_pos += 1
	var depth := 1
	while _pos < n:
		var c := _src[_pos]
		if c == "\n" and not triple:
			break
		if c == "\n":
			_line += 1
		if c == "'" or c == "\"":
			if c == q and not triple and depth == 1:
				break
			# cadena anidada dentro de la expresión
			var inner := c
			_pos += 1
			while _pos < n and _src[_pos] != inner and _src[_pos] != "\n":
				_pos += 1
			_pos += 1
			continue
		if c == "{" or c == "[" or c == "(":
			depth += 1
		elif c == "}" or c == "]" or c == ")":
			depth -= 1
			if depth == 0 and c == "}":
				var text := _src.substr(start, _pos - start)
				_pos += 1
				return text
		_pos += 1
	_fail("SyntaxError", "f-string: falta la '}' de cierre del campo {...}", line)
	return ""
