@tool

## │ ___      _   _   _                _  _     _                  [br]
## │/ __| ___| |_| |_(_)_ _  __ _ ___ | || |___| |_ __  ___ _ _    [br]
## │\__ \/ -_)  _|  _| | ' \/ _` (_-< | __ / -_) | '_ \/ -_) '_|   [br]
## │|___/\___|\__|\__|_|_||_\__, /__/ |_||_\___|_| .__/\___|_|     [br]
## ╰────────────────────────|___/────────────────|_|────────────── [br]
## Bridge `@export` properties on a target object into [ProjectSettings].
##
## Walks [method Object.get_property_list], maps [code]PROPERTY_USAGE_*[/code]
## groups, and keeps the target in sync when ProjectSettings change.[br]
## Intended for [EditorPlugin] (or similar) + options [Resource].[br]
## [br]
## [b]== Usage ==[/b][br]
## [codeblock]
## func _enter_tree() -> void:
##     settings_mgr = SettingsHelper.new(opts, "plugin/my_plugin_name")
## [/codeblock]
## [br]
## [b]== Examples ==[/b][br]
## [codeblock]
## @export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING)
## var example:bool
## [/codeblock]
## Group / subgroup via [code]PROPERTY_USAGE_GROUP[/code] /
## [code]PROPERTY_USAGE_SUBGROUP[/code] (two layers). Underscores in names
## become path segments when prefixes match.[br]
## [br]
## Not all property hints map 1:1 to Project Settings inspector widgets.[br]
## [br]
## [method ProjectSettings.add_property_info] expects
## [code]name[/code], [code]type[/code], [code]hint[/code],
## [code]hint_string[/code].[br]
## [br]
## 11/11/2025 10:41am ACT+930 - Created[br]
## 09/02/2026 12:58am ACT+930 - Re-added settings_changed; docs[br]
## 24/02/2026 2:45am ACT+930 - Usage-flag notes; tooltip link; removed erase
## on exit (wiped EditorSettings risk); merged editor-tweaks / flatbuffers
## differences (buttons, enabled_plugins)[br]
## 2026-02-27 - ProjectSettings (was EditorSettings)[br]
## 2026-03-08 - settings_changed emits new value, not old[br]
## 2026-06-09 - Docs pass[br]
## 24/07/2026 1:49am ACT+930 - Consolidated editor-tweaks + flatbuffers copies:
## rename handler to ProjectSettings; fuller get_all_plugins_info docs; tool
## buttons use full setting path; enabled flag checks plugin.cfg path; typed
## script path for target; keep local Print preload per host addon[br]
## 24/07/2026 ~2:00am ACT+930 - Vendored into layered-input for Input Map
## editor options; set_initial_value + set_as_basic on register[br]
##
## Tooltip idea (brute force):[br]
## https://github.com/PiCode9560/Godot-Editor-Settings-Description/blob/main/editor_settings_description.gd

# Host logger: sequential LogLevel + HintEnum + bitmask helpers (print_helper).
# FIXME: prefer autoload EneLog once levels are unified.
const Print = preload("uid://hetq57iwhpjm")
const LogLevel = Print.LogLevel


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var _prefix:String
var _target:Object
## Script filename used as a category marker for exported props.
var _target_file:String
## Optional [code]class_name[/code] — Godot may emit either as CATEGORY.
var _target_class:String

## Full ProjectSettings path → target property name (grouping prefixes).
var setting_prop_map:Dictionary = {}

## TODO: per-setting callables when a setting changes.
#var setting_func_map:Dictionary = {}

