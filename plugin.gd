@tool
extends EditorPlugin
## Registers an inspector plugin so [CustomInputMap] resources open the
## InputMapEditor UI instead of a raw Dictionary dump.

const InspectorPluginScript = preload("res://addons/enetheru.input_map_editor/inspector_plugin.gd")

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector_plugin = InspectorPluginScript.new()
	_inspector_plugin.setup(self)
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
