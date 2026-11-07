# Files

## Runtime

What a running game loads, through the autoload [[InputManager]].

| File | Use |
|------|-----|
| `systems/custom_input_map.gd` | Defines [[CustomInputMap]], one layer's action table. |
| `systems/input_action.gd` | Defines [[InputAction]], the deadzone and the events for one action name. |
| `systems/input_manager.gd` | Defines `_InputManager`, the autoload. The note is [[InputManager]]. |
| `systems/responder.gd` | Defines [[Responder]], one layer. |
| `settings/default_input_map.tres` | The stock [[CustomInputMap]] for the root [[Responder]]. |

## EditorPlugin

What the Godot editor loads from `plugin.cfg`.

| File | Use |
|------|-----|
| `plugin.cfg` | Records the plugin name, the author, the version, and the path to `plugin.gd`. |
| `plugin.gd` | The [[EditorPlugin]] that hosts the panel. |
| `host_session.gd` | Holds the host in use: a dock, a main screen, or the inspector. |
| `inspector_plugin.gd` | The `EditorInspectorPlugin` that embeds the panel on a [[CustomInputMap]]. |
| `export_plugin.gd` | The `EditorExportPlugin` that skips paths listed in `.exportignore`. |
| `.exportignore` | Path patterns the export plugin skips. |
| `settings/settings.gd` | `SettingsHelper`. Copies an options resource to and from `ProjectSettings`. |
| `settings/input_map_editor_settings.gd` | `InputMapEditorSettings`. Host mode, auto-raise, the default deadzone, and the panel height. See [[EditorPlugin]]. |
| `settings/logging.gd` | The logger `SettingsHelper` calls. |
| `settings/logging_builtin.gd` | The builtin print logger. |
| `ui/input_map_editor.gd` | `InputMapEditor`. Edits a [[CustomInputMap]], or shows the live [[InputManager]]. |
| `ui/input_map_editor.tscn` | The scene for that panel. |
| `ui/event_config_dialog.gd` | `EventConfigDialog`. Edits one `InputEvent`. |
| `ui/event_config_dialog.tscn` | The scene for that dialog. |
| `ui/event_listener_line_edit.gd` | `EventListenerLineEdit`. Captures the next key, mouse button, or joy event as a bind. |
| `ui/icon_cache.gd` | `IconCache`. Action icons from the project or the engine SVGs. |
| `ui/res/sbf_*.tres` | `StyleBoxFlat` resources for the panel, the action row, the column title, the line edit, and the button states. |
| `test/smoke_input_map_editor.gd` | Checks the global classes and that the editor scene loads. |
| `test/smoke_input_map_editor.tscn` | The scene that runs that check. |

## Documentation

| File | Use |
|------|-----|
| `README.md` | [README](../README.md). How the addon came about, how to enable it, and where the files sit. |
| `docs/Files.md` | This catalogue of the addon files. |
| `docs/Runtime.md` | [[Runtime]]. What a running game loads. |
| `docs/EditorPlugin.md` | [[EditorPlugin]]. The host, the project settings, the inspector, and export. |
| `docs/InputManager.md` | [[InputManager]]. The autoload and the layer tree. |
| `docs/Responder.md` | [[Responder]]. One layer. |
| `docs/CustomInputMap.md` | [[CustomInputMap]]. The action table a layer contributes. |
| `docs/InputAction.md` | [[InputAction]]. One row of that table. |
| `docs/screenshot.jpg` | A [picture](screenshot.jpg) of the panel. |
