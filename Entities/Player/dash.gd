extends State


var _dash_direction: Vector3 = Vector3.ZERO
var _fov_target: float = 0.0
var _fov_lerp_speed: float = 5.0

@onready var state_machine: Node = $".."
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var whoosh: AudioStreamPlayer = $"../../Audio/Whoosh"
@onready var camera_3d: Camera3D = $"../../Head/Camera3D"


func enter() -> void:
	_fov_target = camera_3d.fov + 10
	whoosh.play(0.22)
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
	camera_3d.fov = lerpf(camera_3d.fov, _fov_target, _fov_lerp_speed * delta)


func handle_input(event: InputEvent) -> void:
	pass


func handle_transition() -> void:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
		state_machine.transition_to("Move")
		return
	state_machine.transition_to("Idle")


func exit() -> void:
	pass


func _on_dash_timer_timeout() -> void:
	_fov_target = camera_3d.fov - 10
	await get_tree().create_timer(0.2).timeout
	handle_transition()


func _on_dash_cooldown_timeout() -> void:
	player.can_dash = true
