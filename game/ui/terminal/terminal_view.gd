class_name TerminalView
extends PanelContainer
## Vista del terminal: salida con colores, entrada con historial (↑↓) y autocompletado (Tab).

signal command_executed(line: String, result: CommandResult)

const PROMPT := "ronin@dojo:~$"
const STYLE_COLORS := {
	"normal": RoninPalette.TEXT,
	"ok": RoninPalette.TEAL,
	"error": RoninPalette.RED,
	"warn": RoninPalette.GOLD,
	"muted": RoninPalette.MUTED,
	"accent": RoninPalette.CYAN,
	"data": RoninPalette.TEXT,
	"mentor": RoninPalette.GOLD,
}

const MENTOR_COLORS := {
	"info": RoninPalette.TEXT,
	"question": RoninPalette.CYAN,
	"praise": RoninPalette.TEAL,
	"warn": RoninPalette.GOLD,
	"hint": RoninPalette.VIOLET,
	"debrief": RoninPalette.TEXT,
	"lesson": RoninPalette.TEXT,
	"task": RoninPalette.CYAN,
}

var shell: Shell
var _output: RichTextLabel
var _input: LineEdit
var _history_index: int = -1
## Mientras se ejecuta un comando, lo que dice el mentor espera a que termine la salida del
## comando: así RONIN comenta el resultado DESPUÉS de que lo veas, no antes.
var _busy := false
var _pending_mentor: Array = []

## Efecto de escritura, como en las películas de hackers: RONIN teclea letra a letra (un poco
## más rápido de lo que se lee, con pausas breves tras comas y puntos) y la salida de los
## comandos va apareciendo en cascada. Enter, Esc o un clic lo muestran todo de golpe.
## «efectos lento|normal|rapido» cambia la velocidad y «efectos off» lo quita.
## Velocidades en caracteres por segundo: [RONIN, salida de comandos].
const SPEEDS := {"lento": [32.0, 450.0], "normal": [48.0, 800.0], "rapido": [110.0, 2000.0]}
var effects := true
var speed := "normal"
var _shown: int = -1
## Tiempo acumulado hacia el siguiente carácter.
var _carry: float = 0.0
## Tramos pendientes de revelar: [carácter final, "mentor" u "output"].
var _reveal: Array = []
## Texto visible (sin BBCode) para saber qué carácter toca y si merece pausa.
var _parsed: String = ""
var _rng := RandomNumberGenerator.new()


func setup(p_shell: Shell) -> void:
	shell = p_shell


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.context_menu_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", RoninFonts.mono())
	_output.add_theme_font_override("bold_font", RoninFonts.mono())
	_output.add_theme_font_size_override("normal_font_size", 14)
	_output.add_theme_font_size_override("bold_font_size", 14)
	# Hueco encima de la salida para que su alto sea un número entero de líneas: así la línea
	# de arriba no queda cortada por la mitad (y no pierde las tildes).
	_top_pad = Control.new()
	_top_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_top_pad)
	box.add_child(_output)
	_output.resized.connect(_align_lines)

	var row := HBoxContainer.new()
	box.add_child(row)
	var prompt := Label.new()
	prompt.text = PROMPT
	prompt.add_theme_color_override("font_color", RoninPalette.TEAL)
	prompt.add_theme_font_override("font", RoninFonts.mono())
	prompt.add_theme_font_size_override("font_size", 14)
	row.add_child(prompt)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.placeholder_text = "escribe un comando · help · Tab autocompleta · ↑↓ historial"
	_input.add_theme_font_override("font", RoninFonts.mono())
	_input.add_theme_font_size_override("font_size", 14)
	_input.caret_blink = true
	_input.keep_editing_on_text_submit = true
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_gui)
	row.add_child(_input)

	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			finish_reveal()
			focus_input())
	_output.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			finish_reveal())


var _top_pad: Control
var _aligning := false


