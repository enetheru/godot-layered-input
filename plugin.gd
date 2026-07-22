@tool
extends EditorPlugin

## Editor plugin for [CustomInputMap] resources.
## Default host: bottom panel. Project Settings (prefix [code]input_map_editor/[/code]):
## [br] • [code]use_main_screen[/code] — main editor tab (reload plugin)
## [br] • [code]replace_inspector[/code] — [EditorInspectorPlugin] host (reload plugin)
## [br] • [code]auto_raise[/code] — raise bottom/main when a map is selected
## [br][color=goldenrod]TODO[/color]:Multi-select open maps from the filesystem.


const EditorScene = preload( "ui/input_map_editor.tscn" )
const SettingsScript = preload( "settings/input_map_editor_settings.gd" )
const SettingsHelperScript = preload( "settings/settings_helper.gd" )
const InspectorPluginScript = preload( "inspector_plugin.gd" )

const SETTINGS_PREFIX:String = "input_map_editor"
const MAIN_SCREEN_NAME:String = "Input Map"


## Host for reparenting [member _panel] into the Inspector safely.
class InspectorHost extends MarginContainer:
	var plugin:EditorPlugin

	func _ready() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2( 0.0, 280.0 )
		if plugin != null and plugin.has_method( &"attach_panel_to_inspector_host" ):
			plugin.call( &"attach_panel_to_inspector_host", self )


	func _exit_tree() -> void:
		if plugin != null and plugin.has_method( &"detach_panel_from_inspector_host" ):
			plugin.call( &"detach_panel_from_inspector_host", self )


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var _panel:InputMapEditor
var _panel_button:Button
## Keeps [member _panel] alive when not parented to a host.
var _panel_stash:Node

var _opts:InputMapEditorSettings
var _settings_mgr:RefCounted
var _inspector_plugin:EditorInspectorPlugin

## Avoid re-entrant configure when we caused the inspector refresh ourselves.
var _suppress_edited_object_signal:bool = false

## Standalone disk maps the bottom panel has mutated (need Save / _save_external_data).
var _dirty_maps:Array[CustomInputMap] = []

## Strips editor-only / test paths via [code].exportignore[/code] (see export_plugin.gd).
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
	# Nested InputAction under an open map — keep the editor; do not wipe.
	if obj is InputAction \
	and _open_maps_contain_action( obj as InputAction ):
		return
	# Inspector left the map (and any nested actions) — drop the stale list.
	# In replace_inspector mode the host is freed; still clear open maps.
	if not _use_replace_inspector():
		_clear_edited_map()


## Inspector mutated a property on the current object (e.g. `_actions` add/remove).
func _on_inspector_property_edited( _property:String ) -> void:
	if _panel == null:
		return
	var obj:Object = EditorInterface.get_inspector().get_edited_object()
	if obj is CustomInputMap:
		_refresh_panel_for_map( obj as CustomInputMap )
		return
	if obj is InputAction:
		_refresh_panel_if_action_in_open_maps( obj as InputAction )


func _on_resource_modified( map:CustomInputMap ) -> void:
	if map == null:
		return
	_mark_map_needs_save( map )
	_suppress_edited_object_signal = true
	_clear_suppress.call_deferred()


func _on_settings_changed( setting_name:StringName, _value:Variant ) -> void:
	# Host mode flags need a plugin reload; auto_raise is live.
	if setting_name == &"use_main_screen" \
	or setting_name == &"replace_inspector":
		push_warning(
				"InputMapEditorPlugin: '%s' changed — disable and re-enable "
				% setting_name
				+ "the Custom Input Map Editor plugin to apply host layout." )


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _enter_tree() -> void:
	_opts = SettingsScript.new() as InputMapEditorSettings
	_settings_mgr = SettingsHelperScript.new( _opts, SETTINGS_PREFIX )
	if _settings_mgr.has_signal( &"settings_changed" ):
		_connect_sig(
				_settings_mgr.settings_changed,
				_on_settings_changed )

	_export_plugin = preload( "export_plugin.gd" ).new()
	add_export_plugin( _export_plugin )

	_panel_stash = Node.new()
	_panel_stash.name = "InputMapEditorPanelStash"
	add_child( _panel_stash )

	_panel = EditorScene.instantiate()
	_panel.resource_edit_mode = true
	_panel.apply_edit_map_to_engine = false
	_panel.custom_minimum_size = Vector2( 0.0, _panel.panel_min_height )
	_connect_sig( _panel.resource_modified, _on_resource_modified )
	_panel_stash.add_child( _panel )

	_attach_host()

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if not inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
		_connect_sig( inspector.edited_object_changed, _on_edited_object_changed )
	if not inspector.property_edited.is_connected( _on_inspector_property_edited ):
		_connect_sig( inspector.property_edited, _on_inspector_property_edited )

	_on_edited_object_changed()

	# FIXME at some point during the enabling of the plugin this is triggered:
	#   ERROR: scene\gui\tree.cpp:1576 - Index p_column = 1 is out of bounds (cells.size() = 1).


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
		_panel.queue_free()
		_panel = null
	if is_instance_valid( _panel_stash ):
		_panel_stash.queue_free()
		_panel_stash = null
	_panel_button = null
	_settings_mgr = null
	_opts = null
	_dirty_maps.clear()


func _has_main_screen() -> bool:
	return _use_main_screen()


func _get_plugin_name() -> String:
	return MAIN_SCREEN_NAME


