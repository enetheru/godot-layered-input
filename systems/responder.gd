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
##[br][color=goldenrod]TODO[/color]:Document how game code should mount responders.


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

func _enter_tree() -> void:
	_sync_process_flags()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func set_input_map( value:CustomInputMap ) -> void:
	if input_map == value:
		return
	input_map = value
	_notify_map_dirty()


func set_active( value:bool ) -> void:
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
func add_responder( node:Responder ) -> void:
	if not is_instance_valid( node ):
		push_warning( "Responder.add_responder: invalid node" )
		return
	InputManager.push_state()
	add_child( node )
	if node.contributes_map():
		InputManager.rebuild_input_map()


## Removing a responder does not free the node.
func remove_responder( node:Responder ) -> void:
	if node == null or node.get_parent() != self:
		return
	InputManager.push_state()
	remove_child( node )
	InputManager.rebuild_input_map()


func pop_responder() -> Node:
	var layers:Array = get_children()
	if layers.is_empty():
		return null
	InputManager.push_state()
	var node:Responder = layers[-1]
	remove_child( node )
	InputManager.rebuild_input_map()
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
	# Autoload can be a placeholder while the editor plugin reloads.
	if not is_instance_valid( InputManager ):
		return
	if not InputManager.has_method( &"rebuild_input_map" ):
		return
	InputManager.rebuild_input_map()
