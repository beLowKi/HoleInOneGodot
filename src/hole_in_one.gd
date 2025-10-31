@tool
@icon("res://src/assets/textures/hole_in_one_icon.png")
extends Stage

# TODO loop end songs more smoothly with a cross fade
# TODO weigh mandrill notes a bit more
# TODO to make the monkey miss golf ball look a bit better, you could use
# an AnimationPlayer like what's used for mandril balls, but you'd likely need
# to instantiate a new ball and player each time since monkey misses can overlap

enum Grade {
	TRY_AGAIN,
	OK,
	SUPERB,
	PERFECT
	}

# Counts for notes in each section (anims/environment changes mid-song)
# since I haven't figured out chart sections yet.
# 1 == monkey 2 == mandril
#111111111			- mandrill bends arms more
#111111112			- mandrill double fist bump, seagull mid mandrill throw
#111111111111112	- water spouts
#111111111111112	- water spouts retract with beat of mandrill
#112112				- mandrill back to starting idle
#11111112			- rainbow fades in
#12					- nothin
const SECTIONS_NOTES:Array[int] = [9, 9, 15, 15, 6, 8, 2]

const SUPERB_GRADE:float = 87.0
const SUPERB_ENDING_IMG := \
	preload('res://src/assets/textures/endings/superb_end_screen.tres')
const SUPERB_ENDING_MSG:String = 'Championship title, here we come!'
const SUPERB_ENDING_MUSIC := preload('res://src/assets/sfx/superb_ending.wav')
const OK_ENDING_IMG := \
	preload('res://src/assets/textures/endings/ok_ending_screen.tres')
const OK_ENDING_MSG:String = 'That was a great swing!'
const OK_ENDING_MUSIC := preload('res://src/assets/sfx/ok_ending.wav')
const TRY_AGAIN_GRADE:float = 65.0
const TRY_AGAIN_ENDING_IMG := \
	preload('res://src/assets/textures/endings/try_again_end_screen.tres')
const TRY_AGAIN_ENDING_MSG:String = 'This is even more painful than it looks'
const TRY_AGAIN_ENDING_MUSIC := preload('res://src/assets/sfx/try_again.wav')

const NUM_MONKEY_NOTES:int = 57
const NUM_MANDRILL_NOTES:int = 7

const MONKEY_NO_LIKE_THRESHOLD:int = roundi(NUM_MONKEY_NOTES * 0.33)
const MONKEY_IMPRESS_THRESHOLD:int = roundi(NUM_MONKEY_NOTES * 0.9)
const MONKEY_APPROVE_MESSAGE:String = 'The monkey was very impressed!'
const MONKEY_NO_LIKE_MESSAGE:String = 'The monkey seemed disappointed.'

const MANDRILL_NO_LIKE_THRESHOLD:int = roundi(NUM_MANDRILL_NOTES * 0.33) 
const MANDRILL_IMPRESS_THRESHOLD:int = roundi(NUM_MANDRILL_NOTES * 0.9)
const MANDRILL_APPROVE_MESSAGE:String = \
	'...And your mandrill friend says you did well.'
const MANDRILL_NO_LIKE_MESSAGE:String = \
	'...And that mandrill looked a little down.'

const MEDIOCRE_MESSAGE:String = 'Eh, good enough.'
const BARELY_OK_MSG:String = '...but still just...'
const LONE_POSITIVE_OK_MSG:String = '...but just...'

const SIMIAN_FEEDBACK_PAUSE:float = 0.86
const GRADE_REVEAL_TO_MUSIC_PAUSE:float = 0.23
const ENDING_REVEAL_EXTRA_PAUSE:float = 0.73

const SUPERB_MUSIC := preload("res://src/assets/sfx/superb_music.wav")
const SUPERB_SFX := preload('res://src/assets/sfx/superb.wav')
const OK_MUSIC := preload("res://src/assets/sfx/ok_music.wav")
const OK_SFX := preload("res://src/assets/sfx/ok.wav")
const TRY_AGAIN_MUSIC := preload("res://src/assets/sfx/try_again_music.wav")
const TRY_AGAIN_SFX := preload("res://src/assets/sfx/try_again.wav")
const WATER_SPLOOSH := preload("res://src/assets/sfx/ball_in_water1.wav")
const BIG_WATER_SPLOOSH := preload("res://src/assets/sfx/ball_in_water2.wav")
const A_PRESS_SFX := preload('res://src/assets/sfx/ui_select2.wav')

