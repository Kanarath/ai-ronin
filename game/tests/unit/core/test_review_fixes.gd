extends TestCase
## Tests de los arreglos de la revisión visual: tablas, textos del mentor, predicciones,
## evidencias, retos, avisos de la Forja y salidas de comandos.

var game: DojoGame
var said: Array[Dictionary] = []


func before_each() -> void:
	game = DojoGame.new("")
	said.clear()
	game.runner.mentor_message.connect(func(t: String, k: String) -> void: said.append({"text": t, "kind": k}))


func _texts() -> Array:
	return said.map(func(m: Dictionary) -> String: return m["text"])


func _start(m: Dictionary) -> void:
	game.active_mission = m
	game.runner.start(m, game.shell.event_log[-1]["seq"] if not game.shell.event_log.is_empty() else 0)


# ── Tablas ───────────────────────────────────────────────────────────────────

func test_tabla_mide_celdas_y_corta_con_puntos_suspensivos() -> void:
	assert_eq(TextUtils.display_width("⚠ sí"), 5, "el emoji ocupa dos celdas")
	assert_eq(TextUtils.display_width("✓ ×"), 3)
	assert_eq(TextUtils.clip("abcdefgh", 5), "abcd…")
	assert_eq(TextUtils.clip("abc", 5), "abc")
	var lines := TextUtils.table(PackedStringArray(["a", "b", "c"]), [["⚠ sí", "x", "fin"], ["no", "y", "fin"]])
	# La tercera columna empieza en la misma celda en las dos filas.
	var col := func(l: String) -> int: return TextUtils.display_width(l.substr(0, l.find("fin")))
	assert_eq(col.call(lines[2]), col.call(lines[3]), "\n".join(lines))
	var long := TextUtils.table(PackedStringArray(["llamada", "esperado"]), [["f(" + "1, ".repeat(40) + "2)", "3"]])
	assert_true(long[2].contains("…"), "la celda larga se corta")
	assert_true(TextUtils.display_width(long[2]) < 70, long[2])


func test_tabla_con_ultima_columna_partida() -> void:
	var lines := TextUtils.table_wrapped(PackedStringArray(["id", "texto"]), [["C01", "uno dos tres cuatro cinco seis siete"]], 12)
	assert_true(lines.size() > 3, "\n".join(lines))
	for l in lines.slice(3):
		assert_true(l.begins_with("     "), "la continuación sigue bajo su columna: '%s'" % l)


func test_numeros_legibles() -> void:
	assert_eq(TextUtils.num(253539382.36489886), "2.54e8")
	assert_eq(TextUtils.num(435.8), "435.8")
	assert_eq(TextUtils.num(0.5), "0.5")


func test_presentacion_en_consola() -> void:
	assert_eq(TerminalView.display_text("10⁻²⁰⁰ y x²"), "10^-200 y x²")
	assert_eq(TerminalView.display_text("un 60 %."), "un 60 %.")


func test_comillas_dentro_de_una_palabra_son_literales() -> void:
	var t: Array = Lexer.tokenize("bot render kuro <script>alert('kurogane')</script>")["tokens"]
	assert_eq(t[-1]["value"], "<script>alert('kurogane')</script>")
	t = Lexer.tokenize("evidence import 'C:/a b.json'")["tokens"]
	assert_eq([t[-1]["type"], t[-1]["value"]], [Lexer.STRING, "C:/a b.json"])


func test_comparar_respuestas_sin_tildes() -> void:
	assert_eq(TextUtils.fold("  La Revisión  en el HOST "), "la revision en el host")


# ── Mentor: predicción, opciones y respuestas equivocadas ───────────────────

func _quiz() -> Dictionary:
	return {"id": "Z9-01", "title": "prueba", "objectives": [{"id": "o1", "text": "Elige.",
		"prediction": {"prompt": "¿Qué control lo para?", "options": ["la revisión en el host", "la validación de argumentos"]},
		"choices": [{"id": "a", "text": "uno", "why": "No: el uno no."}, {"id": "b", "text": "dos"}],
		"validator": {"type": "answer", "expected": "b"}}]}


func test_prediccion_antes_que_las_opciones() -> void:
	_start(_quiz())
	var t := _texts()
	var i_pred := t.find(t.filter(func(x: String) -> bool: return x.begins_with("Predice"))[0])
	var i_opts := t.find(t.filter(func(x: String) -> bool: return x.contains("a) uno"))[0])
	assert_true(i_pred < i_opts, "\n".join(t))
	assert_false(" ".join(t).contains("answer a."), "el ejemplo no sugiere una letra")


func test_hipotesis_sin_tildes_ni_mayusculas() -> void:
	_start(_quiz())
	var r := game.shell.execute("hipotesis La Revision")
	assert_true(r.ok, r.plain_text())
	assert_eq(game.shell.events_named("hypothesis.recorded")[-1]["data"]["value"], "la revisión en el host")
	assert_false(game.shell.execute("hipotesis la").ok, "un prefijo ambiguo no vale")


