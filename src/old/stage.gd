@tool
class_name Stage extends Node2D
"""

RHYTHM TIME

These are the scenes where songs or other rhythm-related things happen

< BASE REQUIREMENTS >

(some of these are done through other objects)

1. Take a Chart, read its events, and display them in time with the song
	-> the center (perfect radius) of each event should cross the marker/point at their 'start_time'
	-> needs to account for travel time (including startup animations), track length, and tolerance

2. React to player inputs
	-> tell events when they're activated so they can play animations, sfx, and do their things

3. Keep score
	-> activated notes add to the score based on how close the input time is to their 'start_time'
	-> have some "health" or whatever that fails the song if too many notes are missed
	-> missed notes are just 0

4. Universal compatibility
	-> Any stage should work for any chart and vice versa


< EXTRA BITS TODO AFTER (sort of ordered by priority) >

. Workout a way for songs to be paused and restarted at any point without it jarring the rhythm

. Rhythmic animation
	-> characters bop their head to the beat, the ui bounces with the drums , etc.

. Combo system that increases how many points are earned during streaks
	-> should have varying degrees of "combo" that could emit signals so that other things can react to it
		(i.e. bonus animations like in rhythm heaven)


< HOW THIS'LL WORK - (roughly) >

	This should be INCREDIBLY modular--each piece should be able to be dragged and dropped into a stage and
configured to fit it. Although the demo will be a simple recreation of Hole in One from Rhythm Heaven Fever,
not every stage is going to be a simple "shoot events down some predetermined track and have the player hit 
it" type. Some may have more complex/custom animations, so everything needs to be done through signals. Using
the RhythmEngine as a hub, each stage of an event's life cycle should emit something that informs its
displayer.

Input types:

Single-press - one button press

Single-hold - one button hold

Double-press - ^^ * 2

Double-hold - ^^ * 2

Multi-step (TODO come up with a better name)
	events that are a combination of single and double presses or holds (i.e. starts as double-hold but
		one button is released a little before the other)

Bend - mouse/analog stick control that simulates whammy bar of guitar or synth pitch bend
	More of a modifier than

"""

## scores => {
##	'total' : TODO enum{F, D, C, B, A, S},
##	Utils.SCORES : int "number of those scores" for each score
##}
@warning_ignore("unused_signal")
signal song_ended(failed:bool, scores:Dictionary)

@export var chart:Chart
@export var difficulty:Utils.DIFFICULTIES = Utils.DIFFICULTIES.NORMAL

@export_group("Details")

## Displays that will visually represent RhythmInputEvents in the chart
@export var event_displays:Array[EventDisplay]

## Begins as soon as events are loaded
@export var autostart:bool = true

@onready var displays_node:Node2D
@onready var rhythm_engine:RhythmEngine = $RhythmEngine
@onready var timer_dump:Node2D = $timer_dump
@onready var anim:AnimationPlayer = $AnimationPlayer

var total_score:int = 0
var scores:Dictionary = {
	'num_perfects': 0,
	'num_greats': 0,
	'num_mehs': 0,
	'num_misses': 0		}
#var active:bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	#rhythm_engine.connect('ready', _prep)
	#rhythm_engine.metronome.connect('pickup_started', begin)
	Signals.connect('bpm_changed', _on_meta_config)
	Signals.connect('time_signature_changed', _on_meta_config)
	Signals.connect('song_ended', _on_song_end)
	Signals.connect('event_activated', _on_event_activated)
	Signals.connect('event_missed', _on_event_missed)
	
	_prep()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		
		# Adds 'displays' node to hold all EventDisplays and auto adds valid ones to 'event_displays'
		if not find_child('displays'):
			var n := Node2D.new()
			n.name = 'displays'
			add_child(n)
		
		if not displays_node:
			displays_node = $displays
		
		update_configuration_warnings()
		return


func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray = []
	
	if not chart:
		warnings.append('Stage missing chart')
	
	if displays_node:
		var non_displays:Array[String] = []
		
		for n in displays_node.get_children():
			if not (n is EventDisplay):
				non_displays.append(n.name)
		
		if non_displays:
			warnings.append('Non-display inside of displays node: %s' % non_displays)
	
	return warnings


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                          STAGE FUNCTIONS                                        #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

func _on_meta_config() -> void:
	pass


func _prep() -> void:
	rhythm_engine.set_chart(chart)
	var events = rhythm_engine.stylus.get('queued_events').duplicate()
	for ev:RhythmInputEvent in events:
		var time_until:float = ev.start_time - ev.build_up
		var displays := get_displays_for(ev)
		var t := Timer.new()
		t.wait_time = time_until
		t.one_shot = true
		Signals.connect('song_started', t.start)
		timer_dump.add_child(t)
		
		for d in displays:
			t.connect('timeout', func(): d.add_event(ev))
		#ev.connect('missed', func(event): events.erase(event))
	
	#if autostart:
		#countdown()


func get_displays_for(ev:RhythmInputEvent) -> Array[EventDisplay]:
	var displays:Array[EventDisplay] = []
	
	for dis in event_displays:
		if dis.can_add_event(ev):
			displays.append(dis)
	
	return displays


func begin() -> void:
	assert (chart, "Stage is missing chart")
	#active = true


func pause() -> void:
	pass


func get_max_score() -> int:
	#if not chart:
		#return 0
	return chart.get_num_notes() * Utils.SCORES.PERFECT




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                             OVERRIDES                                           #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

func countdown() -> void:
	pass


func _on_song_end() -> void:
	#print('# Notes: %s Total Score: %s\t' % [chart.get_num_notes(), total_score])
	#prints(scores)
	pass


func _on_event_activated(_ev:RhythmInputEvent, score:Utils.SCORES, _offset:float) -> void:
	match score:
		Utils.SCORES.PERFECT:
			scores['num_perfects'] += 1
		Utils.SCORES.GREAT:
			scores['num_greats'] += 1
		_:
			scores['num_mehs'] += 1
	total_score += score


func _on_event_missed(_ev:RhythmInputEvent) -> void:
	scores['num_misses'] += 1
