@tool
extends EditorPlugin
## Bottom-panel editor for [CustomInputMap] resources (Phantom Camera-style).
## Selecting a CustomInputMap in the Inspector focuses this panel and loads it.

const EditorScene = preload("res://addons/enetheru.input_map_editor/ui/input_map_editor.tscn")

var _panel: InputMapEditor
var _panel_button: Button


func _enter_tree() -> void:
	_panel = EditorScene.instantiate()
	_panel.resource_edit_mode = true
	_panel.apply_edit_map_to_engine = false
	_panel.custom_minimum_size = Vector2(0, 280)

	@warning_ignore("return_value_discarded")
	_panel.resource_modified.connect(_on_resource_modified)

	_panel_button = add_control_to_bottom_panel(_panel, "Input Map")

	var inspector: EditorInspector = get_editor_interface().get_inspector()
	if not inspector.edited_object_changed.is_connected(_on_edited_object_changed):
		@warning_ignore("return_value_discarded")
		inspector.edited_object_changed.connect(_on_edited_object_changed)

	# If a CustomInputMap is already under inspection, load it.
	_on_edited_object_changed()


func _exit_tree() -> void:
	var inspector: EditorInspector = get_editor_interface().get_inspector()
	if inspector.edited_object_changed.is_connected(_on_edited_object_changed):
		inspector.edited_object_changed.disconnect(_on_edited_object_changed)

	if _panel:
		if _panel.resource_modified.is_connected(_on_resource_modified):
			_panel.resource_modified.disconnect(_on_resource_modified)
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	_panel_button = null


func _on_edited_object_changed() -> void:
	var obj: Object = get_editor_interface().get_inspector().get_edited_object()
	if obj is CustomInputMap:
		_edit_map(obj)


func _edit_map(map: CustomInputMap) -> void:
	if _panel == null or map == null:
		return
	_panel.configure_for_resource(map)
	make_bottom_panel_item_visible(_panel)


func _on_resource_modified(map: CustomInputMap) -> void:
	if map == null:
		return
	map.emit_changed()
	if map.resource_path.is_empty():
		return
	var fs: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	if fs:
		fs.update_file(map.resource_path)
