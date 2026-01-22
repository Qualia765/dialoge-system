class_name NewAST
extends RefCounted

var root: BlockNode = BlockNode.new()
var error_msg: String = ""

func _to_string() -> String:
	return str(root)



func parse(text: String) -> void:
	root = BlockNode.new()
	var state: ParseState = ParseState.new(str("\n", text, "\n}"), 0)
	root.parse(state)
	if state.text != "":
		state.add_error("Unexpected content at the end\n")
	error_msg = state.error_msg



class ParseState:
	var text: String = ""
	var line_num: int = 1
	var error_msg: String
	var depth: int = 0
	
	func _init(text_: String = "", line_num_: int = 1, error_msg_: String = "") -> void:
		text = text_
		line_num = line_num_
		error_msg = error_msg_
	
	func lstrip() -> void:
		lstrip_half()
		while text[0] == "\n":
			text = text.substr(1)
			lstrip_half()
			line_num += 1
	
	func lstrip_half() -> void:
		text = text.lstrip(" \t\r")
	
	func add_error(msg: String) -> void:
		error_msg += str("Line ", line_num, ": ", msg, "\n")


static func find_chars(string: String, chars: String) -> int:
	var result: int = 0
	while result < string.length() - 1:
		if chars.contains(string[result]):
			return result
		result += 1
	return result


@abstract class AstNode:
	var depth: int = 0
	@abstract func _to_string() -> String
	@abstract func parse(state: ParseState) -> void



class BlockNode extends AstNode:
	var nodes: Array[AstNode] = []
	func parse(state: ParseState) -> void:
		depth = state.depth
		while true:
			state.lstrip_half()
			if state.text == "": # this is illegal
				state.add_error("Expected '}'")
				return
			# first try without removing new lines
			match state.text[0]:
				"!", "{", "#", "/":
					parse_special(state)
				"}":
					state.text = state.text.substr(1)
					state.depth -= 1
					return
				"\n":
					state.lstrip()
					match state.text[0]:
						"!", "{", "#", "/":
							parse_special(state)
						"}":
							state.text = state.text.substr(1)
							state.depth -= 1
							return
						_: # This is say node
							var say_node := SayNode.new()
							say_node.parse(state)
							nodes.push_back(say_node)
				_: # this is illegal
					var cut_point := state.text.find("\n")
					state.add_error(str("Unexpected '", state.text.substr(0, cut_point), "'"))
					if cut_point != -1:
						state.text = state.text.substr(cut_point) # skip to new line
					# example:
					# } foo
					# Unexpected 'foo' 
					# without this case it would try to say foo - i think it is better to error here
					
	
	# assumes that starts with ! { or # and will only parse one node
	func parse_special(state: ParseState) -> void:
		match state.text[0]:
			"!":
				state.text = state.text.substr(1)
				state.lstrip_half()
				var cut_point: int = NewAST.find_chars(state.text, " \t!{")
				if "!{".contains(state.text[cut_point]):
					cut_point += 1
				var instruct: String = state.text.substr(0, cut_point).to_lower()
				state.text = state.text.substr(cut_point).lstrip(" \t")
				var node: AstNode = null
				match instruct:
					"choose[":
						assert(false, "todo")
					"def{":
						node = FunctionNode.new()
					"x":
						node = ExecuteNode.new()
					"jump":
						node = JumpNode.new()
					"jumpx":
						node = JumpExecuteNode.new()
					"call":
						node = CallNode.new()
					"callx":
						node = CallExecuteNode.new()
					"!":
						node = CommentNode.new()
					"if{":
						node = IfNode.new()
					"else{":
						node = ElseNode.new()
					"elif{":
						node = ElIfNode.new()
					"loop{":
						node = LoopNode.new()
					_:
						state.add_error(str("Unknown Instruction '", instruct, "'"))
						return
				
				node.parse(state)
				nodes.push_back(node)
				
			"{": # This is anouther block node
				state.text = state.text.substr(1)
				state.depth += 1
				var block_node := BlockNode.new()
				block_node.parse(state)
				nodes.push_back(block_node)
			"#":
				assert(false, "todo")
			_:
				assert(false, "unreachable")
	
	func _to_string() -> String:
		var result = ""
		for node in nodes:
			if node is BlockNode:
				result += "\t".repeat(depth) + "{\n"
			result += str(node)
		result += "\t".repeat(depth-1) + "}\n"
		return result



