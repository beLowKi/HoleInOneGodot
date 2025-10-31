class_name SoundSync extends EnginePart
## Handles all Chart-based audio to ensure that it's on-beat. Has a default number of AudioStreamPlayers
## as children and adds more if needed
##
## Plays the Chart's song_file, sound effects for hitting or missing notes, as well as any extra event sfx
## added later


#@export_range(1, 8, 1, 'or_greater') var default_number_of_players:int	## Number of preloaded AudioStreamPlayers

@export var default_number_of_players:int

@onready var song_player:AudioStreamPlayer = $SongPlayer
@onready var players_node:Node2D = $AudioPlayers

var BUS:StringName = &"Master"	# NOTE change later when doing audio mixing and whatnot
var playing:bool = false


func _ready():
	super()
	for i in range(default_number_of_players): _add_player()
	Signals.connect('song_changed', set_song)
	engine.connect('sound_played', _on_sound_played)
	song_player.connect('finished', func(): Signals.emit_signal('song_ended'))


func _process(_delta):
	pass


####################################################################################################
####################################################################################################
####################################################################################################


func _add_player() -> void:
	var p := AudioStreamPlayer.new()
	p.set('bus', BUS)
	# TODO default volume -> p.volume_db = SETTINGS.VOLUME['sfx'] or something like that
	players_node.add_child(p)


## NOTE Godot only supports WAV Ogg Vorbis, and MP3
func _get_stream_from_file(p:String) -> AudioStream:
	#var f := FileAccess.open(p, FileAccess.READ)
	#var stream:AudioStream
	#match p.get_extension():
		#'mp3':
			#stream = AudioStreamMP3.new()
		#'wav':
			#stream = AudioStreamWAV.new()
		#'ogg', 'oga':
			#stream = AudioStreamOggVorbis.new()
		#_:
			#push_error('Unsupported audio file %s' % p.get_extension())
	#stream.data = f.get_buffer(f.get_length())
	return load(p)


func _get_players() -> Array:
	return players_node.get_children()


func _get_available_player() -> AudioStreamPlayer:
	var available:Array
	while not available:
		available = _get_players().filter(func(p): return not p.playing)
		if not available: _add_player()
	return available.front() as AudioStreamPlayer


func _on_sound_played(src, settings:AudioSettings) -> void:
	var p := _get_available_player()
	settings.add_to_player(p)
	var stream = src if src is AudioStream else _get_stream_from_file(src)
	p.set('stream', stream)
	p.play()


func _on_song_start() -> void:
	Signals.song_started.emit()
	song_player.play()
	playing = true



## Sets the current song using path to audio file
func set_song(src) -> void:
	if not (src is String or src is AudioStream): 
		push_error('Invalid set_song for src = %s' % src)
		return
	song_player.stream = _get_stream_from_file(src) if src is String else src


func start_on_next() -> void:
	sync_to_start(_on_song_start)
