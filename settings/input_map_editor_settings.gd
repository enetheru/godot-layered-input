@tool
class_name InputMapEditorSettings
extends Resource

## Project Settings for the Input Map editor plugin.
##
## [member host_mode] chooses where the editor lives. Changing it requires
## disabling and re-enabling the plugin (a toast/warning is shown).
## Other options (auto-raise, defaults) apply without a reload when possible.


enum HostMode {
	## Bottom panel tab (default). Same slot as Animation / Output.
	BOTTOM_PANEL = 0,
	## Main-screen plugin tab next to 2D / 3D / Script / Game / AssetLib.
	MAIN_SCREEN = 1,
	## [EditorInspectorPlugin]: map editor replaces the property list for
	## [CustomInputMap] (and nested [InputAction] under an open map).
	INSPECTOR = 2,
}


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

@export_group( "Layout" )

## Where the Input Map editor is hosted. Reload the plugin after changing.
@export var host_mode:HostMode = HostMode.BOTTOM_PANEL

## When host is bottom panel or main screen, raise that host when a
## [CustomInputMap] is selected. Ignored in Inspector host mode.
@export var auto_raise:bool = true


@export_group( "Defaults" )

## Suggested default deadzone for new actions (authoring hint; panel / API
## may adopt this later). Matches [constant CustomInputMap.DEFAULT_DEADZONE].
@export_range( 0.0, 1.0, 0.01 ) var default_deadzone:float = 0.2

## Preferred minimum height of the editor panel (bottom / inspector host).
@export_range( 120.0, 800.0, 1.0 ) var panel_min_height:float = 280.0
