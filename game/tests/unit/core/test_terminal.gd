extends TestCase
## Tests del terminal: lexer, firmas, resolución de comandos, ayuda y flujo ML completo.

var shell: Shell


func before_each() -> void:
	shell = Shell.new(ContentLibrary.load_default())
	var err := shell.world.load_dataset("katanas.csv", "katanas", "calidad")
	assert_eq(err, "", "carga del dataset")


# ── Lexer ────────────────────────────────────────────────────────────────────

func test_lexer_palabras_comillas_y_pregunta() -> void:
	var r := Lexer.tokenize("explain \"fuga de datos\" ?")
	assert_eq(r["error"], "")
	var t: Array = r["tokens"]
	assert_eq(t.size(), 3)
	assert_eq(t[1]["type"], Lexer.STRING)
	assert_eq(t[1]["value"], "fuga de datos")
	assert_eq(t[2]["type"], Lexer.QUESTION)


func test_lexer_comillas_sin_cerrar() -> void:
	assert_ne(Lexer.tokenize("explain \"hola")["error"], "")


func test_lexer_pipe() -> void:
	var t: Array = Lexer.tokenize("a|b")["tokens"]
	assert_eq(t.size(), 3)
	assert_eq(t[1]["type"], Lexer.PIPE)


# ── Firma y binding ──────────────────────────────────────────────────────────

func _toks(line: String) -> Array[Dictionary]:
	return Lexer.tokenize(line)["tokens"]


func test_binding_opciones_con_espacio_y_con_igual() -> void:
	var sig := CommandSignature.new().pos("x", "x").opt("k", "k", "int", 3)
	var a := sig.bind(_toks("hola --k 5"), null)
	assert_true(a["ok"], a["error"])
	assert_eq(a["args"]["k"], 5)
	assert_eq(sig.bind(_toks("hola --k=7"), null)["args"]["k"], 7)
	assert_eq(sig.bind(_toks("hola"), null)["args"]["k"], 3, "valor por defecto")


func test_binding_errores_claros() -> void:
	var sig := CommandSignature.new().pos("x", "x").opt("k", "k", "int", 3)
	assert_true(sig.bind(_toks("hola --k cinco"), null)["error"].contains("entero"))
	assert_true(sig.bind(_toks("hola --z 1"), null)["error"].contains("opción desconocida"))
	assert_true(sig.bind(_toks(""), null)["error"].contains("falta el argumento"))
	assert_true(sig.bind(_toks("a b"), null)["error"].contains("sobran"))


func test_binding_valida_nombres_de_dataset_con_sugerencia() -> void:
	var r := shell.execute("dataset inspect katana")
	assert_false(r.ok)
	assert_true(r.plain_text().contains("¿Quisiste decir 'katanas'?"), r.plain_text())


# ── Shell ────────────────────────────────────────────────────────────────────

func test_comando_desconocido_sugiere() -> void:
	var r := shell.execute("datset list")
	assert_false(r.ok)
	assert_true(r.plain_text().contains("dataset"))


func test_raiz_sin_subcomando_lista_opciones() -> void:
	var r := shell.execute("model")
	assert_false(r.ok)
	assert_true(r.plain_text().contains("model create"))


func test_help_general_y_de_comando() -> void:
	# El panorama de «help» es corto: imprescindibles + familias (no cada subcomando).
	var ov := shell.execute("help").plain_text()
	assert_true(ov.contains("Imprescindibles"), ov)
	assert_true(ov.contains("dataset"), "la familia dataset aparece en el panorama")
	assert_false(ov.contains("dataset inspect"), "ya no vuelca cada subcomando")
	# La ayuda de un comando concreto no cambia:
	var h := shell.execute("help dataset normalize").plain_text()
	assert_true(h.contains("--method"), h)
	assert_true(shell.execute("model create --help").plain_text().contains("Uso: model create"))


func test_man_explain_y_cheatsheet() -> void:
	assert_true(shell.execute("man knn").plain_text().contains("VECINOS"))
	assert_true(shell.execute("explain fuga de datos").plain_text().contains("leakage") or shell.execute("explain fuga de datos").ok)
	assert_true(shell.execute("explain sobreajuste").plain_text().contains("overfitting"), "alias en castellano")
	assert_false(shell.execute("explain xyzzy").ok)
	assert_true(shell.execute("cheatsheet").plain_text().contains("CHULETA"))


func test_pregunta_contextual_no_ejecuta() -> void:
	var r := shell.execute("model train ?")
	assert_true(r.plain_text().contains("katanas"), "debe listar datasets disponibles")
	assert_eq(shell.events_named("model.trained").size(), 0)


