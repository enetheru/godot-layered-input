extends Node

## Headless smoke for enetheru.layered-input systems + scene load.
##
## Prefer the scene entry (autoload names resolve after full project boot).
## Point Godot at this scene via its path under the project (or uid).


## Addon root (parent of [code]test/[/code]).
func _addon_dir() -> String:
	var scr:Script = get_script()
	return scr.resource_path.get_base_dir().get_base_dir()


func _ready() -> void:
	var failed:int = 0
	# class_name entries live in ProjectSettings global class list, not only ClassDB.
	failed += _check( "global class CustomInputMap",
			_has_global_class( &"CustomInputMap" ) )
	failed += _check( "global class InputAction",
			_has_global_class( &"InputAction" ) )
	failed += _check( "global class Responder",
			_has_global_class( &"Responder" ) )
	failed += _check( "global class _InputManager",
			_has_global_class( &"_InputManager" ) )

	var map:CustomInputMap = CustomInputMap.new()
	failed += _check( "new CustomInputMap", is_instance_valid( map ) )

	var jump:InputAction = map.add_action( &"smoke_jump", 0.25 )
	failed += _check( "add_action",
			is_instance_valid( jump ) and map.has_action( &"smoke_jump" ) )
	failed += _check( "deadzone",
			is_equal_approx( map.get_action_deadzone( &"smoke_jump" ), 0.25 ) )

	var key:InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	map.add_action_event( &"smoke_jump", key )
	var events:Array[InputEvent] = map.get_action_events( &"smoke_jump" )
	failed += _check( "add_action_event", events.size() == 1 )

	var names:Array[StringName] = []
	for action_name:StringName in map:
		names.append( action_name )
	failed += _check( "CustomInputMap for-in", names.has( &"smoke_jump" ) )

	var event_count:int = 0
	for _ie:InputEvent in jump:
		event_count += 1
	failed += _check( "InputAction for-in", event_count == 1 )

	var other:CustomInputMap = CustomInputMap.new()
	var smoke_use:InputAction = other.add_action( &"smoke_use", 0.2 )
	failed += _check( "add_action returns InputAction", smoke_use != null )
	var key2:InputEventKey = InputEventKey.new()
	key2.keycode = KEY_E
	other.add_action_event( &"smoke_use", key2 )
	map.merge( other, true )
	failed += _check( "merge", map.has_action( &"smoke_use" ) )

	var dup:CustomInputMap = map.duplicate_map()
	failed += _check( "duplicate_map",
			dup.has_action( &"smoke_jump" ) and dup.has_action( &"smoke_use" ) )

	var engine_before:bool = InputMap.has_action( &"smoke_jump" )
	map.apply_to_engine( false )
	failed += _check( "apply_to_engine has action", InputMap.has_action( &"smoke_jump" ) )
	failed += _check( "apply_to_engine events",
			InputMap.action_get_events( &"smoke_jump" ).size() >= 1 )

	var from_engine:CustomInputMap = CustomInputMap.from_engine()
	failed += _check( "from_engine",
			is_instance_valid( from_engine ) and from_engine.has_action( &"smoke_jump" ) )

	var root:String = _addon_dir()
	var default_map:Resource = load(
			root.path_join( "settings/default_input_map.tres" ) )
	failed += _check( "load default_input_map.tres",
			is_instance_valid( default_map ) and default_map is CustomInputMap )

	var editor_scene:PackedScene = load(
			root.path_join( "ui/input_map_editor.tscn" ) ) as PackedScene
	failed += _check( "load input_map_editor.tscn", is_instance_valid( editor_scene ) )
	if is_instance_valid( editor_scene ):
		var editor_node:Node = editor_scene.instantiate()
		failed += _check( "instantiate InputMapEditor", is_instance_valid( editor_node ) )
		if is_instance_valid( editor_node ):
			add_child( editor_node )
			if &"edit_map" in editor_node:
				editor_node.set( &"edit_map", map )
			editor_node.queue_free()

	var dialog_scene:PackedScene = load(
			root.path_join( "ui/event_config_dialog.tscn" ) ) as PackedScene
	failed += _check( "load event_config_dialog.tscn", is_instance_valid( dialog_scene ) )
	if is_instance_valid( dialog_scene ):
		var dialog_node:Node = dialog_scene.instantiate()
		failed += _check( "instantiate EventConfigDialog", is_instance_valid( dialog_node ) )
		if is_instance_valid( dialog_node ):
			dialog_node.free()

	var plugin_script:Script = load(
			root.path_join( "plugin.gd" ) ) as Script
	failed += _check( "load plugin.gd", is_instance_valid( plugin_script ) )

	var key_a:InputEventKey = InputEventKey.new()
	key_a.keycode = KEY_F
	var key_b:InputEventKey = InputEventKey.new()
	key_b.keycode = KEY_F
	failed += _check( "InputAction.compare_event match",
			InputAction.compare_event( key_a, key_b ) )

	var im:Node = get_node_or_null( "/root/InputManager" )
	failed += _check( "InputManager autoload present", is_instance_valid( im ) )
	if is_instance_valid( im ):
		failed += _check( "InputManager.responder_root",
				im.get( &"responder_root" ) != null )
		failed += _check( "InputManager has request_rebuild",
				im.has_method( &"request_rebuild" ) )
		var default_from_mgr:Variant = im.call( &"get_default_input_map" )
		failed += _check( "InputManager.get_default_input_map",
				default_from_mgr is CustomInputMap )

	# Remove smoke actions if we introduced them.
	if not engine_before and InputMap.has_action( &"smoke_jump" ):
		InputMap.erase_action( &"smoke_jump" )
	if InputMap.has_action( &"smoke_use" ):
		InputMap.erase_action( &"smoke_use" )

	# Drop temporary maps so RefCounted events free before quit leak check.
	if is_instance_valid( from_engine ):
		from_engine.clear()
	from_engine = null
	if is_instance_valid( dup ):
		dup.clear()
	dup = null
	if is_instance_valid( other ):
		other.clear()
	other = null
	if is_instance_valid( map ):
		map.clear()
	map = null
	if default_map is CustomInputMap:
		( default_map as CustomInputMap ).clear()
	default_map = null

	# Explicit manager teardown (also runs from InputManager._exit_tree).
	if is_instance_valid( im ) and im.has_method( &"shutdown" ):
		im.call( &"shutdown" )

	if failed == 0:
		print( "SMOKE OK: enetheru.layered-input" )
		get_tree().quit( 0 )
	else:
		push_error( "SMOKE FAIL: %d check(s) failed" % failed )
		get_tree().quit( 1 )


func _check( label:String, ok:bool ) -> int:
	if ok:
		print( "  PASS  ", label )
		return 0
	push_error( "  FAIL  %s" % label )
	return 1


func _has_global_class( class_id:StringName ) -> bool:
	var classes:Array = ProjectSettings.get_global_class_list()
	for entry:Dictionary in classes:
		var entry_class:StringName = entry.get( "class", "" )
		if entry_class == class_id:
			return true
	return false
