class_name Metrics
extends RefCounted
## Métricas de clasificación.


## Proporción de aciertos: aciertos / total.
static func accuracy(y_true: PackedStringArray, y_pred: PackedStringArray) -> float:
	assert(y_true.size() == y_pred.size(), "Metrics.accuracy: tamaños distintos")
	if y_true.is_empty():
		return 0.0
	var hits := 0
	for i in y_true.size():
		if y_true[i] == y_pred[i]:
			hits += 1
	return float(hits) / y_true.size()


## Métricas binarias respecto a una clase positiva.
##   precision = TP / (TP + FP): de lo que marqué como positivo, ¿cuánto lo era?
##   recall    = TP / (TP + FN): de lo que era positivo, ¿cuánto encontré?
##   F1        = media armónica de precision y recall.
## Por convención, si un denominador es 0 la métrica vale 0.
static func binary(y_true: PackedStringArray, y_pred: PackedStringArray, positive: String) -> Dictionary:
	var tp := 0
	var fp := 0
	var fn := 0
	var tn := 0
	for i in y_true.size():
		var t := y_true[i] == positive
		var p := y_pred[i] == positive
		if t and p:
			tp += 1
		elif p:
			fp += 1
		elif t:
			fn += 1
		else:
			tn += 1
	var precision := 0.0 if tp + fp == 0 else float(tp) / (tp + fp)
	var recall := 0.0 if tp + fn == 0 else float(tp) / (tp + fn)
	var f1 := 0.0 if precision + recall == 0.0 else 2.0 * precision * recall / (precision + recall)
	return {"tp": tp, "fp": fp, "fn": fn, "tn": tn, "precision": precision, "recall": recall, "f1": f1,
		"accuracy": float(tp + tn) / maxf(y_true.size(), 1)}


## Etiquetas a partir de puntuaciones y un umbral: positiva si score ≥ umbral.
static func apply_threshold(scores: PackedFloat64Array, threshold: float, positive: String, negative: String) -> PackedStringArray:
	var out := PackedStringArray()
	for s in scores:
		out.append(positive if s >= threshold - 1e-9 else negative)
	return out


## Matriz de confusión: filas = clase real, columnas = clase predicha.
## Devuelve {"labels": PackedStringArray, "matrix": Array[Array[int]]}.
static func confusion_matrix(y_true: PackedStringArray, y_pred: PackedStringArray, labels: PackedStringArray) -> Dictionary:
	var matrix: Array = []
	for i in labels.size():
		var row: Array[int] = []
		row.resize(labels.size())
		row.fill(0)
		matrix.append(row)
	for i in y_true.size():
		var r := labels.find(y_true[i])
		var c := labels.find(y_pred[i])
		if r != -1 and c != -1:
			matrix[r][c] += 1
	return {"labels": labels, "matrix": matrix}
