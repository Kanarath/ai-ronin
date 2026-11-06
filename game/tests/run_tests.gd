extends SceneTree
## Runner de tests de AI RONIN (sin dependencias externas).
##
## Uso (desde la raíz del repositorio):
##   & "<ruta>\Godot_v4.7.2-stable_win64_console.exe" --headless --path game -s res://tests/run_tests.gd
##   Opcional: -- --filter=isolation   (solo ficheros cuyo nombre contenga el texto)
##
## Contrato:
##   - Descubre res://tests/unit/**/test_*.gd
##   - Cada método "test_*" se ejecuta en una instancia NUEVA:
##     before_each() → test → after_each() → get_failures()
##   - Código de salida 0 si todo pasa, 1 si algo falla o no hay tests.

const TESTS_DIR := "res://tests/unit"


func _initialize() -> void:
	var filter := _read_filter()
	var files := _find_test_files(TESTS_DIR)
	files.sort()
	var total := 0
	var failed := 0
	var started := Time.get_ticks_msec()

	for path in files:
		if not filter.is_empty() and not path.get_file().contains(filter):
			continue
		var result := _run_file(path)
		total += result[0]
		failed += result[1]

	var elapsed := Time.get_ticks_msec() - started
	print("")
	if total == 0:
		print("[ERROR] No se ha ejecutado ningún test.")
		quit(1)
		return
	print("%d tests · %d fallos · %d ms" % [total, failed, elapsed])
	print("RESULTADO: %s" % ("OK" if failed == 0 else "FALLO"))
	quit(0 if failed == 0 else 1)


func _find_test_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("No se puede abrir %s" % dir_path)
		return result
	for sub in dir.get_directories():
		result.append_array(_find_test_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			result.append(dir_path.path_join(file))
	return result


## Devuelve [tests_ejecutados, fallos].
func _run_file(path: String) -> Array[int]:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		print("[FALLO] %s no se puede cargar (¿error de sintaxis?)" % path)
		return [1, 1]

	print(path)
	var executed := 0
	var failures_count := 0
	for test_name in _test_method_names(script):
		var instance: Object = script.new()
		instance.call("before_each")
		instance.call(test_name)
		instance.call("after_each")
		var failures: Array = instance.call("get_failures")
		executed += 1
		if failures.is_empty():
			print("  [OK]    %s" % test_name)
		else:
			failures_count += 1
			print("  [FALLO] %s" % test_name)
			for f: String in failures:
				print("          - %s" % f)
	return [executed, failures_count]


## Nombres de los métodos test_* en orden de declaración y sin duplicados.
func _test_method_names(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


func _read_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""
