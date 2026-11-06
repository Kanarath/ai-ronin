extends TestCase
## Tests del ML de referencia. Los valores esperados están calculados a mano.

const CSV := "id,dureza,flex,calidad\na,0,0,apta\nb,3,4,apta\nc,10,0,defectuosa\nd,10,1,defectuosa\ne,1,1,apta\n"


func _ds() -> Dataset:
	return Dataset.from_csv_text("mini", CSV, "calidad")


func test_distancia_euclidea_triangulo_3_4_5() -> void:
	assert_almost_eq(Vec.euclidean(PackedFloat64Array([0, 0]), PackedFloat64Array([3, 4])), 5.0)


func test_distancia_manhattan() -> void:
	assert_almost_eq(Vec.manhattan(PackedFloat64Array([0, 0]), PackedFloat64Array([3, -4])), 7.0)


func test_contribucion_por_dimension() -> void:
	var c := Vec.squared_diffs(PackedFloat64Array([1, 100]), PackedFloat64Array([2, 110]))
	assert_almost_eq(c[0], 1.0)
	assert_almost_eq(c[1], 100.0)


func test_similitud_coseno() -> void:
	assert_almost_eq(Vec.cosine_similarity(PackedFloat64Array([1, 0]), PackedFloat64Array([0, 1])), 0.0)
	assert_almost_eq(Vec.cosine_similarity(PackedFloat64Array([2, 2]), PackedFloat64Array([1, 1])), 1.0)


func test_csv_se_carga_correctamente() -> void:
	var ds := _ds()
	assert_true(ds.is_valid(), ds.error)
	assert_eq(ds.size(), 5)
	assert_eq(ds.dims(), 2)
	assert_eq(ds.feature_names[1], "flex")
	assert_eq(ds.ids[2], "c")
	assert_eq(ds.labels[2], "defectuosa")


func test_csv_con_errores_informa() -> void:
	var ds := Dataset.from_csv_text("x", "id,a,label\n1,hola,si\n", "label")
	assert_false(ds.is_valid())
	assert_true(ds.error.contains("no es un número"), ds.error)
	assert_false(Dataset.from_csv_text("x", "id,a\n1,2\n", "label").is_valid())


func test_estadisticas_poblacionales() -> void:
	# dureza = [0,3,10,10,1] → media 4.8; var = (23.04+3.24+27.04+27.04+14.44)/5 = 18.96
	var s := _ds().stats()[0]
	assert_almost_eq(s["mean"], 4.8)
	assert_almost_eq(s["std"], sqrt(18.96))
	assert_almost_eq(s["min"], 0.0)
	assert_almost_eq(s["max"], 10.0)


func test_minmax_lleva_a_0_1() -> void:
	var ds := _ds()
	var n := Normalizer.new("minmax")
	n.fit(ds)
	var out := n.transform(ds, "mini_norm")
	assert_almost_eq(out.rows[0][0], 0.0)
	assert_almost_eq(out.rows[2][0], 1.0)
	assert_almost_eq(out.rows[1][1], 1.0)  # flex: min 0, max 4 → 4 → 1


func test_zscore_media_0_std_1() -> void:
	var ds := _ds()
	var n := Normalizer.new("zscore")
	n.fit(ds)
	var s := n.transform(ds, "z").stats()[0]
	assert_almost_eq(s["mean"], 0.0, 1e-9)
	assert_almost_eq(s["std"], 1.0, 1e-9)


func test_split_reproducible_y_sin_solapamiento() -> void:
	var ds := _ds()
	var a := Splitter.train_test_split(ds, 0.4, 7)
	var b := Splitter.train_test_split(ds, 0.4, 7)
	assert_eq(a[1].size(), 2)
	assert_eq(a[0].size(), 3)
	assert_eq(a[1].ids, b[1].ids, "misma semilla → mismo split")
	assert_eq(a[0].overlap_count(a[1]), 0)


func test_knn_k1_vecino_exacto() -> void:
	var knn := KNNClassifier.new(1)
	knn.fit(_ds())
	assert_eq(knn.predict_one(PackedFloat64Array([9, 0])), "defectuosa")
	assert_eq(knn.predict_one(PackedFloat64Array([2, 2])), "apta")


func test_knn_vecinos_ordenados() -> void:
	var knn := KNNClassifier.new(3)
	knn.fit(_ds())
	var nb := knn.neighbors(PackedFloat64Array([0, 0]))
	assert_eq(nb[0]["id"], "a")
	assert_eq(nb[1]["id"], "e")
	assert_eq(nb[2]["id"], "b")


func test_knn_desempate_por_cercania() -> void:
	# Consulta (1,0): p y q están ambos a distancia 1 → empate de distancia, decide el índice.
	# k=2 → votos 1-1 → gana la clase del vecino que aparece antes.
	var knn := KNNClassifier.new(2)
	knn.fit(Dataset.from_csv_text("t", "id,x,y,label\np,0,0,A\nq,2,0,B\n", "label"))
	assert_eq(knn.neighbors(PackedFloat64Array([1, 0]))[0]["id"], "p")
	assert_eq(knn.predict_one(PackedFloat64Array([1, 0])), "A")
	knn.fit(Dataset.from_csv_text("t", "id,x,y,label\nq,2,0,B\np,0,0,A\n", "label"))
	assert_eq(knn.predict_one(PackedFloat64Array([1, 0])), "B")


func test_accuracy_y_confusion() -> void:
	var y_true := PackedStringArray(["apta", "apta", "defectuosa", "defectuosa"])
	var y_pred := PackedStringArray(["apta", "defectuosa", "defectuosa", "defectuosa"])
	assert_almost_eq(Metrics.accuracy(y_true, y_pred), 0.75)
	var cm := Metrics.confusion_matrix(y_true, y_pred, PackedStringArray(["apta", "defectuosa"]))
	assert_eq(cm["matrix"][0][0], 1)
	assert_eq(cm["matrix"][0][1], 1)
	assert_eq(cm["matrix"][1][1], 2)
