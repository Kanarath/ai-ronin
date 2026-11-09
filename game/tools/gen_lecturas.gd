extends SceneTree
## Genera LECTURAS.md (raíz del repositorio) a partir de missions/, study_path.json y
## references.json, en el orden del temario. Herramienta de desarrollo: el Dojo no la usa.
## Uso (desde la raíz): godot --headless --path game -s res://tools/gen_lecturas.gd

const OUT := "res://../LECTURAS.md"


func _initialize() -> void:
	var catalog := MissionCatalog.load_default()
	var study := StudyPath.load_default()
	var md := PackedStringArray()
	md.append("# Lecturas de AI RONIN")
	md.append("")
	md.append("Generado con `game/tools/gen_lecturas.gd`; no lo edites a mano. Las mismas lecturas están en el Dojo con el comando `lecturas`.")
	md.append("")
	md.append("Las unidades marcadas como **estudio externo** forman parte del temario pero no tienen misión en el Dojo: se estudian con estas referencias, a tu ritmo, en el punto indicado. Cuando las hayas estudiado, márcalas en el Dojo con `lecturas hecho <unidad>`; algunas desbloquean otras.")
	md.append("")
	var units: Array[String] = []
	for m: Dictionary in catalog.missions:
		if not m["unit"] in units:
			units.append(m["unit"])
	for unit: String in units:
		md.append("## " + unit)
		md.append("")
		for m: Dictionary in catalog.missions:
			if m["unit"] != unit or m.get("further_reading", []).is_empty():
				continue
			md.append("**%s · %s**" % [m["id"], m["title"]])
			md.append("")
			for id: String in m["further_reading"]:
				md.append(_ref(study, id))
			md.append("")
		_studies(md, study, catalog, unit)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(md).strip_edges() + "\n")
	f.close()
	print("LECTURAS.md generado")
	quit(0)


func _studies(md: PackedStringArray, study: StudyPath, catalog: MissionCatalog, anchor: String) -> void:
	for u: Dictionary in study.units:
		if study.anchor_of(u, catalog) != anchor:
			continue
		md.append("### 📖 %s · estudio externo" % u["title"])
		md.append("")
		md.append("- **Temario:** " + String(u["temario"]))
		var after := PackedStringArray(u["unlock"]["missions"]) + PackedStringArray(u["unlock"]["studies"])
		md.append("- **Se estudia después de:** " + ", ".join(after))
		if not u["recommended_before"].is_empty():
			md.append("- **Recomendada antes de:** " + ", ".join(PackedStringArray(u["recommended_before"])))
		md.append("- **Referencias:**")
		for id: String in u["refs"]:
			md.append("  " + _ref(study, id))
		md.append("")
		_studies(md, study, catalog, u["id"])


func _ref(study: StudyPath, id: String) -> String:
	var r: Dictionary = study.refs.get(id, {})
	if r.is_empty():
		return "- (falta la referencia %s)" % id
	var who: String = r.get("source", r.get("authors", ""))
	if not r.has("url"):
		return "- %s — %s (sin enlace en línea)" % [r["title"], who]
	return "- [%s](%s) — %s · consultada %s" % [r["title"], r["url"], who, r.get("consulted", "?")]
