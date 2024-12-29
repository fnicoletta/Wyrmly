@tool
extends Node3D


@export var weapon_type: Weapon:
	set(value):
		weapon_type = value
		if Engine.is_editor_hint():
			load_weapon()
@export var sway_noise: NoiseTexture2D
@export var sway_speed: float = 1.2
@export var reset: bool = false:
	set(value):
		reset = value
		if Engine.is_editor_hint():
			load_weapon()
 
var _mouse_movement: Vector2

@onready var weapon_mesh: MeshInstance3D = $WeaponMesh
@onready var player: Player = $"../../../.."


func _ready() -> void:
	await owner.ready
	load_weapon()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_movement = event.relative


func _physics_process(delta: float) -> void:
	sway_weapon(delta)


func load_weapon() -> void:
	weapon_mesh.mesh = weapon_type.mesh
	position = weapon_type.position
	rotation_degrees = weapon_type.rotation
	scale = weapon_type.scale


func sway_weapon(delta: float) -> void:
	if not weapon_type:
		return
	_mouse_movement = _mouse_movement.clamp(weapon_type.sway_min, weapon_type.sway_max)
	position.x = lerpf(position.x, weapon_type.position.x - (_mouse_movement.x * weapon_type.sway_amount_position) * delta, weapon_type.sway_speed_position)
	position.y = lerpf(position.y, weapon_type.position.y - (_mouse_movement.y * weapon_type.sway_amount_position) * delta, weapon_type.sway_speed_position)
	rotation_degrees.y = lerpf(rotation_degrees.y, weapon_type.rotation.y - (_mouse_movement.x * weapon_type.sway_amount_position) * delta, weapon_type.sway_speed_position)
	rotation_degrees.x = lerpf(rotation_degrees.x, weapon_type.rotation.x - (_mouse_movement.y * weapon_type.sway_amount_position) * delta, weapon_type.sway_speed_position)
