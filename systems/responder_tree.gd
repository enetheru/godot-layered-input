extends RefCounted

##[codeblock lang=text]
##│ ___                          _           _____
##│| _ \___ ____ __  ___ _ _  __| |___ _ _  |_   _| _ ___ ___
##│|   / -_|_-< '_ \/ _ \ ' \/ _` / -_) '_|   | || '_/ -_) -_)
##│|_|_\___/__/ .__/\___/_||_\__,_\___|_|     |_||_| \___\___|
##╰───────────|_|───────────────────────────────────────────────
##[/codeblock]Orders responders and runs each input pass.
##
## Children are stored first to last under [member root]. Each walk reverses that order, so the last child is index 0 and sees the event first.
##[br][br]
## A pass calls the callables copied at its start, and stops when the viewport is handled.
##[br][br]
## [member effective_map] keeps the first write of each name. The startup engine map fills a name the responders left empty, and that fill keeps the engine's events.

## Record script.
const Responder = preload( "responder.gd" )

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
var root:Responder

## Front-to-back responders for [code]_input[/code].
var input_walk:Array[Responder] = []

## Front-to-back responders for [code]_shortcut_input[/code].
var shortcut_input_walk:Array[Responder] = []

## Front-to-back responders for [code]_unhandled_key_input[/code].
var unhandled_key_input_walk:Array[Responder] = []

## Front-to-back responders for [code]_unhandled_input[/code].
var unhandled_input_walk:Array[Responder] = []

## Table composed from contributing maps, front first.
var effective_map:CustomInputMap

## Emitted with the settled table while a rebuild is still marked running.
signal input_map_changed( effective:CustomInputMap )

## Emitted when a queued rebuild has settled and no follow-up is waiting.
signal rebuild_finished

## Set while a rebuild is queued.
var _want_rebuild:bool = false

## Set through [method apply_to_engine] and [signal input_map_changed].
var _rebuilding:bool = false


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Creates the active root. [param map] replaces the stock map when set.
func _init( map:CustomInputMap = null ) -> void:
	# Before request_rebuild. A later read would see the merged table.
	var _baseline:CustomInputMap = CustomInputMap.engine_baseline()
	root = Responder.new()
	root._tree = self

	var initial:CustomInputMap = DefaultInputMap
	if map != null:
		initial = map
	root.input_map = initial
	request_rebuild()


## Appends [param record] as the root's last child.
func add_responder( record:Responder ) -> void:
	if record == root:
		push_warning( "ResponderTree.add_responder: root stays held by the tree" )
		return

	root.add_responder( record )


## Detaches [param record] from its parent. The root stays on the tree.
func remove_responder( record:Responder ) -> void:
	if record == root:
		push_warning( "ResponderTree.remove_responder: cannot remove root" )
		return
	var holder:RefCounted = record.parent
	if not holder is Responder:
		return

	var parent_record:Responder = holder
	parent_record.remove_responder( record )


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
	var ordered:Array[Responder] = []
	if is_instance_valid( root ):
		_collect_preorder( root, slot, ordered )
	ordered.reverse()

	var walk:Array[Responder] = _walk_array( slot )
	walk.clear()
	walk.append_array( ordered )


## Rewrites each walk whose slot this record has filled.
func _rebuild_record( record:Responder ) -> void:
	for slot:StringName in CALLBACK_SLOTS:
		if _slot_filled( record, slot ):
			_rebuild_walk( slot )


## Rewrites each walk an active filled slot in [param branch] touches.
func _rebuild_branch( branch:Responder ) -> void:
	var slots:Array[StringName] = []
	_slots_in_branch( branch, slots )
	for slot:StringName in slots:
		_rebuild_walk( slot )


func _collect_preorder( record:Responder, slot:StringName, out:Array[Responder] ) -> void:
	if _in_walk( record, slot ):
		out.append( record )
	for child:Responder in record.children:
		_collect_preorder( child, slot, out )


