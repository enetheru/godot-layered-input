@tool
class_name InputMapEditorSettings
extends RefCounted

## Project Settings for the Input Map editor plugin.
##
## Registers flat keys under [code]input_map_editor/[/code] (no group-prefix
## path bugs). Values persist in [code]project.godot[/code] via
## [method ProjectSettings.set_initial_value] + [method ProjectSettings.save].
##
## [member host_mode] is read at plugin enable only. Changing it while the
## plugin is loaded updates ProjectSettings and warns; teardown still uses the
## host latched at attach. Disable/re-enable to apply a new host.


const PREFIX:String = "input_map_editor"

const KEY_HOST_MODE:String = "input_map_editor/host_mode"
const KEY_AUTO_RAISE:String = "input_map_editor/auto_raise"
const KEY_DEFAULT_DEADZONE:String = "input_map_editor/default_deadzone"
const KEY_PANEL_MIN_HEIGHT:String = "input_map_editor/panel_min_height"

## Legacy broken key written by the old SettingsHelper + @export_group path.
const LEGACY_BROKEN_LAYOUT_KEY:String = "input_map_editor/Layout/"


enum HostMode {
	## Universal [EditorDock] (move to any slot, float). Default slot: bottom.
	DOCK = 0,
	## Main-screen plugin tab next to 2D / 3D / Script.
	MAIN_SCREEN = 1,
	## [EditorInspectorPlugin] for [CustomInputMap].
	INSPECTOR = 2,
}


signal settings_changed( setting_name:StringName, value:Variant )


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var host_mode:HostMode = HostMode.DOCK
var auto_raise:bool = true
var default_deadzone:float = 0.2
var panel_min_height:float = 280.0

var _on_settings_changed_cb:Callable = Callable()
var _shut_down:bool = false
## After init settles; avoids treating register/load noise as a user change.
var _emit_live:bool = false


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init() -> void:
	_emit_live = false
	_purge_broken_layout_key()
	_register_all()
	_purge_legacy_bool_keys()
	_load_from_project()
	_on_settings_changed_cb = Callable( self, &"_on_project_settings_changed" )
	if not ProjectSettings.settings_changed.is_connected( _on_settings_changed_cb ):
		@warning_ignore( "return_value_discarded" )
		ProjectSettings.settings_changed.connect( _on_settings_changed_cb )
	_enable_live_emits.call_deferred()


## Audit only — cleanup is [method shutdown] (RefCounted PREDELETE is unreliable).
func _notification( what:int ) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if not _shut_down:
		push_warning(
				"InputMapEditorSettings: freed without shutdown()" )


## Call from the plugin before dropping the last ref. Idempotent.
func shutdown() -> void:
	if _shut_down:
		return
	_emit_live = false
	if _on_settings_changed_cb.is_valid() \
	and ProjectSettings.settings_changed.is_connected( _on_settings_changed_cb ):
		ProjectSettings.settings_changed.disconnect( _on_settings_changed_cb )
	_on_settings_changed_cb = Callable()
	_shut_down = true


func _enable_live_emits() -> void:
	if _shut_down:
		return
	_load_from_project()
	_emit_live = true


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_project_settings_changed() -> void:
	if _shut_down or not _emit_live:
		return
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
	return HostMode.DOCK


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
	if _shut_down:
		return
	var prev_mode:HostMode = host_mode
	var prev_raise:bool = auto_raise
	var prev_dz:float = default_deadzone
	var prev_h:float = panel_min_height
	_load_from_project()
	if not _emit_live:
		return
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
	return HostMode.DOCK


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
