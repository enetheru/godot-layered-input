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
## A stock row that already shares those events stays. A layer edit rewrites the names that layer owns.

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

# A second request in the same idle waits on this, so the engine sees one table.
var _want_rebuild:bool = false

# Held across the engine write and the map signal, so an edit from that signal becomes a follow-up.
var _rebuilding:bool = false

# The queued compose rewrites every name. A patch leaves this clear.
var _full:bool = false

# Names a layer edit owns, kept until idle so that compose can skip the stock map.
var _patch_names:Dictionary[StringName, bool] = {}


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
	root.input_map = DefaultInputMap if map == null else map
	request_rebuild()


## Appends [param record] as the root's last child.
func add_responder( record:Responder ) -> void:
	assert( record != root, "ResponderTree.add_responder: record is the root" )
	root.add_responder( record )


## Detaches [param record] from its parent.
func remove_responder( record:Responder ) -> void:
	assert( record != root, "ResponderTree.remove_responder: record is the root" )
	record.parent.remove_responder( record )


#region Walks
#MARK: Walks
func                        __Walks__________________              ()->void:pass
# │__      __    _ _
# │\ \    / /_ _| | |__ ___
# │ \ \/\/ / _` | | / /(_-<
# │  \_/\_/\__,_|_|_\_\/__/
# ╰─────────────────────────

# The next event reads this list. A membership change leaves the stored order stale.
func _rebuild_walk( slot:StringName ) -> void:
	var ordered:Array[Responder] = []
	if is_instance_valid( root ):
		_collect_preorder( root, slot, ordered )
	ordered.reverse()

	var walk:Array[Responder] = _walk_array( slot )
	walk.clear()
	walk.append_array( ordered )


# The active flag is membership in every filled slot, so each of those walks is rewritten.
func _rebuild_record( record:Responder ) -> void:
	for slot:StringName in CALLBACK_SLOTS:
		if _slot_filled( record, slot ):
			_rebuild_walk( slot )


# One link change can touch several slots. Each of those walks is rewritten once.
func _rebuild_branch( branch:Responder ) -> void:
	var slots:Array[StringName] = []
	_slots_in_branch( branch, slots )

	for slot:StringName in slots:
		_rebuild_walk( slot )


# _rebuild_walk calls this only when root is valid.
# Stored order is parent, then children. The walk reverses that list, so collection has to be that order.
func _collect_preorder( record:Responder, slot:StringName, out:Array[Responder] ) -> void:
	if _in_walk( record, slot ):
		out.append( record )

	for child:Responder in record.children:
		_collect_preorder( child, slot, out )


# Several records in one branch can fill the same slot. The walk is rewritten once for that slot.
func _slots_in_branch( record:Responder, slots:Array[StringName] ) -> void:
	if record.active:
		for slot:StringName in CALLBACK_SLOTS:
			if _slot_filled( record, slot ) and not slots.has( slot ):
				slots.append( slot )

	for child:Responder in record.children:
		_slots_in_branch( child, slots )


# An inactive record, or an empty slot, is not a member of the pass.
func _in_walk( record:Responder, slot:StringName ) -> bool:
	return record.active and _slot_filled( record, slot )


# Membership is the callable. An empty slot stays off the walk.
func _slot_filled( record:Responder, slot:StringName ) -> bool:
	return _callback( record, slot ).is_valid()


# The walk speaks in slot names. The callable lives on the record under that name.
func _callback( record:Responder, slot:StringName ) -> Callable:
	match slot:
		&"_input":
			return record._input
		&"_shortcut_input":
			return record._shortcut_input
		&"_unhandled_key_input":
			return record._unhandled_key_input
		_:
			return record._unhandled_input


# The same slot name selects the list the pass will copy.
func _walk_array( slot:StringName ) -> Array[Responder]:
	match slot:
		&"_input":
			return input_walk
		&"_shortcut_input":
			return shortcut_input_walk
		&"_unhandled_key_input":
			return unhandled_key_input_walk
		_:
			return unhandled_input_walk

#endregion Walks


#region Map
#MARK: Map

## Queues one deferred rebuild of the whole table. Further requests wait for that rebuild to finish.
func request_rebuild() -> void:
	_full = true
	if not _want_rebuild:
		_schedule()


## Queues one deferred rewrite of [param names].
## A full rebuild already queued covers those names.
func request_patch( names:PackedStringArray ) -> void:
	if _full or names.is_empty():
		return

	var added:bool = false
	for action_name:StringName in names:
		if _patch_names.has( action_name ):
			continue

		_patch_names[action_name] = true
		added = true

	if added or not _want_rebuild:
		_schedule()


## Suspends until [signal rebuild_finished] while a rebuild is queued or running.
func until_rebuilt() -> void:
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


# Callers return when _want_rebuild is already set, so this is entered once per queued compose.
# Do not defer while _rebuilding. The running compose defers the one follow-up.
# A defer here as well would line up a second rebuild.
func _schedule() -> void:
	_want_rebuild = true
	if _rebuilding:
		return

	_rebuild_input_map.call_deferred( false )


