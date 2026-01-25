class_name QRuntime
extends RefCounted


# Instructions to have:
# GDscript node DONE
# await GDscript DONE
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
	var gdscript_varrible_names: PackedStringArray = []
	var gdscript_varible_values: Array = []
	var gdscript_base_instance: Object = null
	
	signal completed
	
	func _init(
		instructions_: Array[Instruction] = [],
		gdscript_varrible_names_: PackedStringArray = [],
		gdscript_varible_values_: Array = [],
		gdscript_base_instance_: Object = null
	):
		instructions = instructions_
		gdscript_varrible_names = gdscript_varrible_names_
		gdscript_varible_values = gdscript_varible_values_
		gdscript_base_instance = gdscript_base_instance_
		
		for instruction in instructions:
			instruction.rt_initalize(self)
	
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
	func _async_recieve() -> void:
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


## if its a value, inistalize with ValueOrGDScript.new(5)
## if its gdscript initalize with ValueOrGDScript.new("random()", true)
## if its only evaulated once use ValueOrGDScript.new("random()", true, true)
class ValueOrGDScript:
	var value: Variant
	var is_gd_script: bool
	var cache_result: bool
	func _init(value_: Variant, is_gd_script_: bool = false, cache_result_: bool = false) -> void:
		value = value_
		is_gd_script = is_gd_script_
		cache_result = cache_result_
		if is_gd_script_:
			assert(value_ is String, "if its gdscript, value must be a string")
		else:
			assert(not cache_result, "cant cache the result if its not gdscript")
	
	func rt_initalize(runtime: Runtime, dbg_ln: int) -> void:
		if is_gd_script:
			assert(runtime != null)
			var command = value
			value = Expression.new()
			var error: Error = value.parse(command, runtime.gdscript_varrible_names)
			if error != OK:
				push_error(value.get_error_text())
				runtime.add_error(dbg_ln, str("Error parsing GDScript: error code ", error))
	
	func get_value(runtime: Runtime, dbg_ln: int) -> Variant:
		if is_gd_script:
			var result = value.execute(runtime.gdscript_varible_values, runtime.gdscript_base_instance)
			if value.has_execute_failed():
				runtime.add_error(dbg_ln, "GDScript Execution Failed")
				result = null
			if cache_result:
				is_gd_script = false
				cache_result = false
				value = result
			return result
		else:
			return value



@abstract class Instruction:
	## dbg_ln means debug line number which is the line number from the original source code to be used in error messages
	var dbg_ln: int = -1
	@abstract func rt_initalize(runtime: Runtime) -> void
	@abstract func execute(runtime: Runtime) -> Variant



class InstructionGDScript extends Instruction:
	var expression: ValueOrGDScript = null
	var await_result: bool = false
	
	func _init(command: String = "", await_result_: bool = false, dbg_ln_: int = -1) -> void:
		dbg_ln = dbg_ln_
		await_result = await_result_
		expression = ValueOrGDScript.new(command, true)
	
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
				runtime.add_error(dbg_ln, "GDScript returned non-null result")
			return null



class InstructionGotoIf extends Instruction:
	var next_instruction: int = 0
	var condition: ValueOrGDScript
	var else_instruction: int = -1
	
	func _init(next_instruction_: int, condition_: ValueOrGDScript = null, else_instruction_: int = -1, dbg_ln_: int = -1):
		dbg_ln = dbg_ln_
		next_instruction = next_instruction_
		else_instruction = else_instruction_
		if condition_ == null:
			condition = ValueOrGDScript.new(true)
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
