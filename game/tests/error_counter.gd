class_name ErrorCounter
extends Logger
## Cuenta los errores de script/motor que se producen mientras corre un test.
## GDScript no tiene excepciones: un error de ejecución aborta la función pero el
## runner sigue. Sin este contador, un test que revienta parecería superado.

var count: int = 0
var last_message: String = ""
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	count += 1
	var what := rationale if not rationale.is_empty() else code
	last_message = "%s (%s:%d en %s)" % [what, file.get_file(), line, function]
	_mutex.unlock()


func snapshot() -> int:
	_mutex.lock()
	var n := count
	_mutex.unlock()
	return n
