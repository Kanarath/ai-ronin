extends SceneTree
## Ejecuta comandos del terminal del Dojo en modo texto (herramienta de desarrollo).
## Uso: godot --headless --path game -s res://tools/terminal_demo.gd -- "help" "dataset stats katanas"

const STYLE_PREFIX := {"error": "✗ ", "warn": "! ", "ok": "", "accent": "", "muted": "  ", "data": "", "normal": ""}


func _initialize() -> void:
	var game := DojoGame.new("")
	var shell := game.shell
	shell.world.load_dataset("katanas.csv", "katanas", "calidad")
	shell.world.load_dataset("temple.csv", "temple", "")
	shell.world.load_dataset("mensajes.csv", "mensajes", "tipo")
	shell.world.load_dataset("peticiones.csv", "peticiones", "tipo")
	shell.world.load_dataset("llamadas.csv", "llamadas", "riesgo")
	shell.world.load_dataset("candidatos.csv", "candidatos", "decision")
	shell.world.load_dataset("prestamos.csv", "prestamos", "devuelve")
	for gate in ["and", "or", "xor", "nand"]:
		shell.world.load_dataset("puerta_%s.csv" % gate, "puerta_%s" % gate, "salida")
	for line in OS.get_cmdline_user_args():
		print("ronin@dojo:~$ " + line)
		var r := shell.execute(line)
		for l in r.lines:
			print(STYLE_PREFIX.get(l["style"], "") + l["text"])
		print("")
	quit(0)
