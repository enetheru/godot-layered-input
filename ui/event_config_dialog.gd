@tool
class_name EventConfigDialog
extends PopupPanel

## Configure a single [InputEvent] for an action binding.
##
## Port of Godot's `InputEventConfigurationDialog`
## (editor/settings/input_event_configuration_dialog.*).
## Scene nodes mirror the editor layout; OK/Cancel replace ConfirmationDialog.

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

signal confirmed
signal canceled

@onready var event_label: Label = $VBoxContainer/VBoxContainer/EventLabel
@onready var event_listener: EventListenerLineEdit = $VBoxContainer/VBoxContainer/EventListenerLineEdit

@onready var filter_input_line_edit: LineEdit = $VBoxContainer/VBoxContainer/ManualSelection/FilterInputLineEdit
@onready var input_list_tree: Tree = $VBoxContainer/VBoxContainer/ManualSelection/MarginContainer/Tree

@onready var additional_options: VBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions
@onready var device_container: HBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions/DeviceHBox
@onready var device_option_button: OptionButton = $VBoxContainer/VBoxContainer/AdditionalOptions/DeviceHBox/OptionButton

@onready var mod_container: HBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer
@onready var alt: CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Alt
@onready var shift: CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Shift
@onready var ctrl: CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Ctrl
@onready var windows: CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/Windows
@onready var command_control: CheckBox = $VBoxContainer/VBoxContainer/AdditionalOptions/HBoxContainer/CommandControl

@onready var key_mode: OptionButton = $VBoxContainer/VBoxContainer/AdditionalOptions/OptionButton
@onready var location_container: HBoxContainer = $VBoxContainer/VBoxContainer/AdditionalOptions/PhysicalLocation
@onready var location_option_button: OptionButton = $VBoxContainer/VBoxContainer/AdditionalOptions/PhysicalLocation/OptionButton

@onready var error: Label = $VBoxContainer/VBoxContainer/Error
@onready var ok: Button = $VBoxContainer/OKCancel/OK
@onready var cancel: Button = $VBoxContainer/OKCancel/Cancel

var _event: InputEvent
var _original_event: InputEvent
var _action_events: Array = []
var _allowed_input_types: int = EventListenerLineEdit.ALL_INPUT_TYPES
var _in_tree_update: bool = false
var _mod_checkboxes: Array[CheckBox] = []


func _ready() -> void:
	visible = false
	hide()

	_mod_checkboxes = [alt, shift, ctrl, windows]

	@warning_ignore_start("return_value_discarded")
	event_listener.event_changed.connect(_on_listen_input_changed)
	filter_input_line_edit.text_changed.connect(_on_search_term_updated)
	input_list_tree.item_activated.connect(_on_input_list_item_activated)
	input_list_tree.item_selected.connect(_on_input_list_item_selected)
	device_option_button.item_selected.connect(_on_device_selection_changed)
	alt.toggled.connect(_on_mod_toggled.bind(ModCheckbox.ALT))
	shift.toggled.connect(_on_mod_toggled.bind(ModCheckbox.SHIFT))
	ctrl.toggled.connect(_on_mod_toggled.bind(ModCheckbox.CTRL))
	windows.toggled.connect(_on_mod_toggled.bind(ModCheckbox.META))
	command_control.toggled.connect(_on_autoremap_command_or_control_toggled)
	key_mode.item_selected.connect(_on_key_mode_selected)
	location_option_button.item_selected.connect(_on_key_location_selected)
	ok.pressed.connect(_on_ok_pressed)
	cancel.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)
	@warning_ignore_restore("return_value_discarded")

	# Device list: index 0 = All Devices (-1), then 0..7
	device_option_button.clear()
	for i: int in range(-1, 8):
		device_option_button.add_item(EventListenerLineEdit.get_device_string(i))

	# Key-mode icons (engine sets these from EditorIcons).
	if key_mode.item_count >= 3:
		key_mode.set_item_icon(KeyMode.KEYCODE, IconCache.get_icon(&"KEYBOARD"))
		key_mode.set_item_icon(KeyMode.PHY_KEYCODE, IconCache.get_icon(&"KEYBOARD_PHYSICAL"))
		key_mode.set_item_icon(KeyMode.UNICODE, IconCache.get_icon(&"KEYBOARD_LABEL"))

	_update_input_list()
	additional_options.hide()
	error.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		event_listener.grab_focus()


