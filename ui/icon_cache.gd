class_name IconCache
extends RefCounted

## Shared textures for [InputMapEditor] / [EventConfigDialog].
##
## Prefers project icons when present; otherwise builds [DPITexture] fallbacks
## from the same SVGs the engine editor uses.
##[br][color=goldenrod]TODO[/color]:Replace INVALID_KEY svg with a real mark.


const _COLOR_MAP:Dictionary = {
	Color( 1, 0.37254903, 0.37254903, 1 ): Color( 1, 0.47, 0.42, 1 ),
	Color( 0.37254903, 1, 0.5921569, 1 ): Color( 0.45, 0.95, 0.5, 1 ),
	Color( 1, 0.8666667, 0.39607844, 1 ): Color( 0.83, 0.78, 0.62, 1 ),
}

const SVG:Dictionary = {
	&"ADD": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"m7 1v6h-6v2h6v6h2v-6h6v-2h-6v-6z\"/></svg>",
	&"REMOVE": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M5 1v1H2v2h1v9a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V4h1V2h-3V1zm2 2h2v1H7zm-2 3h1v7H5zm3 0h1v7H8zm3 0h1v7h-1z\"/></svg>",
	&"EDIT": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M12.586 1.586a2 2 0 0 1 2.828 2.828l-9.9 9.9L2 15l.686-3.514zM11.5 3.5l1 1L4.914 12.086l-1-1z\"/></svg>",
	&"RELOAD": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M8 2a6 6 0 1 0 5.65 4H11.5A4 4 0 1 1 8 4V2zm0 0V0l3 2.5L8 5V2z\"/></svg>",
	&"KEYBOARD": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M6.584 5.135 6.17 4.059l-.412 1.076h.826zm3.203 2.976a.95 1.06 0 0 0 0 2.14.95 1.06 0 0 0 0-2.14zM4 2a1 1 0 0 0-1 1v9a1 1 0 0 0 .995 1h8a1 1 0 0 0 1-1V3A1 1 0 0 0 12 2.007H4Zm1.475.646H6.89l1.865 4.27H7.268l-.286-.744H5.36l-.287.744H3.61l1.866-4.27Zm2.939 8.401a2.42 2.24 0 1 1 2.41.168c.296.465.837-.109 1.06-.007l.544.642c-.64.756-1.883.677-2.605.084-.394-.448-.866-.673-1.409-.887ZM1 4v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4h-1v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V4Z\"/></svg>",
	&"KEYBOARD_PHYSICAL": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M4 2a1 1 0 0 0-1 1v9a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V3a1 1 0 0 0-1-1ZM1 4v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4h-1v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V4Zm5.762-.232h2.476l3.264 7.464H9.898l-.502-1.3H6.561l-.502 1.3H3.498Zm1.217 2.474L7.254 8.12h1.45z\"/></svg>",
	&"KEYBOARD_LABEL": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M4 1.977a1 1 0 0 0-1 1v9a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1zm5.8 2 .58.58-.58.58-.58-.58zm-.6 1 .6.6-.6.6-.6-.6zm1.2 0 .6.6-.6.6-.6-.6zm.717 1.436h1.06c.053.217.093.428.122.63.028.201.043.395.043.58a2.363 2.363 0 0 1-.133.724 1.425 1.425 0 0 1-.31.515c-.249.265-.598.399-1.05.399-.331 0-.594-.08-.785-.235a1.091 1.091 0 0 1-.236-.275c-.063.1-.14.19-.236.265-.206.163-.467.245-.787.245-.252 0-.457-.057-.614-.166a2.75 2.75 0 0 1-.095.42 1.936 1.936 0 0 1-.403.722c-.2.22-.452.383-.756.49-.303.11-.654.166-1.052.166-.466 0-.865-.089-1.2-.265a1.817 1.817 0 0 1-.765-.752c-.18-.327-.27-.715-.27-1.164 0-.256.027-.525.082-.809.055-.284.126-.545.21-.781h1.001c-.062.232-.112.46-.15.684a3.87 3.87 0 0 0-.053.613c0 .37.1.643.3.82.204.177.523.264.96.264.222 0 .425-.03.61-.092a.97.97 0 0 0 .439-.299.803.803 0 0 0 .166-.521 5.463 5.463 0 0 0-.051-.725 11.61 11.61 0 0 0-.068-.482A26.51 26.51 0 0 0 7 6.778h1.135l.043.276c.047.32.123.532.228.634.105.1.24.15.402.15.165 0 .284-.04.358-.124.076-.086.115-.224.115-.412v-.524h1.027v.524c0 .203.032.351.096.447.065.095.202.142.412.142a.637.637 0 0 0 .33-.078c.089-.052.133-.15.133-.297 0-.128-.019-.295-.054-.498zM1 4v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4h-1v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V4z\"/></svg>",
	&"MOUSE": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M8 1a5 5 0 0 0-5 5v4a5 5 0 0 0 10 0V6a5 5 0 0 0-5-5zm-1 2.1A3 3 0 0 1 10 6v1H7zm-1 .9v1H5A3 3 0 0 1 6 4zm2 3h3v3a3 3 0 0 1-6 0V7h3z\"/></svg>",
	&"JOY_BUTTON": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M5 4a4 4 0 0 0-4 4v1a3 3 0 0 0 3 3h1l1 3h4l1-3h1a3 3 0 0 0 3-3V8a4 4 0 0 0-4-4zm1 3h1v1H6zm3 0h1v1H9zM4.5 8.5A1.5 1.5 0 1 1 4.5 11a1.5 1.5 0 0 1 0-2.5zm7 0A1.5 1.5 0 1 1 11.5 11a1.5 1.5 0 0 1 0-2.5z\"/></svg>",
	&"JOY_AXIS": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1zm0 2a5 5 0 1 1 0 10A5 5 0 0 1 8 3zm0 2a3 3 0 1 0 0 6 3 3 0 0 0 0-6z\"/></svg>",
	&"INVALID_KEY": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><path fill=\"#e0e0e0\" d=\"M8 2a6 6 0 1 0 5.65 4H11.5A4 4 0 1 1 8 4V2zm0 0V0l3 2.5L8 5V2z\"/></svg>",
}


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

