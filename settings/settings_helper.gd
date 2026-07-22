@tool
extends RefCounted
class_name InputMapEditorSettingsHelper

## Vendored settings helper (from enetheru.flatbuffers / editor-tweaks pattern).
## Walks [member _target] exported properties and mirrors them into
## [ProjectSettings] under [member _prefix].
##
## [codeblock]
## var opts := InputMapEditorSettings.new()
## var mgr := InputMapEditorSettingsHelper.new( opts, "input_map_editor" )
## mgr.settings_changed.connect( _on_settings_changed )
## [/codeblock]


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var _prefix:String = ""
var _target:Object
var _target_file:String = ""
var _script_category_names:PackedStringArray = PackedStringArray()

## Full ProjectSettings path → property name on [member _target].
var setting_prop_map:Dictionary = {}

signal settings_changed( setting_name:StringName, value:Variant )


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_project_settings_changed() -> void:
	update_target.call_deferred()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init( target:Object, prefix:String = "plugin/un-named" ) -> void:
	assert( target != null, "InputMapEditorSettingsHelper: target is null" )
	_prefix = prefix
	_target = target
	var script:Script = _target.get_script() as Script
	assert( script != null, "InputMapEditorSettingsHelper: target has no script" )
	var target_path:String = script.resource_path
	_target_file = target_path.get_file()
	_script_category_names = PackedStringArray()
	_script_category_names.append( _target_file )
	_script_category_names.append( _target_file.get_basename() )
	var global_name:StringName = script.get_global_name()
	if not global_name.is_empty():
		_script_category_names.append( String( global_name ) )
	add_target_properties()
	if not ProjectSettings.settings_changed.is_connected( _on_project_settings_changed ):
		@warning_ignore( "return_value_discarded" )
		ProjectSettings.settings_changed.connect( _on_project_settings_changed )


func _notification( what:int ) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if ProjectSettings.settings_changed.is_connected( _on_project_settings_changed ):
		ProjectSettings.settings_changed.disconnect( _on_project_settings_changed )


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func add_target_properties() -> void:
	var category:String = ""
	var group:String = ""
	var group_prefix:String = ""
	var subgroup:String = ""
	var subgroup_prefix:String = ""
	var is_inside_script:bool = false

	for property:Dictionary in _target.get_property_list():
		var property_name:String = property.name
		var property_type:int = property.type
		var property_hint:int = property.hint
		var hint_string:String = property.hint_string
		var usage:int = property.usage
		var property_value:Variant = _target.get( property_name )

		if usage & PROPERTY_USAGE_CATEGORY:
			if _is_script_category( property_name ):
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

		if usage & PROPERTY_USAGE_GROUP:
			group = property_name
			group_prefix = hint_string
			subgroup = ""
			subgroup_prefix = ""
			continue

		if usage & PROPERTY_USAGE_SUBGROUP:
			subgroup = property_name
			subgroup_prefix = hint_string
			continue

		if not ( usage & PROPERTY_USAGE_STORAGE ):
			continue

		var group_level:int = 0
		var setting_name:String = ""

		if subgroup and not subgroup_prefix.is_empty():
			if property_name.begins_with( subgroup_prefix ):
				setting_name = property_name.trim_prefix( subgroup_prefix )
				group_level = 2
			else:
				subgroup_prefix = ""
		elif not subgroup.is_empty():
			group_level = 2

		if group_level == 0:
			if not group_prefix.is_empty():
				if property_name.begins_with( group_prefix ):
					setting_name = property_name.trim_prefix( group_prefix )
					group_level = 1
				else:
					group_prefix = ""
			elif not group.is_empty():
				group_level = 1

		if group_level == 0:
			setting_name = property_name

		var parts:Array = [_prefix]
		if not category.is_empty():
			parts.append( category )
		if group_level > 0:
			parts.append( group )
			if group_level > 1:
				parts.append( subgroup )

		var setting_path:String = "/".join( parts )
		var setting_full:String = setting_path.path_join( setting_name )

		if property_value \
		and property_type == TYPE_CALLABLE \
		and property_hint & PROPERTY_HINT_TOOL_BUTTON:
			continue

		setting_prop_map[setting_full] = property_name

		var setting_info:Dictionary = {
			&"name": setting_full,
			&"type": property_type,
			&"hint": property_hint,
			&"hint_string": hint_string,
		}

		if ProjectSettings.has_setting( setting_full ):
			var setting_value:Variant = ProjectSettings.get_setting( setting_full )
			ProjectSettings.add_property_info( setting_info )
			if setting_value != property_value:
				_target.set( property_name, setting_value )
		else:
			ProjectSettings.set_setting( setting_full, property_value )
			ProjectSettings.add_property_info( setting_info )


func update_target() -> void:
	if _target == null:
		return
	for setting_name:String in setting_prop_map.keys():
		var new_val:Variant = ProjectSettings.get_setting( setting_name )
		var prop_name:StringName = setting_prop_map[setting_name]
		if new_val == _target.get( prop_name ):
			continue
		_target.set( prop_name, new_val )
		settings_changed.emit( prop_name, new_val )


func _is_script_category( property_name:String ) -> bool:
	for n:String in _script_category_names:
		if property_name == n:
			return true
	return false
