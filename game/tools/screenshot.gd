extends SceneTree
## Captura de pantalla del hub tras ejecutar unos comandos (herramienta de desarrollo).
## Uso: godot --path game -s res://tools/screenshot.gd -- <salida.png> "comando 1" "comando 2" ...
## Usa un guardado temporal para no tocar el progreso real.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "user://screenshot.png"
	var dojo: Node = root.get_node("Dojo")
	dojo.game = DojoGame.new("user://screenshot_save.json")
	# unlock_all: marca como completadas todas las misiones para poder capturar cualquiera.
	for m in dojo.game.catalog.missions:
		dojo.game.progress.data["missions"][m["id"]] = {"completed": true}
	change_scene_to_file("res://ui/hub/hub_screen.tscn")
	for i in 10:
		await process_frame
	var hub := current_scene
	var term: TerminalView = hub.get("_terminal")
	for line in args.slice(1):
		term.run_command(line)
		await process_frame
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("captura: ", out)
	for p in ["user://screenshot_save.json", "user://screenshot_save.json.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	quit(0)
