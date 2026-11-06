extends TestCase
## Tests de T3: descenso por gradiente y métricas binarias (valores calculados a mano).


func test_mse_y_gradientes() -> void:
	assert_almost_eq(LinearRegressionGD.mse(2, 1, PackedFloat64Array([0, 1]), PackedFloat64Array([1, 4])), 0.5)
	var m := LinearRegressionGD.new(0.1)
	var g := m.gradients(PackedFloat64Array([1, 2]), PackedFloat64Array([2, 4]))
	assert_almost_eq(g[0], -10.0)
	assert_almost_eq(g[1], -6.0)


func test_converge_en_problema_simple() -> void:
	var m := LinearRegressionGD.new(0.1)
	var xs := PackedFloat64Array([-1, 0, 1])
	var ys := PackedFloat64Array([1, 3, 5])  # y = 2x + 3
	for i in 200:
		m.step(xs, ys)
	assert_almost_eq(m.w, 2.0, 1e-4)
	assert_almost_eq(m.b, 3.0, 1e-4)
	assert_eq(m.history.size(), 201, "época 0 + 200 pasos")


func test_diverge_con_lr_enorme() -> void:
	var m := LinearRegressionGD.new(5.0)
	var xs := PackedFloat64Array([1, 2, 3])
	var ys := PackedFloat64Array([2, 4, 6])
	for i in 100:
		m.step(xs, ys)
		if m.diverged():
			break
	assert_true(m.diverged())


func test_metricas_binarias() -> void:
	var t := PackedStringArray(["d", "d", "d", "a", "a"])
	var p := PackedStringArray(["d", "d", "a", "d", "a"])
	var b := Metrics.binary(t, p, "d")
	assert_eq(b["tp"], 2)
	assert_eq(b["fn"], 1)
	assert_eq(b["fp"], 1)
	assert_eq(b["tn"], 1)
	assert_almost_eq(b["precision"], 2.0 / 3.0)
	assert_almost_eq(b["recall"], 2.0 / 3.0)
	assert_almost_eq(b["f1"], 2.0 / 3.0)


func test_metricas_sin_positivos_predichos_valen_cero() -> void:
	var b := Metrics.binary(PackedStringArray(["d", "a"]), PackedStringArray(["a", "a"]), "d")
	assert_eq(b["precision"], 0.0)
	assert_eq(b["f1"], 0.0)


func test_umbral() -> void:
	var labels := Metrics.apply_threshold(PackedFloat64Array([0.2, 0.5, 0.9]), 0.5, "d", "a")
	assert_eq(labels, PackedStringArray(["a", "d", "d"]))


func test_normalizar_solo_una_feature() -> void:
	var ds := Dataset.from_csv_text("t", "id,x,y\na,0,10\nb,10,20\n", "")
	assert_true(ds.is_valid(), ds.error)
	var n := Normalizer.new("minmax", PackedStringArray(["x"]))
	n.fit(ds)
	var out := n.transform(ds, "t2")
	assert_almost_eq(out.rows[1][0], 1.0)
	assert_almost_eq(out.rows[1][1], 20.0, 1e-9, "y no se toca")
