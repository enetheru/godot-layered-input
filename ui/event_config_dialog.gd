@tool
class_name EventConfigDialog
extends PopupPanel

##[codeblock]
##│ ___             _      ___           __ _        ___  _      _
##│| __|_ _____ _ _| |_   / __|___ _ _  / _(_)__ _  |   \(_)__ _| |___  __ _
##│| _|\ V / -_) ' \  _| | (__/ _ \ ' \|  _| / _` | | |) | / _` | / _ \/ _` |
##│|___|\_/\___|_||_\__|  \___\___/_||_|_| |_\__, | |___/|_\__,_|_\___/\__, |
##╰──────────────────────────────────────────|___/─────────────────────|___/───
##[/codeblock]Configure a single [InputEvent] for an action binding.
##
## Port of Godot's `InputEventConfigurationDialog`
## (editor/settings/input_event_configuration_dialog.*).
## Scene nodes mirror the editor layout; OK/Cancel replace ConfirmationDialog.
## [br]Open with [method popup_and_configure], read the result from
## [signal confirmed] or [method get_event]. Restrict device kinds with
## [method set_allowed_input_types].

# Window fires this after popup (window.cpp); not BIND_CONSTANT'd for GDScript.
const NOTIFICATION_POST_POPUP:int = 31

## Manual selection [Tree] columns (single label column today).
enum Column {
	LABEL = 0,
}

enum KeyMode {
	KEYCODE = 0,
	PHY_KEYCODE = 1,
	UNICODE = 2,
}

enum ModCheckbox {
	ALT = 0,
	SHIFT = 1,
	CTRL = 2,
	META = 3,
	MAX = 4,
}


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Size passed to [method Window.popup_centered] when opening the dialog.
@export var popup_size:Vector2i = Vector2i( 661, 400 )

@onready var event_lbl:Label = $VBoxContainer/VBoxContainer/EventLabel
@onready var event_listener_edit:EventListenerLineEdit = $VBoxContainer/VBoxContainer/EventListenerLineEdit

@onready var filter_input_le:LineEdit = $VBoxContainer/VBoxContainer/ManualSelection/FilterInputLineEdit
@onready var input_tree:Tree = $VBoxContainer/VBoxContainer/ManualSelection/MarginContainer/Tree

@onready var additional_options_vbox:VBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions
@onready var device_hbox:HBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions/DeviceHBox
@onready var device_opt:OptionButton = $VBoxContainer/VBoxContainer/AdditionalOptions/DeviceHBox/OptionButton

@onready var mod_hbox:HBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer
@onready var alt_cb:CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Alt
@onready var shift_cb:CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Shift
@onready var ctrl_cb:CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Ctrl
@onready var windows_cb:CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Windows
@onready var command_control_cb:CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/CommandControl

@onready var key_mode_opt:OptionButton = $VBoxContainer/VBoxContainer/AdditionalOptions/OptionButton
@onready var location_hbox:HBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions/PhysicalLocation
@onready var location_opt:OptionButton = $VBoxContainer/VBoxContainer/AdditionalOptions/PhysicalLocation/OptionButton

@onready var error_lbl:Label = $VBoxContainer/VBoxContainer/Error
@onready var ok_btn:Button = $VBoxContainer/OKCancel/OK
@onready var cancel_btn:Button = $VBoxContainer/OKCancel/Cancel

## Working binding being edited (not EventListenerLineEdit's capture buffer).
var _configured_event:InputEvent

var _original_event:InputEvent

var _action_events:Array = []

var _allowed_input_types:int = EventListenerLineEdit.ALL_INPUT_TYPES

## Coalesce manual-picker rebuilds (same idea as InputManager.request_rebuild).
var _want_input_list_update:bool = false

## At most one deferred apply is queued for manual-list picks.
## [member _pending_list_item] is the intent; cleared to cancel (e.g. highlight-from-match).
var _want_list_selection:bool = false
var _pending_list_item:TreeItem = null

# Coalesce focus-to-listener requests; async sequence may span a process frame.
var _want_focus_listener:bool = false
var _focus_listener_running:bool = false

var _mod_checkboxes:Array[CheckBox] = []