# StringName -> Texture2D
static var _cache:Dictionary = {}
# String -> Texture2D
static var _sized_cache:Dictionary = {}


#        ███████ ████████  █████  ████████ ██  ██████                          #
#        ██         ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ███████    ██    ██ ██                               #
#             ██    ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ██   ██    ██    ██  ██████                          #
func                        _________STATIC__________              ()->void:pass

static func get_icon( cache_key:StringName ) -> Texture2D:
	if _cache.has( cache_key ):
		return _cache[cache_key]

	var svg:String = SVG.get( cache_key, SVG[&"INVALID_KEY"] )
	var tex:Texture2D = DPITexture.create_from_string( svg, 1.25, 2.0, _COLOR_MAP )

	_cache[cache_key] = tex
	return tex


## Resize or size-override [param source] so [method Texture2D.get_size]
## matches [param size].
static func at_size( source:Texture2D, size:Vector2i ) -> Texture2D:
	if source == null:
		return null
	if size.x <= 0 or size.y <= 0:
		return source
	var source_size:Vector2 = source.get_size()
	if int( source_size.x ) == size.x and int( source_size.y ) == size.y:
		return source

	var key:String = "%s@%dx%d" % [str( source.get_rid().get_id() ), size.x, size.y]
	if _sized_cache.has( key ):
		return _sized_cache[key]

	var tex:Texture2D
	var img:Image = source.get_image()
	if img != null and not img.is_empty():
		var copy:Image = img.duplicate()
		copy.resize( size.x, size.y, Image.INTERPOLATE_LANCZOS )
		tex = ImageTexture.create_from_image( copy )
	else:
		# DPITexture / compressed sources may not expose pixels.
		var fallback:ImageTexture = ImageTexture.new()
		if img != null and not img.is_empty():
			fallback.set_image( img )
		else:
			var blank:Image = Image.create( size.x, size.y, false, Image.FORMAT_RGBA8 )
			blank.fill( Color( 1, 1, 1, 0.4 ) )
			fallback.set_image( blank )
		fallback.set_size_override( size )
		tex = fallback

	_sized_cache[key] = tex
	return tex


static func for_event( event:InputEvent ) -> Texture2D:
	if event is InputEventKey:
		var key:InputEventKey = event
		if key.physical_keycode == KEY_NONE \
		and key.keycode == KEY_NONE \
		and key.key_label != KEY_NONE:
			return get_icon( &"KEYBOARD_LABEL" )
		if key.keycode != KEY_NONE:
			return get_icon( &"KEYBOARD" )
		if key.physical_keycode != KEY_NONE:
			return get_icon( &"KEYBOARD_PHYSICAL" )
		return get_icon( &"KEYBOARD" )
	if event is InputEventMouseButton:
		return get_icon( &"MOUSE" )
	if event is InputEventJoypadButton:
		return get_icon( &"JOY_BUTTON" )
	if event is InputEventJoypadMotion:
		return get_icon( &"JOY_AXIS" )
	return get_icon( &"KEYBOARD" )
