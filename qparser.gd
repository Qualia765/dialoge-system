class_name QParser
extends RefCounted



var root: RootNode = RootNode.new()
var error_msg: String = ""



func parse(text: String) -> void:
	root = RootNode.new()
	var state: ParseState = ParseState.new(text, 1)
	root.parse(state)
	if state.text != "":
		state.add_error("Unexpected content at the end\n")
	error_msg = state.error_msg



## returns the first index of string (or length if not found) that has a character that is inside of chars
## find_chars("foo bar", " ") -> 3
## "foo bar".substr(0,3) -> "foo"
## "foo bar".substr(3)   -> " bar"
static func find_chars(string: String, chars: String) -> int:
	var result: int = 0
	while result < string.length():
		if chars.contains(string[result]):
			return result
		result += 1
	return result



static func add_new_line_if_not_at_end_already(input: String) -> String:
	if input[len(input) - 1] == "\n": return input
	return input + "\n"



class ParseState:
	var text: String = ""
	var line_num: int = 1
	var error_msg: String
	
	func _init(text_: String = "", line_num_: int = 1, error_msg_: String = "") -> void:
		text = text_
		line_num = line_num_
		error_msg = error_msg_
	
	func lstrip() -> void:
		while true:
			lstrip_half()
			if text.is_empty(): return
			if text[0] != "\n": return
			text = text.substr(1)
			line_num += 1
	
	func lstrip_half() -> void:
		text = text.lstrip(" \t\r")
	
	func add_error(msg: String) -> void:
		error_msg += str("Line ", line_num, ": ", msg, "\n")
	
	func parse_name() -> String:
		var cut_point := QParser.find_chars(text, " \n\t$")
		if cut_point != len(text) && text[cut_point] == "$":
			add_error("Unexpected '$' in name")
			cut_point = QParser.find_chars(text, " \n\t")
		var yoinked := text.substr(0, cut_point)
		text = text.substr(cut_point)
		return yoinked
	
	func parse_instruct_name() -> String:
		var cut_point := QParser.find_chars(text, " \n\t")
		var yoinked := text.substr(0, cut_point)
		text = text.substr(cut_point)
		return yoinked
	
	## expected that lstrip() was called before this
	## if text.is_empty() will return null - take this into consideration to prevent infinite loops
	func parse_instruct_node() -> AstNode:
		if text.is_empty():
			add_error("Expected instruction but found end of file")
			return
		
		var node: AstNode = null
		if text.begins_with("//"):
			text = text.substr(2)
			node = CommentNode.new()
		elif text.begins_with("/*"):
			text = text.substr(2)
			node = BlockCommentNode.new()
		elif text.begins_with("!"):
			text = text.substr(1)
			node = SayNode.new()
		elif text.begins_with("$"):
			text = text.substr(1)
			node = GDScriptNode.new()
		elif text.begins_with("{"):
			text = text.substr(1)
			node = BlockNode.new()
		else:
			var instruct = parse_instruct_name()
			match instruct:
				"Option": node = OptionNode.new()
				"Task": node = TaskNode.new()
				"TaskAdd": node = TaskAddNode.new()
				"TaskEnd": node = TaskEndNode.new()
				"TaskCheckpoint": node = TaskCheckpointNode.new()
				"Tag": node = TagNode.new()
				"If": node = IfNode.new()
				"Else": node = ElseNode.new()
				"Loop": node = LoopNode.new()
				"While": node = WhileNode.new()
				"Until": node = UntilNode.new()
				"Once": node = OnceNode.new()
				"Await": node = AwaitNode.new()
				_:
					add_error(str("Unknown Instruction '", instruct, "'"))
					return
		node.parse(self)
		return node
	
	func parse_gdscript() -> String:
		var cut_point := QParser.find_chars(text, "$\n")
		var result = text.substr(0, cut_point).replace("\\n", "\n").replace("\\d", "$").replace("\\x", "!")
		text = text.substr(cut_point)
		if text.is_empty(): return result
		if text[0] == "\n": line_num += 1
		text = text.substr(1) # +1 to deal with ! or \n
		return result



@abstract class AstNode:
	var depth: int = 0
	@abstract func parse(state: ParseState) -> void
	@abstract func _to_string() -> String



static func indent_string(input: String) -> String:
	var result = ""
	var s := input.split("\n")
	var i := 0
	for e in s:
		result += "\t" + e
		if i != len(s) -1:
			result += "\n"
		i += 1
	return result



class RootNode extends AstNode:
	var nodes: Array[AstNode] = []
	func parse(state: ParseState) -> void:
		while true:
			state.lstrip()
			if state.text.is_empty():
				return
			if state.text.begins_with("}"):
				state.add_error("Unexpected '}' before end of file\n")
				return
			nodes.push_back(state.parse_instruct_node())
	
	func _to_string() -> String:
		if nodes.is_empty():
			return "{}"
		var result = ""
		for node in nodes:
			result += str(node)
		return result.rstrip(" \t\n")



