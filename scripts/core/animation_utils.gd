class_name AnimationUtils

static func play_if_needed(sprite: AnimatedSprite2D, anim_name: StringName, backwards: bool = false, force: bool = false) -> void:
	if not force and sprite.animation == anim_name and sprite.is_playing():
		return
	if backwards:
		sprite.play_backwards(anim_name)
	else:
		sprite.play(anim_name)
