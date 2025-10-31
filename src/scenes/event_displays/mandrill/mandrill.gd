@tool
@icon("res://src/scenes/event_displays/mandrill/assets/mandrill_icon.png")
class_name Mandrill extends BallThrower
## HOY

const SPINNING_BALL_SPRITE := \
	preload("res://src/scenes/event_displays/mandrill/assets/spinning_ball.tres")
const BALL_SPRITE := \
	preload('res://src/scenes/event_displays/mandrill/assets/normal_ball.tres')
const THROW_ANIMS:Array[String] = [
	"Standard/ThrowStartUp", 
	"Standard/Hoo1", 
	"Standard/Hoo2", 
	"Standard/HOY"
	]
enum BopAnims {
	CHILL = 1,
	EXCITED = 2,
	DOUBLE_FIST_PUMP = 3
	}

@onready var sfx:Array[AudioStreamPlayer] = [$ThrowStartUp, $Hoo1, $Hoo2, $HOY]

var current_bop := BopAnims.CHILL:
	set(val):
		_switching_bops = current_bop and (val != current_bop)
		current_bop = val
		if current_bop == BopAnims.DOUBLE_FIST_PUMP:
			num_beats_before_idle = 99
		else:
			num_beats_before_idle = 2
#var _bopping:bool = false
var _switching_bops:bool = false


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                             OVERRIDES                                           #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

func _ready() -> void:
	super()
	bop_anim.animation_finished.connect(_on_bop_end)


func bop() -> void:
	bop_anim.play("Bop%s" % current_bop)


func can_bop() -> bool:
	#if ball_path.get_children().size() >= 1:
		#return false
	return _bopping && (!anim.is_playing() or boppable_anims.has(anim.current_animation))


## connected to Signals => time_signature_changed and bpm_changed
func _on_meta_config() -> void:
	pass


## Warnings that will go to Output to tell you when something isn't set up right
func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray
	# TODO append warnings here
	return warnings


func _on_song_started() -> void:
	#var _beat_dur:float = Song.beat_to_sec(Song.BEATS.quarter)
	#if bop_anim:
		#var anim_dur:float = bop_anim.get_animation('Bop1').length
		#_anim_speed_scales['bop'] = _beat_dur / anim_dur
	#
	_bopping = true
	bop()


func _on_song_ended() -> void:
	_bopping = false
	super()


func _on_beat() -> void:
	if can_bop(): bop()


func _on_bop_end(_a:StringName) -> void:
	if current_bop != BopAnims.DOUBLE_FIST_PUMP:
		anim.play('Standard/Idle')


## Called when using 'add_event'
## NOTE remember to handle special_keys
func _on_event_start(ev:RhythmInputEvent) -> void:
	var step_time:float = ev.build_up / 3.0
	
	for i in range(len(THROW_ANIMS)):
		var anim_name = THROW_ANIMS[i]
		var sfx_path = sfx[i]
		#var speed_scale:float
		#if 'HOY' in anim_name:
			#speed_scale = 2.13
		#else:
			#speed_scale = anim.get_animation(anim_name).length / step_time
		#
		##if not _anim_speed_scales.has(anim_name):
			##_anim_speed_scales[anim_name] = _timescale_anim(anim_name, step_time)
		##_timescale_anim(anim_name, step_time)
		#
		#anim.speed_scale = 2.13 if 'HOY' in anim_name else _anim_speed_scales[anim_name]
		anim.play(anim_name)
		sfx_path.play()
		
		if anim_name == "Standard/Hoo2":
			ball_thrown.emit()
		if anim_name == "Standard/HOY":
			break
		
		await get_tree().create_timer(step_time).timeout
	
	var ball_pf := _add_ball()
	var tween := create_tween()
	tween.tween_property(ball_pf, 'progress_ratio', 1, 0.08)
	tween.tween_callback(ball_pf.queue_free)


## Connected to ev.missed
func _on_event_missed(_ev:RhythmInputEvent) -> void:
	pass


