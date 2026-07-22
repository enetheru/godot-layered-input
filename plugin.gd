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
		var cim:CustomInputMap = obj
		_edit_map( cim )


func _on_resource_modified( map:CustomInputMap ) -> void:
	if map == null:
		return
	# Panel already called emit_changed(). Do not call update_file() here —
	# that rescans the asset, re-fires edited_object_changed, and re-configures
	# the panel in a slow loop.
	_suppress_edited_object_signal = true
	# Defer clear so any synchronous inspector callbacks see the flag.
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


func _clear_suppress() -> void:
	_suppress_edited_object_signal = false


# Connect and report failures (Signal.connect returns Error).
func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags )
	if err != OK:
		push_error( "InputMapEditorPlugin._connect_sig: %s" % error_string( err ) )
