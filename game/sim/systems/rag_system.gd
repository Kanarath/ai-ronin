class_name RagSystem
extends RefCounted
## Sistema RAG (Retrieval-Augmented Generation) del laboratorio A2.
##
## REAL (cálculo de verdad):
##   - Troceo (chunking) de documentos por número de palabras, con solapamiento.
##   - Índice vectorial TF-IDF (embeddings DISPERSOS, una técnica clásica de recuperación)
##     y búsqueda por similitud coseno, con filtro de acceso por documento.
## ⚗ SIMULADO: el «generador» (el LLM que redacta la respuesta) sigue reglas:
##   cita la frase más relevante del contexto recuperado y, como los LLM reales, puede
##   OBEDECER instrucciones escondidas en ese contexto (inyección indirecta).
## Los RAG de producción usan embeddings DENSOS de una red neuronal; los riesgos son los mismos.

const KB_PATH := "res://content/rag/kb_forja.json"
const STOPWORDS: Array[String] = ["el", "la", "los", "las", "un", "una", "unos", "unas", "de", "del", "al", "a", "en", "y", "o", "que", "es", "se", "su", "sus", "con", "por", "para", "lo", "le", "les", "no", "si", "mi", "tu", "me", "te", "nos", "como", "más", "mas", "pero", "hay", "son", "este", "esta", "eso", "esto", "cual", "cuál", "qué", "ser", "tiene", "tienen", "puedo", "hace", "hacéis"]
const DEFENSES: Array[String] = ["acl", "trusted-sources", "spotlight", "min-score", "vector-acl"]
const MIN_SCORE := 0.12
const INJECTION_RX := "(?i)(?:responde|di|dile al cliente|contesta|escribe)\\s+(?:siempre\\s+)?que\\s+([^.\\]]+)"

var kb_name: String = ""
var documents: Array[Dictionary] = []  # {id, title, source, access, text}
var chunks: Array[Dictionary] = []     # {id, doc, source, access, text, vec}
var idf: Dictionary = {}
var chunk_size: int = 40
var overlap: int = 10
var defenses: Dictionary = {"acl": false, "trusted-sources": false, "spotlight": false, "min-score": false, "vector-acl": false}


static func load_default(p_name: String) -> RagSystem:
	var rag := RagSystem.new()
	rag.kb_name = p_name
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KB_PATH))
	for d: Dictionary in data["documents"]:
		rag.documents.append(d.duplicate())
	return rag


func duplicate_system() -> RagSystem:
	var r := RagSystem.new()
	r.kb_name = kb_name
	for d in documents:
		r.documents.append(d.duplicate())
	r.chunk_size = chunk_size
	r.overlap = overlap
	r.defenses = defenses.duplicate()
	r.ingest(chunk_size, overlap)
	return r


static func words_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in RegEx.create_from_string("[\\p{L}\\p{N}%]+").search_all(text.to_lower()):
		out.append(m.get_string())
	return out


static func terms_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in words_of(text):
		if not w in STOPWORDS and w.length() > 1:
			out.append(w)
	return out


func add_document(id: String, title: String, source: String, access: String, text: String) -> void:
	documents.append({"id": id, "title": title, "source": source, "access": access, "text": text})


## Trocea todos los documentos y construye el índice TF-IDF.
func ingest(p_chunk: int, p_overlap: int) -> void:
	chunk_size = maxi(p_chunk, 3)
	overlap = clampi(p_overlap, 0, chunk_size - 1)
	chunks.clear()
	for d in documents:
		# Fuentes no confiables: con trusted-sources ni siquiera entran en el índice.
		if defenses["trusted-sources"] and d["source"] != "forja":
			continue
		var raw := String(d["text"]).split(" ", false)
		var step := chunk_size - overlap
		var n := 0
		var start := 0
		while start < raw.size():
			var piece := " ".join(raw.slice(start, mini(start + chunk_size, raw.size())))
			chunks.append({"id": "%s#%d" % [d["id"], n], "doc": d["id"], "source": d["source"], "access": d["access"], "text": piece})
			n += 1
			if start + chunk_size >= raw.size():
				break
			start += step
	var df := {}
	for c in chunks:
		var seen := {}
		for t in terms_of(c["text"]):
			seen[t] = true
		for t: String in seen:
			df[t] = df.get(t, 0) + 1
	idf.clear()
	var n_chunks := float(chunks.size())
	for t: String in df:
		idf[t] = log((n_chunks + 1.0) / (df[t] + 1.0)) + 1.0
	for c in chunks:
		c["vec"] = vectorize(c["text"])


## Vector TF-IDF normalizado (diccionario término → peso).
func vectorize(text: String) -> Dictionary:
	var tf := {}
	var terms := terms_of(text)
	for t in terms:
		tf[t] = tf.get(t, 0) + 1
	var v := {}
	var norm := 0.0
	for t: String in tf:
		var w: float = float(tf[t]) / maxf(terms.size(), 1) * idf.get(t, 1.0)
		v[t] = w
		norm += w * w
	norm = sqrt(norm)
	if norm > 0.0:
		for t: String in v:
			v[t] /= norm
	return v


static func cosine(a: Dictionary, b: Dictionary) -> float:
	var s := 0.0
	var small := a if a.size() < b.size() else b
	var big := b if small == a else a
	for t: String in small:
		if big.has(t):
			s += small[t] * big[t]
	return s


