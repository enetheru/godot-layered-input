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
## Layers are owned by [Responder] nodes. [InputManager] walks the active
## responder tree, merges layers, and applies the result to the engine
## [InputMap] singleton.
## [br][br]
## There is no implicit project-settings base map — only maps contributed by
## active responders. Create `.tres` assets by hand and assign them on responders.
## [br]Iterable: [code]for action_name in map:[/code] yields [StringName] keys
## (same order as [method get_action_names]; keys snapshotted at loop start).
## [br]
##[br][color=goldenrod]TODO[/color]:add a merge flag to apply_to_engine to
## merge InputAction Input Events


## Default deadzone
const DEFAULT_DEADZONE:float = 0.2

## Larger deadzone for toggle-style _actions (engine default for many `ui_*`).
const DEFAULT_TOGGLE_DEADZONE:float = 0.5

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Maps Action names [StringName] to thier [InputActionMap] definitions
## [br] definition is allowed to be null and is treated equivalently to
## a default constructed [InputActionMap]
@export var _actions:Dictionary[StringName, InputAction] = {}


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## [code]for action_name in map:[/code] — action name keys; state in [param iter].
func _iter_init( iter:Array ) -> bool:
	# Snapshot keys so nested loops / mid-loop mutation do not share one cursor.
	var keys:Array = _actions.keys()
	iter[0] = { &"i": 0, &"keys": keys }
	return not keys.is_empty()


func _iter_next( iter:Array ) -> bool:
	var st:Dictionary = iter[0]
	var i:int = st[&"i"] + 1
	st[&"i"] = i
	var keys:Array = st[&"keys"]
	return i < keys.size()


func _iter_get( iter:Variant ) -> Variant:
	var st:Dictionary = iter
	var keys:Array = st[&"keys"]
	return keys[ st[&"i"] ]


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
	return is_instance_valid( _actions.get( action_name ) )


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
	return ia.deadzone if is_instance_valid( ia ) else DEFAULT_DEADZONE


func get_action_events( action_name:StringName ) -> Array[InputEvent]:
	var ia:InputAction = _actions.get( action_name )
	return ia.events if is_instance_valid( ia ) else []

#endregion Query


#region Mutate
#MARK: Mutate
func                        __Mutate_________________              ()->void:pass
# │ __  __      _        _
# │|  \/  |_  _| |_ __ _| |_ ___
# │| |\/| | || |  _/ _` |  _/ -_)
# │|_|  |_|\_,_|\__\__,_|\__\___|
# ╰────────────────────────────────

## Ensure a non-null [InputAction] exists for [param action_name] and return it.
## Materializes null placeholders (allowed by the resource model).
func ensure_action(
			action_name:StringName,
			deadzone:float = DEFAULT_DEADZONE ) -> InputAction:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.ensure_action: empty action_name" )
	var ia:InputAction = _actions.get( action_name )
	if is_instance_valid( ia ):
		return ia
	ia = InputAction.new( deadzone )
	_actions[action_name] = ia
	return ia


func add_action(
			action_name:StringName,
			deadzone:float = DEFAULT_DEADZONE,
			events:Array[InputEvent] = [] ) -> InputAction:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.add_action: empty action_name" )
	var ia:InputAction = _actions.get( action_name )
	if is_instance_valid( ia ):
		push_warning( "CustomInputMap.add_action:",
				"action '%s' already exists (deadzone %s)" % [action_name, ia.deadzone] )
	# Key may exist with null value — materialize instead of no-op.
	ia = ensure_action( action_name, deadzone )
	for ie:InputEvent in events:
		var dup:InputEvent = ie.duplicate()
		ia.add_event( dup )
	return ia


