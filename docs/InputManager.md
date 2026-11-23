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

The manager implements `_input`, `_shortcut_input`, `_unhandled_key_input`, and `_unhandled_input`. Each pass calls the link tree's walk for that callback. The walk starts at the front. A callback marks the viewport handled to stop the pass.

### Merged map

The link tree merges each active layer's `CustomInputMap`. A name the front of the walk wrote stays. Delivery reads that finished table. `request_rebuild` coalesces into one deferred rebuild when a contributing layer is added, removed, activated, or its map changes.

### Edits during a pass

A handler may mount a layer while an event is still being delivered. That change is queued. The order cache rebuilds when the pass returns, so the walk that is already in progress keeps the order it started with.

## Lifecycle

Mount and unmount are `add_responder` and `remove_responder`. The layer record stays with its owner. Context, UI, and agents own going back.
