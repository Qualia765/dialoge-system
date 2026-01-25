extends Control


@export var label: Label
@export var button: Button

func _on_button_pressed() -> void:
	await test1()
	await test2()
	await test3()
	await test4()
	await test5()
	await test6()
	await test7()
	label.text = "Tests Passed!"
	


func test1():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new()
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")


func test2():
	label.text = ""
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionGDScript.new("fake_print('Hello')", false, 1),
		QRuntime.InstructionGDScript.new("fake_print(str('Hello', foo))", false, 2),
	], ["foo"], [2], self)
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")
	assert(label.text == "Hello\nHello2\n", "correct output")


func test3():
	label.text = ""
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionGDScript.new("fake_print('Press Button To Continue')", false, 1),
		QRuntime.InstructionGDScript.new("button.pressed", true, 2),
		QRuntime.InstructionGDScript.new("fake_print('You Pressed The Button')", false, 3),
	], [], [], self)
	assert(not runtime.execute(), "shouldn't yet be done")
	await runtime.completed
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")


func test4():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionGDScript.new("(", false, 1),
	])
	assert(runtime.execute(), "done")
	assert(runtime.error_msg != "", "Errored")


func test5():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionGDScript.new("5", false, 1),
	])
	assert(runtime.execute(), "done")
	assert(runtime.error_msg != "", "Errored")

func test6():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionGDScript.new("5", true, 1),
	])
	assert(runtime.execute(), "done")
	assert(runtime.error_msg != "", "Errored")

func test7():
	foo = 0
	label.text = ""
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionGDScript.new("set('foo', foo+1)", false, 0),
		QRuntime.InstructionGotoIf.new(0, QRuntime.ValueOrGDScript.new("foo < 3", true), 1),
		QRuntime.InstructionGDScript.new("fake_print(str('Foo:', foo))", false, 2),
	], [], [], self)
	assert(runtime.error_msg == "", "no error")
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")
	assert(label.text == "Foo:3\n", "correct output")

var foo

func fake_print(string: String) -> void:
	label.text = str(label.text, string, "\n")
