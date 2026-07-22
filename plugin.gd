@tool
extends EditorPlugin

## Editor plugin for [CustomInputMap] resources.
##
## [b]Host mode[/b] ([code]input_map_editor/host_mode[/code] in Project Settings):
## [br] • [b]Dock[/b] — [EditorDock] via [method add_dock] (any slot + floating)
## [br] • [b]Main screen[/b] — tab next to 2D/3D/Script
## [br] • [b]Inspector[/b] — [EditorInspectorPlugin] for [CustomInputMap]
## [br]Changing host mode requires disable/enable of this plugin.


const EditorScene = preload( "ui/input_map_editor.tscn" )
const SettingsScript = preload( "settings/input_map_editor_settings.gd" )
const InspectorPluginScript = preload( "inspector_plugin.gd" )

const MAIN_SCREEN_NAME:String = "Input Map"


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var _panel:InputMapEditor
## Universal dock host (Godot 4.7+ [EditorDock]); null in other modes.
var _dock:EditorDock
var _opts:InputMapEditorSettings
var _inspector_plugin:EditorInspectorPlugin
var _inspector_editor:InputMapEditor

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
	if _suppress_edited_object_signal:
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
	if map == null:
		return
	_mark_map_needs_save( map )
	_suppress_edited_object_signal = true
	_clear_suppress.call_deferred()


func _on_settings_changed( setting_name:StringName, _value:Variant ) -> void:
	if setting_name == &"host_mode":
		_notify_reload_plugin(
				"Host mode changed. Disable and re-enable the "
				+ "Custom Input Map Editor plugin to apply." )
		# Persist immediately so unload does not drop the choice.
		ProjectSettings.save()
		return
	if setting_name == &"panel_min_height" and is_instance_valid( _panel ):
		_apply_panel_defaults( _panel )
	if setting_name == &"auto_raise" \
	or setting_name == &"default_deadzone" \
	or setting_name == &"panel_min_height":
		ProjectSettings.save()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _enter_tree() -> void:
	_opts = SettingsScript.new() as InputMapEditorSettings
	_connect_sig( _opts.settings_changed, _on_settings_changed )

	_export_plugin = preload( "export_plugin.gd" ).new()
	add_export_plugin( _export_plugin )

	_panel = EditorScene.instantiate() as InputMapEditor
	_panel.resource_edit_mode = true
	_panel.apply_edit_map_to_engine = false
	_apply_panel_defaults( _panel )
	_connect_sig( _panel.resource_modified, _on_resource_modified )

	_attach_host()

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if not inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
		_connect_sig( inspector.edited_object_changed, _on_edited_object_changed )
	if not inspector.property_edited.is_connected( _on_inspector_property_edited ):
		_connect_sig( inspector.property_edited, _on_inspector_property_edited )

	_on_edited_object_changed()


func _exit_tree() -> void:
	_detach_host()

	if _export_plugin:
		remove_export_plugin( _export_plugin )
		_export_plugin = null

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if inspector:
		if inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
			inspector.edited_object_changed.disconnect( _on_edited_object_changed )
		if inspector.property_edited.is_connected( _on_inspector_property_edited ):
			inspector.property_edited.disconnect( _on_inspector_property_edited )

	if is_instance_valid( _panel ):
		if _panel.resource_modified.is_connected( _on_resource_modified ):
			_panel.resource_modified.disconnect( _on_resource_modified )
		if _panel.get_parent() != null:
			_panel.get_parent().remove_child( _panel )
		_panel.queue_free()
		_panel = null
	_dock = null
	_inspector_editor = null
	_opts = null
	_dirty_maps.clear()
	# Intentionally leave ProjectSettings keys intact.


## Editor may call this before [method _enter_tree]; read ProjectSettings only.
func _has_main_screen() -> bool:
	return (
			InputMapEditorSettings.read_host_mode()
			== InputMapEditorSettings.HostMode.MAIN_SCREEN
	)


func _get_plugin_name() -> String:
	return MAIN_SCREEN_NAME


func _get_plugin_icon() -> Texture2D:
	var theme:Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon( &"InputEventAction", &"EditorIcons" ):
		return theme.get_icon( &"InputEventAction", &"EditorIcons" )
	if theme != null and theme.has_icon( &"Node", &"EditorIcons" ):
		return theme.get_icon( &"Node", &"EditorIcons" )
	return null


func _make_visible( visible:bool ) -> void:
	if not is_instance_valid( _panel ):
		return
	if not _is_host_main_screen():
		return
	_panel.visible = visible


func _get_unsaved_status( for_scene:String ) -> String:
	_prune_dirty_maps()
	if not for_scene.is_empty():
		return ""
	if _dirty_maps.is_empty():
		return ""
	var lines:PackedStringArray = PackedStringArray()
	for m:CustomInputMap in _dirty_maps:
		if m != null and not m.resource_path.is_empty():
			lines.append( m.resource_path )
	if lines.is_empty():
		return ""
	return "Save changes to Input Map resource(s):\n%s" % "\n".join( lines )


func _save_external_data() -> void:
	_prune_dirty_maps()
	for m:CustomInputMap in _dirty_maps:
		if m == null or m.resource_path.is_empty():
			continue
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