func test_pipes_bloqueados_en_nivel_1() -> void:
	assert_false(shell.execute("dataset list | dataset list").ok)


func test_autocompletado() -> void:
	assert_has(shell.complete("data"), "dataset")
	assert_has(shell.complete("dataset ins"), "inspect")
	assert_has(shell.complete("dataset inspect ka"), "katanas")
	assert_has(shell.complete("model create m1 --"), "--k")


func test_historial() -> void:
	shell.execute("dataset list")
	shell.execute("help")
	assert_eq(shell.history.size(), 2)
	assert_true(shell.execute("history").plain_text().contains("dataset list"))


# ── Flujo completo de las misiones v0.1 ──────────────────────────────────────

func test_flujo_ml_completo_y_eventos() -> void:
	assert_true(shell.execute("dataset stats katanas").ok)
	assert_true(shell.execute("distance katanas hoja-001 hoja-002").ok)
	var dist: Dictionary = shell.events_named("distance.computed")[0]["data"]
	assert_eq(dist["dominant_feature"], "temperatura_temple", "sin normalizar domina la temperatura (por diseño del dataset)")

	assert_true(shell.execute("dataset split katanas --test 0.3 --seed 42").ok)
	assert_true(shell.execute("dataset normalize katanas_train --method minmax --as tr").ok)
	assert_true(shell.execute("dataset normalize katanas_test --fit katanas_train --as te").ok)
	var norm: Dictionary = shell.events_named("dataset.normalized")[1]["data"]
	assert_eq(norm["fit_on"], "katanas_train")
	assert_eq(norm["fit_overlap_with_source"], 0)

	assert_true(shell.execute("model create m --k 9").ok)
	assert_true(shell.execute("model train m tr").ok)
	var ev := shell.execute("model evaluate m te")
	assert_true(ev.ok, ev.plain_text())
	var e: Dictionary = shell.events_named("model.evaluated")[0]["data"]
	assert_eq(e["overlap"], 0)
	assert_true(e["accuracy"] > 0.8, "con minmax y k=9 la accuracy de test debe superar 0.8 (fue %s)" % e["accuracy"])


func test_evaluar_con_entrenamiento_marca_fuga() -> void:
	shell.execute("model create m --k 1")
	shell.execute("model train m katanas")
	var r := shell.execute("model evaluate m katanas")
	assert_true(r.plain_text().contains("también estaban en el entrenamiento"))
	var e: Dictionary = shell.events_named("model.evaluated")[0]["data"]
	assert_eq(e["overlap"], 240)
	assert_almost_eq(e["accuracy"], 1.0, 1e-9, "k=1 sobre su propio entrenamiento: memoriza todo")


func test_predecir_sin_entrenar_falla_con_explicacion() -> void:
	shell.execute("model create m")
	var r := shell.execute("model predict m katanas hoja-001")
	assert_false(r.ok)
	assert_true(r.plain_text().contains("model train"))


func test_sweep_muestra_overfitting() -> void:
	shell.execute("dataset split katanas --test 0.3 --seed 42")
	shell.execute("dataset normalize katanas_train --as tr")
	shell.execute("dataset normalize katanas_test --fit katanas_train --as te")
	assert_true(shell.execute("model sweep --train tr --test te --k 1,9").ok)
	var res: Array = shell.events_named("model.swept")[0]["data"]["results"]
	assert_almost_eq(res[0]["train"], 1.0, 1e-9, "k=1 → 100 % en train")
	assert_true(res[0]["test"] < res[1]["test"], "k=9 generaliza mejor que k=1")


func test_comandos_no_dejan_eventos_si_fallan_al_validar() -> void:
	shell.execute("model train noexiste katanas")
	assert_eq(shell.events_named("model.trained").size(), 0)
	assert_eq(shell.events_named("command.failed").size(), 1)


func test_forja_setup_explica_instalacion_por_sistema() -> void:
	assert_true(shell.execute("forja setup").plain_text().contains("winget install"))
	assert_true(shell.execute("forja setup --os macos").plain_text().contains("brew install python"))
	assert_true(shell.execute("forja setup --os linux").plain_text().contains("apt install python3"))
	assert_true(shell.execute("man python").ok)


func test_contenido_sin_errores() -> void:
	var lib := ContentLibrary.load_default()
	assert_eq(lib.errors.size(), 0, ", ".join(lib.errors))
	assert_true(lib.terms.size() >= 15)
	assert_true(lib.topics.has("knn"))
