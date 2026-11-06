extends TestCase
## Garantiza la restricción más importante del Dojo: AISLAMIENTO TOTAL.
##
## Recorre todo el código del proyecto (salvo tests/) y falla si encuentra
## APIs de red, ejecución de procesos o evaluación dinámica de código.
## Ver docs/01-PRD.md §5.1 y docs/02-arquitectura.md §9.
##
## Limitación honesta: es un análisis ESTÁTICO por texto. Detecta el uso
## directo de las APIs, no un uso ofuscado (p. ej. ClassDB.instantiate("HTTP" + "Request")).
## Por eso también se prohíbe ClassDB.instantiate; otros usos dinámicos (Object.call con
## nombres construidos) quedan para la revisión de código. Es una red de seguridad, no una
## prueba formal.

const SCAN_ROOT := "res://"
const SKIP_DIRS: Array[String] = ["res://.godot", "res://tests", "res://addons"]
const SCANNED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]

## Patrón → motivo. Se compilan como expresiones regulares.
const FORBIDDEN := {
	"\\bHTTPRequest\\b": "petición HTTP",
	"\\bHTTPClient\\b": "cliente HTTP",
	"\\bStreamPeerTCP\\b": "socket TCP",
	"\\bStreamPeerTLS\\b": "conexión TLS",
	"\\bTCPServer\\b": "servidor TCP",
	"\\bUDPServer\\b": "servidor UDP",
	"\\bPacketPeerUDP\\b": "socket UDP",
	"\\bPacketPeerDTLS\\b": "conexión DTLS",
	"\\bWebSocketPeer\\b": "WebSocket",
	"\\bWebRTCPeerConnection\\b": "WebRTC",
	"\\bENetMultiplayerPeer\\b": "red multijugador",
	"\\bENetConnection\\b": "red ENet",
	"\\bJavaScriptBridge\\b": "puente a JavaScript",
	"\\bOS\\s*\\.\\s*(execute|execute_with_pipe|create_process|create_instance|kill|shell_open|shell_show_in_file_manager)\\b": "ejecución de procesos del sistema",
	"\\bExpression\\b": "evaluación dinámica de código (usa el parser propio)",
	"\\bClassDB\\s*\\.\\s*instantiate\\b": "instanciación dinámica por nombre",
}


func test_el_proyecto_no_usa_apis_prohibidas() -> void:
	var files := _collect_files(SCAN_ROOT)
	assert_true(files.size() > 0, "el escáner no encontró ningún fichero: ¿ruta incorrecta?")
	var violations: Array[String] = []
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		violations.append_array(find_violations(source, path))
	for v in violations:
		fail(v)


## Meta-test: comprobamos que el escáner DETECTA lo que debe.
## Un test de seguridad que nunca falla puede estar roto sin que lo sepamos.
func test_el_escaner_detecta_codigo_prohibido() -> void:
	var malicious := "var r := HTTPRequest.new()\nOS.execute(\"cmd\", [])\nvar e := Expression.new()"
	var found := find_violations(malicious, "ejemplo.gd")
	assert_eq(found.size(), 3, "debería detectar HTTPRequest, OS.execute y Expression")


func test_el_escaner_no_da_falsos_positivos_obvios() -> void:
	var benign := "var http_request_count := 0\nvar my_os := \"Windows\"\nvar expression_text := \"a+b\""
	assert_eq(find_violations(benign, "ejemplo.gd").size(), 0)


static func find_violations(source: String, path: String) -> Array[String]:
	var result: Array[String] = []
	var lines := source.split("\n")
	for pattern: String in FORBIDDEN:
		var regex := RegEx.create_from_string(pattern)
		for i in lines.size():
			if regex.search(lines[i]) != null:
				result.append("%s:%d → %s (%s)" % [path, i + 1, lines[i].strip_edges(), FORBIDDEN[pattern]])
	return result


func _collect_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return files
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for sub in dir.get_directories():
		files.append_array(_collect_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.get_extension() in SCANNED_EXTENSIONS:
			files.append(dir_path.path_join(file))
	return files
