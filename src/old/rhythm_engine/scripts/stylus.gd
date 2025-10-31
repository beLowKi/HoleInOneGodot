class_name Stylus extends EnginePart
## Tracks current position in song and notes. Notes are tracked by start_time and track_number


## When pre-read preparation is finished
signal read_loaded
## Beganing _reading a song
signal read_started(c: Chart)
## Stopped _reading a song; returns bool for if it ended early
signal read_ended(ended_early: bool)

# TMP just for Hole in One demo
const INPUT_BUFFER:float = 0.55

## Basically a difficulty setting; this is how many thirty-second notes early or late an input can be
#@export_range(1, 5, 0.25, 'or_greater') var tolerance:float

#@export_subgroup('Test Stuff')
#@export var current_chart: Chart
### Exported for testing
#@export_file('*.mid') var test_midi : String

@export var tolerance:float

@onready var song_timer:Timer = $SongTimer
#@onready var player:Player = %Player

# Inherited signals
var section_changed:Signal = Signals.section_changed
var measure_changed:Signal = Signals.measure_changed
var time_signature_changed:Signal = Signals.time_signature_changed
var bpm_changed:Signal = Signals.bpm_changed

# - - - - - >
var current_chart:Chart
var sections:Array[Section]			# All of a song's sections
var current_section:Section

var measures:Array[Measure]			# Only the measures of the current section
var current_measure:Measure

var queued_events:Array[RhythmInputEvent] = []	# Notes ordered by starting time (RhythmInputEvent.start_time)

# {Utils.input: Array[QueuedInputEvent]} \
# {track1: list of events in order of soonest to latest}
# A track with multiple events means that there are two events really close together--making their
# tolerated times overlap a bit. The queue makes it so that the next input for that track only calls the
# earliest event
var _input_events:Dictionary = {}
var _release_events:Dictionary = {}
var _non_input_events:Array = []

var _timers:Dictionary = {Utils.INPUTS.button1: [], Utils.INPUTS.button2: []}
var _song_length:float
var _beat_num:int = 0  				# used to track measures
var _reading: bool = false :
	set(b):
		_reading = b
		if b == true:
			set_process(true)
		else:
			set_process(false)
var _event_on_1:bool = false
var _input_buffering:bool = false


func _ready():
	super()
	_reset()
	
	engine.connect('ready', _on_player_loaded)
	Signals.connect('chart_changed', set_chart)


func _process(_delta):
	if not current_section or not current_measure: return
	var event := get_next_event()
	if not event: return
	
	var time := get_song_time()
	
	if get_tolerated_time(event.start_time) <= time:
		_queue_event(event)
	else:
		#print("Note time %.3f not started because time was %.3f" % [event.start_time, time])
		pass


func _input(event: InputEvent) -> void:
	# TMP for Hole in One demo
	if _input_buffering: return
	_input_buffering = true
	get_tree().create_timer(INPUT_BUFFER).timeout.connect(
		func(): _input_buffering = false, CONNECT_ONE_SHOT
		)
	
	# TODO check for combination
	var action:Utils.INPUTS
	if event.is_action("Button1"):
		action = Utils.action_enum("Button1")
	elif event.is_action("Button2"):
		action = Utils.action_enum("Button2")
	else:
		return
	
	var checking = _release_events if event.is_released() else _input_events
	var queue:Array # = checking[action].duplicate(true)
	
	# makeshift fix so that single-button inputs count for both
	if action == Utils.INPUTS.button1 or action == Utils.INPUTS.button2:
		queue.append_array(checking[Utils.INPUTS.button1])
		queue.append_array(checking[Utils.INPUTS.button2])
	else:
		pass
	
	if queue.is_empty():
		## NOTE this was a makeshift way of handling events that happen on beat 1 of the first measure
		##if song_timer.is_stopped() and _event_on_1:
			##var t := get_tree().create_timer(get_window_duration() / 2)
			##t.connect('timeout', func(): _on_player_input(input))
		
		#prints('no notes in queue ', queue, checking)
		return
	
	var first_match:RhythmInputEvent = queue.front()
	
	# Release events that released early are missed instead
	if event.is_released() and (get_song_time() < get_tolerated_time(first_match.end_time, false)):
		first_match.emit_signal('missed')
		return
	
	#print("activated event")
	_activate_event(first_match)


####################################################################################################
####################################################################################################
####################################################################################################


## Used to change current chart; also prepares for next read
func set_chart(c:Chart) -> void:
	current_chart = c
	_prep_read()


## TODO Begins _reading chart on next valid time -> next time metronome is started OR on the next beat
func start_on_next() -> void:
	#sync_to_start(_on_prestart, true)
	sync_to_start(_on_read_start)


## Pauses, but doesn't end, current read
func pause() -> void:
	set('_reading', false)


