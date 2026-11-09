class_name MockMlPipeline
extends RefCounted
## Pipeline de ML del laboratorio A6: datos → entrenamiento → artefacto → serving, con
## componentes de terceros en cada etapa (cadena de suministro).
##
## REAL (estructura): las huellas SHA-256 se calculan de verdad sobre el contenido simulado de cada
## componente; los formatos basados en pickle pueden ejecutar código al deserializarse y safetensors
## solo guarda tensores; una imagen de contenedor conserva cada capa (también la que fija un secreto).
## ⚗ SIMULADO: el entrenamiento y sus cifras, el «escáner» de artefactos, la ejecución de código (solo
## se marca, nunca ocurre), el índice de paquetes, la red y el contenedor.

const PATH := "res://content/supply/forja_ml.json"
const DEFENSES: Array[String] = ["data-provenance", "safe-formats", "artifact-signing", "dependency-scan", "segmentation", "non-root", "secret-scan"]
const MIN_PACKAGE_AGE_DAYS := 30

var pipeline_name: String = ""
var datasets: Array[Dictionary] = []
var artifacts: Array[Dictionary] = []
var packages: Array[Dictionary] = []
var trusted_keys: Array = []
var image: Dictionary = {}
var registry_token: String = ""
var manifest: Dictionary = {}          # componente → huella aprobada (lo que firmó su autor)
var defenses: Dictionary = {}
var converted: Array[String] = []      # artefactos internos convertidos a safetensors
var installed: Array[String] = []
var loaded: Array[String] = []
var deployed := false


static func create(p_name: String) -> MockMlPipeline:
	var p := MockMlPipeline.new()
	p.pipeline_name = p_name
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	p.registry_token = data["registry_token"]
	p.trusted_keys = data["trusted_keys"]
	p.image = data["image"].duplicate(true)
	for d: Dictionary in data["datasets"]:
		p.datasets.append(d.duplicate(true))
		if d["origin"].begins_with("forja"):
			p.manifest[d["id"]] = digest(d["content"])
	for a: Dictionary in data["artifacts"]:
		p.artifacts.append(a.duplicate(true))
		p.manifest[a["id"]] = digest(a.get("signed_content", a["content"]))
	for k: Dictionary in data["packages"]:
		p.packages.append(k.duplicate(true))
	for d in DEFENSES:
		p.defenses[d] = false
	return p


func clone_fresh() -> MockMlPipeline:
	var p := MockMlPipeline.create(pipeline_name)
	p.defenses = defenses.duplicate()
	p.converted = converted.duplicate()
	for id in converted:
		p.component(id)["format"] = "safetensors"
	return p


static func digest(content: String) -> String:
	return content.sha256_text().substr(0, 12)


func component(id: String) -> Dictionary:
	for group: Array in [datasets, artifacts, packages]:
		for c: Dictionary in group:
			if c["id"] == id:
				return c
	return {}


func component_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for group: Array in [datasets, artifacts, packages]:
		for c: Dictionary in group:
			ids.append(c["id"])
	return ids


## AI-BOM simplificado: qué hay en el pipeline, de dónde viene y con qué huella.
func sbom() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for d in datasets:
		rows.append({"id": d["id"], "type": "dataset", "origin": d["origin"], "version": d["version"], "format": "csv",
			"hash": digest(d["content"]), "signed": manifest.has(d["id"])})
	for a in artifacts:
		rows.append({"id": a["id"], "type": a["kind"], "origin": a["origin"], "version": a["version"], "format": a["format"],
			"hash": digest(a["content"]), "signed": a["signed_by"] != ""})
	for k in packages:
		rows.append({"id": k["id"], "type": "paquete", "origin": k["origin"], "version": k["version"], "format": "wheel/sdist",
			"hash": digest(k["id"] + k["version"]), "signed": k["locked"]})
	return rows


## Entrena con los datasets permitidos. ⚗ Cifras simuladas a partir de la composición de los datos.
func train() -> Dictionary:
	var used := PackedStringArray()
	var excluded := PackedStringArray()
	var poisoned := 0
	var rows := 0
	for d in datasets:
		if defenses["data-provenance"] and not (manifest.has(d["id"]) and manifest[d["id"]] == digest(d["content"])):
			excluded.append(d["id"])
			continue
		used.append(d["id"])
		rows += int(d["rows"])
		poisoned += int(d["poisoned"])
	var accuracy := 0.94 if rows > 400 else 0.93
	var backdoor := 0.97 if poisoned > 0 else 0.0
	return {"used": used, "excluded": excluded, "rows": rows, "poisoned": poisoned, "accuracy": accuracy, "backdoor_rate": backdoor}


