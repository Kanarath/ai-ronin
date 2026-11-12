extends SceneTree
## Prueba de humo de la pantalla de título SIN ventana (usar con --headless): arranca el
## título con la intro, la salta, abre Opciones y Acerca de, cambia una opción y entra al
## Dojo con «Continuar». Usa un guardado temporal y lo borra al terminar.


func _initialize() -> void:
	var dojo: Node = root.get_node("Dojo")
	dojo.prefs.path = ""  # no tocar las opciones reales
	dojo.game = DojoGame.new("user://smoke_title.json", dojo.prefs)
	dojo.intro_played = false
	change_scene_to_file("res://ui/title/title_screen.tscn")
	for i in 5:
		await process_frame
	var title := current_scene
	var ok := title != null and title.name == "TitleScreen"
	var intro: Node = null
	for c in title.get_children():
		if c is IntroOverlay:
			intro = c
	print("HUMO · intro en marcha: %s" % (intro != null))
	ok = ok and intro != null
	for i in 20:
		await process_frame
	intro.skip()
	await create_timer(0.6).timeout
	print("HUMO · intro saltada: %s" % (not is_instance_valid(intro)))
	ok = ok and not is_instance_valid(intro)
	title.call("_show_options")
	await process_frame
	title.call("_save_setting", "volumen", 55)
	print("HUMO · opciones: volumen %s" % dojo.prefs.data.get("volumen"))
	ok = ok and int(dojo.prefs.data["volumen"]) == 55
	title.call("_close_dialog")
	title.call("_show_about")
	await process_frame
	title.call("_close_dialog")
	await process_frame
	title.call("_show_slots")
	await process_frame
	print("HUMO · partidas: %d ranuras" % SaveSlots.COUNT)
	title.call("_go_to_hub")
	await create_timer(0.8).timeout
	print("HUMO · escena tras Continuar: %s" % current_scene.name)
	ok = ok and current_scene.name == "HubScreen"
	for p in ["user://smoke_title.json", "user://smoke_title.json.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	print("HUMO: " + ("OK" if ok else "FALLO"))
	quit(0 if ok else 1)
