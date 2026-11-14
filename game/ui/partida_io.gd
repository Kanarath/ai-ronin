class_name PartidaIO
extends RefCounted
## Diálogos de archivo nativos para exportar/importar la partida desde la interfaz (botones del
## menú). La lógica de leer y escribir vive en DojoGame (export_partida/import_partida): aquí solo
## está el selector de archivos del sistema y el aviso con el resultado. Así los botones y el
## comando `partida` comparten exactamente el mismo comportamiento.

const FILTRO := ["*.json ; Partida de AI RONIN"]


## Abre el selector para GUARDAR y exporta la partida al archivo elegido.
static func exportar(host: Node, game: DojoGame) -> void:
	var fd := _dialogo(host, FileDialog.FILE_MODE_SAVE_FILE, "Exportar partida")
	fd.current_file = "ai-ronin.json"
	fd.file_selected.connect(func(path: String) -> void:
		var res := game.export_partida(path)
		_aviso(host, "✓ Partida exportada en:\n%s\n\nCópiala a tu otro ordenador e impórtala allí." % path if res["ok"] else res["error"])
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered(Vector2i(900, 600))


## Abre el selector para ABRIR e importa la partida del archivo elegido (reemplaza el progreso).
## Si va bien, llama a `al_terminar` para que la interfaz se refresque.
static func importar(host: Node, game: DojoGame, al_terminar: Callable = Callable()) -> void:
	var fd := _dialogo(host, FileDialog.FILE_MODE_OPEN_FILE, "Importar partida")
	fd.file_selected.connect(func(path: String) -> void:
		var res := game.import_partida(path)
		_aviso(host, "✓ Partida importada. Tu progreso es ahora el de ese archivo." if res["ok"] else res["error"])
		if res["ok"] and al_terminar.is_valid():
			al_terminar.call()
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered(Vector2i(900, 600))


static func _dialogo(host: Node, mode: FileDialog.FileMode, titulo: String) -> FileDialog:
	var fd := FileDialog.new()
	fd.title = titulo
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.file_mode = mode
	fd.filters = PackedStringArray(FILTRO)
	host.add_child(fd)
	return fd


static func _aviso(host: Node, text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "AI RONIN · partida"
	dlg.dialog_text = text
	host.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()