## Ajusta el hueco superior para que la salida mida un número entero de líneas.
func _align_lines() -> void:
	if _aligning or _output == null:
		return
	var font := _output.get_theme_font("normal_font")
	var lh := font.get_height(14) + _output.get_theme_constant("line_separation")
	if lh <= 0.0:
		return
	var total := _output.size.y + _top_pad.custom_minimum_size.y
	var pad := fmod(total, lh)
	if absf(pad - _top_pad.custom_minimum_size.y) < 0.5:
		return
	_aligning = true
	_top_pad.custom_minimum_size.y = pad
	_aligning = false


func _process(delta: float) -> void:
	if _reveal.is_empty():
		return
	_carry += minf(delta, 0.1)
	var speeds: Array = SPEEDS.get(speed, SPEEDS["normal"])
	while not _reveal.is_empty():
		var end: int = _reveal[0][0]
		if _shown >= end:
			_reveal.pop_front()
			continue
		var cost := _char_cost(_reveal[0][1], speeds)
		if _carry < cost:
			break
		_carry -= cost
		_shown += 1
	if _reveal.is_empty():
		finish_reveal()
	else:
		_output.visible_characters = _shown


## Lo que cuesta mostrar el siguiente carácter. RONIN teclea con un ritmo algo irregular y
## se para un instante tras la puntuación; la salida de los comandos fluye en cascada.
func _char_cost(kind: String, speeds: Array) -> float:
	var ch := _parsed[_shown] if _shown < _parsed.length() else ""
	if kind == "mentor":
		var c: float = (1.0 / speeds[0]) * _rng.randf_range(0.6, 1.4)
		if ch == "," or ch == ";" or ch == ":":
			c += 0.08
		elif ch == "." or ch == "?" or ch == "!" or ch == "…":
			c += 0.16
		elif ch == "\n":
			c += 0.12
		return c
	var o: float = 1.0 / speeds[1]
	if ch == "\n":
		o += 0.012
	return o


## Enseña de golpe todo lo que estaba apareciendo.
func finish_reveal() -> void:
	_reveal.clear()
	_shown = -1
	_carry = 0.0
	if _output != null:
		_output.visible_characters = -1


func is_revealing() -> bool:
	return not _reveal.is_empty()


func focus_input() -> void:
	if _input != null:
		_input.grab_focus()


## Ejecuta una línea como si la hubiera escrito el usuario (la usan los botones de la interfaz).
func run_command(line: String) -> CommandResult:
	finish_reveal()
	_print_raw("[color=%s]%s[/color] %s" % [RoninPalette.TEAL.to_html(false), PROMPT, _escape(line)], "instant")
	_busy = true
	var result := shell.execute(line)
	if result.action == "clear":
		_output.clear()
		finish_reveal()
	elif result.action == "effects_on":
		effects = true
	elif result.action.begins_with("effects_speed_"):
		effects = true
		speed = result.action.trim_prefix("effects_speed_")
	elif result.action == "effects_off":
		effects = false
		finish_reveal()
	for l in result.lines:
		print_line(l["text"], l["style"])
	_busy = false
	for m: Array in _pending_mentor:
		print_mentor(m[0], m[1])
	_pending_mentor.clear()
	_history_index = -1
	command_executed.emit(line, result)
	return result


## Mensaje de RONIN dentro de la consola. Las lecciones llevan título y una barra a la
## izquierda; «task» es lo que te toca hacer ahora; el resto, una línea con «RONIN ›».
func print_mentor(text: String, kind: String = "info") -> void:
	if _busy:
		_pending_mentor.append([text, kind])
		return
	var col: Color = MENTOR_COLORS.get(kind, RoninPalette.TEXT)
	var bar := "[color=%s]┃[/color] " % RoninPalette.CYAN.to_html(false)
	if kind == "lesson":
		var parts := text.split("\n")
		_print_raw("", "mentor")
		_print_raw("%s[color=%s][b]◇ %s[/b][/color]" % [bar, RoninPalette.CYAN.to_html(false), _escape(parts[0])], "mentor")
		for p in parts.slice(1):
			_print_raw("%s[color=%s]%s[/color]" % [bar, col.to_html(false), _escape(p)], "mentor")
		return
	if kind == "task":
		_print_raw("[color=%s][b]▶ %s[/b][/color]" % [col.to_html(false), _escape(text).replace("\n", "\n   ")], "mentor")
		_print_raw("", "mentor")
		return
	var who := "[color=%s]RONIN ›[/color] " % RoninPalette.GOLD.to_html(false)
	var prefix := "◆ " if kind == "debrief" else ""
	_print_raw("%s[color=%s]%s%s[/color]" % [who, col.to_html(false), prefix, _escape(text).replace("\n", "\n        ")], "mentor")