signal settings_changed( setting_name:StringName, value:Variant )


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_project_settings_changed() -> void:
	Print.plog(LogLevel.TRACE, "_on_project_settings_changed")
	update_target.call_deferred()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init( target:Object, prefix:String = "plugin/un-named" ) -> void:
	_prefix = prefix
	_target = target

	var script_var:Variant = _target.get_script()
	if not script_var is Script:
		push_error("SettingsHelper._init: target needs a Script")
		return
	@warning_ignore("unsafe_cast")
	var target_script:Script = script_var as Script
	_target_file = target_script.resource_path.get_file()
	_target_class = String(target_script.get_global_name())

	add_target_properties()

	@warning_ignore_start("return_value_discarded")
	ProjectSettings.settings_changed.connect(_on_project_settings_changed)
	@warning_ignore_restore("return_value_discarded")


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Register target properties as ProjectSettings under [member _prefix].
func add_target_properties() -> void:
	Print.plog(LogLevel.TRACE, "add_target_properties")

	var category:String
	var group:String
	var group_prefix:String
	var subgroup:String
	var subgroup_prefix:String
	var is_inside_script:bool = false

	# Inspector grouping: unused group/subgroup prefixes reset that level.
	for property:Dictionary in _target.get_property_list():
		var property_name:String = property.name
		Print.plog(LogLevel.TRACE, "\nproperty.name: ", property_name)
		var property_type:int = property.type
		Print.plog(LogLevel.TRACE, "property.type: ", type_string(property_type))
		var property_hint:int = property.hint
		Print.plog(LogLevel.TRACE, "property.hint: ",
			Print.HintEnum.find_key(property_hint))
		var hint_string:String = property.hint_string
		Print.plog(LogLevel.TRACE, "property.hint_string: ", hint_string)

		var usage:int = property.usage
		var usage_bits:PackedByteArray = Print.bitmask_array(usage, 30)
		var usage_flags:PackedStringArray = Print.get_usage_flags(usage_bits)
		Print.plog(LogLevel.TRACE, "property.usage: ", usage_flags)

		var property_value:Variant = _target.get(property_name)
		Print.plog(LogLevel.TRACE, "value: ", property_value)

		if property.usage & PROPERTY_USAGE_CATEGORY:
			if _is_target_category(property_name):
				is_inside_script = true
				category = ""
				continue
			if not is_inside_script:
				continue
			category = property_name
			group = ""
			group_prefix = ""
			subgroup = ""
			subgroup_prefix = ""
			continue

		if not is_inside_script:
			continue

		if property.usage & PROPERTY_USAGE_GROUP:
			group = property_name
			group_prefix = hint_string
			subgroup = ""
			subgroup_prefix = ""
			continue

		if property.usage & PROPERTY_USAGE_SUBGROUP:
			subgroup = property_name
			subgroup_prefix = hint_string
			continue

		if not (usage & PROPERTY_USAGE_STORAGE):
			continue

		var group_level:int = 0
		var trimmed:bool = false
		var setting_name:String

		if subgroup and subgroup_prefix:
			if property_name.begins_with(subgroup_prefix):
				Print.plog(LogLevel.TRACE, "matched subgroup_prefix")
				setting_name = property_name.trim_prefix(subgroup_prefix)
				trimmed = true
				group_level = 2
			else:
				subgroup_prefix = ""
		elif subgroup:
			group_level = 2

		if group_level == 0:
			if group_prefix:
				if property_name.begins_with(group_prefix):
					Print.plog(LogLevel.TRACE, "match group_prefix")
					setting_name = property_name.trim_prefix(group_prefix)
					trimmed = true
					group_level = 1
				else:
					group_prefix = ""
			elif group:
				group_level = 1

		if group_level == 0:
			setting_name = property_name

		var parts:Array = [_prefix]
		if category:
			parts.append(category)
		if group_level > 0:
			parts.append(group)
			if group_level > 1:
				parts.append(subgroup)

		var setting_path:String = "/".join(parts)
		var setting_full:String = setting_path.path_join(setting_name)

		Print.plog(LogLevel.TRACE, "Category: ", category)
		Print.plog(LogLevel.TRACE, "Group: ", [group, group_prefix])
		Print.plog(LogLevel.TRACE, "SubGroup: ", [subgroup, subgroup_prefix])
		Print.plog(LogLevel.TRACE, "group_level: ", group_level)
		Print.plog(LogLevel.TRACE, "Trimmed: ", trimmed)
		Print.plog(LogLevel.TRACE, "Setting Path: ", setting_path)
		Print.plog(LogLevel.TRACE, "Setting Name: ", setting_name)
		Print.plog(LogLevel.TRACE, "Setting_full: ", setting_full)

		if property_value \
		and property_type == TYPE_CALLABLE \
		and property_hint & PROPERTY_HINT_TOOL_BUTTON:
			Print.plog(LogLevel.TRACE, "is button")
			var button_func:Callable = property_value
			# Full path so buttons sit under the same prefix as other settings.
			add_callable_as_button(setting_full, button_func, hint_string)
			continue

		# Map full path → original property name (needed when prefixes trim).
		setting_prop_map[setting_full] = property_name

		var setting_info:Dictionary = {
			&"name": setting_full,
			&"type": property_type,
			&"hint": property_hint,
			&"hint_string": hint_string,
		}

		if ProjectSettings.has_setting(setting_full):
			var setting_value:Variant = ProjectSettings.get_setting(setting_full)
			ProjectSettings.add_property_info(setting_info)
			ProjectSettings.set_initial_value(setting_full, property_value)
			ProjectSettings.set_as_basic(setting_full, true)
			if setting_value == property_value:
				continue
			_target.set(property_name, setting_value)
		else:
			ProjectSettings.set_setting(setting_full, property_value)
			ProjectSettings.add_property_info(setting_info)
			ProjectSettings.set_initial_value(setting_full, property_value)
			ProjectSettings.set_as_basic(setting_full, true)


