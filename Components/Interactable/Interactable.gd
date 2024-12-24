extends CollisionObject3D
class_name Interactable


signal interacted(body)


@export var prompt_message: String = "Yo, it's the fuckin %INTERACTABLE_OBJECT% from Mario"
@export var prompt_input: String = "interact"
@export var show_key: bool = false


func get_prompt() -> String:
	if not show_key:
		return prompt_message
	var key_name = ""
	for action in InputMap.action_get_events(prompt_input):
		if action is InputEventKey:
			key_name = action.as_text_physical_keycode()
			break
	return prompt_message + "\n[" + key_name + "]"


func interact(owner: Player) -> void:
	interacted.emit(owner)
