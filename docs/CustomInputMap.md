# Custom input map

One layer's action table. A [[Responder]] holds one while it is active. [[InputManager]] merges the active maps and writes the result onto the engine `InputMap`. Each row is an [[InputAction]], or a name that does not have one yet.

There is no hidden project-settings base inside the resource. Only maps that active responders contribute reach the engine. The autoload's root responder contributes `settings/default_input_map.tres`, and that asset is one of these maps.

## Names and rows

`_actions` is a `Dictionary` from `StringName` to `InputAction`. `for action_name in map` yields the names in `get_action_names` order.

**Placeholder**
  `null` is a name with no events yet. The panel adds a name that way. An empty `InputAction` is also legal, and that is what the inspector stores when it creates the sub-resource itself.

**Deadzone defaults**
  `0.2` for a new action. `0.5` for toggle-style actions, the engine's habit for many `ui_*` binds.

## Writing

Mutate through the methods. An in-place dictionary write does not refresh the inspector, and it is easy for that edit to vanish on save.

**add_action**
  A new name with no events and the default deadzone stores `null` and returns `null`. Events, or a non-default deadzone, materialise an `InputAction`. Calling it again on a live action does not wipe that action. The deadzone updates, and the new events are appended.

**merge**
  Folds another map in place. The same name is replaced wholesale. Event lists are not concatenated. The incoming map wins when `overwrite` is true, which is the default. That is how a later layer beats an earlier one. `duplicate_map` is the copy used so the two maps do not alias one action.

**Engine**
  `apply_to_engine` writes each name this map contains onto the engine `InputMap`. The default path erases that name and adds it back from this map. Names this map does not contain are left alone. `from_engine` snapshots the engine map into a new resource.

## Authoring

Hand-author a `.tres` and assign it on a responder, or build the map in code. `emit_changed` is what tells the editor the asset is dirty. The editor for that `.tres` is the plugin described in [[Addon]].