const RAINBOW_FADE_TIME := Song.BEATS.whole
const SEAGULL_DUR := Song.BEATS.whole

@onready var intro_screen:CanvasLayer = $IntroScreen
@onready var end_screens:CanvasLayer = $EndScreens
@onready var feedback_screen:Control = $EndScreens/Feedback
@onready var simian_feedback:Label = $EndScreens/Feedback/SimianFeedback
@onready var review_label:Label = $EndScreens/Feedback/ChartReview
@onready var stage_grade:AnimatedSprite2D = $EndScreens/Feedback/StageGrade
@onready var ok_extra_label:Label = $EndScreens/Feedback/StageGrade/ButStillJust
@onready var feedback_A:AnimatedSprite2D = $EndScreens/Feedback/StageGrade/AButton
@onready var ending_screen:Control = $EndScreens/Ending
@onready var end_img:TextureRect = \
	$EndScreens/Ending/MarginContainer/VBoxContainer/Image
@onready var end_desc:Label = \
	$EndScreens/Ending/MarginContainer/VBoxContainer/Description
@onready var ending_A:AnimatedSprite2D = \
	$EndScreens/Ending/MarginContainer/VBoxContainer/CenterContainer/AButton
@onready var ball_flight_path:GolfBallFlightPath = \
	$displays/Golfer/GolfBallFlightPath
@onready var water_spouts:Array[WaterSpout] = [
	$Environment/WaterSpout1,
	$Environment/WaterSpout2,
	$Environment/WaterSpout3
	]
@onready var mandrill:Mandrill = $displays/Mandrill
@onready var mandrill_miss_anim:AnimationPlayer = $MandrillMissAnim
@onready var cutin:GolfHoleCutin = $displays/GolfHoleCutin
@onready var ending_music_player:AudioStreamPlayer = $EndingMusicPlayer
@onready var grade_music_player:AudioStreamPlayer = $GradeMusicPlayer
@onready var review_player:AudioStreamPlayer = $ReviewsPlayer
@onready var grade_reveal_player:AudioStreamPlayer = $GradeRevealPlayer
@onready var water_sploosh_player:AudioStreamPlayer = $WaterSplooshSFX
@onready var loop_timer:Timer = $LoopTimer

var scored_perfect:bool = false
var _section:int = 0
var _notes_this_section:int = 0
var _grade := Grade.OK:
	set(val):
		_grade = val
		match _grade:
			Grade.TRY_AGAIN:
				grade_music_player.stream = TRY_AGAIN_MUSIC
				grade_reveal_player.stream = TRY_AGAIN_SFX
				end_img.texture = TRY_AGAIN_ENDING_IMG
				end_desc.text = TRY_AGAIN_ENDING_MSG
				ending_music_player.stream = TRY_AGAIN_ENDING_MUSIC
			Grade.OK:
				grade_music_player.stream = OK_MUSIC
				grade_reveal_player.stream = OK_SFX
				end_img.texture = OK_ENDING_IMG
				end_desc.text = OK_ENDING_MSG
				ending_music_player.stream = OK_ENDING_MUSIC
			Grade.SUPERB:
				grade_music_player.stream = SUPERB_MUSIC
				grade_reveal_player.stream = SUPERB_SFX
				end_img.texture = SUPERB_ENDING_IMG
				end_desc.text = SUPERB_ENDING_MSG
				ending_music_player.stream = SUPERB_ENDING_MUSIC
			Grade.PERFECT:
				#grade_music_player.stream = PERFECT_MUSIC
				#grade_reveal_player.stream = PERFECT_SFX
				pass
var _max_score:int = 0
var _total_notes:int = 0
var _monkey_balls_missed:int = 0
var _mandrill_balls_missed:int = 0


