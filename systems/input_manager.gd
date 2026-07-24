class_name _InputManager
extends Node

##[codeblock]
##│ ___                _     __  __
##│|_ _|_ _  _ __ _  _| |_  |  \/  |__ _ _ _  __ _ __ _ ___ _ _
##│ | || ' \| '_ \ || |  _| | |\/| / _` | ' \/ _` / _` / -_) '_|
##│|___|_||_| .__/\_,_|\__| |_|  |_\__,_|_||_\__,_\__, \___|_|
##╰─────────|_|───────────────────────────────────|___/───────────
##[/codeblock]Owns the responder branch and projects merged maps onto the engine.
##
## Registered as the [code]InputManager[/code] autoload. Class name is
## [code]_InputManager[/code] so the global name can match the autoload.
##[br][br]
## Owns the responder branch (last child of the scene root) and projects the
## merged set of active [CustomInputMap] layers onto the engine [InputMap].
##[br][br]
## No project-settings base map is kept. Only maps on active responders count.
##[br][br]
## Merge order is tree order (depth-first, children first-to-last) so later
## siblings both receive input first and win action-name conflicts.
## [br]Full responder-tree undo lives here ([member undo_stack],
## [method push_state], [method pop_state]) because this node owns
## [member responder_root] — not a separate UndoRedo service or per-map editor
## history.
##
## Default root map is [method get_default_input_map] (lazy [method @GlobalScope.load],
## not [code]preload[/code]) so this script does not form a cycle with
## [InputAction] via [code]default_input_map.tres[/code].
##[br]
##[br][color=goldenrod]TODO[/color]: I have a major problem with the responder
## tree in that when its history is modified, it invalidates the references to
## the nodes. This makes dealing with unpredictable.



## Stock root layer ([code]default_input_map.tres[/code] beside this script).
## Prefer [code]uid://[/code] so the addon stays relocatable.
const DEFAULT_INPUT_MAP_UID:StringName = &"uid://6hh6cxvfe0kf"


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Root of the responder tree (created in [method _enter_tree]).
var responder_root:Responder

## Last effective map pushed to the engine (for inspection and snapshots).
var effective_map:CustomInputMap

## Full deep copies of [member responder_root] for [method push_state] /
## [method pop_state] (whole-tree snapshots only).
var undo_stack:Array[Responder] = []

var _want_rebuild:bool = false
var _rebuilding:bool = false

## Cached stock map from [constant DEFAULT_INPUT_MAP_UID] (null until first load).
static var _default_input_map:CustomInputMap


#            ███████ ██  ██████  ███    ██  █████  ██      ███████             #
#            ██      ██ ██       ████   ██ ██   ██ ██      ██                  #
#            ███████ ██ ██   ███ ██ ██  ██ ███████ ██      ███████             #
#                 ██ ██ ██    ██ ██  ██ ██ ██   ██ ██           ██             #
#            ███████ ██  ██████  ██   ████ ██   ██ ███████ ███████             #
func                        _________SIGNALS_________              ()->void:pass

## Emitted after the engine [InputMap] has been replaced.
signal input_map_changed( effective:CustomInputMap )


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_parent_child_order_changed() -> void:
	var parent:Node = get_parent()
	if not is_instance_valid( parent ):
		return
	var child_count:int = parent.get_child_count()
	if get_index() == child_count - 1:
		return
	parent.move_child( self, -1 )


func _on_responder_tree_changed() -> void:
	request_rebuild()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## Create [member responder_root], wire tree signals, and schedule first rebuild.
func _enter_tree() -> void:
	var parent:Node = get_parent()
	if parent \
	and not parent.child_order_changed.is_connected( _on_parent_child_order_changed ):
		_connect_sig(
				parent.child_order_changed,
				_on_parent_child_order_changed,
				CONNECT_DEFERRED )

	responder_root = Responder.new()
	responder_root.name = &"root"
	responder_root.input_map = get_default_input_map()
	add_child( responder_root )
	if not responder_root.child_order_changed.is_connected( _on_responder_tree_changed ):
		_connect_sig( responder_root.child_order_changed, _on_responder_tree_changed )

	request_rebuild()


## Tear down via [method shutdown] (idempotent).
func _exit_tree() -> void:
	shutdown()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Push a deep copy of [member responder_root] onto [member undo_stack].
## [br][method Responder.add_responder], [method Responder.remove_responder], and
## [method Responder.pop_responder] call this before mutating the tree so
## [method pop_state] can restore the prior branch.
func push_state() -> void:
	assert( is_instance_valid( responder_root ),
			"InputManager.push_state: responder_root missing" )
	var copy:Responder = responder_root.duplicate() as Responder
	assert( is_instance_valid( copy ), "InputManager.push_state: duplicate failed" )
	undo_stack.push_back( copy )


## Pop [member undo_stack] and replace [member responder_root] with that snapshot,
## then [method request_rebuild]. No-op (warning) if the stack is empty.
func pop_state() -> void:
	if undo_stack.is_empty():
		push_warning( "InputManager.pop_state: undo stack empty" )
		return
	var last_state:Responder = undo_stack.pop_back()
	var old_root:Responder = responder_root
	if old_root.child_order_changed.is_connected( _on_responder_tree_changed ):
		old_root.child_order_changed.disconnect( _on_responder_tree_changed )
	old_root.replace_by( last_state )
	responder_root = last_state
	if not responder_root.child_order_changed.is_connected( _on_responder_tree_changed ):
		_connect_sig( responder_root.child_order_changed, _on_responder_tree_changed )
	old_root.queue_free()
	request_rebuild()


