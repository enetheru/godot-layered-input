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
	else:
		# Inspector left a CustomInputMap — drop the stale action list.
		_clear_edited_map()


func _on_resource_modified( map:CustomInputMap ) -> void:
	if map == null:
		return
	# Panel already emit_changed + notify_property_list_changed for the inspector.
	# Do not call EditorFileSystem.update_file here — it rescans and re-configures
	# the panel in a slow loop.
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
	_panel = EditorScene.instantiate()
	_panel.resource_edit_mode = true
	_panel.apply_edit_map_to_engine = false
	_panel.custom_minimum_size = Vector2( 0.0, _panel.panel_min_height )

	_connect_sig( _panel.resource_modified, _on_resource_modified )

	_panel_button = add_control_to_bottom_panel( _panel, "Input Map" )

	var inspector:EditorInspector = EditorInterface.get_inspector()
	if not inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
		_connect_sig( inspector.edited_object_changed, _on_edited_object_changed )

	_on_edited_object_changed()

	# FIXME at some point during the enabling of the plugin this is triggered:
	#   ERROR: scene\gui\tree.cpp:1576 - Index p_column = 1 is out of bounds (cells.size() = 1).
	# Since the error does not show the gdscript, I cannot be sure exactly where it comes from.


func _exit_tree() -> void:
	var inspector:EditorInspector = EditorInterface.get_inspector()
	if inspector \
	and inspector.edited_object_changed.is_connected( _on_edited_object_changed ):
		inspector.edited_object_changed.disconnect( _on_edited_object_changed )

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
