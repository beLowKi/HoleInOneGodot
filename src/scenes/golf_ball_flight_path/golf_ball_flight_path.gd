@tool
class_name GolfBallFlightPath extends Path2D
## this will be the golf ball that flies off after being hit by a Golfer

# TODO make early late flightpath shorter

signal flight_ended(end_pt:Vector2)

const BALL_FOLLOW_SCENE := preload("res://src/scenes/golf_ball_flight_path/components/ball_follow/ball_follow.tscn")
const SHADOW_FOLLOW_SCENE := preload("res://src/scenes/golf_ball_flight_path/components/shadow_follow.tscn")
const SHADOW_Z_INDEX_CHANGE:int = -100
const EARLYLATE_END_SCALE:float = 0.48

@export var flight_time_rhythm:Array[Beat] :
	set(v):
		flight_time_rhythm = v
		update_configuration_warnings()
@export var early_late_flight_time:Array[Beat]
@onready var shadow_path:Path2D = $ShadowPath
@onready var early_late_shadow_path:Path2D = $EarlyLateShadowPath
@onready var early_late_path:Path2D = $EarlyLatePath

#var flight_time_sec:float


func _ready() -> void:
	if Engine.is_editor_hint():
		return


func _process(_delta: float) -> void:
	if not curve: curve = Curve2D.new()
	if not shadow_path.curve: shadow_path.curve = Curve2D.new()
	if not early_late_shadow_path.curve: early_late_shadow_path.curve = Curve2D.new()
	if not early_late_path.curve: early_late_path.curve = Curve2D.new()
	
	# Matching curves to their respective shadow path
	if curve.point_count >= 2:
		var curve_points:int = curve.point_count
		if shadow_path.curve.point_count < 2:
			shadow_path.curve.clear_points()
			shadow_path.curve.add_point(curve.get_point_position(0))
			shadow_path.curve.add_point(curve.get_point_position(curve_points-1))
		
		var shadow_points:int = shadow_path.curve.point_count
		shadow_path.curve.set_point_position(0, curve.get_point_position(0))
		shadow_path.curve.set_point_position(shadow_points-1, curve.get_point_position(curve_points-1))
	else:
		shadow_path.curve.clear_points()
	
	if early_late_path.curve.point_count >= 2:
		var curve_points:int = early_late_path.curve.point_count
		
		if early_late_shadow_path.curve.point_count < 2:
			early_late_shadow_path.curve.clear_points()
			early_late_shadow_path.curve.add_point(early_late_path.curve.get_point_position(0))
			early_late_shadow_path.curve.add_point(early_late_path.curve.get_point_position(curve_points - 1))
		
		var shadow_points:int = early_late_shadow_path.curve.point_count
		early_late_shadow_path.curve.set_point_position(0, early_late_path.curve.get_point_position(0))
		early_late_shadow_path.curve.set_point_position(shadow_points-1, early_late_path.curve.get_point_position(curve_points-1))
	else:
		early_late_shadow_path.curve.clear_points()
	
	if Engine.is_editor_hint():
		# TODO maybe try make the early-late path's final point's pos.y scale proportional to the main 
		# path's basically, if you raised the main path's final point a bit, the early-late should 
		# get raised enough to keep the ratio between early-late.initial_pos_y / main.initial_pos_y which
		# should be constant
		
		#if not curve or not curve.get_baked_points():
			#return
		#
		#if not initial_height_ratio:
			#initial_height_ratio = (_get_curve_dimensions(early_late_path.curve).y / 
				#_get_curve_dimensions(curve).y)
		#
		#var main_starting_pos:Vector2 = curve.get_point_position(0)
		#var main_end_pos:Vector2 = curve.get_point_position(curve.point_count - 1)
		#
		#early_late_path.curve.set_point_position(0, main_starting_pos)
		#for i in range(curve.point_count):
			#if i == 0: continue
			#var target:Vector2 = curve.get_point_position(i)
			#early_late_path.curve.set_point_position(i, target * Vector2(1.33, 0.66))
		return


func _get_curve_dimensions(p_curve:Curve2D) -> Vector2:
	var start_pos = p_curve.get_point_position(0)
	var end_pos = p_curve.get_point_position(p_curve.point_count - 1)
	return end_pos - start_pos


## Add a golf ball
func add_ball(_ev:RhythmInputEvent, score:Utils.SCORES, offset:float) -> void:
	var path:Path2D
	var end_pt:Vector2
	var shadow_p:Path2D
	if score == Utils.SCORES.MEH:
		var num_pts := early_late_path.curve.point_count
		end_pt = early_late_path.curve.get_point_position(num_pts - 1)
		path = early_late_path
		shadow_p = early_late_shadow_path
		early_late_path.scale.x = -1 if ceili(offset) > 0 else 1
		early_late_shadow_path.scale.x = -1 if ceili(offset) > 0 else 1
	else:
		var num_pts := curve.point_count
		end_pt = curve.get_point_position(num_pts - 1)
		path = self
		shadow_p = shadow_path
	
	var ball:PathFollow2D = BALL_FOLLOW_SCENE.instantiate()
	var shadow:PathFollow2D = SHADOW_FOLLOW_SCENE.instantiate()
	path.add_child(ball)
	shadow_p.add_child(shadow)
	
	var flight_time := get_flight_time()
	#flight_time_sec = Song.rhythm_to_sec(flight_time_rhythm)
	# TODO add temporary blur to ball's sprite
	
	var end_scale := \
		Vector2(1, 1) * EARLYLATE_END_SCALE if path == early_late_path else Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(ball, 'scale', end_scale, flight_time) \
		.set_trans(Tween.TRANS_CIRC) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ball, "progress_ratio", 1, flight_time) \
		.set_trans(Tween.TRANS_CIRC) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shadow, 'scale', end_scale, flight_time) \
		.set_trans(Tween.TRANS_CIRC) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shadow, 'progress_ratio', 1, flight_time) \
		.set_trans(Tween.TRANS_CIRC) \
		.set_ease(Tween.EASE_OUT)
	
	# Arbitrary timer to have the shadow disappear for a bit to look like 
	# it's cresting the little hill
	var hide_time:float
	var unhide_time:float
	if path == early_late_path:
		hide_time = flight_time/15.92
		unhide_time = flight_time
	else:
		hide_time = flight_time/4.85
		unhide_time = hide_time * 1.72
	
	var t := get_tree().create_timer(hide_time)
	t.timeout.connect(shadow.hide)
	if path == early_late_path:
		t.timeout.connect(func():ball.z_index -= 3)
	
	var t2 := get_tree().create_timer(unhide_time)
	if path != early_late_path: t2.timeout.connect(shadow.show)
	
	tween.tween_callback(ball.queue_free)
	tween.tween_callback(shadow.queue_free)
	tween.tween_callback(flight_ended.emit.bind(end_pt))


## Returns current flight time
func get_flight_time() -> float:
	return Song.rhythm_to_sec(flight_time_rhythm)
