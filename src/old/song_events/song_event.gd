class_name SongEvent extends Resource
## Base class for all rhythm-based events that are usually used to expect some kind of input.
## Could be a note, an obstacle, or any other cue.

@warning_ignore("unused_signal")
signal event_ended
@warning_ignore("unused_signal")
signal started

@export_storage var start_time: float
@export_storage var end_time: float :
	set(t):
		end_time = t
@export_storage var delta_time: int


# TODO test that this works and doesn't reset variables
#func _init() -> void:
	#self.start_time = start_time
	#self.end_time = end_time
	#self.delta_time = delta_time


func get_duration() -> float: 
	@warning_ignore("incompatible_ternary")
	return (end_time - start_time) if end_time > start_time else 0
