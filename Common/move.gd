extends State


var _current_speed: float

@onready var state_machine: Node = $".."


func enter() -> void:
	_current_speed = player.walk_speed
	state_machine.playback.travel("Walk")


func physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		player.velocity.x = direction.x * _current_speed
		player.velocity.z = direction.z * _current_speed


func handle_input(event: InputEvent) -> void:
	if Input.is_action_pressed("sprint"):
		state_machine.playback.travel("Sprint")
		_current_speed = player.walk_speed * player.run_multiplier
	if Input.is_action_just_released("sprint"):
		state_machine.playback.travel("Walk")
		_current_speed = player.walk_speed
	if Input.is_action_just_pressed("dash"):
		state_machine.transition_to("Dash", player.can_dash)
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO:
		state_machine.transition_to("Idle")
