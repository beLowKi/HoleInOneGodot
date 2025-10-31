@tool
@icon("res://src/scenes/event_displays/golfer/assets/icon.png")
class_name Golfer extends EventDisplay
## The golfer the player controls in Hole in One.

const MEH_SFX := preload('res://src/assets/sfx/tap4.wav')
const BIG_MEH_PITCH_SCALE:float = 0.8
const MEH_EARLYLATE_MOD:float = 0.23

const BALL_HIT_SFX := preload("res://src/assets/sfx/golf_ball_hit.wav")
const MISS_SFX:Array[AudioStreamWAV] = [
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_miss1.wav"),
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_miss2.wav"),
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_miss3.wav")
	]
const HURT_SFX:Array[AudioStreamWAV] = [
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_hurt1.wav"),
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_hurt2.wav"),
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_hurt3.wav"),
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_hurt4.wav"),
	preload("res://src/scenes/event_displays/golfer/assets/sfx/golfer_hurt5.wav"),
	]

const PERFECT_FLASH_DUR:float = 0.04167  # 1 frame in 24 fps

## Listens to these for animating the wind up
@export var ball_throwers:Array[BallThrower]

@onready var flight_path:GolfBallFlightPath
@onready var hurt_miss_player:AudioStreamPlayer = $HurtMissPlayer
@onready var ball_hit_player:AudioStreamPlayer = $BallHitPlayer

var _bopping:bool = false
var _swinging:bool = false
var _default_ball_hit_pitch:float = 0
var _swing_on_cd:bool = false


func _ready() -> void:
	super()
	
	set_process_input(false)
	
	if Engine.is_editor_hint():
		return
	
	for thrower in ball_throwers:
		thrower.connect('ball_thrown', func(): anim.play("Standard/WindUp"))
	
	_default_ball_hit_pitch = ball_hit_player.pitch_scale


func _process(delta: float) -> void:
	super(delta)
	
	if not flight_path and find_child('GolfBallFlightPath'):
		var fpath = find_child('GolfBallFlightPath')
		if fpath is GolfBallFlightPath:
			flight_path = fpath
	
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return


func _input(event: InputEvent) -> void:
	if !_swing_on_cd and \
		(event.is_action_pressed("Button1") or event.is_action_pressed("Button2")):
		_swing()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray = []
	
	if not flight_path:
		warnings.append("Golfer is missing valid GolfBallFlightPath")
	
	return warnings


func _on_meta_config() -> void:
	_timescale_anim("Standard/WindUp", [[Song.BEATS.quarter, false]])


func can_bop() -> bool:
	return _bopping && !_swinging && super()


func _on_song_started() -> void:
	super()
	_bopping = true
	bop()
	set_process_input(true)


func _on_song_ended() -> void:
	super()
	_bopping = false


## Connected to ev.missed
func _on_event_missed(ev:RhythmInputEvent, meh:bool=false) -> void:
	# Means it was an early or late note re-emitted by stage
	# doesn't need to play a reaction
	if !meh:
		if ev.note_key == 'D':
			hurt_miss_player.stream = HURT_SFX.pick_random()
			anim.play('Reactions/LegHit')
		else:
			if 'swing' not in anim.current_animation.to_lower():
				anim.play('Reactions/Miss')
			hurt_miss_player.stream = MISS_SFX.pick_random()
	
	hurt_miss_player.play()


## Connected to ev.activated
func _on_event_hit(ev:RhythmInputEvent, score:Utils.SCORES, offset:float) -> void:
	#print(Utils.SCORES.keys()[score])
	if score == Utils.SCORES.PERFECT:
		$PerfectImpact.show()
		var t := get_tree().create_timer(PERFECT_FLASH_DUR)
		t.timeout.connect($PerfectImpact.hide)
	if score == Utils.SCORES.MEH:
		ball_hit_player.stream = MEH_SFX
		if ev.note_key == 'D': 
			ball_hit_player.pitch_scale = BIG_MEH_PITCH_SCALE
		else:
			ball_hit_player.pitch_scale = _default_ball_hit_pitch
		
		if Funcs.roundf_dec(offset, 3) <= 0.000:
			ball_hit_player.pitch_scale += MEH_EARLYLATE_MOD
		else:
			ball_hit_player.pitch_scale -= MEH_EARLYLATE_MOD
		
		ball_hit_player.play()
	else:
		ball_hit_player.stream = BALL_HIT_SFX
		ball_hit_player.pitch_scale = _default_ball_hit_pitch
		ball_hit_player.play()
	flight_path.add_ball(ev, score, offset)


# # # # # # # # # q# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                        GOLFER FUNCTIONS                                         #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

func _swing() -> void:
	if anim.is_playing():
		if 'LegHit' in anim.current_animation: return
		if 'Swing' in anim.current_animation: anim.stop()
	anim.play("Standard/Swing")
	_swing_on_cd = true
	get_tree().create_timer(Stylus.INPUT_BUFFER).timeout.connect(
		func():_swing_on_cd = false, CONNECT_ONE_SHOT
		)
	
	# Queues idle anim on next beat after swing anim
	# NOTE Commenting this makes golfer idle later after swinging
	anim.animation_finished.connect(func(_a):
		Signals.beat.connect(
			func(): if !anim.is_playing(): anim.play('Standard/Idle'),
			CONNECT_ONE_SHOT
			),
			CONNECT_ONE_SHOT
		)
	
	_swinging = true
	#var wait_time:float = anim.get_animation('Standard/Swing').length * 0.67
	var wait_time := Song.beat_to_sec(Song.BEATS.quarter) * 0.8
	var t := get_tree().create_timer(wait_time)
	t.timeout.connect(func(): _swinging = false, CONNECT_ONE_SHOT)


func get_flight_time() -> float:
	if not flight_path: return 0.0
	return flight_path.get_flight_time()
