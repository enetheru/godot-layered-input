# Custom Input Map Editor

Self-contained Godot 4 addon for layered input maps and an editor UI.

## Features

- **`CustomInputMap` / `InputAction`** — serializable action-layer resources
- **`InputManager` + `Responder`** — runtime merge of active maps onto the engine `InputMap`
- **`InputMapEditor`** — tree UI with two operation modes:
  - **EDITOR** — edit a `CustomInputMap` asset (writable)
  - **MONITOR** — inspect live effective / loaded maps from a running game (read-only host)
- **Editor plugin** — default **bottom panel** "Input Map"; optional main screen or inspector host

## Project Settings

Prefix: `input_map_editor/` (Project → Project Settings → General, search “input map”).

| Setting | Default | Notes |
|---------|---------|--------|
| `host_mode` | Dock | Enum: **Dock** · **Main screen** · **Inspector**. **Disable & re-enable the plugin** after change. |
| `auto_raise` | `true` | Focus dock / main screen when a map is selected. |
| `default_deadzone` | `0.2` | Authoring default (more wiring later). |
| `panel_min_height` | `280` | Min height for dock / inspector editors. |

Settings use `set_initial_value` + `ProjectSettings.save()` so they survive plugin unload.

**Dock** uses Godot 4.7+ `EditorDock` + `add_dock` with vertical, horizontal, and floating layouts (not the older bottom-panel-only API).

**Main screen** = main-screen plugin tab (`get_editor_main_screen().add_child`, `_has_main_screen`, `_make_visible`).

## Install

1. Copy `addons/enetheru.input_map_editor` into your project.
2. Enable **Custom Input Map Editor** under Project → Project Settings → Plugins.
3. (Optional) Autoload the manager:

   ```
   InputManager = *res://addons/enetheru.input_map_editor/systems/input_manager.gd
   ```

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

### Embed the UI in-game

```gdscript
var editor := preload("res://addons/enetheru.input_map_editor/ui/input_map_editor.tscn").instantiate()
editor.edit_map = my_map
add_child(editor)
# or editor.configure_for_resource(my_map) for pure resource mode
```

## Layout

```
addons/enetheru.input_map_editor/
  plugin.cfg / plugin.gd / export_plugin.gd / .exportignore
  systems/   # CustomInputMap, InputAction, InputManager, Responder
  ui/        # InputMapEditor scene + event config dialog + icons
  test/      # Headless smoke (excluded from export)
```

No dependency on project-specific bases (`ENode`, `ERes`, `Core`, `EneLog`).

## Export

`export_plugin.gd` reads `.exportignore` and calls `skip()` so editor-only
files (plugin entry, smoke tests, README) are not packed into exports.
Runtime `systems/` and in-game `ui/` remain available in the pck.