#            ███████ ██  ██████  ███    ██  █████  ██      ███████             #
#            ██      ██ ██       ████   ██ ██   ██ ██      ██                  #
#            ███████ ██ ██   ███ ██ ██  ██ ███████ ██      ███████             #
#                 ██ ██ ██    ██ ██  ██ ██ ██   ██ ██           ██             #
#            ███████ ██  ██████  ██   ████ ██   ██ ███████ ███████             #
func                        _________SIGNALS_________              ()->void:pass

## User accepted the dialog. [param event] is the configured binding (never null).
signal confirmed( event:InputEvent )

## User dismissed the dialog without accepting (Cancel, window close, or Escape).
signal canceled


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_listen_input_changed( event:InputEvent ) -> void:
	# Listener already filters press/echo/allowed; re-check for clear_event(null)
	# and so this handler does not depend on that path alone (engine does the same).
	if not is_instance_valid( event ) \
	or event.is_echo() \
	or not event.is_pressed():
		return

	var type:int = _input_type_for_event( event )
	if type == 0 or ( _allowed_input_types & type ) == 0:
		return

	# Snapshot full capture for key-mode switching; then normalize the live event
	# in place (same Ref the listener holds — engine port does this too).
	var original:InputEvent = event.duplicate()
	match type:
		EventListenerLineEdit.InputType.JOY_MOTION:
			var jm:InputEventJoypadMotion = event
			jm.axis_value = signf( jm.axis_value )
		EventListenerLineEdit.InputType.KEY:
			var k:InputEventKey = event
			# Avoid serializing pressed; actions ignore it.
			k.pressed = false
			_apply_selected_key_mode( k )
			if location_opt.get_selected_id() == KEY_LOCATION_UNSPECIFIED:
				k.location = KEY_LOCATION_UNSPECIFIED

	if event is InputEventWithModifiers:
		var mod:InputEventWithModifiers = event
		mod.window_id = 0

	event.device = _get_current_device()
	_set_event( event, original )


func _on_search_term_updated( _term:String = "" ) -> void:
	_request_input_list_update()


func _on_input_list_item_activated() -> void:
	var selected:TreeItem = input_tree.get_selected()
	if selected:
		selected.collapsed = not selected.collapsed


func _on_input_list_item_selected() -> void:
	# Record intent only; apply at idle time so highlight-from-match can cancel.
	_pending_list_item = input_tree.get_selected()
	_request_list_selection_apply()


func _on_mod_toggled( pressed:bool, index:int ) -> void:
	if not (_configured_event is InputEventWithModifiers):
		return
	var ie:InputEventWithModifiers = _configured_event
	match index:
		ModCheckbox.ALT:
			ie.alt_pressed = pressed
		ModCheckbox.SHIFT:
			ie.shift_pressed = pressed
		ModCheckbox.CTRL:
			if not command_control_cb.button_pressed:
				ie.ctrl_pressed = pressed
		ModCheckbox.META:
			if not command_control_cb.button_pressed:
				ie.meta_pressed = pressed
	_set_event( ie, _original_event )


func _on_autoremap_command_or_control_toggled( pressed:bool ) -> void:
	if _configured_event is InputEventWithModifiers:
		var ie:InputEventWithModifiers = _configured_event
		ie.command_or_control_autoremap = pressed
		_set_event( _configured_event, _original_event )
	ctrl_cb.visible = not pressed
	windows_cb.visible = not pressed


func _on_key_mode_selected( _idx:int ) -> void:
	if not (_configured_event is InputEventKey) \
	or not (_original_event is InputEventKey):
		return

	var ie :InputEventKey = _configured_event
	var oie :InputEventKey = _original_event
	match key_mode_opt.get_selected_id():
		KeyMode.KEYCODE:
			ie.keycode = oie.keycode
			ie.physical_keycode = KEY_NONE
			ie.key_label = KEY_NONE
		KeyMode.PHY_KEYCODE:
			ie.keycode = KEY_NONE
			ie.physical_keycode = oie.physical_keycode
			ie.key_label = KEY_NONE
		KeyMode.UNICODE:
			ie.physical_keycode = KEY_NONE
			ie.keycode = KEY_NONE
			ie.key_label = oie.key_label
	_set_event( ie, _original_event )


func _on_key_location_selected( _idx:int ) -> void:
	if not (_configured_event is InputEventKey):
		return
	var ie:InputEventKey = _configured_event
	ie.location = location_opt.get_selected_id() as KeyLocation
	_set_event( ie, _original_event )


