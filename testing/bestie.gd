extends Node2D

@export var label: Label
@export var nav_agent: NavigationAgent2D


var runtime: QRuntime.Runtime

func _ready() -> void:
	runtime = QRuntime.Runtime.new([
		QRuntime.InstructionSay.new(0, [QRuntime.ValueOrExpression.new("Click Me!!!")]),
		QRuntime.InstructionSay.new(1, [QRuntime.ValueOrExpression.new("wow! if you click me again, ill show you a trick")]),
		QRuntime.InstructionSay.new(2, [QRuntime.ValueOrExpression.new("randf(): "), QRuntime.ValueOrExpression.new("randf()", true), QRuntime.ValueOrExpression.new("!")]),
		QRuntime.InstructionSay.new(3, [], false),
		QRuntime.InstructionExpression.new(4, QRuntime.ValueOrExpression.new("go_to(LOCATION_THEATER)", true), true),
		QRuntime.InstructionExpression.new(5, QRuntime.ValueOrExpression.new("_say('Wow look at that, im here now')", true), true),
		QRuntime.InstructionExpression.new(6, QRuntime.ValueOrExpression.new("_say('Isn\\'t that so cool?')", true), true),
		QRuntime.InstructionExpression.new(7, QRuntime.ValueOrExpression.new("_say('')", true), false),
	], [], [], self)
	assert(runtime.error_msg == "", "no error")
	runtime.execute()




signal clicked
func _on_button_2_pressed() -> void:
	clicked.emit()

func _say(what: String) -> Signal:
	label.text = what
	return clicked

var pathing: bool = false

func go_to(goal: Vector2) -> Signal:
	pathing = true
	nav_agent.target_position = goal
	return nav_agent.navigation_finished

const LOCATION_THEATER: Vector2 = Vector2(857.0, 673.0)
const LOCATION_BILLIARDS: Vector2 = Vector2(2027.0, 1565.0)
const LOCATION_KITCHEN: Vector2 = Vector2(1434.0, 299.0)
const LOCATION_OFFICE: Vector2 = Vector2(305.0, 1167.0)
const LOCATION_WEIGHTS: Vector2 = Vector2(155.0, 1632.0)
const LOCATION_COUCH: Vector2 = Vector2(975.0, 1150.0)
const LOCATION_BATHROOM: Vector2 = Vector2(1752.0, 485.0)
const LOCATION_WASHING_MACHINE: Vector2 = Vector2(1654.0, 959.0)
const LOCATION_PING_PONG: Vector2 = Vector2(2006.0, 1248.0)
const LOCATION_DOWNSTAIRS: Vector2 = Vector2(1283.0, 1690.0)
const LOCATION_EXIT: Vector2 = Vector2(117.0, 1908.0)

var velocity: Vector2 = Vector2(0, 0)

func _process(delta: float) -> void:
	if pathing:
		var goal: Vector2 = nav_agent.get_next_path_position()
		velocity += (goal - global_position).normalized() * delta * 10
	velocity *= exp(-delta * 2)
	global_position += velocity


func _on_navigation_agent_2d_navigation_finished() -> void:
	pathing = false
