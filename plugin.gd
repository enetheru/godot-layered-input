@tool
extends EditorPlugin


## Bottom-panel editor for [CustomInputMap] resources (Phantom Camera-style).
## Selecting a CustomInputMap in the Inspector focuses this panel and loads it.

const EditorScene = preload("ui/input_map_editor.tscn")


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var _panel: InputMapEditor
var _panel_button: Button
## Avoid re-entrant configure when we caused the inspector refresh ourselves.
var _suppress_edited_object_signal: bool = false


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
	_panel.custom_minimum_size = Vector2(0, 280)

	@warning_ignore("return_value_discarded")
	_panel.resource_modified.connect(_on_resource_modified)

	_panel_button = add_control_to_bottom_panel(_panel, "Input Map")

	var inspector: EditorInspector = get_editor_interface().get_inspector()
	if not inspector.edited_object_changed.is_connected(_on_edited_object_changed):
		@warning_ignore("return_value_discarded")
		inspector.edited_object_changed.connect(_on_edited_object_changed)

	_on_edited_object_changed()


func _exit_tree() -> void:
	var inspector: EditorInspector = get_editor_interface().get_inspector()
	if inspector and inspector.edited_object_changed.is_connected(_on_edited_object_changed):
		inspector.edited_object_changed.disconnect(_on_edited_object_changed)

	if _panel:
		if _panel.resource_modified.is_connected(_on_resource_modified):
			_panel.resource_modified.disconnect(_on_resource_modified)
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	_panel_button = null


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

func _on_edited_object_changed() -> void:
	if _suppress_edited_object_signal:
		return
	var obj: Object = get_editor_interface().get_inspector().get_edited_object()
	if obj is CustomInputMap:
		_edit_map(obj)


func _edit_map(map: CustomInputMap) -> void:
	if _panel == null or map == null:
		return
	# Same instance already loaded — do not rebuild the tree (avoids lag loops).
	if _panel.edit_map == map and _panel.resource_edit_mode:
		return
	_panel.configure_for_resource(map)
	make_bottom_panel_item_visible(_panel)


func _on_resource_modified(map: CustomInputMap) -> void:
	if map == null:
		return
	# Panel already called emit_changed(). Do not call update_file() here —
	# that rescans the asset, re-fires edited_object_changed, and re-configures
	# the panel in a slow loop.
	#
	# Suppress inspector churn while the editor acknowledges the mutation.
	_suppress_edited_object_signal = true
	# Defer clear so any synchronous inspector callbacks see the flag.
	_clear_suppress.call_deferred()


func _clear_suppress() -> void:
	_suppress_edited_object_signal = false
