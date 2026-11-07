# Input action

One row inside a [[CustomInputMap]]. A deadzone and an ordered list of `InputEvent`s. The engine action is that same pair. This resource is the pair a layer can carry.

Build one through `CustomInputMap.add_action`, or author it as a sub-resource inside the map `.tres`.

## Fields

**Deadzone**
  Default `0.2`, the same constant the map uses for a new action. The setter emits `changed` when the value actually moves, so the input-map panel and the inspector stay on the same number.

**Events**
  `events` is the binding list, in storage order. `for event in action` walks that list and skips empty slots. `add_event`, `erase_event`, and `clear_events` refresh the inspector's array. Replacing the whole array emits `changed` as well.

## Where it lives

It is an embedded sub-resource of a map, not its own `.tres`. When a scene shares the map, the inspector shows the action as linked. Make the map unique. Making only the action unique often fails to stick, because a dictionary-value override does not save.

An action built in code sets `resource_local_to_scene`. A scene that then makes the map local does not keep sharing one action across scenes. `duplicate_action` is the copy `merge` uses, so two layers do not alias one event list.
