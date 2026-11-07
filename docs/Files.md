# Files

What each file in `addons/enetheru.layered-input` is for. `.uid` siblings are Godot's script ids. `.import` siblings are imported textures. Neither is listed again below. The design pages are [[Addon]], [[InputManager]], [[Responder]], [[CustomInputMap]], and [[InputAction]].

## Root

**plugin.cfg**
  Plugin manifest. Name, author, version, and `plugin.gd` as the entry.

**plugin.gd**
  `EditorPlugin`. Attaches the input-map editor in the host mode from project settings, and detaches it without reading those settings again.

**host_session.gd**
  The applied host for one attach or rehost. Dock, main screen, or inspector. Desired mode is read at attach. Detach uses this object only.

**inspector_plugin.gd**
  `EditorInspectorPlugin` used when the host mode is inspector. Embeds an `InputMapEditor` for a `CustomInputMap`.

**export_plugin.gd**
  `EditorExportPlugin`. Skips paths listed in `.exportignore` so editor-only files stay out of the pck.

**.exportignore**
  Those paths. Plugin entry, `test/`, and `README.md`. `systems/` and `ui/` are not in it, so a game build still has the runtime and the in-game editor control.

**README.md**
  Install notes and the original writeup of why the addon exists.

## settings

**settings.gd**
  `SettingsHelper`. Copies an options resource to and from `ProjectSettings` under a prefix. No `class_name`. The plugin preloads it.

**input_map_editor_settings.gd**
  `InputMapEditorSettings`. Host mode, auto-raise, default deadzone, panel height. This is the resource the helper syncs.

**default_input_map.tres**
  The stock `CustomInputMap` the autoload assigns to the root responder.

**logging.gd**
  Which logger this addon calls. Default is the builtin. Point it at another script when the project wants a richer log. No `class_name`, so other addons keep their own selector.

**logging_builtin.gd**
  The print fallback `logging.gd` uses when nothing else is selected.

## systems

**custom_input_map.gd**
  `CustomInputMap`. One layer's action table. See [[CustomInputMap]].

**input_action.gd**
  `InputAction`. Deadzone and events for one action name. See [[InputAction]].

**input_manager.gd**
  `_InputManager`. Autoload script. Owns the responder branch and projects the merged map onto the engine `InputMap`. See [[InputManager]].

**responder.gd**
  `Responder`. One layer node. Map, active flag, and the child list the branch still uses today. See [[Responder]].

## ui

**input_map_editor.gd**
  `InputMapEditor`. Port of the engine action-map editor. Edits a `CustomInputMap`, or inspects the live manager.

**input_map_editor.tscn**
  The scene that script sits on.

**event_config_dialog.gd**
  `EventConfigDialog`. Port of the engine's event configuration dialog. One `InputEvent`, then OK or Cancel.

**event_config_dialog.tscn**
  The scene for that dialog.

**event_listener_line_edit.gd**
  `EventListenerLineEdit`. While focused, the next key, mouse button, or joy event becomes the bind. Hold `ui_cancel` to release focus.

**icon_cache.gd**
  `IconCache`. Textures for the editor. Uses a project icon when one exists, otherwise a `DPITexture` from the same SVGs the engine editor uses.

**res/sbf_*.tres**
  `StyleBoxFlat` resources for the panel, the action-row halves, the column title, the line edit, and the button hover and disabled states.

## test

**smoke_input_map_editor.gd**
  Headless smoke. Checks the global classes and that the editor scene loads.

**smoke_input_map_editor.tscn**
  Scene entry for that smoke. Run this, so autoload names exist.

## docs

**Addon.md**
  What the package is. Runtime, editor, settings, export.

**InputManager.md**
  The branch the manager is growing into, and what it does on each pass.

**Responder.md**
  One layer, and the slot storage that replaces the child list.

**CustomInputMap.md**
  The action table a layer contributes.

**InputAction.md**
  One row of that table.

**Files.md**
  This list.

**screenshot.jpg**
  The editor, as shown at the top of the README.
