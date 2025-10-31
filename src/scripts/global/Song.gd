extends Node
## Dump for song-related constants


enum SECTION_TYPES {undefined, intro, A, B, C, prechorus, chorus, interlude, bridge, outro}
const NOTE_KEYS: Array[StringName] = [&"C", &"C#", &"D", &"D#", &"E", &"F", &"F#", &"G", &"G#", &"A", &"A#", &"B"]
const BUILD_UP_KEYS:Array[StringName] = [&"C#", &"D#"]	## Special Chart keys used to signify 'build_up' of each event
const INPUT_KEYS:Array[StringName] = [&'C', &'D']		## Keys that denote a RhythmInputEvent
const SPECIAL_KEYS:Array[StringName] = [&'E', &'F', &'G', &'A']
enum INPUT_KEYS_ENUM {C, D}
enum SPECIAL_NOTE_KEYS_ENUM {E, F, G, A}	## Reserved for noting special moments in charts for EventDisplays

enum BEATS {thirty_second, sixteenth, eighth, quarter, half, whole}
enum NOTE_POSITIONS {on_beat, sync_beat1, off_beat, sync_beat2}
enum KEY_SIGNATURES {TODO}	# TODO
enum TIME_SIGNATURES {two_four, three_four, four_four, five_four, six_eight, nine_eight, twelve_eight}




## Converts TIME_SIGNATURE values into string => four_four = '4/4'
func time_signature_to_string(ts:TIME_SIGNATURES) -> String:
	var string: String
	match ts:
		TIME_SIGNATURES.two_four:
			string = '2/4'
		TIME_SIGNATURES.four_four:
			string = '4/4'
		TIME_SIGNATURES.three_four:
			string = '3/4'
		TIME_SIGNATURES.six_eight:
			string = '6/8'
		TIME_SIGNATURES.nine_eight:
			string = '9/8'
		TIME_SIGNATURES.twelve_eight:
			string = '12/8'
	return string


func string_to_time_signature(string:String):
	match string:
		'2/4':
			return TIME_SIGNATURES.two_four
		'3/4':
			return TIME_SIGNATURES.three_four
		'4/4':
			return TIME_SIGNATURES.four_four
		'5/4':
			return TIME_SIGNATURES.five_four
		'4/4':
			return TIME_SIGNATURES.four_four
		'6/8':
			return TIME_SIGNATURES.six_eight
		'9/8':
			return TIME_SIGNATURES.nine_eight
		'12/8':
			return TIME_SIGNATURES.twelve_eight
		_:
			push_error('Invalid time signature %s' % string)
			return null


func ts_from_meta(meta:MidiData.TimeSignature) -> TIME_SIGNATURES:
	return string_to_time_signature("%s/%s" % [meta.numerator, meta.denominator])


## Splits and returns time signature with both values as integers
func split_time_signature(ts:String) -> Array[int]:
	var split = Array(ts.split('/'))
	var int_split:Array[int] = []
	for s in split: int_split.append(int(s))
	return int_split


## Returns [numerator, denominator] split for TIME_SIGNATURE enum values
func split_ts_enum(ts:TIME_SIGNATURES) -> Array[int]: 
	# FIXME returns just [0] when GameState doesn't have a time signature
	return split_time_signature(time_signature_to_string(ts))


func get_ts_numerator(ts:TIME_SIGNATURES) -> int:
	return split_ts_enum(ts)[0]

func get_ts_denominator(ts:TIME_SIGNATURES) -> int:
	return split_ts_enum(ts)[1]


## Returns the relevant track for the given INPUT_KEY note
func get_note_track(n:StringName) -> int: return INPUT_KEYS.find(n)


## Sorts notes according to NOTE_KEYS
## Starts at C and ends with B
func sort_notes(n1: String, n2: String) -> bool: 
	return Song.NOTE_KEYS.find(n2) >= Song.NOTE_KEYS.find(n1)


## Converts bpm to seconds per beat
func bpm_to_spb(bpm:float) -> float: 
	return 1 / (bpm / 60)


## Returns the time, in seconds, of the beat type in current
func beat_to_sec(beat:BEATS, dotted:bool=false) -> float:
	if not (GameState.bpm and GameState.time_signature):
		return -1.0
	
	var t:float = bpm_to_spb(GameState.bpm)
	
	## Multiplying or dividing seconds per beat
	match beat:
		Song.BEATS.thirty_second:
			t /= 8
		Song.BEATS.sixteenth:
			t /= 4
		Song.BEATS.eighth:
			t /= 2
		Song.BEATS.quarter:
			pass
		Song.BEATS.half:
			t *= 2
		Song.BEATS.whole:
			t *= 4
	
	## Adjusts for eighth note time signatures
	if Song.split_ts_enum(GameState.time_signature)[1] == 8:
		t *= 2
	
	## Dotted notes are 1.5 times longer
	if dotted: t *= 1.5
	return t


## Returns the time, in seconds, of a series of beats
## beats -> Array[[Song.BEAT, dotted:bool]]
func rhythm_to_sec(beats:Array[Beat]) -> float:
	var sec:float = 0
	for b in beats: 
		sec += beat_to_sec(b.duration, b.dotted)
	return sec
