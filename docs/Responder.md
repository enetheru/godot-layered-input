# Responder

One layer in the input branch. The manager is [[InputManager]].

A layer delegates to one or more targets. The target stays in the world or the UI. It is not a child of this branch, and mounting a layer does not reparent the target. A priority lets one layer serve several targets. Until that field exists, sibling position is the order. Depth in the branch is how a key changes meaning.

**Map**
  `input_map` is the one [[CustomInputMap]] this layer contributes while it is active. Each row of that map is an [[InputAction]].

**Active**
  An inactive layer is skipped by delivery and left out of the merge. Toggling it does not rebuild the order cache.

## Storage

SceneTree keeps a parent pointer and a child list, and every walk chases those links. This branch stores layers in slots and walks a packed cache.

**Slots**
  Each layer is a slot. A slot id carries a generation, so a layer removed during a pass cannot be called through a stale index.

**One order**
  The order cache is a contiguous list of slot ids. Parent, then children, siblings from first to last. Merge walks it forward. Delivery and teardown walk it backward, so a child still runs before its parent and a later sibling still runs first. A second cached sequence would be a copy of that reverse.

**Subtree**
  A layer's descendants occupy the slice from its index through its last descendant. Asking whether a branch affects the map is a scan of that slice.

**Edits**
  Append, erase, and a change of parent rebuild the order cache. The walk itself is an index along that array. It does not recurse and it does not follow a child pointer.

**Priority**
  When a priority field exists it changes the comparator that writes the cache. The forward and backward scans stay as they are.
