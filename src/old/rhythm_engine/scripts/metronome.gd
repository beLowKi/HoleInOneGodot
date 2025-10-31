class_name Metronome extends EnginePart
## Rhythm-tracker. Each beat (on, off, sixteenth, etc.) creates an area2D along an off-screen line.
## Being on-rhythm means inputting while that given beat is colliding with the tracker; the distance
## from its center determining score.


## Prestart measure
signal pickup_started
## Emitted after first primary beat when calling start() for syncing
signal started
## Called on configuration
signal finished_config
## Just tracks next measure, doesn't contain it though
signal new_measure


# @export_range(1, 4, 1) var pick_up_measures:int

@export var pick_up_measures:int

@export_subgroup('Misc')
@export_file('*.mp3', '*.wav', '*.ogg', '*.oga') var tick_sound_file:String
@export var tick_sound	:bool = false

@onready var timers_node: Node2D = $Timers  ## Timer dump
@onready var prestart_timer:Timer = $PrestartTimer
@onready var beat:Signal = Signals.beat

enum TICK_TYPES {primary, secondary, tertiary}
var timers: Dictionary = {
	'primary': null,
	'secondary': null,
	'secondary_offset': null,
	'tertiary': null,
	'tertiary_offset': null}
var running: bool = false
var pick_up_beats:int
var beat_count:int = 0


func _ready():
	super()
	#connect("started", Signals.song_started.emit)
	Signals.connect('time_signature_changed', func(): config())
	Signals.connect('bpm_changed', func(): config())


func _process(_delta):
	#print(get_prestart_time())
	pass


####################################################################################################
####################################################################################################
####################################################################################################


## Configure metronome to current time_signature and bpm
## Needs to be called manually by the RhythmEngine because otherwise it would trigger off of every single
## subsequent change after a chart is loaded
func config():
	_set_timers()
	
	pick_up_beats = Song.split_ts_enum(GameState.time_signature)[0] * pick_up_measures 
	
	#prints(pick_up_beats, pick_up_measures)
	
	prestart_timer.wait_time = Song.bpm_to_spb(GameState.bpm) * pick_up_beats
	finished_config.emit()


## Returns time until 'started' should emit as negative float
func get_prestart_time() -> float: 
	return -prestart_timer.time_left if not prestart_timer.is_stopped() else 0.0


func start():
	if running:
		return
	
	pickup_started.emit()
	prestart_timer.start()
	
	# Begins and waits for first primary before syncing the rest
	timers['primary'].start()


func stop():
	if not running: return
	for t in timers.values():
		t.stop()
	running = false
	timers['primary'].connect('timeout', _sync_timers)


func _reset():
	for t in timers.values():
		t = null


func _set_timers():
	_reset()
	
	# Getting beats per second for primary timer
	# Each var pertains to the beat types
	var bps: = GameState.bpm / 60.0
	
	var primary: Timer = Timer.new()
	primary.wait_time = 1.0 / bps
	
	# Secondary and tertiary start at an offset
	# Their wait times aren't the actual time between their respective beats because
	# they would overlap with each other
	var secondary_offset: Timer = Timer.new()
	var secondary: Timer = Timer.new()
	secondary.wait_time = primary.wait_time
	
	var tertiary_offset: Timer = Timer.new()
	var tertiary: Timer = Timer.new()
	
	# Assigning based on time signature
	match Song.split_ts_enum(GameState.time_signature)[0]:
		4:
			secondary_offset.wait_time = primary.wait_time / 2.0
		8:
			secondary_offset.wait_time = primary.wait_time * (2.0 / 3.0)
	
	# Same for both
	# distance between tertiaries is secondary offset time
	tertiary.wait_time = secondary_offset.wait_time
	
	# Tertiary offset is half secondary offset
	tertiary_offset.wait_time = secondary_offset.wait_time / 2.0
	
	# Timer settings
	for t: Timer in [primary, secondary, secondary_offset, tertiary, tertiary_offset]:
		if t in [secondary_offset, tertiary_offset]:
			t.one_shot = true
		timers_node.add_child(t)
	
	# Adding to dict; yes, I know it's ugly lookin
	timers['primary'] = primary
	timers['secondary'] = secondary
	timers['secondary_offset'] = secondary_offset
	timers['tertiary'] = tertiary
	timers['tertiary_offset'] = tertiary_offset
	
	# Primary config
	#primary.connect('timeout', _on_start)
	primary.connect('timeout', _sync_timers)
	timers['primary'].connect('timeout', func(): _on_tick(TICK_TYPES.primary))
	
	# Secondary config
	secondary.connect('timeout', func(): _on_tick(TICK_TYPES.secondary))
	secondary_offset.connect('timeout', secondary.start)
	
	# Tertiary config
	tertiary.connect('timeout', func(): _on_tick(TICK_TYPES.tertiary))
	tertiary_offset.connect('timeout', tertiary.start)




func _on_tick(type:TICK_TYPES) -> void:
	if beat_count >= pick_up_beats:
		if not running: 
			timers['primary'].connect('timeout', _on_start)
		else: new_measure.emit()
		beat_count = 1
	
	#var audio_settings := AudioSettings.new()
	match type:
		TICK_TYPES.primary:
			beat.emit()
			#audio_settings.volume_db = -4.0
			#engine.sound_played.emit(tick_sound_file, audio_settings)
			beat_count += 1
		TICK_TYPES.secondary:
			# player.volume_db = -9.0
			# player.pitch_scale = 1.5
			pass
		TICK_TYPES.tertiary:
			# player.volume_db = -10.0
			# player.pitch_scale = 2
			pass


func _sync_timers() -> void:
	timers['primary'].disconnect('timeout', _sync_timers)
	timers['secondary_offset'].start()
	timers['tertiary_offset'].start()


func _on_start():
	running = true
	timers['primary'].disconnect('timeout', _on_start)
	started.emit()
