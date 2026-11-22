@tool
class_name InputAction
extends Resource

##[codeblock]
##│ ___                _       _      _   _
##│|_ _|_ _  _ __ _  _| |_    /_\  __| |_(_)___ _ _
##│ | || ' \| '_ \ || |  _|  / _ \/ _|  _| / _ \ ' \
##│|___|_||_| .__/\_,_|\__| /_/ \_\__|\__|_\___/_||_|
##╰─────────|_|───────────────────────────────────────
##[/codeblock]Single action definition for a [CustomInputMap] layer.
##
## Hand-author as a sub-resource inside a [CustomInputMap] `.tres`, or build
## in code via [method CustomInputMap.add_action] /
## [method CustomInputMap.add_action_event].
## [br]Intended as an **embedded** sub-resource of a map (not a standalone
## `.tres`). Nested under an external map on a scene, the inspector shows
## “linked”; make the [CustomInputMap] unique/local, not only this action —
## Dictionary value overrides often fail to stick on save.
## [br][member events] is the binding list in storage order. Empty slots are
## skipped by the methods that read it.


## Default deadzone for new actions and inspector revert.
const DEFAULT_DEADZONE:float = 0.2


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

## Inspector and panel both edit this field; emit so listeners (Input Map tree)
## stay in sync without replacing the whole action resource.
@export var deadzone:float = DEFAULT_DEADZONE:
	set( value ):
		if is_equal_approx( deadzone, value ):
			return
		deadzone = value
		emit_changed()

## Binding list for this action. Setter covers wholesale Inspector replace.
## In-place [method add_event] / [method erase_event] / [method clear_events]
## call [method refresh_events_inspector] so the array editor sees a write.
@export var events:Array[InputEvent] = []:
	set( value ):
		events = value
		emit_changed()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## Optional args simplify construction when materializing placeholders.
func _init(
			new_deadzone:float = DEFAULT_DEADZONE,
			new_events:Array[InputEvent] = [] ) -> void:
	# Owned by the parent [CustomInputMap]; duplicate with the map when a scene
	# makes the map local (avoids accidental cross-scene sharing of one action).
	resource_local_to_scene = true
	deadzone = new_deadzone
	# Copy into this instance's typed array (do not alias the caller / default arg).
	events.assign( new_events )


## Hide inspector revert where the export default is not a useful “previous
## state” ([member events] would otherwise revert to an empty list).
func _property_can_revert( property:StringName ) -> bool:
	if property == &"events":
		return false
	if property == &"deadzone":
		return not is_equal_approx( deadzone, DEFAULT_DEADZONE )
	return false


## Revert target for [member deadzone] only ([member events] is not revertible).
func _property_get_revert( property:StringName ) -> Variant:
	if property == &"deadzone":
		return DEFAULT_DEADZONE
	return null


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Deep copy of deadzone + events (events are duplicated).
func duplicate_action() -> InputAction:
	var out:InputAction = InputAction.new()
	out.deadzone = deadzone
	for i:int in events.size():
		var ev:InputEvent = events[i]
		if is_instance_valid( ev ):
			out.events.append( ev.duplicate() )
	return out


## True if [param event] matches any stored entry ([method compare_event]).
func has_event( event:InputEvent ) -> bool:
	assert( event, "InputAction.has_event: event is invalid" )
	for i:int in events.size():
		var ev:InputEvent = events[i]
		if is_instance_valid( ev ) and compare_event( event, ev ):
			return true
	return false


## Force the Inspector array editor to refresh after in-place [member events]
## edits (append/remove are invisible without a property write).
func refresh_events_inspector() -> void:
	var copy:Array[InputEvent] = []
	copy.assign( events )
	events = copy
	notify_property_list_changed()


## Append [param event] if not already present; refreshes the Inspector array.
func add_event( event:InputEvent ) -> void:
	assert( event, "InputAction.add_event: invalid event" )
	if has_event( event ):
		push_warning( "InputAction.add_event: event already exists" )
		return
	events.append( event )
	refresh_events_inspector()


## Remove entries matching [param event] (and null slots); refreshes Inspector.
func erase_event( event:InputEvent ) -> void:
	if not is_instance_valid( event ):
		return
	var removed:bool = false
	for i:int in range( events.size() - 1, -1, -1 ):
		var ev:InputEvent = events[i]
		if ev == null:
			events.remove_at( i )
			removed = true
			continue
		if compare_event( event, ev ):
			events.remove_at( i )
			removed = true
	if removed:
		refresh_events_inspector()


## Remove every stored event and refresh the Inspector array editor.
func clear_events() -> void:
	if events.is_empty():
		return
	events.clear()
	refresh_events_inspector()


## True when [param a] and [param b] are the same event or match under
## [method InputEvent.is_match].
## Lives here (not on [code]_InputManager[/code]) so [InputAction] does not
## depend on the manager autoload / script — that cycle broke headless load of
## [code]default_input_map.tres[/code].
static func compare_event(
			a:InputEvent,
			b:InputEvent,
			exact_match:bool = true ) -> bool:
	assert( a and b, "InputAction.compare_event: a or b is invalid" )
	return a == b or a.is_match( b, exact_match )
