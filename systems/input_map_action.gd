class_name InputMapAction
extends Resource

##[codeblock]
##│ ___                _     __  __               _      _   _
##│|_ _|_ _  _ __ _  _| |_  |  \/  |__ _ _ __    /_\  __| |_(_)___ _ _
##│ | || ' \| '_ \ || |  _| | |\/| / _` | '_ \  / _ \/ _|  _| / _ \ ' \
##│|___|_||_| .__/\_,_|\__| |_|  |_\__,_| .__/ /_/ \_\__|\__|_\___/_||_|
##╰─────────|_|─────────────────────────|_|───────────────────────────────
##[/codeblock]Single action definition for a [CustomInputMap] layer.
##
## Hand-author as a sub-resource inside a [CustomInputMap] `.tres`, or build
## in code via [method CustomInputMap.add_action] / [method CustomInputMap.action_add_event].
#[br][color=goldenrod]TODO[/color]: what

const DEFAULT_DEADZONE: float = 0.2

@export var deadzone: float = DEFAULT_DEADZONE
@export var events: Array[InputEvent] = []

## Deep copy of deadzone + events (events are duplicated).
func duplicate_action() -> InputMapAction:
	var out := InputMapAction.new()
	out.deadzone = deadzone
	for ev: InputEvent in events:
		if ev != null:
			out.events.append(ev.duplicate())
	return out
