@tool
class_name PropertyLink extends Node2D
## Links nodes so that any changes in the specified properties are mirrored
## NOTE only works in the editor
##
## I'm doing this mostly for advanced exports. Since Godot doesn't have multi-inheritance, I'm instead having
## 'inherited' Nodes that don't match the actual 'extended' class as child nodes that link their variables with
## those of the parent node with the same name. This might be a really roundabout way of doing things, but if it works
## it works

@export var root_node:Node	## Node whose changes influence the others
@export var linked_nodes:Array[Node]  
@export var properties_strings:Array[StringName]

func _process(_delta:float) -> void:
	#if not Engine.is_editor_hint(): return
	if not (root_node and linked_nodes and properties_strings): return
	
	for prop in properties_strings:
		var base_value = root_node.get(prop)
		
		for n in linked_nodes:
			if not (prop in n): continue
			if n.get(prop) != base_value: n.set(prop, base_value)
