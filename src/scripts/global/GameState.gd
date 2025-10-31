extends Node
## Buncha variables for game state. All are updated during runtime and should ALWAYS use set or get

# Misc
var fade_into_menu:bool = false

# Song-related
var chart:Chart:
	set(c):
		chart = c
		#chart.connect_events()
		var meta := chart.get_starting_meta()
		set('song', chart.song_file)
		for k in meta.keys():
			set(k, meta[k])
		#chart.validate()
		Signals.chart_changed.emit(chart)
var song:String:
	set(s):
		song = s
		Signals.song_changed.emit(song)
var key_signature:Song.KEY_SIGNATURES = Song.KEY_SIGNATURES.TODO:
	set(k):
		key_signature = k
		# TODO Signals.key_signature_changed.emit(key_signature)
var time_signature:Song.TIME_SIGNATURES :
	set(ts):
		if ts == time_signature: return
		time_signature = ts
		Signals.time_signature_changed.emit()
var bpm:float :
	set(b):
		if b == bpm: return
		bpm = b
		Signals.bpm_changed.emit()


# Run-time
#var current_interactive:Interactive:
	#set(i):
		#current_interactive = i
	#get:
		#return current_interactive
