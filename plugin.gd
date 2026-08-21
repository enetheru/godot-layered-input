@tool
extends EditorPlugin

## Editor plugin for [CustomInputMap] resources.
##
## [b]Host mode[/b] ([code]input_map_editor/host_mode[/code] in Project Settings):
## [br] • [b]Dock[/b] — [EditorDock] via [method add_dock] (any slot + floating)
## [br] • [b]Main screen[/b] — tab next to 2D/3D/Script
## [br] • [b]Inspector[/b] — [EditorInspectorPlugin] for [CustomInputMap]
## [br]
## [b]Desired[/b] host is ProjectSettings. [b]Applied[/b] host is [code]_session[/code],
## set only in attach/rehost. Detach never re-reads settings. Changing host mode
## while enabled runs in-process rehost (no [code]set_plugin_enabled[/code]).


const EditorScene = preload( "ui/input_map_editor.tscn" )
const SettingsScript = preload( "settings/input_map_editor_settings.gd" )
const SettingsHelperScript = preload( "settings/settings.gd" )
## Preload so attach still resolves if class_name is mid-reload.
const HostSessionScript = preload( "host_session.gd" )

const MAIN_SCREEN_NAME:String = "Input Map"
## ProjectSettings prefix (must match existing keys: input_map_editor/*).
const SETTINGS_PREFIX:String = "input_map_editor"


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Applied host; null when detached. See [HostSession].
var _session:HostSession
## Bumped at detach start; deferred work captures and checks this.
var _session_id:int = 0
var _shutting_down:bool = false
var _rehosting:bool = false
## Ignore settings noise until attach + helper settle.
var _settings_live:bool = false

var _inspector_editor:InputMapEditor
var _auto_raise:bool = true
var _panel_min_height:float = 280.0

## Options resource + SettingsHelper (not raw ProjectSettings in features).
var opts:InputMapEditorSettings
var settings_hlp:Object

var _suppress_edited_object_signal:bool = false
var _dirty_maps:Array[CustomInputMap] = []
var _export_plugin:EditorExportPlugin


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_edited_object_changed() -> void:
	if _shutting_down or _suppress_edited_object_signal:
		return
	var obj:Object = EditorInterface.get_inspector().get_edited_object()
	if obj is CustomInputMap:
		_edit_map( obj as CustomInputMap )
		return
	if obj is InputAction and _open_maps_contain_action( obj as InputAction ):
		return
	if not _is_host_inspector():
		_clear_edited_map()


func _on_inspector_property_edited( _property:String ) -> void:
	if _shutting_down:
		return
	var editor:InputMapEditor = _active_editor()
	if editor == null:
		return
	var obj:Object = EditorInterface.get_inspector().get_edited_object()
	if obj is CustomInputMap:
		_refresh_editor_for_map( editor, obj as CustomInputMap )
		return
	if obj is InputAction:
		_refresh_editor_if_action( editor, obj as InputAction )


func _on_resource_modified( map:CustomInputMap ) -> void:
	if _shutting_down or map == null:
		return
	_mark_map_needs_save( map )
	_suppress_edited_object_signal = true
	var id:int = _session_id
	_clear_suppress_deferred( id )


## SettingsHelper: [param prop_name] is the options resource member name.
## [param _value] is already written onto [member opts] before this fires.
func _on_settings_changed( prop_name:StringName, _value:Variant ) -> void:
	if _shutting_down or not _settings_live or _rehosting:
		return
	_apply_settings_change.call_deferred( _session_id, prop_name )


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## Register settings helper, export plugin, attach host, wire inspector.
func _enter_tree() -> void:
	_shutting_down = false
	_settings_live = false
	_setup_settings_helper()
	_auto_raise = opts.auto_raise
	_panel_min_height = opts.panel_min_height

	_export_plugin = preload( "export_plugin.gd" ).new()
	add_export_plugin( _export_plugin )

	_attach_session( opts.host_mode )

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if not inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
		_connect_sig( inspector.edited_object_changed, _on_edited_object_changed )
	if not inspector.property_edited.is_connected( _on_inspector_property_edited ):
		_connect_sig( inspector.property_edited, _on_inspector_property_edited )

	_on_edited_object_changed()
	_enable_settings_live.call_deferred( _session_id )