func _on_device_selection_changed( option_index:int ) -> void:
	if is_instance_valid( _configured_event ):
		_configured_event.device = option_index - 1
		event_lbl.text = EventListenerLineEdit.get_event_text( _configured_event, true )


func _on_ok_pressed() -> void:
	_sync_ok_enabled()
	if not is_instance_valid( _configured_event ):
		if is_instance_valid( error_lbl ):
			error_lbl.text = "No event configured. Listen for input or pick one from the list."
			error_lbl.show()
		return
	if ok_btn.disabled:
		return
	# Pass the event so listeners need not call get_event() after hide.
	confirmed.emit( _configured_event )
	hide()


func _on_cancel_pressed() -> void:
	canceled.emit()
	hide()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _ready() -> void:
	visible = false
	hide()

	_mod_checkboxes = [alt_cb, shift_cb, ctrl_cb, windows_cb]

	_connect_sig( event_listener_edit.event_changed, _on_listen_input_changed )
	_connect_sig( filter_input_le.text_changed, _on_search_term_updated )
	_connect_sig( input_tree.item_activated, _on_input_list_item_activated )
	_connect_sig( input_tree.item_selected, _on_input_list_item_selected )
	_connect_sig( device_opt.item_selected, _on_device_selection_changed )
	_connect_sig( alt_cb.toggled, _on_mod_toggled.bind( ModCheckbox.ALT ) )
	_connect_sig( shift_cb.toggled, _on_mod_toggled.bind( ModCheckbox.SHIFT ) )
	_connect_sig( ctrl_cb.toggled, _on_mod_toggled.bind( ModCheckbox.CTRL ) )
	_connect_sig( windows_cb.toggled, _on_mod_toggled.bind( ModCheckbox.META ) )
	_connect_sig( command_control_cb.toggled, _on_autoremap_command_or_control_toggled )
	_connect_sig( key_mode_opt.item_selected, _on_key_mode_selected )
	_connect_sig( location_opt.item_selected, _on_key_location_selected )
	_connect_sig( ok_btn.pressed, _on_ok_pressed )
	_connect_sig( cancel_btn.pressed, _on_cancel_pressed )
	_connect_sig( close_requested, _on_cancel_pressed )

	# Device list: index 0 = All Devices (-1), then 0..7
	device_opt.clear()
	for i:int in range(-1, 8):
		device_opt.add_item(
				EventListenerLineEdit.get_device_string( i ) )

	# Key-mode icons (engine sets these from EditorIcons).
	if key_mode_opt.item_count >= 3:
		key_mode_opt.set_item_icon( KeyMode.KEYCODE, IconCache.get_icon(&"KEYBOARD") )
		key_mode_opt.set_item_icon( KeyMode.PHY_KEYCODE, IconCache.get_icon(&"KEYBOARD_PHYSICAL") )
		key_mode_opt.set_item_icon( KeyMode.UNICODE, IconCache.get_icon(&"KEYBOARD_LABEL") )

	_update_input_list()
	additional_options_vbox.hide()
	error_lbl.hide()