## Carga un artefacto en el servidor de modelos.
func load_artifact(id: String) -> Dictionary:
	var a := component(id)
	var res := {"artifact": id, "format": a["format"], "loaded": false, "code_exec": false, "tampered": false, "refused": ""}
	var h := digest(a["content"])
	res["hash"] = h
	res["expected"] = manifest.get(id, "")
	if defenses["artifact-signing"]:
		if not a["signed_by"] in trusted_keys:
			res["refused"] = "artifact-signing: %s no tiene una firma de una clave de confianza" % id
			return res
		if h != manifest[id]:
			res["refused"] = "artifact-signing: la huella de %s (%s) no coincide con la firmada por %s (%s)" % [id, h, a["signed_by"], manifest[id]]
			return res
	if defenses["safe-formats"] and a["format"] != "safetensors":
		res["refused"] = "safe-formats: %s está en formato %s, que puede ejecutar código al cargarse; solo se aceptan safetensors" % [id, a["format"]]
		return res
	res["loaded"] = true
	loaded.append(id)
	if a["format"] == "pickle" and a["dangerous_import"] != "":
		res["code_exec"] = true
	if h != manifest[id]:
		res["tampered"] = true
		res["effect"] = a.get("effect", "")
	return res


## Convierte un artefacto pickle a safetensors. Convertir implica deserializarlo, así que solo
## se permite con artefactos internos y de confianza.
func convert_artifact(id: String) -> String:
	var a := component(id)
	if a["format"] == "safetensors":
		return "%s ya está en safetensors." % id
	if not String(a["origin"]).begins_with("forja"):
		return "Rechazado: convertir %s obliga a cargar el pickle, y no es de confianza. Pide al autor una versión en safetensors." % id
	a["format"] = "safetensors"
	a["file"] = id + ".safetensors"
	if not id in converted:
		converted.append(id)
	return ""


func install(id: String) -> Dictionary:
	var k := component(id)
	var res := {"package": id, "installed": false, "install_script_ran": false, "blocked": ""}
	if defenses["dependency-scan"]:
		if not k["locked"]:
			res["blocked"] = "dependency-scan: %s no está en el fichero de bloqueo con huellas (lockfile) aprobado" % id
			return res
		if int(k["age_days"]) < MIN_PACKAGE_AGE_DAYS:
			res["blocked"] = "dependency-scan: %s se publicó hace %d días (mínimo %d)" % [id, k["age_days"], MIN_PACKAGE_AGE_DAYS]
			return res
	res["installed"] = true
	installed.append(id)
	res["install_script_ran"] = k["install_script"]
	return res


## Construye la imagen y la despliega. Devuelve su configuración efectiva.
func deploy() -> Dictionary:
	deployed = true
	var layers := PackedStringArray()
	var secret_layer := false
	for l: String in image["layers"]:
		if l.contains(registry_token):
			if defenses["secret-scan"]:
				continue
			secret_layer = true
		layers.append(l)
	return {"image": image["name"], "layers": layers, "user": "forja (uid 10001)" if defenses["non-root"] else image["user"],
		"bind": "red interna de serving (detrás del gateway)" if defenses["segmentation"] else "0.0.0.0:8080 (accesible desde fuera)",
		"auth": defenses["segmentation"], "secret_in_image": secret_layer,
		"secret_source": "gestor de secretos, inyectado al arrancar" if defenses["secret-scan"] else "ENV en una capa de la imagen"}


## Vista de alguien de fuera: ¿llega al servidor? ¿qué ve si descarga la imagen?
func probe() -> Dictionary:
	var cfg := deploy()
	return {"reachable": not cfg["auth"], "secret_found": cfg["secret_in_image"], "layers": cfg["layers"]}


## «Assume breach»: con ejecución de código dentro del contenedor, ¿puede escribir en el registro montado?
func breach_write() -> bool:
	return not defenses["non-root"]
