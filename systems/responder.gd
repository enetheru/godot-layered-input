extends RefCounted

##[codeblock lang=text]
##│ ___                          _
##│| _ \___ ____ __  ___ _ _  __| |___ _ _
##│|   / -_|_-< '_ \/ _ \ ' \/ _` / -_) '_|
##│|_|_\___/__/ .__/\___/_||_\__,_\___|_|
##╰───────────|_|────────────────────────────
##[/codeblock]One layer's claim on what an input means.
##
## [member parent] and [member children] link it into a [ResponderTree]. The root leaves [member parent] empty.
##[br][br]
## While [member active] is set and [member input_map] is set, the tree merges that map. A filled callback joins the walk for that pass.

const ResponderTree = preload( "responder_tree.gd" )
const Responder = preload( "responder.gd" )


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## CustomInputMap this responder contributes.
var input_map:CustomInputMap:
	set = set_input_map

## Process flag. Walk membership and [method contributes_map] read it.
var active:bool = true:
	set = set_active

## Callable for the pass before the GUI. It takes the [InputEvent].
## An empty callable stays off that walk. Filling or clearing rewrites it.
var _input:Callable:
	set = set_input_callback

## Callable for the pass after the GUI for a key, a shortcut, or a joypad button.
## An empty callable stays off that walk. Filling or clearing rewrites it.
var _shortcut_input:Callable:
	set = set_shortcut_input

## Callable for a key still unhandled after the shortcut pass.
## An empty callable stays off that walk. Filling or clearing rewrites it.
var _unhandled_key_input:Callable:
	set = set_unhandled_key_input

## Callable for an event still left after the key pass.
## An empty callable stays off that walk. Filling or clearing rewrites it.
var _unhandled_input:Callable:
	set = set_unhandled_input

## Responder this one is linked under. The root keeps this empty.
var parent:Responder

## Child responders, first to last. [method add_responder] appends.
var children:Array[Responder] = []

## Tree that stores the walks while this record is linked there.
var _tree:ResponderTree


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Writes the map when [param value] differs from the current map.
## Requests a rebuild when the contribution changes.
func set_input_map( value:CustomInputMap ) -> void:
	if input_map == value:
		return

	var was_contributing:bool = contributes_map()
	input_map = value
	if was_contributing or contributes_map():
		_request_map()


## Writes the process flag when [param value] differs from the current flag.
## Each filled slot's walk is rewritten from the tree.
func set_active( value:bool ) -> void:
	if active == value:
		return

	var was_contributing:bool = contributes_map()
	active = value
	_notify_record()
	if was_contributing or contributes_map():
		_request_map()


## Writes [param value] and rewrites the input walk when the slot gains or loses its callable.
func set_input_callback( value:Callable ) -> void:
	if _input == value:
		return
	var was_filled:bool = _input.is_valid()
	_input = value
	if was_filled == _input.is_valid():
		return
	_notify_walk( &"_input" )


## Writes [param value] and rewrites the shortcut walk when the slot gains or loses its callable.
func set_shortcut_input( value:Callable ) -> void:
	if _shortcut_input == value:
		return
	var was_filled:bool = _shortcut_input.is_valid()
	_shortcut_input = value
	if was_filled == _shortcut_input.is_valid():
		return
	_notify_walk( &"_shortcut_input" )


## Writes [param value] and rewrites the key walk when the slot gains or loses its callable.
func set_unhandled_key_input( value:Callable ) -> void:
	if _unhandled_key_input == value:
		return
	var was_filled:bool = _unhandled_key_input.is_valid()
	_unhandled_key_input = value
	if was_filled == _unhandled_key_input.is_valid():
		return
	_notify_walk( &"_unhandled_key_input" )


## Writes [param value] and rewrites the unhandled walk when the slot gains or loses its callable.
func set_unhandled_input( value:Callable ) -> void:
	if _unhandled_input == value:
		return
	var was_filled:bool = _unhandled_input.is_valid()
	_unhandled_input = value
	if was_filled == _unhandled_input.is_valid():
		return
	_notify_walk( &"_unhandled_input" )


func _notify_walk( slot:StringName ) -> void:
	if _tree == null:
		return
	_tree._rebuild_walk( slot )


func _notify_record() -> void:
	if _tree == null:
		return
	_tree._rebuild_record( self )


func _request_map() -> void:
	if _tree == null:
		return
	_tree.request_rebuild()


## True when [member active] is set and [member input_map] is set.
func contributes_map() -> bool:
	return active and input_map != null


#region Children
#MARK: Children
func                        __Children_______________              ()->void:pass
# │  ___ _    _ _    _
# │ / __| |_ (_) |__| |_ _ ___ _ _
# │| (__| ' \| | / _` | '_/ -_) ' \
# │ \___|_||_|_|_\__,_|_| \___|_||_|
# ╰──────────────────────────────────

## Appends [param record] as the last child.
func add_responder( record:Responder ) -> void:
	if not is_instance_valid( record ) or not record is Responder:
		push_warning( "Responder.add_responder: record is missing or uses another script" )
		return
	if record == self:
		push_warning( "Responder.add_responder: record is this responder" )
		return
	if record.parent == self:
		return
	if record.parent != null:
		push_warning( "Responder.add_responder: record already has a parent" )
		return
	if record._tree != null:
		push_warning( "Responder.add_responder: record is held by a tree" )
		return

	record.parent = self
	children.append( record )
	if _tree == null:
		return
	_bind_tree( record, _tree )
	_request_branch( _tree, record )


## Detaches [param record] when this responder is its parent. The caller keeps the record.
func remove_responder( record:Responder ) -> void:
	if not is_instance_valid( record ) or not record is Responder:
		return
	if record.parent != self:
		return

	var owner:ResponderTree = _tree
	record.parent = null
	children.erase( record )
	_unbind_tree( record )
	_request_branch( owner, record )


## Detaches and returns the last child. Returns null when [member children] is empty.
func pop_responder() -> Responder:
	if children.is_empty():
		return null

	var record:Responder = children[-1]
	remove_responder( record )
	return record


func _request_branch( owner:ResponderTree, branch:Responder ) -> void:
	if owner == null:
		return
	owner._rebuild_branch( branch )
	if owner.branch_affects_map( branch ):
		owner.request_rebuild()


func _bind_tree( record:Responder, tree:ResponderTree ) -> void:
	record._tree = tree
	for child:Responder in record.children:
		_bind_tree( child, tree )


func _unbind_tree( record:Responder ) -> void:
	record._tree = null
	for child:Responder in record.children:
		_unbind_tree( child )

#endregion Children
