class_name NGramLM
extends RefCounted
## Modelo de lenguaje n-grama: estima P(siguiente palabra | las n−1 anteriores) contando
## en un corpus. Es un modelo de lenguaje DE VERDAD (los hubo en producción durante décadas)
## y comparte la tarea con un LLM: predecir el siguiente token. La diferencia es CÓMO:
## un LLM usa una red neuronal (transformer) con un contexto de miles de tokens, no un recuento.
##
## Backoff: si el contexto completo nunca apareció, se usa uno más corto (hasta el unigrama).
## Tokens: palabras y signos de puntuación, en minúsculas.

var order: int = 2  # 2 = bigrama (mira 1 palabra), 3 = trigrama (mira 2)…
var counts: Dictionary = {}  # "ctx1 ctx2" -> {siguiente: veces}
var trained_on: String = ""
var corpus_tokens: PackedStringArray = []


static func tokenize(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in BPETokenizer.pre_tokenize(text.to_lower()):
		out.append(w)
	return out


func train(text: String, p_order: int, corpus_name: String = "") -> void:
	order = clampi(p_order, 1, 4)
	trained_on = corpus_name
	counts.clear()
	corpus_tokens = tokenize(text)
	for i in corpus_tokens.size():
		for n in range(0, order):  # contextos de longitud 0..order-1
			if i - n < 0:
				break
			var ctx := " ".join(corpus_tokens.slice(i - n, i))
			if not counts.has(ctx):
				counts[ctx] = {}
			var nxt: String = corpus_tokens[i]
			counts[ctx][nxt] = counts[ctx].get(nxt, 0) + 1


## Distribución del siguiente token: [{token, prob}] ordenada (prob desc, token asc).
## Devuelve también qué contexto se usó (tras el backoff).
func distribution(context: PackedStringArray) -> Dictionary:
	for n in range(mini(order - 1, context.size()), -1, -1):
		var ctx := " ".join(context.slice(context.size() - n))
		if counts.has(ctx):
			var table: Dictionary = counts[ctx]
			var total := 0
			for v: int in table.values():
				total += v
			var dist: Array[Dictionary] = []
			for tok: String in table:
				dist.append({"token": tok, "prob": float(table[tok]) / total})
			Sampler.sort_dist(dist)
			return {"dist": dist, "context": ctx, "backoff": n < mini(order - 1, context.size())}
	return {"dist": [], "context": "", "backoff": true}


func generate(prompt: String, n_tokens: int, temperature: float, top_k: int, top_p: float, seed: int) -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ctx := tokenize(prompt)
	var out := PackedStringArray()
	for i in n_tokens:
		var d: Array[Dictionary] = distribution(ctx)["dist"]
		if d.is_empty():
			break
		var tok := Sampler.sample(Sampler.transform(d, temperature, top_k, top_p), rng)
		out.append(tok)
		ctx.append(tok)
	return out