class SayNode extends AstNode:
	var msg: String = ""
	func parse(state: ParseState) -> void:
		depth = state.depth
		var cut_point := state.text.find("\n")
		msg = state.text.substr(0, cut_point).replace("\\\n", "\n")
		if msg[0] == "\\":
			msg = msg.substr(1)
		state.text = state.text.substr(cut_point)
		state.line_num += 1
	func _to_string() -> String:
		var msg_converted := msg.replace("\n", "\\n")
		if " \t!{}#".contains(msg_converted[0]):
			msg_converted = "\\" + msg_converted
		return "\t".repeat(depth) + msg_converted + "\n"

@abstract class SimpleLineNode extends AstNode:
	var line: String = ""
	func parse(state: ParseState) -> void:
		depth = state.depth
		var cut_point := state.text.find("\n")
		line = state.text.substr(0, cut_point)
		state.text = state.text.substr(cut_point)
		state.line_num += 1

class ExecuteNode extends SimpleLineNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! X ", line, "\n")

class JumpExecuteNode extends SimpleLineNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! JumpX ", line, "\n")

class CallExecuteNode extends SimpleLineNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! CallX ", line, "\n")

class CommentNode extends SimpleLineNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "!! ", line, "\n")

@abstract class SimpleNameNode extends AstNode:
	var name: String = ""
	func parse(state: ParseState) -> void:
		depth = state.depth
		var cut_point: int = NewAST.find_chars(state.text, " \n\t!{#")
		name = state.text.substr(0, cut_point)
		state.text = state.text.substr(cut_point)

class CallNode extends SimpleNameNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! Call ", name, "\n")

class JumpNode extends SimpleNameNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! Jump ", name, "\n")

class FunctionNode extends AstNode:
	# syntax:
	# ! def{ FunctionName
	# 	!! code here
	# }
	var name: String = ""
	var block: BlockNode
	func parse(state: ParseState) -> void:
		depth = state.depth
		var cut_point: int = NewAST.find_chars(state.text, " \n\t!{#")
		name = state.text.substr(0, cut_point)
		
		state.text = state.text.substr(cut_point)
		state.depth += 1
		var block_node := BlockNode.new()
		block_node.parse(state)
		block = block_node
	func _to_string() -> String:
		return str("\t".repeat(depth), "! Def{ ", name, "\n", block)

class IfNode extends AstNode:
	var code: String = ""
	var block: BlockNode
	func parse(state: ParseState) -> void:
		depth = state.depth
		var cut_point := state.text.find("\n")
		code = state.text.substr(0, cut_point)
		state.text = state.text.substr(cut_point)
		state.line_num += 1
		
		state.depth += 1
		var block_node := BlockNode.new()
		block_node.parse(state)
		block = block_node
	
	func _to_string() -> String:
		return str("\t".repeat(depth), "! If{ ", code, "\n", block)

class ElIfNode extends IfNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! ElIf{ ", code, "\n", block)

@abstract class SimpleBlockNode extends AstNode:
	var block: BlockNode
	func parse(state: ParseState) -> void:
		depth = state.depth
		state.depth += 1
		var block_node := BlockNode.new()
		block_node.parse(state)
		block = block_node

class ElseNode extends SimpleBlockNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! Else{ ", "\n", block)

class LoopNode extends SimpleBlockNode:
	func _to_string() -> String:
		return str("\t".repeat(depth), "! Loop{ ", "\n", block)
