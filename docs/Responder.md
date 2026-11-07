# Responder

A responder is one layer in the input branch. [[InputManager]] owns the branch and is the node the viewport calls. [[EditorPlugin]] authors the maps. This branch is where the layers live.

## Delegation

A layer delegates to one or more targets. The target stays in the world or the UI. Mounting a layer leaves the target on the node that already owns it. A priority lets one layer serve several targets. Until that field exists, sibling position is the order. Depth in the branch is how a key changes meaning.

## What it contributes

The map and the active flag are separate. Active is what puts a mounted layer into the projection.

### Map

`input_map` is the one [[CustomInputMap]] this layer contributes while it is active. Each row of that map is an [[InputAction]].

### Active

Delivery and the merge include an active layer. The order cache records the shape of the branch. Active filters the walk, and toggling it leaves that cache as it is.

## Storage

SceneTree keeps a parent pointer and a child list, and every walk chases those links. This branch stores layers in slots and walks a packed cache.

### Slots

Each layer is a slot. A slot id carries a generation, so a call during a pass resolves to the layer that still owns that slot.

### One order

The order cache is a contiguous list of slot ids: parent, then children, siblings from first to last. Merge walks it forward. Delivery and teardown walk the same list backward, so a child runs before its parent and a later sibling runs first.

### Subtree

A layer's descendants occupy the slice from its index through its last descendant. Asking whether a branch affects the map is a scan of that slice, which is why the descendants have to sit together.

### Edits

Append, erase, and a change of parent rebuild the order cache. The walk itself is an index along that array. The packed list keeps that walk on the index.

### Priority

When a priority field exists it changes the comparator that writes the cache. The forward and backward scans stay as they are.
