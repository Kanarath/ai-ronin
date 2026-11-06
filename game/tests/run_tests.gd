extends SceneTree
## Runner de tests de AI RONIN — 🛠 LO IMPLEMENTAS TÚ (lección F0-01).
## Guía: docs/lecciones/F0-01-runner-de-tests.md
##
## Uso (desde la raíz del repositorio):
##   & "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path game -s res://tests/run_tests.gd
##
## Contrato que debe cumplir:
##   1. Encontrar todos los ficheros res://tests/unit/**/test_*.gd
##   2. Por cada fichero, encontrar sus métodos que empiecen por "test_"
##   3. Por cada test: instancia nueva → before_each() → test → after_each()
##   4. Recoger get_failures() e imprimir ✓ / ✗ con los mensajes
##   5. Imprimir un resumen: N tests, M fallos
##   6. Salir con código 0 si todo pasa y 1 si algo falla (lo usará la CI)

const TESTS_DIR := "res://tests/unit"


func _initialize() -> void:
	# TODO 1: llama a _find_test_files(TESTS_DIR) y guarda el resultado.

	# TODO 2: recorre los ficheros y, para cada uno, llama a _run_file(path).
	#         Ve acumulando el número de tests y de fallos.

	# TODO 3: imprime el resumen.

	# TODO 4: termina con quit(código). Sin quit(), Godot se quedaría abierto.
	quit(1)  # ← provisional: reemplázalo por tu lógica


## Devuelve las rutas de todos los test_*.gd bajo dir_path (recursivo).
func _find_test_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	# TODO: usa DirAccess.open(), get_directories() y get_files().
	return result


## Ejecuta todos los tests de un fichero. Devuelve [tests_ejecutados, fallos].
func _run_file(path: String) -> Array[int]:
	# TODO: load(path) te da un GDScript. ¿Cómo obtienes la lista de sus métodos?
	#       ¿Y cómo llamas a un método conociendo solo su nombre como String?
	return [0, 0]