class BlockNode extends AstNode:
	var nodes: Array[AstNode] = []
	func parse(state: ParseState) -> void:
		while true:
			state.lstrip()
			if state.text.is_empty():
				state.add_error("Expected instruction but found end of file")
				return
			if state.text.begins_with("}"):
				state.text = state.text.substr(1)
				return
			nodes.push_back(state.parse_instruct_node())
	
	func _to_string() -> String:
		if nodes.is_empty():
			return "{}"
		var result = ""
		for node in nodes:
			result += str(node)
		return  "{\n" + QParser.indent_string(result.rstrip(" \t\n")) + "\n} "



class TextNode extends AstNode:
	var msg_parts: Array[String] = []
	var code_parts: Array[String] = []
	
	func parse(state: ParseState) -> void:
		var msg_mode: bool = true
		while true:
			var cut_point := QParser.find_chars(state.text, "$!\n")
			var section = state.text.substr(0, cut_point).replace("\\n", "\n").replace("\\d", "$").replace("\\x", "!")
			if msg_mode:
				msg_parts.push_back(section)
			else:
				code_parts.push_back(section)
			state.text = state.text.substr(cut_point)
			if state.text.is_empty(): return
			if state.text[0] == "$":
				state.text = state.text.substr(1)  # to deal with $
				msg_mode = !msg_mode
			else:
				break
		if state.text[0] == "\n": state.line_num += 1
		state.text = state.text.substr(1) # to deal with ! or \n
	
	func _to_string() -> String:
		var result: String = ""
		var index: int = 0
		while true:
			if index >= len(msg_parts): break
			result += msg_parts[index].replace("\n", "\\n").replace("$", "\\d").replace("!", "\\x") + "$"
			if index >= len(code_parts): break
			result += code_parts[index].replace("\n", "\\n").replace("$", "\\d").replace("!", "\\x") + "$"
			index += 1
		return result.substr(0, len(result) - 1)



class SayNode extends AstNode:
	var text_node: TextNode
	func parse(state: ParseState) -> void:
		text_node = TextNode.new()
		text_node.parse(state)
	func _to_string() -> String:
		return str("!", text_node, "\n")

class CommentNode extends AstNode:
	var msg: String = ""
	func parse(state: ParseState) -> void:
		var cut_point := QParser.find_chars(state.text, "\n")
		msg = state.text.substr(0, cut_point)
		state.text = state.text.substr(cut_point)
		if state.text.is_empty(): return
		state.line_num += 1
		state.text = state.text.substr(1) # +1 to deal with ! or \n
	func _to_string() -> String:
		return str("//", msg, "\n")

class BlockCommentNode extends AstNode:
	var msg: String = ""
	func parse(state: ParseState) -> void:
		var cut_point := state.text.find("*/")
		msg = state.text.substr(0, cut_point)
		state.line_num += msg.count("\n")
		state.text = state.text.substr(cut_point)
		if state.text.is_empty():
			state.add_error("Expected '*/' but encounted end of file")
			return
		state.text = state.text.substr(2) # +1 to deal with ! or \n
	func _to_string() -> String:
		return str("/*", msg, "*/\n")

class GDScriptNode extends AstNode:
	var code: String = ""
	func parse(state: ParseState) -> void:
		code = state.parse_gdscript()
	func _to_string() -> String:
		return str("$", code.replace("\n", "\\n").replace("d", "\\$"), "\n")

class TaskEndNode extends AstNode:
	func parse(_state: ParseState) -> void:
		return
	func _to_string() -> String:
		return "TaskEnd "

class TaskCheckpointNode extends AstNode:
	var node: AstNode
	func parse(state: ParseState) -> void:
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return "TaskCheckpoint " + QParser.add_new_line_if_not_at_end_already(str(node))

class IfNode extends AstNode:
	var node: AstNode
	var condition: ValueOrGDScriptNode
	func parse(state: ParseState) -> void:
		condition = ValueOrGDScriptNode.new()
		condition.parse(state)
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return QParser.add_new_line_if_not_at_end_already(str("If ", condition, node))

class AwaitNode extends AstNode:
	var code: String
	func parse(state: ParseState) -> void:
		state.lstrip()
		if state.text.is_empty():
			state.add_error("Expected $, but found end of file")
			return
		if state.text[0] != "$":
			state.add_error(str("Expected $, but found ", state.text[0]))
			return
		state.text = state.text.substr(1)
		code = state.parse_gdscript()
	func _to_string() -> String:
		return str("Await $", code, "$\n")

