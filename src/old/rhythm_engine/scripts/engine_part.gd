class_name EnginePart extends Node2D
## Base class for RhythmEngine parts

@onready var engine:RhythmEngine = get_parent()
var metronome:Metronome
var stylus:Stylus
var ssync:SoundSync


func _ready():
	engine.connect('ready', func(): 
		metronome = engine.metronome
		stylus = engine.stylus
		ssync = engine.ssync
		#player = engine.player
		)


func _process(_delta):
	pass


func sync_to_start(link:Callable, pickups:bool=false) -> void:
	if pickups: 
		metronome.connect('pickup_started', link)
	else:
		metronome.connect('started', link)


func desync(link:Callable) -> void:
	if metronome.is_connected('new_measure', link):
		metronome.disconnect('new_measure', link)
	else:
		metronome.disconnect('started', link)


func pause() -> void:
	pass
