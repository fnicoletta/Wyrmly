extends RayCast3D


@onready var interact_reticle: TextureRect = %InteractReticle
@onready var interact_prompt: Label = $InteractPrompt
@onready var dialogue_reticle: TextureRect = %DialogueReticle
@onready var reticle: CenterContainer = %Reticle


func _physics_process(delta: float) -> void:
	if is_colliding():
		var collider = get_collider()
		if collider is NPC:
			dialogue_reticle.visible = true
			reticle.visible = false
		elif collider is Interactable:
			interact_reticle.visible = true
			reticle.visible = false
		interact_prompt.text = collider.get_prompt()
		if Input.is_action_just_pressed(collider.prompt_input):
			collider.interact(owner)
	else:
		interact_reticle.visible = false
		dialogue_reticle.visible = false
		reticle.visible = true
		interact_prompt.text = ""
