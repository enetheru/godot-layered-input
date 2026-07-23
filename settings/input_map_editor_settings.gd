@tool
class_name InputMapEditorSettings
extends Resource
## Options for the Input Map editor plugin (SettingsHelper target).
##
## ProjectSettings keys use prefix [code]input_map_editor[/code] (property names
## as path segments). Owned by the plugin; features read this resource, not raw
## ProjectSettings paths.
##
## [b]Desired[/b] [member host_mode] is applied at attach/rehost. Live prefs
## ([member auto_raise], [member panel_min_height]) update while enabled.

## Where the Input Map editor UI is hosted while the plugin is enabled.
enum HostMode {
	## Universal [EditorDock] (any slot / floating). Default: bottom.
	DOCK = 0,
	## Main-screen tab next to 2D / 3D / Script.
	MAIN_SCREEN = 1,
	## [EditorInspectorPlugin] for [CustomInputMap].
	INSPECTOR = 2,
}

@export_enum("Dock:0", "Main screen:1", "Inspector:2")
var host_mode:int = HostMode.DOCK

@export
var auto_raise:bool = true

@export_range(0.0, 1.0, 0.01)
var default_deadzone:float = 0.2

@export_range(120.0, 800.0, 1.0)
var panel_min_height:float = 280.0
