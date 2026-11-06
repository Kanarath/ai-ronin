class_name BPETokenizer
extends RefCounted
## Tokenizador BPE (Byte Pair Encoding) entrenado de verdad sobre un corpus.
##
## Entrenamiento:
##   1. Pre-tokenización: se separa el texto en palabras; cada palabra empieza con «▁»
##      (marca de inicio de palabra, como en SentencePiece) y se parte en caracteres.
##   2. Se cuentan los pares de símbolos adyacentes en todo el corpus (ponderados por la
##      frecuencia de cada palabra).
##   3. El par más frecuente se FUSIONA en un símbolo nuevo. Empate → el par menor en orden
##      alfabético (para que el resultado sea reproducible).
##   4. Se repite N veces (N fusiones = N tokens nuevos en el vocabulario).
## Codificación: se parte la palabra en caracteres y se aplican las fusiones en el MISMO
## orden en que se aprendieron.
##
## ⚗ Simplificación: trabajamos con caracteres, no con bytes. Los tokenizadores reales de
## los LLM (GPT, Llama…) son «byte-level»: nunca encuentran un carácter desconocido.

const WORD_START := "▁"
const UNKNOWN := "<?>"

var merges: Array[PackedStringArray] = []  # [[a, b], ...] en orden de aprendizaje
var base_symbols: PackedStringArray = []
var trained_on: String = ""


## Separa en «palabras» (letras/números) y signos de puntuación sueltos.
static func pre_tokenize(text: String) -> PackedStringArray:
	var rx := RegEx.create_from_string("[\\p{L}\\p{N}]+|[^\\s\\p{L}\\p{N}]")
	var out := PackedStringArray()
	for m in rx.search_all(text):
		out.append(m.get_string())
	return out


static func word_symbols(word: String) -> PackedStringArray:
	var out := PackedStringArray([WORD_START])
	for c in word:
		out.append(c)
	return out


func train(corpus: String, num_merges: int, corpus_name: String = "") -> void:
	merges.clear()
	trained_on = corpus_name
	var freq := {}  # palabra -> veces
	for w in pre_tokenize(corpus):
		freq[w] = freq.get(w, 0) + 1
	var words: Array = []  # [[símbolos, frecuencia]]
	var base := {}
	for w: String in freq:
		var syms := word_symbols(w)
		for s in syms:
			base[s] = true
		words.append([syms, freq[w]])
	base_symbols = PackedStringArray(base.keys())
	base_symbols.sort()
	for i in num_merges:
		var pairs := {}
		for entry in words:
			var syms: PackedStringArray = entry[0]
			for j in syms.size() - 1:
				var key := syms[j] + "\u0001" + syms[j + 1]
				pairs[key] = pairs.get(key, 0) + int(entry[1])
		if pairs.is_empty():
			break
		var best := ""
		var best_count := -1
		for key: String in pairs:
			var c: int = pairs[key]
			if c > best_count or (c == best_count and key < best):
				best = key
				best_count = c
		var pair := best.split("\u0001")
		merges.append(pair)
		for entry in words:
			entry[0] = _apply_merge(entry[0], pair[0], pair[1])


static func _apply_merge(syms: PackedStringArray, a: String, b: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < syms.size():
		if i < syms.size() - 1 and syms[i] == a and syms[i + 1] == b:
			out.append(a + b)
			i += 2
		else:
			out.append(syms[i])
			i += 1
	return out


## Vocabulario: símbolos base (orden alfabético) + un token por fusión (orden de aprendizaje).
func vocab() -> PackedStringArray:
	var v := base_symbols.duplicate()
	v.append(UNKNOWN)
	for m in merges:
		v.append(m[0] + m[1])
	return v


func encode_word(word: String) -> PackedStringArray:
	var syms := word_symbols(word)
	for i in syms.size():
		if not syms[i] in base_symbols:
			syms[i] = UNKNOWN
	for m in merges:
		syms = _apply_merge(syms, m[0], m[1])
	return syms


func encode(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in pre_tokenize(text):
		out.append_array(encode_word(w))
	return out


func ids(tokens: PackedStringArray) -> PackedInt32Array:
	var v := vocab()
	var out := PackedInt32Array()
	for t in tokens:
		out.append(v.find(t))
	return out
