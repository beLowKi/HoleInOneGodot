class_name RhythmEngine extends Node2D
## Rhythm hub for tracking beats and songs.


## Emitted by children to sync audio; handled mostly by the ssync
@warning_ignore("unused_signal")
signal sound_played(src, settings:AudioSettings)

signal song_ended

@export var active:bool = false
#@export var difficulty:Utils.DIFFICULTIES:  ## Doesn't do anything right now
	#set(d):
		#match d:
			#Utils.DIFFICULTIES.STANDARD:
				#max_tolerance = 5
			#Utils.DIFFICULTIES.EXPERT:
				#max_tolerance = 3
		#difficulty = d

@export_subgroup('Metronome')
## Number of measures metronome will count before emitting 'started'
@export_range(1, 4, 1) var pick_up_measures:int = 1  

@export_subgroup('Stylus')
var max_tolerance:float

## Increases window for RhythmInputEvents. A tolerance of 1 means that an input event can be activated,
## at most, one 32nd note early or late--scores are determined within that radius.
@export_range(1, 4, 0.05) var tolerance:float = 13.5 

@export_subgroup('Sound Sync')
@export_range(1, 8, 1, 'or_greater') var default_number_of_players:int = 5	## Number of preloaded AudioStreamPlayers

@onready var stylus:Stylus = $Stylus
@onready var metronome:Metronome = $Metronome
@onready var ssync:SoundSync = $SoundSync
#@onready var player:Player = %Player if active else null

var paused:bool = false
#var song_playing:bool = false


func _ready() -> void:
	if not active:
		return
	
	metronome.pick_up_measures = pick_up_measures
	stylus.tolerance = tolerance
	ssync.default_number_of_players = default_number_of_players
	
	stylus.connect('read_ended', song_ended.emit)


func _process(_delta) -> void:
	pass


####################################################################################################
####################################################################################################
####################################################################################################


## Returns the score of a note based on its offset. Uses the current difficulty
func get_score(offset:float) -> Utils.SCORES:
	# Each value marks how much offset an activated RhythmInputEvent can have for each score
	# They're measured in terms of tolerance i.e. 2 = 2 * tolerance, 0.5 = 1/2 * tolerance
	# They can't actually be greater than--or even equal to--the tolerance though because the stylus
	# wouldn't sync then
	
	# i know the elifs can just be ifs but I like it this way
	
	# TODO scale these with difficulty
	var perfect_radius:float = 1.0 / 70.0
	var great_radius:float = 1.0 / 25.0
	var offset_ratio:float = abs(offset) / tolerance
	
	# PERFECT
	if offset_ratio <= perfect_radius:
		#prints(offset, tolerance, offset_ratio)
		return Utils.SCORES.PERFECT
		
	# GREAT
	elif offset_ratio <= great_radius:
		#prints(offset, tolerance, offset_ratio)
		return Utils.SCORES.GREAT
		
	# MEH
	else:
		#prints(offset, tolerance, (meh_radius * tolerance))
		return Utils.SCORES.MEH


func is_ready() -> bool:
	# TODO
	return true


## Returns time (seconds) of the pickup measures
func get_pickup_time() -> float: 
	return pick_up_measures * Utils.split_ts_enum(GameState.time_signature)[0] * Funcs.bpm_to_spb(GameState.bpm)


## By the powers of rhythm combined, this song will start
## Everything else gets primed first, then the metronome is started to sync them all up
func start_song() -> void:
	if not active:
		return
	
	ssync.start_on_next()
	stylus.start_on_next()
	metronome.start()


## Pauses song; unpauses when called again TODO
func pause() -> void:
	if not paused:
		metronome.stop()
		stylus.pause()
		ssync.pause()
	else:
		start_song()
	
	paused = not paused


func stop() -> void:
	metronome.stop()
	stylus.force_stop()


func set_chart(c:Chart) -> void:
	GameState.set('chart', c)
	metronome.config()
