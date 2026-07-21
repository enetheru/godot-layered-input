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
#[br][color=goldenrod]TODO[/color]:what

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
@export var _actions:Dictionary[StringName, InputMapAction] = {}


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

## True if the action key exists (value may still be null — treated as empty def).
func has_action(action: StringName) -> bool:
	return _actions.has(action)


## True if the action exists and has a non-null [InputMapAction] definition.
func has_action_def(action: StringName) -> bool:
	return _actions.get(action) != null


func get_actions() -> Array[StringName]:
	return _actions.keys()


## Returns deadzone, or [constant DEFAULT_DEADZONE] when missing/null (no warning).
## Null definitions are intentional placeholders — same as a default-constructed def.
func action_get_deadzone(action: StringName) -> float:
	var def: InputMapAction = _actions.get(action)
	if def == null:
		return DEFAULT_DEADZONE
	return def.deadzone


func action_get_events(action: StringName) -> Array[InputEvent]:
	var def: InputMapAction = _actions.get(action)
	if def == null:
		return []
	return def.events


func action_has_event(action: StringName, event: InputEvent) -> bool:
	var def: InputMapAction = _actions.get(action)
	if def == null or event == null:
		return false
	for ev: InputEvent in def.events:
		if ev != null and ev == event:
			return true
		if ev != null and event.is_match(ev, true):
			return true
	return false

#endregion Query


#region Mutate
#MARK: Mutate
func                        __Mutate_________________              ()->void:pass
# │ __  __      _        _
# │|  \/  |_  _| |_ __ _| |_ ___
# │| |\/| | || |  _/ _` |  _/ -_)
# │|_|  |_|\_,_|\__\__,_|\__\___|
# ╰────────────────────────────────

## Ensure a non-null [InputMapAction] exists for [param action] and return it.
## Materializes null placeholders (allowed by the resource model).
func ensure_action(action: StringName, deadzone: float = DEFAULT_DEADZONE) -> InputMapAction:
	var ima: InputMapAction = _actions.get(action)
	if ima != null:
		return ima
	ima = InputMapAction.new()
	ima.deadzone = deadzone
	_actions[action] = ima
	return ima


func add_action(action: StringName, deadzone: float = DEFAULT_DEADZONE) -> void:
	var ima: InputMapAction = _actions.get(action)
	if ima != null:
		push_warning("CustomInputMap: action '%s' already exists (deadzone %s)" % [action, ima.deadzone])
		return
	# Key may exist with null value — materialize instead of no-op.
	ensure_action(action, deadzone)


func erase_action(action: StringName) -> void:
	if not _actions.erase(action):
		push_warning("CustomInputMap: action '%s' not found" % action)


func action_set_deadzone(action: StringName, deadzone: float) -> void:
	var ima: InputMapAction = ensure_action(action, deadzone)
	ima.deadzone = deadzone


func action_add_event(action: StringName, event: InputEvent) -> void:
	if event == null:
		push_error("CustomInputMap.action_add_event: invalid event")
		return
	var ima: InputMapAction = ensure_action(action)
	if action_has_event(action, event):
		return
	ima.events.append(event)


func action_erase_event(action: StringName, event: InputEvent) -> void:
	var ima: InputMapAction = _actions.get(action)
	if ima == null or event == null:
		return
	for i: int in range(ima.events.size() - 1, -1, -1):
		var ev: InputEvent = ima.events[i]
		if ev == null:
			ima.events.remove_at(i)
			continue
		if ev == event or event.is_match(ev, true):
			ima.events.remove_at(i)


func action_clear_events(action: StringName) -> void:
	var def: InputMapAction = _actions.get(action)
	if def == null:
		return
	def.events.clear()

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
	for key:StringName in _actions:
		var ima:InputMapAction = _actions[key]
		dup._actions[key] = null if ima == null else ima.duplicate_action()
	return dup


## Return a new map = [param base] with this layer applied on top.
## Same action names are replaced wholesale (not event-appended).
## If [param base] is null, this layer alone is returned as a deep copy.
func merge_over(base:CustomInputMap) -> CustomInputMap:
	var out := base.duplicate_map() if base != null else CustomInputMap.new()
	for key:StringName in _actions.keys():
		var ima:InputMapAction = _actions[key]
		out._actions[key] = InputMapAction.new() if ima == null else ima.duplicate_action()
	return out