## Detach host, remove export plugin, disconnect inspector / settings signals.
func _exit_tree() -> void:
	_shutting_down = true
	_settings_live = false
	_session_id += 1

	_detach_session()

	if _export_plugin:
		remove_export_plugin( _export_plugin )
		_export_plugin = null

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if inspector:
		if inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
			inspector.edited_object_changed.disconnect( _on_edited_object_changed )
		if inspector.property_edited.is_connected( _on_inspector_property_edited ):
			inspector.property_edited.disconnect( _on_inspector_property_edited )

	if settings_hlp != null \
	and settings_hlp.is_connected( &"settings_changed", _on_settings_changed ):
		settings_hlp.disconnect( &"settings_changed", _on_settings_changed )
	settings_hlp = null
	opts = null

	_inspector_editor = null
	_dirty_maps.clear()
	# Intentionally leave ProjectSettings keys intact.


## Before [method _enter_tree] uses desired; while live uses applied session.
func _has_main_screen() -> bool:
	if _session != null:
		return _session.is_main_screen()
	if opts != null:
		return opts.host_mode == SettingsScript.HostMode.MAIN_SCREEN
	return false


## Main-screen tab title ([constant MAIN_SCREEN_NAME]).
func _get_plugin_name() -> String:
	return MAIN_SCREEN_NAME


## Editor icon for the main-screen / plugin list entry.
func _get_plugin_icon() -> Texture2D:
	var theme:Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon( &"InputEventAction", &"EditorIcons" ):
		return theme.get_icon( &"InputEventAction", &"EditorIcons" )
	if theme != null and theme.has_icon( &"Node", &"EditorIcons" ):
		return theme.get_icon( &"Node", &"EditorIcons" )
	return null


## Show or hide the main-screen panel when that host is applied.
func _make_visible( visible:bool ) -> void:
	if _shutting_down or not _is_host_main_screen():
		return
	var panel:InputMapEditor = _session_panel()
	if not is_instance_valid( panel ):
		return
	panel.visible = visible


## Unsaved dirty [CustomInputMap] paths when the user closes the project.
func _get_unsaved_status( for_scene:String ) -> String:
	if not for_scene.is_empty():
		return ""
	var maps:Array[CustomInputMap] = _prune_dirty_maps()
	if maps.is_empty():
		return ""
	return "Save changes to Input Map resource(s):\n%s" % "\n".join(
			maps.map( _dirty_map_resource_path ) )


## Persist dirty maps via [ResourceSaver] (called with the save-all path).
func _save_external_data() -> void:
	# Sequential I/O: plain loop is intentional (not a pure projection).
	var maps:Array[CustomInputMap] = _prune_dirty_maps()
	for m:CustomInputMap in maps:
		var err:Error = ResourceSaver.save( m ) as Error
		if err != OK:
			push_error(
					"InputMapEditorPlugin: failed to save '%s': %s"
					% [m.resource_path, error_string( err )] )
	_dirty_maps.clear()


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

#region Host session
#MARK: Host session

func _session_kind() -> int:
	if _session == null:
		return -1
	return _session.kind


func _session_panel() -> InputMapEditor:
	if _session == null:
		return null
	return _session.panel


func _session_dock() -> EditorDock:
	if _session == null:
		return null
	return _session.dock


func _is_host_main_screen() -> bool:
	return _session != null and _session.is_main_screen()


func _is_host_inspector() -> bool:
	return _session != null and _session.is_inspector()


func _attach_session( desired_kind:int ) -> void:
	var panel:InputMapEditor = null
	if desired_kind != SettingsScript.HostMode.INSPECTOR:
		panel = _create_panel()
	_session = HostSessionScript.attach( self, desired_kind, panel )
	if panel != null:
		_apply_panel_defaults( panel )


func _detach_session() -> void:
	# Cancel deferred work tied to this session.
	_session_id += 1
	_unbind_inspector_editor_any()
	if _session == null:
		return
	var panel:InputMapEditor = _session_panel()
	if is_instance_valid( panel ) \
	and panel.resource_modified.is_connected( _on_resource_modified ):
		panel.resource_modified.disconnect( _on_resource_modified )
	var session:HostSession = _session
	_session = null
	session.detach( self )


