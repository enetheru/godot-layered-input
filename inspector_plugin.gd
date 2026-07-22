@tool
extends EditorInspectorPlugin

## Inspector host mode: embed a dedicated [InputMapEditor] for [CustomInputMap].


const EditorScene = preload( "ui/input_map_editor.tscn" )

var _plugin:EditorPlugin


func setup( plugin:EditorPlugin ) -> void:
	_plugin = plugin


func _can_handle( object:Object ) -> bool:
	if _plugin == null or not _plugin.has_method( &"inspector_can_handle" ):
		return false
	return _plugin.call( &"inspector_can_handle", object ) as bool


func _parse_begin( object:Object ) -> void:
	if _plugin == null or not ( object is CustomInputMap ):
		return

	var wrap:MarginContainer = MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override( &"margin_left", 0 )
	wrap.add_theme_constant_override( &"margin_right", 0 )
	wrap.add_theme_constant_override( &"margin_top", 0 )
	wrap.add_theme_constant_override( &"margin_bottom", 0 )

	var editor:InputMapEditor = EditorScene.instantiate() as InputMapEditor
	editor.resource_edit_mode = true
	editor.apply_edit_map_to_engine = false
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var min_h:float = 280.0
	if _plugin.has_method( &"get_settings_panel_min_height" ):
		min_h = float( _plugin.call( &"get_settings_panel_min_height" ) )
	editor.custom_minimum_size = Vector2( 0.0, min_h )
	editor.configure_for_resource( object as CustomInputMap )

	if _plugin.has_method( &"bind_inspector_editor" ):
		_plugin.call( &"bind_inspector_editor", editor )

	wrap.add_child( editor )
	add_custom_control( wrap )


func _parse_property(
			_object:Object,
			_type:Variant.Type,
			_name:String,
			_hint_type:PropertyHint,
			_hint_string:String,
			_usage_flags:PropertyUsageFlags,
			_wide:bool ) -> bool:
	return true
