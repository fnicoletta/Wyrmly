extends CanvasLayer


signal on_transition_finished


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	color_rect.visible = false
	animation_player.animation_finished.connect(_on_animation_finish)


func fade_out() -> void:
	color_rect.visible = true
	animation_player.play("FadeToBlack")


func fade_in() -> void:
	color_rect.visible = true
	animation_player.play("FadeIn")


func _on_animation_finish(anim_name: String) -> void:
	if anim_name == "FadeToBlack":
		on_transition_finished.emit()
		animation_player.play("FadeIn")
	elif anim_name == "FadeIn":
		color_rect.visible = false
