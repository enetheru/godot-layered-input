# Runtime

This is the code a running game loads. [[EditorPlugin]] is the other program in the same folder. It writes the `.tres` files in the editor. Gameplay events arrive through this side.

## Autoload

The project turns this side on by adding an autoload named `InputManager` whose script is `systems/input_manager.gd`. That name is what game code calls. The class in the script is `_InputManager`, because the autoload name already occupies `InputManager`. The Plugins list is a different switch. Enabling Layered Input there loads the editor panel and leaves this autoload alone.

## Layers

[[InputManager]] is the one node the viewport calls. A [[Responder]] is one layer on the branch that node owns. While a layer is active it contributes one [[CustomInputMap]], and each row of that map is an [[InputAction]]. The layer is how a context changes what a key means on Godot's single action table. The manager walks the active layers, merges those maps, and writes the result onto `InputMap`.

## Stock map

`settings/default_input_map.tres` is the [[CustomInputMap]] the autoload assigns to the root responder, so a project has a base layer before game code adds one. The file sits in `settings/` beside the scripts that configure the editor panel. Those scripts are plugin options. This file is a map the game merges.

## Where the layers sit

Today each layer is still a child node, so adding and removing one pays SceneTree enter and exit. [[InputManager]] and [[Responder]] describe the branch being built. The manager stays the one node in Godot's tree, layers live in a packed list, merge walks that list forward, and delivery walks it backward. The work list for that move is `agent_knowledge/ReplaceSceneTree/responder.md`.

## Files

The scripts live in `systems/`, together with the stock map above. The runtime half of [[Files]] is the full list, notes included.