func get_event() -> InputEvent:
	return _event


func set_allowed_input_types(type_masks: int) -> void:
	_allowed_input_types = type_masks
	if is_instance_valid(event_listener):
		event_listener.set_allowed_input_types(type_masks)


## Open dialog to edit [param event] (or blank). [param current_action] expects
## [code]{"events": Array, "deadzone": float}[/code] for duplicate detection.
func popup_and_configure(
		event: InputEvent = null,
		current_action_name: String = "",
		current_action: Dictionary = {}
) -> void:
	var events: Array = current_action.get("events", [])
	_action_events = events.duplicate()

	if event != null:
		# Drop one matching instance so the event being edited is not flagged duplicate.
		for i: int in range(_action_events.size()):
			var ie: InputEvent = _action_events[i]
			if ie != null and ie.is_match(event):
				_action_events.remove_at(i)
				break
		var a: InputEvent = event.duplicate()
		var b: InputEvent = event.duplicate()
		_set_event(a, b)
	else:
		_set_event(null, null)
		for cb: CheckBox in _mod_checkboxes:
			cb.set_pressed_no_signal(false)
		key_mode.select(KeyMode.PHY_KEYCODE)
		command_control.set_pressed_no_signal(false)
		device_option_button.select(0)
		location_option_button.select(0)

	if not current_action_name.is_empty():
		title = 'Event Configuration for "%s"' % current_action_name
	else:
		title = "Event Configuration"

	# Bottom-panel parents can clip / break Window popups in the editor.
	# Transient + exclusive keeps the dialog on top of the editor chrome.
	if Engine.is_editor_hint():
		exclusive = true
		unresizable = false
	popup_centered(Vector2i(661, 400))
	# Ensure OK reflects current event (null → disabled).
	_sync_ok_enabled()


# ── event state ─────────────────────────────────────────────────────────────

