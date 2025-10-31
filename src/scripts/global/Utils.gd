extends Node
## Storing all those juicy enums and constants

enum DIFFICULTIES {EASY, NORMAL}
enum INPUTS {
	button1,
	button2,
	button3,
	button4 
	}
enum INPUT_TYPES {
	single_press,
	single_hold,
	double_press,
	double_hold,
	}
enum SCORES {
	MISS = 0,
	MEH,
	GREAT,
	PERFECT }

## Returns dictionary with keys in INPUTS and values as empty arrays
func get_button_dict(num:int=2) -> Dictionary:
	var dict:Dictionary = {}
	for i in range(num):
		dict.merge({INPUTS[INPUTS.find_key(i)]: []})
	return dict

## Converts InputEventAction action string to enum
func action_enum(a:String) -> INPUTS:
	assert(a in ['Button1', 'Button2', 'Button3', 'Button4'])
	match a:
		'Button1':
			return INPUTS.button1
		'Button2':
			return INPUTS.button2
		'Button3':
			return INPUTS.button3
		'Button4':
			return INPUTS.button4
		_:
			return INPUTS.button1

## Converts enum value or int to InputEventAction
func enum_action(e) -> InputEventAction:
	assert(INPUTS.find_key(e))
	#if not INPUTS.find_key(e):
		#return null
	
	var action := InputEventAction.new()
	match e:
		INPUTS.button1:
			action.action = &"Button1"
		INPUTS.button2:
			action.action = &"Button2"
		INPUTS.button2:
			action.action = &"Button3"
		INPUTS.button3:
			action.action = &"Button4"
	return action