func _get_plugin_icon() -> Texture2D:
	# Editor theme icon; falls back if missing.
	var theme:Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon( &"InputEventAction", &"EditorIcons" ):
		return theme.get_icon( &"InputEventAction", &"EditorIcons" )
	if theme != null and theme.has_icon( &"Object", &"EditorIcons" ):
		return theme.get_icon( &"Object", &"EditorIcons" )
	return null


func _make_visible( visible:bool ) -> void:
	if not is_instance_valid( _panel ):
		return
	if not _use_main_screen():
		return
	_panel.visible = visible


## List dirty standalone Input Maps so Save All / quit can prompt.
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


## Persist standalone maps the panel marked dirty.
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

func _use_main_screen() -> bool:
	return _opts != null and _opts.use_main_screen


func _use_replace_inspector() -> bool:
	return _opts != null and _opts.replace_inspector


func _use_auto_raise() -> bool:
	return _opts == null or _opts.auto_raise


func _attach_host() -> void:
	if _use_replace_inspector():
		_inspector_plugin = InspectorPluginScript.new()
		if _inspector_plugin.has_method( &"setup" ):
			_inspector_plugin.call( &"setup", self )
		add_inspector_plugin( _inspector_plugin )
		# Panel stays in stash until an inspector host claims it.
		return
	if _use_main_screen():
		var main:VBoxContainer = EditorInterface.get_editor_main_screen()
		_reparent_panel( main )
		_panel.visible = false
		return
	# Default: bottom panel (must not already have a parent).
	if is_instance_valid( _panel ) and _panel.get_parent() != null:
		_panel.get_parent().remove_child( _panel )
	_panel_button = add_control_to_bottom_panel( _panel, MAIN_SCREEN_NAME )
	_panel.visible = true


func _detach_host() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin( _inspector_plugin )
		_inspector_plugin = null
	if _panel_button != null and is_instance_valid( _panel ):
		remove_control_from_bottom_panel( _panel )
		_panel_button = null
	if is_instance_valid( _panel ) and is_instance_valid( _panel_stash ):
		if _panel.get_parent() != _panel_stash:
			_reparent_panel( _panel_stash )


func _reparent_panel( new_parent:Node ) -> void:
	if not is_instance_valid( _panel ) or new_parent == null:
		return
	var old:Node = _panel.get_parent()
	if old == new_parent:
		return
	if old != null:
		old.remove_child( _panel )
	new_parent.add_child( _panel )


## Raise bottom panel or switch main screen when [member auto_raise] allows.
func _raise_editor_if_needed() -> void:
	if not _use_auto_raise():
		return
	if _use_replace_inspector():
		return
	if not is_instance_valid( _panel ):
		return
	if _use_main_screen():
		EditorInterface.set_main_screen_editor( MAIN_SCREEN_NAME )
		return
	if _panel_button != null:
		make_bottom_panel_item_visible( _panel )

#endregion Host layout


#region Inspector plugin API
#MARK: Inspector plugin API

## Used by [code]inspector_plugin.gd[/code].
func inspector_can_handle( object:Object ) -> bool:
	if not _use_replace_inspector():
		return false
	if object is CustomInputMap:
		return true
	if object is InputAction \
	and _open_maps_contain_action( object as InputAction ):
		return true
	return false


## Used by [code]inspector_plugin.gd[/code].
func inspector_parse_begin( object:Object, insp:EditorInspectorPlugin ) -> void:
	if object is CustomInputMap:
		_edit_map( object as CustomInputMap, false )
	var host:InspectorHost = InspectorHost.new()
	host.plugin = self
	insp.add_custom_control( host )


func attach_panel_to_inspector_host( host:Control ) -> void:
	if not is_instance_valid( _panel ) or host == null:
		return
	_reparent_panel( host )
	_panel.visible = true
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


func detach_panel_from_inspector_host( host:Control ) -> void:
	if not is_instance_valid( _panel ):
		return
	if _panel.get_parent() != host:
		return
	if is_instance_valid( _panel_stash ):
		_reparent_panel( _panel_stash )
	# Leaving the map's inspector — drop the open list like non-replace mode.
	_clear_edited_map()

#endregion Inspector plugin API


func _edit_map( map:CustomInputMap, do_raise:bool = true ) -> void:
	if _panel == null or map == null:
		return
	# Same instance already the sole open map — optional raise only.
	if _panel.resource_edit_mode \
	and _panel.edit_map == map \
	and _panel.open_maps.size() == 1 \
	and _panel.open_maps[0] == map:
		if do_raise:
			_raise_editor_if_needed()
		return
	_panel.configure_for_resource( map )
	if do_raise:
		_raise_editor_if_needed()


## Clear the action list when the inspector is not on a CustomInputMap.
func _clear_edited_map() -> void:
	if _panel == null:
		return
	if _panel.resource_edit_mode \
	and _panel.edit_map == null \
	and _panel.open_maps.is_empty():
		return
	_panel.configure_for_resource( null )


func _refresh_panel_for_map( map:CustomInputMap ) -> void:
	if _panel == null or map == null:
		return
	if _panel.edit_map != map and not _panel.open_maps.has( map ):
		return
	_panel.refresh()


func _open_maps_contain_action( action:InputAction ) -> bool:
	if _panel == null or action == null:
		return false
	for map:CustomInputMap in _panel.open_maps:
		if map != null and map.get_actions().has( action ):
			return true
	return false


func _refresh_panel_if_action_in_open_maps( action:InputAction ) -> void:
	if not _open_maps_contain_action( action ):
		return
	_panel.refresh()


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