func print_line(text: String, style: String = "normal") -> void:
	var color: Color = STYLE_COLORS.get(style, RoninPalette.TEXT)
	var body := _escape(text)
	if style == "accent":
		body = "[b]%s[/b]" % body
	_print_raw("[color=%s]%s[/color]" % [color.to_html(false), body])


## kind: "mentor" (RONIN teclea), "output" (salida en cascada) o "instant" (de golpe, como
## lo que escribes tú; si aún hay texto apareciendo, se suma a la cascada).
func _print_raw(bbcode: String, kind: String = "output") -> void:
	var before := _output.get_total_character_count()
	_output.append_text(bbcode + "\n")
	if not effects or not is_inside_tree():
		return
	if kind == "instant":
		if _reveal.is_empty():
			return
		kind = "output"
	if _reveal.is_empty():
		_shown = before
		_carry = 0.0
		_output.visible_characters = before
	_parsed = _output.get_parsed_text()
	_reveal.append([_output.get_total_character_count(), kind])


func _on_submitted(text: String) -> void:
	_input.clear()
	if text.strip_edges().is_empty():
		return
	run_command(text)


func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_ESCAPE:
			finish_reveal()
			_input.accept_event()
		KEY_TAB:
			_complete()
			_input.accept_event()
		KEY_UP:
			_navigate_history(-1)
			_input.accept_event()
		KEY_DOWN:
			_navigate_history(1)
			_input.accept_event()


func _complete() -> void:
	var line := _input.text
	var candidates := shell.complete(line)
	if candidates.is_empty():
		return
	var words := line.split(" ")
	if candidates.size() == 1:
		words[words.size() - 1] = candidates[0]
		_input.text = " ".join(words) + " "
	else:
		var common := _common_prefix(candidates)
		if common.length() > words[-1].length():
			words[words.size() - 1] = common
			_input.text = " ".join(words)
		else:
			print_line("  " + "   ".join(candidates), "muted")
	_input.caret_column = _input.text.length()


func _navigate_history(direction: int) -> void:
	var h := shell.history
	if h.is_empty():
		return
	if _history_index == -1:
		_history_index = h.size()
	_history_index = clampi(_history_index + direction, 0, h.size())
	_input.text = h[_history_index] if _history_index < h.size() else ""
	_input.caret_column = _input.text.length()


static func _common_prefix(items: PackedStringArray) -> String:
	var prefix := items[0]
	for s in items:
		while not s.begins_with(prefix):
			prefix = prefix.substr(0, prefix.length() - 1)
	return prefix


static func _escape(text: String) -> String:
	return display_text(text).replace("[", "[lb]")


const _SUPERSCRIPTS := {"⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9", "⁻": "-", "⁺": "+"}


## Ajustes de presentación para la fuente de la consola:
##   - «60 %» lleva un espacio que no se parte: el «%» nunca queda solo en la línea siguiente.
##   - Los superíndices que la fuente monoespaciada no tiene (⁰, ⁴…⁹, ⁻) se dibujaban con
##     otra fuente y parecían «°»: «10⁻²⁰⁰» se escribe 10^-200. ¹ ² ³ sí están y se dejan.
static func display_text(text: String) -> String:
	var out := text.replace(" %", " %")
	if not RegEx.create_from_string("[⁰⁴-⁹⁻⁺]").search(out):
		return out
	var res := ""
	var run := ""
	for ch in out + " ":
		if _SUPERSCRIPTS.has(ch):
			run += ch
			continue
		if not run.is_empty():
			if RegEx.create_from_string("[⁰⁴-⁹⁻⁺]").search(run):
				res += "^"
				for r in run:
					res += _SUPERSCRIPTS[r]
			else:
				res += run
			run = ""
		res += ch
	return res.substr(0, res.length() - 1)
