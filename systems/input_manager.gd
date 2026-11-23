class_name _InputManager
extends Node

## Owns one link tree and is the node the viewport calls.
##
## Registered as the [code]InputManager[/code] autoload. The class name is
## [code]_InputManager[/code] so the global name can match the autoload.
##[br][br]
## Layers are link responders. This node stays the last child of the scene root
## and forwards each input pass to the tree. The tree merges the active maps
## and writes the result onto the engine [InputMap].


const ResponderTreeScript = preload( "responder_tree.gd" )

## Stock root layer ([code]default_input_map.tres[/code] beside this script).
const DEFAULT_INPUT_MAP_UID:StringName = &"uid://6hh6cxvfe0kf"

## The link tree this autoload dispatches.
var tree:RefCounted

## Cached stock map from [constant DEFAULT_INPUT_MAP_UID].
static var _default_input_map:CustomInputMap

## Emitted after the engine [InputMap] has been replaced.
signal input_map_changed( effective:CustomInputMap )

## Emitted when a rebuild has finished and no further rebuild is queued.
signal rebuild_finished


## The table the link tree last wrote.
var effective_map:CustomInputMap:
	get:
		if tree == null:
			return null
		return tree.get( &"effective_map" )


func _enter_tree() -> void:
	var parent:Node = get_parent()
	if parent != null \
	and not parent.child_order_changed.is_connected( _on_parent_child_order_changed ):
		var _order_hook:Error = parent.child_order_changed.connect(
				_on_parent_child_order_changed,
				CONNECT_DEFERRED ) as Error
	tree = ResponderTreeScript.new()
	var _map_hook:Error = tree.connect( &"input_map_changed", _on_tree_map_changed ) as Error
	var _done_hook:Error = tree.connect( &"rebuild_finished", _on_tree_rebuilt ) as Error
	set_process_input( true )
	set_process_shortcut_input( true )
	set_process_unhandled_key_input( true )
	set_process_unhandled_input( true )


func _exit_tree() -> void:
	shutdown()


func _input( event:InputEvent ) -> void:
	if tree == null:
		return
	tree.call( &"dispatch_input", get_viewport(), event )


func _shortcut_input( event:InputEvent ) -> void:
	if tree == null:
		return
	tree.call( &"dispatch_shortcut_input", get_viewport(), event )


func _unhandled_key_input( event:InputEvent ) -> void:
	if tree == null:
		return
	tree.call( &"dispatch_unhandled_key_input", get_viewport(), event )


func _unhandled_input( event:InputEvent ) -> void:
	if tree == null:
		return
	tree.call( &"dispatch_unhandled_input", get_viewport(), event )


## Append [param record] under the link root.
func add_responder( record:RefCounted ) -> void:
	if tree == null:
		push_warning( "InputManager.add_responder: link tree missing" )
		return
	tree.call( &"add_responder", record )


## Detach [param record] from the link tree.
func remove_responder( record:RefCounted ) -> void:
	if tree == null:
		return
	tree.call( &"remove_responder", record )


## Queue one rebuild on the link tree.
func request_rebuild() -> void:
	if tree == null:
		return
	tree.call( &"request_rebuild" )


## Wait until the link tree has finished a queued rebuild.
func until_rebuilt() -> void:
	if tree == null:
		return
	await tree.call( &"until_rebuilt" )


## Drop the link tree and the cached stock map.
func shutdown() -> void:
	var parent:Node = get_parent()
	if is_instance_valid( parent ) \
	and parent.child_order_changed.is_connected( _on_parent_child_order_changed ):
		parent.child_order_changed.disconnect( _on_parent_child_order_changed )
	tree = null
	clear_default_input_map_cache()


## Stock root [CustomInputMap]. Loaded on first use.
static func get_default_input_map() -> CustomInputMap:
	if is_instance_valid( _default_input_map ):
		return _default_input_map
	var loaded:Resource = ResourceLoader.load(
			String( DEFAULT_INPUT_MAP_UID ),
			"",
			ResourceLoader.CACHE_MODE_IGNORE )
	if loaded is CustomInputMap:
		_default_input_map = loaded as CustomInputMap
		return _default_input_map
	push_error( "InputManager.get_default_input_map: failed to load the stock map" )
	_default_input_map = CustomInputMap.new()
	return _default_input_map


## Drop the static stock map.
static func clear_default_input_map_cache() -> void:
	if is_instance_valid( _default_input_map ):
		_default_input_map.clear()
	_default_input_map = null


func _on_parent_child_order_changed() -> void:
	var parent:Node = get_parent()
	if not is_instance_valid( parent ):
		return
	if get_index() == parent.get_child_count() - 1:
		return
	parent.move_child( self, -1 )


func _on_tree_map_changed( effective:CustomInputMap ) -> void:
	input_map_changed.emit( effective )


func _on_tree_rebuilt() -> void:
	rebuild_finished.emit()