func _set_event(
		event: InputEvent,
		original_event: InputEvent,
		update_input_list_selection: bool = true
) -> void:
	if event != null:
		# Enter / Escape confirm or cancel when a binding is already set.
		if _event != null and visible and event_listener.has_focus():
			if event is InputEventKey:
				var current_key := event as InputEventKey
				var mods := event as InputEventWithModifiers
				# Bare Enter/Escape confirm or cancel (no modifier chords).
				if mods != null and int(mods.get_modifiers_mask()) == 0:
					if current_key.physical_keycode == KEY_ENTER or current_key.keycode == KEY_ENTER:
						_on_ok_pressed()
						return
					if current_key.physical_keycode == KEY_ESCAPE or current_key.keycode == KEY_ESCAPE:
						_on_cancel_pressed()
						return

		var listener_event := event_listener.get_event()
		if listener_event != null and not listener_event.is_match(event):
			event_listener.clear_event()

		_event = event
		_original_event = original_event
		event_label.text = EventListenerLineEdit.get_event_text(_event, true)

		_sync_ok_enabled()

		var show_mods := false
		var show_device := false
		var show_key := false
		var show_location := false

		if event is InputEventWithModifiers:
			show_mods = true
			var mod := event as InputEventWithModifiers
			alt.set_pressed_no_signal(mod.alt_pressed)
			shift.set_pressed_no_signal(mod.shift_pressed)
			ctrl.set_pressed_no_signal(mod.ctrl_pressed)
			windows.set_pressed_no_signal(mod.meta_pressed)
			command_control.set_pressed_no_signal(mod.command_or_control_autoremap)

		if event is InputEventKey:
			show_key = true
			var k := event as InputEventKey
			var phys_key := k.physical_keycode
			if k.keycode == KEY_NONE and phys_key == KEY_NONE and k.key_label != KEY_NONE:
				key_mode.select(KeyMode.UNICODE)
			elif k.keycode != KEY_NONE:
				key_mode.select(KeyMode.KEYCODE)
			elif phys_key != KEY_NONE:
				key_mode.select(KeyMode.PHY_KEYCODE)
				if phys_key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
					location_option_button.select(int(k.location))
					show_location = true
			else:
				_event = null
				_original_event = null
				event_listener.clear_event()
				event_label.text = "No Event Configured"
				additional_options.hide()
				input_list_tree.deselect_all()
				_update_input_list()
				return
		elif (
				event is InputEventJoypadButton
				or event is InputEventJoypadMotion
				or event is InputEventMouseButton
		):
			show_device = true
			_set_current_device(event.device)

		mod_container.visible = show_mods
		device_container.visible = show_device
		key_mode.visible = show_key
		location_container.visible = show_location
		additional_options.show()

		# Disable key-mode options the original event cannot supply.
		if original_event is InputEventKey:
			var ko := original_event as InputEventKey
			key_mode.set_item_disabled(KeyMode.KEYCODE, ko.keycode == KEY_NONE)
			key_mode.set_item_disabled(KeyMode.PHY_KEYCODE, ko.physical_keycode == KEY_NONE)
			key_mode.set_item_disabled(KeyMode.UNICODE, ko.key_label == KEY_NONE)

		if update_input_list_selection:
			_select_matching_input_list_item(event)
	else:
		_event = null
		_original_event = null
		event_listener.clear_event()
		event_label.text = "No Event Configured"
		additional_options.hide()
		input_list_tree.deselect_all()
		_update_input_list()
		_sync_ok_enabled()


func _on_listen_input_changed(event: InputEvent) -> void:
	if event == null or event.is_echo() or not event.is_pressed():
		return

	var received: InputEvent = event
	var received_original: InputEvent = received.duplicate()

	var type := 0
	if received is InputEventKey:
		type = EventListenerLineEdit.InputType.KEY
	elif received is InputEventJoypadButton:
		type = EventListenerLineEdit.InputType.JOY_BUTTON
	elif received is InputEventJoypadMotion:
		type = EventListenerLineEdit.InputType.JOY_MOTION
	elif received is InputEventMouseButton:
		type = EventListenerLineEdit.InputType.MOUSE_BUTTON

	if (_allowed_input_types & type) == 0:
		return

	if received is InputEventJoypadMotion:
		var jm := received as InputEventJoypadMotion
		jm.axis_value = signf(jm.axis_value)

	if received is InputEventKey:
		var k := received as InputEventKey
		k.pressed = false
		match key_mode.get_selected_id():
			KeyMode.KEYCODE:
				k.physical_keycode = KEY_NONE
				k.key_label = KEY_NONE
			KeyMode.PHY_KEYCODE:
				k.keycode = KEY_NONE
				k.key_label = KEY_NONE
			KeyMode.UNICODE:
				k.physical_keycode = KEY_NONE
				k.keycode = KEY_NONE
		if location_option_button.get_selected_id() == int(KEY_LOCATION_UNSPECIFIED):
			k.location = KEY_LOCATION_UNSPECIFIED

	if received is InputEventWithModifiers:
		(received as InputEventWithModifiers).window_id = 0

	received.device = _get_current_device()
	_set_event(received, received_original)


# ── manual input list ───────────────────────────────────────────────────────

func _on_search_term_updated(_term: String = "") -> void:
	_update_input_list()


