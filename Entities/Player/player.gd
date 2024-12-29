class_name Player
extends CharacterBody3D


enum CameraStyle {
	FIRST_PERSON, THIRD_PERSON_VERTICAL_LOOK, THIRD_PERSON_FREE_LOOK
}

@export_group("Ground Movement")
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.0
@export var jump_velocity: float = 6.0
@export var auto_bhop: bool = true
@export_subgroup("Ground Stats")
@export var ground_acceleration: float = 14.0
@export var ground_deceleration: float = 10.0
@export var ground_friction: float = 6.0
@export_group("Air Movement")
@export var air_cap: float = 0.85
@export var air_acceleration: float = 800.0
@export var air_move_speed: float = 500.0
@export_group("Look")
@export var mouse_sensitivity: float = 0.006
@export var controller_sensitivity: float = 0.05
@export var smooth_speed: float = 20.0
@export var camera_style: CameraStyle = CameraStyle.FIRST_PERSON:
	set(v):
		camera_style = v
		_update_camera()

var _wish_direction: Vector3 = Vector3.ZERO
var _headbob_time: float = 0.0
var _cur_controller_look: Vector2 = Vector2()
var _cam_aligned_wish_direction: Vector3 = Vector3.ZERO
var _no_clip_speed_multiplier: float = 3.0
var _is_no_clip: bool = false
var _has_snapped_to_stairs_last_frame: bool = false
var _last_frame_was_on_floor: int = -INF
var _saved_camera_global_position = null
var _is_crouched: bool = false

const HEADBOB_MOVE_AMOUNT: float = 0.06
const HEADBOB_FREQUENCY: float = 2.4
const MAX_STEP_HEIGHT: float = 0.5
const CROUCH_TRANSLATE: float = 0.7
const CROUCH_JUMP_ADD = CROUCH_TRANSLATE * 0.9
const WORLD_MODEL_LAYER = 2
const VIEW_MODEL_LAYER = 9

@onready var ui: Control = $UI
@onready var camera: Camera3D = %Camera3D
@onready var third_person_camera: Camera3D = %ThirdPersonCamera
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var stairs_ahead_cast: RayCast3D = %StairsAheadCast
@onready var stairs_below_cast: RayCast3D = %StairsBelowCast
@onready var camera_smooth: Node3D = %CameraSmooth
@onready var original_capsule_height: float = $CollisionShape3D.shape.height
@onready var head: Node3D = %Head
@onready var third_person_yaw: Node3D = %ThirdPersonOrbitCamYaw
@onready var third_person_pitch: Node3D = %ThirdPersonOrbitCamPitch
@onready var view_model: Node3D = %ViewModel
@onready var world_model: Node3D = %WorldModel


func _ready() -> void:
	NavigationManager.on_trigger_player_spawn.connect(_on_spawn)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_view_and_world_model_masks()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseMotion:
		_handle_camera_input(event.relative)
		
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_no_clip_speed_multiplier = min(100.0, _no_clip_speed_multiplier * 1.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_no_clip_speed_multiplier = min(100.0, _no_clip_speed_multiplier * 0.9)
			

func _process(delta: float) -> void:
	_handle_controller_look_input(delta)
	if camera_style == CameraStyle.THIRD_PERSON_FREE_LOOK and _wish_direction.length():
		var add_rotation_y = (-self.global_transform.basis.z).signed_angle_to(_wish_direction.normalized(), Vector3.UP)
		var rotate_towards = lerp_angle(self.global_rotation.y, self.global_rotation.y + add_rotation_y, max(0.1, abs(add_rotation_y/TAU))) - self.global_rotation.y
		self.rotation.y += rotate_towards
		third_person_yaw.rotation.y -= rotate_towards


func _physics_process(delta: float) -> void:
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	
	_update_camera()
	
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back").normalized()
	_wish_direction = self.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	_cam_aligned_wish_direction = get_active_camera().global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if camera_style == CameraStyle.THIRD_PERSON_FREE_LOOK:
		_wish_direction = third_person_yaw.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	
	_handle_crouch(delta)
	
	if not _handle_no_clip(delta):
		if is_on_floor() or _has_snapped_to_stairs_last_frame:
			if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
				self.velocity.y = jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)

		if not _snap_up_stairs_check(delta):
			_push_away_rigid_bodies()
			move_and_slide()
			_snap_down_to_stairs_check()
	
	_slide_camera_smooth_back_to_origin(delta)


