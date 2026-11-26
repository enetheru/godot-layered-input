@tool
class_name CustomInputMap
extends Resource

##[codeblock]
##│  ___        _               ___                _     __  __
##│ / __|  _ __| |_ ___ _ __   |_ _|_ _  _ __ _  _| |_  |  \/  |__ _ _ __
##│| (_| || (_-<  _/ _ \ '  \   | || ' \| '_ \ || |  _| | |\/| / _` | '_ \
##│ \___\_,_/__/\__\___/_|_|_| |___|_||_| .__/\_,_|\__| |_|  |_\__,_| .__/
##╰─────────────────────────────────────|_|─────────────────────────|_|─────
##[/codeblock]Resource representing one input-mapping layer.
##
## Layers are link responders. [InputManager] owns one link tree, merges the
## active maps, and applies the result to the engine [InputMap] singleton.
## [br][br]
## There is no implicit project-settings base map — only maps contributed by
## active responders. Create `.tres` assets by hand and assign them on responders.
## [br]Action names are the keys of [member _actions], in the same order as
## [method get_action_names].


## Default deadzone for materialised [InputAction]s on this map.
const DEFAULT_DEADZONE:float = 0.2

## Larger deadzone for toggle-style actions (engine default for many [code]ui_*[/code]).
const DEFAULT_TOGGLE_DEADZONE:float = 0.5

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Engine map captured at startup, before the first rebuild writes [InputMap].
static var _engine_baseline:CustomInputMap


## Maps action names to [InputAction] definitions (or [code]null[/code]).
## [br][code]null[/code] is a name-only placeholder (panel “add name” with no
## events yet). An empty [InputAction] resource is also legal (Inspector).
## [br][b]Editor note:[/b] in-place [code]dict[k]=…[/code] edits do [i]not[/i]
## refresh the Inspector dictionary; mutate via the methods below (they call
## [method refresh_actions_inspector] on structure changes).
@export var _actions:Dictionary[StringName, InputAction] = {}:
	set( value ):
		_actions = value
		emit_changed()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## The inspector has no revert on this map. [member _actions] would otherwise
## revert to an empty dictionary and wipe the layer.
func _property_can_revert( _property:StringName ) -> bool:
	return false


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

#region Query
#MARK: Query
func                        __Query__________________              ()->void:pass
# │  ___
# │ / _ \ _  _ ___ _ _ _  _
# │| (_) | || / -_) '_| || |
# │ \__\_\\_,_\___|_|  \_, |
# ╰────────────────────|__/───

## True if the action name exists (value may still be null — treated as empty def).
func has_action( action_name:StringName ) -> bool:
	return _actions.has( action_name )


## True if the action name exists and has a non-null [InputAction] definition.
func has_action_def( action_name:StringName ) -> bool:
	return _actions.get( action_name ) != null


## The [InputAction] for [param action_name], or null if missing / placeholder.
func get_action( action_name:StringName ) -> InputAction:
	return _actions.get( action_name )


## equivalent to Dictionary.keys()
func get_action_names() -> Array[StringName]:
	return _actions.keys()


## equivalent to Dictionary.values()
func get_actions() -> Array[InputAction]:
	return _actions.values()


## Returns deadzone, or [constant DEFAULT_DEADZONE] when missing/null (no warning).
## Null definitions are intentional placeholders — same as a default-constructed def.
func get_action_deadzone( action_name:StringName ) -> float:
	var ia:InputAction = _actions.get( action_name )
	# Resources: prefer null-check over [method @GlobalScope.is_instance_valid]
	# (editor proxies can lie; see InputMapEditor open_maps notes).
	return ia.deadzone if ia != null else DEFAULT_DEADZONE


## Copy of stored events (never aliases the live [member InputAction.events] array).
func get_action_events( action_name:StringName ) -> Array[InputEvent]:
	var ia:InputAction = _actions.get( action_name )
	var out:Array[InputEvent] = []
	if ia == null:
		return out
	out.assign( ia.events )
	return out

#endregion Query


