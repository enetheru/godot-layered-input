@tool
extends EditorPlugin

## Bottom-panel editor for [CustomInputMap] resources (Phantom Camera-style).
## Selecting a CustomInputMap in the Inspector focuses this panel and loads it.
##[br][color=goldenrod]TODO[/color]:Multi-select open maps from the filesystem.


const EditorScene = preload( "ui/input_map_editor.tscn" )


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var _panel:InputMapEditor
var _panel_button:Button

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
	# Nested InputAction under an open map — keep the bottom panel; do not wipe.
	if obj is InputAction \
	and _open_maps_contain_action( obj as InputAction ):
		return
	# Inspector left the map (and any nested actions) — drop the stale list.
	_clear_edited_map()


## Inspector mutated a property on the current object (e.g. `_actions` add/remove).
## [CustomInputMap] emits [signal Resource.changed] from its `_actions` setter;
## this is a second path so the panel still rebuilds if a future inspector path
## mutates without going through that setter.
func _on_inspector_property_edited( _property:String ) -> void:
	if _panel == null:
		return
	var obj:Object = EditorInterface.get_inspector().get_edited_object()
	if obj is CustomInputMap:
		_refresh_panel_for_map( obj as CustomInputMap )
		return
	# Nested [InputAction] edit while the map is still open in the bottom panel.
	if obj is InputAction:
		_refresh_panel_if_action_in_open_maps( obj as InputAction )


func _on_resource_modified( map:CustomInputMap ) -> void:
	if map == null:
		return
	# Panel already emit_changed (and notify_property_list_changed only when
	# action keys change). Do not call EditorFileSystem.update_file here — it
	# rescans and re-configures the panel in a slow loop.
	_mark_map_needs_save( map )
	_suppress_edited_object_signal = true
	_clear_suppress.call_deferred()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _enter_tree() -> void:
	_export_plugin = preload( "export_plugin.gd" ).new()
	add_export_plugin( _export_plugin )

	_panel = EditorScene.instantiate()
	_panel.resource_edit_mode = true
	_panel.apply_edit_map_to_engine = false
	_panel.custom_minimum_size = Vector2( 0.0, _panel.panel_min_height )

	_connect_sig( _panel.resource_modified, _on_resource_modified )

	_panel_button = add_control_to_bottom_panel( _panel, "Input Map" )

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if not inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
		_connect_sig( inspector.edited_object_changed, _on_edited_object_changed )
	if not inspector.property_edited.is_connected( _on_inspector_property_edited ):
		_connect_sig( inspector.property_edited, _on_inspector_property_edited )

	_on_edited_object_changed()

	# FIXME at some point during the enabling of the plugin this is triggered:
	#   ERROR: scene\gui\tree.cpp:1576 - Index p_column = 1 is out of bounds (cells.size() = 1).
	# Since the error does not show the gdscript, I cannot be sure exactly where it comes from.


func _exit_tree() -> void:
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
		remove_control_from_bottom_panel( _panel )
		_panel.queue_free()
		_panel = null
	_panel_button = null
	_dirty_maps.clear()


## List dirty standalone Input Maps so Save All / quit can prompt.
func _get_unsaved_status( for_scene:String ) -> String:
	_prune_dirty_maps()
	if not for_scene.is_empty():
		# Scene close: pathless maps already dirtied the scene via mark_scene_as_unsaved.
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

func _edit_map( map:CustomInputMap ) -> void:
	if _panel == null or map == null:
		return
	# Same instance already the sole open map — do not rebuild the tree.
	if _panel.resource_edit_mode \
	and _panel.edit_map == map \
	and _panel.open_maps.size() == 1 \
	and _panel.open_maps[0] == map:
		return
	_panel.configure_for_resource( map )
	make_bottom_panel_item_visible( _panel )


## Clear the bottom-panel list when the inspector is not on a CustomInputMap.
func _clear_edited_map() -> void:
	if _panel == null:
		return
	if _panel.resource_edit_mode \
	and _panel.edit_map == null \
	and _panel.open_maps.is_empty():
		return
	_panel.configure_for_resource( null )


## Rebuild the bottom panel when [param map] is currently shown.
func _refresh_panel_for_map( map:CustomInputMap ) -> void:
	if _panel == null or map == null:
		return
	if _panel.edit_map != map and not _panel.open_maps.has( map ):
		return
	_panel.refresh()


## True if [param action] is a non-null value in any open map.
func _open_maps_contain_action( action:InputAction ) -> bool:
	if _panel == null or action == null:
		return false
	for map:CustomInputMap in _panel.open_maps:
		if map != null and map.get_actions().has( action ):
			return true
	return false


## If [param action] is stored in an open map, refresh that map's tree.
func _refresh_panel_if_action_in_open_maps( action:InputAction ) -> void:
	if not _open_maps_contain_action( action ):
		return
	_panel.refresh()


func _clear_suppress() -> void:
	_suppress_edited_object_signal = false


## Disk maps → plugin dirty list (Save All). Pathless → mark the open scene unsaved.
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


# Connect and report failures (Signal.connect returns Error).
func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags ) as Error
	if err != OK:
		push_error( "InputMapEditorPlugin._connect_sig: %s" % error_string( err ) )
