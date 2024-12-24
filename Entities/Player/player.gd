class_name Player
extends CharacterBody3D


@export_group("Movement")
@export var walk_speed: float = 5.0
@export var run_multiplier: float = 1.5
@export var dash_speed: float = 20.0
@export var ground_friction: float = 10
@export_group("Mouse")
@export var mouse_sensitivity: float = 0.2
@export var smooth_speed: float = 20.0

var run_speed: float = walk_speed * run_multiplier
var can_dash: bool = true
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var ui: Control = $UI


func _ready() -> void:
	NavigationManager.on_trigger_player_spawn.connect(_on_spawn)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_camera(event.relative)

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	rotation.y = lerp_angle(rotation.y, _target_yaw, smooth_speed * delta)
	camera_pivot.rotation_degrees.x = lerp(
		camera_pivot.rotation_degrees.x,
		_target_pitch,
		smooth_speed * delta
	)

	move_and_slide()


func rotate_camera(mouse_motion: Vector2):
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
		
	_target_yaw -= deg_to_rad(mouse_motion.x * mouse_sensitivity)
	_target_pitch -= -mouse_motion.y * mouse_sensitivity
	_target_pitch = clamp(_target_pitch, -89.0, 89.0)


func _on_tower_door_interacted(body: Variant) -> void:
	ui.modulate = "#000"
	
	position = Vector3.ZERO


func _on_spawn(position: Vector3):
	global_position = position
