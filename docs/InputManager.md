# Input Manager

Godot only has a singular `InputMap` and it is even made as a singleton for some reason.
I want multiple action maps, and depending on the context I enable/disable them.
So I created the Layered Input Addon to solve that need.

The autoload class is `_InputManager`. A layer is a link responder. A layer's table is a [[CustomInputMap]], and a row in that table is an [[InputAction]]. This page is the runtime side. [[EditorPlugin]] writes the tables in the editor, and [[Runtime]] is the index for the program the game loads.

The autoload is the one node the viewport calls. It owns a link tree. Adding and removing a layer edits that tree.

## The branch

This system keeps its own tree of layers, and one node in Godot's tree so the viewport will call it. The main scene graph stays the scene graph.

Godot delivers `_input` in reverse depth-first order. For any node it visits children from last to first, then the node itself. `_unhandled_input` and `_unhandled_key_input` are later passes. Controls sit between `_input` and `_unhandled_input`.

The autoload moves itself to the last child of the root. Among that parent's children this branch is the first entry point for events.

## What the manager does

The manager holds the layer tree and projects it onto the engine `InputMap`. Domain code decides when a layer exists. The manager records that decision.

### Delivery

The manager implements `_input`, `_shortcut_input`, `_unhandled_key_input`, and `_unhandled_input`, in the order Godot already uses, so a caller meets the names they know. `_input` runs before the GUI. `_shortcut_input` runs after it for a key, a shortcut, or a joypad button. `_unhandled_key_input` runs for a key that is still unhandled. `_unhandled_input` runs for anything still left. Each pass calls the tree's walk for that callback. The walk starts at the front, because the last child was stored at the far end of the parent list and the walk reads that list backwards. A callback marks the viewport handled to stop the pass. The remaining callables stay in the copy this event started with.

### Merged map

The link tree reads each contributing layer's `CustomInputMap` from that same front. A name the front wrote stays, so a later layer's row for that name is left unread. That skip is the work a second copy would throw away. A stock row shares the stock map's events, so a later compose does not duplicate them. A gameplay row keeps its copy while the source events stay the same. Adding, removing, activating, or swapping a layer patches the names that layer owns, and those edits in one frame land as one table. Delivery and `Input.get_vector` read the table the engine was given.

### Edits during a pass

A handler may mount a layer while an event is still being delivered. The stored walks rebuild at the change. The pass keeps the callables it copied at the start, so this key finishes on the tree that was current when it arrived. The map rebuild waits until idle, which is why the engine table and the walks can move on different frames.

## Lifecycle

Mount and unmount are `add_responder` and `remove_responder`. The layer record stays with its owner. Context, UI, and agents own going back.

## Still open

Priority is unset. A layer binds one callable. A list of targets waits until a layer needs more than one. The autoload enables every pass when it enters the tree. Enabling a pass only while its walk has a member is a later saving.
