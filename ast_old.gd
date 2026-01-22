class_name AST
extends RefCounted

# this only tokenizes
# do not add fancy logic to make different things reference each other
# if thats needed do it in a second pass



# godot please add scoped functions please please please
# godot please a private key word please please please
var _line: String
var _line_num: int

func _get_error_prefix() -> String:
	return str("Line ", _line_num+1, ": ", _line, "\n")

var tokens: Array[Token] = []


func parse(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	_line_num = 0
	for original_line: String in lines:
		_line = original_line.strip_edges()
		
		if _line.begins_with("#"):
			var marker_name: String = _line.substr(1).strip_edges()
			if not is_valid_name(marker_name):
				return str(_get_error_prefix(), "Invalid maker name: '", marker_name, "'")
			tokens.push_back(Marker.new(marker_name))
			
		elif _line.begins_with("!"):
			var instruct_prams: String = _line.substr(1).strip_edges()
			if len(instruct_prams) == 0:
				return str(_get_error_prefix(), "Expected Instruction")
			var instruct_end: int = instruct_prams.find(" ")
			var instruct: String = instruct_prams.substr(0, instruct_end).to_lower()
			var prams: String = instruct_prams.substr(instruct_end)
			match instruct:
				"goto":
					var l := _LineNameIterator.new(prams)
					var marker_name := l.next()
					l.done()
					if l.error != "": return str(_get_error_prefix(), l.error)
					tokens.push_back(GoTo.new(marker_name))
				
				"exe":
					tokens.push_back(Execute.new(prams))
				
				"set":
					var l := _LineNameIterator.new(prams)
					var var_name = l.next()
					if l.error != "": return str(_get_error_prefix(), l.error)
					tokens.push_back(Set.new(var_name, l.remain_text))
				
				"call":
					tokens.push_back(Call.new(prams))
				
				"return", "}":
					var l := _LineNameIterator.new(prams)
					l.done()
					if l.error != "": return str(_get_error_prefix(), l.error)
					tokens.push_back(Return.new())
				
				"jmpr":
					tokens.push_back(JumpRelative.new(prams))
				
				"if{":
					tokens.push_back(If.new(prams))
				
				_:
					return str(_get_error_prefix(), "Unknown Instruction '", instruct, "'")
		
		else:
			tokens.push_back(Say.new(original_line))
		_line_num += 1
	
	return ""


class _LineNameIterator:
	var remain_text: String = ""
	var error: String = ""
	func _init(text: String):
		remain_text = text.lstrip(" \t\r\n")
	func next() -> String:
		if remain_text == "":
			error += str("Not enough arguments\n")
			return ""
		var name_end: int = remain_text.find(" ")
		var name: String = remain_text.substr(0, name_end)
		if not AST.is_valid_name(name):
			error += str("Invalid name: '", name, "'\n")
		remain_text = remain_text.substr(name_end).lstrip(" \t\r\n")
		return name
	func done() -> void:
		if remain_text != "":
			error += str("Too many arguments\n")


func _to_string() -> String:
	var result: String = ""
	for tok in tokens:
		result += str(tok) + "\n"
	return result


static func is_valid_name(name_: String) -> bool:
	return not name_.contains(" ")


@abstract class Token:
	@abstract func _to_string()

class Marker extends Token:
	var name: String = ""
	func _init(name_: String):
		name = name_
	func _to_string() -> String:
		return "# " + name

class Say extends Token:
	var text: String = ""
	func _init(text_: String):
		text = text_
	func _to_string() -> String:
		return text

class GoTo extends Token:
	var marker_name: String = ""
	func _init(marker_name_: String):
		marker_name = marker_name_
	func _to_string() -> String:
		return "! GoTo " + marker_name

class Execute extends Token:
	var code: String = ""
	func _init(code_: String):
		code = code_
	func _to_string() -> String:
		return "! Exe " + code

class Set extends Token:
	var var_name: String = ""
	var code: String = ""
	func _init(var_name_: String, code_: String):
		var_name = var_name_
		code = code_
	func _to_string() -> String:
		return "! Set " + var_name + code

class Call extends Token:
	var marker_name: String = ""
	func _init(marker_name_: String):
		marker_name = marker_name_
	func _to_string() -> String:
		return "! Call " + marker_name

class Return extends Token:
	func _to_string() -> String:
		return "! Return"

class JumpRelative extends Token:
	var code: String = ""
	func _init(code_: String):
		code = code_
	func _to_string() -> String:
		return "! JmpR " + code

class If extends Token:
	var code: String = ""
	func _init(code_: String):
		code = code_
	func _to_string() -> String:
		return "! If{ " + code
