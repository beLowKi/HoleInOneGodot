@tool
@icon("res://src/scenes/event_displays/monkey/assets/monkey_icon.png")
class_name Monkey extends BallThrower

const MISS_PATH_TIME := Song.BEATS.half

@onready var oog:AudioStreamPlayer = $OOGsfx
@onready var miss_path:Path2D = $BallMissPath
@onready var shadow_path:Path2D = $ShadowPath
@onready var miss_shadow_path:Path2D = $ShadowMissPath

var spin_tween:Tween
#var _bopping:bool = false
var _spinning:bool = false


func can_bop() -> bool:
	if ball_path.get_children().size() >= 1:
		return false
	return super() && ( _bopping && !_spinning )


## Called when using 'add_event'
func _on_event_start(ev:RhythmInputEvent) -> void:
	if ev.note_key == 'D':
		var t := get_tree().create_timer(ev.build_up)
		t.connect('timeout', func():_on_mandrill_throw(ev))
		return
	
	_bopping = false
	_reset()
	
	var half_time:float = ev.build_up / 2.0
	var ball_pf := _add_ball()
	var shadow_pf := BALL_SHADOW_SCENE.instantiate()
	
	anim.play("Standard/Crouch")
	ball_pf.show()
	oog.play()
	await get_tree().create_timer(half_time).timeout
	
	anim.play("Standard/Throw")
	oog.play()
	ball_thrown.emit()
	ball_pf.show()
	shadow_path.add_child(shadow_pf)
	
	var tween := get_tree().create_tween()
	tween.tween_property(ball_pf, "progress_ratio", 1, half_time) \
		.set_ease(Tween.EASE_OUT_IN) \
		.set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(shadow_pf, "progress_ratio", 1, half_time) \
		.set_ease(Tween.EASE_OUT_IN) \
		.set_trans(Tween.TRANS_QUAD)
	
	# This can trigger before tween finishes when 
	# an event is activated a little early
	var lambda := \
		func(_ev,_s,_ofs): _on_ball_throw_finished(ball_pf, tween, shadow_pf)
	Signals.event_activated.connect(lambda, CONNECT_ONE_SHOT)
	tween.tween_callback(func():
		Signals.event_activated.disconnect(lambda)
		_on_ball_throw_finished(ball_pf, null, shadow_pf)
		)


## Connected to ev.missed
func _on_event_missed(ev:RhythmInputEvent) -> void:
	if ev.note_key == 'D': return
	
	# Adding last in-flight ball to miss path
	#var ball:PathFollow2D = ball_path.get_children().back()
	#ball.progress_ratio = 0
	#ball_path.remove_child(ball)
	#miss_path.add_child(ball)
	#
	## Traveling path
	#var tw := create_tween()
	#tw.tween_property(ball, 'progress_ratio', 1, Song.beat_to_sec(MISS_PATH_TIME)) \
		#.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	#tw.tween_callback(ball.queue_free)
	
	if 'Crouch' not in anim.current_animation: 
		anim.play('Reactions/Miss')


## Connected to ev.activated
func _on_event_hit(ev:RhythmInputEvent, score:Utils.SCORES, _offset:float) -> void:
	# Removing in-flight ball
	var balls:Array = ball_path.get_children()
	var shadows:Array = shadow_path.get_children()
	if ev.note_key == 'C' and !balls.is_empty():
		# Sometimes, when there are a lot of events, an activation
		# might trigger so close to when the ball/shadow is moved to
		# the miss path that this would free the wrong ball without the 
		# progress ratio check.
		var ball:PathFollow2D = balls.front()
		if ball.progress_ratio >= 0.6: ball.queue_free()
		if !shadows.is_empty(): 
			var shadow:PathFollow2D = shadows.front()
			if shadow.progress_ratio >= 0.6: shadow.queue_free()
	
	# Doesn't interupt spins
	if 'Spin' in anim.current_animation or 'Crouch' in anim.current_animation:
		return
	
	var anim_name:String
	match score:
		Utils.SCORES.PERFECT, Utils.SCORES.GREAT:
			anim_name = 'Reactions/Hit'
		Utils.SCORES.MEH:
			anim_name = 'Reactions/Miss'
		_:
			return
	
	# this is ugly ik and it doesn't work for the very first reaction
	# that could be a happy accident because the first ev in Hole in One also has the monkey looking
	# back at the golfer sooner than usual
	num_beats_before_idle = 3
	
	# anim speed scale is defaulted to a quarter note if flight time is 0 -> meaning that
	# the reaction happens before the flight path can calculate flight time
	# FIXME this could use a signal to fix this
	if not _anim_speed_scales.has(anim_name):
		var flight_time := golfer.get_flight_time()
		var anim_time:float = flight_time / 2.0 if flight_time > 0.0 else \
			Song.beat_to_sec(Song.BEATS.quarter)
		
		_anim_speed_scales[anim_name] = _timescale_anim(anim_name, anim_time)
	
	anim.play(anim_name, -1, _anim_speed_scales[anim_name])
	
	var wait_time:float = Song.beat_to_sec(Song.BEATS.quarter, true)
	get_tree().create_timer(wait_time).connect('timeout', _post_hit_pog)