#region Mutate
#MARK: Mutate
func                        __Mutate_________________              ()->void:pass
# │ __  __      _        _
# │|  \/  |_  _| |_ __ _| |_ ___
# │| |\/| | || |  _/ _` |  _/ -_)
# │|_|  |_|\_,_|\__\__,_|\__\___|
# ╰────────────────────────────────

## True when [param ia] is null or empty at [constant InputAction.DEFAULT_DEADZONE]
## (equivalent to a name-only placeholder).
static func is_trivial_action_def( ia:InputAction ) -> bool:
	if ia == null:
		return true
	if not is_equal_approx( ia.deadzone, InputAction.DEFAULT_DEADZONE ):
		return false
	var evs:Array[InputEvent] = ia.events
	for i:int in evs.size():
		if is_instance_valid( evs[i] ):
			return false
	return true


## Force the Inspector to see `_actions` updates after in-place dict edits.
## Shallow-copies the dictionary (same [InputAction] instances) so
## [code]EditorPropertyDictionary[/code] receives a property write, then
## [method Object.notify_property_list_changed].
func refresh_actions_inspector() -> void:
	var copy:Dictionary[StringName, InputAction] = {}
	for k:StringName in _actions:
		copy[k] = _actions[k]
	_actions = copy
	notify_property_list_changed()


## [method Resource.emit_changed] only (value edits on nested actions; no
## dictionary rebuild — keeps expanded Inspector rows open).
func notify_actions_values_changed() -> void:
	emit_changed()


