extends SceneTree
## Genera los datasets sintéticos de las misiones (determinista, semilla fija).
## Uso: godot --headless --path game -s res://tools/generate_datasets.gd
##
## «Forja de katanas»: dureza (HRC), flexibilidad (0-10) y temperatura de temple (°C).
## Diseño pedagógico INTENCIONADO:
##   - La calidad depende de dureza y flexibilidad.
##   - La temperatura NO aporta información, pero su escala (~120 °C de rango)
##     domina la distancia euclídea si no se normaliza → k-NN sin normalizar falla.
##   - «defectuosa» tiene dos subgrupos (quebradiza y blanda): no es separable con una
##     sola línea recta, pero k-NN lo resuelve bien.
##   - ~8 % de etiquetas erróneas (ruido de inspección): k=1 las memoriza → overfitting.

const OUT_DIR := "res://content/datasets"
const SEED := 20261106
const LABEL_NOISE := 0.08
const ROWS := 240


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var lines := PackedStringArray(["id,dureza_hrc,flexibilidad,temperatura_temple,calidad"])
	var n := 0
	for i in ROWS:
		var kind := i % 4  # 0,1 → apta · 2 → quebradiza · 3 → blanda
		var dureza: float
		var flex: float
		var label := "defectuosa"
		match kind:
			0, 1:
				dureza = rng.randfn(60.0, 1.2)
				flex = rng.randfn(6.0, 0.8)
				label = "apta"
			2:
				dureza = rng.randfn(63.5, 1.0)
				flex = rng.randfn(3.8, 0.8)
			_:
				dureza = rng.randfn(56.5, 1.2)
				flex = rng.randfn(7.6, 0.8)
		var temp := rng.randi_range(760, 880)
		# Ruido de etiqueta (~8 %): el inspector se equivocó. Es lo que k=1 «memoriza».
		if rng.randf() < LABEL_NOISE:
			label = "apta" if label == "defectuosa" else "defectuosa"
		n += 1
		lines.append("hoja-%03d,%.1f,%.2f,%d,%s" % [n, dureza, clampf(flex, 0.0, 10.0), temp, label])
	# Barajamos el orden de las filas (manteniendo los ids) para que no haya patrón por posición.
	var body := lines.slice(1)
	for i in range(body.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := body[i]
		body[i] = body[j]
		body[j] = tmp
	var csv := lines[0] + "\n" + "\n".join(body) + "\n"
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var f := FileAccess.open(OUT_DIR.path_join("katanas.csv"), FileAccess.WRITE)
	f.store_string(csv)
	f.close()
	print("katanas.csv: %d filas" % body.size())
	_report(Dataset.from_csv_text("katanas", csv, "calidad"))
	_generate_temple()
	quit(0)


## «Temple»: relación lineal con ruido entre minutos de enfriado y dureza (T3, regresión).
## dureza ≈ 50 + 1.5·minutos + ruido(σ=1). Generador propio para no alterar katanas.csv.
## x en [0, 10] sin normalizar → problema mal condicionado: el descenso por gradiente
## diverge con lr ≥ ~0.03 y converge muy despacio en b con lr pequeños.
func _generate_temple() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var lines := PackedStringArray(["id,minutos_enfriado,dureza_hrc"])
	for i in 60:
		var x := snappedf(rng.randf_range(0.0, 10.0), 0.1)
		var y := 50.0 + 1.5 * x + rng.randfn(0.0, 1.0)
		lines.append("temple-%03d,%.1f,%.2f" % [i + 1, x, y])
	var f := FileAccess.open(OUT_DIR.path_join("temple.csv"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("temple.csv: 60 filas")


func _report(ds: Dataset) -> void:
	var split := Splitter.train_test_split(ds, 0.3, 42)
	var norm := Normalizer.new("minmax")
	norm.fit(split[0])
	var tr_n := norm.transform(split[0], "tr_n")
	var te_n := norm.transform(split[1], "te_n")
	for k in [1, 3, 5, 9, 15, 31]:
		var raw := KNNClassifier.new(k)
		raw.fit(split[0])
		var nrm := KNNClassifier.new(k)
		nrm.fit(tr_n)
		print("k=%2d  sin normalizar: train %.2f test %.2f | minmax: train %.2f test %.2f" % [
			k,
			Metrics.accuracy(split[0].labels, raw.predict(split[0])),
			Metrics.accuracy(split[1].labels, raw.predict(split[1])),
			Metrics.accuracy(tr_n.labels, nrm.predict(tr_n)),
			Metrics.accuracy(te_n.labels, nrm.predict(te_n)),
		])
