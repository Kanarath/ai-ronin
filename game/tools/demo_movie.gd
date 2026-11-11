extends SceneTree
## Graba una demo del hub con el efecto de escritura (herramienta de desarrollo).
## Uso: godot --path game --write-movie demo.avi --fixed-fps 30 -s res://tools/demo_movie.gd -- [velocidad] "cmd" "@3" "cmd"...
## «@N» espera N segundos. Usa un guardado temporal para no tocar el progreso real.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var speed := args[0] if not args.is_empty() else "normal"
	var dojo: Node = root.get_node("Dojo")
	dojo.game = DojoGame.new("user://demo_save.json")
	change_scene_to_file("res://ui/hub/hub_screen.tscn")
	for i in 5:
		await process_frame
	var term: TerminalView = current_scene.get("_terminal")
	term.effects = true
	term.speed = speed
	for line in args.slice(1):
		if line.begins_with("@"):
			await create_timer(float(line.substr(1))).timeout
		else:
			term.run_command(line)
	await create_timer(1.0).timeout
	for p in ["user://demo_save.json", "user://demo_save.json.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	quit()