func _update_input_list() -> void:
	input_list_tree.clear()
	var root := input_list_tree.create_item()
	var search_term := filter_input_line_edit.text
	var collapse := search_term.is_empty()

	if (_allowed_input_types & EventListenerLineEdit.InputType.KEY) != 0:
		var kb_root := input_list_tree.create_item(root)
		kb_root.set_text(0, "Keyboard Keys")
		kb_root.set_icon(0, IconCache.get_icon(&"KEYBOARD"))
		kb_root.set_collapsed(collapse)
		kb_root.set_meta(&"__type", EventListenerLineEdit.InputType.KEY)
		for keycode:int in _keyboard_keycodes():
			var key_name:String = OS.get_keycode_string(keycode)
			if key_name.is_empty():
				continue
			if not search_term.is_empty() and not key_name.containsn(search_term):
				continue
			var item := input_list_tree.create_item(kb_root)
			item.set_text(0, key_name)
			item.set_meta(&"__keycode", keycode)

	if (_allowed_input_types & EventListenerLineEdit.InputType.MOUSE_BUTTON) != 0:
		var mouse_root := input_list_tree.create_item(root)
		mouse_root.set_text(0, "Mouse Buttons")
		mouse_root.set_icon(0, IconCache.get_icon(&"MOUSE"))
		mouse_root.set_collapsed(collapse)
		mouse_root.set_meta(&"__type", EventListenerLineEdit.InputType.MOUSE_BUTTON)
		var mouse_buttons: Array[int] = [
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
			MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
		]
		for btn: int in mouse_buttons:
			var mb := InputEventMouseButton.new()
			mb.button_index = btn as MouseButton
			var desc := EventListenerLineEdit.get_event_text(mb, false)
			if not search_term.is_empty() and not desc.containsn(search_term):
				continue
			var item := input_list_tree.create_item(mouse_root)
			item.set_text(0, desc)
			item.set_meta(&"__index", btn)

	if (_allowed_input_types & EventListenerLineEdit.InputType.JOY_BUTTON) != 0:
		var joyb_root := input_list_tree.create_item(root)
		joyb_root.set_text(0, "Joypad Buttons")
		joyb_root.set_icon(0, IconCache.get_icon(&"JOY_BUTTON"))
		joyb_root.set_collapsed(collapse)
		joyb_root.set_meta(&"__type", EventListenerLineEdit.InputType.JOY_BUTTON)
		for i: int in range(int(JoyButton.JOY_BUTTON_MAX)):
			var joyb := InputEventJoypadButton.new()
			joyb.button_index = i as JoyButton
			var desc := EventListenerLineEdit.get_event_text(joyb, false)
			if not search_term.is_empty() and not desc.containsn(search_term):
				continue
			var item := input_list_tree.create_item(joyb_root)
			item.set_text(0, desc)
			item.set_meta(&"__index", i)

	if (_allowed_input_types & EventListenerLineEdit.InputType.JOY_MOTION) != 0:
		var joya_root := input_list_tree.create_item(root)
		joya_root.set_text(0, "Joypad Axes")
		joya_root.set_icon(0, IconCache.get_icon(&"JOY_AXIS"))
		joya_root.set_collapsed(collapse)
		joya_root.set_meta(&"__type", EventListenerLineEdit.InputType.JOY_MOTION)
		for i: int in range(int(JoyAxis.JOY_AXIS_MAX) * 2):
			var axis := i >> 1
			var direction := 1 if (i & 1) else -1
			var joym := InputEventJoypadMotion.new()
			joym.axis = axis as JoyAxis
			joym.axis_value = float(direction)
			var desc := EventListenerLineEdit.get_event_text(joym, false)
			if not search_term.is_empty() and not desc.containsn(search_term):
				continue
			var item := input_list_tree.create_item(joya_root)
			item.set_text(0, desc)
			item.set_meta(&"__axis", axis)
			item.set_meta(&"__value", direction)


func _on_input_list_item_activated() -> void:
	var selected := input_list_tree.get_selected()
	if selected:
		selected.collapsed = not selected.collapsed


