@tool
extends Object

##[codeblock]
##│ ___      _ _ _       _        _                   _
##│| _ )_  _(_) | |_ ___(_)_ _   | |   ___  __ _ __ _(_)_ _  __ _
##│| _ \ || | | |  _|___| | ' \  | |__/ _ \/ _` / _` | | ' \/ _` |
##│|___/\_,_|_|_|\__|   |_|_||_| |____\___/\__, \__, |_|_||_\__, |
##╰────────────────────────────────────────|___/|___/───────|___/───
##[/codeblock] Addon-local concrete logger for enetheru.gdtask: dump to Godot builtins.
##
## Selected via sibling [code]logging.gd[/code]. No [code]class_name[/code], no
## autoload — each addon tree keeps its own selector + fallback.
##[br][color=goldenrod]TODO[/color]: re-work thsi whole thing so its coherant.
##[br][color=goldenrod]TODO[/color]: should inherit from an abstract base


# TODO flip these so its exclusive blah rather than inclusive blah
enum LogLevel {
	SILENT = 0x00,
	CRITICAL = 0x01,
	ERROR = 0x02,
	WARNING = 0x04,
	NOTICE = 0x08,
	INFO = 0x10,
	DEBUG = 0x20,
	TRACE = 0x40,
	MASK = 0xFF,
	INCLUSIVE_CRITICAL = 0x01,
	INCLUSIVE_ERROR = 0x03,
	INCLUSIVE_WARNING = 0x07,
	INCLUSIVE_NOTICE = 0x0F,
	INCLUSIVE_INFO = 0x1F,
	INCLUSIVE_DEBUG = 0x3F,
	INCLUSIVE_TRACE = 0x7F,
	DEFAULT = NOTICE,
	INCLUSIVE_DEFAULT = INCLUSIVE_NOTICE,
}


static var disabled:bool = false


static func check_level(
			_what_lvl:int = LogLevel.NOTICE,
			_object:Object = null ) -> bool:
	return not disabled


static func get_stack_popped( n:int = 0 ) -> Array:
	var stack:Array = get_stack()
	for _i:int in mini( n + 1, maxi( stack.size() - 1, 0 ) ):
		stack.pop_front()
	return stack


static func printy(
			content:Variant = null,
			args_in:Variant = null,
			object:Object = null,
			indent:String = "",
			_custom_stack:Array = [] ) -> void:
	if disabled:
		return
	var msg:String = indent
	if is_instance_valid( object ):
		msg = ( msg + " " if not msg.is_empty() else "" ) + str( object )
	var body:String = _stringify( content )
	msg = ( msg + " " if not msg.is_empty() else "" ) + body
	if args_in != null:
		msg += " " + _stringify( args_in )
	var head:String = msg.left( 12 ).to_upper()
	if head.begins_with( "CRITICAL" ) or head.begins_with( "ERR" ):
		push_error( msg )
	elif head.begins_with( "WARN" ):
		push_warning( msg )
	else:
		print( msg )


static func trace(
			args:Dictionary = {},
			_stack:Array = [],
			object:Object = null ) -> void:
	printy( args, null, object )


static func plog( _level:int, ...message:Array ) -> void:
	if disabled:
		return
	print( _join_message( message ) )


static func _join_message( message:Array ) -> String:
	var out:String = ""
	for i:int in message.size():
		var piece:String = _stringify( message[i] )
		out = piece if i == 0 else out + " " + piece
	return out


static func _stringify( value:Variant ) -> String:
	if value == null:
		return ""
	if value is String:
		return value
	return str( value )