# Callers return when a compose is already queued. _schedule defers this only when not _rebuilding.
# The running compose defers the one follow-up after _rebuilding is cleared.
# A direct call composes every name. An idle call passes false.
# This returns when a compose is in progress, when that idle call finds the queue consumed,
# or when the root is gone.
func _rebuild_input_map( force_full:bool = true ) -> void:
	if _rebuilding:
		return

	if not force_full and not _want_rebuild:
		return

	if not is_instance_valid( root ):
		_want_rebuild = false
		_full = false
		_patch_names.clear()
		rebuild_finished.emit()
		return

	var full:bool = force_full or _full
	var pending:Dictionary[StringName, bool] = {}
	if not full:
		for action_name:StringName in _patch_names:
			pending[action_name] = true

	_full = false
	_patch_names.clear()
	_want_rebuild = false
	_rebuilding = true

	if effective_map == null:
		effective_map = CustomInputMap.new()
		full = true

	CustomInputMap._sweep_cached_events()
	var dirty:Dictionary[StringName, bool] = {}
	if full:
		_compose_all( dirty )
	else:
		_compose_names( pending, dirty )

	_write_dirty( dirty )
	input_map_changed.emit( effective_map )
	_rebuilding = false
	if _want_rebuild:
		_rebuild_input_map.call_deferred( false )
		return

	rebuild_finished.emit()


# _rebuild_input_map calls this only after its own early returns, so the root is present.
# Front write stays, then the startup map fills a name nobody wrote. A row that already matches is left in place.
func _compose_all( dirty:Dictionary[StringName, bool] ) -> void:
	var claimed:Dictionary[StringName, bool] = {}
	var layers:Array[CustomInputMap] = []
	_collect_maps( root, layers )
	layers.reverse()
	for layer:CustomInputMap in layers:
		var share:bool = _shares_row( layer )
		for action_name:StringName in layer.get_action_names():
			if claimed.has( action_name ):
				continue

			claimed[action_name] = true
			if effective_map.project_action( action_name,
						layer.get_action( action_name ), share ):
				dirty[action_name] = true

	var baseline:CustomInputMap = CustomInputMap.engine_baseline()
	for action_name:StringName in baseline.get_action_names():
		if claimed.has( action_name ):
			continue

		claimed[action_name] = true
		if effective_map.project_action( action_name,
					baseline.get_action( action_name ), true ):
			dirty[action_name] = true

	var present:Array[StringName] = effective_map.get_action_names()
	for action_name:StringName in present:
		if claimed.has( action_name ):
			continue

		effective_map.release_action( action_name )
		dirty[action_name] = true


# _rebuild_input_map calls this only after its own early returns, and only for a patch.
# A layer edit owns a few names. The other rows, including stock, stay where they are.
func _compose_names(
		names:Dictionary[StringName, bool],
		dirty:Dictionary[StringName, bool] ) -> void:
	var baseline:CustomInputMap = CustomInputMap.engine_baseline()
	for action_name:StringName in names:
		var winner:CustomInputMap = _front_map( root, action_name )
		var source:CustomInputMap = winner
		var share:bool = false
		if winner == null and baseline.has_action( action_name ):
			source = baseline
			share = true

		if source == null:
			if effective_map.has_action( action_name ):
				effective_map.release_action( action_name )
				dirty[action_name] = true
			elif InputMap.has_action( action_name ):
				dirty[action_name] = true
			continue

		if winner != null:
			share = _shares_row( winner )

		if effective_map.project_action(
				action_name, source.get_action( action_name ), share ):
			dirty[action_name] = true


# Children are visited before the parent, last child first, so the front write is the one that wins.
func _front_map( record:Responder, action_name:StringName ) -> CustomInputMap:
	var kids:Array[Responder] = record.children
	for index:int in range( kids.size() - 1, -1, -1 ):
		var found:CustomInputMap = _front_map( kids[index], action_name )
		if found != null:
			return found

	if record.contributes_map() and record.input_map.has_action( action_name ):
		return record.input_map

	return null


# Stock and the startup engine map are the rows a later compose must not copy.
func _shares_row( layer:CustomInputMap ) -> bool:
	return layer == DefaultInputMap or layer == CustomInputMap.engine_baseline()


# An unchanged name is already on the engine. A name that left the table has to leave the engine with it.
func _write_dirty( dirty:Dictionary[StringName, bool] ) -> void:
	for action_name:StringName in dirty:
		if effective_map.has_action( action_name ):
			effective_map.apply_action( action_name )
		elif InputMap.has_action( action_name ):
			InputMap.erase_action( action_name )


# An inactive parent stays out of the table. An active child is still a layer of its own.
func _collect_maps( record:Responder, out:Array[CustomInputMap] ) -> void:
	if record.contributes_map():
		out.append( record.input_map )

	for child:Responder in record.children:
		_collect_maps( child, out )

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
	if is_instance_valid( viewport ):
		_dispatch( input_walk, &"_input", viewport, event )
		return
	push_warning( "ResponderTree.dispatch: viewport is missing" )


## Calls the captured [code]_shortcut_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_shortcut_input( viewport:Viewport, event:InputEvent ) -> void:
	if is_instance_valid( viewport ):
		_dispatch( shortcut_input_walk, &"_shortcut_input", viewport, event )
		return
	push_warning( "ResponderTree.dispatch: viewport is missing" )


## Calls the captured [code]_unhandled_key_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_unhandled_key_input( viewport:Viewport, event:InputEvent ) -> void:
	if is_instance_valid( viewport ):
		_dispatch( unhandled_key_input_walk, &"_unhandled_key_input", viewport, event )
		return
	push_warning( "ResponderTree.dispatch: viewport is missing" )


## Calls the captured [code]_unhandled_input[/code] callables with [param event] until [param viewport] is handled.
func dispatch_unhandled_input( viewport:Viewport, event:InputEvent ) -> void:
	if is_instance_valid( viewport ):
		_dispatch( unhandled_input_walk, &"_unhandled_input", viewport, event )
		return
	push_warning( "ResponderTree.dispatch: viewport is missing" )


# Callers return when the viewport is missing. This pass assumes that viewport is live.
# The pass copies the callables it will call. A handler may add or remove a responder
# before it returns, and this event still belongs to the responders that were in front.
func _dispatch( walk:Array[Responder], slot:StringName, viewport:Viewport, event:InputEvent ) -> void:
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
