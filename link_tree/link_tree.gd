extends RefCounted

##[codeblock lang=text]
##│ _    _      _     _
##│| |  (_)_ _ | |__ | |_ _ _ ___ ___
##│| |__| | ' \| / / |  _| '_/ -_) -_)
##│|____|_|_||_|_\_\  \__|_| \___\___|
##╰─────────────────────────────────────
##[/codeblock]Tree of link responders.
##
## Holds the root and links responders in parent and child lists.
##[br][br]
## Keeps a front-to-back walk for each callback. Index 0 sees the event first.
##[br][br]
## Each dispatch pass calls the walk and the callables copied at its start, and returns when the viewport is handled.
##[br][br]
## Preloads the live CustomInputMap and InputAction scripts.


## Live map script.
const CustomInputMapScript = preload( "../systems/custom_input_map.gd" )

## Live action script.
const InputActionScript = preload( "../systems/input_action.gd" )

## Record script.
const LinkResponderScript = preload( "link_responder.gd" )

## Stock root map. Assigned when the caller passes no map.
const DefaultInputMap:CustomInputMap = preload( "../settings/default_input_map.tres" )

## Callback property names, in pass order.
const CALLBACK_SLOTS:Array[StringName] = [
	&"_input",
	&"_shortcut_input",
	&"_unhandled_key_input",
	&"_unhandled_input",
]


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Root responder. The tree holds it, and its parent stays empty.
var root:RefCounted

## Front-to-back responders for [code]_input[/code].
var input_walk:Array[RefCounted] = []

## Front-to-back responders for [code]_shortcut_input[/code].
var shortcut_input_walk:Array[RefCounted] = []

## Front-to-back responders for [code]_unhandled_key_input[/code].
var unhandled_key_input_walk:Array[RefCounted] = []

## Front-to-back responders for [code]_unhandled_input[/code].
var unhandled_input_walk:Array[RefCounted] = []


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Creates the active root. [param map] replaces the stock map when set.
func _init( map:CustomInputMap = null ) -> void:
	root = LinkResponderScript.new()
	root.set( &"_tree", self )

	var initial:CustomInputMap = DefaultInputMap
	if map != null:
		initial = map
	root.set( &"input_map", initial )


## Appends [param record] as the root's last child.
func add_responder( record:Variant ) -> void:
	if record == root:
		push_warning( "LinkTree.add_responder: root stays held by the tree" )
		return

	root.call( &"add_responder", record )


## Detaches [param record] from its parent. The root stays on the tree.
func remove_responder( record:Variant ) -> void:
	if record == root:
		push_warning( "LinkTree.remove_responder: cannot remove root" )
		return
	if not _is_record( record ):
		return
	var other:Object = record
	var holder:Object = other.get( &"parent" )
	if holder == null or holder.get_script() != LinkResponderScript:
		return

	holder.call( &"remove_responder", record )


func _is_record( record:Variant ) -> bool:
	if not is_instance_valid( record ):
		return false
	var other:Object = record
	return other.get_script() == LinkResponderScript


#region Walks
#MARK: Walks
func                        __Walks__________________              ()->void:pass
# │__      __    _ _
# │\ \    / /_ _| | |__ ___
# │ \ \/\/ / _` | | / /(_-<
# │  \_/\_/\__,_|_|_\_\/__/
# ╰─────────────────────────

## Rewrites the stored walk for [param slot] from the current links.
func _rebuild_walk( slot:StringName ) -> void:
	var ordered:Array[RefCounted] = []
	if is_instance_valid( root ):
		_collect_preorder( root, slot, ordered )
	ordered.reverse()

	var walk:Array[RefCounted] = _walk_array( slot )
	walk.clear()
	walk.append_array( ordered )


## Rewrites each walk whose slot this record has filled.
func _rebuild_record( record:Object ) -> void:
	for slot:StringName in CALLBACK_SLOTS:
		if _slot_filled( record, slot ):
			_rebuild_walk( slot )


## Rewrites each walk an active filled slot in [param branch] touches.
func _rebuild_branch( branch:Object ) -> void:
	var slots:Array[StringName] = []
	_slots_in_branch( branch, slots )
	for slot:StringName in slots:
		_rebuild_walk( slot )


func _collect_preorder( record:Object, slot:StringName, out:Array[RefCounted] ) -> void:
	if _in_walk( record, slot ):
		out.append( record as RefCounted )
	var kids:Array = record.get( &"children" )
	for child:Variant in kids:
		var next:Object = child
		_collect_preorder( next, slot, out )


func _slots_in_branch( record:Object, slots:Array[StringName] ) -> void:
	var active:bool = record.get( &"active" )
	if active:
		for slot:StringName in CALLBACK_SLOTS:
			if _slot_filled( record, slot ) and not slots.has( slot ):
				slots.append( slot )
	var kids:Array = record.get( &"children" )
	for child:Variant in kids:
		var next:Object = child
		_slots_in_branch( next, slots )


func _in_walk( record:Object, slot:StringName ) -> bool:
	var active:bool = record.get( &"active" )
	return active and _slot_filled( record, slot )


func _slot_filled( record:Object, slot:StringName ) -> bool:
	var cb:Callable = record.get( slot )
	return cb.is_valid()


func _walk_array( slot:StringName ) -> Array[RefCounted]:
	if slot == &"_input":
		return input_walk
	if slot == &"_shortcut_input":
		return shortcut_input_walk
	if slot == &"_unhandled_key_input":
		return unhandled_key_input_walk
	return unhandled_input_walk

#endregion Walks


#region Dispatch
#MARK: Dispatch
func                        __Dispatch_______________              ()->void:pass
# │ ___  _               _      _
# │|   \(_)____ __  __ _| |_ __| |_
# │| |) | (_-< '_ \/ _` |  _/ _| ' \
# │|___/|_/__/ .__/\__,_|\__\__|_||_|
# ╰──────────|_|──────────────────────

## Calls the captured [code]_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_input( viewport:Viewport, event:InputEvent ) -> void:
	_dispatch( input_walk, &"_input", viewport, event )


## Calls the captured [code]_shortcut_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_shortcut_input( viewport:Viewport, event:InputEvent ) -> void:
	_dispatch( shortcut_input_walk, &"_shortcut_input", viewport, event )


## Calls the captured [code]_unhandled_key_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_unhandled_key_input( viewport:Viewport, event:InputEvent ) -> void:
	_dispatch( unhandled_key_input_walk, &"_unhandled_key_input", viewport, event )


## Calls the captured [code]_unhandled_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_unhandled_input( viewport:Viewport, event:InputEvent ) -> void:
	_dispatch( unhandled_input_walk, &"_unhandled_input", viewport, event )


## Copies [param walk] and each record's [param slot] callable, then calls that copy until [param viewport] is handled.
func _dispatch( walk:Array[RefCounted], slot:StringName, viewport:Viewport, event:InputEvent ) -> void:
	if not is_instance_valid( viewport ):
		push_warning( "LinkTree.dispatch: viewport is missing" )
		return

	var records:Array[RefCounted] = []
	records.assign( walk )
	var calls:Array[Callable] = []
	for record:RefCounted in records:
		var captured:Callable = record.get( slot )
		calls.append( captured )

	for cb:Callable in calls:
		if cb.is_valid():
			cb.call( event )
		if viewport.is_input_handled():
			return

#endregion Dispatch