func erase_action( action_name:StringName ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.erase_action: empty action_name" )
	if not _actions.erase( action_name ):
		push_warning( "CustomInputMap.erase_action: action '%s' not found" % action_name )


func set_action_deadzone( action_name:StringName, deadzone:float ) -> void:
	# ensure_action asserts non-empty name.
	var ia:InputAction = ensure_action( action_name, deadzone )
	ia.deadzone = deadzone


func add_action_event( action_name:StringName, event:InputEvent ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.add_action_event: empty action_name" )
	assert( is_instance_valid( event ),
			"CustomInputMap.add_action_event: invalid event" )
	var ia:InputAction = ensure_action( action_name )
	ia.add_event( event )


func erase_action_event( action_name:StringName, event:InputEvent ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.erase_action_event: empty action_name" )
	assert( is_instance_valid( event ),
			"CustomInputMap.erase_action_event: invalid event" )
	var ia:InputAction = _actions.get( action_name )
	if not is_instance_valid( ia ):
		push_warning(
				"CustomInputMap.erase_action_event: no InputAction for '%s'"
				% action_name )
		return
	ia.erase_event( event )


func clear_action_events( action_name:StringName ) -> void:
	assert( not String( action_name ).is_empty(),
			"CustomInputMap.clear_action_events: empty action_name" )
	var ia:InputAction = _actions.get( action_name )
	if not is_instance_valid( ia ):
		push_warning(
				"CustomInputMap.clear_action_events: no InputAction for '%s'"
				% action_name )
		return
	ia.clear_events()

#endregion Mutate


#region Clone / Merge
#MARK: Clone / Merge
func                        __Clone___Merge__________              ()->void:pass
# │  ___ _                  __  __  __
# │ / __| |___ _ _  ___    / / |  \/  |___ _ _ __ _ ___
# │| (__| / _ \ ' \/ -_)  / /  | |\/| / -_) '_/ _` / -_)
# │ \___|_\___/_||_\___| /_/   |_|  |_\___|_| \__, \___|
# ╰───────────────────────────────────────────|___/───────

## Deep copy suitable for merge intermediates and mementos.
func duplicate_map() -> CustomInputMap:
	var dup:CustomInputMap = CustomInputMap.new()
	dup.resource_name = resource_name
	for action_name:StringName in self:
		var ia:InputAction = _actions[action_name]
		dup._actions[action_name] = (
				ia.duplicate_action() if is_instance_valid( ia ) else null )
	return dup


## Fold [param other] into this map in place (same shape as [method Dictionary.merge]).
## [br]Same action names are replaced wholesale (not event-appended).
## When [param overwrite] is [code]true[/code] (default), [param other] wins on
## clash — later input layers override earlier ones. When [code]false[/code],
## existing names are kept (Dictionary default; less common for layer stacks).
func merge( other:CustomInputMap, overwrite:bool = true ) -> void:
	assert( is_instance_valid( other ), "CustomInputMap.merge: other is invalid" )
	for action_name:StringName in other:
		if not overwrite and _actions.has( action_name ):
			continue
		var ia:InputAction = other._actions[action_name]
		_actions[action_name] = (
				ia.duplicate_action() if is_instance_valid( ia ) else InputAction.new() )


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
static func from_engine() -> CustomInputMap:
	var new_map := CustomInputMap.new()
	for action_name:StringName in InputMap.get_actions():
		var _ia:InputAction = new_map.add_action(
				action_name,
				InputMap.action_get_deadzone( action_name ),
				InputMap.action_get_events( action_name ))
	return new_map


## Push this map into the engine singleton, overriding wholesale any existing
## actions
func apply_to_engine() -> void:
	for action_name:StringName in self:
		if InputMap.has_action( action_name ):
			InputMap.erase_action( action_name )
		var ia:InputAction = _actions[action_name]
		if not is_instance_valid( ia ):
			InputMap.add_action( action_name, DEFAULT_DEADZONE )
			continue
		InputMap.add_action( action_name, ia.deadzone )
		# InputAction iterator skips null event slots.
		for ie:InputEvent in ia:
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

## Reload project-settings actions into the engine, then snapshot.
##[br]Authoring helper only — not used as a runtime base layer.
##[br][br]
##[color=goldenrod]TODO[/color]:Evaluate the need for this.
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
	for action_name:StringName in self:
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
		for ie:InputEvent in ia:
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
