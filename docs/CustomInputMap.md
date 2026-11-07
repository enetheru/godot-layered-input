# Custom input map

A [[Responder]] holds one of these while it is active. [[InputManager]] merges the active maps and writes the result onto Godot's `InputMap`. Each row is an [[InputAction]], or a name reserved ahead of one. [[EditorPlugin]] is the panel that writes the `.tres`. This page is the resource the game merges.

The layer branch is the source, and the engine map is the projection. The maps that reach the engine are the ones active responders contribute. The autoload's root responder contributes `settings/default_input_map.tres`, and that asset is one of these maps.

## Names and rows

`_actions` is a `Dictionary` from `StringName` to `InputAction`. `for action_name in map` yields the names in `get_action_names` order.

### Placeholder

`null` reserves a name at the default deadzone. `add_action` stores that when the new name is in that state, and the name sits in the map until events or another deadzone allocate an `InputAction`. An empty `InputAction` is the same reservation with an object the inspector can draw. Both keep the name in the map.

### Deadzone defaults

`0.2` is the deadzone for a new action. `0.5` is the deadzone for toggle-style actions, which is the engine's habit for many `ui_*` binds. The editor's `default_deadzone` setting is a separate number until it is passed into this resource. [[EditorPlugin]] records that gap.

## Writing

The methods are the structure changes the resource publishes. Listeners and the rebuild follow those calls. An in-place write on the dictionary stays local to the caller.

### add_action

A new name at the default deadzone, ahead of any events, stores `null` and returns `null`. Events, or a deadzone other than the default, allocate an `InputAction`. Calling the method again on a live action adds bindings. The deadzone updates, and the new events append to the ones already there.

### merge

`merge` folds another map in place. The same name is replaced wholesale. The incoming event list becomes that action, because a later layer's meaning of the name replaces the earlier one. The incoming map wins when `overwrite` is true, which is the default. `duplicate_map` copies the incoming map, so each layer keeps its own action.

### Engine

`apply_to_engine` writes each name this map contains onto the engine `InputMap`. The usual path erases that name and adds it back from this map, so the engine action matches this map's events. The write covers those names. The rest of the engine map stays as the other layers left it. `from_engine` snapshots the engine map into a new resource.

## Authoring

Build the map in code and assign it on a responder, or hand-author a `.tres`. `emit_changed` marks the resource dirty. How the editor saves that file, including the linked-action case, is [[EditorPlugin]].
