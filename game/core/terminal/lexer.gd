class_name Lexer
extends RefCounted
## Convierte una línea de texto en tokens.
## Tipos: WORD, STRING (entre comillas), PIPE (|), QUESTION (? final).

const WORD := "WORD"
const STRING := "STRING"
const PIPE := "PIPE"
const QUESTION := "QUESTION"


## Devuelve {"tokens": Array[Dictionary], "error": String}.
static func tokenize(line: String) -> Dictionary:
	var tokens: Array[Dictionary] = []
	var text := line.strip_edges()
	# Un «?» al final pide ayuda contextual sin ejecutar nada.
	var question := text.ends_with("?") and not text.ends_with("\\?")
	if question:
		text = text.substr(0, text.length() - 1).strip_edges()
	var i := 0
	var current := ""
	var in_word := false
	while i < text.length():
		var c := text[i]
		if c == "\"" or c == "'":
			if in_word:
				tokens.append({"type": WORD, "value": current})
				current = ""
				in_word = false
			var end := text.find(c, i + 1)
			if end == -1:
				return {"tokens": tokens, "error": "comillas sin cerrar (%s)" % c}
			tokens.append({"type": STRING, "value": text.substr(i + 1, end - i - 1)})
			i = end + 1
			continue
		if c == "|":
			if in_word:
				tokens.append({"type": WORD, "value": current})
				current = ""
				in_word = false
			tokens.append({"type": PIPE, "value": "|"})
		elif c == " " or c == "\t":
			if in_word:
				tokens.append({"type": WORD, "value": current})
				current = ""
				in_word = false
		else:
			current += c
			in_word = true
		i += 1
	if in_word:
		tokens.append({"type": WORD, "value": current})
	if question:
		tokens.append({"type": QUESTION, "value": "?"})
	return {"tokens": tokens, "error": ""}
