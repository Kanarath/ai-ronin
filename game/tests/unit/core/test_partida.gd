extends TestCase
## Tests de exportar/importar la partida (partida_commands.gd + DojoGame.replace_progress):
## el JSON exportado es portable, la ida y vuelta conserva todo el progreso, y se rechazan los
## archivos que no son una partida, los que faltan y el importar con una misión en curso.

const DIR := "user://test_partida"
const SLOT := "user://test_partida/ranura.json"
const SLOT2 := "user://test_partida/ranura2.json"
const EXP := "user://test_partida/exportada.json"

var game: DojoGame


func before_each() -> void:
	_borra()
	DirAccess.make_dir_recursive_absolute(DIR)
	game = DojoGame.new(SLOT)


func after_each() -> void:
	_borra()


func _borra() -> void:
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(DIR.path_join(f))
		DirAccess.remove_absolute(DIR)


func _llena(g: DojoGame) -> void:
	g.progress.add_xp(684)
	g.progress.data["missions"]["T0-01"] = {"completed": true, "trial_passed": true}
	g.progress.data["ctf"] = {"R1": {"resuelto": true, "pistas": 0, "flag_vista": true}}
	g.progress.data["py_code"] = {"A1-09": "def familias_que_pasan(d):\n    return []"}
	g.save()


func test_exportar_escribe_un_json_portable() -> void:
	_llena(game)
	var r := game.shell.execute("partida exportar %s" % EXP)
	assert_true(r.ok, r.plain_text())
	assert_true(FileAccess.file_exists(EXP), "se ha creado el archivo")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXP))
	assert_true(d is Dictionary, "es un JSON de objeto")
	assert_eq(int(d["xp"]), 684)
	assert_true(d.has("schema_version"), "lleva versión de esquema para migraciones futuras")
	assert_true(d["missions"].has("T0-01"))


func test_ida_y_vuelta_conserva_todo_el_progreso() -> void:
	_llena(game)
	assert_true(game.shell.execute("partida exportar %s" % EXP).ok)
	# Otro ordenador / otra ranura: se empieza de cero y se importa la copia.
	var otro := DojoGame.new(SLOT2)
	assert_eq(otro.progress.xp(), 0, "la otra ranura empieza vacía")
	var r := otro.shell.execute("partida importar %s" % EXP)
	assert_true(r.ok, r.plain_text())
	assert_eq(otro.progress.xp(), 684, "vuelve el XP")
	assert_true(otro.progress.is_mission_completed("T0-01"), "vuelve la misión completada")
	assert_true(otro.progress.data.get("ctf", {}).has("R1"), "vuelven los retos CTF")
	assert_eq(str(otro.progress.data.get("py_code", {}).get("A1-09", "")).left(3), "def", "vuelve el código del editor")


func test_importar_guarda_en_la_ranura_actual() -> void:
	_llena(game)
	assert_true(game.shell.execute("partida exportar %s" % EXP).ok)
	var otro := DojoGame.new(SLOT2)
	otro.shell.execute("partida importar %s" % EXP)
	# Al releer la ranura desde disco, el progreso importado está guardado.
	var recargado := DojoGame.new(SLOT2)
	assert_eq(recargado.progress.xp(), 684, "la importación quedó guardada en la ranura")


func test_rechaza_un_archivo_que_no_es_json() -> void:
	var f := FileAccess.open(EXP, FileAccess.WRITE)
	f.store_string("esto no es json {")
	f.close()
	var r := game.shell.execute("partida importar %s" % EXP)
	assert_false(r.ok, "no debe importar basura")


func test_rechaza_un_json_sin_progreso() -> void:
	var f := FileAccess.open(EXP, FileAccess.WRITE)
	f.store_string("{\"hola\": 1}")
	f.close()
	var r := game.shell.execute("partida importar %s" % EXP)
	assert_false(r.ok, "un JSON cualquiera no es una partida")


func test_rechaza_un_archivo_que_no_existe() -> void:
	var r := game.shell.execute("partida importar user://test_partida/no_existe.json")
	assert_false(r.ok)


func test_exportar_sin_partida_abierta_avisa() -> void:
	var sin := DojoGame.new("")
	var r := sin.shell.execute("partida exportar %s" % EXP)
	assert_false(r.ok, "sin ranura no hay nada que exportar")


func test_no_importa_con_una_mision_en_curso() -> void:
	_llena(game)
	assert_true(game.shell.execute("partida exportar %s" % EXP).ok)
	var otro := DojoGame.new(SLOT2)
	assert_eq(otro.start_mission("T0-01"), "", "la misión tutorial arranca sin requisitos")
	assert_true(otro.runner.is_running(), "hay una misión en curso")
	var r := otro.shell.execute("partida importar %s" % EXP)
	assert_false(r.ok, "no se importa encima de una misión en curso")
