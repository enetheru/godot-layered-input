# Addon

Layered Input lives at `addons/enetheru.layered-input`. It is a runtime and an editor that share the action types. [[Files]] says what each file is.

**Runtime**
  [[InputManager]] and [[Responder]]. The autoload name is `InputManager`, script `systems/input_manager.gd`. Domain code decides when a layer exists. The manager merges each active layer's [[CustomInputMap]] onto the engine `InputMap`. A row in that map is an [[InputAction]].

**Editor**
  The plugin in `plugin.cfg` edits a `CustomInputMap` with the same gestures as the engine's action map. It can be a dock, a main screen, or an inspector. Which one is the project setting `input_map_editor/host_mode`. The dock path needs Godot 4.7 `EditorDock`.

Enable the plugin to author maps. Add the autoload to run layers in a game. The two switches are separate. A project can author `.tres` files and never mount a responder, or mount responders and never open the dock.

Export keeps `systems/` and `ui/`. `export_plugin.gd` reads `.exportignore` and skips the plugin entry, the smoke test, and the README.

## Project settings

Prefix `input_map_editor/`. The plugin owns them. Features read `InputMapEditorSettings`, not raw `ProjectSettings` paths.

**host_mode**
  Dock, main screen, or inspector. Applied when the plugin attaches, and again if the setting changes while it is enabled.

**auto_raise**
  Focus the dock or the main screen when a map is selected. Default on.

**default_deadzone**
  Authoring default. The resources still use `0.2` until this setting is wired through.

**panel_min_height**
  Minimum height for the dock and the inspector editor. Default `280`.

## What is built, and what is next

Today a layer is still a child node. [[InputManager]] and [[Responder]] describe the branch being built: one node in Godot's tree, layers in a packed list, merge forward, delivery backward. The move off the child nodes is `agent_knowledge/ReplaceSceneTree/responder.md`.
