extends Control
## Pantalla principal (provisional en la Fase 0).
## En la Fase 1 se convertirá en el hub con currículo, laboratorio, mentor y terminal.

# El prefijo % accede a nodos marcados como «nombre único» en la escena
# (unique_name_in_owner). Así el script no depende de la ruta exacta del nodo.
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle


func _ready() -> void:
	_title.add_theme_color_override("font_color", RoninPalette.TEAL)
	_subtitle.add_theme_color_override("font_color", RoninPalette.MUTED)
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	_subtitle.text = "v%s · Fase 0 · Cimientos" % version