func update_view_and_world_model_masks():
	for child in %WorldModel.find_children("*", "VisualInstance3D", true, false):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(WORLD_MODEL_LAYER, true)
	for child in %ViewModel.find_children("*", "VisualInstance3D", true, false):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(VIEW_MODEL_LAYER, true)
		if child is GeometryInstance3D:
			child.cast_shadow = false
	%Camera3D.set_cull_mask_value(WORLD_MODEL_LAYER, false)
	%ThirdPersonCamera.set_cull_mask_value(VIEW_MODEL_LAYER, false)


func get_move_speed() -> float:
	if _is_crouched:
		return walk_speed * 0.8
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed


func clip_velocity(normal: Vector3, overbounce: float, delta: float) -> void:
	var backoff: float = self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change: Vector3 = normal * backoff
	self.velocity -= change
	
	var adjust: float = self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust


func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle


func get_active_camera() -> Camera3D:
	if camera_style == CameraStyle.FIRST_PERSON:
		return camera
	else:
		return third_person_camera
		
		
func _update_camera() -> void:
	if not is_inside_tree():
		return
	var cameras = [camera, third_person_camera]
	if not cameras.any(func(c: Camera3D): return c.current):
		return
	get_active_camera().current = true


func _handle_crouch(delta: float) -> void:
	var was_crouched_last_frame: bool = _is_crouched
	if Input.is_action_pressed("crouch"):
		_is_crouched = true
	elif _is_crouched and not self.test_move(self.transform, Vector3(0, CROUCH_TRANSLATE, 0)):
		_is_crouched = false
	
	var translate_y_if_possible: float = 0.0
	if was_crouched_last_frame != _is_crouched and not is_on_floor() and not _has_snapped_to_stairs_last_frame:
		translate_y_if_possible = CROUCH_JUMP_ADD if _is_crouched else -CROUCH_JUMP_ADD
		
	if translate_y_if_possible != 0.0:
		var result = KinematicCollision3D.new()
		self.test_move(self.transform, Vector3(0, translate_y_if_possible, 0), result)
		self.position.y += result.get_travel().y
		head.position.y -= result.get_travel().y
		head.position.y = clampf(head.position.y, -CROUCH_TRANSLATE, 0)
	
	head.position.y = move_toward(head.position.y, -CROUCH_TRANSLATE if _is_crouched else 0, 7.0 * delta)
	collision_shape.shape.height = original_capsule_height - CROUCH_TRANSLATE if _is_crouched else original_capsule_height
	collision_shape.position.y = collision_shape.shape.height / 2


func _run_body_test_motion(from: Transform3D, motion: Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)


func _headbob_effect(delta: float) -> void:
	_headbob_time += delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(_headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(_headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)


func _save_camera_position_for_smoothing() -> void:
	if _saved_camera_global_position == null:
		_saved_camera_global_position = camera_smooth.global_position


func _slide_camera_smooth_back_to_origin(delta: float) -> void:
	if _saved_camera_global_position == null: return
	camera_smooth.global_position.y = _saved_camera_global_position.y
	camera_smooth.position.y = clampf(camera_smooth.position.y, -0.7, 0.7)
	var move_amount: float = max(self.velocity.length() * delta, walk_speed / 2 * delta)
	camera_smooth.position.y = move_toward(camera_smooth.position.y, 0.0, move_amount)
	_saved_camera_global_position = camera_smooth.global_position
	if camera_smooth.position.y == 0:
		_saved_camera_global_position = null


func _push_away_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir = -c.get_normal()
			# How much velocity the object needs to increase to match player velocity in the push direction
			var velocity_diff_in_push_dir = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			# Only count velocity towards push dir, away from character
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			# Objects with more mass than us should be harder to push. But doesn't really make sense to push faster than we are going
			const MY_APPROX_MASS_KG = 80.0
			var mass_ratio = min(1., MY_APPROX_MASS_KG / c.get_collider().mass)
			# Optional add: Don't push object at all if it's 4x heavier or more
			if mass_ratio < 0.25:
				continue
			# Don't push object from above/below
			push_dir.y = 0
			# 5.0 is a magic number, adjust to your needs
			var push_force = mass_ratio * 5.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)



func _snap_down_to_stairs_check() -> void:
	var did_snap: bool = false
	var is_floor_below: bool = stairs_below_cast.is_colliding() and not is_surface_too_steep(stairs_below_cast.get_collision_normal())
	var was_on_floor_last_frame: bool = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	
	if not is_on_floor() and velocity.y < 0 and (was_on_floor_last_frame or _has_snapped_to_stairs_last_frame) and is_floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			_save_camera_position_for_smoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_has_snapped_to_stairs_last_frame = did_snap


