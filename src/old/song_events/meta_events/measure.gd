class_name Measure extends MetaEvent
## Contains events, and tempo and time signature information

@export_storage var events:Array[RhythmInputEvent]
@export_storage var number: int
@export_storage var unique_notes:Array[String]


static func new_measure(num:int) -> Measure:
	var m := Measure.new()
	m.number = num
	m.events = []
	m.unique_notes = []
	return m


func add_note(ev: RhythmInputEvent) -> void:
	if not unique_notes.has(ev.note_key): 
		#print('unique note %s added to %s' % [ev.note_key, number])
		unique_notes.append(ev.note_key)
		unique_notes.sort_custom(Song.sort_notes)
	events.append(ev)


func check_missing(note_key: String) -> RhythmInputEvent:
	for ev in events:
		if (ev.note_key == note_key) and not (ev.end_time): return ev
	return null


func is_finished() -> bool:
	return events.any(func(ev: RhythmInputEvent): return (ev.end_time != null))


func get_note_tracks() -> Array[Array]:
	var tracks: Array[Array]  = []
	for i in range(len(unique_notes)): tracks.append([])
	for ev: RhythmInputEvent in events:
		var index = unique_notes.find(ev.note_key)
		if index == -1:
			#prints(unique_notes, ev.note_key)
			pass
		tracks[index].append(ev)
	
	for t in tracks:
		var note: String = t[0].note_key
		for ev:RhythmInputEvent in t:
			assert(ev.note_key == note, "Uh oh tracks didn't sort right")
	
	return tracks
