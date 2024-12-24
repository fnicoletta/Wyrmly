extends Node3D
class_name Level


func _ready() -> void:
	if NavigationManager.spawn_door_tag != null and NavigationManager.spawn_door_tag != "":
		_on_level_spawn(NavigationManager.spawn_door_tag)


func _on_level_spawn(destination_tag: String) -> void:
	var door_path = "Doors/Door_" + destination_tag
	if has_node(door_path):
		var door = get_node(door_path) as Door
		if door != null and door.spawn != null:
			NavigationManager.trigger_player_spawn(door.spawn.global_position)
		else:
			push_error("Door node or spawn point is invalid at path: " + door_path)
	else:
		push_error("No door found with path: " + door_path)
