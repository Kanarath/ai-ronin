extends SceneTree
## Ejecuta comandos del terminal del Dojo en modo texto (herramienta de desarrollo).
## Uso: godot --headless --path game -s res://tools/terminal_demo.gd -- "help" "dataset stats katanas"

const STYLE_PREFIX := {"error": "✗ ", "warn": "! ", "ok": "", "accent": "", "muted": "  ", "data": "", "normal": ""}


func _initialize() -> void:
	var shell := Shell.new(ContentLibrary.load_default())
	shell.world.load_dataset("katanas.csv", "katanas", "calidad")
	for line in OS.get_cmdline_user_args():
		print("ronin@dojo:~$ " + line)
		var r := shell.execute(line)
		for l in r.lines:
			print(STYLE_PREFIX.get(l["style"], "") + l["text"])
		print("")
	quit(0)
