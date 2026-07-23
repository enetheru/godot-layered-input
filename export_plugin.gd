@tool
extends EditorExportPlugin

## Skips editor-only / test files listed in [code].exportignore[/code] next to
## this script (same pattern as [code]enetheru.gdtask[/code]).


const Self:Resource = preload( "export_plugin.gd" )

## Addon root with trailing slash (for path matching against export files).
var path_prefix:String = Self.resource_path.get_base_dir() + "/"

## Glob-like patterns loaded from [code].exportignore[/code] for this export.
var ignore_patterns:Array[String] = []


## Export-plugin id shown in the export pipeline.
func _get_name() -> String:
	return "InputMapEditorExportPlugin"


## Reload [member ignore_patterns] from [code].exportignore[/code] at export start.
func _export_begin(
			_features:PackedStringArray,
			_is_debug:bool,
			_path:String,
			_flags:int ) -> void:
	ignore_patterns.clear()
	_load_ignore_file()


func _load_ignore_file() -> void:
	var path:String = path_prefix + ".exportignore"
	if not FileAccess.file_exists( path ):
		return
	var file:FileAccess = FileAccess.open( path, FileAccess.READ )
	if file == null:
		push_error( "InputMapEditorExportPlugin: open .exportignore failed: %s"
				% error_string( FileAccess.get_open_error() ) )
		return
	while not file.eof_reached():
		var line:String = file.get_line().strip_edges()
		if line and not line.begins_with( "#" ):
			ignore_patterns.append( line )


## Skip files matching [member ignore_patterns] under this addon's prefix.
func _export_file(
			path:String,
			_type:String,
			_features:PackedStringArray ) -> void:
	for pattern:String in ignore_patterns:
		var pat:String = pattern
		if pat.begins_with( "./" ):
			pat = pat.trim_prefix( "./" )
		if path.match( pat ) \
		or path.begins_with( path_prefix + pat.trim_suffix( "/" ) ):
			skip()
			return