func visible_to(c: Dictionary, role: String) -> bool:
	return not defenses["acl"] or c["access"] == "publico" or role == "empleado"


## Devuelve [{chunk, score}] ordenado por similitud.
func search(query: String, k: int, role: String) -> Array[Dictionary]:
	var q := vectorize(query)
	var scored: Array[Dictionary] = []
	for c in chunks:
		if not visible_to(c, role):
			continue
		scored.append({"chunk": c, "score": cosine(q, c["vec"])})
	scored.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if is_equal_approx(x["score"], y["score"]):
			return x["chunk"]["id"] < y["chunk"]["id"]
		return x["score"] > y["score"])
	return scored.slice(0, mini(k, scored.size()))


## Respuesta completa con análisis:
## {answer, sources, top_score, grounded, injected, poisoned, leaked_internal, context_words, refused}
func ask(question: String, role: String, k: int = 3) -> Dictionary:
	var hits := search(question, k, role)
	var res := {"answer": "", "sources": PackedStringArray(), "top_score": 0.0, "grounded": false, "injected": false,
		"poisoned": false, "leaked_internal": false, "context_words": 0, "refused": false}
	if hits.is_empty() or (defenses["min-score"] and hits[0]["score"] < MIN_SCORE):
		res["answer"] = "No tengo información fiable sobre eso en la documentación de la forja."
		res["refused"] = true
		res["top_score"] = hits[0]["score"] if not hits.is_empty() else 0.0
		return res
	res["top_score"] = hits[0]["score"]
	var sources := PackedStringArray()
	var context_words := 0
	for h in hits:
		sources.append(h["chunk"]["id"])
		context_words += String(h["chunk"]["text"]).split(" ", false).size()
	res["sources"] = sources
	res["context_words"] = context_words
	# 1) ¿Hay instrucciones escondidas en el contexto recuperado? (inyección indirecta)
	if not defenses["spotlight"]:
		var rx := RegEx.create_from_string(INJECTION_RX)
		for h in hits:
			var m := rx.search(h["chunk"]["text"])
			# La instrucción se «impone» cuando su fragmento es de los más relevantes para la
			# pregunta (los modelos atienden sobre todo al contexto más pertinente).
			if m != null and h["score"] > 0.0 and h["score"] >= 0.8 * hits[0]["score"]:
				res["answer"] = m.get_string(1).strip_edges() + "."
				res["injected"] = true
				res["poisoned"] = h["chunk"]["source"] != "forja"
				res["leaked_internal"] = h["chunk"]["access"] == "interno" and role != "empleado"
				return res
	# 2) Respuesta «fundamentada»: la frase del contexto que más se parece a la pregunta.
	var q_terms := terms_of(question)
	var best := ""
	var best_overlap := -1.0
	var best_chunk: Dictionary = hits[0]["chunk"]
	for h in hits:
		for sentence in split_sentences(h["chunk"]["text"]):
			var s_terms := terms_of(sentence)
			if s_terms.is_empty():
				continue
			# Con spotlight, el contenido recuperado se marca como DATOS: una frase con forma de
			# instrucción no se obedece ni se usa como respuesta.
			if defenses["spotlight"] and RegEx.create_from_string(INJECTION_RX).search(sentence) != null:
				continue
			var ov := 0.0
			for t in q_terms:
				if t in s_terms:
					ov += idf.get(t, 1.0)
			ov += h["score"] * 0.01  # desempate a favor del fragmento más relevante
			if ov > best_overlap:
				best_overlap = ov
				best = sentence.strip_edges()
				best_chunk = h["chunk"]
	res["answer"] = best + "."
	res["grounded"] = true
	res["poisoned"] = best_chunk["source"] != "forja"
	res["leaked_internal"] = best_chunk["access"] == "interno" and role != "empleado"
	return res


## Frases de un texto. Un punto pegado a letras o cifras por los dos lados («1.000»,
## «compras@tamagawa.example», «v2.1») no corta la frase: solo corta el que va seguido de un
## espacio o del final del texto.
static func split_sentences(text: String) -> PackedStringArray:
	var mark := char(0xE000)
	var protected := RegEx.create_from_string("(?<=[\\p{L}\\p{N}])\\.(?=[\\p{L}\\p{N}])").sub(text, mark, true)
	var out := PackedStringArray()
	for s in protected.split(".", false):
		if not s.strip_edges().is_empty():
			out.append(s.replace(mark, ".").strip_edges())
	return out


## Lo que «vería» quien tenga acceso de lectura a la base de datos vectorial.
func vector_of(chunk_id: String) -> Dictionary:
	for c in chunks:
		if c["id"] == chunk_id:
			return c
	return {}


## «Inversión» de un vector disperso: sus dimensiones con peso son palabras del texto original.
## (Con embeddings densos hace falta un modelo entrenado para invertirlos, pero la investigación
## muestra que también se recupera gran parte del texto: ver Morris et al., 2023.)
static func invert(vec: Dictionary) -> PackedStringArray:
	var pairs: Array = []
	for t: String in vec:
		pairs.append([t, vec[t]])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (is_equal_approx(a[1], b[1]) and a[0] < b[0]))
	var out := PackedStringArray()
	for p in pairs:
		out.append(p[0])
	return out
