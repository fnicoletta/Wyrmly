extends State


var _current_speed: float
var _is_sprinting: bool = false

# Head bobbing variables
var head_bob_timer: float = 0.0
var bob_frequency: float = 3
var bob_amplitude: float = .6
var run_multiplier: float = 1.5
var initial_camera_position: Vector3

@onready var state_machine: Node = $".."
# @onready var animation_handler: Node = $"../../AnimationHandler"
@onready var footsteps: AudioStreamPlayer = $"../../Audio/Footsteps"
@onready var camera_3d: Camera3D = $"../../Head/Camera3D"


func enter() -> void:
	footsteps.play()
	footsteps.pitch_scale = 1.3
	_current_speed = player.walk_speed
	# animation_handler.travel("Walk")
	initial_camera_position = camera_3d.transform.origin


func exit() -> void:
	footsteps.stop()
	camera_3d.transform.origin = initial_camera_position


func physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * _current_speed
		player.velocity.z = direction.z * _current_speed
		_update_head_bob(delta)
	else:
		_reset_head_bob(delta)


func handle_input(event: InputEvent) -> void:
	if Input.is_action_pressed("sprint") and not _is_sprinting:
		start_sprinting()
	elif Input.is_action_just_released("sprint") and _is_sprinting:
		stop_sprinting()
		
	if Input.is_action_just_pressed("dash"):
		state_machine.transition_to("Dash", player.can_dash)
		
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO:
		state_machine.transition_to("Idle")


func start_sprinting() -> void:
	_is_sprinting = true
	footsteps.pitch_scale = 1.9
	_current_speed = player.walk_speed * player.run_multiplier
	bob_frequency = 4
	bob_amplitude = 0.8
	# animation_handler.travel("Sprint")


func stop_sprinting() -> void:
	_is_sprinting = false
	footsteps.pitch_scale = 1.5
	_current_speed = player.walk_speed
	bob_frequency = 3
	bob_amplitude = 0.25
	# animation_handler.travel("Walk")
	

func _update_head_bob(delta: float) -> void:
	head_bob_timer += delta * bob_frequency
	var offset_x = sin(head_bob_timer) * bob_amplitude * 0.5  # Horizontal sway
	var offset_y = abs(sin(head_bob_timer * 2)) * bob_amplitude  # Vertical bounce
	
	camera_3d.transform.origin = initial_camera_position + Vector3(offset_x, offset_y, 0)


func _reset_head_bob(delta: float) -> void:
	camera_3d.transform.origin = lerp(camera_3d.transform.origin, initial_camera_position, delta * 5.0)