func _on_input_list_item_selected() -> void:
	if _in_tree_update:
		return
	var selected := input_list_tree.get_selected()
	if selected == null or selected.has_meta(&"__type"):
		return

	var input_type: int = selected.get_parent().get_meta(&"__type")
	match input_type:
		EventListenerLineEdit.InputType.KEY:
			var keycode: int = selected.get_meta(&"__keycode")
			var k := InputEventKey.new()
			k.physical_keycode = keycode as Key
			k.keycode = keycode as Key
			k.key_label = keycode as Key
			_apply_mod_checkboxes(k)
			var ko: InputEventKey = k.duplicate() as InputEventKey
			if key_mode.get_selected_id() == KeyMode.UNICODE:
				key_mode.select(KeyMode.PHY_KEYCODE)
			match key_mode.get_selected_id():
				KeyMode.KEYCODE:
					k.physical_keycode = KEY_NONE
					k.keycode = keycode as Key
					k.key_label = KEY_NONE
				KeyMode.PHY_KEYCODE:
					k.physical_keycode = keycode as Key
					k.keycode = KEY_NONE
					k.key_label = KEY_NONE
			_set_event(k, ko, false)

		EventListenerLineEdit.InputType.MOUSE_BUTTON:
			var mb := InputEventMouseButton.new()
			mb.button_index = selected.get_meta(&"__index")
			_apply_mod_checkboxes(mb)
			mb.device = _get_current_device()
			_set_event(mb, mb, false)

		EventListenerLineEdit.InputType.JOY_BUTTON:
			var jb := InputEventJoypadButton.new()
			jb.button_index = selected.get_meta(&"__index")
			jb.device = _get_current_device()
			_set_event(jb, jb, false)

		EventListenerLineEdit.InputType.JOY_MOTION:
			var jm := InputEventJoypadMotion.new()
			jm.axis = selected.get_meta(&"__axis")
			jm.axis_value = selected.get_meta(&"__value")
			jm.device = _get_current_device()
			_set_event(jm, jm, false)


func _apply_mod_checkboxes(mod: InputEventWithModifiers) -> void:
	mod.alt_pressed = alt.button_pressed
	mod.shift_pressed = shift.button_pressed
	if command_control.button_pressed:
		mod.command_or_control_autoremap = true
	else:
		mod.ctrl_pressed = ctrl.button_pressed
		mod.meta_pressed = windows.button_pressed


func _select_matching_input_list_item(event: InputEvent) -> void:
	if input_list_tree.get_root() == null:
		return
	_in_tree_update = true
	var category := input_list_tree.get_root().get_first_child()
	while category:
		var input_item := category.get_first_child()
		if input_item != null:
			var input_type: int = category.get_meta(&"__type", 0)
			var type_match := (
					(event is InputEventKey and input_type == EventListenerLineEdit.InputType.KEY)
					or (event is InputEventJoypadButton and input_type == EventListenerLineEdit.InputType.JOY_BUTTON)
					or (event is InputEventJoypadMotion and input_type == EventListenerLineEdit.InputType.JOY_MOTION)
					or (event is InputEventMouseButton and input_type == EventListenerLineEdit.InputType.MOUSE_BUTTON)
			)
			if type_match:
				while input_item:
					var matched:bool = false
					if event is InputEventKey:
						var ev:InputEventKey = event
						var code: int = input_item.get_meta(&"__keycode")
						matched = ev.keycode == code or ev.physical_keycode == code
					elif event is InputEventJoypadButton:
						var ev:InputEventJoypadButton = event
						matched = ev.button_index == input_item.get_meta(&"__index")
					elif event is InputEventJoypadMotion:
						var ev:InputEventJoypadMotion = event
						var axis:int = input_item.get_meta(&"__axis")
						var value:float = input_item.get_meta(&"__value")
						matched = ev.axis == axis and is_equal_approx(ev.axis_value, value)
					elif event is InputEventMouseButton:
						var ev:InputEventMouseButton = event
						matched = ev.button_index == input_item.get_meta(&"__index")
					if matched:
						category.collapsed = false
						input_item.select(0)
						input_list_tree.ensure_cursor_is_visible()
						_in_tree_update = false
						return
					input_item = input_item.get_next()
		category.collapsed = true
		category = category.get_next()
	_in_tree_update = false


