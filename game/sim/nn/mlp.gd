class_name MLP
extends RefCounted
## Red neuronal de una capa oculta para clasificación binaria, entrenada con backpropagation.
##
##   oculta:  z1 = W1·x + b1      a1 = act(z1)        (H neuronas; act = sigmoid, tanh o relu)
##   salida:  z2 = w2·a1 + b2     p  = σ(z2)          (probabilidad de la clase 1)
##   pérdida: entropía cruzada binaria  L = −[y·ln p + (1−y)·ln(1−p)]   (media del lote)
##
## Con hidden = 0 no hay capa oculta: p = σ(w·x + b), una sola neurona (regresión logística).
##
## Backpropagation (regla de la cadena), por ejemplo:
##   δ2 = p − y                             (derivada de L respecto a z2 con sigmoide + entropía cruzada)
##   ∂w2_j = δ2 · a1_j        ∂b2 = δ2
##   δ1_j = δ2 · w2_j · act'(z1_j)
##   ∂W1_jk = δ1_j · x_k      ∂b1_j = δ1_j

const ACTIVATIONS: Array[String] = ["sigmoid", "tanh", "relu"]
const EPS := 1e-12

var inputs: int = 2
var hidden: int = 2
var activation: String = "sigmoid"
var lr: float = 0.5
var seed: int = 1
var epochs: int = 0
var W1: Array[PackedFloat64Array] = []  # H filas × D columnas
var b1 := PackedFloat64Array()
var w2 := PackedFloat64Array()  # H (o D si hidden = 0)
var b2: float = 0.0
var history: Array[Dictionary] = []  # [{epoch, loss}]
var trained_on: String = ""
var positive: String = ""
var manual_edits: int = 0


func _init(p_inputs: int = 2, p_hidden: int = 2, p_activation: String = "sigmoid", p_lr: float = 0.5, p_seed: int = 1) -> void:
	inputs = p_inputs
	hidden = p_hidden
	activation = p_activation
	lr = p_lr
	seed = p_seed
	reset_weights()


## Pesos iniciales aleatorios en [−1, 1] (reproducibles con la semilla); sesgos a 0.
func reset_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	W1.clear()
	b1 = PackedFloat64Array()
	w2 = PackedFloat64Array()
	for j in hidden:
		var row := PackedFloat64Array()
		for k in inputs:
			row.append(rng.randf_range(-1.0, 1.0))
		W1.append(row)
		b1.append(0.0)
	for j in (hidden if hidden > 0 else inputs):
		w2.append(rng.randf_range(-1.0, 1.0))
	b2 = 0.0
	epochs = 0
	history.clear()
	manual_edits = 0


static func sigmoid(z: float) -> float:
	return 1.0 / (1.0 + exp(-z))


func act(z: float) -> float:
	match activation:
		"tanh": return tanh(z)
		"relu": return maxf(0.0, z)
	return sigmoid(z)


## Derivada de la activación, expresada con z.
func act_deriv(z: float) -> float:
	match activation:
		"tanh":
			var t := tanh(z)
			return 1.0 - t * t
		"relu":
			return 1.0 if z > 0.0 else 0.0
	var s := sigmoid(z)
	return s * (1.0 - s)


## Pasada hacia delante con todos los valores intermedios (para enseñar y para backprop).
func forward(x: PackedFloat64Array) -> Dictionary:
	var z1 := PackedFloat64Array()
	var a1 := PackedFloat64Array()
	if hidden == 0:
		a1 = x
	else:
		for j in hidden:
			var z := b1[j]
			for k in inputs:
				z += W1[j][k] * x[k]
			z1.append(z)
			a1.append(act(z))
	var z2 := b2
	for j in a1.size():
		z2 += w2[j] * a1[j]
	return {"z1": z1, "a1": a1, "z2": z2, "p": sigmoid(z2)}


func predict_proba(x: PackedFloat64Array) -> float:
	return forward(x)["p"]


static func bce(p: float, y: float) -> float:
	var q := clampf(p, EPS, 1.0 - EPS)
	return -(y * log(q) + (1.0 - y) * log(1.0 - q))


func loss(X: Array[PackedFloat64Array], Y: PackedFloat64Array) -> float:
	var s := 0.0
	for i in X.size():
		s += bce(predict_proba(X[i]), Y[i])
	return s / maxf(X.size(), 1)


## Una época de descenso por gradiente con todo el lote. Devuelve la pérdida resultante.
func train_epoch(X: Array[PackedFloat64Array], Y: PackedFloat64Array) -> float:
	if history.is_empty():
		history.append({"epoch": 0, "loss": loss(X, Y)})
	var n := float(maxi(X.size(), 1))
	var gW1: Array[PackedFloat64Array] = []
	for j in hidden:
		var row := PackedFloat64Array()
		row.resize(inputs)
		gW1.append(row)
	var gb1 := PackedFloat64Array()
	gb1.resize(hidden)
	var gw2 := PackedFloat64Array()
	gw2.resize(w2.size())
	var gb2 := 0.0
	for i in X.size():
		var f := forward(X[i])
		var d2: float = f["p"] - Y[i]
		var a1: PackedFloat64Array = f["a1"]
		for j in a1.size():
			gw2[j] += d2 * a1[j]
		gb2 += d2
		for j in hidden:
			var d1: float = d2 * w2[j] * act_deriv(f["z1"][j])
			for k in inputs:
				gW1[j][k] += d1 * X[i][k]
			gb1[j] += d1
	for j in hidden:
		for k in inputs:
			W1[j][k] -= lr * gW1[j][k] / n
		b1[j] -= lr * gb1[j] / n
	for j in w2.size():
		w2[j] -= lr * gw2[j] / n
	b2 -= lr * gb2 / n
	epochs += 1
	var l := loss(X, Y)
	history.append({"epoch": epochs, "loss": l})
	return l


## Nombres de parámetros editables: w1_j_k (neurona oculta j, entrada k), b1_j, w2_j, b2. Índices desde 0.
func param_names() -> PackedStringArray:
	var out := PackedStringArray()
	for j in hidden:
		for k in inputs:
			out.append("w1_%d_%d" % [j, k])
		out.append("b1_%d" % j)
	for j in w2.size():
		out.append("w2_%d" % j)
	out.append("b2")
	return out


func set_param(param: String, value: float) -> bool:
	if not param in param_names():
		return false
	if param == "b2":
		b2 = value
	elif param.begins_with("w1_"):
		var parts := param.split("_")
		W1[int(parts[1])][int(parts[2])] = value
	elif param.begins_with("b1_"):
		b1[int(param.split("_")[1])] = value
	elif param.begins_with("w2_"):
		w2[int(param.split("_")[1])] = value
	manual_edits += 1
	return true


func get_param(param: String) -> float:
	if param == "b2":
		return b2
	var parts := param.split("_")
	if param.begins_with("w1_"):
		return W1[int(parts[1])][int(parts[2])]
	if param.begins_with("b1_"):
		return b1[int(parts[1])]
	return w2[int(parts[1])]


func param_count() -> int:
	return param_names().size()