## apply [param top] over this map.
## Same action names are replaced wholesale (not event-appended).
func merge_with(top:CustomInputMap) -> void:
	for key:StringName in top._actions.keys():
		var ima:InputMapAction = top._actions[key]
		_actions[key] = InputMapAction.new() if ima == null else ima.duplicate_action()

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
	var out := CustomInputMap.new()
	for action:StringName in InputMap.get_actions():
		out.add_action(action, InputMap.action_get_deadzone(action))
		for ev:InputEvent in InputMap.action_get_events(action):
			if ev != null:
				out.action_add_event(action, ev.duplicate() as InputEvent)
	return out


## Push this map into the engine singleton (clears all existing _actions first).
func apply_to_engine() -> void:
	for action:StringName in InputMap.get_actions():
		InputMap.erase_action(action)
	for action:StringName in _actions:
		var ima:InputMapAction = _actions[action]
		if ima == null:
			InputMap.add_action(action, DEFAULT_DEADZONE)
			continue
		InputMap.add_action(action, ima.deadzone)
		for ev:InputEvent in ima.events:
			if ev != null:
				InputMap.action_add_event(action, ev)

#endregion Engine


#region Project / config
#MARK: Project / config
func                        __Project___config_______              ()->void:pass
#│ ___          _        _       __               __ _
#│| _ \_ _ ___ (_)___ __| |_    / /  __ ___ _ _  / _(_)__ _
#│|  _/ '_/ _ \| / -_) _|  _|  / /  / _/ _ \ ' \|  _| / _` |
#│|_| |_| \___// \___\__|\__| /_/   \__\___/_||_|_| |_\__, |
#╰───────────|__/─────────────────────────────────────|___/───

## Reload project-settings _actions into the engine, then snapshot.
## Authoring helper only — not used as a runtime base layer.
static func from_project_settings() -> CustomInputMap:
	InputMap.load_from_project_settings()
	return from_engine()


## Saves map to .cfg file in project.godot [input] compatible style.
## Note: Some advanced InputEvent properties may be lossy.
func save_to_config(path:String) -> Error:
	if not path.ends_with(".cfg"):
		path += ".cfg"
	var cfg := ConfigFile.new()
	for action:StringName in get_actions():
		var ima:InputMapAction = _actions[action]
		if ima == null:
			cfg.set_value("input", action, {})
			continue

		cfg.set_value("input", action + "/deadzone", ima.deadzone)

		var event_list := PackedStringArray()
		for ev:InputEvent in ima.events:
			if ev != null:
				# ConfigFile can serialize basic InputEvents; for exact match use to_json or custom
				if not event_list.append(str(ev)):  # simplistic; improve as needed
					push_error('CustomInputMap: failed to append event %s' % str(ev))
		cfg.set_value("input", action + "/events", event_list)
	var err := cfg.save(path)
	if err != OK:
		push_error("CustomInputMap: save_to_config failed: %s" % error_string(err))
	return err


## Loads from .cfg and returns new map (or populates this one).
static func create_from_config(path:String) -> CustomInputMap:
	var cfg := ConfigFile.new()
	var err:Error = cfg.load(path)
	if err != OK:
		push_error("CustomInputMap: load config failed: %s" % path)
		return null
	var map := CustomInputMap.new()
	# Parse [input] section
	var input_section := cfg.get_section_keys("input")
	for key in input_section:
		if key.ends_with("/deadzone"):
			var action:StringName = key.get_slice("/", 0)
			var dz:float = cfg.get_value("input", key, 0.5)
			map.add_action(action, dz)

		if key.ends_with("/events"):
			pass
			# TODO events handling would go here - more complex
	return map

#endregion Project / config


@export_category("Tools")
@export_tool_button('Copy Project+Engine Map')
var export_engine_map:Callable = func() -> void:
	var engine_map := from_engine()
	merge_with(engine_map)