# ── additional options ──────────────────────────────────────────────────────

func _on_mod_toggled(pressed: bool, index: int) -> void:
	if not (_event is InputEventWithModifiers):
		return
	var ie := _event as InputEventWithModifiers
	match index:
		ModCheckbox.ALT:
			ie.alt_pressed = pressed
		ModCheckbox.SHIFT:
			ie.shift_pressed = pressed
		ModCheckbox.CTRL:
			if not command_control.button_pressed:
				ie.ctrl_pressed = pressed
		ModCheckbox.META:
			if not command_control.button_pressed:
				ie.meta_pressed = pressed
	_set_event(ie, _original_event)


func _on_autoremap_command_or_control_toggled(pressed: bool) -> void:
	if _event is InputEventWithModifiers:
		(_event as InputEventWithModifiers).command_or_control_autoremap = pressed
		_set_event(_event, _original_event)
	ctrl.visible = not pressed
	windows.visible = not pressed


func _on_key_mode_selected(_idx: int) -> void:
	if not (_event is InputEventKey) or not (_original_event is InputEventKey):
		return
	var k := _event as InputEventKey
	var ko := _original_event as InputEventKey
	match key_mode.get_selected_id():
		KeyMode.KEYCODE:
			k.keycode = ko.keycode
			k.physical_keycode = KEY_NONE
			k.key_label = KEY_NONE
		KeyMode.PHY_KEYCODE:
			k.keycode = KEY_NONE
			k.physical_keycode = ko.physical_keycode
			k.key_label = KEY_NONE
		KeyMode.UNICODE:
			k.physical_keycode = KEY_NONE
			k.keycode = KEY_NONE
			k.key_label = ko.key_label
	_set_event(k, _original_event)


func _on_key_location_selected(_idx: int) -> void:
	if not (_event is InputEventKey):
		return
	var k := _event as InputEventKey
	k.location = location_option_button.get_selected_id() as KeyLocation
	_set_event(k, _original_event)


func _on_device_selection_changed(option_index: int) -> void:
	if _event == null:
		return
	_event.device = option_index - 1
	event_label.text = EventListenerLineEdit.get_event_text(_event, true)


func _set_current_device(device: int) -> void:
	device_option_button.select(device + 1)


func _get_current_device() -> int:
	return device_option_button.selected - 1


func _sync_ok_enabled() -> void:
	if not is_instance_valid(ok):
		return
	# Allow OK only when a real event is configured and not a duplicate.
	var duplicate: bool = false
	if _event != null:
		for v: Variant in _action_events:
			var ie: InputEvent = v
			if ie != null and ie.is_match(_event):
				duplicate = true
				break
	if is_instance_valid(error):
		error.visible = duplicate
	ok.disabled = _event == null or duplicate


func _on_ok_pressed() -> void:
	_sync_ok_enabled()
	if _event == null:
		if is_instance_valid(error):
			error.text = "No event configured. Listen for input or pick one from the list."
			error.show()
		return
	if ok.disabled:
		return
	# Emit while still visible so listeners can read get_event() reliably.
	confirmed.emit()
	hide()


func _on_cancel_pressed() -> void:
	canceled.emit()
	hide()


## Practical key set for the manual picker (engine uses keycode_get_count() C++).
static func _keyboard_keycodes() -> Array[int]:
	var keys: Array[int] = []
	# Printable ASCII range used by KEY_* where applicable (SPACE..~).
	for c: int in range(KEY_SPACE, 0x007E + 1):
		keys.append(c)
	var specials: Array[int] = [
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

	for k: int in specials:
		if k not in keys:
			keys.append(k)
	return keys
