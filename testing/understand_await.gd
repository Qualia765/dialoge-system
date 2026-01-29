class_name FooBar extends Node

static var next_button: BaseButton

@export var switch_task_button: BaseButton

func _ready():
	next_button = %NextButton

var which: int = 0
var currently_executing: CancelableCode
func task_switch() -> void:
	currently_executing = CancelableCode.new()
	for i in range(10000):
		#print("meow")
		currently_executing.foo()
		currently_executing.bar()
		currently_executing.qux()
	#currently_executing = CancelableCode.new()
	#which = (which % 3) + 1
	#match which:
		#1: currently_executing.foo()
		#2: currently_executing.bar()
		#3: currently_executing.qux()
		#_: assert(false, "unreachable")




class CancelableCode:
	func say(what: String) -> Signal:
		if randf() < 0.0001: print(what)
		return FooBar.next_button.pressed
	
	func foo():
		await say("Foo1")
		await say("Foo2")
		await say("Foo3")

	func bar():
		await say("Bar1")
		await say("Bar2")
		await say("Bar3")

	func qux():
		await say("Qux1")
		await say("Qux2")
		await say("Qux3")