func _on_song_started() -> void:
	super()
	_bopping = true
	bop()


func _on_song_ended() -> void:
	_bopping = false
	super()


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                      MONKEY FUNCTIONS                                           #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

func _reset() -> void:
	if spin_tween and spin_tween.is_running():
		spin_tween.kill()
		anim.speed_scale = 1
	num_beats_before_idle = 2
	anim.stop()
	#anim.speed_scale = 1


func _on_mandrill_throw(ev:RhythmInputEvent) -> void:
	if 'Crouch' in anim.current_animation:
		return
	
	_spinning = true
	num_beats_before_idle = 99
	#anim.speed_scale = 1.5
	anim.play('Reactions/Spin', -1, 1.5)
	#var t := get_tree().create_timer((Song.beat_to_sec(Song.BEATS.quarter) * num_beats_before_idle) * 2)
	#t.connect('timeout', _on_spin_timer_end)
	spin_tween = get_tree().create_tween()
	spin_tween.tween_property(anim, 'speed_scale', 0.15, ev.build_up) \
		.set_ease(Tween.EASE_OUT)
	spin_tween.tween_callback(_on_spin_end)


func _on_spin_end() -> void:
	#print('spin end')
	_spinning = false
	num_beats_before_idle = 2
	anim.speed_scale = 1
	
	if not ('Spin' in anim.current_animation) and anim.is_playing():
		return
	anim.play('Standard/Idle')


func _post_hit_pog() -> void:
	if anim.is_playing() or 'Throw' in anim.current_animation:
		return
	_reset()
	anim.play('Reactions/PostHitPog')


func _on_ball_throw_finished(
	ball_pf:BallFollow,
	tween:Tween=null,
	shadow_pf:BallFollow=null
) -> bool:
	if !super(ball_pf, tween, shadow_pf): return false
	
	# Adding ball to miss path
	# NOTE PathFollow2D progress can only be changed while in the scene
	ball_pf.hide()
	ball_pf.progress_ratio = 0.0
	ball_path.remove_child(ball_pf)
	miss_path.add_child(ball_pf)
	ball_pf.show()
	
	# Adding shadow to miss path
	shadow_pf.hide()
	shadow_pf.progress_ratio = 0.0
	shadow_path.remove_child(shadow_pf)
	miss_shadow_path.add_child(shadow_pf)
	shadow_pf.show()
	
	# Traveling path
	var tw := create_tween()
	var time := Song.beat_to_sec(miss_path_time) / 2.0
	
	# Catches late event activations
	# FIXME error saying lambda capture at index 2 was freed
	var lambda := func(_ev, _s, _ofs): 
		if tw.is_running(): tw.kill()
		if is_instance_valid(ball_pf): ball_pf.queue_free()
		if is_instance_valid(shadow_pf): shadow_pf.queue_free()
	Signals.event_activated.connect(lambda, CONNECT_ONE_SHOT)
	
	var curve_length:float = miss_path.curve.get_baked_length()
	
	# Bouncing into Golfer's leg
	# Getting progress ratio diff to 3rd point since that's the one that
	# hits the Golfer's leg; i.e., where the tween changes a bit
	var init_offset:float = \
		miss_path.curve.get_closest_offset(miss_path.curve.get_point_position(2))
	var mid_pratio:float = (init_offset / curve_length)
	tw.tween_property(ball_pf, 'progress_ratio', mid_pratio, time*0.9) \
		.set_ease(Tween.EASE_OUT_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(shadow_pf, 'progress_ratio', mid_pratio, time*0.9) \
		.set_ease(Tween.EASE_OUT_IN).set_trans(Tween.TRANS_QUAD)
	
	# Rolling off-screen
	# Getting progress ratio of the split proportional to the remaining progress
	var p1_offset:float = \
		miss_path.curve.get_closest_offset(miss_path.curve.get_point_position(2))
	var p1_ratio:float = ( p1_offset / curve_length ) / (init_offset) / curve_length
	
	# Using all that to split tween time
	var p1_time:float = time * p1_ratio
	var p2_time:float = time - p1_time
	
	# Part 1: Slowly bouncing off Golfer
	tw.tween_property(ball_pf, 'progress_ratio', 1, p1_time) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shadow_pf, 'progress_ratio', 1, p1_time) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	# FIXME this doesn't roll down as smoothly as I'd like
	# Part 2: Rolling off-screen
	tw.tween_property(ball_pf, 'progress_ratio', 1, p2_time)
	tw.parallel().tween_property(shadow_pf, 'progress_ratio', 1, p2_time)
	tw.tween_callback(ball_pf.queue_free)
	tw.tween_callback(shadow_pf.queue_free)
	tw.tween_callback(Signals.event_activated.disconnect.bind(lambda))
	#tw.finished.connect(func(): _on_missed_ball_bounce_finished(ball_pf, shadow_pf))
	return true