## Attach [param node] under [member responder_root] (undo snapshot + rebuild).
func add_responder( node:Responder ) -> void:
	responder_root.add_responder( node )


## Detach [param node] from the responder tree without freeing it.
func remove_responder( node:Responder ) -> void:
	if not is_instance_valid( node ):
		return
	if node.is_ancestor_of( responder_root ):
		var parent:Responder = node.get_parent()
		parent.remove_responder( node )


## Flag a full map rebuild; at most one [method Object.call_deferred] is queued.
## Runs at idle time (MessageQueue flush — mainly end of process/physics frames),
## not “next frame”; nested deferred work can still run in the same idle cycle.
func request_rebuild() -> void:
	if _want_rebuild:
		return
	_want_rebuild = true
	_rebuild_input_map.call_deferred()


## Tear down responder tree, undo snapshots, effective map, and the static
## default-map cache. Idempotent — safe from [method _exit_tree] and tests.
## [br]Does not erase engine [InputMap] actions (those may still hold events
## that were [method CustomInputMap.apply_to_engine]'d).
func shutdown() -> void:
	_want_rebuild = false
	_rebuilding = false

	var parent:Node = get_parent()
	if is_instance_valid( parent ) \
	and parent.child_order_changed.is_connected( _on_parent_child_order_changed ):
		parent.child_order_changed.disconnect( _on_parent_child_order_changed )

	for snapshot:Responder in undo_stack:
		if not is_instance_valid( snapshot ):
			continue
		_release_map( snapshot.input_map )
		snapshot.input_map = null
		if snapshot.is_inside_tree():
			snapshot.queue_free()
		else:
			snapshot.free()
	undo_stack.clear()

	if is_instance_valid( responder_root ):
		if responder_root.child_order_changed.is_connected(
				_on_responder_tree_changed ):
			responder_root.child_order_changed.disconnect(
					_on_responder_tree_changed )
		_release_responder_tree( responder_root )
		if responder_root.get_parent() == self:
			remove_child( responder_root )
		responder_root.free()
	responder_root = null

	_release_map( effective_map )
	effective_map = null
	clear_default_input_map_cache()


#        ███████ ████████  █████  ████████ ██  ██████                          #
#        ██         ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ███████    ██    ██ ██                               #
#             ██    ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ██   ██    ██    ██  ██████                          #
func                        _________STATIC__________              ()->void:pass

## Stock root [CustomInputMap]. Loaded on first use (not script-parse preload).
## Uses [constant ResourceLoader.CACHE_MODE_IGNORE] so shutdown can drop the
## only strong ref without leaving a ResourceLoader cache pin.
static func get_default_input_map() -> CustomInputMap:
	if is_instance_valid( _default_input_map ):
		return _default_input_map
	var path:String = String( DEFAULT_INPUT_MAP_UID )
	var loaded:Resource = ResourceLoader.load(
			path,
			"",
			ResourceLoader.CACHE_MODE_IGNORE )
	if loaded is CustomInputMap:
		_default_input_map = loaded as CustomInputMap
		return _default_input_map
	push_error( "InputManager.get_default_input_map: failed to load '%s'"
			% path )
	_default_input_map = CustomInputMap.new()
	return _default_input_map


## Drop the static stock map (clears actions/events first). Safe if never loaded.
static func clear_default_input_map_cache() -> void:
	if is_instance_valid( _default_input_map ):
		_default_input_map.clear()
	_default_input_map = null


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

func _collect_maps( node:Node, out:Array[CustomInputMap] ) -> void:
	if node is Responder:
		var responder:Responder = node
		if responder.contributes_map():
			out.append( responder.input_map )
	for child:Node in node.get_children():
		_collect_maps( child, out )


## Internal rebuild body; schedule via [method request_rebuild].
func _rebuild_input_map() -> void:
	if not is_instance_valid( responder_root ):
		_want_rebuild = false
		return
	_want_rebuild = false
	if _rebuilding:
		return
	_rebuilding = true

	var layers:Array[CustomInputMap] = []
	_collect_maps( responder_root, layers )

	var effective:CustomInputMap = CustomInputMap.new()
	for layer:CustomInputMap in layers:
		# Later layers overwrite on name clash (merge default).
		effective.merge( layer )

	# Drop the previous merge so its duplicated events/actions free promptly.
	if effective_map != effective:
		_release_map( effective_map )
	effective_map = effective
	effective.apply_to_engine()
	input_map_changed.emit( effective )
	_rebuilding = false


# Connect and report failures (Signal.connect returns Error).
func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags ) as Error
	if err != OK:
		push_error( "InputManager._connect_sig: %s" % error_string( err ) )


func _release_map( map:CustomInputMap ) -> void:
	if not is_instance_valid( map ):
		return
	# Do not clear the shared stock cache here — [method clear_default_input_map_cache]
	# owns that. Runtime merges / snapshots can clear immediately.
	if map == _default_input_map:
		return
	map.clear()


func _release_responder_tree( node:Node ) -> void:
	if not is_instance_valid( node ):
		return
	if node is Responder:
		var responder:Responder = node as Responder
		_release_map( responder.input_map )
		responder.input_map = null
	for child:Node in node.get_children():
		_release_responder_tree( child )
