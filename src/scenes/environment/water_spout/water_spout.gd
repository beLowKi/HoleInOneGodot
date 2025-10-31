class_name WaterSpout extends Node2D
## Class for the water spouts in Hole in One.

const FPS:float = 10.0
@onready var anim:AnimationPlayer = $AnimationPlayer

## Does the spout then idle sequence.
func spout() -> void:
	# Configures and starts gifs
	for c in get_children(true):
		if c is AnimatedSprite2D:
			c.sprite_frames.set_animation_speed('default', FPS)
			if !c.is_playing(): c.play('default')
	
	anim.play('Gush')
	await anim.animation_finished
	anim.play('Idle')

## Falls back into the water
func retract() -> void:
	anim.play_backwards("Gush")
	anim.animation_finished.connect(func(_a): hide(), CONNECT_ONE_SHOT)
