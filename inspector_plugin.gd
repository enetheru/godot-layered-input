@tool
extends EditorInspectorPlugin

## When [member InputMapEditorSettings.replace_inspector] is on, handles
## [CustomInputMap] (and nested [InputAction] under the open map) by embedding
## the shared [InputMapEditor] panel and hiding default properties.


var _plugin:EditorPlugin


func setup( plugin:EditorPlugin ) -> void:
	_plugin = plugin


func _can_handle( object:Object ) -> bool:
	if _plugin == null or not _plugin.has_method( &"inspector_can_handle" ):
		return false
	return _plugin.call( &"inspector_can_handle", object ) as bool


func _parse_begin( object:Object ) -> void:
	if _plugin == null or not _plugin.has_method( &"inspector_parse_begin" ):
		return
	_plugin.call( &"inspector_parse_begin", object, self )


func _parse_property(
			_object:Object,
			_type:Variant.Type,
			_name:String,
			_hint_type:PropertyHint,
			_hint_string:String,
			_usage_flags:PropertyUsageFlags,
			_wide:bool ) -> bool:
	# Consume all default properties — the embedded panel is the editor.
	return true
