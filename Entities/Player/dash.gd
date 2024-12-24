extends State


var _dash_direction: Vector3 = Vector3.ZERO

@onready var state_machine: Node = $".."
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown


func enter() -> void:
	player.can_dash = false
	dash_cooldown.start()
	dash_timer.start()
	
	# Set dash direction to the current movement direction or forward if stationary
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	if input_dir == Vector2.ZERO:
		_dash_direction = -player.transform.basis.z.normalized()  # Dash forward
	else:
		_dash_direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
	player.velocity = _dash_direction * player.dash_speed


func physics_process(delta: float) -> void:
	player.velocity = _dash_direction * player.dash_speed



func handle_input(event: InputEvent) -> void:
	pass


func handle_transition() -> void:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
		state_machine.transition_to("Move")
		return
	state_machine.transition_to("Idle")


func _on_dash_timer_timeout() -> void:
	handle_transition()


func _on_dash_cooldown_timeout() -> void:
	player.can_dash = true
