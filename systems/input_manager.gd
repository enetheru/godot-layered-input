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


const INPUT_MAP:CustomInputMap = preload( "default_input_map.tres" )


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var responder_root:Responder

## Last effective map pushed to the engine (for inspection and snapshots).
var effective_map:CustomInputMap

## Full deep copies of [member responder_root] for [method push_state] /
## [method pop_state] (whole-tree snapshots only).
var undo_stack:Array[Responder] = []

var _want_rebuild:bool = false
var _rebuilding:bool = false


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
	responder_root.input_map = INPUT_MAP
	add_child( responder_root )
	if not responder_root.child_order_changed.is_connected( _on_responder_tree_changed ):
		_connect_sig( responder_root.child_order_changed, _on_responder_tree_changed )

	request_rebuild()


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


func add_responder( node:Responder ) -> void:
	responder_root.add_responder( node )


## free is not called on the node removed from the tree.
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


#        ███████ ████████  █████  ████████ ██  ██████                          #
#        ██         ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ███████    ██    ██ ██                               #
#             ██    ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ██   ██    ██    ██  ██████                          #
func                        _________STATIC__________              ()->void:pass

static func compare_event(
			a:InputEvent,
			b:InputEvent,
			exact_match:bool = true ) -> bool:
	assert( a and b, "InputManager.compare_event: a or b is invalid" )
	return a == b or a.is_match( b, exact_match )


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
	assert( responder_root, "InputManager._rebuild_input_map: responder root missing" )
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

	effective_map = effective
	effective.apply_to_engine()
	input_map_changed.emit( effective )
	_rebuilding = false


# Connect and report failures (Signal.connect returns Error).
func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags ) as Error
	if err != OK:
		push_error( "InputManager._connect_sig: %s" % error_string( err ) )
