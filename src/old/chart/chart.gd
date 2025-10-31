class_name Chart extends Resource
## Prepared chart for playing a song; converted from midi files.
##
## RULES / RECOMMENDATIONS
##
##		1. Don't have notes that start on beat 1 of the first measure of 
##		the first section
##
## TODO
## 		> Not all DAWs support midis with markers, so I'm gonna need some other
##		way to find sections.
##			-> Could just have a dedicated note like B or summ, but it couldn't
##			include the section name--you'd have to add that manually.
##			-> Could also just find another tool to make the midis that
##			supports markers.

## Failed to load for whatever reasion
#signal load_failed(reason: String)
enum LOAD_FAIL_CONDITIONS {FILE_NOT_FOUND, MISSING_TRACKS}

## When new chart.tres file is saved successfully
signal saved(p: String)

## Saving chart file failed for some reason
signal save_failed(msg: SAVE_FAIL_CONDITIONS)
enum SAVE_FAIL_CONDITIONS {PATH_INVALID, FILE_EXISTS}


@export_category('Details')
@export var Name: String
@export_file('*.mp3', '*.wav', '*.flac') var song_file: String
@export_multiline var description: String

@export_subgroup('Misc')
## Input tracks; would be stored separately for performance?
#@export var tracks: Array[Array]
@export var sections: Array[Section]
#var raw:MidiData  ## TODO make uneditable

# TODO @export genre but when 'misc' is selected has an extra multiline
#@export var section_display: Array[Array]


enum FAIL_POINTS {invalid_track_type, too_many_note_keys}  # TODO
var fail_msgs: Dictionary = {
	FAIL_POINTS.invalid_track_type: "",
	FAIL_POINTS.too_many_note_keys: "" }
var ms_per_tick:float
var ticks_per_beat:int


## Loads chart from Chart.tres resource
static func load_resource(f:String):
	if not FileAccess.file_exists(f):
		push_error('Chart not found at %s' % f)
		return LOAD_FAIL_CONDITIONS.FILE_NOT_FOUND
	
	var chart:Chart = ResourceLoader.load(f, "res://CustomClasses/Chart/Chart.gd", ResourceLoader.CACHE_MODE_REPLACE)
	#if chart.sections and not chart.get_tracks(): 
		#push_error('Load of %s failed; tracks empty' % f)
		#return LOAD_FAIL_CONDITIONS.MISSING_TRACKS
	
	return chart


