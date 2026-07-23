@tool
extends RefCounted

## Applied host for one plugin load (or rehost). Not a ProjectSettings mirror.
##
## [b]Desired[/b] host is read only at attach/rehost entry.
## [b]Detach[/b] uses instance slots only and never re-reads settings.


const SettingsScript = preload( "settings/input_map_editor_settings.gd" )
const InspectorPluginScript = preload( "inspector_plugin.gd" )

const MAIN_SCREEN_NAME:String = "Input Map"


## [member SettingsScript.HostMode] value for this session.
var kind:int = -1
var panel:InputMapEditor = null
var dock:EditorDock = null
var inspector_plugin:EditorInspectorPlugin = null


## True when this session's applied host is main-screen.
func is_main_screen() -> bool:
	return kind == SettingsScript.HostMode.MAIN_SCREEN


## True when this session's applied host is the inspector plugin.
func is_inspector() -> bool:
	return kind == SettingsScript.HostMode.INSPECTOR


## True when this session's applied host is an [EditorDock].
func is_dock() -> bool:
	return kind == SettingsScript.HostMode.DOCK


## Build host for [param desired_kind]. [param panel] is required for dock/main
## and must be null for inspector (inspector plugin creates its own editors).
static func attach(
			plugin:EditorPlugin,
			desired_kind:int,
			panel:InputMapEditor ) -> RefCounted:
	var session:RefCounted = new()
	session.kind = desired_kind
	match desired_kind:
		SettingsScript.HostMode.MAIN_SCREEN:
			assert( panel != null, "HostSession.attach: main screen needs panel" )
			session.panel = panel
			var main_screen:VBoxContainer = (
					EditorInterface.get_editor_main_screen() )
			main_screen.add_child( panel )
			panel.set_anchors_and_offsets_preset( Control.PRESET_FULL_RECT )
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			panel.visible = false
		SettingsScript.HostMode.INSPECTOR:
			assert( panel == null, "HostSession.attach: inspector has no primary panel" )
			session.inspector_plugin = InspectorPluginScript.new()
			if session.inspector_plugin.has_method( &"setup" ):
				session.inspector_plugin.call( &"setup", plugin )
			plugin.add_inspector_plugin( session.inspector_plugin )
		_:
			assert( panel != null, "HostSession.attach: dock needs panel" )
			session.panel = panel
			session.kind = SettingsScript.HostMode.DOCK
			var d:EditorDock = EditorDock.new()
			d.title = MAIN_SCREEN_NAME
			d.layout_key = "enetheru_input_map_editor"
			d.default_slot = EditorDock.DOCK_SLOT_BOTTOM
			d.available_layouts = (
					EditorDock.DOCK_LAYOUT_VERTICAL
					| EditorDock.DOCK_LAYOUT_HORIZONTAL
					| EditorDock.DOCK_LAYOUT_FLOATING
			)
			d.global = true
			d.icon_name = &"InputEventAction"
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			d.add_child( panel )
			plugin.add_dock( d )
			panel.visible = true
			session.dock = d
	return session


## Tear down every owned slot. Idempotent. Never reads ProjectSettings.
func detach( plugin:EditorPlugin ) -> void:
	if inspector_plugin != null:
		if inspector_plugin.has_method( &"cleanup" ):
			inspector_plugin.call( &"cleanup" )
		plugin.remove_inspector_plugin( inspector_plugin )
		inspector_plugin = null
	if is_instance_valid( dock ):
		plugin.remove_dock( dock )
		if is_instance_valid( panel ) and panel.get_parent() == dock:
			dock.remove_child( panel )
		dock.queue_free()
		dock = null
	if is_instance_valid( panel ):
		var parent:Node = panel.get_parent()
		if parent != null:
			parent.remove_child( panel )
		panel.queue_free()
		panel = null
	kind = -1
