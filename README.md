# Layered Input Addon for Godot

I was working away on my game, and ran into a puzzle on how to manage the input.

It came about because the escape key has many many different purposes. Depending
on which nodes are visible, I wanted to change what happens when I press the key.

It could be asking to quit, toggle the menus, or go back through the menus.

The existing node tree heirarchy was not an appropriate abstraction for what I
was wanting, and its not the first time I have run into problems trying to use
the single graph for multiple cross purposes.

So I created an `InputManager` auto load, ensured it was the last child or the root
and that guarantees that it will process events before the rest of the tree.

The `InputManager` has a `Responder` node child which is a root node of a tree of 
`Responder` nodes.

Each `Responder` node has a reference to a `CustomInputMap` resource

The `CustomInputMap` resource contains a dictionary of action names, and 
`InputAction` resources. which is a 1:1 representation of what the editor provides.


## How it works:

On initialisation, and when the tree is modified, the `InputManager` walks the
responder-tree merging the `CustomInputMaps` and then replaces the actions in
the engines `InputMap` singleton.

> [!NOTE] It's important to note that any nodes processing input must only reference 
actions which are valid, or errors will be recevied in the console.

This gives us a layerable input map which is easily modifiable ar runtime by
re-arranging and managing the responder-tree.

Where this de-couples from the main scene tree is that because the `InputManager` is
the last child, it's input processing comes first, so delegating input functionality
to `Responder` node overrides handles the input before it reaches the main tree.

At the moment I tend to make my `Responder` overrides extra simple, and keep a 
priority list of delegates to forward input to, which keeps the input handling code
on the objects in the main tree.

I believe this is similar to how other engines do things using pseudo trees, and 
whatever.

## Making it easier:

Editing the `CustomInputMap` resource in the inspector was a real PITA, there is no
way I was going to spend the time to replicate the engine UI, so I got Grok to
port it from the engine code, and spent far too much time making it nicer.

The `InputMapEditor` plugin can be a dock, custom inspector, or a main screen plugin.

It's been a day so I'm sure there will be bugs, but the interface code is secondary
to the functionality. I just wanted the same experience as what the editor provides.

## Features

- **`CustomInputMap` / `InputAction`** — serializable action-layer resources
- **`InputManager` + `Responder`** — runtime merge of active maps onto the engine `InputMap`
- **`InputMapEditor`** — a control for editing the `CustomInputMap`
- **Editor plugin** — as either a dock panel, a main screen, or an inspector. requires enable/disable

## Project Settings

Prefix: `input_map_editor/` (Project → Project Settings → General, search “input map”).

| Setting | Default | Notes |
|---------|---------|--------|
| `host_mode` | Dock | Enum: **Dock** · **Main screen** · **Inspector**. |
| `auto_raise` | `true` | Focus dock / main screen when a map is selected. |
| `default_deadzone` | `0.2` | Authoring default (more wiring later). |
| `panel_min_height` | `280` | Min height for dock / inspector editors. |

## Requirements

**Dock** uses Godot 4.7+ `EditorDock` + `add_dock` with vertical, horizontal, and floating layouts (not the older bottom-panel-only API).

## Install

1. This repository can be cloned into the addons folder, and names whatever, all internal references are relative.
2. Enable **Layered Input** under Project → Project Settings → Plugins.
3. (Optional) Add the InputManager to global autoloads `/systems/input_manager.gd`

## Usage

### Edit a resource in the editor

Create or open a `CustomInputMap` `.tres`. The **Input Map** bottom panel loads it (same slot as Animation / Phantom Camera). Changes call `emit_changed()` so the asset can be saved.

### Runtime layers

```gdscript
var layer := CustomInputMap.new()
layer.add_action(&"jump")
# bind events...

var responder := Responder.new()
responder.input_map = layer
InputManager.add_responder(responder)
```

## Layout

```
  plugin.cfg / plugin.gd / export_plugin.gd / .exportignore
  settings/  # Plugin settings resource, 
  systems/   # CustomInputMap, InputAction, InputManager, Responder
  ui/        # InputMapEditor scene + event config dialog + icons
  test/      # Headless smoke (excluded from export)
```

## Export

`export_plugin.gd` reads `.exportignore` and calls `skip()` so editor-only
files (plugin entry, smoke tests, README) are not packed into exports.
Runtime `systems/` and in-game `ui/` remain available in the pck.
