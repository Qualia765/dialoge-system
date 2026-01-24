class_name Runtime
extends RefCounted


static func eval(_code: String):
	assert(false, "TODO") # TODO


class ValueOrGDScript:
	var value: Variant
	func init(value_: Variant) -> void:
		value = value_
	
	func get_value() -> Variant:
		if value is Expression:
			return Runtime.eval(value)
		else:
			return value


class Global:
	static var singleton: Global
	var tasks: Dictionary[StringName, Task]
	
	static func get_singleton() -> Global:
		if Global.singleton == null:
			Global.singleton = Global.new()
		return Global.singleton


class Task:
	var utility: ValueOrGDScript
	var instructions: Array[Instruction]
	
	func get_utility() -> float:
		return utility.get_value()
	
	func execute(line: int) -> void:
		assert(line < len(instructions), "line is too large for instructions")
		assert(line >= 0, "line is less than 0")
		instructions[line].execute()
		


class Agent:
	var active_tasks: Array[Task]
	var current_task_index: int
	var instruction_in_task_index: int
	
	func choose_next_task() -> void:
		var highest_utility: float = -1.79769e308
		var highest_index: int = -1
		var index: int = -1
		for task in active_tasks:
			index += 1
			var current_task_utility: float = task.get_utility()
			if current_task_utility > highest_utility:
				highest_index = index
		
		if highest_index != current_task_index:
			switch_to_task(highest_index)
	
	func switch_to_task(new_active_task_index):
		current_task_index = new_active_task_index
	
	func execute() -> void:
		if current_task_index < 0: return
		assert(current_task_index <= len(active_tasks), "current_task_index is too large for active_tasks")
		active_tasks[current_task_index].execute(instruction_in_task_index)


@abstract class Instruction:
	@abstract func execute() -> void


class InstructionExecute extends Instruction:
	var code: String
	func execute() -> void:
		Runtime.eval(code)




# All agents use a single Global, but different Agents

# Instructions to have:
# GDscript node
# await GDscript
# Say
# Option
# Goto
# Goto if
# Once/else
# Add Task
# Checkpoint ?
# EndTask ?

# Other classes:
# Agent
# Cached GDscript
# AdvancedString - for stuff like !Hello $name$, that item costs \d$price$.!
# Task - Just an array of instructions with a nice API

# Data to consern oneself with:
# Once - Instruction
# Cached GDscript results - Specific Class
# All the tasks - Global
# The active tasks - Agent
# The current line in the current task - Agent
# What we are awaiting on - Agent
# The tags for a given - Instruction
