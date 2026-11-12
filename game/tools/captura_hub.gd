extends SceneTree
## Captura de pantalla del Dojo (necesita ventana: NO usar --headless). Abre el hub con una
## partida temporal, empieza una misión con gráfico, espera a que se dibuje, guarda un PNG y
## sale. Uso:
##   godot --path game -s res://tools/captura_hub.gd -- <ruta.png> [mision] [comandos…]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://captura_hub.png"
	var mission := args[1] if args.size() > 1 else "T2-01"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var dojo: Node = root.get_node("Dojo")
	dojo.prefs.path = ""  # no tocar las opciones reales
	dojo.prefs.data["efectos"] = false
	dojo.game = DojoGame.new("user://captura_save.json", dojo.prefs)
	change_scene_to_file("res://ui/hub/hub_screen.tscn")
	for i in 10:
		await process_frame
	var hub := current_scene
	var term: TerminalView = hub.get("_terminal")
	term.effects = false
	term.run_command("mission start " + mission)
	for i in range(2, args.size()):
		term.run_command(args[i])
	await create_timer(1.5).timeout
	# Fuera notificaciones (tapan la esquina del laboratorio en la captura)
	var toaster: Control = hub.get("_toaster")
	for c in toaster.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("CAPTURA: ", out)
	for p in ["user://captura_save.json", "user://captura_save.json.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	quit()