## Switch applied host to match [member opts.host_mode]. Preserves dirty maps.
## [br]Dock ↔ Inspector is in-process. Any transition involving main screen needs
## a plugin disable/enable (engine builds main tabs only at enable time).
func _rehost() -> void:
	if _shutting_down or _rehosting or opts == null:
		return
	var desired:int = opts.host_mode
	var applied:int = _session_kind()
	if _session != null and applied == desired:
		return
	var touches_main:bool = (
			desired == SettingsScript.HostMode.MAIN_SCREEN
			or applied == SettingsScript.HostMode.MAIN_SCREEN
	)
	if touches_main:
		_save_project_settings( "rehost main-screen notice" )
		_toast(
				"Main screen host changes require disable and re-enable "
				+ "of the Custom Input Map Editor plugin." )
		return
	_rehosting = true
	_settings_live = false
	_detach_session()
	_attach_session( desired )
	_on_edited_object_changed()
	_settings_live = true
	_rehosting = false
	_toast(
			"Input Map Editor host updated (%s)."
			% _host_mode_label( desired ) )


func _create_panel() -> InputMapEditor:
	var panel:InputMapEditor = EditorScene.instantiate() as InputMapEditor
	panel.resource_edit_mode = true
	panel.apply_edit_map_to_engine = false
	_apply_panel_defaults( panel )
	_connect_sig( panel.resource_modified, _on_resource_modified )
	return panel


func _raise_editor_if_needed() -> void:
	if not _auto_raise or _shutting_down:
		return
	if _is_host_inspector():
		return
	var panel:InputMapEditor = _session_panel()
	if not is_instance_valid( panel ):
		return
	if _is_host_main_screen():
		EditorInterface.set_main_screen_editor( MAIN_SCREEN_NAME )
		return
	var dock:EditorDock = _session_dock()
	if is_instance_valid( dock ):
		dock.make_visible()


func _apply_panel_defaults( editor:InputMapEditor ) -> void:
	if editor == null:
		return
	editor.panel_min_height = _panel_min_height
	editor.custom_minimum_size = Vector2( 0.0, _panel_min_height )


func _host_mode_label( kind:int ) -> String:
	match kind:
		SettingsScript.HostMode.MAIN_SCREEN:
			return "Main screen"
		SettingsScript.HostMode.INSPECTOR:
			return "Inspector"
		_:
			return "Dock"


func _toast( message:String ) -> void:
	push_warning( "InputMapEditorPlugin: %s" % message )
	if EditorInterface.has_method( &"get_editor_toaster" ):
		var toaster:Object = EditorInterface.call( &"get_editor_toaster" )
		if toaster != null and toaster.has_method( &"push_toast" ):
			toaster.call( &"push_toast", message, 1 )

#endregion Host session


#region Settings sync
#MARK: Settings sync

func _setup_settings_helper() -> void:
	opts = SettingsScript.new()
	settings_hlp = SettingsHelperScript.new( opts, SETTINGS_PREFIX )
	@warning_ignore( "return_value_discarded" )
	settings_hlp.connect( &"settings_changed", _on_settings_changed )


func _enable_settings_live( id:int ) -> void:
	if _shutting_down or id != _session_id or opts == null:
		return
	_auto_raise = opts.auto_raise
	_panel_min_height = opts.panel_min_height
	_settings_live = true


## [param prop_name] already applied on [member opts] by SettingsHelper.
func _apply_settings_change( id:int, prop_name:StringName ) -> void:
	if _shutting_down or id != _session_id or not _settings_live or _rehosting:
		return
	if opts == null:
		return
	match prop_name:
		&"host_mode":
			_save_project_settings( "rehost desired host" )
			_rehost()
		&"auto_raise":
			_auto_raise = opts.auto_raise
			_save_project_settings( "auto_raise" )
		&"panel_min_height":
			_panel_min_height = opts.panel_min_height
			var panel:InputMapEditor = _session_panel()
			if is_instance_valid( panel ):
				_apply_panel_defaults( panel )
			if is_instance_valid( _inspector_editor ):
				_apply_panel_defaults( _inspector_editor )
			_save_project_settings( "panel_min_height" )
		&"default_deadzone":
			_save_project_settings( "default_deadzone" )
		_:
			pass

#endregion Settings sync


#region Inspector plugin API
#MARK: Inspector plugin API

## True when inspector host is applied and [param object] is a [CustomInputMap].
func inspector_can_handle( object:Object ) -> bool:
	if not _is_host_inspector():
		return false
	return object is CustomInputMap


## Cached [code]panel_min_height[/code] setting for inspector embeds.
func get_settings_panel_min_height() -> float:
	return _panel_min_height


## Register an inspector-hosted [InputMapEditor] for dirty tracking and defaults.
func bind_inspector_editor( editor:InputMapEditor ) -> void:
	if editor == null or _shutting_down:
		return
	if _inspector_editor == editor:
		return
	_unbind_inspector_editor_any()
	_inspector_editor = editor
	_apply_panel_defaults( editor )
	if not editor.resource_modified.is_connected( _on_resource_modified ):
		_connect_sig( editor.resource_modified, _on_resource_modified )


