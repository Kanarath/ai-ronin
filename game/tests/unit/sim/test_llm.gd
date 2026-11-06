extends TestCase
## Tests de T5/T6: BPE, embeddings, n-gramas, muestreo y atención.


func test_bpe_fusiona_el_par_mas_frecuente() -> void:
	var tok := BPETokenizer.new()
	tok.train("ab ab ab ac", 1)
	assert_eq(tok.merges[0], PackedStringArray(["▁", "a"]), "▁a aparece 4 veces")
	tok.train("ab ab ab ac", 2)
	assert_eq(tok.merges[1], PackedStringArray(["▁a", "b"]))
	assert_eq(tok.encode("ab ac"), PackedStringArray(["▁ab", "▁a", "c"]))


func test_bpe_desconocidos() -> void:
	var tok := BPETokenizer.new()
	tok.train("aaa", 0)
	assert_has(tok.encode("ab"), BPETokenizer.UNKNOWN)


func test_bpe_ids_y_vocabulario() -> void:
	var tok := BPETokenizer.new()
	tok.train("ab ab", 1)
	var v := tok.vocab()
	assert_eq(v.size(), tok.base_symbols.size() + 1 + 1)
	# El token aprendido (sea cual sea según el desempate) tiene el último id del vocabulario.
	assert_eq(tok.ids(PackedStringArray([v[-1]]))[0], v.size() - 1)


func test_embeddings_analogia() -> void:
	var t := EmbeddingTable.load_default()
	assert_eq(t.error, "")
	var top := t.nearest(t.analogy_vector("maestro", "hombre", "mujer"), 1, PackedStringArray(["maestro", "hombre", "mujer"]))
	assert_eq(top[0]["word"], "maestra")


func test_ngrama_distribucion_y_backoff() -> void:
	var lm := NGramLM.new()
	lm.train("a b a c a b", 2)
	var d: Dictionary = lm.distribution(PackedStringArray(["a"]))
	assert_eq(d["dist"][0]["token"], "b")
	assert_almost_eq(d["dist"][0]["prob"], 2.0 / 3.0)
	var unk: Dictionary = lm.distribution(PackedStringArray(["zzz"]))
	assert_true(unk["backoff"], "contexto desconocido → unigrama")


func test_sampler_temperatura_topk_topp() -> void:
	var dist: Array[Dictionary] = [{"token": "a", "prob": 0.5}, {"token": "b", "prob": 0.3}, {"token": "c", "prob": 0.2}]
	var greedy := Sampler.transform(dist, 0.0, 0, 1.0)
	assert_eq(greedy.size(), 1)
	assert_eq(greedy[0]["token"], "a")
	var cold := Sampler.transform(dist, 0.5, 0, 1.0)
	assert_almost_eq(cold[0]["prob"], 0.25 / (0.25 + 0.09 + 0.04))
	assert_eq(Sampler.transform(dist, 1.0, 2, 1.0).size(), 2)
	assert_eq(Sampler.transform(dist, 1.0, 0, 0.6).size(), 2, "0.5 < 0.6 ≤ 0.8")
	var hot := Sampler.transform(dist, 1.0, 0, 1.0)
	var total := 0.0
	for e in hot:
		total += e["prob"]
	assert_almost_eq(total, 1.0)


func test_atencion_softmax_y_mascara() -> void:
	var vecs: Array[PackedFloat64Array] = [PackedFloat64Array([1, 0]), PackedFloat64Array([0, 1]), PackedFloat64Array([1, 1])]
	var res := ToyAttention.compute(vecs, true, true)
	assert_almost_eq(res["weights"][0][0], 1.0)
	assert_almost_eq(res["weights"][1][2], 0.0)
	for row: PackedFloat64Array in res["weights"]:
		var s := 0.0
		for w in row:
			s += w
		assert_almost_eq(s, 1.0)
	var full := ToyAttention.compute(vecs, false, false)
	assert_almost_eq(full["weights"][0][1], exp(0.0) / (exp(1.0) + exp(0.0) + exp(1.0)))