## TODO Forces the end of current read -> should emit when song is stopped early
func force_stop() -> void:
	_on_read_end()


## Gets next note based on start_time
func get_next_event() -> RhythmInputEvent: 
	if queued_events.is_empty(): return null
	return queued_events.front()


func get_song_time() -> float: 
	return _song_length - song_timer.time_left


## Returns array of input events and release events in that order
## They're both input dictionaries
func get_active_events() -> Array[Dictionary]:
	return [_input_events, _release_events]


## Returns current window time (in sec) for each event
func get_window_duration() -> float: return 2 * tolerance * _get_subdiv_time()


## Returns t after adjusting for tolerance with current time signature and bpm
## NOTE high bpms with 8 note beats might need a bit more tolerating
func get_tolerated_time(t:float, is_start:bool = true) -> float:
	if t == 0: return 0
	var out:float
	var subdiv := _get_subdiv_time()
	
	out = t - (tolerance * subdiv) if is_start else t + (tolerance * subdiv)
	if out < 0.0: out = 0
	
	return out



func _sort_notes(n1:RhythmInputEvent, n2:RhythmInputEvent) -> bool: return n2.start_time > n1.start_time


func _queue_timer(ev:RhythmInputEvent, is_release:bool=false):
	var timer := get_tree().create_timer(get_window_duration())
	timer.connect('timeout', func(): _on_window_end(ev, is_release))
	ev.emit_signal('started', ev)
	Signals.event_started.emit(ev)


# TODO stop events from queuing their release if their initial event is missed
func _queue_release(ev:RhythmInputEvent) -> void:
	_release_events[ev.get_track()].append(ev)
	
	# Timer before release window begins
	var starting_timer := get_tree().create_timer(ev.get_duration() - get_window_duration())
	# Connected to starting actual window timer
	starting_timer.connect('timeout', func(): _queue_timer(ev, true))


func _queue_event(ev:RhythmInputEvent) -> void:
	if not _reading: return
	
	queued_events.pop_front()
	#print('\t\t%s at %s with current time = %s' % [ev.note_key, ev.start_time, Funcs.round_to(get_song_time(), 4)])
	
	# Adds relevant input event to dictionary
	var track_num:int = Song.get_note_track(ev.note_key)
	#_input_events[Utils.INPUTS.find_key(Utils.get_note_track(ev.note_key))].append(ev)
	_input_events[track_num].append(ev)
	
	# Starts timer based on window duration
	_queue_timer(ev)
	
	# Test that makes a sound in the middle of event
	#var t := get_tree().create_timer(get_window_duration() / 2)
	#t.connect('timeout', $EventSound.play)
	
	# If it's a held note, queue a release event after it's been activated
	# NOTE will auto miss if not activated
	if ev.is_held: 
		ev.connect('activated', func(_ev, _score): _queue_release(ev))
		#ev.connect('missed', ev.event_missed.emit)


# If window for event ends without input
func _on_window_end(ev:RhythmInputEvent, is_release:bool=false) -> void:
	var track := ev.get_track()
	if is_release and ev.is_held:
		_release_events[track].erase(ev)
		
		# NOTE release events count as activated if the player holds for too long
		#if player.is_holding(track): _activate_event(ev)
		
		return
	
	if not _input_events[track].has(ev): 
		return
	_input_events[track].erase(ev)
	
	#print('\t\t%s released at %.3f' % [ev.note_key, ev.start_time])

	ev.emit_signal('missed', ev)
	Signals.event_missed.emit(ev)


func _get_subdiv_time() -> float:
	var subdiv:float
	var ts: Song.TIME_SIGNATURES = GameState.time_signature
	var bpm = GameState.bpm
	assert(bpm)
	var sec_per_beat:float = (1.0 / (bpm / 60.0))
	
	# seconds per 32 note for both
	match Song.split_ts_enum(ts)[1]:
		4:
			subdiv = sec_per_beat / 8.0
		8: 
			subdiv = sec_per_beat / 2.0
	
	return subdiv


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - >


func _activate_event(ev:RhythmInputEvent) -> void:
	var offset:float = get_song_time() - ev.start_time
	var input := ev.get_track()
	var score := engine.get_score(offset)
	
	ev.emit_signal('activated', ev, score, offset)
	Signals.event_activated.emit(ev, score, offset)
	
	if _input_events[input].has(ev):
		_input_events[input].erase(ev)
	elif _release_events[input].has(ev):
		_release_events[input].erase(ev)
	
	# If there's an ongoing timer for the event, ends it
	if not _timers.has(input): 
		push_error('Input missing timer')
		return
	var timer:Timer = _timers[input].pop_front()
	if not timer: return
	timer.stop()


func _on_player_loaded() -> void:
	#if not player: return
	
	## TODO only when its EncounterPlayer
	#player.connect('button_pressed', _on_player_input)
	#player.connect('button_released', func(ev): _on_player_input(ev, true))
	pass


