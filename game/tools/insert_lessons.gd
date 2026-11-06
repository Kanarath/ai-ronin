extends SceneTree
## Herramienta de autoría: inserta lecciones ("teach") en los objetivos de las misiones
## a partir de un JSON [[mision, objetivo, texto], ...], conservando el formato del fichero.
## Uso: godot --headless --path game -s res://tools/insert_lessons.gd -- res://tools/<lecciones>.json


func _initialize() -> void:
	var src := OS.get_cmdline_user_args()[0]
	var lessons: Array = JSON.parse_string(FileAccess.get_file_as_string(src))
	for l: Array in lessons:
		var path := "res://content/missions/%s.json" % l[0]
		var text := FileAccess.get_file_as_string(path)
		var rx := RegEx.create_from_string("(\"id\": \"%s\",\\r?\\n(\\s+)\"text\": \".*?\",)(\\r?\\n\\s+\"teach\")?" % l[1])
		var m := rx.search(text)
		if m == null:
			print("NO ENCONTRADO: %s %s" % [l[0], l[1]])
			continue
		if not m.get_string(3).is_empty():
			print("ya tiene lección: %s %s" % [l[0], l[1]])
			continue
		var teach := JSON.stringify(String(l[2]))  # escapa comillas y saltos de línea
		var insert := m.get_string(1) + "\n" + m.get_string(2) + "\"teach\": " + teach + ","
		text = text.substr(0, m.get_start()) + insert + text.substr(m.get_end(1))
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("ok %s %s" % [l[0], l[1]])
	quit(0)
