extends Control


@export var label: Label
@export var button: BaseButton

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
		QRuntime.InstructionExpression.new(1, "fake_print('Hello')", false),
		QRuntime.InstructionExpression.new(2, "fake_print(str('Hello', foo))", false),
	], ["foo"], [2], self)
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")
	assert(label.text == "Hello\nHello2\n", "correct output")


func test3():
	label.text = ""
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionExpression.new(1, "fake_print('Press Button To Continue')", false),
		QRuntime.InstructionExpression.new(2, "button.pressed", true),
		QRuntime.InstructionExpression.new(3, "fake_print('You Pressed The Button')", false),
	], [], [], self)
	assert(not runtime.execute(), "shouldn't yet be done")
	await runtime.completed
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")


func test4():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionExpression.new(1, "(", false),
	])
	assert(runtime.execute(), "done")
	assert(runtime.error_msg != "", "Errored")


func test5():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionExpression.new(1, "5", false),
	])
	assert(runtime.execute(), "done")
	assert(runtime.error_msg != "", "Errored")

func test6():
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionExpression.new(1, "5", true),
	])
	assert(runtime.execute(), "done")
	assert(runtime.error_msg != "", "Errored")

func test7():
	foo = 0
	label.text = ""
	var runtime: QRuntime.Runtime = QRuntime.Runtime.new([
		QRuntime.InstructionExpression.new(1, "set('foo', foo+1)", false),
		QRuntime.InstructionGotoIf.new(2, 0, QRuntime.ValueOrExpression.new("foo < 3", true)),
		QRuntime.InstructionExpression.new(3, "fake_print(str('Foo:', foo))", false),
	], [], [], self)
	assert(runtime.error_msg == "", "no error")
	assert(runtime.execute(), "done")
	assert(runtime.error_msg == "", "no error")
	assert(label.text == "Foo:3\n", "correct output")

var foo

func fake_print(string: String) -> void:
	label.text = str(label.text, string, "\n")
