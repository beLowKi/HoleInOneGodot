@tool
@icon("res://src/scenes/event_displays/the_hole/assets/icon.tres")
class_name GolfHoleCutin extends EventDisplay
## The cut in showing the ball going into the hole.

const STARTUP_ANIMS:Array[String] = [
	'Reactions/1_Start',
	'Reactions/2_Start',
	'Reactions/3_Start'
	]

@export var golfer:Golfer
@onready var img:CanvasGroup = $Image
@onready var wind_sfx_player:AnimationPlayer = $WindSFXPlayer
var _wind_up_time:float


func _ready() -> void:
	super()
	
	if Engine.is_editor_hint():
		return


func _process(delta: float) -> void:
	super(delta)
	
	if Engine.is_editor_hint():
		if not golfer:
			update_configuration_warnings()
		
		return


#func _input(event: InputEvent) -> void:
	#pass


## connected to Signals => time_signature_changed and bpm_changed
func _on_meta_config() -> void:
	pass


## Warnings that will go to Output to tell you when something isn't set up right
func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray
	
	if not golfer:
		warnings.append('Cutin is missing valid golfer')
	
	return warnings


## Connected to ev.activated
func _on_event_hit(ev:RhythmInputEvent, score:Utils.SCORES, _offset:float) -> void:
	if score in [Utils.SCORES.PERFECT, Utils.SCORES.GREAT]:
		img.show()
		_idle_beat_count = 0
	else:
		return
	
	var t := get_tree().create_timer(golfer.get_flight_time())
	if ev.note_key == 'D':
		t.connect('timeout', func(): anim.play('Reactions/BigBall'))
	else:
		t.connect('timeout', _play_rand_reaction)


func _on_song_started() -> void:
	super()
	
	_wind_up_time = Song.beat_to_sec(Song.BEATS.quarter)


func _on_song_ended() -> void:
	pass


func _play_rand_reaction() -> void:
	var chosen_anim:String = STARTUP_ANIMS.pick_random()
	
	anim.play(chosen_anim)
	if not ('3' in chosen_anim or '1' in chosen_anim): return
	
	await anim.animation_finished
	
	# Wind up
	var wind_anim:String = chosen_anim.replace('Start', 'WindUp')
	# FIXME anim 1 lags the game for some reason?
	anim.play(wind_anim)
	
	# Tweening pitch_scale during wind up
	if wind_sfx_player.is_playing(): wind_sfx_player.stop()
	var speed_scale:float = anim.get_animation(wind_anim).length / _wind_up_time
	if '1' in chosen_anim:
		wind_sfx_player.play('Fwip', -1, speed_scale)
		pass
	else:
		wind_sfx_player.play('Spin', -1, speed_scale)
	
	var t := get_tree().create_timer(_wind_up_time)
	t.timeout.connect(_on_wind_end)


func _on_wind_end() -> void:
	#if not ('1' in anim.current_animation or '3' in anim.current_animation):
		#push_error('Wind anim was interupted prematurely')
		#return
	
	anim.play(anim.current_animation.replace('WindUp', 'End'))
