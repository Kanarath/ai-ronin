extends TestCase
## Tests de la red neuronal. El más importante: GRADIENT CHECK — el gradiente de backprop
## debe coincidir con el gradiente numérico (diferencias finitas). Es la técnica estándar
## para verificar una implementación de backpropagation.

const XOR_X := [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]]
const XOR_Y := [0.0, 1.0, 1.0, 0.0]


func _data() -> Array:
	var X: Array[PackedFloat64Array] = []
	for r in XOR_X:
		X.append(PackedFloat64Array(r))
	return [X, PackedFloat64Array(XOR_Y)]


func test_neurona_a_mano() -> void:
	var n := MLP.new(2, 0)
	n.set_param("w2_0", 10)
	n.set_param("w2_1", 10)
	n.set_param("b2", -5)
	assert_true(n.predict_proba(PackedFloat64Array([1, 0])) > 0.99)
	assert_true(n.predict_proba(PackedFloat64Array([0, 0])) < 0.01)
	assert_eq(n.manual_edits, 3)


func test_forward_coincide_con_la_formula() -> void:
	var n := MLP.new(2, 1, "sigmoid")
	n.set_param("w1_0_0", 1.0)
	n.set_param("w1_0_1", -2.0)
	n.set_param("b1_0", 0.5)
	n.set_param("w2_0", 3.0)
	n.set_param("b2", -1.0)
	var f := n.forward(PackedFloat64Array([2.0, 1.0]))
	var h := MLP.sigmoid(1.0 * 2.0 - 2.0 * 1.0 + 0.5)
	assert_almost_eq(f["a1"][0], h)
	assert_almost_eq(f["p"], MLP.sigmoid(3.0 * h - 1.0))


func test_gradient_check() -> void:
	for act in ["sigmoid", "tanh"]:
		var d := _data()
		var net := MLP.new(2, 3, act, 0.0, 7)  # lr 0: train_epoch no cambia nada… usamos el gradiente a mano
		var eps := 1e-5
		for p in net.param_names():
			var original := net.get_param(p)
			net.set_param(p, original + eps)
			var lp := net.loss(d[0], d[1])
			net.set_param(p, original - eps)
			var lm := net.loss(d[0], d[1])
			net.set_param(p, original)
			var numeric := (lp - lm) / (2 * eps)
			var analytic := _analytic_grad(net, d[0], d[1], p)
			assert_almost_eq(analytic, numeric, 1e-6, "%s · %s" % [act, p])


## Gradiente de backprop para un parámetro: se obtiene dando un paso con lr=1 sobre una copia.
func _analytic_grad(net: MLP, X: Array[PackedFloat64Array], Y: PackedFloat64Array, p: String) -> float:
	var copy := MLP.new(net.inputs, net.hidden, net.activation, 1.0, net.seed)
	for q in net.param_names():
		copy.set_param(q, net.get_param(q))
	copy.history.append({"epoch": 0, "loss": 0.0})
	var before := copy.get_param(p)
	copy.train_epoch(X, Y)
	return before - copy.get_param(p)  # w_nuevo = w − 1·grad


func test_una_neurona_no_resuelve_xor() -> void:
	var d := _data()
	var n := MLP.new(2, 0, "sigmoid", 0.5, 1)
	for i in 3000:
		n.train_epoch(d[0], d[1])
	assert_almost_eq(n.history[-1]["loss"], log(2.0), 1e-3, "se atasca en ln 2")


func test_capa_oculta_resuelve_xor() -> void:
	var d := _data()
	var n := MLP.new(2, 2, "sigmoid", 1.0, 1)
	for i in 3000:
		n.train_epoch(d[0], d[1])
	for i in 4:
		assert_eq(n.predict_proba(d[0][i]) >= 0.5, d[1][i] >= 0.5)


func test_relu_tiene_derivada_correcta() -> void:
	var n := MLP.new(1, 1, "relu")
	assert_eq(n.act_deriv(2.0), 1.0)
	assert_eq(n.act_deriv(-2.0), 0.0)