## Connected to ev.activated
func _on_event_hit(_ev:RhythmInputEvent, score:Utils.SCORES, _offset:float) -> void:
	## Removing in-flight ball
	#var balls:Array = ball_path.get_children()
	#if ev.note_key == 'D' and !balls.is_empty():
		## Sometimes, when there are a lot of events, an activation
		## might trigger so close to when the ball/shadow is moved to
		## the miss path that this would free the wrong ball without the 
		## progress ratio check.
		#var ball:PathFollow2D = balls.front()
		#if ball.progress_ratio >= 0.2: ball.queue_free()
	
	if score == Utils.SCORES.MEH: return
	$HOYIMPACT.play()

#
#func _on_ball_throw_finished(
	#ball_pf:BallFollow, 
	#tween:Tween=null, 
	#shadow_pf:BallFollow=null
#) -> bool:
	#if !super(ball_pf, tween, shadow_pf): return false
	#
	#print('here')
	#
	## Adding ball to miss path
	## NOTE PathFollow2D progress can only be changed while in the scene
	#ball_pf.hide()
	#ball_pf.progress_ratio = 0.0
	#ball_pf.ball_sprite.texture = SPINNING_BALL_SPRITE
	#ball_path.remove_child(ball_pf)
	#miss_path.add_child(ball_pf)
	#ball_pf.show()
	#
	## Adding shadow to miss path
	#var shadow := BALL_SHADOW_SCENE.instantiate()
	#miss_shadow_path.add_child(shadow)
	#
	## Traveling path
	#var tw := create_tween()
	#var time := Song.beat_to_sec(miss_path_time) / 2.0
	#
	## Catches late event activations
	#var lambda := func(_ev, _s, _ofs): 
		#if tw.is_running(): tw.kill()
		#if is_instance_valid(ball_pf): ball_pf.queue_free()
		#if is_instance_valid(shadow_pf): shadow_pf.queue_free()
	#Signals.event_activated.connect(lambda, CONNECT_ONE_SHOT)
	#
	#var curve_length:float = miss_path.curve.get_baked_length()
	#
	## Bouncing into Golfer's leg
	## Getting progress ratio diff to 3rd point since that's the one that
	## hits the Golfer's leg; i.e., where the tween changes a bit
	#var init_offset:float = \
		#miss_path.curve.get_closest_offset(miss_path.curve.get_point_position(2))
	#var mid_pratio:float = (init_offset / curve_length)
	#tw.tween_property(ball_pf, 'progress_ratio', mid_pratio, time*0.9) \
		#.set_ease(Tween.EASE_OUT_IN).set_trans(Tween.TRANS_QUAD)
	#tw.parallel().tween_property(shadow, 'progress_ratio', mid_pratio, time*0.9) \
		#.set_ease(Tween.EASE_OUT_IN).set_trans(Tween.TRANS_QUAD)
	#get_tree().create_timer(time*0.9).timeout.connect(func():
		#ball_pf.ball_sprite.texture = BALL_SPRITE
		#)
	#
	## Rolling off-screen
	## Getting progress ratio of the split proportional to the remaining progress
	#var p1_offset:float = \
		#miss_path.curve.get_closest_offset(miss_path.curve.get_point_position(2))
	#var p1_ratio:float = ( p1_offset / curve_length ) / (init_offset) / curve_length
	#
	## Using all that to split tween time
	#var p1_time:float = time * p1_ratio
	#var p2_time:float = time - p1_time
	#
	## Part 1: Slowly bouncing off Golfer
	#tw.tween_property(ball_pf, 'progress_ratio', 1, p1_time) \
		#.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	#tw.parallel().tween_property(shadow, 'progress_ratio', 1, p1_time) \
		#.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	#
	#print('here2')
	#
	## FIXME this doesn't roll down as smoothly as I'd like
	## Part 2: Rolling off-screen
	#tw.tween_property(ball_pf, 'progress_ratio', 1, p2_time)
	#tw.parallel().tween_property(shadow_pf, 'progress_ratio', 1, p2_time)
	#tw.tween_callback(ball_pf.queue_free)
	#tw.tween_callback(shadow.queue_free)
	#tw.tween_callback(Signals.event_activated.disconnect.bind(lambda))
	#return true
