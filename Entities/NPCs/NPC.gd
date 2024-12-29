class_name NPC
extends Interactable


@export var timeline: String

func _on_interacted(body: Variant) -> void:
	Dialogic.start(timeline)
