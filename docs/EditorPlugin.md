# Editor plugin

`plugin.gd` is an `EditorPlugin`. It authors a [[CustomInputMap]] while the Godot editor is open. [[Runtime]] mounts each [[Responder]] and runs the game's input passes.

## Host

`input_map_editor/host_mode` chooses where the panel appears: a dock, a main screen, or the inspector. `host_session.gd` stores the host that was actually built. Detach closes the host that object stored, the one built at attach, which still closes the right panel after `host_mode` has changed. If the setting changes while the plugin stays enabled, the plugin builds the new host in place, and the panel moves with the plugin still on. The dock path uses Godot 4.7 `EditorDock`.

### The panel

`ui/input_map_editor.tscn` is the control those hosts show. The event dialog and the listen field edit one `InputEvent` at a time, which is the same job as the engine's action map. The scenes use calls a running game can make, which is why a game can instance the same control and why export keeps `ui/`. Opening the panel from the editor is this plugin's job. A game that instances the scene is using the control. The plugin is what opens that control inside the editor.

## Project settings

The prefix is `input_map_editor/`. `settings/input_map_editor_settings.gd` is the options resource the features read. `settings/settings.gd` copies that resource to and from `ProjectSettings`. A feature reads the options resource. `settings/logging.gd` is the logger that copier uses when a copy fails.

**host_mode**
  Dock, main screen, or inspector. Applied when the plugin attaches, and again when the setting changes while the plugin stays enabled.

**auto_raise**
  Brings the dock or the main screen forward when a map is selected, so the panel is what is on screen after the selection. Default on.

**default_deadzone**
  The deadzone the panel offers when an action is created in the editor. [[CustomInputMap]] and [[InputAction]] still use `0.2` until this setting is passed into those resources. Until then the editor default and the runtime constant can disagree.

**panel_min_height**
  Minimum height of the dock and of the inspector editor, so the action list stays usable when the host is short. Default `280`.

## What it writes

A name at the default deadzone, ahead of any events, is stored as `null` on the map. That matches [[CustomInputMap]], where `null` reserves the name. The inspector may store an empty [[InputAction]] for the same row when the property editor needs an object to draw. `emit_changed` is what marks the `.tres` dirty, so Godot offers to save it.

When a scene shares the map, the inspector shows the action as linked. Make the map unique. An override on the action alone writes through to the shared map, so the row the editor showed as local stays the shared one.

## Export

`export_plugin.gd` reads `.exportignore`. The pck keeps `systems/`, which is [[Runtime]], and `ui/`, which a game may instance. The plugin entry, `test/`, the README, and `docs/` stay in the repository, where they run the editor and explain the addon. `docs/screenshot.jpg` is a picture of this editor.
