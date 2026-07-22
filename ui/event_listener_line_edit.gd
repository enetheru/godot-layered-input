@tool
class_name EventListenerLineEdit
extends LineEdit

##[codeblock]
##│ ___             _     _    _    _
##│| __|_ _____ _ _| |_  | |  (_)__| |_ ___ _ _  ___ _ _
##│| _|\ V / -_) ' \  _| | |__| (_-<  _/ -_) ' \/ -_) '_|
##│|___|\_/\___|_||_\__| |____|_/__/\__\___|_||_\___|_|
##╰────────────────────────────────────────────────────────
##[/codeblock]Captures a single pressed InputEvent for binding / filtering.
##
## Port of Godot's `EventListenerLineEdit` (editor/settings/event_listener_line_edit.*).
## Independent of editor-only APIs so it can run in-game or as an editor tool.
##[br]
## While focused, key / mouse-button / joy events are consumed and exposed via
## [signal event_changed]. Hold [code]ui_cancel[/code] briefly to release focus.

## Bitmask of accepted event kinds for [method set_allowed_input_types].
enum InputType {
	KEY = 0x1,
	MOUSE_BUTTON = 0x2,
	JOY_BUTTON = 0x4,
	JOY_MOTION = 0x8,
}

const ALL_INPUT_TYPES:int = (
		InputType.KEY
		| InputType.MOUSE_BUTTON
		| InputType.JOY_BUTTON
		| InputType.JOY_MOTION
)

## Joy axis descriptions matching engine EventListenerLineEdit (axis*2 + direction).
const _JOY_AXIS_DESCRIPTIONS: PackedStringArray = [
	"Left Stick Left, Joystick 0 Left",
	"Left Stick Right, Joystick 0 Right",
	"Left Stick Up, Joystick 0 Up",
	"Left Stick Down, Joystick 0 Down",
	"Right Stick Left, Joystick 1 Left",
	"Right Stick Right, Joystick 1 Right",
	"Right Stick Up, Joystick 1 Up",
	"Right Stick Down, Joystick 1 Down",
	"Joystick 2 Left",
	"Left Trigger, Sony L2, Xbox LT, Joystick 2 Right",
	"Joystick 2 Up",
	"Right Trigger, Sony R2, Xbox RT, Joystick 2 Down",
	"Joystick 3 Left",
	"Joystick 3 Right",
	"Joystick 3 Up",
	"Joystick 3 Down",
	"Joystick 4 Left",
	"Joystick 4 Right",
	"Joystick 4 Up",
	"Joystick 4 Down",
]

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Hold [code]ui_cancel[/code] this long (ms) to release focus while listening.
@export var hold_to_unfocus_ms:int = 3000

var allowed_input_types:int = ALL_INPUT_TYPES
var _event:InputEvent
var _ignore_next_event:bool = true
var _hold_next_ms:int = 0
var _hold_event:InputEvent


#            ███████ ██  ██████  ███    ██  █████  ██      ███████             #
#            ██      ██ ██       ████   ██ ██   ██ ██      ██                  #
#            ███████ ██ ██   ███ ██ ██  ██ ███████ ██      ███████             #
#                 ██ ██ ██    ██ ██  ██ ██ ██   ██ ██           ██             #
#            ███████ ██  ██████  ██   ████ ██   ██ ███████ ███████             #
func                        _________SIGNALS_________              ()->void:pass

signal event_changed( event:InputEvent )


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_focus_entered() -> void:
	placeholder_text = "Listening for Input"


func _on_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		clear_event()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_FOCUS_ENTER:
			var window: Window = get_window()
			if window is AcceptDialog:
				(window as AcceptDialog).dialog_close_on_escape = false
			placeholder_text = "Listening for Input"
		NOTIFICATION_FOCUS_EXIT:
			var window: Window = get_window()
			if window is AcceptDialog:
				(window as AcceptDialog).dialog_close_on_escape = true
			# Only ignore the focusing click when the user focuses by mouse.
			# Programmatic manual_grab_focus() clears this again before the next event.
			_ignore_next_event = true
			placeholder_text = "Filter by Event"


func _ready() -> void:
	caret_blink = false
	clear_button_enabled = true
	focus_mode = Control.FOCUS_ALL
	if placeholder_text.is_empty():
		placeholder_text = "Filter by Event"
	@warning_ignore_start("return_value_discarded")
	text_changed.connect(_on_text_changed)
	focus_entered.connect(_on_focus_entered)
	@warning_ignore_restore("return_value_discarded")


