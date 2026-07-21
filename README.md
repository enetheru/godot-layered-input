# Custom Input Map Editor

Self-contained Godot 4 addon for layered input maps and an editor UI.

## Features

- **`CustomInputMap` / `InputMapAction`** — serializable action-layer resources
- **`InputManager` + `Responder`** — runtime merge of active maps onto the engine `InputMap`
- **`InputMapEditor`** — tree UI for editing maps (runtime or editor)
- **Editor plugin** — inspecting a `CustomInputMap` resource embeds the editor in the Inspector

## Install

1. Copy `addons/enetheru.input_map_editor` into your project.
2. Enable **Custom Input Map Editor** under Project → Project Settings → Plugins.
3. (Optional) Autoload the manager:

   ```
   InputManager = *res://addons/enetheru.input_map_editor/systems/input_manager.gd
   ```

## Usage

### Edit a resource in the editor

Create or open a `CustomInputMap` `.tres`. The Inspector shows the full action/event editor. Changes call `emit_changed()` so the asset can be saved.

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
  plugin.cfg / plugin.gd / inspector_plugin.gd
  systems/   # CustomInputMap, InputMapAction, InputManager, Responder
  ui/        # InputMapEditor scene + event config dialog + icons
```

No dependency on project-specific bases (`ENode`, `ERes`, `Core`, `EneLog`).
