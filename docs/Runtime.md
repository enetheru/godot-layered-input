# Runtime

This is the code a running game loads. [[EditorPlugin]] is the other program in the same folder. It writes the `.tres` files in the editor. Gameplay events arrive through this side.

## Autoload

The project turns this side on by adding an autoload named `InputManager` whose script is `systems/input_manager.gd`. That name is what game code calls. The class in the script is `_InputManager`, because the autoload name already occupies `InputManager`. The Plugins list is a different switch. Enabling Layered Input there loads the editor panel and leaves this autoload alone.

## Layers

[[InputManager]] is the one node the viewport calls. It owns a link tree. A link responder is one layer on that tree. While a layer is active it contributes one [[CustomInputMap]], and each row of that map is an [[InputAction]]. The layer is how a context changes what a key means on Godot's single action table. The tree composes those maps and writes the result onto `InputMap`.

## Stock map

`settings/default_input_map.tres` is the [[CustomInputMap]] the autoload assigns to the root responder, so a project has a base layer before game code adds one. The file sits in `settings/` beside the scripts that configure the editor panel. Those scripts are plugin options. This file is a map the game merges.

The autoload also reads the engine `InputMap` once, before the first rebuild. That read keeps the engine's event objects. A name only the engine had stays, and it stays the engine's event. The stock map shares its events the same way. A name a gameplay responder defines replaces that row with a copy.

## Where the layers sit

The autoload is the one node in Godot's tree, and it stays the last child of the root so the viewport asks it before the rest of the scene. Each layer is a link responder in parent and child lists. The lists are stored parent, then children. The walk reverses that, so the last child is the front and sees the event first. The table writes from that same front, and a name written there stays. Dispatch calls the copy of the walk it took at the start of the pass and stops when the viewport is handled.

## Files

The scripts live in `systems/`, together with the stock map above. The runtime half of [[Files]] is the full list, notes included.
