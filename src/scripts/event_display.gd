@tool
class_name EventDisplay extends Node2D
## Class for things that are animated according to RhythmInputEvent signal calls


@export_group("Notes")
## Supported input notes => see Songs.INPUT_KEYS. and Songs.INPUT_KEYS_ENUM
## Yes it's a separate var because I don't wanna fix the array's implementation rn
@export var note_keys:Array[Song.INPUT_KEYS_ENUM] = [Song.INPUT_KEYS_ENUM.C, Song.INPUT_KEYS_ENUM.D]

## The special keys that will be checked
@export var special_keys:Array[Song.SPECIAL_NOTE_KEYS_ENUM]

@export_group('Supported Inputs')
@export var single_press:bool = true
@export var single_hold:bool = false
@export var double_press:bool = false
@export var double_hold:bool = false
@export var bends:bool = false

## Will be the sfx played for the relevant event signals unless otherwise specified
@export_group('Default Sound Effects')

"""
lower-case s = single
lower-case db = double
capital B = bend * remember, more of a modifier than its own input type

P = press
H = hold

"""

@export_subgroup('Single')
@export var single_press_start_sfx:AudioStream
@export var single_press_miss_sfx:AudioStream
@export var single_hold_start_sfx:AudioStream
@export var single_hold_holding_sfx:AudioStream
@export var single_hold_miss_sfx:AudioStream

@export_subgroup('Double')
@export var double_press_start_sfx:AudioStream
@export var double_press_miss_sfx:AudioStream
@export var double_hold_start_sfx:AudioStream
@export var double_hold_holding_sfx:AudioStream
@export var double_hold_miss_sfx:AudioStream

# NOTE all bends are holds
# TODO not sure if these should play INSTEAD of the normal sfx or on top of it
@export_subgroup('Bends')
@export var bend_start_sfx:AudioStream
@export var bend_stretch_sfx:AudioStream
@export var bend_snap_sfx:AudioStream
@export var bend_miss_sfx:AudioStream


@export_group("Misc")

## The beat-speed that animations will follow
## i.e. a display that telegraphs an input will use this => Song.beat_to_sec() to match its
## animations to different bpms
#@export var anim_beat:Song.BEATS = Song.BEATS.quarter

## The rhythm that the display will wait until going back to idle
@export_range(1, 4, 1, 'or_greater') var num_beats_before_idle:int = 2

## Names of animations that are interupted by idle
@export var idle_skip_anims:Array[StringName]

## Nodes that will "bop" to the beat. They'll jump down a few pixels then gradually return
## to their resting position. 
##
##These nodes can still have an "On_beat" animation and it won't
## conflict as long as they aren't both affecting the nodes "position" property
#@export var boppers:Array[Node]
@export var bop_anim:AnimationPlayer
@export var boppable_anims:Array[StringName]

@onready var anim:AnimationPlayer = $AnimationPlayer
#@onready var idle_timer:Timer = $IdleTimer

var supported_inputs:Array[Utils.INPUT_TYPES]
var wind_speed_scale:float
var _anim_speed_scales:Dictionary = {}
var _idle_beat_count:int = 0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	#if !bop_anim: bop_anim = anim
	
	if single_press:
		supported_inputs.append(Utils.INPUT_TYPES.single_press)
	if single_hold:
		supported_inputs.append(Utils.INPUT_TYPES.single_hold)
	if double_press:
		supported_inputs.append(Utils.INPUT_TYPES.double_press)
	if double_hold:
		supported_inputs.append(Utils.INPUT_TYPES.double_hold)
	
	anim.animation_started.connect(_on_anim_started)
	Signals.song_started.connect(_on_song_started)
	Signals.song_ended.connect(_on_song_ended)
	Signals.connect('bpm_changed', _on_meta_config)
	Signals.connect('time_signature_changed', _on_meta_config)
	Signals.connect('beat', _on_beat)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		#if anim.has_animation("Standard/Idle"):
			#anim.current_animation = "Standard/Idle"
		
		# Checking for duplicates
		var tmp:Array[Song.INPUT_KEYS_ENUM] = []
		for nk in note_keys:
			if not tmp.has(nk):
				tmp.append(nk)
		
		# Adding a new element from 0 will auto set it to C and D
		if note_keys != tmp:
			if len(note_keys) == 2:
				note_keys[0] = Song.INPUT_KEYS_ENUM.C
				note_keys[1] = Song.INPUT_KEYS_ENUM.D
			else:
				note_keys = tmp
		
		return




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                           DISPLAY FUNCTIONS                                     #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