func _notification(what:int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED when visible:
			_focus_listener()
		NOTIFICATION_POST_POPUP:
			_focus_listener()
		NOTIFICATION_WM_WINDOW_FOCUS_IN when visible:
			# Editor may hand window focus to the popup without focusing a child control.
			_focus_listener()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Binding currently shown in the dialog (also emitted on [signal confirmed]).
## Null when nothing is configured yet or after a blank open.
func get_event() -> InputEvent:
	return _configured_event


## Bitmask of [enum EventListenerLineEdit.InputType] values accepted from the
## listener and the manual list. Defaults to all types.
func set_allowed_input_types( type_masks:int ) -> void:
	_allowed_input_types = type_masks
	if is_instance_valid( event_listener_edit ):
		event_listener_edit.set_allowed_input_types( type_masks )


## Open centered to edit [param event], or blank when [param event] is null.
## [param current_action_name] is shown in the window title when non-empty.
## [param current_action] should be
## [code]{"events": Array, "deadzone": float}[/code] so the dialog can flag
## duplicates against other bindings on the same action (the event being edited
## is excluded from that list).
func popup_and_configure(
			event:InputEvent = null,
			current_action_name:String = "",
			current_action:Dictionary = {} ) -> void:
	var events:Array = current_action.get( "events", [] )
	_action_events = events.duplicate()

	if is_instance_valid( event ):
		# Drop one matching instance so the event being edited is not
		# immediately flagged as a duplicate of itself.
		var ie:InputEvent
		for i:int in range( _action_events.size() ):
			ie = _action_events[i]
			if is_instance_valid( ie ) \
			and ie.is_match( event ):
				_action_events.remove_at( i )
				break
		ie = event.duplicate()
		var og_ie:InputEvent = event.duplicate()
		_set_event( ie, og_ie )
	else:
		_reset_configure_ui()

	if current_action_name.is_empty():
		title = "Event Configuration"
	else:
		title = 'Event Configuration for "%s"' % current_action_name

	# Bottom-panel parents can clip / break Window popups in the editor.
	# Transient + exclusive keeps the dialog on top of the editor chrome.
	if Engine.is_editor_hint():
		transient = true
		exclusive = true
		unresizable = false
	# Prefer the listener over any other focusable child when the window opens.
	if is_instance_valid( event_listener_edit ):
		event_listener_edit.focus_mode = Control.FOCUS_ALL
	popup_centered( popup_size )
	# Ensure OK reflects current event (null → disabled).
	_sync_ok_enabled()
	_focus_listener()


## Clear binding + option controls for a blank “add event” open.
func _reset_configure_ui() -> void:
	_set_event( null, null )
	for cb:CheckBox in _mod_checkboxes:
		cb.set_pressed_no_signal( false )
	key_mode_opt.select( KeyMode.PHY_KEYCODE )
	command_control_cb.set_pressed_no_signal( false )
	device_opt.select( 0 )
	location_opt.select( 0 )


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

# Request focus on the listen field. Coalesced; runs an idle grab then one
# process-frame retry (editor popups often are not focus-ready mid-notification).
func _focus_listener() -> void:
	if not is_instance_valid( event_listener_edit ):
		return
	_want_focus_listener = true
	if _focus_listener_running:
		return
	_focus_listener_running = true
	_run_focus_listener()


func _run_focus_listener() -> void:
	while _want_focus_listener:
		_want_focus_listener = false
		if not visible \
		or not is_instance_valid( event_listener_edit ):
			break
		# Idle-time first attempt (manual_grab_focus: LineEdit.grab_focus is final).
		event_listener_edit.call_deferred( &"manual_grab_focus" )
		if not is_inside_tree():
			break
		await get_tree().process_frame
		if not visible \
		or not is_instance_valid( event_listener_edit ):
			break
		if not event_listener_edit.has_focus():
			event_listener_edit.manual_grab_focus()
	_focus_listener_running = false


func _set_event(
			event:InputEvent,
			original_event:InputEvent,
			update_input_list_selection:bool = true ) -> void:
	if not is_instance_valid( event ):
		_clear_configured_event_ui()
		return
	if _try_confirm_or_cancel_shortcut( event ):
		return

	var listener_event:InputEvent = event_listener_edit.get_event()
	if is_instance_valid( listener_event ) \
	and not listener_event.is_match( event ):
		event_listener_edit.clear_event()

	_configured_event = event
	_original_event = original_event
	event_lbl.text = EventListenerLineEdit.get_event_text( _configured_event, true )
	_sync_ok_enabled()

	if not _sync_options_from_event( event, original_event ):
		_clear_configured_event_ui()
		return

	if update_input_list_selection:
		_select_matching_input_list_item( event )


## Bare Enter confirms / Escape cancels while listening with a binding set.
func _try_confirm_or_cancel_shortcut( event:InputEvent ) -> bool:
	if not is_instance_valid( _configured_event ) \
	or not visible \
	or not event_listener_edit.has_focus():
		return false
	if not ( event is InputEventKey ):
		return false
	var ie:InputEventKey = event
	if ie.get_modifiers_mask() != 0:
		return false
	if ie.physical_keycode == KEY_ENTER or ie.keycode == KEY_ENTER:
		_on_ok_pressed()
		return true
	if ie.physical_keycode == KEY_ESCAPE or ie.keycode == KEY_ESCAPE:
		_on_cancel_pressed()
		return true
	return false


## Update additional-options UI from [param event]. Returns false if the event
## is an empty/invalid key binding and the UI was cleared.
func _sync_options_from_event(
			event:InputEvent,
			original_event:InputEvent ) -> bool:
	var show_mods:bool = false
	var show_device:bool = false
	var show_key:bool = false
	var show_location:bool = false

	if event is InputEventWithModifiers:
		show_mods = true
		var mod:InputEventWithModifiers = event
		alt_cb.set_pressed_no_signal( mod.alt_pressed )
		shift_cb.set_pressed_no_signal( mod.shift_pressed )
		ctrl_cb.set_pressed_no_signal( mod.ctrl_pressed )
		windows_cb.set_pressed_no_signal( mod.meta_pressed )
		command_control_cb.set_pressed_no_signal( mod.command_or_control_autoremap )

	if event is InputEventKey:
		show_key = true
		var k:InputEventKey = event
		var phys_key:Key = k.physical_keycode
		if k.keycode == KEY_NONE \
		and phys_key == KEY_NONE \
		and k.key_label != KEY_NONE:
			key_mode_opt.select( KeyMode.UNICODE )
		elif k.keycode != KEY_NONE:
			key_mode_opt.select( KeyMode.KEYCODE )
		elif phys_key != KEY_NONE:
			key_mode_opt.select( KeyMode.PHY_KEYCODE )
			if phys_key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
				location_opt.select( k.location )
				show_location = true
		else:
			return false
	elif event is InputEventJoypadButton \
	or event is InputEventJoypadMotion \
	or event is InputEventMouseButton:
		show_device = true
		_set_current_device( event.device )

	mod_hbox.visible = show_mods
	device_hbox.visible = show_device
	key_mode_opt.visible = show_key
	location_hbox.visible = show_location
	additional_options_vbox.show()

	if original_event is InputEventKey:
		var orig:InputEventKey = original_event
		key_mode_opt.set_item_disabled( KeyMode.KEYCODE, orig.keycode == KEY_NONE )
		key_mode_opt.set_item_disabled( KeyMode.PHY_KEYCODE, orig.physical_keycode == KEY_NONE )
		key_mode_opt.set_item_disabled( KeyMode.UNICODE, orig.key_label == KEY_NONE )
	return true


func _clear_configured_event_ui() -> void:
	_configured_event = null
	_original_event = null
	event_listener_edit.clear_event()
	event_lbl.text = "No Event Configured"
	additional_options_vbox.hide()
	input_tree.deselect_all()
	_update_input_list()
	_sync_ok_enabled()


## Zero unused keycode fields according to the key-mode option button.
func _apply_selected_key_mode( ie:InputEventKey ) -> void:
	match key_mode_opt.get_selected_id():
		KeyMode.KEYCODE:
			ie.physical_keycode = KEY_NONE
			ie.key_label = KEY_NONE
		KeyMode.PHY_KEYCODE:
			ie.keycode = KEY_NONE
			ie.key_label = KEY_NONE
		KeyMode.UNICODE:
			ie.physical_keycode = KEY_NONE
			ie.keycode = KEY_NONE


## Flag a manual-picker rebuild; at most one [method Object.call_deferred] is queued.
## Runs at idle time (end of process/physics frames), not “next frame”.
func _request_input_list_update() -> void:
	if _want_input_list_update:
		return
	_want_input_list_update = true
	_update_input_list.call_deferred()


## Flag a manual-list pick; at most one [method Object.call_deferred] is queued.
## Runs at idle time (end of process/physics frames), not “next frame”.
func _request_list_selection_apply() -> void:
	if _want_list_selection:
		return
	_want_list_selection = true
	_apply_list_selection.call_deferred()


## Apply [member _pending_list_item] as the configured binding (user pick only).
func _apply_list_selection() -> void:
	_want_list_selection = false
	var selected:TreeItem = _pending_list_item
	_pending_list_item = null
	if not is_instance_valid( selected ) \
	or selected.has_meta( &"__type" ):
		return

	var input_type:int = selected.get_parent().get_meta( &"__type" )
	match input_type:
		EventListenerLineEdit.InputType.KEY:
			var keycode:Key = selected.get_meta( &"__keycode" )
			var ie:InputEventKey = InputEventKey.new()
			ie.physical_keycode = keycode
			ie.keycode = keycode
			ie.key_label = keycode
			_apply_mod_checkboxes( ie )
			# Manual pick: UNICODE mode needs a key_label-only event; default to physical.
			if key_mode_opt.get_selected_id() == KeyMode.UNICODE:
				key_mode_opt.select( KeyMode.PHY_KEYCODE )
			var dup:InputEventKey = ie.duplicate()
			_apply_selected_key_mode( ie )
			_set_event( ie, dup, false )

		EventListenerLineEdit.InputType.MOUSE_BUTTON:
			var ie:InputEventMouseButton = InputEventMouseButton.new()
			ie.button_index = selected.get_meta( &"__index" )
			_apply_mod_checkboxes( ie )
			ie.device = _get_current_device()
			_set_event( ie, ie, false )

		EventListenerLineEdit.InputType.JOY_BUTTON:
			var ie:InputEventJoypadButton = InputEventJoypadButton.new()
			ie.button_index = selected.get_meta( &"__index" )
			ie.device = _get_current_device()
			_set_event( ie, ie, false )

		EventListenerLineEdit.InputType.JOY_MOTION:
			var ie:InputEventJoypadMotion = InputEventJoypadMotion.new()
			ie.axis = selected.get_meta( &"__axis" )
			ie.axis_value = selected.get_meta( &"__value" )
			ie.device = _get_current_device()
			_set_event( ie, ie, false )


# I dont like how much repetition this function looks like, but it might be
# necessary
func _update_input_list() -> void:
	_want_input_list_update = false
	# Tree items are freed; drop any pending pick that pointed into the old tree.
	_pending_list_item = null
	if not is_instance_valid( input_tree ):
		return
	input_tree.clear()
	var root:TreeItem = input_tree.create_item()
	var search_term:String = filter_input_le.text
	var collapse:bool = search_term.is_empty()

	if (_allowed_input_types & EventListenerLineEdit.InputType.KEY):
		var kb_root:TreeItem = input_tree.create_item( root )
		# Column 0 - Name + Icon
		kb_root.set_text( Column.LABEL, "Keyboard Keys" )
		kb_root.set_icon( Column.LABEL, IconCache.get_icon( &"KEYBOARD" ) )
		kb_root.set_collapsed( collapse )
		kb_root.set_meta( &"__type", EventListenerLineEdit.InputType.KEY )
		# filter() is fine here: short list, editor-only rebuilds.
		for keycode:int in _keyboard_keycodes().filter(
				_keycode_matches_search.bind( search_term ) ):
			var item:TreeItem = input_tree.create_item( kb_root )
			item.set_text( Column.LABEL, OS.get_keycode_string( keycode ) )
			item.set_meta( &"__keycode", keycode )

	if (_allowed_input_types & EventListenerLineEdit.InputType.MOUSE_BUTTON):
		var mouse_root:TreeItem = input_tree.create_item( root )
		mouse_root.set_text( Column.LABEL, "Mouse Buttons" )
		mouse_root.set_icon( Column.LABEL, IconCache.get_icon( &"MOUSE" ) )
		mouse_root.set_collapsed( collapse )
		mouse_root.set_meta( &"__type", EventListenerLineEdit.InputType.MOUSE_BUTTON )
		var mouse_buttons:Array[int] = [
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
			MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
		]
		for btn:int in mouse_buttons:
			var mb:InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = btn as MouseButton
			var desc:String = EventListenerLineEdit.get_event_text( mb, false )
			if not _matches_search( desc, search_term ):
				continue
			var item:TreeItem = input_tree.create_item( mouse_root )
			item.set_text( Column.LABEL, desc )
			item.set_meta( &"__index", btn )

	if (_allowed_input_types & EventListenerLineEdit.InputType.JOY_BUTTON):
		var joyb_root:TreeItem = input_tree.create_item( root )
		joyb_root.set_text( Column.LABEL, "Joypad Buttons" )
		joyb_root.set_icon( Column.LABEL, IconCache.get_icon( &"JOY_BUTTON" ) )
		joyb_root.set_collapsed( collapse )
		joyb_root.set_meta( &"__type", EventListenerLineEdit.InputType.JOY_BUTTON )
		for i:int in range( JoyButton.JOY_BUTTON_MAX ):
			var joyb:InputEventJoypadButton = InputEventJoypadButton.new()
			joyb.button_index = i as JoyButton
			var desc:String = EventListenerLineEdit.get_event_text( joyb, false )
			if not _matches_search( desc, search_term ):
				continue
			var item:TreeItem = input_tree.create_item( joyb_root )
			item.set_text( Column.LABEL, desc )
			item.set_meta( &"__index", i )

	if (_allowed_input_types & EventListenerLineEdit.InputType.JOY_MOTION):
		var joya_root:TreeItem = input_tree.create_item( root )
		joya_root.set_text( Column.LABEL, "Joypad Axes" )
		joya_root.set_icon( Column.LABEL, IconCache.get_icon( &"JOY_AXIS" ) )
		joya_root.set_collapsed( collapse )
		joya_root.set_meta( &"__type", EventListenerLineEdit.InputType.JOY_MOTION )
		for i:int in range( JoyAxis.JOY_AXIS_MAX * 2 ):
			var axis:int = i >> 1
			var direction:int = 1 if ( i & 1 ) else -1
			var joym:InputEventJoypadMotion = InputEventJoypadMotion.new()
			joym.axis = axis as JoyAxis
			joym.axis_value = float( direction )
			var desc:String = EventListenerLineEdit.get_event_text( joym, false )
			if not _matches_search( desc, search_term ):
				continue
			var item:TreeItem = input_tree.create_item( joya_root )
			item.set_text( Column.LABEL, desc )
			item.set_meta( &"__axis", axis )
			item.set_meta( &"__value", direction )


func _apply_mod_checkboxes( mod:InputEventWithModifiers ) -> void:
	mod.alt_pressed = alt_cb.button_pressed
	mod.shift_pressed = shift_cb.button_pressed
	if command_control_cb.button_pressed:
		mod.command_or_control_autoremap = true
	else:
		mod.ctrl_pressed = ctrl_cb.button_pressed
		mod.meta_pressed = windows_cb.button_pressed


func _select_matching_input_list_item( event:InputEvent ) -> void:
	if input_tree.get_root() == null:
		return
	var category:TreeItem = input_tree.get_root().get_first_child()
	while category:
		var input_item:TreeItem = category.get_first_child()
		if is_instance_valid( input_item ):
			var input_type:int = category.get_meta( &"__type", 0 )
			if _event_matches_list_type( event, input_type ):
				while input_item:
					if _list_item_matches_event( input_item, event ):
						category.collapsed = false
						# select() fires item_selected; cancel deferred apply — highlight only.
						input_item.select( Column.LABEL )
						input_tree.ensure_cursor_is_visible()
						_pending_list_item = null
						return
					input_item = input_item.get_next()
		category.collapsed = true
		category = category.get_next()


# True when [param text] should appear under the current search box filter.
func _matches_search( text:String, search_term:String ) -> bool:
	return search_term.is_empty() or text.containsn( search_term )


# Predicate for [method Array.filter] over keycodes (empty names dropped).
func _keycode_matches_search( keycode:int, search_term:String ) -> bool:
	var key_name:String = OS.get_keycode_string( keycode )
	return not key_name.is_empty() and _matches_search( key_name, search_term )


# [EventListenerLineEdit.InputType] bit for [param event], or 0 if unsupported.
func _input_type_for_event( event:InputEvent ) -> int:
	if event is InputEventKey:
		return EventListenerLineEdit.InputType.KEY
	if event is InputEventJoypadButton:
		return EventListenerLineEdit.InputType.JOY_BUTTON
	if event is InputEventJoypadMotion:
		return EventListenerLineEdit.InputType.JOY_MOTION
	if event is InputEventMouseButton:
		return EventListenerLineEdit.InputType.MOUSE_BUTTON
	return 0


func _event_matches_list_type( event:InputEvent, input_type:int ) -> bool:
	return _input_type_for_event( event ) == input_type


func _list_item_matches_event( item:TreeItem, event:InputEvent ) -> bool:
	if event is InputEventKey:
		var ev:InputEventKey = event
		var code:int = item.get_meta( &"__keycode" )
		return ev.keycode == code or ev.physical_keycode == code
	if event is InputEventJoypadButton:
		var jb:InputEventJoypadButton = event
		return jb.button_index == item.get_meta( &"__index" )
	if event is InputEventJoypadMotion:
		var jm:InputEventJoypadMotion = event
		var axis:int = item.get_meta( &"__axis" )
		var value:float = item.get_meta( &"__value" )
		return jm.axis == axis and is_equal_approx( jm.axis_value, value )
	if event is InputEventMouseButton:
		var mb:InputEventMouseButton = event
		return mb.button_index == item.get_meta( &"__index" )
	return false


func _set_current_device( device:int ) -> void:
	device_opt.select( device + 1 )


func _get_current_device() -> int:
	return device_opt.selected - 1


func _sync_ok_enabled() -> void:
	# Scene nodes exist after _ready; guard only for early @tool calls.
	if not is_instance_valid( ok_btn ):
		return
	# Allow OK only when a real event is configured and not a duplicate.
	var do_dup:bool = false
	if is_instance_valid( _configured_event ):
		for v:Variant in _action_events:
			var ie:InputEvent = v
			if _InputManager.compare_event( ie, _configured_event ):
				do_dup = true
				break
	if is_instance_valid( error_lbl ):
		error_lbl.visible = do_dup
	ok_btn.disabled = _configured_event == null or do_dup


# Connect and report failures (Signal.connect returns Error).
func _connect_sig( sig:Signal, callable:Callable, flags:int = 0 ) -> void:
	var err:Error = sig.connect( callable, flags ) as Error
	if err != OK:
		push_error( "EventConfigDialog._connect_sig: %s" % error_string( err ) )


## Practical key set for the manual picker (engine uses keycode_get_count() C++).
static func _keyboard_keycodes() -> Array[int]:
	var keys:Array[int] = []
	# Printable ASCII range used by KEY_* where applicable (SPACE..~).
	for c:int in range(KEY_SPACE, 0x007E + 1):
		keys.append(c)
	var specials:Array[int] = [
		KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER,
		KEY_INSERT, KEY_DELETE, KEY_PAUSE, KEY_PRINT, KEY_SYSREQ, KEY_CLEAR,
		KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN,
		KEY_PAGEUP, KEY_PAGEDOWN,
		KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT, KEY_CAPSLOCK, KEY_NUMLOCK,
		KEY_SCROLLLOCK, KEY_MENU,
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8,
		KEY_F9, KEY_F10, KEY_F11, KEY_F12, KEY_F13, KEY_F14, KEY_F15, KEY_F16,
		KEY_F17, KEY_F18, KEY_F19, KEY_F20, KEY_F21, KEY_F22, KEY_F23, KEY_F24,
		KEY_F25, KEY_F26, KEY_F27, KEY_F28, KEY_F29, KEY_F30, KEY_F31, KEY_F32,
		KEY_F33, KEY_F34, KEY_F35,
		KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_PERIOD,
		KEY_KP_ADD, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4,
		KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
		#KEY_SUPER_L, KEY_SUPER_R,
		#KEY_HYPER_L, KEY_HYPER_R,
		KEY_HELP,
		#KEY_DIRECTION_L, KEY_DIRECTION_R,
		KEY_BACK, KEY_FORWARD, KEY_STOP, KEY_REFRESH,
		KEY_VOLUMEDOWN, KEY_VOLUMEMUTE, KEY_VOLUMEUP,
		#KEY_MEDIANEXT, KEY_MEDIAPLAY, KEY_MEDIAPREV, KEY_MEDIASTOP,
		KEY_HOMEPAGE, KEY_FAVORITES, KEY_SEARCH, KEY_STANDBY,
		KEY_OPENURL, KEY_LAUNCHMAIL, KEY_LAUNCHMEDIA,
		KEY_LAUNCH0, KEY_LAUNCH1, KEY_LAUNCH2, KEY_LAUNCH3,
		KEY_LAUNCH4, KEY_LAUNCH5, KEY_LAUNCH6, KEY_LAUNCH7,
		KEY_LAUNCH8, KEY_LAUNCH9, KEY_LAUNCHA, KEY_LAUNCHB,
		KEY_LAUNCHC, KEY_LAUNCHD, KEY_LAUNCHE, KEY_LAUNCHF,
	]

	for k:int in specials:
		if k not in keys:
			keys.append(k)
	return keys
