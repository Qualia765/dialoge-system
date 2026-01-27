class_name QRuntime
extends RefCounted


# Instructions to have:
# Expression node DONE
# await Expression DONE
# Say
# Option
# Goto DONE
# Goto if DONE
# Once/else
# Add Task
# Checkpoint ?
# EndTask ?



class Runtime:
	var instructions: Array[Instruction] = []
	var current_instruction: int = 0
	var async_signal: Signal = Signal()
	var error_msg: String = ""
	var expression_varrible_names: PackedStringArray = []
	var expression_varible_values: Array = []
	var expression_base_instance: Object = null
	var say_function: Callable
	
	signal completed
	
	func _init(
		instructions_: Array[Instruction] = [],
		expression_varrible_names_: PackedStringArray = [],
		expression_varible_values_: Array = [],
		expression_base_instance_: Object = null,
	):
		instructions = instructions_
		expression_varrible_names = expression_varrible_names_
		expression_varible_values = expression_varible_values_
		expression_base_instance = expression_base_instance_
		
		for instruction in instructions:
			instruction.rt_initalize(self)
		
		if expression_base_instance_ != null and expression_base_instance_.has_method(&"_say"):
			say_function = expression_base_instance_._say
	
	func add_error(line_num: int, msg: String) -> void:
		error_msg += str("Line ", line_num, ": ", msg, "\n")
	
	## Returns true when its done with the program
	## Returns false when its waiting for async
	func execute() -> bool:
		assert(async_signal.is_null(), "Dont execute while Runtime is awaiting a signal")
		while current_instruction < len(instructions):
			var result: Variant = instructions[current_instruction].execute(self)
			if result is Signal:
				_connect_signal(result)
				return false
			else:
				assert(result == null, "Instructions must return Signal or null")
			current_instruction += 1
		
		quit()
		completed.emit()
		return true
	
	## should only be connected to the signal in async_signal
	## not to be called under other circumstances
	func _async_recieve(...__) -> void: # ...__ lets it take any number of arguments - which it will completly ignore
		_disconnect_signal()
		current_instruction += 1
		execute()
	
	func _connect_signal(le_signal: Signal):
		assert(async_signal.is_null(), "Expected async_signal to be null")
		async_signal = le_signal
		async_signal.connect(_async_recieve)
	
	func _disconnect_signal():
		assert(not async_signal.is_null(), "Expected async_signal to not be null")
		async_signal.disconnect(_async_recieve)
		async_signal = Signal()
	
	func quit():
		if not async_signal.is_null():
			_disconnect_signal()


## if its a value, inistalize with ValueOrExpression.new(5)
## if its expression initalize with ValueOrExpression.new("random()", true)
## if its only evaulated once use ValueOrExpression.new("random()", true, true)
class ValueOrExpression:
	var value: Variant
	var is_expression: bool
	var cache_result: bool
	func _init(value_: Variant = null, is_expression_: bool = false, cache_result_: bool = false) -> void:
		value = value_
		is_expression = is_expression_
		cache_result = cache_result_
		if is_expression_:
			assert(value_ is String, "if its expression, value must be a string")
		else:
			assert(not cache_result, "cant cache the result if its not expression")
	
	func rt_initalize(runtime: Runtime, dbg_ln: int) -> void:
		if is_expression:
			assert(runtime != null)
			var command = value
			value = Expression.new()
			var error: Error = value.parse(command, runtime.expression_varrible_names)
			if error != OK:
				push_error(value.get_error_text())
				runtime.add_error(dbg_ln, str("Error parsing Expression: error code ", error))
	
	func get_value(runtime: Runtime, dbg_ln: int) -> Variant:
		if is_expression:
			var result = value.execute(runtime.expression_varible_values, runtime.expression_base_instance)
			if value.has_execute_failed():
				runtime.add_error(dbg_ln, "Expression Execution Failed")
				result = null
			if cache_result:
				is_expression = false
				cache_result = false
				value = result
			return result
		else:
			return value
	
	static func make_string_from_array(voes: Array[ValueOrExpression], runtime: Runtime, dbg_ln: int) -> String:
		var result := ""
		for voe in voes:
			result += str(voe.get_value(runtime, dbg_ln))
		return result






@abstract class Instruction:
	## dbg_ln means debug line number which is the line number from the original source code to be used in error messages
	var dbg_ln: int = -1
	@abstract func rt_initalize(runtime: Runtime) -> void
	@abstract func execute(runtime: Runtime) -> Variant



class InstructionExpression extends Instruction:
	var expression: ValueOrExpression = null
	var await_result: bool = false
	
	func _init(dbg_ln_: int, expression_: ValueOrExpression = null, await_result_: bool = false) -> void:
		dbg_ln = dbg_ln_
		await_result = await_result_
		if expression_ == null:
			expression = ValueOrExpression.new()
		else:
			expression = expression_
	
	func rt_initalize(runtime: Runtime) -> void:
		expression.rt_initalize(runtime, dbg_ln)
	
	func execute(runtime: Runtime) -> Variant:
		var result = expression.get_value(runtime, dbg_ln)
		if await_result:
			if result is Signal:
				return result
			runtime.add_error(dbg_ln, str("Await did not recieve signal and instead got ", typeof(result)))
			return null
		else:
			if result != null:
				runtime.add_error(dbg_ln, "Expression returned non-null result")
			return null



class InstructionGotoIf extends Instruction:
	var next_instruction: int = 0
	var condition: ValueOrExpression
	var else_instruction: int = -1
	
	func _init(dbg_ln_: int, next_instruction_: int, condition_: ValueOrExpression = null, else_instruction_: int = -1):
		dbg_ln = dbg_ln_
		next_instruction = next_instruction_
		else_instruction = else_instruction_
		if condition_ == null:
			condition = ValueOrExpression.new(true)
		else:
			condition = condition_
	
	func rt_initalize(runtime: Runtime) -> void:
		condition.rt_initalize(runtime, dbg_ln)
	
	func execute(runtime: Runtime) -> Variant:
		var condition_value = condition.get_value(runtime, dbg_ln)
		if not(condition_value is bool):
			runtime.add_error(dbg_ln, str("Expected bool for condition, but found ", typeof(condition_value)))
			return null
		if condition_value:
			runtime.current_instruction = next_instruction - 1 # - 1 because the current_instruction will +=1
		else:
			if else_instruction != -1:
				runtime.current_instruction = else_instruction - 1
		return null



class InstructionSay extends Instruction:
	var voes: Array[ValueOrExpression]
	func _init(dbg_ln_: int, voes_: Array[ValueOrExpression] = []) -> void:
		dbg_ln = dbg_ln_
		voes = voes_
	
	func rt_initalize(runtime: Runtime) -> void:
		for voe in voes:
			voe.rt_initalize(runtime, dbg_ln)
	
	func _complain_about_lack_of_say(runtime: Runtime):
		runtime.add_error(dbg_ln, "Can not use 'say' instruction if base instance does not have _say method")
	
	func execute(runtime: Runtime) -> Variant:
		if runtime.say_function.is_null():
			_complain_about_lack_of_say(runtime)
			return
		var result = ValueOrExpression.make_string_from_array(voes, runtime, dbg_ln)
		return null
	
	