static func load_from_midi(fpath: String) -> Chart:
	#assert((midi is String or midi is PackedByteArray), "Invalid input for Chart: %s" % midi)
	var chart := Chart.new()
	var bytes := FileAccess.get_file_as_bytes(fpath)
	chart.Name = fpath.get_file().replace('.mid', '')
	chart.description = 'No description'
	
	var midi := MidiData.load_packed_byte_array(bytes)
	var header := midi.header
	chart.ms_per_tick = header.ms_per_tick
	chart.ticks_per_beat = header.ticks_per_beat
	
	var tempos: Array[MidiData.Tempo] = []  # Stores tempo meta; including mid-song changes hopefully
	var time_signatures: Array[MidiData.TimeSignature] = []  # same but for delta_time signatures
	var tracks = midi.tracks
	var note_keys: Array[String] = []  # Used to make sure there aren't too many different notes
	assert(len(tracks) == 2, "Unsupported track type, fix it bozo %s" % header.Format.find_key(header.format))
	
	# First track SEEMS to be the master track; I'll change this if it ever doesn't work :)
	for event: MidiData.Event in tracks[0].events:
		if event is MidiData.Tempo:
			tempos.append(event)
		elif event is MidiData.TimeSignature:
			time_signatures.append(event)
	
	var delta_time: int = 0
	var time_sec:float
	var measure_count:int = 1
	var current_section:Section = null
	var current_measure:Measure = null
	var current_time_signature: MidiData.TimeSignature = time_signatures.pop_front()
	var current_tempo:MidiData.Tempo = tempos.pop_front()
	var queued_measures:Array[Measure] = []
	var build_up_events:Array[RhythmInputEvent] = []
	var queued_notes:Array[RhythmInputEvent] = []  # Notes waiting for their respective NoteOff before being added to a track
	var next_measure_start := header.convert_to_seconds(current_tempo.us_per_beat, 0)
	for event: MidiData.Event in tracks[1].events:
		
		# Skips unhandled events
		if not (event is MidiData.Marker or event is MidiData.NoteOn or event is MidiData.NoteOff): 
			continue
		
		# Updating delta_time signature and tempo information - - - - - >
		delta_time += event.delta_time
		time_sec = header.convert_to_seconds(current_tempo.us_per_beat, delta_time)
		
		if tempos and (delta_time >= tempos.front().delta_time):
			current_tempo = tempos.pop_front()
		if time_signatures and (delta_time >= time_signatures.front().delta_time):
			current_time_signature = time_signatures.pop_front()
		
		
		# Section - - - - - - - - - - - - - - - - - - - - - - - - >
		var placeholder: String = "Temporary/Unnamed Section"
		if event is MidiData.Marker:
			
			if current_section:
				
				# Updates section name if temp is empty
				if not current_section.name == placeholder: 
					current_section.name = event.text
					
				# Ends current section and starts new one
				if current_measure:
					# TODO check for broken measures; missing or incomplete beats
					current_section.add_measure(current_measure)
					
				# NOTE Empty sections aren't deleted
				current_section.end_time = delta_time
				chart.sections.append(current_section)
				current_section = null
			else:
				# Creating a new section
				current_section = Section.new_section(event.text, time_sec, current_tempo, current_time_signature)
				measure_count = 1
			continue
		
		
		# Makes temp section if missing one
		if not current_section:
			current_section = Section.new_section(placeholder, time_sec, current_tempo, current_time_signature)
			measure_count = 1
		
		# Measure - - - - - - - - - - - - - - - - - - - - - - - - >
		
		# If (event.delta_time converted to seconds) >= current_measure.end_time: start new measure
		if current_measure and (event is MidiData.NoteOn):
			
			# Dunno why, but doesn't work if placed earlier at delta_time +=
			var tmp: float = header.convert_to_seconds(current_tempo.us_per_beat, delta_time) * 1e6
			#prints(tmp, next_measure_start)
			
			# Updates section or adds to queue
			if tmp >= next_measure_start:
				if current_measure.is_finished():
					current_section.add_measure(current_measure)
				else:
					queued_measures.append(current_measure)
				current_measure = null
		
		
		# Make a new measure if missing one
		if not current_measure:
			current_measure = Measure.new_measure(measure_count)
			
			# Adds milliseconds per beat times # beats per m
			next_measure_start += ((current_time_signature.numerator * current_tempo.us_per_beat))
			measure_count += 1
		
		
		# RhythmInputEvent - - - - - - - - - - - - - - - - - - - - - - - - >
		# NOTE every event past this point is either a NoteOn or NoteOff
		
		var note_key: String = event.note_key
		
		# the array being accessed
		var dst:Array[RhythmInputEvent]
		var is_build_up:bool
		if note_key in Song.BUILD_UP_KEYS:
			dst = build_up_events
			is_build_up = true
		else:
			dst = queued_notes
			is_build_up = false
			#print("%s not in build_ups" % note_key)
		
		
		# Adding new, non-build-up note_keys
		if not (is_build_up or note_keys.has(note_key)): 
			note_keys.append(note_key)
			note_keys.sort_custom(Song.sort_notes)  # Sorts by MidiData.NOTE_KEYS
		
		if event is MidiData.NoteOn:
			var new_ev := RhythmInputEvent.from_NoteOn(time_sec, event)
			
			# TODO make the push_error returns not interupt the Chart making
			
			#if is_build_up and get_earliest_matching(event, build_up_events, true):
				##push_error("Overlapping build up events, fix it bozo")
				#return
			
			# updates new_ev build up time to the queued event with matching note
			if build_up_events and not is_build_up:
				
				#print('checking build ups for %s' % event.note_key)
				var build_ev = get_earliest_matching(new_ev, build_up_events, true)
				
				if build_ev:
					#print("updated build up event")
					new_ev.set('build_up', build_ev.get_duration())
					build_up_events.erase(build_ev)
			
			dst.append(new_ev)
			continue
		
		
		# NOTE past this point is all MidiData.NoteOn
		
		var matching := get_earliest_matching(event, dst)
		if matching:
			matching.set_end_time(time_sec, Song.ts_from_meta(current_time_signature), current_tempo.bpm)
			
			if not is_build_up:
				current_measure.add_note(matching)
				dst.erase(matching)
			
			continue
		
		# Checks queued measure for earliest match
		# Each measure will check if it's missing a NoteOff for this note_key
		for m: Measure in queued_measures:
			var old_note: RhythmInputEvent = m.check_missing(note_key)
			if not old_note: 
				continue
			
			old_note.set_end_time(time_sec, Song.ts_from_meta(current_time_signature), current_tempo.bpm)
			#queued_measures.erase(m)
			break
	
	# Waste management
	# TODO
	assert(not queued_notes, "Leftover notes bozo")
	if current_section: 
		current_section.end_time = time_sec
		chart.sections.append(current_section)
	if current_measure: chart.sections.back().add_measure(current_measure)
	
	#chart._benchmark()
	
	# TODO return enum of what went wrong if it does
	#chart.validate()
	
	return chart