#region Host layout
#MARK: Host layout

func _host_mode() -> int:
	if _opts != null:
		return _opts.host_mode as int
	return InputMapEditorSettings.read_host_mode()


func _is_host_main_screen() -> bool:
	return _host_mode() == InputMapEditorSettings.HostMode.MAIN_SCREEN


func _is_host_inspector() -> bool:
	return _host_mode() == InputMapEditorSettings.HostMode.INSPECTOR


func _use_auto_raise() -> bool:
	if _opts != null:
		return _opts.auto_raise
	return InputMapEditorSettings.read_auto_raise()


func _attach_host() -> void:
	match _host_mode():
		InputMapEditorSettings.HostMode.MAIN_SCREEN:
			# https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_main_screen_plugins.html
			var main_screen:VBoxContainer = EditorInterface.get_editor_main_screen()
			main_screen.add_child( _panel )
			_panel.set_anchors_and_offsets_preset( Control.PRESET_FULL_RECT )
			_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_make_visible( false )
		InputMapEditorSettings.HostMode.INSPECTOR:
			_inspector_plugin = InspectorPluginScript.new()
			if _inspector_plugin.has_method( &"setup" ):
				_inspector_plugin.call( &"setup", self )
			add_inspector_plugin( _inspector_plugin )
			add_child( _panel )
			_panel.visible = false
		_:
			# Universal dock (not add_control_to_bottom_panel — that is bottom-only).
			# https://docs.godotengine.org/en/stable/classes/class_editordock.html
			_dock = EditorDock.new()
			_dock.title = MAIN_SCREEN_NAME
			_dock.layout_key = "enetheru_input_map_editor"
			_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
			# Vertical (side) + horizontal (bottom) + floating.
			_dock.available_layouts = (
					EditorDock.DOCK_LAYOUT_VERTICAL
					| EditorDock.DOCK_LAYOUT_HORIZONTAL
					| EditorDock.DOCK_LAYOUT_FLOATING
			)
			_dock.global = true
			_dock.icon_name = &"InputEventAction"
			_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_dock.add_child( _panel )
			add_dock( _dock )
			_panel.visible = true


func _detach_host() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin( _inspector_plugin )
		_inspector_plugin = null
	if is_instance_valid( _dock ):
		remove_dock( _dock )
		# Panel is child of dock; reparent out before freeing dock.
		if is_instance_valid( _panel ) and _panel.get_parent() == _dock:
			_dock.remove_child( _panel )
		_dock.queue_free()
		_dock = null


func _raise_editor_if_needed() -> void:
	if not _use_auto_raise():
		return
	if _is_host_inspector():
		return
	if not is_instance_valid( _panel ):
		return
	if _is_host_main_screen():
		EditorInterface.set_main_screen_editor( MAIN_SCREEN_NAME )
		return
	if is_instance_valid( _dock ):
		_dock.make_visible()


func _notify_reload_plugin( message:String ) -> void:
	push_warning( "InputMapEditorPlugin: %s" % message )
	if EditorInterface.has_method( &"get_editor_toaster" ):
		var toaster:Object = EditorInterface.call( &"get_editor_toaster" )
		if toaster != null and toaster.has_method( &"push_toast" ):
			toaster.call( &"push_toast", message, 1 )


func _apply_panel_defaults( editor:InputMapEditor ) -> void:
	if editor == null:
		return
	var min_h:float = InputMapEditorSettings.read_panel_min_height()
	if _opts != null:
		min_h = _opts.panel_min_height
	editor.panel_min_height = min_h
	editor.custom_minimum_size = Vector2( 0.0, min_h )

#endregion Host layout


#region Inspector plugin API
#MARK: Inspector plugin API

func inspector_can_handle( object:Object ) -> bool:
	if not _is_host_inspector():
		return false
	return object is CustomInputMap


func get_settings_panel_min_height() -> float:
	return InputMapEditorSettings.read_panel_min_height()


func bind_inspector_editor( editor:InputMapEditor ) -> void:
	_inspector_editor = editor
	if editor == null:
		return
	_apply_panel_defaults( editor )
	if not editor.resource_modified.is_connected( _on_resource_modified ):
		_connect_sig( editor.resource_modified, _on_resource_modified )


func inspector_map_for_action( action:InputAction ) -> CustomInputMap:
	var maps:Array[CustomInputMap] = []
	if is_instance_valid( _panel ):
		maps.append_array( _panel.open_maps )
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
	return _panel


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


func _clear_suppress() -> void:
	_suppress_edited_object_signal = false


func _mark_map_needs_save( map:CustomInputMap ) -> void:
	if map == null:
		return
	if map.resource_path.is_empty():
		EditorInterface.mark_scene_as_unsaved()
		return
	if not _dirty_maps.has( map ):
		_dirty_maps.append( map )


func _prune_dirty_maps() -> void:
	var kept:Array[CustomInputMap] = []
	for m:CustomInputMap in _dirty_maps:
		if m != null and not m.resource_path.is_empty():
			kept.append( m )
	_dirty_maps = kept


func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags ) as Error
	if err != OK:
		push_error( "InputMapEditorPlugin._connect_sig: %s" % error_string( err ) )
