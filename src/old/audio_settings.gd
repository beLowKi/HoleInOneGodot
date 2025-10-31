class_name AudioSettings extends Resource
## Stores AudioStreamPlayer settings

@export_range(-80, 24, 0.001) var volume_db:float = 0.0
@export_range(0.01,4,0.01,'or_greater') var pitch_scale:float = 1.0
@export var bus:StringName = &"Master"


@warning_ignore("shadowed_variable")
func _init(bus:StringName=&"Master", pitch_scale:float=1.0, volume_db:float=0.0):
	self.bus = bus
	self.pitch_scale = pitch_scale
	self.volume_db = volume_db

## Returns list of string propert_names
func get_list() -> Array[String]:
	return ['bus', 'pitch_scale', 'volume_db']

## adds settings to AudioStreamPlayer
func add_to_player(player:AudioStreamPlayer) -> void:
	for p in get_list():
		player.set(p, get(p))
