@tool
class_name BallThrower extends EventDisplay

@warning_ignore("unused_signal")
signal ball_thrown

const BALL_SHADOW_SCENE := \
	preload("res://src/scenes/golf_ball_flight_path/components/shadow_follow.tscn")

@export var uses_ball_path:bool = true
@export var uses_shadow_path:bool = true
@export var miss_path_time := Song.BEATS.half
@export var ball_follow_scene:PackedScene
@export var golfer:Golfer

@onready var ball_path:Path2D = $BallPath if uses_ball_path else null
#@onready var miss_path:Path2D = $BallMissPath
#@onready var shadow_path:Path2D = $ShadowPath if uses_shadow_path else null
#@onready var miss_shadow_path:Path2D = $ShadowMissPath

var _bopping:bool = false


func _ready() -> void:
	super()
	
	if Engine.is_editor_hint():
		return
	
	if not ball_path.visible:
		ball_path.show()


## connected to Signals => time_signature_changed and bpm_changed
func _on_meta_config() -> void:
	pass


## Warnings that will go to Output to tell you when something isn't set up right
func _get_configuration_warnings() -> PackedStringArray:
	var warnings:PackedStringArray
	# TODO append warnings here
	return warnings


## Called when using 'add_event'
## NOTE remember to handle special_keys
@warning_ignore("unused_parameter")
func _on_event_start(ev:RhythmInputEvent) -> void:
	pass


## Connected to ev.missed
@warning_ignore("unused_parameter")
func _on_event_missed(ev:RhythmInputEvent) -> void:
	pass


## Connected to ev.activated
func _on_event_hit(_ev:RhythmInputEvent, _score:Utils.SCORES, _offset:float) -> void:
	pass


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                    BallThrower FUNCTIONS                                        #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#func get_next_ball() -> PathFollow2D:
	#return _balls_in_flight.front()


#func ball_in_flight() -> bool:
	#return get_next_ball() != null


func _add_ball() -> BallFollow:
	var ball_pf := ball_follow_scene.instantiate()
	ball_path.add_child(ball_pf)
	return ball_pf


func _on_ball_throw_finished(ball_pf:BallFollow, tween:Tween=null, shadow_pf:BallFollow=null) -> bool:
	if tween and is_instance_valid(tween) and tween.is_running(): tween.kill()
	var t := get_tree().create_timer(0.01)
	t.timeout.connect(func(): _bopping = true, CONNECT_ONE_SHOT)
	if !is_instance_valid(ball_pf) || ball_pf.is_queued_for_deletion():
		if is_instance_valid(shadow_pf): shadow_pf.queue_free()
		return false
	return true
