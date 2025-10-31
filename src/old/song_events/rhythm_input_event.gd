class_name RhythmInputEvent extends SongEvent
## Basic resource for tracking notes in a midi chart


@warning_ignore("unused_signal")
signal missed
@warning_ignore("unused_signal")
signal activated

@export_storage var note_key:StringName
@export_storage var build_up:float
@export_storage var action:InputEventAction
@export_storage var is_held:bool
@export_storage var bent:bool


static func from_NoteOn(time: float, src: MidiData.NoteOn = null, key:String = '', delta:int = 0) -> RhythmInputEvent:
	var ev := RhythmInputEvent.new()
	ev.note_key = src.note_key if src else key
	if Song.INPUT_KEYS.has(ev.note_key):
		ev.action = ev._get_action(ev.note_key)
	ev.delta_time = src.delta_time if src else delta
	ev.start_time = time
	return ev


## Updates 'is_held' based on time signature and bpm
func update(time_signature:Song.TIME_SIGNATURES=GameState.time_signature, bpm:float=GameState.bpm) -> void:
	var too_long:float
	var sec_per_32:float
	var sec_per_beat: float = 1 / (bpm / 60)
	match Song.split_ts_enum(time_signature)[0]:
		4:
			sec_per_32 = sec_per_beat / 8.0
			too_long = sec_per_beat / 2.0  # Longer than eighth note
		8:
			sec_per_32 = sec_per_beat / 4.0
			
			# Longer than 2 beats (time from start of 1 to beginning of 3 in 1,2,3 -> 4,5,6)
			too_long = sec_per_beat * (2.0 / 3.0)
	
	# Increases a little bit so that only notes that are noticably greater that 'too_long' get changed
	too_long += sec_per_32 * 2
	
	is_held = get_duration() > too_long
	#prints(get_duration(), too_long, is_held)
	
	if Song.INPUT_KEYS.has(note_key) and not action: 
		action = _get_action(note_key)
	if action:
		action.pressed = not is_held


## Sets end_time and updates
func set_end_time(t:float, time_signature:Song.TIME_SIGNATURES=GameState.time_signature, bpm:float=GameState.bpm) -> void:
	end_time = t
	#update(time_signature, bpm)


## Returns if ev has matching note
func is_same_note(ev) -> bool: 
	assert((ev is RhythmInputEvent) or (ev is MidiData.NoteOn) or (ev is MidiData.NoteOff), 'Invalid RhythmInputEvent comparison')
	return note_key == ev.note_key


func get_track() -> int:
	return Utils.action_enum(action.action)


func _get_action(nkey:StringName) -> InputEventAction:
	return Utils.enum_action(Song.get_note_track(nkey))


func get_input_type() -> Utils.INPUT_TYPES:
	
	# Single-input
	if ["Button1", "Button2"].has(action.action):
		return Utils.INPUT_TYPES.single_hold if is_held else Utils.INPUT_TYPES.single_press
	
	return Utils.INPUT_TYPES.double_hold if is_held else Utils.INPUT_TYPES.double_press
