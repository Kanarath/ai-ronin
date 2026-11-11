extends SceneTree
## Prueba de humo de la interfaz SIN ventana (usar con --headless): carga el hub, ejecuta unos
## comandos en la consola y termina. Sirve para comprobar que los scripts de la UI compilan
## y que los comandos no rompen nada. Uso:
##   godot --headless --path game -s res://tools/hub_smoke.gd -- "cmd 1" "cmd 2" ...


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dojo: Node = root.get_node("Dojo")
	dojo.game = DojoGame.new("user://smoke_save.json")
	change_scene_to_file("res://ui/hub/hub_screen.tscn")
	for i in 5:
		await process_frame
	var hub := current_scene
	if hub == null:
		print("HUMO: FALLO · no se ha cargado el hub")
		quit(1)
		return
	var term: TerminalView = hub.get("_terminal")
	term.effects = false
	for line in args:
		var r := term.run_command(line)
		print("HUMO · %s → %s" % [line, "ok" if r.ok else "error: " + r.plain_text().left(120)])
		await process_frame
	for p in ["user://smoke_save.json", "user://smoke_save.json.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	print("HUMO: OK")
	quit()
