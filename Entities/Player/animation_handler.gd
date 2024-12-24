extends Node

@onready var pm_animation_tree: AnimationTree = $"../PlayerMesh/AnimationTree"
@onready var al_animation_tree: AnimationTree = $"../ArmsAndLegs/AnimationTree"
@onready var pm_playback: AnimationNodeStateMachinePlayback
@onready var al_playback: AnimationNodeStateMachinePlayback


func _ready():
	# Safely get AnimationNodeStateMachinePlayback
	if pm_animation_tree:
		pm_playback = pm_animation_tree["parameters/playback"]
	else:
		push_error("PlayerMesh AnimationTree not found or improperly configured!")
	
	if al_animation_tree:
		al_playback = al_animation_tree["parameters/playback"]
	else:
		push_error("ArmsAndLegs AnimationTree not found or improperly configured!")


func travel(anim_name: String) -> void:
	# Ensure both playbacks exist before calling travel
	if pm_playback:
		pm_playback.travel(anim_name)
	else:
		push_error("pm_playback is not initialized!")
	
	if al_playback:
		al_playback.travel(anim_name)
	else:
		push_error("al_playback is not initialized!")
