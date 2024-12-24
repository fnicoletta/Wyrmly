extends RayCast3D


@onready var interact_reticle: TextureRect = %InteractReticle
@onready var interact_prompt: Label = $InteractPrompt


func _physics_process(delta: float) -> void:
	if is_colliding():
		var collider = get_collider()
		
		if collider is Interactable:
			interact_reticle.visible = true
			interact_prompt.text = collider.get_prompt()
			
			if Input.is_action_just_pressed(collider.prompt_input):
				collider.interact(owner)
	else:
		interact_reticle.visible = false
		interact_prompt.text = ""
