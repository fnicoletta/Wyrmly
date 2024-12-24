extends Node


signal on_trigger_player_spawn(position: Vector3)

var spawn_door_tag: String

const wyrmly_hq: PackedScene = preload("res://Levels/WyrmlyHQ/wyrmly_hq.tscn")
const hub: PackedScene = preload("res://Levels/Hub/hub.tscn")


func go_to_level(level_name: String, destination_tag: String) -> void:
	var level_scene: PackedScene
	
	match(level_name):
		"hq":
			level_scene = wyrmly_hq
		"hub":
			level_scene = hub
			
	if level_scene != null:
		TransitionScreen.fade_out()
		await TransitionScreen.on_transition_finished
		
		# Store the spawn tag
		spawn_door_tag = destination_tag
		
		# Change the scene
		var result = get_tree().change_scene_to_packed(level_scene)
		if result != OK:
			push_error("Failed to load level scene. Error code: %s" % result)
	else:
		push_error("Invalid level name: %s" % level_name)


func trigger_player_spawn(position: Vector3) -> void:
	on_trigger_player_spawn.emit(position)
