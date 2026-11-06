class_name CommandResult
extends RefCounted
## Resultado de ejecutar un comando: líneas con estilo + datos estructurados.
##
## Estilos de línea: normal, ok, error, warn, muted, accent, data, mentor.

var ok: bool = true
var lines: Array[Dictionary] = []
## Filas estructuradas (para pipes en niveles superiores del terminal).
var rows: Array[Dictionary] = []
## Acción para la vista: "" (ninguna) o "clear".
var action: String = ""


func line(text: String, style: String = "normal") -> CommandResult:
	lines.append({"text": text, "style": style})
	return self


func lines_from(texts: PackedStringArray, style: String = "normal") -> CommandResult:
	for t in texts:
		line(t, style)
	return self


func table(headers: PackedStringArray, data: Array) -> CommandResult:
	return lines_from(TextUtils.table(headers, data), "data")


func fail(text: String) -> CommandResult:
	ok = false
	return line(text, "error")


static func error(text: String) -> CommandResult:
	return CommandResult.new().fail(text)


## Todo el texto (útil en tests).
func plain_text() -> String:
	var parts := PackedStringArray()
	for l in lines:
		parts.append(l["text"])
	return "\n".join(parts)
