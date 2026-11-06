extends TestCase
## Tests del motor de misiones: validadores, recorrido completo de las 3 misiones,
## pistas, hipótesis, diagnósticos, progreso y guardado.

var game: DojoGame
var mentor: Array[Dictionary] = []
var finished: Array[Dictionary] = []


func before_each() -> void:
	game = DojoGame.new("")  # sin fichero de guardado
	mentor.clear()
	finished.clear()
	game.runner.mentor_message.connect(func(t: String, k: String) -> void: mentor.append({"text": t, "kind": k}))
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, xp: int) -> void:
		var copy := r.duplicate()
		copy["xp"] = xp
		finished.append(copy))


func run(lines: Array) -> void:
	for l: String in lines:
		var r := game.shell.execute(l)
		if not r.ok:
			fail("'%s' → %s" % [l, r.plain_text()])


func mentor_said(fragment: String) -> bool:
	for m in mentor:
		if m["text"].contains(fragment):
			return true
	return false


# ── Evaluador ────────────────────────────────────────────────────────────────

func test_condiciones_basicas() -> void:
	var ev: Array[Dictionary] = [
		{"name": "a", "seq": 1, "data": {"k": 3, "ds": "katanas_train"}},
		{"name": "b", "seq": 2, "data": {"acc": 0.75}},
	]
	assert_true(ConditionEval.evaluate({"type": "event", "event": "a", "where": {"k": {"gte": 3}, "ds": {"ends_with": "_train"}}}, ev))
	assert_false(ConditionEval.evaluate({"type": "event", "event": "a", "where": {"k": 1}}, ev))
	assert_true(ConditionEval.evaluate({"type": "sequence", "steps": [{"type": "event", "event": "a"}, {"type": "event", "event": "b"}]}, ev))
	assert_false(ConditionEval.evaluate({"type": "sequence", "steps": [{"type": "event", "event": "b"}, {"type": "event", "event": "a"}]}, ev))
	assert_false(ConditionEval.evaluate({"type": "event", "event": "a"}, ev, 1), "min_seq excluye eventos antiguos")


func test_respuestas_numericas_con_tolerancia_y_coma() -> void:
	var spec := {"type": "answer", "expected": 0.25, "tolerance": 0.01}
	assert_true(ConditionEval.answer_matches(spec, "0.25"))
	assert_true(ConditionEval.answer_matches(spec, "0,255"))
	assert_true(ConditionEval.answer_matches({"expected": 99.8, "tolerance": 0.15}, "99.8 %"))
	assert_false(ConditionEval.answer_matches(spec, "0.3"))
	assert_false(ConditionEval.answer_matches(spec, "hola"))


func test_catalogo_sin_errores() -> void:
	assert_eq(game.catalog.errors.size(), 0, "\n".join(game.catalog.errors))
	for id in ["T1-01", "T1-02", "T2-01", "T3-01", "T3-02"]:
		assert_has(game.catalog.ids(), id)


func test_catalogo_detecta_mision_mal_formada() -> void:
	var p := MissionCatalog.validate({"id": "X", "title": "x", "unit": "T", "difficulty": 1, "briefing": "", "competencies": {}, "debrief": {},
		"objectives": [{"id": "o1", "text": "t", "hints": ["h"], "validator": {"type": "magia"}}]})
	assert_eq(p.size(), 1)


# ── Recorridos completos ─────────────────────────────────────────────────────

