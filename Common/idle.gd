extends State


@onready var state_machine: Node = $".."
# @onready var animation_handler: Node = $"../../AnimationHandler"


func enter():
	pass
	# animation_handler.travel("Idle")


func physics_process(delta: float) -> void:
	if not player.velocity.is_zero_approx():
		player.velocity.x = move_toward(player.velocity.x, 0.0, delta * player.ground_friction)
		player.velocity.z = move_toward(player.velocity.z, 0.0, delta * player.ground_friction)


func handle_input(event: InputEvent) -> void:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
		state_machine.transition_to("Move")
		return
	
	if Input.is_action_just_pressed("dash"):
		state_machine.transition_to("Dash", player.can_dash)
