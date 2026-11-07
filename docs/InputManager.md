# Input Manager

Godot only has a singular `InputMap` and it is even made as a singleton for some reason.
I want multiple action maps, and depending on the context I enable/disable them.
So I created the Layered Input Addon to solve that need.

The autoload class is `_InputManager`. A layer is a [[Responder]]. A layer's table is a [[CustomInputMap]], and a row in that table is an [[InputAction]]. This page is the runtime side. [[EditorPlugin]] writes the tables in the editor, and [[Runtime]] is the index for the program the game loads.

Today the layers are still child nodes. The branch below is the one being built, because adding and removing those nodes pays SceneTree enter and exit. The work list is `agent_knowledge/ReplaceSceneTree/responder.md`.

## The branch

This system keeps its own tree of layers, and one node in Godot's tree so the viewport will call it. The main scene graph stays the scene graph.

Godot delivers `_input` in reverse depth-first order. For any node it visits children from last to first, then the node itself. `_unhandled_input` and `_unhandled_key_input` are later passes. Controls sit between `_input` and `_unhandled_input`.

The autoload moves itself to the last child of the root. Among that parent's children this branch is the first entry point for events.

## What the manager does

The manager holds the layer tree and projects it onto the engine `InputMap`. Domain code decides when a layer exists. The manager records that decision.

### Delivery

The manager implements `_input`, `_unhandled_input`, and `_unhandled_key_input`. Each pass walks the packed order backward and calls that method on active layers, then stops when the event is handled. The three passes share one order and differ in the method each one calls.

### Merged map

A forward walk of the same order merges each active layer's `CustomInputMap`. A later layer overwrites an action of the same name. This merge is its own cache. Delivery reads that finished table. `request_rebuild` coalesces into one deferred rebuild when a contributing layer is added, removed, activated, or its map changes.

### Edits during a pass

A handler may mount a layer while an event is still being delivered. That change is queued. The order cache rebuilds when the pass returns, so the walk that is already in progress keeps the order it started with.

## Lifecycle

Mount and unmount are `add_responder`, `remove_responder`, and `pop_responder`. The layer object stays with its owner. Context, UI, and agents own going back.
