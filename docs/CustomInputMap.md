# Custom input map

A [[Responder]] holds one of these while it is active. [[InputManager]] merges the active maps and writes the result onto Godot's `InputMap`. Each row is an [[InputAction]], or a name reserved ahead of one. [[EditorPlugin]] is the panel that writes the `.tres`. This page is the resource the game merges.

The layer branch is the source, and the engine map is the projection. The maps that reach the engine are the ones active responders contribute. The autoload's root responder contributes `settings/default_input_map.tres`, and that asset is one of these maps.

## Names and rows

`_actions` is a `Dictionary` from `StringName` to `InputAction`. Its keys are the action names, in `get_action_names` order.

### Placeholder

`null` reserves a name at the default deadzone. `add_action` stores that when the new name is in that state, and the name sits in the map until events or another deadzone allocate an `InputAction`. An empty `InputAction` is the same reservation with an object the inspector can draw. Both keep the name in the map.

### Deadzone defaults

`0.2` is the deadzone for a new action. `0.5` is the deadzone for toggle-style actions, which is the engine's habit for many `ui_*` binds. The editor's `default_deadzone` setting is a separate number until it is passed into this resource. [[EditorPlugin]] records that gap.

## Writing

The methods are the structure changes the resource publishes. Listeners and the rebuild follow those calls. An in-place write on the dictionary stays local to the caller.

### add_action

A new name at the default deadzone, ahead of any events, stores `null` and returns `null`. Events, or a deadzone other than the default, allocate an `InputAction`. Calling the method again on a live action adds bindings. The deadzone updates, and the new events append to the ones already there.

### merge

`merge` folds another map in place. The same name is replaced wholesale when `overwrite` is true, which is the default, so a caller who merges back-to-front lets the incoming layer win. When `overwrite` is false, a name already stored stays, and the incoming row is left unread. `refresh` recopies the dictionary for the inspector. The duplicated events are kept while the source action still holds those same event objects. `duplicate_map` copies the incoming map, so each layer keeps its own action.

The tree keeps one table. `project_action` writes a single name into it. A stock map or the startup engine map shares its event objects. A gameplay map uses the cached duplicates. An existing row with the same deadzone and the same event objects stays, so the compose does not allocate that row again.

### Engine

`apply_to_engine` writes each name this map contains onto the engine `InputMap`. A name whose deadzone and event objects are already on the engine is left in place. Any other name is erased and added back from this map. The rest of the engine map stays as the other layers left it. `from_engine` copies the engine map into a new resource. `alias_from_engine` keeps the engine's event objects. The autoload stores that alias at startup. A name no layer wrote is shared from that alias. `apply_action` writes one name, which is how a patch leaves the rest of the engine map alone.

## Authoring

Build the map in code and assign it on a responder, or hand-author a `.tres`. `emit_changed` marks the resource dirty. How the editor saves that file, including the linked-action case, is [[EditorPlugin]].
