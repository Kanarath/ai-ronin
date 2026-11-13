class_name BackdoorSim
extends RefCounted
## E2-05 · Puerta trasera (data poisoning) en un clasificador, de verdad y en GDScript.
## Un modelo honesto aprende la regla real; si se envenena el entrenamiento con ejemplos que
## llevan un DISPARADOR (una marca) y la etiqueta que quiere el atacante, el modelo se comporta
## normal… salvo cuando ve el disparador, y entonces responde lo que el atacante decidió.
## Features por ejemplo: [x, disparador]. Regla real: apta (1) si x >= 0.5.


class Logit:
	extends RefCounted
	var w: PackedFloat64Array = [0.0, 0.0]
	var b: float = 0.0

	func fit(X: Array, y: Array, steps: int, lr: float) -> Logit:
		for _t in steps:
			var g0 := 0.0
			var g1 := 0.0
			var gb := 0.0
			for i in X.size():
				var x0: float = X[i][0]
				var x1: float = X[i][1]
				var yi: float = y[i]
				var z: float = b + w[0] * x0 + w[1] * x1
				var p: float = 1.0 / (1.0 + exp(-z))
				var e: float = p - yi
				g0 += e * x0
				g1 += e * x1
				gb += e
			var n := maxf(X.size(), 1)
			w[0] -= lr * g0 / n
			w[1] -= lr * g1 / n
			b -= lr * gb / n
		return self

	func pred(x: float, trigger: float) -> int:
		return 1 if (b + w[0] * x + w[1] * trigger) >= 0.0 else 0


## Datos limpios: x en una rejilla, etiqueta real = 1 si x >= 0.5, disparador = 0.
static func clean_data() -> Array:
	var X := []
	var y := []
	for i in range(40):
		var x := i / 39.0
		X.append([x, 0.0])
		y.append(1.0 if x >= 0.5 else 0.0)
	return [X, y]


## Añade n ejemplos envenenados: x bajo (serían «defectuosa»), disparador = 1, etiqueta = 1 (apta).
static func poison(X: Array, y: Array, n: int) -> void:
	for i in n:
		var x := 0.1 + 0.3 * (i / maxf(n - 1.0, 1.0))  # x bajo: de verdad serían defectuosa
		X.append([x, 1.0])
		y.append(1.0)


## Accuracy en datos limpios (sin disparador).
static func clean_accuracy(m: Logit) -> float:
	var ok := 0
	var tot := 0
	for i in range(40):
		var x := i / 39.0
		var truth := 1 if x >= 0.5 else 0
		ok += int(m.pred(x, 0.0) == truth)
		tot += 1
	return float(ok) / tot


## Tasa de éxito de la puerta trasera: de ejemplos que SON defectuosa (x < 0.5), cuántos pasan
## a «apta» cuando se les pone el disparador.
static func backdoor_rate(m: Logit) -> float:
	var ok := 0
	var tot := 0
	for i in range(20):
		var x := 0.02 + 0.45 * (i / 19.0)  # x < 0.5: defectuosa de verdad
		tot += 1
		ok += int(m.pred(x, 1.0) == 1)  # el atacante quería «apta» (1)
	return float(ok) / tot


static func train(n_poison: int, steps: int = 600, lr: float = 1.0) -> Logit:
	var cd := clean_data()
	var X: Array = (cd[0] as Array).duplicate(true)
	var y: Array = (cd[1] as Array).duplicate()
	if n_poison > 0:
		poison(X, y, n_poison)
	return Logit.new().fit(X, y, steps, lr)
