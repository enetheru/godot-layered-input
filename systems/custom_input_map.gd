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
## [br]
##[br][color=goldenrod]TODO[/color]:Implement iterators for actions
##[br][color=goldenrod]TODO[/color]:Improve clarity of merge function names.
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
	var ia:InputAction = _actions.get( action_name )
	if is_instance_valid( ia ):
		push_warning("CustomInputMap.add_action:",
			"action '%s' already exists (deadzone %s)" % [action_name, ia.deadzone])
	# Key may exist with null value — materialize instead of no-op.
	ia = ensure_action( action_name, deadzone )
	for ie:InputEvent in events:
		var dup:InputEvent = ie.duplicate()
		ia.add_event( dup )
	return ia


func erase_action( action_name:StringName ) -> void:
	if not _actions.erase( action_name ):
		push_warning("CustomInputMap: action_name '%s' not found" % action_name)


func set_action_deadzone( action_name:StringName, deadzone:float ) -> void:
	var ia:InputAction = ensure_action( action_name, deadzone )
	ia.deadzone = deadzone


func add_action_event(action_name:StringName, event:InputEvent) -> void:
	if not is_instance_valid( event ):
		push_error("CustomInputMap.action_add_event: invalid event")
		return
	var ia:InputAction = ensure_action( action_name )
	ia.add_event( event )


func erase_action_event( action_name:StringName, event:InputEvent ) -> void:
	var ia:InputAction = _actions.get( action_name )
	if is_instance_valid( ia ) \
	and is_instance_valid( action_name ):
		ia.erase_event( event )
		return
	push_warning("CustomInputMap.erase_action_event: empty action_name or invalid event.")


func clear_action_events( action_name:StringName ) -> void:
	var ia:InputAction = _actions.get( action_name )
	if not is_instance_valid( ia ):
		push_warning("CustomInputMap.clear_action_events: empty InputAction")
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
	var dup := CustomInputMap.new()
	dup.resource_name = resource_name
	for action_name:StringName in _actions.keys():
		var ia:InputAction = _actions[action_name]
		dup._actions[action_name] = ia.duplicate_action() if is_instance_valid( ia ) else null
	return dup


## Return a new map = [param base] with this layer applied on top.
## Same action names are replaced wholesale (not event-appended).
## If [param base] is null, this layer alone is returned as a deep copy.
func merge_over( base:CustomInputMap ) -> CustomInputMap:
	var new_map:CustomInputMap = base.duplicate_map() if is_instance_valid( base ) else CustomInputMap.new()
	for action_name:StringName in _actions.keys():
		var ia:InputAction = _actions[action_name]
		new_map._actions[action_name] = ia.duplicate_action() if is_instance_valid( ia ) else InputAction.new()
	return new_map


## apply [param top] over this map.
## Same action names are replaced wholesale (not event-appended).
func merge_with( top:CustomInputMap ) -> void:
	for action_name:StringName in top._actions.keys():
		var ia:InputAction = top._actions[action_name]
		_actions[action_name] = ia.duplicate_action() if is_instance_valid( ia ) else InputAction.new()

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
	for action_name:StringName in _actions:
		if InputMap.has_action( action_name ):
			InputMap.erase_action( action_name )
		var ia:InputAction = _actions[action_name]
		if not is_instance_valid( ia ):
			InputMap.add_action( action_name, DEFAULT_DEADZONE )
			continue
		InputMap.add_action( action_name, ia.deadzone )
		for ie:InputEvent in ia.events:
			# TODO error checking when iterating over events may be mitigated when
			# the iterator is implemented.
			if is_instance_valid( ie ):
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


## Saves map to .cfg file in project.godot [input] compatible style.
##[color=yellow_green]NOTE[/color]:Some advanced InputEvent properties may be lossy.
func save_to_config( path:String ) -> Error:
	#FIXME: dont make decisions for the user.
	if not path.ends_with(".cfg"):
		path += ".cfg"

	#FIXME: Replicate the project config format exactly, each action looks
	# like a dictionary
	var cfg := ConfigFile.new()
	for action_name:StringName in get_action_names():
		var ia:InputAction = _actions[action_name]
		if not is_instance_valid( ia ):
			cfg.set_value( "input", action_name, {} )
			continue

		cfg.set_value( "input", action_name + "/deadzone", ia.deadzone )

		var event_list := PackedStringArray()
		for ie:InputEvent in ia.events:
			if is_instance_valid( ie ):
				# ConfigFile can serialize basic InputEvents; for exact match use to_json or custom
				if not event_list.append(str(ie)):  # simplistic; improve as needed
					push_error('CustomInputMap: failed to append event %s' % str(ie))
		cfg.set_value( "input", action_name + "/events", event_list )
	# TODO more robust error checking and user reporting.
	var err := cfg.save( path )
	if err != OK:
		push_error("CustomInputMap: save_to_config failed: %s" % error_string(err))
	return err


## Loads from .cfg and returns new map (or populates this one).
static func create_from_config( path:String ) -> CustomInputMap:
	var cfg := ConfigFile.new()
	var err:Error = cfg.load( path )
	if err != OK:
		push_error("CustomInputMap: load config failed: '%s' with:" % path, error_string(err))
		return null
	var map := CustomInputMap.new()
	# Parse [input] section
	var section_keys:PackedStringArray = cfg.get_section_keys( "input" )
	for key:String in section_keys:
		# FIXME, this parsing section is broken, surely there are builtin tools
		# to better parse the structures. Either way, the saving will change
		# so much this to match.
		var action_name:StringName = key.get_slice( "/", 0 )
		var im:InputAction = map.add_action(action_name)
		if key.ends_with( "/deadzone" ):
			im.deadzone = cfg.get_value( "input", key, 0.5 )
		elif key.ends_with( "/events" ):
			pass
			# TODO events handling would go here - more complex
		# TODO, what if the format is a dictionary like the project file?
	return map

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
	var engine_map := from_engine()
	merge_with( engine_map )
