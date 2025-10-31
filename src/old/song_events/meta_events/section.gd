class_name Section extends MetaEvent
## Section containing Measures

@export var name: String = 'N/A'
@export var type: Song.SECTION_TYPES
@export_range(1,200,0.5,'or_greater') var bpm:float:
	set(v):
		bpm = v
		# TODO update event times
@export_multiline var descrption:String
@export_storage var measures: Array[Measure]
@export_storage var time_signature: Song.TIME_SIGNATURES
@export_storage var key_signature: Song.KEY_SIGNATURES		# Not sure if this will do anything yet or just be flavor
@export_storage var num_tracks: int
@export_storage var us_per_beat:int


static func new_section(n: String, time:float, temp:MidiData.Tempo, new_ts:MidiData.TimeSignature) -> Section:
	var sect := Section.new()
	sect.name = n
	sect.type = Song.SECTION_TYPES.undefined
	sect.start_time = time
	sect.bpm = temp.bpm
	sect.us_per_beat = temp.us_per_beat
	sect.measures = []
	sect.time_signature = Song.ts_from_meta(new_ts)
	return sect


## Adds a measure to the section
func add_measure(m: Measure) -> void:
	if len(m.unique_notes) > num_tracks: 
		num_tracks = len(m.unique_notes)
	measures.append(m)