#func _on_player_input(input:Utils.INPUTS, released:bool=false) -> void:
	#var check_dict:Dictionary = _input_events if not released else _release_events
	#
	## Gets queue of this input's tracked events
	#var queue:Array = check_dict[input]
	#if not queue: 
		#if song_timer.is_stopped() and _event_on_1:
			#var t := get_tree().create_timer(get_window_duration() / 2)
			#t.connect('timeout', func(): _on_player_input(input))
		#return
	#
	#var event:RhythmInputEvent = queue.pop_front()
	#
	## Release events that released early are missed instead
	#if released and ( get_song_time() < get_tolerated_time(event.end_time, false)):
		#event.emit_signal('missed')
		#return
	#
	#_activate_event(event)


func _reset() -> void:
	if not engine.is_node_ready(): await engine.ready
	set('_reading', false)
	if metronome.is_connected('started', _on_read_start) or metronome.is_connected('new_measure', _on_read_start):
		desync(_on_read_start)
	var input_dict:Dictionary = Utils.get_button_dict()
	_input_events = input_dict.duplicate(true)
	_release_events = input_dict.duplicate(true)
	current_section = null
	measures.clear()
	current_measure = null
	queued_events.clear()
	_non_input_events.clear()
	_input_events.values().clear()
	_song_length = -1
	song_timer.wait_time = 1


func _prep_read() -> void:
	_reset()
	
	# Resetting song variables
	sections = current_chart.sections.duplicate_deep()
	
	# Reading chart
	var tracks := current_chart.get_tracks()
	for t in tracks: 
		for ev:RhythmInputEvent in t: 
			if not Song.INPUT_KEYS.has(ev.note_key):
				_non_input_events.append(ev)
			else:
				queued_events.append(ev)
	queued_events.sort_custom(_sort_notes)
	_non_input_events.sort_custom(_sort_notes)
	
	# Events that start on beat 1 of the first measure wouldn't have their start window extended correctly
	# because it uses get_song_time which only works while the song is running, and their extension
	# would be before that
	# This queues the first event's start in relation to metronome.get_prestart_time
	var first_event:RhythmInputEvent = queued_events.front()
	if get_tolerated_time(first_event.start_time) == 0:
		_event_on_1 = true
	
	# Song timer setup
	_song_length = current_chart.get_duration()
	song_timer.wait_time = _song_length
	
	read_loaded.emit()


func _on_read_start() -> void:
	_new_section()
	_new_measure()
	
	Signals.beat.connect(_on_beat)
	_reading = true
	song_timer.start()
	read_started.emit()


func _on_read_end() -> void:
	_reset()
	
	# FIXME this is printing like 2-4 times?
	# TODO this should force any outstanding events from ending
	#if _input_events.values(): print(_input_events)
	song_timer.stop()
	read_ended.emit()
	print('\n< Chart ended - - - - - - - - - -  - - - - - - - - - >')


func _new_section() -> void:
	current_section = sections.pop_front()
	# TODO key_signature
	GameState.set('time_signature', current_section.time_signature)
	GameState.set('bpm', current_section.bpm)
	measures = current_section.measures
	
	print('< Section: %s\n\tTime Signature: %s\n\tBPM: %s- - - - - >' % 
		[current_section.name, Song.time_signature_to_string(GameState.time_signature), GameState.bpm])
	section_changed.emit(current_section)


func _new_measure() -> void:
	current_measure = measures.pop_front()
	
	#print('\nCurrent queue:\tPressed -> %s\n\t\t\tReleased -> %s\n\n\t- Measure #%s' % [_input_events, 
			#_release_events, current_measure.number])
	measure_changed.emit(current_measure)


func _on_beat() -> void:
	#prints(_input_events, _release_events)
	
	if _beat_num >= Song.split_ts_enum(GameState.time_signature)[0]: 
		if sections and not measures: 
			_new_section()
		elif measures: 
			_new_measure()
		else:
			var connected:bool = \
				Signals.event_activated.is_connected(_await_last_ev) && \
				Signals.event_missed.is_connected(_await_last_ev)
			if !connected && !(queued_events.is_empty() && _release_events.is_empty()):
				Signals.event_activated.connect(_await_last_ev)
				Signals.event_missed.connect(_await_last_ev)
			elif queued_events.is_empty() && _release_events.is_empty():
				_on_read_end()
			return
		_beat_num = 0
	
	_beat_num += 1


func _await_last_ev(_ev=null,_s=null,_ofs=null) -> void:
	if !(queued_events.is_empty() && _release_events.is_empty()):
		return
	
	_on_read_end()
	Signals.event_activated.disconnect(_await_last_ev)
	Signals.event_missed.disconnect(_await_last_ev)
