extends Interactable
class_name Door

@export var destination_level: String
@export var destination_door_tag: String

@onready var spawn = $Spawn


func _on_interacted(body: Variant) -> void:
	if body is Player:
		NavigationManager.go_to_level(destination_level, destination_door_tag)
