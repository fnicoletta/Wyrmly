class_name WeaponResource
extends Resource


@export_category("Weapon Stats")
@export var damage: float = 10
@export_group("Fire Rate")
@export var auto_fire: bool = true
@export var max_fire_rate_ms: float = 50
@export_group("Ammo")
@export var current_amo: int = INF
@export var magazine_capacity: int = INF
@export var reserve_amo: int = INF
@export var max_reserve_amo: int = INF

@export_category("View Model")
@export var view_model: PackedScene # weapon + arms
@export_group("Transform")
@export var view_model_position: Vector3
@export var view_model_rotation: Vector3
@export var view_model_scale: Vector3 = Vector3(1,1,1)
@export_group("Animations")
@export var view_idle_anim: String
@export var view_equip_anim: String
@export var view_attack_anim: String
@export var view_reload_anim: String

@export_category("World Model")
@export var world_model: PackedScene # just the weapon
@export_group("Transform")
@export var world_model_position: Vector3
@export var world_model_rotation: Vector3
@export var world_model_scale: Vector3 = Vector3(1,1,1)

@export_category("Sounds")
@export var attack_sound: AudioStream
@export var reload_sound: AudioStream
@export var equip_sound: AudioStream

const RAYCAST_DISTANCE: float = 9999

# weapon logic
var weapon_manager: WeaponManager

var trigger_down: bool = false:
	set(v):
		if trigger_down != v:
			trigger_down = v
			if trigger_down:
				on_trigger_down()
			else:
				on_trigger_up()
var is_equipped: bool = false:
	set(v):
		if is_equipped != v:
			is_equipped = v
			if is_equipped:
				on_equip()
			else:
				on_unequip()
var last_fire_time: int = -9999999


func on_process(delta):
	if trigger_down and auto_fire and Time.get_ticks_msec() - last_fire_time > max_fire_rate_ms:
		if current_amo > 0:
			attack()
		else:
			reload_pressed()


func on_trigger_down() -> void:
	if Time.get_ticks_msec() - last_fire_time >= max_fire_rate_ms and current_amo > 0:
		attack()
	elif current_amo == 0:
		reload_pressed()


func on_trigger_up() -> void:
	pass


func on_equip() -> void:
	weapon_manager.play_sound(equip_sound)
	weapon_manager.play_anim(view_equip_anim)
	weapon_manager.queue_anim(view_idle_anim)


func on_unequip() -> void:
	pass


func get_amount_can_reload() -> int:
	var wish_reload = magazine_capacity - current_amo
	var can_reload = min(wish_reload, reserve_amo)
	return can_reload


func reload_pressed() -> void:
	if view_reload_anim and weapon_manager.get_anim() == view_reload_anim:
		return
	if get_amount_can_reload() <= 0:
		return
	var cancel_cb = (func():
		weapon_manager.stop_sound())
	weapon_manager.play_anim(view_reload_anim, reload, cancel_cb)
	weapon_manager.queue_anim(view_idle_anim)
	weapon_manager.play_sound(reload_sound)


func reload():
	var can_reload: int = get_amount_can_reload()
	if can_reload < 0: return
	if magazine_capacity == INF or current_amo == INF:
		current_amo = magazine_capacity
		return
	current_amo += can_reload
	reserve_amo -= can_reload


func attack():
	weapon_manager.play_anim(view_attack_anim)
	weapon_manager.play_sound(attack_sound)
	weapon_manager.queue_anim(view_idle_anim)
	
	var raycast = weapon_manager.bullet_cast
	raycast.target_position = Vector3(0, 0, -abs(RAYCAST_DISTANCE))
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var object = raycast.get_collider()
		var normal = raycast.get_collision_normal()
		var point = raycast.get_collision_point()
		if object is RigidBody3D:
			object.apply_impulse(-normal * 10.0 / object.mass, point - object.global_position)
		if object.has_method("take_damage"):
			object.take_damage(self.damage)
			
	last_fire_time = Time.get_ticks_msec()
	current_amo -= 1