class ValueOrGDScriptNode extends AstNode:
	var isCode: bool = false
	var value: String = ""
	func parse(state: ParseState) -> void:
		state.lstrip()
		if state.text.is_empty():
			state.add_error("Expected value or gdscript but found end of file")
		if state.text[0] == "$":
			isCode = true
			state.text = state.text.substr(1)
			value = state.parse_gdscript()
		else:
			isCode = false
			value = state.parse_name()
		
	func _to_string() -> String:
		if isCode:
			return str("$", value, "$ ")
		else:
			return value + " "

class ElseNode extends AstNode:
	var node: AstNode
	func parse(state: ParseState) -> void:
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return "Else " + QParser.add_new_line_if_not_at_end_already(str(node))

class LoopNode extends AstNode:
	var node: AstNode
	func parse(state: ParseState) -> void:
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return "Loop " + QParser.add_new_line_if_not_at_end_already(str(node))

class OnceNode extends AstNode:
	var node: AstNode
	func parse(state: ParseState) -> void:
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return "Once " + QParser.add_new_line_if_not_at_end_already(str(node))

class WhileNode extends AstNode:
	var node: AstNode
	var condition: ValueOrGDScriptNode
	func parse(state: ParseState) -> void:
		condition = ValueOrGDScriptNode.new()
		condition.parse(state)
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return QParser.add_new_line_if_not_at_end_already(str("While ", condition, node))

class UntilNode extends AstNode:
	var node: AstNode
	var condition: ValueOrGDScriptNode
	func parse(state: ParseState) -> void:
		condition = ValueOrGDScriptNode.new()
		condition.parse(state)
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return QParser.add_new_line_if_not_at_end_already(str("Until ", condition, node))

class TaskAddNode extends AstNode:
	var task_name: String = ""
	var recipient_name: String = ""
	func parse(state: ParseState) -> void:
		state.lstrip()
		if state.text.is_empty():
			state.add_error("Expected name but found end of file")
			return
		task_name = state.parse_name()
		state.lstrip_half()
		if state.text.is_empty() || state.text[0] == "\n":
			return
		recipient_name = state.parse_name()
	func _to_string() -> String:
		if recipient_name == "":
			return str("TaskAdd ", task_name, "\n")
		else:
			return str("TaskAdd ", task_name, " ", recipient_name, " ")

class TaskNode extends AstNode:
	var task_name: String = ""
	var utility: ValueOrGDScriptNode = ValueOrGDScriptNode.new()
	var node: AstNode
	func parse(state: ParseState) -> void:
		state.lstrip()
		if state.text.is_empty():
			state.add_error("Expected task name, utility, and node, but found end of file")
			return
		task_name = state.parse_name()
		utility = ValueOrGDScriptNode.new()
		utility.parse(state)
		state.lstrip()
		node = state.parse_instruct_node()
	func _to_string() -> String:
		return QParser.add_new_line_if_not_at_end_already(str("Task ", task_name, " ", utility, " ", node))

class TagNode extends AstNode:
	var tag_name: String = ""
	var value: ValueOrGDScriptNode = ValueOrGDScriptNode.new()
	func parse(state: ParseState) -> void:
		state.lstrip()
		if state.text.is_empty():
			state.add_error("Expected tag name and value but found end of file")
			return
		tag_name = state.parse_name()
		value = ValueOrGDScriptNode.new()
		value.parse(state)
	func _to_string() -> String:
		return str("Task ", tag_name, " ", value, " ")



class OptionNode extends AstNode:
	var option_names: Array[TextNode] = []
	var blocks: Array[BlockNode] = []
	
	func parse(state: ParseState) -> void:
		state.lstrip()
		if state.text.is_empty():
			state.add_error("Expected {, but found end of file")
			return
		if state.text[0] != "{":
			state.add_error(str("Expected {, but found ", state.text[0]))
			return
		state.text = state.text.substr(1)
		while true:
			state.lstrip()
			if state.text.is_empty():
				state.add_error("Expected ! or } in Option, but found end of file")
				return
			if state.text[0] == "!":
				state.text = state.text.substr(1)
				var success = parse_part(state)
				if not success: return
			elif state.text[0] == "}":
				state.text = state.text.substr(1)
				return
			else:
				state.add_error(str("Expected ! or } in option block, but found ", state.text[0]))
				return
	
	func parse_part(state: ParseState) -> bool:
		var option_name: TextNode = TextNode.new()
		option_name.parse(state)
		option_names.push_back(option_name)
		state.lstrip()
		if state.text.is_empty():
				state.add_error("Expected { in Option, but found end of file")
				return false
		if state.text[0] != "{":
			state.add_error(str("Expected {, but found ", state.text[0]))
			return false
		state.text = state.text.substr(1)
		var block: BlockNode = BlockNode.new()
		block.parse(state)
		blocks.push_back(block)
		return true
	
	func _to_string() -> String:
		var result: String = ""
		for index in range(len(blocks)):
			result += str("!", option_names[index], "! ", blocks[index], "\n")
		return str("Option {\n", QParser.indent_string(result.rstrip(" \t\n")), "\n} ")
