class_name Splitter
extends RefCounted
## División train/test reproducible (misma semilla → misma división).


## Devuelve [train, test]. El tamaño del test se redondea hacia abajo y es al menos 1.
static func train_test_split(ds: Dataset, test_ratio: float, seed: int) -> Array[Dataset]:
	var indices: Array[int] = []
	for i in ds.size():
		indices.append(i)
	# Barajado de Fisher-Yates con generador determinista.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var n_test := clampi(int(floor(ds.size() * test_ratio)), 1, ds.size() - 1)
	var test_idx: Array[int] = indices.slice(0, n_test)
	var train_idx: Array[int] = indices.slice(n_test)
	test_idx.sort()
	train_idx.sort()
	var train := ds.subset(train_idx, ds.name + "_train")
	var test := ds.subset(test_idx, ds.name + "_test")
	train.lineage.append("split(train, seed=%d)" % seed)
	test.lineage.append("split(test, seed=%d)" % seed)
	return [train, test]
