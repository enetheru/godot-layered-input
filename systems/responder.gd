class_name Responder
extends Node

##[codeblock]
##│ ___                          _
##│| _ \___ ____ __  ___ _ _  __| |___ _ _
##│|   / -_|_-< '_ \/ _ \ ' \/ _` / -_) '_|
##│|_|_\___/__/ .__/\___/_||_\__,_\___|_|
##╰───────────|_|────────────────────────────
##[/codeblock]Node in the [InputManager] responder tree.
##
## • [member input_map] — optional layer contributed while [member active].
##[br]
## • [member active] — when false, input processing is off and the map is
##   excluded from the merged engine [InputMap].
##[br][color=goldenrod]TODO[/color]:Document how game code should mount
## responders — defer until the plugin API is more mature (would need a rewrite
## if written too early).


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Layer contributed to the merged InputMap while this responder is active.
@export var input_map:CustomInputMap:
	set = set_input_map

## When false: no `_input*` callbacks and no map contribution.
@export var active:bool = true:
	set = set_active


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## Apply process flags from [member active] when entering the tree.
func _enter_tree() -> void:
	_sync_process_flags()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Property setter for [member input_map]; rebuilds when contribution changes.
func set_input_map( value:CustomInputMap ) -> void:
	if input_map == value:
		return
	var was_contributing:bool = contributes_map()
	input_map = value
	if was_contributing or contributes_map():
		_notify_map_dirty()


## Property setter for [member active]; toggles process flags and map contribution.
func set_active( value:bool ) -> void:
	if active == value:
		return
	var was_contributing:bool = contributes_map()
	active = value
	_sync_process_flags()
	if was_contributing or contributes_map():
		_notify_map_dirty()


## True when this node should contribute its [member input_map] to the merge.
func contributes_map() -> bool:
	return active and input_map != null


## Add a responder node to this branch. Does not free or replace existing
## siblings. Requests a map rebuild when the new branch can contribute layers.
func add_responder( node:Responder ) -> void:
	if not is_instance_valid( node ):
		push_warning( "Responder.add_responder: invalid node" )
		return
	if node.get_parent() == self:
		return
	if is_instance_valid( node.get_parent() ):
		push_warning( "Responder.add_responder: node already has a parent" )
		return
	var affects:bool = _branch_affects_map( node )
	add_child( node )
	if affects:
		_request_rebuild()


## Detach [param node] from this branch without freeing it. Rebuilds when the
## detached branch could have contributed to the merged map.
func remove_responder( node:Responder ) -> void:
	if node == null or node.get_parent() != self:
		return
	var affects:bool = _branch_affects_map( node )
	remove_child( node )
	if affects:
		_request_rebuild()


## Detach and return the last child [Responder] (does not free). [code]null[/code]
## if this node has no children.
func pop_responder() -> Node:
	var layers:Array = get_children()
	if layers.is_empty():
		return null
	var node:Responder = layers[-1] as Responder
	if node == null:
		return null
	var affects:bool = _branch_affects_map( node )
	remove_child( node )
	if affects:
		_request_rebuild()
	return node


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

func _sync_process_flags() -> void:
	set_process_input( active )
	set_process_unhandled_input( active )
	set_process_unhandled_key_input( active )


func _notify_map_dirty() -> void:
	if not is_inside_tree():
		return
	_request_rebuild()


func _request_rebuild() -> void:
	# Autoload can be a placeholder while the editor plugin reloads.
	if not is_instance_valid( InputManager ):
		return
	if not InputManager.has_method( &"request_rebuild" ):
		return
	InputManager.request_rebuild()


## Whether this node or a descendant can change the merged engine map.
func _branch_affects_map( node:Node ) -> bool:
	if is_instance_valid( InputManager ) \
	and InputManager.has_method( &"branch_affects_map" ):
		return InputManager.branch_affects_map( node ) as bool
	# Fallback before autoload is ready: local contribution only.
	if node is Responder:
		return (node as Responder).contributes_map()
	return false
