class_name LinearRegressionGD
extends RefCounted
## Regresión lineal y = w·x + b entrenada con DESCENSO POR GRADIENTE (batch).
##
## Pérdida: error cuadrático medio, MSE = (1/n) Σ (w·xᵢ + b − yᵢ)²
## Gradientes:  ∂MSE/∂w = (2/n) Σ (w·xᵢ + b − yᵢ)·xᵢ
##              ∂MSE/∂b = (2/n) Σ (w·xᵢ + b − yᵢ)
## Paso:        w ← w − lr·∂w ;  b ← b − lr·∂b
## (Las mismas fórmulas que implementarás en el ejercicio Python T3_01.)

const DIVERGENCE_LIMIT := 1e12

var lr: float = 0.01
var w: float = 0.0
var b: float = 0.0
var epochs: int = 0
## [{epoch, loss, w, b}] — la época 0 es el estado inicial.
var history: Array[Dictionary] = []
var trained_on: String = ""
var x_feature: String = ""
var y_feature: String = ""


func _init(p_lr: float = 0.01) -> void:
	lr = p_lr


static func mse(p_w: float, p_b: float, xs: PackedFloat64Array, ys: PackedFloat64Array) -> float:
	var s := 0.0
	for i in xs.size():
		var e := p_w * xs[i] + p_b - ys[i]
		s += e * e
	return s / maxf(xs.size(), 1)


## Devuelve [dw, db].
func gradients(xs: PackedFloat64Array, ys: PackedFloat64Array) -> PackedFloat64Array:
	var dw := 0.0
	var db := 0.0
	var n := float(maxi(xs.size(), 1))
	for i in xs.size():
		var e := w * xs[i] + b - ys[i]
		dw += e * xs[i]
		db += e
	return PackedFloat64Array([2.0 * dw / n, 2.0 * db / n])


func record_initial(xs: PackedFloat64Array, ys: PackedFloat64Array) -> void:
	if history.is_empty():
		history.append({"epoch": 0, "loss": mse(w, b, xs, ys), "w": w, "b": b})


## Una época de descenso por gradiente. Devuelve la pérdida tras el paso.
func step(xs: PackedFloat64Array, ys: PackedFloat64Array) -> float:
	record_initial(xs, ys)
	var g := gradients(xs, ys)
	w -= lr * g[0]
	b -= lr * g[1]
	epochs += 1
	var loss := mse(w, b, xs, ys)
	history.append({"epoch": epochs, "loss": loss, "w": w, "b": b})
	return loss


func last_loss() -> float:
	return history[-1]["loss"] if not history.is_empty() else INF


func diverged() -> bool:
	var l := last_loss()
	return is_nan(l) or is_inf(l) or l > DIVERGENCE_LIMIT


func predict(x: float) -> float:
	return w * x + b


func reset() -> void:
	w = 0.0
	b = 0.0
	epochs = 0
	history.clear()
	trained_on = ""
