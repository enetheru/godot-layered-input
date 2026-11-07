# Input action

One row inside a [[CustomInputMap]]. It holds a deadzone and an ordered list of `InputEvent`s, which is the same pair Godot stores on an engine action. The resource exists so a layer can carry that pair. How the inspector saves the row is [[EditorPlugin]].

Build one through `CustomInputMap.add_action`, or author it as a sub-resource inside the map `.tres`.

## Fields

### Deadzone

The default is `0.2`, the same constant the map uses for a new action. The setter emits `changed` when the value moves. Writing the same number leaves the resource as it was.

### Events

`events` is the binding list, in storage order. `for event in action` walks that list and yields the stored events, passing over empty slots. `add_event`, `erase_event`, and `clear_events` update that list. Replacing the whole array emits `changed` as well.

## Where it lives

An action lives embedded in its map `.tres`. The row belongs to that table. An action built in code sets `resource_local_to_scene`, so a scene that makes the map local gets its own action. The inspector's linked-versus-unique behaviour is [[EditorPlugin]].

`duplicate_action` is the copy `merge` uses, so each layer keeps its own event list. A bind on the later layer stays on that copy.
