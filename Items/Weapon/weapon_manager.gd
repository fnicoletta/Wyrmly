class_name WeaponManager
extends Node3D


@export var allow_attack: bool = true
@export var current_weapon: WeaponResource
@export var player: Player
@export var bullet_cast: RayCast3D
@export var view_model_container: Node3D
@export var world_model_container: Node3D

var current_weapon_view_model: Node3D
var current_weapon_world_model: Node3D
var last_played_anim: String = ""
var current_anim_finished_callback
var current_anim_cancelled_callback

@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer


func _ready() -> void:
	update_weapon_model()


func _process(delta: float) -> void:
	if current_weapon:
		current_weapon.on_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_weapon and is_inside_tree():
		if event.is_action_pressed("primary") and allow_attack:
			current_weapon.trigger_down = true
		elif event.is_action_released("primary"):
			current_weapon.trigger_down = false
		
		if event.is_action_pressed("reload"):
			current_weapon.reload_pressed()


func update_weapon_model() -> void:
	if current_weapon != null:
		current_weapon.weapon_manager = self
		if view_model_container and current_weapon.view_model:
			current_weapon_view_model = current_weapon.view_model.instantiate()
			view_model_container.add_child(current_weapon_view_model)
			current_weapon_view_model.position = current_weapon.view_model_position
			current_weapon_view_model.rotation = current_weapon.view_model_rotation
			current_weapon_view_model.scale = current_weapon.view_model_scale
			if current_weapon_view_model.get_node_or_null("AnimationPlayer"):
				current_weapon_view_model.get_node_or_null("AnimationPlayer").connect("current_animation_changed", current_anim_changed)
		if world_model_container and current_weapon.world_model:
			current_weapon_world_model = current_weapon.world_model.instantiate()
			world_model_container.add_child(current_weapon_world_model)
			current_weapon_world_model.position = current_weapon.world_model_position
			current_weapon_world_model.rotation = current_weapon.world_model_rotation
			current_weapon_world_model.scale = current_weapon.world_model_scale
		current_weapon.is_equipped = true
		if player.has_method("update_view_and_world_model_masks"):
				player.update_view_and_world_model_masks()


func play_sound(sound: AudioStream) -> void:
	if sound:
		if audio_stream_player.stream != sound:
			audio_stream_player.stream = sound
		audio_stream_player.play()


func stop_sound():
	audio_stream_player.stop()


func play_anim(name: String, finished_callback = null, cancelled_callback = null) -> void:
	var anim_player: AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	
	if last_played_anim and get_anim() == last_played_anim and current_anim_cancelled_callback is Callable:
		current_anim_cancelled_callback.call()
	
	if not anim_player or not anim_player.has_animation(name):
		if finished_callback is Callable:
			finished_callback.call()
		return
	
	current_anim_finished_callback = finished_callback
	current_anim_cancelled_callback = cancelled_callback
	last_played_anim = name
	anim_player.clear_queue()
	anim_player.seek(0.0)
	anim_player.play(name)


func get_anim() -> String:
	var anim_player: AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	if not anim_player: return ""
	return anim_player.current_animation


func current_anim_changed(new_anim: StringName) -> void:
	var anim_player: AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	if new_anim != last_played_anim and current_anim_finished_callback is Callable:
		current_anim_finished_callback.call()
	last_played_anim = anim_player.current_animation
	if last_played_anim != anim_player.current_animation:
		current_anim_finished_callback = null
		current_anim_cancelled_callback = null


func queue_anim(name: String):
	var anim_player: AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	if not anim_player: return
	anim_player.queue(name)
