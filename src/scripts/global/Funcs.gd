@tool
extends Node
## Global func dump

func _format_path(p:String) -> String:
	return p.replace('\\', '/').replace('//', '/')


## Enumerate like Python
func enumerate(list: Array) -> Array[Array]:
	var out: Array[Array] = []
	for index in range(list.size()):
		out.append([index, list[index]])
	return out


## Rounds a float to the given number of decimal points
func roundf_dec(x:float, decimals:int=2) -> float:
	var y = x * pow(10, decimals)
	y = roundi(y)
	return y / pow(10, decimals)


## Returns if a path exists
func path_exists(p: String) -> bool:
	return DirAccess.dir_exists_absolute(_format_path(p).get_base_dir())


## Creates and returns file dialog
func create_file_dialog(
	type:=FileDialog.FILE_MODE_OPEN_FILE, 
	filters:Array[String]=[]
) -> FileDialog:
	
	var fd := FileDialog.new()
	fd.title = 'Select a File'
	fd.dialog_hide_on_ok = true
	fd.show_hidden_files = false
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = type
	fd.filters = filters
	return fd


## Rounds to 'digit' sig figs. Negative 'digit' will round in opposite direction: i.e. digit = -2
## would round 24.123 to 20
func round_to(num, digit:int=2):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)


## Fades the screen into the given color. The nodes used during this
## are freed on end by default. Returns the fade Tween.
func fade_into(
	color:Color, 
	t:float=1.25,
	freed_on_end:bool=false,
	layer:int=99
) -> Tween:
	
	# Creates TextureRect of 1D gradient
	var color_text := TextureRect.new()
	color_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_text.texture = GradientTexture1D.new()
	color_text.texture.gradient = Gradient.new()
	color_text.texture.gradient.set_color(0, color)
	color_text.texture.gradient.remove_point(1)
	color_text.modulate.a = 0.0
	
	# TextureRect needs a CanvasLayer to function properly
	var canvas := CanvasLayer.new()
	canvas.layer = layer
	canvas.add_child(color_text, true, Node.INTERNAL_MODE_BACK)
	
	# Adding nodes to scene
	var scene := get_tree().current_scene
	scene.add_child(canvas, true, Node.INTERNAL_MODE_BACK)
	
	# Tween to animate alpha
	var tw := create_tween()
	tw.tween_property(color_text, 'modulate:a', 1.0, t)
	if freed_on_end: tw.tween_callback(canvas.queue_free)
	
	return tw


## Fades screen out of the given color. Nodes are automatically freed by default.
## Warning: this can look janky if the screen wasn't already covered in this 
## color. Returns the fade Tween.
func fade_outof(color:Color, 
	t:float=1.25,
	freed_on_end:bool=false,
	layer:int=99
) -> Tween:
	
	# Creates TextureRect of 1D gradient
	var color_text := TextureRect.new()
	color_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_text.texture = GradientTexture1D.new()
	color_text.texture.gradient = Gradient.new()
	color_text.texture.gradient.set_color(0, color)
	color_text.texture.gradient.remove_point(1)
	color_text.modulate.a = 1.0
	
	# TextureRect needs a CanvasLayer to function properly
	var canvas := CanvasLayer.new()
	canvas.layer = layer
	canvas.add_child(color_text, true, Node.INTERNAL_MODE_BACK)
	
	# Adding nodes to scene
	var scene := get_tree().current_scene
	scene.add_child(canvas, true, Node.INTERNAL_MODE_BACK)
	
	# Tween to animate alpha
	var tw := create_tween()
	tw.tween_property(color_text, 'modulate:a', 0.0, t)
	if freed_on_end: tw.tween_callback(canvas.queue_free)
	
	return tw


## Connects a callback to a signal after skipping a certain number of emissions.
## Inputting a delay of 0 creates a normal connection.
func delay_connect(
	s:Signal, 
	cb:Callable, 
	delay:int=1, 
	flags := CONNECT_ONE_SHOT
) -> Error:
	
	if s.is_null() || cb.is_null() || delay < 0: 
		return ERR_INVALID_PARAMETER
	
	# TODO
	# Give lambda with 'bound' trigger number
	# if trigger >= delay, connect cb
	# else increment trigger
	# disconnect old lambda, reconnect new one
	
	return OK


## Returns the absolute z_index of a CanvasItem.
func absolute_z(target:CanvasItem) -> int:
	var node = target
	var z_index:int = 0
	while node && node is CanvasItem:
		z_index += node.z_index
		if !node.z_as_relative: break
		node = node.get_parent()
	return z_index
