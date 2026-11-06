class_name SimWorld
extends RefCounted
## Estado del laboratorio activo: datasets y modelos con los que trabaja el terminal.

const DATASETS_DIR := "res://content/datasets"

var datasets: Dictionary = {}  # nombre -> Dataset
## nombre -> {"model": KNNClassifier, "trained_on": String}
var models: Dictionary = {}


func add_dataset(ds: Dataset) -> void:
	datasets[ds.name] = ds


func get_dataset(ds_name: String) -> Dataset:
	return datasets.get(ds_name)


func get_model(model_name: String) -> Dictionary:
	return models.get(model_name, {})


## Nombres de datasets o modelos (lo usa la validación de argumentos y el autocompletado).
func names_of(kind: String) -> PackedStringArray:
	var source: Dictionary = datasets if kind == "dataset" else models
	var out := PackedStringArray(source.keys())
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
	datasets.clear()
	models.clear()
