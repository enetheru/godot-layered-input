@tool
class_name InputMapEditorSettings
extends RefCounted

## Project Settings for the Input Map editor plugin.
##
## Registers flat keys under [code]input_map_editor/[/code] (no group-prefix
## path bugs). Values persist in [code]project.godot[/code] via
## [method ProjectSettings.set_initial_value] + [method ProjectSettings.save].
##
## [member host_mode] requires disabling and re-enabling the plugin to apply.


const PREFIX:String = "input_map_editor"

const KEY_HOST_MODE:String = "input_map_editor/host_mode"
const KEY_AUTO_RAISE:String = "input_map_editor/auto_raise"
const KEY_DEFAULT_DEADZONE:String = "input_map_editor/default_deadzone"
const KEY_PANEL_MIN_HEIGHT:String = "input_map_editor/panel_min_height"

## Legacy broken key written by the old SettingsHelper + @export_group path.
const LEGACY_BROKEN_LAYOUT_KEY:String = "input_map_editor/Layout/"


enum HostMode {
	BOTTOM_PANEL = 0,
	MAIN_SCREEN = 1,
	INSPECTOR = 2,
}


signal settings_changed( setting_name:StringName, value:Variant )


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var host_mode:HostMode = HostMode.BOTTOM_PANEL
var auto_raise:bool = true
var default_deadzone:float = 0.2
var panel_min_height:float = 280.0


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init() -> void:
	_purge_broken_layout_key()
	_register_all()
	_purge_legacy_bool_keys()
	_load_from_project()
	if not ProjectSettings.settings_changed.is_connected( _on_project_settings_changed ):
		@warning_ignore( "return_value_discarded" )
		ProjectSettings.settings_changed.connect( _on_project_settings_changed )


func _notification( what:int ) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if ProjectSettings.settings_changed.is_connected( _on_project_settings_changed ):
		ProjectSettings.settings_changed.disconnect( _on_project_settings_changed )
	# Do NOT erase ProjectSettings — they must survive plugin disable.


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_project_settings_changed() -> void:
	_sync_from_project.call_deferred()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Host mode from ProjectSettings (safe before any plugin instance exists).
static func read_host_mode() -> int:
	if ProjectSettings.has_setting( KEY_HOST_MODE ):
		return int( ProjectSettings.get_setting( KEY_HOST_MODE ) )
	# Legacy two-bool keys.
	if ProjectSettings.get_setting( "input_map_editor/use_main_screen", false ):
		return HostMode.MAIN_SCREEN
	if ProjectSettings.get_setting( "input_map_editor/replace_inspector", false ):
		return HostMode.INSPECTOR
	return HostMode.BOTTOM_PANEL


static func read_auto_raise() -> bool:
	if ProjectSettings.has_setting( KEY_AUTO_RAISE ):
		return bool( ProjectSettings.get_setting( KEY_AUTO_RAISE ) )
	return true


static func read_panel_min_height() -> float:
	if ProjectSettings.has_setting( KEY_PANEL_MIN_HEIGHT ):
		return float( ProjectSettings.get_setting( KEY_PANEL_MIN_HEIGHT ) )
	return 280.0


static func read_default_deadzone() -> float:
	if ProjectSettings.has_setting( KEY_DEFAULT_DEADZONE ):
		return float( ProjectSettings.get_setting( KEY_DEFAULT_DEADZONE ) )
	return 0.2


func _register_all() -> void:
	# First-time default for host_mode may come from legacy bools.
	var default_mode:int = HostMode.BOTTOM_PANEL
	if not ProjectSettings.has_setting( KEY_HOST_MODE ):
		default_mode = _legacy_bools_to_host_mode()
	_register_setting(
			KEY_HOST_MODE,
			default_mode,
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Bottom panel,Main screen,Inspector" )
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


func _register_setting(
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
	# Show under Project Settings → General (not only Advanced).
	ProjectSettings.set_as_basic( key, true )


func _load_from_project() -> void:
	host_mode = read_host_mode() as HostMode
	auto_raise = read_auto_raise()
	default_deadzone = read_default_deadzone()
	panel_min_height = read_panel_min_height()


func _sync_from_project() -> void:
	var prev_mode:HostMode = host_mode
	var prev_raise:bool = auto_raise
	var prev_dz:float = default_deadzone
	var prev_h:float = panel_min_height
	_load_from_project()
	if host_mode != prev_mode:
		settings_changed.emit( &"host_mode", host_mode )
	if auto_raise != prev_raise:
		settings_changed.emit( &"auto_raise", auto_raise )
	if not is_equal_approx( default_deadzone, prev_dz ):
		settings_changed.emit( &"default_deadzone", default_deadzone )
	if not is_equal_approx( panel_min_height, prev_h ):
		settings_changed.emit( &"panel_min_height", panel_min_height )


func _legacy_bools_to_host_mode() -> int:
	if ProjectSettings.get_setting( "input_map_editor/use_main_screen", false ):
		return HostMode.MAIN_SCREEN
	if ProjectSettings.get_setting( "input_map_editor/replace_inspector", false ):
		return HostMode.INSPECTOR
	return HostMode.BOTTOM_PANEL


## Drop mis-named key [code]input_map_editor/Layout/[/code] (old helper bug).
func _purge_broken_layout_key() -> void:
	if ProjectSettings.has_setting( LEGACY_BROKEN_LAYOUT_KEY ):
		ProjectSettings.set_setting( LEGACY_BROKEN_LAYOUT_KEY, null )


## Remove superseded bool toggles after [member KEY_HOST_MODE] exists.
func _purge_legacy_bool_keys() -> void:
	if not ProjectSettings.has_setting( KEY_HOST_MODE ):
		return
	if ProjectSettings.has_setting( "input_map_editor/use_main_screen" ):
		ProjectSettings.set_setting( "input_map_editor/use_main_screen", null )
	if ProjectSettings.has_setting( "input_map_editor/replace_inspector" ):
		ProjectSettings.set_setting( "input_map_editor/replace_inspector", null )