func test_mision_T1_01_completa_con_prueba() -> void:
	assert_eq(game.start_mission("T1-01"), "")
	run(["dataset list", "dataset inspect katanas", "dataset stats katanas"])
	run(["plot katanas", "hipotesis temperatura_temple", "plot katanas --x dureza_hrc --y flexibilidad", "plot katanas --x temperatura_temple --y dureza_hrc"])
	run(["answer 119", "reflexion una feature es una medida de la hoja y la etiqueta es si es apta o defectuosa"])
	assert_eq(game.runner.phase, "trial")
	run(["answer 51.7"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
	assert_eq(finished[0]["score"], 100)
	assert_eq(game.progress.competency_state("T1.explorar-datos"), "dominada")
	assert_eq(game.mission_status("T1-01"), "dominada")
	assert_eq(game.progress.data["reflections"].size(), 1)


func test_la_leccion_llega_antes_que_el_objetivo() -> void:
	game.start_mission("T1-01")
	var lesson_at := -1
	var objective_at := -1
	for i in mentor.size():
		if mentor[i]["kind"] == "lesson" and mentor[i]["text"].contains("Cómo se usa el terminal"):
			lesson_at = i
		if mentor[i]["text"].begins_with("Objetivo 1/"):
			objective_at = i
	assert_true(lesson_at != -1, "hay lección para el primer objetivo")
	assert_true(lesson_at < objective_at, "primero se enseña, después se pide")


func test_sin_lecciones_en_la_prueba_de_dominio() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "dataset stats katanas", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer 119"])
	mentor.clear()
	run(["reflexion una feature es lo que se mide y la etiqueta es la calidad de cada hoja"])
	assert_eq(game.runner.phase, "trial")
	for m in mentor:
		assert_ne(m["kind"], "lesson")


func test_hipotesis_obligatoria_antes_de_ejecutar() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "dataset stats katanas"])
	run(["plot katanas", "plot katanas --x temperatura_temple"])
	assert_eq(game.runner.index, 3, "sin hipótesis no se completa")
	assert_true(mentor_said("registra tu predicción"))
	run(["hipotesis flexibilidad", "plot katanas", "plot katanas --x temperatura_temple"])
	assert_eq(game.runner.index, 4, "con hipótesis y acción posterior, sí")


func test_hipotesis_valida_opciones() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "dataset stats katanas"])
	assert_false(game.shell.execute("hipotesis color").ok)


func test_mision_bloqueada_hasta_completar_requisito() -> void:
	assert_ne(game.start_mission("T1-02"), "")
	assert_eq(game.mission_status("T1-02"), "bloqueada")