func _ready() -> void:
	super()
	
	if Engine.is_editor_hint(): return
	
	_max_score = get_max_score()
	end_screens.hide()
	feedback_screen.hide()
	ending_screen.hide()
	#chart._benchmark()
	
	#var num_c:int = 0
	#var num_d:int = 0
	#for track in chart.get_tracks():
		#for note in track:
			#if note.note_key == 'C':
				#num_c += 1
			#elif note.note_key == 'D':
				#num_d += 1
	#print('Monkey Notes: %s\nMandrill Notes: %s' % [num_c, num_d])
	
	grade_reveal_player.finished.connect(_on_grade_reveal_sfx_ended)
	grade_music_player.finished.connect(grade_music_player.play)
	Signals.beat.connect(_on_beat)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Button1"):
		if intro_screen.visible && !anim.is_playing():
			Funcs.fade_into(Color.BLACK, 1.2/2, true)
			get_tree().create_timer(1.2/2.2).timeout.connect(func(): 
				intro_screen.hide()
				Funcs.fade_outof(Color.BLACK, 1.2/2, true)
				get_tree().create_timer(0.3).timeout.connect(countdown)
				)
		elif feedback_screen.visible:
			# Stealing the reviews player since it isn't doing anything
			review_player.stream = A_PRESS_SFX
			review_player.play()
			feedback_A.play("Pressed")
			await feedback_A.animation_finished
			
			# Fade out
			var tw := Funcs.fade_into(Color.BLACK, 2.15, false, 101)
			create_tween().tween_property(grade_music_player, 'volume_db', -20.0, 1.85)
			await tw.finished
			feedback_screen.hide()
			end_screens.layer = 102
			grade_music_player.stop()
			loop_timer.stop()
			
			# Fade in - barely noticeable
			#tw = Funcs.fade_outof(Color.BLACK, 1.25, true, 99)
			#await tw.finished
			await get_tree().create_timer(ENDING_REVEAL_EXTRA_PAUSE).timeout
			
			anim.play('Ending')
			ending_music_player.play()
		elif ending_screen.visible:
			review_player.play()
			ending_A.play("Pressed")
			await ending_A.animation_finished
			
			GameState.fade_into_menu = true
			var tw := Funcs.fade_into(Color.BLACK, 0.85, false, 999)
			tw.tween_callback(func():
				var tree := get_tree()
				await tree.create_timer(0.5).timeout
				tree.reload_current_scene()
				)

func countdown() -> void:
	_total_notes = chart.get_num_notes()
	rhythm_engine.start_song()
	#Funcs.fade_outof(Color.BLACK)
	#print(get_max_score())

func start_grade_gif() -> void:
	match _grade:
		Grade.TRY_AGAIN:
			stage_grade.play('TryAgain')
		Grade.OK:
			stage_grade.play('Ok')
		Grade.SUPERB:
			stage_grade.play('Superb')
		Grade.PERFECT:
			push_error('Grade.PERFECT not implemented')


func _on_grade_reveal_sfx_ended() -> void:
	#set_process_input(true)
	await get_tree().create_timer(GRADE_REVEAL_TO_MUSIC_PAUSE).timeout
	
	# Queueing cross fade
	var time := grade_music_player.stream.get_length()
	loop_timer.wait_time = time - 3.0
	loop_timer.timeout.connect(_crossfade_player.bind(grade_music_player, 3))
	grade_music_player.play()
	loop_timer.start()

