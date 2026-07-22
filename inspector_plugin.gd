@tool
extends EditorInspectorPlugin

## Inspector host mode: embed a dedicated [InputMapEditor] for [CustomInputMap].
##
## The inspector is a [ScrollContainer], so SIZE_EXPAND alone will not fill the
## dock. We match the inspector's current height (minus chrome) as min size.
## [method cleanup] disconnects editor signals before the host session detaches.


const EditorScene = preload( "ui/input_map_editor.tscn" )

var _plugin:EditorPlugin
var _wrap:MarginContainer
var _editor:InputMapEditor
var _insp_resized_cb:Callable = Callable()


func setup( plugin:EditorPlugin ) -> void:
	_plugin = plugin


## Called from host detach before [method EditorPlugin.remove_inspector_plugin].
func cleanup() -> void:
	_disconnect_inspector_resized()
	_unbind_editor()
	_wrap = null
	_editor = null
	_plugin = null


func _can_handle( object:Object ) -> bool:
	if _plugin == null or not _plugin.has_method( &"inspector_can_handle" ):
		return false
	return _plugin.call( &"inspector_can_handle", object ) as bool


func _parse_begin( object:Object ) -> void:
	if _plugin == null or not ( object is CustomInputMap ):
		return

	# Re-parse: drop previous bind/resize before building a new control tree.
	_disconnect_inspector_resized()
	_unbind_editor()

	_wrap = MarginContainer.new()
	_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wrap.add_theme_constant_override( &"margin_left", 0 )
	_wrap.add_theme_constant_override( &"margin_right", 0 )
	_wrap.add_theme_constant_override( &"margin_top", 0 )
	_wrap.add_theme_constant_override( &"margin_bottom", 0 )

	_editor = EditorScene.instantiate() as InputMapEditor
	_editor.resource_edit_mode = true
	_editor.apply_edit_map_to_engine = false
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.configure_for_resource( object as CustomInputMap )

	if _plugin.has_method( &"bind_inspector_editor" ):
		_plugin.call( &"bind_inspector_editor", _editor )

	_wrap.add_child( _editor )
	_fit_inspector_height()
	add_custom_control( _wrap )

	var insp:EditorInspector = EditorInterface.get_inspector()
	if insp != null:
		_insp_resized_cb = Callable( self, &"_on_inspector_resized" )
		if not insp.resized.is_connected( _insp_resized_cb ):
			insp.resized.connect( _insp_resized_cb )


func _parse_property(
			_object:Object,
			_type:Variant.Type,
			_name:String,
			_hint_type:PropertyHint,
			_hint_string:String,
			_usage_flags:PropertyUsageFlags,
			_wide:bool ) -> bool:
	return true


func _on_inspector_resized() -> void:
	_fit_inspector_height()


func _fit_inspector_height() -> void:
	if not is_instance_valid( _wrap ) or not is_instance_valid( _editor ):
		return
	var min_h:float = 280.0
	if _plugin != null and _plugin.has_method( &"get_settings_panel_min_height" ):
		min_h = float( _plugin.call( &"get_settings_panel_min_height" ) )
	var insp:EditorInspector = EditorInterface.get_inspector()
	var target:float = min_h
	if insp != null:
		# Leave a little room for inspector chrome / scrollbars.
		target = maxf( min_h, insp.size.y - 48.0 )
	_wrap.custom_minimum_size = Vector2( 0.0, target )
	_editor.custom_minimum_size = Vector2( 0.0, target )
	_editor.panel_min_height = target


func _unbind_editor() -> void:
	if _plugin != null \
	and is_instance_valid( _editor ) \
	and _plugin.has_method( &"unbind_inspector_editor" ):
		_plugin.call( &"unbind_inspector_editor", _editor )
	_editor = null
	_wrap = null


func _disconnect_inspector_resized() -> void:
	if not _insp_resized_cb.is_valid():
		return
	var insp:EditorInspector = EditorInterface.get_inspector()
	if insp != null and insp.resized.is_connected( _insp_resized_cb ):
		insp.resized.disconnect( _insp_resized_cb )
	_insp_resized_cb = Callable()
