# Input Manager

Godot only has a singular `InputMap` and it is even made as a singleton for some reason.
I want multiple action maps, and depending on the context I enable/disable them.
So I created the Layered Input Addon to solve that need.

The addon is `addons/enetheru.layered-input`. The autoload class is `_InputManager`. A layer is a [[Responder]]. The package page is [[Addon]]. A layer's table is a [[CustomInputMap]], and a row in it is an [[InputAction]]. [[Files]] lists the tree.

Today the layers are still child nodes. The branch below is the one being built. The move off those nodes is `agent_knowledge/ReplaceSceneTree/responder.md`.

## The branch

The main scene graph cannot be the input order as well. It is one compromise after another. This system keeps its own tree of layers, and one node in Godot's tree so the viewport will call it.

Godot delivers `_input` in reverse depth-first order. For any node it visits children from last to first, then the node itself. `_unhandled_input` and `_unhandled_key_input` are later passes. Controls sit between `_input` and `_unhandled_input`.

The autoload moves itself to the last child of the root. Among that parent's children this branch is the first entry point for events.

## What the manager does

The manager holds the layer tree and projects it onto the engine `InputMap`. Domain code decides when a layer exists. The manager does not undo a mount.

**Delivery**
  The manager implements `_input`, `_unhandled_input`, and `_unhandled_key_input`. Each pass walks the packed order backward and calls that method on active layers, then stops when the event is handled. The three passes share one order and differ only in the method.

**Merged map**
  A forward walk of the same order merges each active layer's `CustomInputMap`. A later layer overwrites an action of the same name. This merge is its own cache. An input event never rebuilds it. `request_rebuild` coalesces into one deferred rebuild when a contributing layer is added, removed, activated, or its map changes.

**Edits during a pass**
  A handler may mount a layer while an event is still being delivered. That change is queued. The order cache rebuilds when the pass returns.

## Lifecycle

Mount and unmount are operations: `add_responder`, `remove_responder`, `pop_responder`. They do not free the layer and they keep no snapshot history. Context, UI, and agents own "go back".