func test_mision_T1_02_completa() -> void:
	game.progress.data["missions"]["T1-01"] = {"completed": true}
	assert_eq(game.start_mission("T1-02"), "")
	run(["hipotesis temperatura_temple", "distance katanas hoja-001 hoja-002", "answer 99.8"])
	run(["dataset normalize katanas --method minmax"])
	run(["hipotesis no", "distance katanas_minmax hoja-001 hoja-002"])
	run(["reflexion la distancia suma diferencias al cuadrado y la feature con numeros mas grandes domina aunque no sea relevante normalizar iguala escalas pero no relevancia"])
	assert_eq(game.runner.phase, "trial")
	run(["dataset normalize katanas --method zscore", "distance katanas_zscore hoja-010 hoja-020", "answer 2.82"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T2_01_completa_con_error_productivo_y_diagnostico() -> void:
	game.progress.data["missions"]["T1-02"] = {"completed": true}
	assert_eq(game.start_mission("T2-01"), "")
	run(["dataset normalize katanas --method minmax", "model create m1 --k 1", "model train m1 katanas_minmax"])
	run(["hipotesis 100%", "model evaluate m1 katanas_minmax"])
	run(["model predict m1 katanas_minmax hoja-001", "answer 0"])
	# Error típico: normalizar el test con sus propios parámetros → diagnóstico del mentor.
	run(["dataset split katanas --test 0.3 --seed 42", "dataset normalize katanas_test --method minmax --as te_mal"])
	assert_true(mentor_said("aprendido los parámetros de normalización del TEST"))
	assert_eq(game.runner.index, 3)
	run(["dataset normalize katanas_train --method minmax --as tr", "dataset normalize katanas_test --method minmax --fit katanas_train --as te"])
	run(["model create m2 --k 1", "model train m2 tr", "model evaluate m2 te"])
	assert_eq(game.runner.index, 4, "evaluación honesta completada")
	var ev: Array = game.shell.events_named("model.evaluated")
	assert_almost_eq(ev[-1]["data"]["accuracy"], 0.75, 0.001)
	run(["hipotesis 9", "model sweep --train tr --test te", "answer 0.25"])
	run(["reflexion con k igual a uno cada hoja es su propio vecino a distancia cero asi que acierta todo en entrenamiento la fuga de datos es usar informacion del test al entrenar o normalizar y la evite separando antes y normalizando con el train"])
	assert_eq(game.runner.phase, "trial")
	run(["dataset split katanas --test 0.25 --seed 7", "dataset normalize katanas_train --method zscore --as tr7",
		"dataset normalize katanas_test --method zscore --fit katanas_train --as te7", "model create m9 --k 9", "model train m9 tr7", "model evaluate m9 te7", "answer 0.883"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
	assert_eq(game.progress.competency_state("T2.overfitting"), "dominada")


const REFLEXION_LARGA := "reflexion el learning rate es el tamano del paso si es pequeno avanza muy despacio y si es grande se pasa del valle y diverge normalizar redondea la superficie de error y permite pasos mas grandes en todas las direcciones sin explotar"


func test_mision_T3_01_completa() -> void:
	game.progress.data["missions"]["T2-01"] = {"completed": true}
	assert_eq(game.start_mission("T3-01"), "")
	var xy := " --x minutos_enfriado --y dureza_hrc"
	run(["plot temple" + xy])
	run(["hipotesis no", "regress create r1 --lr 0.001", "regress train r1 temple" + xy + " --epochs 100", "answer 435.8"])
	run(["hipotesis diverge", "regress create r2 --lr 0.03", "regress train r2 temple" + xy + " --epochs 100"])
	assert_true(game.shell.events_named("regress.trained")[-1]["data"]["diverged"])
	run(["regress create r3 --lr 0.02", "regress train r3 temple" + xy + " --epochs 500"])
	assert_eq(game.runner.index, 5, "lr 0.02 en 500 épocas cumple el reto")
	run(["hipotesis menos de 10", "dataset normalize temple --method zscore --only minutos_enfriado --as tz",
		"regress create r4 --lr 0.5", "regress train r4 tz" + xy + " --epochs 20", REFLEXION_LARGA])
	assert_eq(game.runner.phase, "trial")
	run(["regress info r4", "dataset stats temple", "answer 1.51"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_T3_01_diagnostico_de_lr_lento() -> void:
	game.progress.data["missions"]["T2-01"] = {"completed": true}
	game.start_mission("T3-01")
	var xy := " --x minutos_enfriado --y dureza_hrc"
	run(["plot temple" + xy, "hipotesis no", "regress create r1 --lr 0.001", "regress train r1 temple" + xy + " --epochs 100", "answer 435.8",
		"hipotesis diverge", "regress create r2 --lr 0.03", "regress train r2 temple" + xy])
	run(["regress create r3 --lr 0.005", "regress train r3 temple" + xy + " --epochs 500"])
	assert_eq(game.runner.index, 4, "lr 0.005 no llega en 500 épocas")
	assert_true(mentor_said("Converge, pero no llega"))


func test_mision_T3_02_completa() -> void:
	game.progress.data["missions"]["T2-01"] = {"completed": true}
	assert_eq(game.start_mission("T3-02"), "")
	run(["dataset split katanas --test 0.3 --seed 42", "dataset normalize katanas_train --as tr",
		"dataset normalize katanas_test --fit katanas_train --as te", "model create m --k 9", "model train m tr"])
	run(["metrics m te --positive defectuosa", "answer 4"])
	run(["hipotesis sube recall y baja precision", "metrics m te --positive defectuosa --threshold 0.3"])
	run(["metrics curve m te --positive defectuosa", "answer 0.222", "answer 27"])
	run(["reflexion la accuracy trata igual los dos errores pero vender una katana defectuosa es mucho peor que desechar una buena por eso miro el recall de la clase defectuosa y elijo un umbral bajo aunque baje la precision y aumenten los descartes"])
	assert_eq(game.runner.phase, "trial")
	run(["model create m15 --k 15", "model train m15 tr", "metrics curve m15 te --positive defectuosa", "answer 0.531"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


# ── Pistas y maestría ────────────────────────────────────────────────────────

func test_escalera_de_pistas_y_confirmacion_nivel_5() -> void:
	game.progress.data["missions"]["T1-02"] = {"completed": true}
	game.start_mission("T2-01")
	run(["dataset normalize katanas --method minmax", "model create m1 --k 1", "model train m1 katanas_minmax", "hipotesis 100%", "model evaluate m1 katanas_minmax", "model predict m1 katanas_minmax hoja-001", "answer 0"])
	for i in 4:
		assert_true(game.runner.request_hint(false)["ok"])
	var r5 := game.runner.request_hint(false)
	assert_false(r5["ok"], "el nivel 5 exige confirmación")
	assert_true(game.runner.request_hint(true)["ok"])
	assert_eq(game.runner.result()["max_hint_main"], 5)
	assert_eq(game.runner.result()["score"], 40)


func test_prueba_de_dominio_limita_pistas() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "dataset stats katanas", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer 119", "reflexion una feature es lo que se mide y la etiqueta es la calidad de cada hoja"])
	assert_eq(game.runner.phase, "trial")
	assert_true(game.runner.request_hint(false)["ok"])
	assert_true(game.runner.request_hint(false)["ok"])
	assert_false(game.runner.request_hint(false)["ok"], "en la prueba, máximo nivel 2")


func test_respuesta_incorrecta_da_feedback() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "dataset stats katanas", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer 13.6"])
	assert_true(mentor_said("máximo menos mínimo"))
	assert_eq(game.runner.index, 4)


func test_repetir_mision_da_menos_xp() -> void:
	var full := ["dataset list", "dataset inspect katanas", "dataset stats katanas", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer 119", "reflexion una feature es lo que se mide y la etiqueta es la calidad de cada hoja", "answer 51.7"]
	game.start_mission("T1-01")
	run(full)
	game.start_mission("T1-01")
	run(full)
	assert_eq(finished.size(), 2)
	assert_eq(finished[1]["xp"], int(round(finished[0]["xp"] * Progress.REPLAY_XP_FACTOR)))


# ── Guardado ─────────────────────────────────────────────────────────────────

func test_guardado_atomico_y_recuperacion_de_backup() -> void:
	var path := "user://test_save.json"
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	assert_eq(SaveStore.save(path, {"xp": 10}), OK)
	assert_eq(SaveStore.save(path, {"xp": 20}), OK)
	assert_eq(SaveStore.read(path)["data"]["xp"], 20)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ corrupto")
	f.close()
	var loaded := SaveStore.read(path)
	assert_eq(loaded["source"], "backup")
	assert_eq(loaded["data"]["xp"], 10)
	for p in [path, path + ".bak"]:
		DirAccess.remove_absolute(p)


func test_progreso_persiste_entre_sesiones() -> void:
	var path := "user://test_progress.json"
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var g1 := DojoGame.new(path)
	g1.start_mission("T1-01")
	for l in ["dataset list", "dataset inspect katanas", "dataset stats katanas", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer 119", "reflexion una feature es lo que se mide y la etiqueta es la calidad de cada hoja", "answer 51.7"]:
		g1.shell.execute(l)
	var g2 := DojoGame.new(path)
	assert_true(g2.progress.is_mission_completed("T1-01"))
	assert_true(g2.progress.xp() > 0)
	assert_eq(g2.mission_status("T1-02"), "disponible")
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