## Code-driven focus must accept the next bind immediately (engine EventListenerLineEdit).
## [br]FIXME: The grab_focus function cannot be overridden, if the override
## behavior was being relied upon, we need to figure out a different mechanism
## to trigger this.
func manual_grab_focus() -> void:
	# Opening the config dialog via a tree button leaves a mouse-up in the queue.
	# Accept the next non-key residual (mouse) once, then take real binds.
	_ignore_next_event = false
	grab_focus()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return

	# Allow clear-button interaction without capturing as a bind.
	if event is InputEventMouseButton and clear_button_enabled and text.length() > 0:
		var mb := event as InputEventMouseButton
		# Rough right-edge hit; exact clear button rect is not exposed.
		if mb.position.x > size.x - size.y:
			return

	# Swallow residual open-click / focus-click without eating the first key bind.
	if _ignore_next_event:
		_ignore_next_event = false
		if event is InputEventMouseButton:
			accept_event()
			return
		# Key/joy that arrived while ignore was set (e.g. focus race): treat as bind.

	var event_to_check: InputEvent = event

	# Hold ui_cancel to release focus (see [member hold_to_unfocus_ms]).
	if event.is_action_pressed( &"ui_cancel", true, true ):
		var now:int = Time.get_ticks_msec()
		if _hold_next_ms > 0 and ( now - _hold_next_ms ) < hold_to_unfocus_ms:
			_hold_next_ms = 0
			var next := find_next_valid_focus()
			if next:
				next.grab_focus()
		else:
			_hold_next_ms = now
			_hold_event = event
		accept_event()
		return

	if event.is_action_released(&"ui_cancel", true):
		event_to_check = _hold_event
		_hold_next_ms = 0
		_hold_event = null

	accept_event()
	if (
			event_to_check == null
			or not event_to_check.is_pressed()
			or event_to_check.is_echo()
			or (_event != null and event_to_check.is_match(_event))
			or not _is_event_allowed(event_to_check)
	):
		return

	_event = event_to_check
	text = get_event_text(_event, false)
	event_changed.emit(_event)


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func get_event() -> InputEvent:
	return _event


func clear_event() -> void:
	if _event == null:
		return
	_event = null
	text = ""
	event_changed.emit( null )


func set_allowed_input_types( type_masks:int ) -> void:
	allowed_input_types = type_masks


func get_allowed_input_types() -> int:
	return allowed_input_types


#        ███████ ████████  █████  ████████ ██  ██████                          #
#        ██         ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ███████    ██    ██ ██                               #
#             ██    ██    ██   ██    ██    ██ ██                               #
#        ███████    ██    ██   ██    ██    ██  ██████                          #
func                        _________STATIC__________              ()->void:pass

## Human-readable description of [param event].
static func get_event_text(
			event:InputEvent,
			include_device:bool = true ) -> String:
	if event == null:
		return ""

	var event_text:String = ""
	if event is InputEventKey:
		var key := event as InputEventKey
		var mods_text := _modifiers_text(key)
		if not mods_text.is_empty():
			mods_text += "+"

		if key.keycode != KEY_NONE:
			event_text += mods_text + OS.get_keycode_string(key.keycode)
		if key.physical_keycode != KEY_NONE:
			if not event_text.is_empty():
				event_text += " or "
			event_text += mods_text + OS.get_keycode_string(key.physical_keycode) + " (Physical"
			if key.location != KEY_LOCATION_UNSPECIFIED:
				event_text += " " + key.as_text_location()
			event_text += ")"
		if key.key_label != KEY_NONE:
			if not event_text.is_empty():
				event_text += " or "
			event_text += mods_text + OS.get_keycode_string(key.key_label) + " (Unicode)"
		if event_text.is_empty():
			event_text = "(unset)"
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		var desc := "Unknown Joypad Axis"
		var axis_i := int(jm.axis)
		var idx := 2 * axis_i + (0 if jm.axis_value < 0.0 else 1)
		if idx >= 0 and idx < _JOY_AXIS_DESCRIPTIONS.size():
			desc = _JOY_AXIS_DESCRIPTIONS[idx]
		var sign_s := "-" if jm.axis_value < 0.0 else "+"
		event_text = "Joypad Axis %d %s (%s)" % [axis_i, sign_s, desc]
	else:
		event_text = event.as_text()

	if include_device and (
			event is InputEventMouse
			or event is InputEventJoypadButton
			or event is InputEventJoypadMotion
	):
		event_text += " - %s" % get_device_string(event.device)
	return event_text


static func get_device_string(device: int) -> String:
	if device < 0:
		return "All Devices"
	return "Device %d" % device


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

static func _modifiers_text(key: InputEventWithModifiers) -> String:
	var parts:Array = []
	if key.command_or_control_autoremap:
		parts.append("Command/Ctrl")
	else:
		if key.ctrl_pressed:
			parts.append("Ctrl")
		if key.meta_pressed:
			parts.append("Meta")
	if key.alt_pressed:
		parts.append("Alt")
	if key.shift_pressed:
		parts.append("Shift")
	return "+".join(parts)


func _is_event_allowed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (allowed_input_types & InputType.MOUSE_BUTTON) != 0
	if event is InputEventKey:
		return (allowed_input_types & InputType.KEY) != 0
	if event is InputEventJoypadButton:
		return (allowed_input_types & InputType.JOY_BUTTON) != 0
	if event is InputEventJoypadMotion:
		return (allowed_input_types & InputType.JOY_MOTION) != 0
	return false
