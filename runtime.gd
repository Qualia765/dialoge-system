class_name Runtime
extends RefCounted

var tokens: Array[Token] = []

var index: int = 0
var stack: Array[int] = []

@abstract class Token:
	@abstract func _to_string()

class Say extends Token:
	var text: String = ""
	func _init(text_: String):
		text = text_
	func _to_string() -> String:
		return "Say: " + text

func evaluate(command, variable_names = [], variable_values = []) -> Variant:
	var expression = Expression.new()
	var error = expression.parse(command, variable_names)
	if error != OK:
		push_error(expression.get_error_text())
		return

	var result = expression.execute(variable_values, self)

	if not expression.has_execute_failed():
		return result
	return