## Ensure the action [param action_name] key exists. New names are stored as
## [code]null[/code] placeholders (no empty [InputAction] resource).
func ensure_action_name( action_name:StringName ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.ensure_action_name: empty action_name" )
	if _actions.has( action_name ):
		return
	_actions[action_name] = null
	refresh_actions_inspector()


## Ensure a non-null [InputAction] exists for [param action_name] and return it.
## Materializes null placeholders (allowed by the resource model).
func ensure_action(
			action_name:StringName,
			deadzone:float = DEFAULT_DEADZONE ) -> InputAction:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.ensure_action: empty action_name" )
	var ia:InputAction = _actions.get( action_name )
	if ia != null:
		return ia
	ia = InputAction.new( deadzone )
	_actions[action_name] = ia
	refresh_actions_inspector()
	return ia


## Add or update action [param action_name].
## [br]New name with empty [param events] and default [param deadzone] stores a
## [code]null[/code] placeholder (returns [code]null[/code]).
## [br]Existing non-null defs are not wiped: deadzone/events merge in; returns
## the live [InputAction].
func add_action(
			action_name:StringName,
			deadzone:float = DEFAULT_DEADZONE,
			events:Array[InputEvent] = [] ) -> InputAction:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.add_action: empty action_name" )
	var ia:InputAction = _actions.get( action_name )
	if ia != null:
		push_warning( "CustomInputMap.add_action:",
				"action '%s' already exists (deadzone %s)" % [action_name, ia.deadzone] )
		# Do not wipe an existing def when called again with empty defaults.
		if not is_equal_approx( ia.deadzone, deadzone ):
			ia.deadzone = deadzone
		for ie:InputEvent in events:
			var dup:InputEvent = ie.duplicate()
			ia.add_event( dup )
		return ia
	# New name, no events, default deadzone → null placeholder (panel-style).
	# Inspector may still author an empty InputAction resource separately.
	if events.is_empty() and is_equal_approx( deadzone, DEFAULT_DEADZONE ):
		_actions[action_name] = null
		refresh_actions_inspector()
		return null
	# Key may exist with null value — materialize instead of no-op.
	ia = ensure_action( action_name, deadzone )
	if not is_equal_approx( ia.deadzone, deadzone ):
		ia.deadzone = deadzone
	for ie:InputEvent in events:
		var dup:InputEvent = ie.duplicate()
		ia.add_event( dup )
	return ia


## Remove [param action_name] and its definition. Warns if the name is missing.
func erase_action( action_name:StringName ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.erase_action: empty action_name" )
	if not _actions.erase( action_name ):
		push_warning( "CustomInputMap.erase_action: action '%s' not found" % action_name )
		return
	refresh_actions_inspector()


## Move an existing action to [param new_name], keeping the same [InputAction]
## instance (Inspector can stay on that resource). Warns on missing source or
## clashing destination.
func rename_action( old_name:StringName, new_name:StringName ) -> void:
	assert( not String( old_name ).is_empty(),
			"CustomInputMap.rename_action: empty old_name" )
	assert( not String( new_name ).is_empty(),
			"CustomInputMap.rename_action: empty new_name" )
	if old_name == new_name:
		return
	if not _actions.has( old_name ):
		push_warning(
				"CustomInputMap.rename_action: action '%s' not found" % old_name )
		return
	if _actions.has( new_name ):
		push_warning(
				"CustomInputMap.rename_action: target '%s' already exists"
				% new_name )
		return
	var ia:InputAction = _actions[old_name]
	@warning_ignore( "return_value_discarded" )
	_actions.erase( old_name )
	_actions[new_name] = ia
	refresh_actions_inspector()


## Reorder keys to [param ordered_names] (permutation). Keeps the same
## [InputAction] instances. Names missing from the map are skipped; keys not
## listed are appended in their previous order.
func reorder_actions( ordered_names:Array[StringName] ) -> void:
	var next:Dictionary[StringName, InputAction] = {}
	var seen:Dictionary = {}
	for k:StringName in ordered_names:
		if not _actions.has( k ) or seen.has( k ):
			continue
		next[k] = _actions[k]
		seen[k] = true
	for k:StringName in _actions:
		if seen.has( k ):
			continue
		next[k] = _actions[k]
	_actions = next
	notify_property_list_changed()


## Set deadzone on [param action_name], materializing a def if needed.
func set_action_deadzone( action_name:StringName, deadzone:float ) -> void:
	# ensure_action asserts non-empty name.
	var ia:InputAction = ensure_action( action_name, deadzone )
	ia.deadzone = deadzone


## Append a duplicate-safe [param event] to [param action_name] (materializes def).
func add_action_event( action_name:StringName, event:InputEvent ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.add_action_event: empty action_name" )
	assert( is_instance_valid( event ),
			"CustomInputMap.add_action_event: invalid event" )
	var ia:InputAction = ensure_action( action_name )
	ia.add_event( event )


## Remove [param event] from [param action_name] via [method InputAction.erase_event].
## No-op (warning) when the name has no [InputAction] def.
func erase_action_event( action_name:StringName, event:InputEvent ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.erase_action_event: empty action_name" )
	assert( is_instance_valid( event ),
			"CustomInputMap.erase_action_event: invalid event" )
	var ia:InputAction = _actions.get( action_name )
	if ia == null:
		push_warning(
				"CustomInputMap.erase_action_event: no InputAction for '%s'"
				% action_name )
		return
	ia.erase_event( event )


## Clear all events on [param action_name] without removing the name or def.
## No-op (warning) when the name has no [InputAction] def.
func clear_action_events( action_name:StringName ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.clear_action_events: empty action_name" )
	var ia:InputAction = _actions.get( action_name )
	if ia == null:
		push_warning(
				"CustomInputMap.clear_action_events: no InputAction for '%s'"
				% action_name )
		return
	ia.clear_events()


## Keep the action name but drop the [InputAction] resource ([code]null[/code]
## placeholder). No-op if the name is missing.
## [br]Used by the Input Map panel when the [b]last[/b] event is removed and
## deadzone is default — not when the Inspector authors an empty [InputAction].
func clear_action_def( action_name:StringName ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.clear_action_def: empty action_name" )
	if not _actions.has( action_name ):
		push_warning(
				"CustomInputMap.clear_action_def: action '%s' not found"
				% action_name )
		return
	if _actions.get( action_name ) == null:
		return
	_actions[action_name] = null
	refresh_actions_inspector()


## Panel helper: if [param action_name] has no events and default deadzone,
## store [code]null[/code] (keep the name). Returns true when dematerialized.
## Do [b]not[/b] call from generic mutate paths — empty Inspector-authored
## actions must remain legal.
func dematerialize_if_trivial( action_name:StringName ) -> bool:
	if not _actions.has( action_name ):
		return false
	var ia:InputAction = _actions.get( action_name )
	if ia == null:
		return false
	if not is_trivial_action_def( ia ):
		return false
	clear_action_def( action_name )
	return true


## Drop every action and its events so [InputEvent] / [InputAction] refcounts
## can fall immediately (shutdown, tests, large temporary snapshots).
func clear() -> void:
	for action_name:StringName in get_action_names():
		var ia:InputAction = _actions.get( action_name )
		if is_instance_valid( ia ):
			ia.clear_events()
	_actions.clear()
	refresh_actions_inspector()

#endregion Mutate


#region Clone / Merge
#MARK: Clone / Merge
func                        __Clone___Merge__________              ()->void:pass
# │  ___ _                  __  __  __
# │ / __| |___ _ _  ___    / / |  \/  |___ _ _ __ _ ___
# │| (__| / _ \ ' \/ -_)  / /  | |\/| / -_) '_/ _` / -_)
# │ \___|_\___/_||_\___| /_/   |_|  |_\___|_| \__, \___|
# ╰───────────────────────────────────────────|___/───────

## Deep copy suitable for merge intermediates and whole-map snapshots.
func duplicate_map() -> CustomInputMap:
	var dup:CustomInputMap = CustomInputMap.new()
	dup.resource_name = resource_name
	for action_name:StringName in _actions:
		var ia:InputAction = _actions[action_name]
		dup._actions[action_name] = (
				ia.duplicate_action() if is_instance_valid( ia ) else null )
	return dup


## Fold [param other] into this map in place (same shape as [method Dictionary.merge]).
## [br]Same action names are replaced wholesale (not event-appended).
## When [param overwrite] is [code]true[/code] (default), [param other] wins on
## clash — later input layers override earlier ones. When [code]false[/code],
## existing names are kept (Dictionary default; less common for layer stacks).
## [br]The copied events are kept while the source action still holds those same
## event objects. [param refresh] updates the inspector dictionary.
func merge(
		other:CustomInputMap,
		overwrite:bool = true,
		refresh:bool = true ) -> void:
	assert( is_instance_valid( other ), "CustomInputMap.merge: other is invalid" )
	_sweep_cached_events()
	for action_name:StringName in other._actions:
		if not overwrite and _actions.has( action_name ):
			continue
		var ia:InputAction = other._actions[action_name]
		# Preserve null placeholders; do not invent empty InputAction resources.
		_actions[action_name] = (
				InputAction.new( ia.deadzone, _cached_events( ia ) ) if ia != null else null )
	if refresh:
		refresh_actions_inspector()


## Instance id of a source action to its duplicated events and the objects they came from.
static var _dup_events:Dictionary = {}


## Duplicated events for [param ia]. The copy stays while [param ia] still holds
## the same event objects. A field edit on one of those objects is not seen here.
func _cached_events( ia:InputAction ) -> Array[InputEvent]:
	var id:int = ia.get_instance_id()
	if _dup_events.has( id ):
		var row:Dictionary = _dup_events[id]
		var owner:WeakRef = row[&"owner"]
		var held:Array[InputEvent] = row[&"source"]
		if owner.get_ref() == ia and _same_event_objects( ia.events, held ):
			return row[&"events"]
	var stored:Array[InputEvent] = []
	var source:Array[InputEvent] = []
	var evs:Array[InputEvent] = ia.events
	for i:int in evs.size():
		var ev:InputEvent = evs[i]
		if not is_instance_valid( ev ):
			continue
		source.append( ev )
		stored.append( ev.duplicate() as InputEvent )
	_dup_events[id] = {
		&"owner": weakref( ia ),
		&"events": stored,
		&"source": source,
	}
	return stored


## True when [param evs] still holds [param source], skipping empty slots.
func _same_event_objects(
		evs:Array[InputEvent],
		source:Array[InputEvent] ) -> bool:
	var index:int = 0
	for i:int in evs.size():
		var ev:InputEvent = evs[i]
		if not is_instance_valid( ev ):
			continue
		if index >= source.size() or source[index] != ev:
			return false
		index += 1
	return index == source.size()


## Drop copies whose source action has been freed.
static func _sweep_cached_events() -> void:
	var dead:Array[int] = []
	for key:Variant in _dup_events:
		if key is int:
			var id:int = key
			var row:Dictionary = _dup_events[id]
			var owner:WeakRef = row[&"owner"]
			if owner.get_ref() == null:
				dead.append( id )
	for id:int in dead:
		var _drop_events:bool = _dup_events.erase( id )


## Install [param source] by sharing its event objects.
## [br]Each stored name gets a new [InputAction] whose event list points at
## [param source]'s events. The source map and its action objects stay as they
## are, so clearing this map does not clear the baseline.
## [br]When [param overwrite] is [code]false[/code], a name already stored here stays.
func install( source:CustomInputMap, overwrite:bool = true ) -> void:
	assert( is_instance_valid( source ), "CustomInputMap.install: source is invalid" )
	var next:Dictionary[StringName, InputAction] = {}
	for action_name:StringName in _actions:
		next[action_name] = _actions[action_name]
	for action_name:StringName in source._actions:
		if not overwrite and next.has( action_name ):
			continue
		var ia:InputAction = source._actions[action_name]
		if not is_instance_valid( ia ):
			next[action_name] = null
			continue
		next[action_name] = InputAction.new( ia.deadzone, ia.events )
	_actions = next


## Stores one row from [param source_action].
## [br][param share] keeps that action's event objects. A gameplay row stores the
## cached duplicates instead, and those duplicates stay while the source action
## still holds the same event objects.
## [br]An existing row with the same deadzone and the same event objects stays,
## so a later compose does not allocate it again.
## [br]Returns true when the stored row changes. A null [param source_action] stores
## a null placeholder.
func project_action(
		action_name:StringName,
		source_action:InputAction,
		share:bool ) -> bool:
	var deadzone:float = DEFAULT_DEADZONE
	var wanted:Array[InputEvent] = []
	if source_action != null:
		deadzone = source_action.deadzone
		if share:
			wanted = source_action.events
		else:
			wanted = _cached_events( source_action )

	if _actions.has( action_name ):
		var existing:InputAction = _actions[action_name]
		if source_action == null:
			if existing == null:
				return false
		elif existing != null \
				and is_equal_approx( existing.deadzone, deadzone ) \
				and _same_event_objects( existing.events, wanted ):
			return false

	if source_action == null:
		_actions[action_name] = null
		return true
	_actions[action_name] = InputAction.new( deadzone, wanted )
	return true


## Drops [param action_name] without clearing its events.
## A shared row's events still belong to the source map.
func release_action( action_name:StringName ) -> void:
	var _gone:bool = _actions.erase( action_name )


## New map: this map with [param other] folded in (same shape as [method Dictionary.merged]).
func merged( other:CustomInputMap, overwrite:bool = true ) -> CustomInputMap:
	var out:CustomInputMap = duplicate_map()
	out.merge( other, overwrite )
	return out

#endregion Clone / Merge


#region Engine
#MARK: Engine
func                        __Engine_________________              ()->void:pass
# │ ___           _
# │| __|_ _  __ _(_)_ _  ___
# │| _|| ' \/ _` | | ' \/ -_)
# │|___|_||_\__, |_|_||_\___|
# ╰─────────|___/──────────────

## Snapshot the current engine [InputMap] into a new resource.
## Useful when bootstrapping hand-authored `.tres` files from a running session.
## Events are copied, so a later edit of the snapshot leaves the engine alone.
static func from_engine() -> CustomInputMap:
	var new_map:CustomInputMap = CustomInputMap.new()
	for action_name:StringName in InputMap.get_actions():
		var _ia:InputAction = new_map.add_action(
				action_name,
				InputMap.action_get_deadzone( action_name ),
				InputMap.action_get_events( action_name ))
	return new_map


## Read the engine [InputMap] and keep its event objects.
## The startup baseline uses this. [method from_engine] is the copying snapshot.
static func alias_from_engine() -> CustomInputMap:
	var actions:Dictionary[StringName, InputAction] = {}
	for action_name:StringName in InputMap.get_actions():
		var deadzone:float = InputMap.action_get_deadzone( action_name )
		var evs:Array[InputEvent] = InputMap.action_get_events( action_name )
		if evs.is_empty() and is_equal_approx( deadzone, DEFAULT_DEADZONE ):
			actions[action_name] = null
			continue
		actions[action_name] = InputAction.new( deadzone, evs )
	var new_map:CustomInputMap = CustomInputMap.new()
	new_map._actions = actions
	return new_map


## The startup engine map. The first call reads [method alias_from_engine].
## Later calls return that same map, so a rebuild cannot recapture the table it just wrote.
static func engine_baseline() -> CustomInputMap:
	if not is_instance_valid( _engine_baseline ):
		_engine_baseline = alias_from_engine()
	return _engine_baseline


## Push this map into the engine [InputMap] for each action name it contains.
## [br]When [param merge] is [code]false[/code] (default), each name is erased
## then re-added from this map (wholesale replace of that name only; other
## engine actions are left alone).
## [br]When [param merge] is [code]true[/code], existing engine actions are kept:
## deadzone is updated from this map, and events are appended only when not
## already present ([method InputMap.action_has_event]). Null [InputAction]
## placeholders ensure the action exists with [constant DEFAULT_DEADZONE].
func apply_to_engine( do_merge:bool = false ) -> void:
	for action_name:StringName in _actions:
		apply_action( action_name, do_merge )


## Writes one name to the engine [InputMap].
## [br]A name whose deadzone and event objects already match is left in place.
## Missing names are skipped. [param do_merge] appends events instead of replacing the name.
func apply_action( action_name:StringName, do_merge:bool = false ) -> void:
	if not _actions.has( action_name ):
		return
	var ia:InputAction = _actions[action_name]
	if do_merge:
		_merge_action_into_engine( action_name, ia )
		return
	var matches:bool = false
	if InputMap.has_action( action_name ):
		var want_deadzone:float = (
				ia.deadzone if is_instance_valid( ia ) else DEFAULT_DEADZONE )
		if is_equal_approx(
				InputMap.action_get_deadzone( action_name ), want_deadzone ):
			var live:Array[InputEvent] = InputMap.action_get_events( action_name )
			if is_instance_valid( ia ):
				matches = _same_event_objects( ia.events, live )
			else:
				matches = live.is_empty()
	if matches:
		return
	if InputMap.has_action( action_name ):
		InputMap.erase_action( action_name )
	if not is_instance_valid( ia ):
		InputMap.add_action( action_name, DEFAULT_DEADZONE )
		return
	InputMap.add_action( action_name, ia.deadzone )
	var evs:Array[InputEvent] = ia.events
	for i:int in evs.size():
		var ie:InputEvent = evs[i]
		if is_instance_valid( ie ):
			InputMap.action_add_event( action_name, ie )


# Keep existing engine events; update deadzone and append missing events.
func _merge_action_into_engine( action_name:StringName, ia:InputAction ) -> void:
	var deadzone:float = (
			ia.deadzone if is_instance_valid( ia ) else DEFAULT_DEADZONE )
	if not InputMap.has_action( action_name ):
		InputMap.add_action( action_name, deadzone )
	else:
		InputMap.action_set_deadzone( action_name, deadzone )
	if not is_instance_valid( ia ):
		return
	var evs:Array[InputEvent] = ia.events
	for i:int in evs.size():
		var ie:InputEvent = evs[i]
		if not is_instance_valid( ie ):
			continue
		if InputMap.action_has_event( action_name, ie ):
			continue
		InputMap.action_add_event( action_name, ie )

#endregion Engine


#region Project / config
#MARK: Project / config
func                        __Project___config_______              ()->void:pass
#│ ___          _        _       __               __ _
#│| _ \_ _ ___ (_)___ __| |_    / /  __ ___ _ _  / _(_)__ _
#│|  _/ '_/ _ \| / -_) _|  _|  / /  / _/ _ \ ' \|  _| / _` |
#│|_| |_| \___// \___\__|\__| /_/   \__\___/_||_|_| |_\__, |
#╰───────────|__/─────────────────────────────────────|___/───

## Authoring helper: reload [code]project.godot[/code] [input] into the live
## [InputMap], then return a [method from_engine] snapshot.
## [br][b]Side effect:[/b] [method InputMap.load_from_project_settings] clears
## and rebuilds the engine map. Prefer [method from_engine] when you only need
## the current map without reloading the project. Not used as a runtime base
## layer — active maps come from responders.
static func from_project_settings() -> CustomInputMap:
	InputMap.load_from_project_settings()
	return from_engine()


## Save to a ConfigFile at [param path] using project.godot [input] shape:
## each action is one key whose value is
## [code]{ "deadzone": float, "events": Array[InputEvent] }[/code].
## [br][param path] is used as given (extension is the caller's choice).
## [br][color=yellow_green]NOTE[/color]:ConfigFile encoding of InputEvents can
## drop uncommon properties; prefer [code].tres[/code] for lossless authoring.
func save_to_config( path:String ) -> Error:
	assert( not path.is_empty(), "CustomInputMap.save_to_config: empty path" )
	var cfg:ConfigFile = ConfigFile.new()
	for action_name:StringName in _actions:
		cfg.set_value(
				"input",
				String( action_name ),
				_action_to_project_dict( _actions[action_name] ) )
	var err:Error = cfg.save( path )
	if err != OK:
		push_error(
				"CustomInputMap.save_to_config: failed for '%s': %s"
				% [path, error_string( err )] )
	return err


## Load a ConfigFile written by [method save_to_config] (or an [code][input][/code]
## section in the same dictionary shape as project.godot). Returns null on load error.
static func create_from_config( path:String ) -> CustomInputMap:
	assert( not path.is_empty(), "CustomInputMap.create_from_config: empty path" )
	var cfg:ConfigFile = ConfigFile.new()
	var err:Error = cfg.load( path )
	if err != OK:
		push_error(
				"CustomInputMap.create_from_config: failed for '%s': %s"
				% [path, error_string( err )] )
		return null

	var map:CustomInputMap = CustomInputMap.new()
	if not cfg.has_section( "input" ):
		return map

	for key:String in cfg.get_section_keys( "input" ):
		var value:Variant = cfg.get_value( "input", key )
		if not ( value is Dictionary ):
			push_warning(
					"CustomInputMap.create_from_config: skip key '%s' (expected Dictionary, got %s)"
					% [key, type_string( typeof( value ) )] )
			continue
		var action_dict:Dictionary = value
		var deadzone:float = action_dict.get( "deadzone", DEFAULT_DEADZONE )
		var events:Array[InputEvent] = _events_from_project_variant(
				action_dict.get( "events", [] ) )
		var _ia:InputAction = map.add_action( key, deadzone, events )
	return map


## project.godot-shaped dictionary for one action (null → empty defaults).
static func _action_to_project_dict( ia:InputAction ) -> Dictionary:
	var events:Array = []
	var deadzone:float = DEFAULT_DEADZONE
	if is_instance_valid( ia ):
		deadzone = ia.deadzone
		var evs:Array[InputEvent] = ia.events
		for i:int in evs.size():
			var ie:InputEvent = evs[i]
			if is_instance_valid( ie ):
				events.append( ie )
	return {
		"deadzone": deadzone,
		"events": events,
	}


## Coerce ConfigFile / project [code]events[/code] value into typed InputEvents.
static func _events_from_project_variant( raw:Variant ) -> Array[InputEvent]:
	var out:Array[InputEvent] = []
	if not ( raw is Array ):
		return out
	for item:Variant in raw:
		if item is InputEvent:
			var ie:InputEvent = item
			if is_instance_valid( ie ):
				out.append( ie )
	return out

#endregion Project / config


#                 ████████  ██████   ██████  ██      ███████                   #
#                    ██    ██    ██ ██    ██ ██      ██                        #
#                    ██    ██    ██ ██    ██ ██      ███████                   #
#                    ██    ██    ██ ██    ██ ██           ██                   #
#                    ██     ██████   ██████  ███████ ███████                   #
func                        __________TOOLS__________              ()->void:pass

@export_category("Tools")
@export_tool_button('Copy Project+Engine Map')
var export_engine_map:Callable = func() -> void:
	var engine_map:CustomInputMap = from_engine()
	merge( engine_map )