func _is_target_category( property_name:String ) -> bool:
	if property_name == _target_file:
		return true
	if not _target_class.is_empty() and property_name == _target_class:
		return true
	# Some builds use basename without extension.
	if property_name == _target_file.get_basename():
		return true
	return false


## Pull ProjectSettings values into the target; emit [signal settings_changed].
func update_target() -> void:
	Print.plog(LogLevel.TRACE, "update_target")
	for setting_name:String in setting_prop_map.keys():
		var new_val:Variant = ProjectSettings.get(setting_name)
		var prop_name:StringName = setting_prop_map[setting_name]
		if new_val == _target.get(prop_name):
			continue
		Print.plog(LogLevel.TRACE, "Updating '%s' : %s" % [setting_name, new_val])
		_target.set(prop_name, new_val)
		settings_changed.emit(prop_name, new_val)


func inspect_target() -> void:
	Print.plog(LogLevel.TRACE, "inspect_target")
	EditorInterface.inspect_object(_target)


#                 ███████ ████████  █████  ████████ ██  ██████                 #
#                 ██         ██    ██   ██    ██    ██ ██                      #
#                 ███████    ██    ███████    ██    ██ ██                      #
#                      ██    ██    ██   ██    ██    ██ ██                      #
#                 ███████    ██    ██   ██    ██    ██  ██████                 #
func                        __________STATIC_________              ()->void:pass

## Scan project [code]addons[/code] for [code]plugin.cfg[/code] entries.[br]
## Each dict: [code]path[/code], [code]config[/code], [code]enabled[/code].[br]
##[br][color=yellow_green]NOTE[/color]: Uses engine project-root path form
## ([code]res://addons[/code]) so results match
## [code]editor_plugins/enabled[/code]. Whole-project discovery — not this
## helper's install path.
static func get_all_plugins_info( only_loaded:bool = false ) -> Array[Dictionary]:
	Print.plog(LogLevel.TRACE, "get_all_plugins_info")
	var enabled_plugins:PackedStringArray = ProjectSettings.get_setting(
		"editor_plugins/enabled")
	var plugins_info:Array[Dictionary] = []

	var addons_path:String = "res://addons"
	var dir:DirAccess = DirAccess.open(addons_path)
	if dir == null:
		push_error("SettingsHelper.get_all_plugins_info: cannot open project addons dir")
		return plugins_info

	var err:Error = dir.list_dir_begin()
	if err != OK:
		push_warning(
			"SettingsHelper.get_all_plugins_info: list_dir_begin failed (%s)"
			% error_string(err))
		return plugins_info

	var folder_name:String = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir():
			var plugin_path:String = addons_path.path_join(folder_name)
			var cfg_path:String = plugin_path.path_join("plugin.cfg")

			if only_loaded and cfg_path not in enabled_plugins:
				folder_name = dir.get_next()
				continue

			if FileAccess.file_exists(cfg_path):
				var config:ConfigFile = ConfigFile.new()
				err = config.load(cfg_path)
				if err != OK:
					push_warning("SettingsHelper.get_all_plugins_info: load %s failed (%s)"
						% [cfg_path, error_string(err)])
					folder_name = dir.get_next()
					continue

				var config_props:Dictionary = {}
				var keys:PackedStringArray = config.get_section_keys("plugin")
				for key:String in keys:
					config_props[key] = config.get_value("plugin", key)

				plugins_info.append({
					&"path": plugin_path,
					&"config": config_props,
					&"enabled": cfg_path in enabled_plugins,
				})

		folder_name = dir.get_next()
	dir.list_dir_end()
	return plugins_info


## Register a TOOL_BUTTON callable under [param path].[br]
## FIXME: Callables do not serialise cleanly; once set they are hard to erase.
static func add_callable_as_button(
			path:String,
			callable:Callable,
			label:String = callable.get_method().capitalize() ) -> void:
	Print.plog(LogLevel.TRACE, "add_callable_as_button")
	ProjectSettings.set(path, callable)
	ProjectSettings.add_property_info({
		&"name": path,
		&"type": TYPE_CALLABLE,
		&"hint": PROPERTY_HINT_TOOL_BUTTON,
		&"hint_string": label,
	})


## Clear ProjectSettings under [param prefix] (skips TYPE_CALLABLE).
static func erase_prefix( prefix:String ) -> void:
	Print.plog(LogLevel.TRACE, "erase_prefix")
	for property:Dictionary in ProjectSettings.get_property_list():
		var setting_name:String = property.get(&"name")
		if not setting_name.begins_with(prefix):
			continue
		# Callables: cannot clear usage flags; erasing can error — skip.
		if property.type == TYPE_CALLABLE:
			continue
		ProjectSettings.set_setting(setting_name, null)