func _slots_in_branch( record:Responder, slots:Array[StringName] ) -> void:
	if record.active:
		for slot:StringName in CALLBACK_SLOTS:
			if _slot_filled( record, slot ) and not slots.has( slot ):
				slots.append( slot )
	for child:Responder in record.children:
		_slots_in_branch( child, slots )


func _in_walk( record:Responder, slot:StringName ) -> bool:
	return record.active and _slot_filled( record, slot )


func _slot_filled( record:Responder, slot:StringName ) -> bool:
	return _callback( record, slot ).is_valid()


func _callback( record:Responder, slot:StringName ) -> Callable:
	if slot == &"_input":
		return record._input
	if slot == &"_shortcut_input":
		return record._shortcut_input
	if slot == &"_unhandled_key_input":
		return record._unhandled_key_input
	return record._unhandled_input


func _walk_array( slot:StringName ) -> Array[Responder]:
	if slot == &"_input":
		return input_walk
	if slot == &"_shortcut_input":
		return shortcut_input_walk
	if slot == &"_unhandled_key_input":
		return unhandled_key_input_walk
	return unhandled_input_walk

#endregion Walks


#region Map
#MARK: Map

## Queues one deferred rebuild. Further requests wait for that rebuild to finish.
func request_rebuild() -> void:
	if _want_rebuild:
		return
	_want_rebuild = true
	if _rebuilding:
		return
	_rebuild_input_map.call_deferred()


## Suspends until [signal rebuild_finished] while a rebuild is queued or running.
func until_rebuilt() -> void:
	if not _want_rebuild and not _rebuilding:
		return
	while _want_rebuild or _rebuilding:
		await rebuild_finished


## True when [param record] or a descendant contributes a map.
func branch_affects_map( record:Responder ) -> bool:
	if not is_instance_valid( record ):
		return false
	if record.contributes_map():
		return true
	for child:Responder in record.children:
		if branch_affects_map( child ):
			return true
	return false


## Builds [member effective_map] from the front and writes it to the engine.
func _rebuild_input_map() -> void:
	if _rebuilding:
		return
	if not is_instance_valid( root ):
		_want_rebuild = false
		rebuild_finished.emit()
		return
	_want_rebuild = false
	_rebuilding = true

	var layers:Array[CustomInputMap] = []
	_collect_maps( root, layers )
	layers.reverse()

	var effective:CustomInputMap = CustomInputMap.new()
	for layer:CustomInputMap in layers:
		effective.merge( layer, false, false )
	effective.install( CustomInputMap.engine_baseline(), false )

	if effective_map != effective:
		_release_map( effective_map )
	effective_map = effective
	effective.apply_to_engine()
	input_map_changed.emit( effective )
	_rebuilding = false
	if _want_rebuild:
		_rebuild_input_map.call_deferred()
		return
	rebuild_finished.emit()


func _collect_maps( record:Responder, out:Array[CustomInputMap] ) -> void:
	if record.contributes_map():
		out.append( record.input_map )
	for child:Responder in record.children:
		_collect_maps( child, out )


func _release_map( map:CustomInputMap ) -> void:
	if not is_instance_valid( map ):
		return
	if map == DefaultInputMap:
		return
	map.clear()

#endregion Map


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
func _dispatch( walk:Array[Responder], slot:StringName, viewport:Viewport, event:InputEvent ) -> void:
	if not is_instance_valid( viewport ):
		push_warning( "ResponderTree.dispatch: viewport is missing" )
		return

	var records:Array[Responder] = []
	records.assign( walk )
	var calls:Array[Callable] = []
	for record:Responder in records:
		var captured:Callable = _callback( record, slot )
		calls.append( captured )

	for cb:Callable in calls:
		if cb.is_valid():
			cb.call( event )
		if viewport.is_input_handled():
			return

#endregion Dispatch
