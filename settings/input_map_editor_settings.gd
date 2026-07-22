@tool
class_name InputMapEditorSettings
extends Resource

## Project Settings for the Input Map editor plugin (via [InputMapEditorSettingsHelper]).
##
## [br][b]use_main_screen[/b] and [b]replace_inspector[/b] are mutually exclusive.
## Changing host mode requires disabling and re-enabling the plugin.
## [br][b]auto_raise[/b] applies immediately when the selection changes.


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Host the editor as a main-screen tab (next to 2D / 3D / Script).
## Mutually exclusive with [member replace_inspector]. Default off.
## Reload the plugin after changing this.
@export var use_main_screen:bool = false:
	set( value ):
		if use_main_screen == value:
			return
		use_main_screen = value
		if value and replace_inspector:
			replace_inspector = false


## When a [CustomInputMap] is selected, show this editor via an
## [EditorInspectorPlugin] instead of the default property list.
## Mutually exclusive with [member use_main_screen]. Default off.
## Reload the plugin after changing this.
@export var replace_inspector:bool = false:
	set( value ):
		if replace_inspector == value:
			return
		replace_inspector = value
		if value and use_main_screen:
			use_main_screen = false


## When not using [member replace_inspector], raise the bottom panel or main
## screen when a [CustomInputMap] is selected / edited. Default on (previous
## bottom-panel behaviour).
@export var auto_raise:bool = true