## Connects RhythmEvents' signals to their Signals counterpart
## NOTE/TODO there has GOT to be a better way to do this
func connect_events() -> void:
	
	# Makes a temp node to get default signals
	var DEFAULT_SIGNALS = _get_signal_names(Resource.new().get_signal_list())
	#print(DEFAULT_SIGNALS)
	
	for t in get_tracks(): for ev:SongEvent in t:
		var ev_signals:Array = _get_signal_names(ev.get_signal_list()).filter(func(sig): return not DEFAULT_SIGNALS.has(sig))
		var signal_list:Array = _get_signal_names(Signals.get_signal_list())
		var shared_signals:Array = signal_list.filter(func(sig): return ev_signals.has(sig))
		
		#prints(ev_signals, shared_signals)
		for sig in shared_signals:
			ev.connect(sig, Signals.get(sig).emit)


## Saves chart to file
func save(p: String, overwritting:bool=false):
	if not overwritting and FileAccess.file_exists(p): 
		print("File exists at path %s" % p)
		save_failed.emit(SAVE_FAIL_CONDITIONS.FILE_EXISTS)
		return
	if not Funcs.path_exists(p):
		save_failed.emit(SAVE_FAIL_CONDITIONS.PATH_INVALID)
		return
	
	var path: String = p
	if p.ends_with('.tres'): path = p
	else: path = "%s.tres" % p
	
	var err = ResourceSaver.save(self, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err: 
		push_error('Error saving file %s' % err)
		return
	
	# FIXME PLEEEEASSSE doesn't actually flush while game is running and focuses
	# File appears in editor when its focused, but so far I haven't been able to reference a Chart
	
	saved.emit(p)


## Double checks that chart is valid and does some housecleaning
## < Checklist - - - >
##	1. Isn't empty: has at least 1 note, 1 measure, and 1 section
##	2. Has a valid mp3, wav, or flac file attached
##
## < HouseCleaning - - - >
## 1. Updates notes' 'is_held' by guessing based on time signature and bpm
func validate(_updating:bool = false):
	if is_empty(): 
		push_error('Chart is empty')
		return
	if song_file and not get_duration():
		push_error('Chart does not have valid audio file attached')
		return
	for t in get_tracks(): 
		for ev:RhythmInputEvent in t:
			ev.update()


## Returns if chart has no sections, measures, or notes
func is_empty() -> bool:
	if sections != []: return false
	for s in sections: for m:Measure in s.measures:
		if m.notes != []: return false
	return true


## Returns all note tracks in Chart
## May or may not be in order; it most likely is, but I haven't checked yet, but I don't think it matters
func get_tracks() -> Array[Array]:
	#_benchmark()
	
	var tracks: Array[Array] = []
	for s in sections:
		
		# Adds new tracks
		if s.num_tracks > len(tracks):
			for t in range(s.num_tracks - len(tracks)):
				tracks.append([])
		
		#print(s.num_tracks)
		
		# Getting note tracks from measures
		for m: Measure in s.get('measures'):
			for pair: Array in Funcs.enumerate(m.get_note_tracks()):
				var index: int = pair[0]
				var track: Array = pair[1]
				#assert(len(tracks) >= index, 
						#'Measure had too many tracks in Section: %s Measure: ' % [s.name, m.number])
				tracks[index].append_array(track)
	
	return tracks.duplicate(true)


## Returns duration of song_file
func get_duration() -> float:
	assert(song_file, 'Chart %s failed to return duration because of missing song file' % Name)
	#var stream := AudioStreamMP3.new()
	#stream.set_data(FileAccess.get_file_as_bytes(song_file))
	var stream:AudioStream = load(song_file)
	return stream.get_length()


## Returns meta for first section
## keys are time_signature, key_signature, bpm
func get_starting_meta() -> Dictionary:
	var first_section:Section = sections.front()
	return {'time_signature': first_section.time_signature, 'key_signature': first_section.key_signature, 
				'bpm': first_section.bpm}


func get_num_notes() -> int:
	var count:int = 0
	for t in get_tracks():
		for ev in t:
			count += 1
	return count



func _get_signal_names(list:Array[Dictionary]) -> Array[String]:
	var out:Array[String] = []
	for sig in list:
		out.append(sig['name'])
	return out


func _benchmark() -> void:
	for s: Section in sections:
		print("< Section: %s	Type: %s	Time Signature: %s	BPM: %s- - - - - - - >\n" % [s.name, s.type, s.time_signature, s.bpm])
		
		for m: Measure in s.measures:
			print("\nMeasure #%s" % m.number)
			
			for ev: RhythmInputEvent in m.events:
				print("	%s	Build-up: %.3f	Start: %.3f	End: %.3f	Input-type: %s" % \
					[ev.note_key, ev.build_up, ev.start_time, ev.end_time, ev.get_input_type()])


#static func _filter_build_up_evs(ev_match:MidiData.NoteOn, build_ups:Array[RhythmInputEvent]) -> RhythmInputEvent:
	#var matching:Array[RhythmInputEvent] = []
	#var build_up_key:String = 'C#' if ev_match.note_key == 'C' else 'D#'
	#
	#for ev in build_ups:
		#if ev.note_key != build_up_key:
			#continue
		#matching.append(ev)
	#
	#if len(matching) > 1:
		#push_error("overlapping build_up events")
		#return null
	#
	#return matching.front()
	
	#return build_ups.filter(func(ev): return ev.is_same_note(ev_match))[0] as RhythmInputEvent


static func get_earliest_matching(ev_src, checking:Array[RhythmInputEvent], get_build_ups:bool = false) -> RhythmInputEvent:
	var earliest:RhythmInputEvent = null
	for ev in checking:
		var needs_to_match:String
		if get_build_ups and ev_src.note_key in ['C', 'D']:
			needs_to_match = 'C#' if ev_src.note_key == 'C' else 'D#'
		else:
			needs_to_match = ev_src.note_key
		
		if ev.note_key != needs_to_match:
			#prints(ev_src.note_key, ev.note_key, needs_to_match)
			continue
		
		if not earliest or (ev.start_time < earliest.start_time):
			earliest = ev
	
	return earliest