func _on_song_end() -> void:
	Signals.beat.connect(func():
		if cutin.anim.is_playing(): await cutin.anim.animation_finished
		rhythm_engine.stop(), 
		CONNECT_ONE_SHOT
		)
	#rhythm_engine.stop()
	
	var score_perc:float
	if total_score > 0.0:
		score_perc = ( float(total_score) / _max_score ) * 100.0
	else:
		score_perc = 0.0
	
	# Grading
	if score_perc >= SUPERB_GRADE:
		_grade = Grade.SUPERB
	elif score_perc <= TRY_AGAIN_GRADE:
		_grade = Grade.TRY_AGAIN
	else:
		_grade = Grade.OK
	
	print_rich('\n[color=yellow]RESULTS')
	print('\tMax possible score: %s' % _max_score)
	print('\tTotal Score: %s' % total_score)
	print('\tGrading: %.2f - %s' % [score_perc, Grade.find_key(_grade)])
	print('\tPerfects: %s' % scores['num_perfects'])
	print('\tMisses: %s' % (_monkey_balls_missed + _mandrill_balls_missed))
	
	# Fade out
	var tw := Funcs.fade_into(Color.BLACK, 1.25, false)
	
	# PERFECT TODO special display?
	# og game doesn't do Simian feedback when doing that unique
	# perfect screen
	#if grade == 100.00:
		#pass
	
	# Simian Feedback
	var monkey_balls_hit:int = NUM_MONKEY_NOTES - _monkey_balls_missed
	var monkey_happy:bool = monkey_balls_hit >= MONKEY_IMPRESS_THRESHOLD
	var monkey_msg:String = ''
	if monkey_happy:
		monkey_msg = MONKEY_APPROVE_MESSAGE
	elif _monkey_balls_missed >= MONKEY_NO_LIKE_THRESHOLD:
		monkey_msg = MONKEY_NO_LIKE_MESSAGE
	
	var mandrill_balls_hit:int = NUM_MANDRILL_NOTES - _mandrill_balls_missed
	var mandrill_happy:bool = mandrill_balls_hit >= MANDRILL_IMPRESS_THRESHOLD
	var mandrill_msg:String
	if mandrill_happy:
		mandrill_msg = MANDRILL_APPROVE_MESSAGE
	elif _mandrill_balls_missed >= MANDRILL_NO_LIKE_THRESHOLD:
		mandrill_msg = MANDRILL_NO_LIKE_MESSAGE
	print('\tMonkey - %s' % ['Happy' if monkey_happy else 'Sad'])
	print('\t\t%s' % (monkey_msg if monkey_msg else '> No message'))
	print('\tMandrill - %s' % ['Happy' if mandrill_happy else 'Sad'])
	print('\t\t%s' % (mandrill_msg if mandrill_msg else '> No message'))
	
	# Removing the ...And when monkey msg is empty
	if mandrill_msg and !monkey_msg:
		mandrill_msg = mandrill_msg.replace('...And ', '')
		mandrill_msg[0] = mandrill_msg[0].capitalize()
	
	# Setting feedback text
	if !(monkey_msg.is_empty() and mandrill_msg.is_empty()):
		
		# Configuring extra OK messages
		if _grade == Grade.OK:
			var monkey_fedback_pos:bool = monkey_msg and monkey_happy
			var mandrill_fed_back_pos:bool =  mandrill_msg and mandrill_happy
			#prints(monkey_fedback_pos, mandrill_fed_back_pos)
			
			if monkey_fedback_pos and mandrill_fed_back_pos:
				ok_extra_label.text = BARELY_OK_MSG
			elif monkey_fedback_pos or mandrill_fed_back_pos:
				ok_extra_label.text = LONE_POSITIVE_OK_MSG
			else:
				ok_extra_label.text = ''
			ok_extra_label.show()
		
		review_label.text = "%s\n%s" % [monkey_msg, mandrill_msg]
	
	else:
		review_label.text = MEDIOCRE_MESSAGE
	
	# Animation of text and gif being revealed
	if tw.is_running(): await tw.finished
	end_screens.show()
	await get_tree().create_timer(SIMIAN_FEEDBACK_PAUSE).timeout
	anim.play('GradeReveal')

func _on_event_activated(
	ev:RhythmInputEvent, 
	score:Utils.SCORES, 
	offset:float
) -> void:
	
	super(ev, score, offset)
	_notes_this_section += 1
	
	# MEHs will count as misses
	if score == Utils.SCORES.MEH:
		# Slight delay so it doesn't happen immediately for events
		# activated on or slightly before a beat
		get_tree().create_timer(0.12).timeout.connect(func():
			Signals.beat.connect(
				func(): _on_ball_landed_in_water(ev.note_key=='D'),
				CONNECT_ONE_SHOT
				),
			CONNECT_ONE_SHOT
			)
		Signals.event_missed.emit(ev, true)

