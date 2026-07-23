@tool
class_name InputMapEditorSettings
extends Object

## Project Settings keys for the Input Map editor plugin (static API).
##
## [b]Desired[/b] [member host_mode] is read at attach/rehost only. The plugin
## owns [code]ProjectSettings.settings_changed[/code] and applies live prefs
## ([member auto_raise], [member panel_min_height]); host changes call rehost.
## No RefCounted instance / PREDELETE teardown.


## ProjectSettings key prefix for this plugin.
const PREFIX:String = "input_map_editor"

## ProjectSettings path for desired host mode ([enum HostMode]).
const KEY_HOST_MODE:String = "input_map_editor/host_mode"
## ProjectSettings path for auto-raise when editing a map.
const KEY_AUTO_RAISE:String = "input_map_editor/auto_raise"
## ProjectSettings path for the panel default action deadzone.
const KEY_DEFAULT_DEADZONE:String = "input_map_editor/default_deadzone"
## ProjectSettings path for inspector-embed minimum height.
const KEY_PANEL_MIN_HEIGHT:String = "input_map_editor/panel_min_height"

## Legacy broken key written by the old SettingsHelper + @export_group path.
const LEGACY_BROKEN_LAYOUT_KEY:String = "input_map_editor/Layout/"


## Where the Input Map editor UI is hosted while the plugin is enabled.
enum HostMode {
	## Universal [EditorDock] (move to any slot, float). Default slot: bottom.
	DOCK = 0,
	## Main-screen plugin tab next to 2D / 3D / Script.
	MAIN_SCREEN = 1,
	## [EditorInspectorPlugin] for [CustomInputMap].
	INSPECTOR = 2,
}


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Register keys and purge legacy names. Safe to call on every plugin enable.
static func register_project_settings() -> void:
	_purge_broken_layout_key()
	var default_mode:int = HostMode.DOCK
	if not ProjectSettings.has_setting( KEY_HOST_MODE ):
		default_mode = _legacy_bools_to_host_mode()
	_register_setting(
			KEY_HOST_MODE,
			default_mode,
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Dock,Main screen,Inspector" )
	_register_setting(
			KEY_AUTO_RAISE,
			true,
			TYPE_BOOL,
			PROPERTY_HINT_NONE,
			"" )
	_register_setting(
			KEY_DEFAULT_DEADZONE,
			0.2,
			TYPE_FLOAT,
			PROPERTY_HINT_RANGE,
			"0,1,0.01" )
	_register_setting(
			KEY_PANEL_MIN_HEIGHT,
			280.0,
			TYPE_FLOAT,
			PROPERTY_HINT_RANGE,
			"120,800,1" )
	_purge_legacy_bool_keys()


## Desired host from ProjectSettings (safe before any plugin session exists).
static func read_host_mode() -> int:
	if ProjectSettings.has_setting( KEY_HOST_MODE ):
		var mode:int = ProjectSettings.get_setting( KEY_HOST_MODE )
		return mode
	if ProjectSettings.get_setting( "input_map_editor/use_main_screen", false ):
		return HostMode.MAIN_SCREEN
	if ProjectSettings.get_setting( "input_map_editor/replace_inspector", false ):
		return HostMode.INSPECTOR
	return HostMode.DOCK


## [code]auto_raise[/code] from ProjectSettings (default [code]true[/code]).
static func read_auto_raise() -> bool:
	if ProjectSettings.has_setting( KEY_AUTO_RAISE ):
		var raise:bool = ProjectSettings.get_setting( KEY_AUTO_RAISE )
		return raise
	return true


## [code]panel_min_height[/code] from ProjectSettings (default [code]280[/code]).
static func read_panel_min_height() -> float:
	if ProjectSettings.has_setting( KEY_PANEL_MIN_HEIGHT ):
		var h:float = ProjectSettings.get_setting( KEY_PANEL_MIN_HEIGHT )
		return h
	return 280.0


## [code]default_deadzone[/code] from ProjectSettings (default [code]0.2[/code]).
static func read_default_deadzone() -> float:
	if ProjectSettings.has_setting( KEY_DEFAULT_DEADZONE ):
		var dz:float = ProjectSettings.get_setting( KEY_DEFAULT_DEADZONE )
		return dz
	return 0.2


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

static func _register_setting(
			key:String,
			default:Variant,
			type:int,
			hint:int,
			hint_string:String ) -> void:
	if not ProjectSettings.has_setting( key ):
		ProjectSettings.set_setting( key, default )
	ProjectSettings.set_initial_value( key, default )
	ProjectSettings.add_property_info({
		&"name": key,
		&"type": type,
		&"hint": hint,
		&"hint_string": hint_string,
	})
	ProjectSettings.set_as_basic( key, true )


static func _legacy_bools_to_host_mode() -> int:
	if ProjectSettings.get_setting( "input_map_editor/use_main_screen", false ):
		return HostMode.MAIN_SCREEN
	if ProjectSettings.get_setting( "input_map_editor/replace_inspector", false ):
		return HostMode.INSPECTOR
	return HostMode.DOCK


static func _purge_broken_layout_key() -> void:
	if ProjectSettings.has_setting( LEGACY_BROKEN_LAYOUT_KEY ):
		ProjectSettings.set_setting( LEGACY_BROKEN_LAYOUT_KEY, null )


static func _purge_legacy_bool_keys() -> void:
	if not ProjectSettings.has_setting( KEY_HOST_MODE ):
		return
	if ProjectSettings.has_setting( "input_map_editor/use_main_screen" ):
		ProjectSettings.set_setting( "input_map_editor/use_main_screen", null )
	if ProjectSettings.has_setting( "input_map_editor/replace_inspector" ):
		ProjectSettings.set_setting( "input_map_editor/replace_inspector", null )
