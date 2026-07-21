class_name Responder
extends Node

## Node in the [InputManager] responder tree.
##[br]
## • [member input_map] — optional layer contributed while [member active].
##[br]
## • [member active] — when false, input processing is off and the map is
##   excluded from the merged engine [InputMap].

## Layer contributed to the merged InputMap while this responder is active.
@export var input_map: CustomInputMap:
	set = set_input_map

## When false: no `_input*` callbacks and no map contribution.
@export var active: bool = true:
	set = set_active


func _enter_tree() -> void:
	_sync_process_flags()


func set_input_map(value: CustomInputMap) -> void:
	if input_map == value:
		return
	input_map = value
	_notify_map_dirty()


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_sync_process_flags()
	if contributes_map():
		_notify_map_dirty()


## True when this node should contribute its [member input_map] to the merge.
func contributes_map() -> bool:
	return active and input_map != null


## Add a responder node to this branch.
func add_responder(node: Responder) -> void:
	InputManager.push_state()
	add_child(node)
	if node.contributes_map():
		InputManager.rebuild_input_map()


## Removing a responder does not free the node.
func remove_responder(node: Responder) -> void:
	if node == null or node.get_parent() != self:
		return
	InputManager.push_state()
	remove_child(node)
	InputManager.rebuild_input_map()


func pop_responder() -> Node:
	var layers: Array = get_children()
	if layers.is_empty():
		return null
	InputManager.push_state()
	var node: Responder = layers[-1]
	remove_child(node)
	InputManager.rebuild_input_map()
	return node


func _sync_process_flags() -> void:
	set_process_input(active)
	set_process_unhandled_input(active)
	set_process_unhandled_key_input(active)


func _notify_map_dirty() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(InputManager):
		InputManager.rebuild_input_map()
