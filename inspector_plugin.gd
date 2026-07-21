@tool
extends EditorInspectorPlugin
## Embeds [InputMapEditor] when the inspected object is a [CustomInputMap].

const InputMapEditorScene = preload("res://addons/enetheru.input_map_editor/ui/input_map_editor.tscn")

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _can_handle(object: Object) -> bool:
	return object is CustomInputMap


func _parse_begin(object: Object) -> void:
	var map: CustomInputMap = object
	var editor: InputMapEditor = InputMapEditorScene.instantiate()
	editor.custom_minimum_size = Vector2(0, 420)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Set before enter_tree / _ready so resource mode is active immediately.
	editor.resource_edit_mode = true
	editor.edit_map = map
	editor.apply_edit_map_to_engine = false

	@warning_ignore("return_value_discarded")
	editor.resource_modified.connect(_on_resource_modified)

	add_custom_control(editor)


func _on_resource_modified(map: CustomInputMap) -> void:
	if map == null:
		return
	map.emit_changed()
	if map.resource_path.is_empty() or _plugin == null:
		return
	var ei: EditorInterface = _plugin.get_editor_interface()
	if ei == null:
		return
	var fs: EditorFileSystem = ei.get_resource_filesystem()
	if fs:
		fs.update_file(map.resource_path)
