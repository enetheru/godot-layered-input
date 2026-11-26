class_name _InputManager
extends Node

##[codeblock lang=text]
##│ ___                _     __  __
##│|_ _|_ _  _ __ _  _| |_  |  \/  |__ _ _ _  __ _ __ _ ___ _ _
##│ | || ' \| '_ \ || |  _| | |\/| / _` | ' \/ _` / _` / -_) '_|
##│|___|_||_| .__/\_,_|\__| |_|  |_\__,_|_||_\__,_\__, \___|_|
##╰─────────|_|───────────────────────────────────|___/───────────
##[/codeblock]Owns one link tree and is the node the viewport calls.
##
## Registered as the [code]InputManager[/code] autoload. The class name is
## [code]_InputManager[/code] so the global name can match the autoload.
##[br][br]
## Layers are link responders. This node stays the last child of the scene root
## and forwards each input pass to the tree. The tree merges the active maps
## and writes the result onto the engine [InputMap].

const ResponderTree = preload( "responder_tree.gd" )
const Responder = preload( "responder.gd" )

## Stock root layer ([code]default_input_map.tres[/code] beside this script).
const DEFAULT_INPUT_MAP_UID:StringName = &"uid://6hh6cxvfe0kf"


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## The link tree this autoload dispatches.
var tree:ResponderTree

## Cached stock map from [constant DEFAULT_INPUT_MAP_UID].
static var _default_input_map:CustomInputMap

## The table the link tree last wrote.
var effective_map:CustomInputMap:
	get:
		if is_instance_valid(tree):
			return tree.effective_map
		return null


#            ███████ ██  ██████  ███    ██  █████  ██      ███████             #
#            ██      ██ ██       ████   ██ ██   ██ ██      ██                  #
#            ███████ ██ ██   ███ ██ ██  ██ ███████ ██      ███████             #
#                 ██ ██ ██    ██ ██  ██ ██ ██   ██ ██           ██             #
#            ███████ ██  ██████  ██   ████ ██   ██ ███████ ███████             #
func                        _________SIGNALS_________              ()->void:pass

## Emitted after the engine [InputMap] has been replaced.
signal input_map_changed( effective:CustomInputMap )

## Emitted when a rebuild has finished and no further rebuild is queued.
signal rebuild_finished


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_parent_child_order_changed() -> void:
	var parent:Node = get_parent()
	if is_instance_valid( parent ):
		if get_index() != parent.get_child_count() - 1:
			parent.move_child( self, -1 )


func _on_tree_map_changed( effective:CustomInputMap ) -> void:
	input_map_changed.emit( effective )


func _on_tree_rebuilt() -> void:
	rebuild_finished.emit()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _enter_tree() -> void:
	# FIXME: It seems impossible to enter the tree without a parent.
	# Also seems prudent to cache the parent
	var parent:Node = get_parent()
	if is_instance_valid(parent) \
	and not parent.child_order_changed.is_connected( _on_parent_child_order_changed ):
		var _order_hook:int = parent.child_order_changed.connect(
				_on_parent_child_order_changed,
				CONNECT_DEFERRED )

	tree = ResponderTree.new()
	var _map_hook:int = tree.input_map_changed.connect( _on_tree_map_changed )
	var _done_hook:int = tree.rebuild_finished.connect( _on_tree_rebuilt )

	# TODO: An opportunity for saving some cycles only activate when a responder needs it.
	set_process_input( true )
	set_process_shortcut_input( true )
	set_process_unhandled_key_input( true )
	set_process_unhandled_input( true )


func _exit_tree() -> void:
	var parent:Node = get_parent()
	if is_instance_valid( parent ) \
	and parent.child_order_changed.is_connected( _on_parent_child_order_changed ):
		parent.child_order_changed.disconnect( _on_parent_child_order_changed )
	tree = null
	clear_default_input_map_cache()


func _input( event:InputEvent ) -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.dispatch_input( get_viewport(), event )


func _shortcut_input( event:InputEvent ) -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.dispatch_shortcut_input( get_viewport(), event )


func _unhandled_key_input( event:InputEvent ) -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.dispatch_unhandled_key_input( get_viewport(), event )


func _unhandled_input( event:InputEvent ) -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.dispatch_unhandled_input( get_viewport(), event )


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Append [param record] under the link root.
func add_responder( record:Responder ) -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.add_responder( record )


## Detach [param record] from the link tree.
func remove_responder( record:Responder ) -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.remove_responder( record )


## Queue one rebuild on the link tree.
func request_rebuild() -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	tree.request_rebuild()


## Wait until the link tree has finished a queued rebuild.
func until_rebuilt() -> void:
	assert(is_instance_valid(tree), "missing ResponderTree")
	await tree.until_rebuilt()


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
