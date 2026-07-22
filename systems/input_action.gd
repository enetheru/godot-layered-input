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
##[br][color=goldenrod]TODO[/color]:Implement iterators for events.


const DEFAULT_DEADZONE:float = 0.2


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

@export var deadzone:float = DEFAULT_DEADZONE
@export var events:Array[InputEvent] = []


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
	deadzone = new_deadzone
	events = new_events


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
	for ev:InputEvent in events:
		if is_instance_valid( ev ):
			out.events.append( ev.duplicate() )
	return out


func has_event( event:InputEvent ) -> bool:
	assert( event, "InputAction.has_event: event is invalid" )
	for ev:InputEvent in events:
		if ev == null:
			push_warning( "InputAction.has_event: null entry in events" )
			continue
		if _InputManager.compare_event( event, ev ):
			return true
	return false


func add_event( event:InputEvent ) -> void:
	assert( event, "InputAction.add_event: invalid event" )
	if has_event( event ):
		push_warning( "InputAction.add_event: event already exists" )
		return
	events.append( event )


func erase_event( event:InputEvent ) -> void:
	if not is_instance_valid( event ):
		return
	for i:int in range( events.size() - 1, -1, -1 ):
		var ev:InputEvent = events[i]
		if ev == null:
			events.remove_at( i )
			continue
		if _InputManager.compare_event( event, ev ):
			events.remove_at( i )


func clear_events() -> void:
	events.clear()