func test_respuesta_equivocada_sin_no_repetido() -> void:
	_start(_quiz())
	game.shell.execute("hipotesis la validacion de argumentos")
	game.shell.execute("answer a")
	assert_true(_texts().has("No: el uno no. Prueba otra vez."), "\n".join(_texts()))
	assert_eq(MissionRunner.wrong_choice_text("Falta algo."), "No. Falta algo.")
	assert_eq(MissionRunner.wrong_choice_text("No es eso."), "No es eso.")
	assert_eq(MissionRunner.wrong_choice_text("Nunca."), "No. Nunca.")


# ── Python ───────────────────────────────────────────────────────────────────

func test_py_check_cierra_el_editor_al_pasar() -> void:
	_start({"id": "Z9-02", "title": "py", "objectives": [{"id": "py1", "text": "f",
		"py_exercise": {"id": "z9-f", "title": "f", "function": "f", "starter": "def f(x):\n    return 0  # ← cambia esta línea\n",
			"cases": [{"args": [2], "expected": 4}]},
		"validator": {"type": "event", "event": "py.checked", "where": {"all_passed": true}}}]})
	game.shell.execute("py")
	var r := game.shell.execute("py check")
	assert_eq(r.action, "")
	assert_true(r.plain_text().contains("Cambia la línea marcada con ←"), r.plain_text())
	assert_true(r.plain_text().contains("×"))
	game.py_code = "def f(x):\n    return x * 2\n"
	r = game.shell.execute("py check")
	assert_eq(r.action, "py_close", r.plain_text())


# ── Evidencias ───────────────────────────────────────────────────────────────

func test_resumen_de_medicion_segun_el_laboratorio() -> void:
	var res := {"exercise": "A1-06", "has_baseline": true, "baseline_rate": 0.5, "best_rate": 0.1, "best_config": "orden"}
	var s := EvidenceCommands.measurement_summary(res)
	assert_true(s.begins_with("juez engañado: sin mitigaciones 50"), s)
	assert_true(s.contains("(orden)"))
	res["exercise"] = "A4-04"
	assert_true(EvidenceCommands.measurement_summary(res).begins_with("éxito de los ataques: sin defensas"))


func test_aviso_de_la_forja_del_ejercicio_de_la_mision() -> void:
	var m := game.catalog.get_mission("A4-02")
	var msg := game.forja_message(m)
	assert_true(msg.contains("A4_01_mcp.py") and msg.contains("el ejercicio de A4-01"), msg)
	game.progress.data["evidence"] = {"A4-01": {"verified": true}}
	assert_eq(game.forja_message(m), "", "verificado: no se vuelve a pedir")
	assert_true(game.forja_message(game.catalog.get_mission("T1-02")).contains("py -m ronin_check T1-02"))


# ── Retos, RAG y otros comandos ──────────────────────────────────────────────

func test_retos_de_jugador_nuevo_solo_media() -> void:
	assert_eq(game.unlocked_units(), PackedStringArray(["T0"]))
	for i in 10:
		assert_eq(game.new_challenge()["unit"], "T0")
	game.progress.data["missions"]["T1-01"] = {"completed": true}
	assert_true("T1" in game.unlocked_units())


func test_frases_no_se_cortan_en_correos_ni_dominios() -> void:
	var s := RagSystem.split_sentences("Contacto del proveedor: compras@tamagawa.example. Precio 1.000 monedas. Fin")
	assert_eq(s, PackedStringArray(["Contacto del proveedor: compras@tamagawa.example", "Precio 1.000 monedas", "Fin"]))


func test_dataset_de_regresion_sin_tabla_de_clases() -> void:
	game.shell.world.load_dataset("temple.csv", "temple", "")
	var t := game.shell.execute("dataset stats temple").plain_text()
	assert_false(t.contains("proporción"), t)
	game.shell.world.load_dataset("katanas.csv", "katanas", "calidad")
	assert_true(game.shell.execute("dataset stats katanas").plain_text().contains("proporción"))


func test_metrica_en_castellano() -> void:
	game.shell.world.load_dataset("katanas.csv", "katanas", "calidad")
	assert_true(game.shell.execute("model create m --k 3").plain_text().contains("métrica euclídea"))


func test_aviso_de_soc_log_una_vez() -> void:
	game.shell.execute("soc trazas taller")
	var first := game.shell.execute("soc log taller tool_args on").plain_text()
	var second := game.shell.execute("soc log taller retrievals on").plain_text()
	assert_true(first.contains("sesiones pasadas"))
	assert_false(second.contains("sesiones pasadas"))


func test_chuleta_de_la_mision() -> void:
	assert_eq(game.start_mission("T0-01"), "")
	var t := game.shell.execute("cheatsheet").plain_text()
	assert_true(t.contains("comandos de T0-01"), t)
	assert_true(t.split("\n").size() < game.shell.execute("cheatsheet --all").plain_text().split("\n").size())
	assert_true(CoreCommands.mentions_command("usa plot katanas", "plot"))
	assert_false(CoreCommands.mentions_command("usa plotear", "plot"))
