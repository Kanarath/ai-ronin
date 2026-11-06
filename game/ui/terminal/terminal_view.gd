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

var shell: Shell
var _output: RichTextLabel
var _input: LineEdit
var _history_index: int = -1


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
	box.add_child(_output)

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
			focus_input())


func focus_input() -> void:
	if _input != null:
		_input.grab_focus()


## Ejecuta una línea como si la hubiera escrito el usuario (la usan los botones del mentor).
func run_command(line: String) -> CommandResult:
	_print_raw("[color=%s]%s[/color] %s" % [RoninPalette.TEAL.to_html(false), PROMPT, _escape(line)])
	var result := shell.execute(line)
	if result.action == "clear":
		_output.clear()
	for l in result.lines:
		print_line(l["text"], l["style"])
	_history_index = -1
	command_executed.emit(line, result)
	return result


func print_line(text: String, style: String = "normal") -> void:
	var color: Color = STYLE_COLORS.get(style, RoninPalette.TEXT)
	var body := _escape(text)
	if style == "accent":
		body = "[b]%s[/b]" % body
	_print_raw("[color=%s]%s[/color]" % [color.to_html(false), body])


func _print_raw(bbcode: String) -> void:
	_output.append_text(bbcode + "\n")


func _on_submitted(text: String) -> void:
	_input.clear()
	if text.strip_edges().is_empty():
		return
	run_command(text)


func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
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
	return text.replace("[", "[lb]")
