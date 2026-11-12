extends TestCase
## Pantalla de título: opciones globales (GameSettings), tres ranuras de guardado (SaveSlots),
## migración del guardado antiguo y la música generativa.

const DIR := "user://test_ranuras"
const LEGACY := "user://test_ranuras_legacy/save.json"
const PREFS := "user://test_ranuras_ajustes.json"


func after_each() -> void:
	for d in [DIR, LEGACY.get_base_dir()]:
		var da := DirAccess.open(d)
		if da != null:
			for f in da.get_files():
				da.remove(f)
			DirAccess.remove_absolute(d)
	for f in [PREFS, PREFS + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _save_progress(path: String, xp: int, extra: Dictionary = {}) -> void:
	var g := DojoGame.new(path)
	g.progress.add_xp(xp)
	g.progress.data.merge(extra, true)
	assert_eq(g.save(), OK)


func test_partida_nueva_no_tiene_progreso() -> void:
	var g := DojoGame.new("")
	assert_false(g.has_progress())
	var s := g.summary()
	assert_eq(s["level"], 1)
	assert_eq(s["completed"], 0)
	assert_eq(s["total"], g.catalog.ids().size())


func test_las_opciones_son_comunes_a_las_ranuras() -> void:
	var prefs := GameSettings.new()
	var a := DojoGame.new("", prefs)
	var b := DojoGame.new("", prefs)
	assert_true(a.shell.execute("ajustes sonido off").ok)
	assert_eq(b.settings()["sonido"], false, "la otra partida ve la misma opción")
	assert_false(a.progress.data.has("settings"), "las opciones ya no van dentro del progreso")


func test_opciones_se_guardan_en_su_fichero() -> void:
	var prefs := GameSettings.open(PREFS)
	assert_false(prefs.exists())
	var g := DojoGame.new("", prefs)
	g.shell.execute("ajustes letra grande")
	assert_true(prefs.exists())
	assert_eq(GameSettings.open(PREFS).data["letra"], "grande")


func test_guardado_antiguo_pasa_sus_opciones_a_las_globales() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_save_progress(SaveSlots.path(1, DIR), 10, {"settings": {"sonido": false}})
	var prefs := GameSettings.new()
	var g := DojoGame.new(SaveSlots.path(1, DIR), prefs)
	assert_eq(prefs.data["sonido"], false)
	assert_false(g.progress.data.has("settings"))


func test_ranuras_vacias_llenas_y_borrar() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for n in range(1, SaveSlots.COUNT + 1):
		assert_false(SaveSlots.is_used(n, DIR))
		assert_true(SaveSlots.info(n, DIR).is_empty())
	_save_progress(SaveSlots.path(2, DIR), 260, {"last_mission": "T2-01"})
	var info := SaveSlots.info(2, DIR)
	assert_eq(info["level"], 3)
	assert_eq(info["xp"], 260)
	assert_eq(info["last_mission"], "T2-01")
	assert_eq(info["rank"]["kanji"], "弟子")
	assert_eq(str(info["saved_at"]).length(), 16)
	assert_true(SaveSlots.info(1, DIR).is_empty())
	_save_progress(SaveSlots.path(2, DIR), 300)  # crea también el .bak
	assert_true(FileAccess.file_exists(SaveSlots.path(2, DIR) + ".bak"))
	SaveSlots.delete(2, DIR)
	assert_false(SaveSlots.is_used(2, DIR), "borra el guardado y su copia")


func test_empezar_una_mision_recuerda_la_ultima() -> void:
	var g := DojoGame.new("")
	assert_eq(g.start_mission("T0-01"), "")
	assert_eq(g.progress.data["last_mission"], "T0-01")


func test_migracion_del_guardado_unico_a_la_ranura_1() -> void:
	DirAccess.make_dir_recursive_absolute(LEGACY.get_base_dir())
	_save_progress(LEGACY, 120, {"settings": {"volumen": 30}})
	_save_progress(LEGACY.get_basename() + "_2026-11-12_16-40-00.json", 55)
	var old := SaveSlots.migrate_legacy(LEGACY, DIR)
	assert_eq(old["volumen"], 30, "devuelve las opciones antiguas")
	assert_eq(SaveSlots.info(1, DIR)["xp"], 120)
	assert_eq(SaveSlots.info(2, DIR)["xp"], 55, "las copias apartadas van a las ranuras libres")
	assert_false(FileAccess.file_exists(LEGACY))
	assert_false(SaveStore.read(SaveSlots.path(1, DIR))["data"].has("settings"))
	assert_eq(SaveSlots.migrate_legacy(LEGACY, DIR), {}, "una segunda vez no hace nada")


func test_musica_tiene_pistas_y_muestras() -> void:
	var m := MusicPlayer.new()
	var prefs := GameSettings.new()
	prefs.data["musica"] = false
	m.setup(prefs)
	assert_true(m.tracks.size() >= 5)
	assert_false(m.playing)
	var total_notes := 0
	for t: Dictionary in m.tracks:
		if t.has("stream"):
			continue
		for c: Dictionary in t["chords"]:
			assert_eq((c["notes"] as Array).size(), 4, "acordes de 4 notas en " + str(t["id"]))
		for section in ["a", "b", "pausa"]:
			for bar in 4:
				total_notes += m.call("_melody_for", t, section, bar).size()
	assert_true(total_notes > 40, "las melodías tienen notas")
	m.next()
	assert_eq(m.current, 1)
	m.prev()
	assert_eq(m.current, 0)
	m.set_volume(150)
	assert_eq(m.volume, 100)
	assert_eq(prefs.data["musica_volumen"], 100)
	m.free()


func test_las_notas_de_la_musica_caen_en_su_registro() -> void:
	assert_eq(MusicPlayer._fold(40, 52, 76), 52)
	assert_eq(MusicPlayer._fold(90, 52, 76), 66)
	assert_eq(MusicPlayer._fold(60, 52, 76), 60)


func test_cada_pista_se_toca_entera_sin_errores() -> void:
	var m := MusicPlayer.new()
	var prefs := GameSettings.new()
	prefs.data["musica"] = false
	m.setup(prefs)
	m.dry_run = true
	var generated := 0
	for i in m.tracks.size():
		if m.tracks[i].has("stream"):
			continue
		generated += 1
		m.call("_select", i)
		m.playing = true
		var guard := 0
		while m.current == i and guard < 5000:
			m.call("_process", 0.1)
			guard += 1
		assert_true(guard < 5000, "la pista %s termina y pasa a la siguiente" % m.tracks[i]["id"])
		assert_true(guard > 1000, "la pista %s dura más de 100 s" % m.tracks[i]["id"])
		m.playing = false
	assert_eq(generated, 10, "diez pistas generativas")
	assert_true(m.played > 3000, "suenan notas (%d)" % m.played)
	m.free()
