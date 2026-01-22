extends Node



@export var code_editor: CodeEdit
@export var label: Label
@export var label2: Label



func _on_button_pressed() -> void:
	var ast := NewNewAST.new()
	ast.parse(code_editor.text)
	var line_num: int = 1
	var sss := str(ast.root).split("\n")
	label.text = ""
	for line in sss:
		label.text += str(str(line_num).pad_zeros(2), ": ", line, "\n")
		line_num += 1
	label.text = label.text.replace("\t", "      ")
	label2.text = ast.error_msg
