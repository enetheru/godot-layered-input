class_name _InputManager
extends Node

##[codeblock]
##│ ___                _     __  __
##│|_ _|_ _  _ __ _  _| |_  |  \/  |__ _ _ _  __ _ __ _ ___ _ _
##│ | || ' \| '_ \ || |  _| | |\/| / _` | ' \/ _` / _` / -_) '_|
##│|___|_||_| .__/\_,_|\__| |_|  |_\__,_|_||_\__,_\__, \___|_|
##╰─────────|_|───────────────────────────────────|___/───────────
##[/codeblock]
##
## Owns the responder branch (last child of the scene root) and projects the
## merged set of active [CustomInputMap] layers onto the engine [InputMap].
## [br][br]
## No project-settings base map is kept. Only maps on active responders count.
## [br][br]
## Merge order is tree order (depth-first, children first-to-last) so
## later siblings both receive input first and win action-name conflicts.

const INPUT_MAP: CustomInputMap = preload("res://addons/enetheru.input_map_editor/systems/default_input_map.tres")

var responder_root: Responder

## Last effective map pushed to the engine (for inspection and snapshots).
var effective_map: CustomInputMap

## Simple stack of responder-tree snapshots.
var undo_stack: Array = []

var _want_rebuild: bool = false
var _rebuilding: bool = false

## Emitted after the engine [InputMap] has been replaced.
signal input_map_changed(effective: CustomInputMap)


func _on_parent_child_order_changed() -> void:
	var parent: Node = get_parent()
	if not is_instance_valid(parent):
		return
	var child_count: int = parent.get_child_count()
	if get_index() == child_count - 1:
		return
	parent.move_child(self, -1)


func _on_responder_tree_changed() -> void:
	rebuild_input_map()


func _enter_tree() -> void:
	var parent: Node = get_parent()
	if parent and not parent.child_order_changed.is_connected(_on_parent_child_order_changed):
		parent.child_order_changed.connect(_on_parent_child_order_changed, CONNECT_DEFERRED)

	responder_root = Responder.new()
	responder_root.name = &"root"
	responder_root.input_map = INPUT_MAP
	add_child(responder_root)
	if not responder_root.child_order_changed.is_connected(_on_responder_tree_changed):
		responder_root.child_order_changed.connect(_on_responder_tree_changed)

	rebuild_input_map()


func push_state() -> void:
	var copy: Responder = responder_root.duplicate()
	undo_stack.push_back(copy)


func pop_state() -> void:
	if undo_stack.is_empty():
		push_warning("InputManager.pop_state: undo stack empty")
		return
	var last_state: Responder = undo_stack.pop_back()
	var old_root: Responder = responder_root
	if old_root.child_order_changed.is_connected(_on_responder_tree_changed):
		old_root.child_order_changed.disconnect(_on_responder_tree_changed)
	old_root.replace_by(last_state)
	responder_root = last_state
	if not responder_root.child_order_changed.is_connected(_on_responder_tree_changed):
		responder_root.child_order_changed.connect(_on_responder_tree_changed)
	old_root.queue_free()
	rebuild_input_map()


func add_responder(node: Responder) -> void:
	responder_root.add_responder(node)


## free is not called on the node removed from the tree
func remove_responder(node: Responder) -> void:
	if node.is_ancestor_of(responder_root):
		var parent: Responder = node.get_parent()
		parent.remove_responder(node)


func rebuild_input_map() -> void:
	if _want_rebuild == false:
		_want_rebuild = true
		_rebuild_input_map.call_deferred()


func _collect_maps(node: Node, out: Array[CustomInputMap]) -> void:
	if node is Responder:
		var responder: Responder = node
		if responder.contributes_map():
			out.append(responder.input_map)
	for child: Node in node.get_children():
		_collect_maps(child, out)


func _rebuild_input_map() -> void:
	assert(responder_root, "responder root missing")
	_want_rebuild = false
	if _rebuilding:
		return
	_rebuilding = true

	var layers: Array[CustomInputMap] = []
	_collect_maps(responder_root, layers)

	var effective: CustomInputMap = CustomInputMap.new()
	for layer: CustomInputMap in layers:
		effective = layer.merge_over(effective)

	effective_map = effective
	effective.apply_to_engine()
	input_map_changed.emit(effective)
	_rebuilding = false
