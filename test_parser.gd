extends Node



@export var code_editor: CodeEdit
@export var label: Label
@export var label2: Label



func _on_button_pressed() -> void:
	var parser := QParser.new()
	parser.parse(code_editor.text)
	var line_num: int = 1
	var separated_lines := str(parser.root).split("\n")
	label.text = ""
	for line in separated_lines:
		label.text += str(str(line_num).pad_zeros(2), ": ", line, "\n")
		line_num += 1
	label2.text = parser.error_msg