func _snap_up_stairs_check(delta: float) -> bool:
	if not is_on_floor() and not _has_snapped_to_stairs_last_frame: return false
	if self.velocity.y > 0 or (self.velocity * Vector3(1, 0, 1)).length() == 0: return false
	var expected_move_motion: Vector3 = self.velocity * Vector3(1, 0, 1) * delta
	var step_position_with_clearance: Transform3D = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	var down_check_result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	
	if (_run_body_test_motion(step_position_with_clearance, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height: float = ((step_position_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_collision_point() - self.global_position).y > MAX_STEP_HEIGHT: return false
		stairs_ahead_cast.global_position = down_check_result.get_collision_point() + Vector3(0, MAX_STEP_HEIGHT, 0) + expected_move_motion.normalized() * 0.1
		stairs_ahead_cast.force_raycast_update()
		if stairs_ahead_cast.is_colliding() and not is_surface_too_steep(stairs_ahead_cast.get_collision_normal()):
			_save_camera_position_for_smoothing()
			self.global_position = step_position_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_has_snapped_to_stairs_last_frame = true
			return true
	return false


func _handle_no_clip(delta: float) -> bool:
	if Input.is_action_just_pressed("_no_clip") and OS.has_feature("debug"):
		_is_no_clip = !_is_no_clip
	
	collision_shape.disabled = _is_no_clip
	
	if not _is_no_clip: return false
	
	var speed = get_move_speed() * _no_clip_speed_multiplier
	if Input.is_action_pressed("sprint"): speed *= 3
	
	self.velocity = _cam_aligned_wish_direction * speed
	global_position += self.velocity * delta
	
	return true



func _handle_air_physics(delta: float) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	var current_speed_in_wish_direction = self.velocity.dot(_wish_direction)
	var capped_speed = min((air_move_speed * _wish_direction).length(), air_cap)
	var add_speed_till_cap = capped_speed - current_speed_in_wish_direction
	
	if add_speed_till_cap > 0:
		var acceleration_speed = air_acceleration * air_move_speed * delta
		acceleration_speed = min(acceleration_speed, add_speed_till_cap)
		self.velocity += acceleration_speed * _wish_direction
		
	if is_on_wall():
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			
		clip_velocity(get_wall_normal(), 1, delta)


func _handle_ground_physics(delta: float) -> void:
	var current_speed_in_wish_direction = self.velocity.dot(_wish_direction)
	var add_speed_till_cap = get_move_speed() - current_speed_in_wish_direction
	
	if add_speed_till_cap > 0:
		var acceleration_speed = ground_acceleration * get_move_speed() * delta
		acceleration_speed = min(ground_acceleration, add_speed_till_cap)
		self.velocity += acceleration_speed * _wish_direction
		
	var control = max(self.velocity.length(), ground_deceleration)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	_headbob_effect(delta)


func _handle_camera_input(mouse_motion: Vector2):
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	
	if camera_style == CameraStyle.THIRD_PERSON_FREE_LOOK:
		third_person_yaw.rotate_y(-mouse_motion.x * mouse_sensitivity)
	else:
		third_person_yaw.rotation.y = 0.0
		rotate_y(-mouse_motion.x * mouse_sensitivity)
		
	camera.rotate_x(-mouse_motion.y * mouse_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	third_person_pitch.rotate_x(-mouse_motion.y * mouse_sensitivity)
	third_person_pitch.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	


func _handle_controller_look_input(delta: float) -> void:
	var target_look = Input.get_vector("look_left", "look_right", "look_up", "look_down").normalized()
	_cur_controller_look = target_look
	
	if target_look.length() < _cur_controller_look.length():
		_cur_controller_look = target_look
	else:
		_cur_controller_look = _cur_controller_look.lerp(target_look, 5.0 * delta)
		
	if camera_style == CameraStyle.THIRD_PERSON_VERTICAL_LOOK or camera_style == CameraStyle.FIRST_PERSON:
		rotate_y(-_cur_controller_look.x * controller_sensitivity)
	else:
		third_person_yaw.rotate_y(-_cur_controller_look.x * controller_sensitivity)
	
	camera.rotate_x(-_cur_controller_look.y * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	third_person_pitch.rotation.x = camera.rotation.x 


func _on_tower_door_interacted(body: Variant) -> void:
	ui.modulate = "#000"
	position = Vector3.ZERO


func _on_spawn(position: Vector3):
	global_position = position
