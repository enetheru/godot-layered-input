# Responder

A responder is one context's claim on what an input means. [[InputManager]] owns the tree and is the node the viewport calls. The scene tree stays the drawing order. This record is the order a key should see.

## Why a separate tree

Godot walks `_input` from the last child of a parent back to that parent. A menu drawn on top of play already sits in that place. A key should also reach the layer the game pushed last, and that layer is often a different node from the one drawn last. The link tree stores the order the game means. The autoload stays the last child of the root so the viewport asks it first.

## Links

**parent**
  The responder this one hangs under. The root leaves it empty. The tree holds the root.

**children**
  The child responders, first to last. `add_responder` appends, so a layer added last is the front of its parent. The walk reads the stored order from the other end, which is why that last child sees the event first.

Master order is parent, then children. A root, a play child, and an inventory child of play stand as root, play, inventory. The walk reverses that list, so inventory is index 0. A menu added as the root's last child stands in front of that whole branch, which is how a screen pushed on the root covers the play branch without a second sort.

## Callbacks

The record has four callables, one for each pass the autoload receives. An empty callable leaves the responder out of that one walk. A caller fills the passes it handles and leaves the others empty. The callable may forward to a target that already lives on the world or the UI. Adding the responder leaves that target where it is.

**_input**
  The pass before the GUI.

**_shortcut_input**
  The pass after the GUI, for a key, a shortcut, or a joypad button.

**_unhandled_key_input**
  A key that is still unhandled after the shortcut pass.

**_unhandled_input**
  Anything still left after the key pass.

The tree caches each walk. Chasing parent and child links on every event would repeat the walk the last membership change already knew. Filling a slot, turning a record on, or adding a branch rebuilds the walks those records join, because the cache has no index for an insertion. Clearing a slot, turning a record off, or removing a branch erases those records from the cached walks and leaves the others in order.

A pass copies the records and the callables at its start. A handler may add or remove a responder before it returns, and this event still belongs to the responders that were in front when it arrived. The next event reads the walk the handler left behind.

## Map

**input_map**
  The one [[CustomInputMap]] this layer contributes.

**active**
  The process flag. `contributes_map()` is active with `input_map` set. An inactive parent stays out of the table. An active child is still visited, because that child is a context of its own.

The table reads the same front-to-back order as a walk. The front map is written first, and a name it wrote stays, including a name with no events. A menu in front can clear jump, and play's Space is left unread. A name only a layer behind defines is still written, so an action the menu never mentions keeps the binding from play.

A row from the stock map, or from the engine map captured at startup, shares that map's events. A gameplay map stores a copy, and the copy stays while the source action still holds the same event objects. The table itself stays. An edit rewrites the names that layer owns, or used to own, and leaves the other rows where they are.

`set_active` and `set_input_map` return when the value is already current. Each remembers whether the record was contributing, and asks the tree to patch when it contributed before the write or contributes after it. An edit made before the record is linked waits, because `_tree` is empty. A frame can add a responder, silence one, and swap a map. Those edits are one meaning, so they queue a single deferred compose and the engine sees one table. `request_rebuild` still composes every name, and an unchanged stock row stays in place for that pass too.

`add_responder` and `remove_responder` keep the record with the caller. The link is the parent pointer and one entry in `children`. The tree holds the root, and both calls take a child.
