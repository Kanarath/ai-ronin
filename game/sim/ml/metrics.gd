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