func _on_beat() -> void:
	if SECTIONS_NOTES.size() <= _section: return
	var section_break:int = SECTIONS_NOTES[_section]
	
	# Seagulls start on last note of first section
	if _section == 1 && _notes_this_section == ( section_break - 1 ):
		# Seagull
		print('playing seagulls')
		# FIXME sometimes this triggers like 4-5 times?
		if anim.current_animation != 'Seagull': 
			var target_time := Song.beat_to_sec(SEAGULL_DUR)
			var speed_scale := \
				anim.get_animation('Seagull').length / target_time
			anim.play('Seagull', -1, speed_scale)
	
	# Water spouts retract on-beat with last mandrill note of this section
	elif _section == 3 && _notes_this_section == section_break - 2:
		water_spouts.front().retract()
		var beat_dur := Song.beat_to_sec(Song.BEATS.quarter)
		get_tree().create_timer(beat_dur) \
			.timeout.connect(water_spouts[1].retract)
		get_tree().create_timer(beat_dur*2) \
			.timeout.connect(water_spouts[2].retract)
	
	# Section changes
	if _notes_this_section >= section_break:
		#print('Moving to section %s' % (_section+1))
		
		var section:int = _section
		Signals.beat.connect(func():
			match section:
				# Mandrill gets a little pep in his idle
				0: mandrill.current_bop = Mandrill.BopAnims.EXCITED
				
				# Mandrill starts double fist pumping
				1: 
					mandrill.current_bop = Mandrill.BopAnims.DOUBLE_FIST_PUMP
					mandrill.bop()
				
				# Mandrill goes back to starting idle
				4: mandrill.current_bop = Mandrill.BopAnims.CHILL
			,
			CONNECT_ONE_SHOT
			)
		
		# This stuff shouldn't be buffered
		match _section:
			# Water spouts 
			2:
				for ws in water_spouts: 
					ws.spout()
					ws.show()
			
			# Rainbow
			5:
				var target_time := Song.beat_to_sec(RAINBOW_FADE_TIME)
				var speed_scale := \
					anim.get_animation('Rainbow').length / target_time
				anim.play('Rainbow', -1, speed_scale)
		
		_notes_this_section = 0
		_section += 1

func _on_event_missed(ev:RhythmInputEvent, meh:bool=false) -> void:
	super(ev)
	
	if !meh:
		if ev.note_key == 'D':
			var time := Song.beat_to_sec(Song.BEATS.whole)
			var speed_scale := \
				mandrill_miss_anim.get_animation("Miss").length / time
			mandrill_miss_anim.play("Miss", -1, speed_scale)
		_notes_this_section += 1
	
	if ev.note_key == 'C':
		#print('monkey ball missed')
		_monkey_balls_missed += 1
	elif ev.note_key == 'D':
		#print('mandrill ball missed')
		_mandrill_balls_missed += 1
	else:
		push_error('Weird unexpected event: %s' % ev)

func _on_ball_landed_in_water(big:bool) -> void:
	#if water_sploosh_player.playing: water_sploosh_player.stop()
	if big:
		water_sploosh_player.stream = BIG_WATER_SPLOOSH
	else:
		water_sploosh_player.stream = WATER_SPLOOSH
	water_sploosh_player.play()

func _crossfade_player(p:AudioStreamPlayer, t:float) -> void:
	#print('crossfading %s' % p)
	
	# Fade in player
	var fade_in := p.duplicate()
	p.get_parent().add_child(fade_in)
	fade_in.volume_db = -20.0
	
	# Fading initial player
	var tw := create_tween()
	tw.tween_property(p, 'volume_db', -20.0, t)
	
	# Fading fade_in in
	fade_in.play()
	tw.parallel().tween_property(fade_in, 'volume_db', p.volume_db, t * 0.6)
	
	# Restarting initial player
	tw.tween_callback(func(): 
		p.volume_db = fade_in.volume_db
		p.play(fade_in.get_playback_position())
		)
	tw.tween_callback(fade_in.queue_free)