# adjusts the duration of an animation to match a certain rhythm
# dur arrays need to be structured as Array[[Song.BEATS, dotted]]
# NOTE 'dotted' notes *= their duration by 1.5
func _timescale_anim(anim_name:String, dur) -> float:
	var curr_anim := anim.current_animation
	
	# can only get anim length of current animation as far as I know
	anim.set_current_animation(anim_name)
	var curr_time:float = anim.current_animation_length
	
	var target_time:float = 0.0
	if typeof(dur) == TYPE_ARRAY:
		for note in dur:
			target_time += Song.beat_to_sec(note[0], note[1])
	elif (typeof(dur) == TYPE_FLOAT) or (typeof(dur) == TYPE_INT):
		target_time = dur
	else:
		push_error("Wrong type of dur in _timescale_anim %s" % dur)
		return 0.0
	
	_anim_speed_scales[anim_name] = target_time / curr_time
	anim.set_current_animation(curr_anim)
	
	return target_time


## "Queues" event - immediately starts it and connects its signals
func add_event(ev:RhythmInputEvent) -> void:
	if not can_add_event(ev):
		#push_error("attempted to add unsupported event %s to display %s" % [ev.get_input_type(), name])
		return
	
	_on_event_start(ev)
	ev.connect('missed', _on_event_missed)
	ev.connect('activated', _on_event_hit)


@warning_ignore("unused_parameter")
func get_travel_time(ev:RhythmInputEvent) -> float:
	return 0.0


func can_add_event(ev:RhythmInputEvent) -> bool:
	# FIXME this entire fucking thing
	if special_keys and special_keys.find(ev.note_key):
		print('special key')
		return true
	if not supported_inputs.has(ev.get_input_type()):
		#prints(supported_inputs, ev.get_input_type())
		#print("unsupported input event %s at %.3f in %s" % [ev.note_key, ev.start_time, name])
		return false
	if ev.bent != bends:
		return false
	if ev.note_key == 'C' and Song.INPUT_KEYS_ENUM.C in note_keys:
		return true
	if ev.note_key == 'D' and Song.INPUT_KEYS_ENUM.D in note_keys:
		return true
	return false


func has_event(ev:RhythmInputEvent) -> bool:
	return ev.is_connected('missed', _on_event_missed) or ev.is_connected('activated', _on_event_hit)


## Head bop effect
func bop() -> void:
	if _anim_speed_scales.has('bop'):
		#print('%s bopped' % name)
		bop_anim.play.call_deferred('Bop', -1, _anim_speed_scales['bop'])


## Returns if the display can/should bop.
func can_bop() -> bool:
	if !(bop_anim and bop_anim.has_animation('Bop')): 
		return false
	return !anim.is_playing() or boppable_anims.has(anim.current_animation)
	#return 'idle' in anim.current_animation.to_lower() or \
		 #idle_skip_anims.has(anim.current_animation)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                             OVERRIDES                                           #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

func _on_anim_started(_anim_name:StringName) -> void:
	if (bop_anim and bop_anim.is_playing()):
		#bop_anim.stop.call_deferred()
		bop_anim.stop()
		pass
		#bop_anim.play('RESET')

func _on_meta_config() -> void:
	pass


func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray
	return warnings


func _on_beat() -> void:
	if (anim.current_animation in idle_skip_anims) or not anim.is_playing():
		_idle_beat_count += 1
	else:
		#print('%s reset idle beat count because busy' % name)
		_idle_beat_count = 0
	
	if _idle_beat_count >= num_beats_before_idle:
		#print('%s reset idle beat count because idling' % name)
		
		#var bopping:bool = bop_anim && bop_anim.is_playing()
		if anim.has_animation('Standard/Idle'):
			anim.play('Standard/Idle')
		
		_idle_beat_count = 0
	
	if can_bop(): bop()


func _on_song_started() -> void:
	var _beat_dur:float = Song.beat_to_sec(Song.BEATS.quarter)
	if bop_anim and bop_anim.has_animation('Bop'):
		var anim_dur:float = bop_anim.get_animation('Bop').length
		_anim_speed_scales['bop'] = _beat_dur / anim_dur


func _on_song_ended() -> void:
	# Waits for next beat to stop processing
	await Signals.beat
	anim.play('Standard/Idle')
	set_process_input(false)
	set_process(false)
	set_physics_process(false)


## Called when using 'add_event'
@warning_ignore("unused_parameter")
func _on_event_start(ev:RhythmInputEvent) -> void:
	pass


## Connected to ev.missed
@warning_ignore("unused_parameter")
func _on_event_missed(ev:RhythmInputEvent) -> void:
	pass


## Connected to ev.activated
@warning_ignore("unused_parameter")
func _on_event_hit(ev:RhythmInputEvent, score:Utils.SCORES, offset:float) -> void:
	pass
