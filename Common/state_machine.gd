class_name StateMachine
extends Node


@export var initial_state: NodePath

var current_state = null


func _ready():
	current_state = get_node(initial_state)
	current_state.enter()


func _process(delta: float):
	if current_state and current_state.has_method("process"):
		current_state.process(delta)


func _physics_process(delta: float):
	if current_state and current_state.has_method("physics_process"):
		current_state.physics_process(delta)


func _input(event):
	if current_state and current_state.has_method("handle_input"):
		current_state.handle_input(event)


func transition_to(state_name: String, has_permission: bool = true):
	if not has_permission:
		return
	if current_state:
		current_state.exit()
	current_state = get_node(state_name)
	current_state.enter()
