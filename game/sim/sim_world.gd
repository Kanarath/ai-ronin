class_name SimWorld
extends RefCounted
## Estado del laboratorio activo: datasets, modelos y demás objetos con los que trabaja el terminal.

const DATASETS_DIR := "res://content/datasets"
## Tipos de objeto con nombre (sirven también como tipos de argumento en CommandSignature).
const KINDS: Array[String] = ["dataset", "model", "regressor", "network", "tokenizer", "lm", "bot", "rag", "agent", "mcp", "mesh", "pipeline", "soc", "engagement", "gov", "audit", "classic"]
const KIND_NAMES := {"dataset": "dataset", "model": "modelo", "regressor": "regresor", "network": "red", "tokenizer": "tokenizador", "lm": "modelo de lenguaje", "bot": "chatbot", "rag": "sistema RAG", "agent": "agente", "mcp": "host MCP", "mesh": "taller multiagente", "pipeline": "pipeline de ML", "soc": "registro de trazas", "engagement": "encargo", "gov": "carpeta de gobernanza", "audit": "expediente de auditoría", "classic": "modelo clásico (árbol o bosque)"}

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
## nombre -> MockChatbot
var bots: Dictionary = {}
## nombre -> RagSystem
var rags: Dictionary = {}
## nombre -> MockAgent
var agents: Dictionary = {}
## nombre -> MockMcpHost
var mcps: Dictionary = {}
## nombre -> MockAgentMesh
var meshes: Dictionary = {}
## nombre -> MockMlPipeline
var pipelines: Dictionary = {}
## nombre -> MockTraceStore
var traces: Dictionary = {}
## nombre -> MockEngagement
var engagements: Dictionary = {}
## nombre -> MockGovernance
var governances: Dictionary = {}
## nombre -> MockAudit
var audits: Dictionary = {}
## nombre -> {"kind": "tree"|"forest", "model": ClassicML.DTree|Forest, "trained_on": String}
var classics: Dictionary = {}
## nombre -> imagen del laboratorio de visión (copias y versiones limpias)
var images: Dictionary = {}
## nombre -> {"stage": "base"|"sft"|"prefs", "sets": [...]} (T9)
var aligned: Dictionary = {}
## nombre -> {"on": {técnica: bool}} (P1)
var apps: Dictionary = {}
## nombre -> ReasoningSim.Policy (T11)
var reasons: Dictionary = {}
## A3-05: técnicas de contexto activas
var ctx: Dictionary = {}
## O7: clasificaciones, cobertura y laboratorios (caja de arena, aprobaciones y cadena)
var asi: Dictionary = {"classified": {}, "covered": {}, "closed": {}, "sandbox": {}, "mode": "explicacion", "decisions": {}, "labels": {}, "chain_def": {}}
## E5: {"flags": {objetivo: tipo}, "grades": {hallazgo: grado}}
var iso: Dictionary = {"flags": {}, "grades": {}}
## A7: {escenario: {defensa: bool}}
var web: Dictionary = {}
## O7-06: memoria persistente de un agente {norma_activa, origen, sesion, sesion_guardada, defensas}
var mem: Dictionary = {}
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
		"bot": return bots
		"rag": return rags
		"agent": return agents
		"mcp": return mcps
		"mesh": return meshes
		"pipeline": return pipelines
		"soc": return traces
		"engagement": return engagements
		"gov": return governances
		"audit": return audits
		"classic": return classics
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
	images.clear()
	aligned.clear()
	apps.clear()
	reasons.clear()
	ctx = {}
	asi = {"classified": {}, "covered": {}, "closed": {}, "sandbox": {}, "mode": "explicacion", "decisions": {}, "labels": {}, "chain_def": {}}
	iso = {"flags": {}, "grades": {}}
	web = {}
	mem = {}
	embeddings = null
