@tool
extends EditorInspectorPlugin

## When host mode is Inspector, handles [CustomInputMap] by embedding a
## dedicated [InputMapEditor] instance and hiding the default property list.


const EditorScene = preload( "ui/input_map_editor.tscn" )

var _plugin:EditorPlugin


func setup( plugin:EditorPlugin ) -> void:
	_plugin = plugin


func _can_handle( object:Object ) -> bool:
	if _plugin == null or not _plugin.has_method( &"inspector_can_handle" ):
		return false
	return _plugin.call( &"inspector_can_handle", object ) as bool


func _parse_begin( object:Object ) -> void:
	if _plugin == null:
		return
	# Dedicated instance — do not reparent the bottom/main panel (that was
	# covering the whole editor when size flags went wrong).
	var editor:InputMapEditor = EditorScene.instantiate() as InputMapEditor
	editor.resource_edit_mode = true
	editor.apply_edit_map_to_engine = false
	var min_h:float = 280.0
	if _plugin.has_method( &"get_settings_panel_min_height" ):
		min_h = float( _plugin.call( &"get_settings_panel_min_height" ) )
	editor.custom_minimum_size = Vector2( 0.0, min_h )
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Do not expand vertically to fill the whole dock past content + min size.
	editor.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if object is CustomInputMap:
		editor.configure_for_resource( object as CustomInputMap )
	elif object is InputAction and _plugin.has_method( &"inspector_map_for_action" ):
		var map:CustomInputMap = _plugin.call(
				&"inspector_map_for_action", object ) as CustomInputMap
		if map != null:
			editor.configure_for_resource( map )

	if _plugin.has_method( &"bind_inspector_editor" ):
		_plugin.call( &"bind_inspector_editor", editor )

	add_custom_control( editor )


func _parse_property(
			_object:Object,
			_type:Variant.Type,
			_name:String,
			_hint_type:PropertyHint,
			_hint_string:String,
			_usage_flags:PropertyUsageFlags,
			_wide:bool ) -> bool:
	# Hide default property drawers; the embedded editor is the UI.
	return true