## Drop [param editor] if it is the bound inspector instance.
func unbind_inspector_editor( editor:InputMapEditor ) -> void:
	if editor == null:
		return
	if _inspector_editor != editor:
		return
	if is_instance_valid( editor ) \
	and editor.resource_modified.is_connected( _on_resource_modified ):
		editor.resource_modified.disconnect( _on_resource_modified )
	_inspector_editor = null


func _unbind_inspector_editor_any() -> void:
	if is_instance_valid( _inspector_editor ):
		if _inspector_editor.resource_modified.is_connected( _on_resource_modified ):
			_inspector_editor.resource_modified.disconnect( _on_resource_modified )
	_inspector_editor = null


## First open map (panel or inspector) that contains [param action], or null.
func inspector_map_for_action( action:InputAction ) -> CustomInputMap:
	var maps:Array[CustomInputMap] = []
	var panel:InputMapEditor = _session_panel()
	if is_instance_valid( panel ):
		maps.append_array( panel.open_maps )
	if is_instance_valid( _inspector_editor ):
		maps.append_array( _inspector_editor.open_maps )
	for map:CustomInputMap in maps:
		if map != null and map.get_actions().has( action ):
			return map
	return null

#endregion Inspector plugin API


func _active_editor() -> InputMapEditor:
	if _is_host_inspector() and is_instance_valid( _inspector_editor ):
		return _inspector_editor
	return _session_panel()


func _edit_map( map:CustomInputMap, do_raise:bool = true ) -> void:
	var editor:InputMapEditor = _active_editor()
	if editor == null or map == null:
		return
	if editor.resource_edit_mode \
	and editor.edit_map == map \
	and editor.open_maps.size() == 1 \
	and editor.open_maps[0] == map:
		if do_raise:
			_raise_editor_if_needed()
		return
	editor.configure_for_resource( map )
	if do_raise:
		_raise_editor_if_needed()


func _clear_edited_map() -> void:
	var editor:InputMapEditor = _active_editor()
	if editor == null:
		return
	if editor.resource_edit_mode \
	and editor.edit_map == null \
	and editor.open_maps.is_empty():
		return
	editor.configure_for_resource( null )


func _refresh_editor_for_map( editor:InputMapEditor, map:CustomInputMap ) -> void:
	if editor == null or map == null:
		return
	if editor.edit_map != map and not editor.open_maps.has( map ):
		return
	editor.refresh()


func _open_maps_contain_action( action:InputAction ) -> bool:
	return inspector_map_for_action( action ) != null


func _refresh_editor_if_action( editor:InputMapEditor, action:InputAction ) -> void:
	if editor == null or action == null:
		return
	for map:CustomInputMap in editor.open_maps:
		if map != null and map.get_actions().has( action ):
			editor.refresh()
			return
	if editor.edit_map != null and editor.edit_map.get_actions().has( action ):
		editor.refresh()


func _clear_suppress_deferred( id:int ) -> void:
	# Use call_deferred with bound id check inside.
	_clear_suppress.call_deferred( id )


func _clear_suppress( id:int ) -> void:
	if _shutting_down or id != _session_id:
		return
	_suppress_edited_object_signal = false


func _mark_map_needs_save( map:CustomInputMap ) -> void:
	if map == null:
		return
	if map.resource_path.is_empty():
		EditorInterface.mark_scene_as_unsaved()
		return
	if not _dirty_maps.has( map ):
		_dirty_maps.append( map )


# Drop null / unsaved (empty path) maps. Returns the cleaned list (also stored).
func _prune_dirty_maps() -> Array[CustomInputMap]:
	_dirty_maps.assign( _dirty_maps.filter( _is_dirty_map_savable ) )
	return _dirty_maps


func _is_dirty_map_savable( m:CustomInputMap ) -> bool:
	return m != null and not m.resource_path.is_empty()


func _dirty_map_resource_path( m:CustomInputMap ) -> String:
	return m.resource_path


func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags ) as Error
	if err != OK:
		push_error( "InputMapEditorPlugin._connect_sig: %s" % error_string( err ) )


func _save_project_settings( context:String ) -> void:
	var err:Error = ProjectSettings.save()
	if err != OK:
		push_warning(
				"InputMapEditorPlugin: ProjectSettings.save failed (%s): %s"
				% [context, error_string( err )] )
