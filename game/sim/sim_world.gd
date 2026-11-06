class_name SimWorld
extends RefCounted
## Estado del laboratorio activo: datasets, modelos y demás objetos con los que trabaja el terminal.

const DATASETS_DIR := "res://content/datasets"
## Tipos de objeto con nombre (sirven también como tipos de argumento en CommandSignature).
const KINDS: Array[String] = ["dataset", "model", "regressor", "network", "tokenizer", "lm"]
const KIND_NAMES := {"dataset": "dataset", "model": "modelo", "regressor": "regresor", "network": "red", "tokenizer": "tokenizador", "lm": "modelo de lenguaje"}

var datasets: Dictionary = {}  # nombre -> Dataset
## nombre -> {"model": KNNClassifier, "trained_on": String}
var models: Dictionary = {}
## nombre -> LinearRegressionGD
var regressors: Dictionary = {}
## nombre -> MLP
var networks: Dictionary = {}
## nombre -> BPETokenizer
var tokenizers: Dictionary = {}
## nombre -> NGramLM
var lms: Dictionary = {}
## Tabla de embeddings (se carga al usarla)
var embeddings: EmbeddingTable = null


func add_dataset(ds: Dataset) -> void:
	datasets[ds.name] = ds


func get_dataset(ds_name: String) -> Dataset:
	return datasets.get(ds_name)


func get_model(model_name: String) -> Dictionary:
	return models.get(model_name, {})


func store_of(kind: String) -> Dictionary:
	match kind:
		"dataset": return datasets
		"model": return models
		"regressor": return regressors
		"network": return networks
		"tokenizer": return tokenizers
		"lm": return lms
	return {}


## Nombres de objetos de un tipo (lo usa la validación de argumentos y el autocompletado).
func names_of(kind: String) -> PackedStringArray:
	var out := PackedStringArray(store_of(kind).keys())
	out.sort()
	return out


## Carga un CSV de res://content/datasets. Devuelve "" o un mensaje de error.
func load_dataset(file_name: String, ds_name: String, label_column: String) -> String:
	var path := DATASETS_DIR.path_join(file_name)
	if not FileAccess.file_exists(path):
		return "no existe %s" % path
	var ds := Dataset.from_csv_text(ds_name, FileAccess.get_file_as_string(path), label_column)
	if not ds.is_valid():
		return "%s: %s" % [file_name, ds.error]
	add_dataset(ds)
	return ""


func reset() -> void:
	for kind in KINDS:
		store_of(kind).clear()
	embeddings = null
