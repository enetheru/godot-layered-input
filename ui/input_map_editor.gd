@tool
class_name InputMapEditor
extends PanelContainer

##[codeblock]
##│ ___                _     __  __             ___    _ _ _
##│|_ _|_ _  _ __ _  _| |_  |  \/  |__ _ _ __  | __|__| (_) |_ ___ _ _
##│ | || ' \| '_ \ || |  _| | |\/| / _` | '_ \ | _|/ _` | |  _/ _ \ '_|
##│|___|_||_| .__/\_,_|\__| |_|  |_\__,_| .__/ |___\__,_|_|\__\___/_|
##╰─────────|_|─────────────────────────|_|──────────────────────────────
##[/codeblock]Action / event map editor UI.
##
## Port of Godot's `ActionMapEditor` (editor/settings/action_map_editor.*).
## Binds to [InputManager] by default:
##[br] • Root — editable map on [code]responder_root[/code]
##[br] • Effective — read-only merge currently applied to the engine
##[br] • Loaded — read-only hierarchy of every responder contribution
##[br][br]
##[color=goldenrod]TODO[/color]:Full style pass (name:Type, parens spacing) —
## file is large; host mutations and map API already aligned with CustomInputMap.
##[br][color=goldenrod]TODO[/color]:Rename @onready nodes with type suffixes.
##[br][color=goldenrod]TODO[/color]:Split tree build / host mutations / drag-drop
## into clearer #region blocks.

## Default pixel size for [TreeItem] buttons (layout uses texture size as-is).
const TREE_BUTTON_SIZE:Vector2i = Vector2i( 16, 16 )
## Preload avoids class_name placeholder failures while the plugin reloads.
const _EventListenerScript = preload(
		"res://addons/enetheru.input_map_editor/ui/event_listener_line_edit.gd" )

enum ItemButton {
	ADD_EVENT,
	EDIT_EVENT,
	REMOVE_ACTION,
	REMOVE_EVENT,
	REVERT_ACTION,
}

## Operation modes for the panel (editor tooling vs live inspection).
enum OperationMode {
	## Edit a [CustomInputMap] asset (writable). Used by the bottom-panel plugin.
	EDITOR,
	## Inspect live InputManager state (effective / loaded layers). Prefer read-only.
	MONITOR,
}

## One row in the action list (mirrors ActionMapEditor::ActionInfo).
class ActionInfo:
	var name: String = ""
	## [code]{"events": Array[InputEvent], "deadzone": float}[/code]
	var action: Dictionary = {}
	var has_initial: bool = false
	var action_initial: Dictionary = {}
	var icon: Texture2D
	var editable: bool = true


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

@onready var filter_name_line_edit: LineEdit = $VBoxContainer/EditorEventSearchBar/FilterNameLineEdit
## Typed as LineEdit: during plugin reload the script may be a placeholder without
## EventListenerLineEdit methods (see _listener_* helpers).
@onready var event_listener_line_edit: LineEdit = $VBoxContainer/EditorEventSearchBar/EventListenerLineEdit
@onready var clear_all_button: Button = $VBoxContainer/EditorEventSearchBar/ClearAllButton

@onready var line_edit: LineEdit = $VBoxContainer/HBoxContainer/LineEdit
@onready var add_button: Button = $VBoxContainer/HBoxContainer/AddButton

@onready var root_check_button: CheckButton = $VBoxContainer/ViewToggles/RootCheckButton
@onready var effective_check_button: CheckButton = $VBoxContainer/ViewToggles/EffectiveCheckButton
@onready var loaded_check_button: CheckButton = $VBoxContainer/ViewToggles/LoadedCheckButton

@onready var tree: Tree = $VBoxContainer/MarginContainer/Tree
@onready var event_config_dialog: EventConfigDialog = $InputEventConfigurationDialog

## Optional map override. When null (and not MONITOR), edits InputManager root map.
## In multi-map EDITOR mode this is the active/context map (add-action target).
@export var edit_map: CustomInputMap

## When true, after writing to the target map, also call
## [method CustomInputMap.apply_to_engine]. Prefer rebuild via InputManager instead.
@export var apply_edit_map_to_engine: bool = false

## Current panel mode. EDITOR = resource tooling; MONITOR = running-game inspection.
@export var operation_mode: OperationMode = OperationMode.EDITOR:
	set = set_operation_mode

## Pure resource editing (editor plugin). Hides runtime view toggles
## and never touches [InputManager]. Prefer [member operation_mode] == EDITOR.
var resource_edit_mode: bool = false:
	set(v):
		resource_edit_mode = v
		if v:
			operation_mode = OperationMode.EDITOR

## Maps open in the tree (each gets a path root). Empty falls back to [member edit_map].
var open_maps: Array[CustomInputMap] = []

var _refreshing: bool = false

var _show_root: bool = true
var _show_effective: bool = false
var _show_loaded: bool = false

var _current_action: Dictionary = {}
var _current_action_name: String = ""
var _current_action_event_index: int = -1
## Map that owns the action currently being edited (event dialog / host mutations).
var _current_map: CustomInputMap

var _message: AcceptDialog
var _button_icon_add: Texture2D
var _button_icon_edit: Texture2D
var _button_icon_remove: Texture2D
var _button_icon_revert: Texture2D

## Joined action-row chrome (engine prop_subsection_stylebox_left/right).
@export var _sb_subsection_left: StyleBoxFlat = preload("uid://c3k1jnturrkkh")
@export var _sb_subsection_right: StyleBoxFlat = preload("uid://c2y7w6vs0t42r")


#            ███████ ██  ██████  ███    ██  █████  ██      ███████             #
#            ██      ██ ██       ████   ██ ██   ██ ██      ██                  #
#            ███████ ██ ██   ███ ██ ██  ██ ███████ ██      ███████             #
#                 ██ ██ ██    ██ ██  ██ ██ ██   ██ ██           ██             #
#            ███████ ██  ██████  ██   ████ ██   ██ ███████ ███████             #
func                        _________SIGNALS_________              ()->void:pass

signal action_added(name: String)
signal action_edited(name: String, new_action: Dictionary)
signal action_removed(name: String)
signal action_renamed(old_name: String, new_name: String)
signal action_reordered(action_name: String, relative_to: String, before: bool)
## Emitted after the target [CustomInputMap] is mutated (for editor dirty/save).
signal resource_modified(map: CustomInputMap)


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

#region View Filtering
#MARK: View Filtering
func                        __View_Filtering_________              ()->void:pass
##    │__   ___              ___ _ _ _           _
##[br]│\ \ / (_)_____ __ __ | __(_) | |_ ___ _ _(_)_ _  __ _
##[br]│ \ V /| / -_) V  V / | _|| | |  _/ -_) '_| | ' \/ _` |
##[br]│  \_/ |_\___|\_/\_/  |_| |_|_|\__\___|_| |_|_||_\__, |
##[br]╰────────────────────────────────────────────────|___/───

func _on_search_bar_value_changed() -> void:
	_update_clear_all_enabled()
	refresh()


func _on_search_event_changed(event: InputEvent) -> void:
	if event != null and (not event.is_pressed() or event.is_echo()):
		return
	_on_search_bar_value_changed()


func _on_clear_all_search() -> void:
	filter_name_line_edit.set_block_signals(true)
	filter_name_line_edit.clear()
	filter_name_line_edit.set_block_signals(false)
	if is_instance_valid(event_listener_line_edit):
		event_listener_line_edit.set_block_signals(true)
		_listener_clear_event(event_listener_line_edit)
		event_listener_line_edit.set_block_signals(false)
	_on_search_bar_value_changed()


func _on_view_toggles_changed() -> void:
	_show_root = root_check_button.button_pressed
	_show_effective = effective_check_button.button_pressed
	_show_loaded = loaded_check_button.button_pressed
	# Keep at least one view visible.
	if not _show_root and not _show_effective and not _show_loaded:
		_show_root = true
		root_check_button.set_pressed_no_signal(true)
	refresh()

#endregion View Filtering


#region Add Action
#MARK: Add Action
func                        __Add_Action_____________              ()->void:pass
##│   _      _    _     _      _   _
##│  /_\  __| |__| |   /_\  __| |_(_)___ _ _
##│ / _ \/ _` / _` |  / _ \/ _|  _| / _ \ ' \
##│/_/ \_\__,_\__,_| /_/ \_\__|\__|_\___/_||_|
##╰─────────────────────────────────────────────

func _on_add_edit_text_changed(action_name: String) -> void:
	var err := _check_new_action_name(action_name)
	# This is just weird, setting the tooltip to be the error, not changing the
	# style of the box or showing any sort of live error.
	# FIXME, make it make sense in a more standard way.
	# Show the exact characters that are the problem.
	add_button.tooltip_text = err if not err.is_empty() else "Add action to root map"
	add_button.disabled = not err.is_empty()


func _on_add_action_pressed() -> void:
	# Snapshot text before any focus-change side effects.
	var typed:String = line_edit.text
	_submit_new_action(typed)


func _on_add_action_submitted(submitted: String) -> void:
	_submit_new_action(submitted)

#endregion Add Action

func _on_action_edited() -> void:
	var ti := tree.get_edited()
	if ti == null or not _item_is_editable(ti):
		return
	_set_mutation_context(ti)
	var col := tree.get_edited_column()
	if col == 0:
		var new_name := ti.get_text(0).strip_edges()
		var old_name: String = ti.get_meta(&"__name")
		if new_name == old_name:
			return
		if new_name.is_empty():
			ti.set_text(0, old_name)
			show_message("Action name cannot be empty.")
			return
		if not _is_action_name_valid(new_name):
			ti.set_text(0, old_name)
			show_message("Invalid action name. It cannot contain '/', ':', '=', '\\' or '\"'.")
			return
		if _map_has_action(_get_mutation_map(), new_name):
			ti.set_text(0, old_name)
			show_message("An action with the name '%s' already exists." % new_name)
			return
		action_renamed.emit(old_name, new_name)
	elif col == 1:
		var action_name: String = ti.get_meta(&"__name")
		var old_action: Dictionary = ti.get_meta(&"__action")
		var new_action: Dictionary = old_action.duplicate(true)
		new_action["deadzone"] = ti.get_range(1)
		action_edited.emit.call_deferred(action_name, new_action)


func _on_tree_item_selected() -> void:
	var item := tree.get_selected()
	if item == null:
		return
	_set_mutation_context(item)


func _on_event_config_confirmed() -> void:
	var ev: InputEvent = event_config_dialog.get_event()
	if ev == null:
		show_message("No input event was configured.")
		return
	if _current_action_name.is_empty():
		show_message("No action selected for this event.")
		return
	var new_action: Dictionary = _current_action.duplicate(true)
	var action_events: Array = new_action.get("events", [])
	var events: Array = action_events.duplicate()
	# Store a duplicate so the dialog can clear its state without affecting the map.
	var stored: InputEvent = ev.duplicate()
	if _current_action_event_index == -1:
		events.append(stored)
	else:
		events[_current_action_event_index] = stored
	new_action["events"] = events
	action_edited.emit(_current_action_name, new_action)


#region Tree Item Events
#MARK: Tree Item Events
func                        __Tree_Item_Events_______              ()->void:pass
##│ _____              ___ _               ___             _
##│|_   _| _ ___ ___  |_ _| |_ ___ _ __   | __|_ _____ _ _| |_ ___
##│  | || '_/ -_) -_)  | ||  _/ -_) '  \  | _|\ V / -_) ' \  _(_-<
##│  |_||_| \___\___| |___|\__\___|_|_|_| |___|\_/\___|_||_\__/__/
##╰─────────────────────────────────────────────────────────────────

func _on_tree_button_pressed(item: TreeItem, _column: int, id: int, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return
	if item == null:
		return

	match id:
		ItemButton.ADD_EVENT:
			if not _item_is_editable(item):
				return
			_set_mutation_context(item)
			_current_action = item.get_meta(&"__action")
			_current_action_name = item.get_meta(&"__name")
			_current_action_event_index = -1
			event_config_dialog.popup_and_configure(null, _current_action_name, _current_action)

		ItemButton.EDIT_EVENT:
			if not _item_is_editable(item):
				return
			var parent := item.get_parent()
			_set_mutation_context(parent)
			_current_action = parent.get_meta(&"__action")
			_current_action_name = parent.get_meta(&"__name")
			_current_action_event_index = item.get_meta(&"__index")
			var ie: InputEvent = item.get_meta(&"__event")
			if ie:
				event_config_dialog.popup_and_configure(ie, _current_action_name, _current_action)

		ItemButton.REMOVE_ACTION:
			if not _item_is_editable(item):
				return
			_set_mutation_context(item)
			action_removed.emit(item.get_meta(&"__name"))

		ItemButton.REMOVE_EVENT:
			if not _item_is_editable(item):
				return
			var parent := item.get_parent()
			_set_mutation_context(parent)
			var parent_action: Dictionary = parent.get_meta(&"__action")
			var action: Dictionary = parent_action.duplicate(true)
			var action_name: String = parent.get_meta(&"__name")
			var event_index: int = item.get_meta(&"__index")
			var action_events: Array = action.get("events", [])
			var events: Array = action_events.duplicate()
			events.remove_at(event_index)
			action["events"] = events
			action_edited.emit(action_name, action)

		ItemButton.REVERT_ACTION:
			if not _item_is_editable(item):
				return
			if not item.has_meta(&"__action_initial"):
				push_error("Revert requested without __action_initial meta.")
				return
			_set_mutation_context(item)
			var initial: Dictionary = item.get_meta(&"__action_initial")
			var action: Dictionary = initial.duplicate(true)
			var action_name: String = item.get_meta(&"__name")
			action_edited.emit(action_name, action)


func _on_tree_item_activated() -> void:
	var item := tree.get_selected()
	if item == null or not item.has_meta(&"__event"):
		return
	if not _item_is_editable(item):
		return
	_on_tree_button_pressed(item, 2, ItemButton.EDIT_EVENT, MOUSE_BUTTON_LEFT)

#endregion Tree Item Events

#region Host Actions
#MARK: Host Actions
func                        __Host_Actions___________              ()->void:pass
##    │ _  _        _       _      _   _
##[br]│| || |___ __| |_    /_\  __| |_(_)___ _ _  ___
##[br]│| __ / _ (_-<  _|  / _ \/ _|  _| / _ \ ' \(_-<
##[br]│|_||_\___/__/\__| /_/ \_\__|\__|_\___/_||_/__/
##[br]╰────────────────────────────────────────────────

func _on_host_action_added( action_name:String ) -> void:
	if operation_mode == OperationMode.MONITOR:
		return
	var map:CustomInputMap = _get_mutation_map()
	if map == null:
		return
	map.ensure_action( StringName( action_name ) )
	_host_refresh( map )


func _on_host_action_edited( action_name:String, new_action:Dictionary ) -> void:
	if operation_mode == OperationMode.MONITOR:
		return
	var map:CustomInputMap = _get_mutation_map()
	if map == null:
		return
	var key:StringName = StringName( action_name )
	var deadzone:float = new_action.get( "deadzone", CustomInputMap.DEFAULT_DEADZONE )
	# Materialize null placeholders; asserts used to fire when key existed with null def.
	map.ensure_action( key, deadzone )
	map.set_action_deadzone( key, deadzone )
	map.clear_action_events( key )
	for v:Variant in new_action.get( "events", [] ):
		var ev:InputEvent = v
		if is_instance_valid( ev ):
			var dup:InputEvent = ev.duplicate()
			map.add_action_event( key, dup )
	_host_refresh( map )


func _on_host_action_removed( action_name:String ) -> void:
	if operation_mode == OperationMode.MONITOR:
		return
	var map:CustomInputMap = _get_mutation_map()
	if map == null:
		return
	map.erase_action( StringName( action_name ) )
	_host_refresh( map )


func _on_host_action_renamed( old_name:String, new_name:String ) -> void:
	if operation_mode == OperationMode.MONITOR:
		return
	var map:CustomInputMap = _get_mutation_map()
	if map == null:
		return
	var old_key:StringName = StringName( old_name )
	var new_key:StringName = StringName( new_name )
	if not map.has_action( old_key ):
		return
	var deadzone:float = map.get_action_deadzone( old_key )
	var events:Array[InputEvent] = []
	for ev:InputEvent in map.get_action_events( old_key ):
		if is_instance_valid( ev ):
			var dup:InputEvent = ev.duplicate()
			events.append( dup )
	map.erase_action( old_key )
	map.ensure_action( new_key, deadzone )
	map.set_action_deadzone( new_key, deadzone )
	for ev:InputEvent in events:
		map.add_action_event( new_key, ev )
	_host_refresh( map )


func _on_host_action_reordered(
			action_name:String,
			relative_to:String,
			before:bool ) -> void:
	if operation_mode == OperationMode.MONITOR:
		return
	var map:CustomInputMap = _get_mutation_map()
	if map == null:
		return
	var keys:Array[StringName] = map.get_action_names()
	var from_i:int = keys.find( StringName( action_name ) )
	var to_i:int = keys.find( StringName( relative_to ) )
	if from_i < 0 or to_i < 0 or from_i == to_i:
		return
	var moved:StringName = keys[from_i]
	keys.remove_at( from_i )
	to_i = keys.find( StringName( relative_to ) )
	if to_i < 0:
		return
	if not before:
		to_i += 1
	@warning_ignore( "return_value_discarded" )
	keys.insert( to_i, moved )

	var snapshot:Dictionary = {}
	for k:StringName in map.get_action_names():
		var ev_list:Array = map.get_action_events( k ).duplicate()
		snapshot[k] = {
			&"deadzone": map.get_action_deadzone( k ),
			&"events": ev_list,
		}
	# Snapshot keys first — erase mutates the live dictionary.
	var old_keys:Array[StringName] = map.get_action_names()
	for k:StringName in old_keys:
		map.erase_action( k )
	for k:StringName in keys:
		var data:Dictionary = snapshot[k]
		var deadzone:float = data[&"deadzone"]
		map.add_action( k, deadzone )
		for v:Variant in data[&"events"]:
			var ev:InputEvent = v
			if is_instance_valid( ev ):
				var dup:InputEvent = ev.duplicate()
				map.add_action_event( k, dup )
	_host_refresh( map )

#endregion Host Actions


func _on_input_map_changed(_effective: CustomInputMap) -> void:
	# Root map is the live resource; effective/loaded need a rebuild redraw.
	if _show_effective or _show_loaded or _show_root:
		refresh()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _ready() -> void:
	_ensure_button_icons()

	tree.columns = 3
	# Column 0 — Action name
	tree.set_column_title(0, "Action")
	tree.set_column_expand(0, true)
	tree.set_column_clip_content(0, true)
	# Column 1 — Deadzone
	tree.set_column_title(1, "Deadzone")
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 80)
	# Column 2 — buttons (revert / add|edit / remove), like the engine editor
	tree.set_column_title(2, "")
	tree.set_column_expand(2, false)
	# ~3×16px icons + margins (engine packs all buttons in this column)
	tree.set_column_custom_minimum_width(2, 72)

	@warning_ignore_start("return_value_discarded")
	filter_name_line_edit.text_changed.connect(_on_search_bar_value_changed.unbind(1))
	if is_instance_valid(event_listener_line_edit) and event_listener_line_edit.has_signal(&"event_changed"):
		event_listener_line_edit.connect(&"event_changed", _on_search_event_changed)
	clear_all_button.pressed.connect(_on_clear_all_search)
	line_edit.text_changed.connect(_on_add_edit_text_changed)
	line_edit.text_submitted.connect(_on_add_action_submitted)
	add_button.pressed.connect(_on_add_action_pressed)
	root_check_button.toggled.connect(_on_view_toggles_changed.unbind(1))
	effective_check_button.toggled.connect(_on_view_toggles_changed.unbind(1))
	loaded_check_button.toggled.connect(_on_view_toggles_changed.unbind(1))
	tree.item_edited.connect(_on_action_edited, CONNECT_DEFERRED)
	tree.item_activated.connect(_on_tree_item_activated)
	tree.item_selected.connect(_on_tree_item_selected)
	tree.button_clicked.connect(_on_tree_button_pressed)
	tree.set_drag_forwarding(_get_drag_data_fw, _can_drop_data_fw, _drop_data_fw)

	if event_config_dialog.has_signal(&"confirmed"):
		event_config_dialog.confirmed.connect(_on_event_config_confirmed)

	action_added.connect(_on_host_action_added)
	action_edited.connect(_on_host_action_edited)
	action_removed.connect(_on_host_action_removed)
	action_renamed.connect(_on_host_action_renamed)
	action_reordered.connect(_on_host_action_reordered)
	@warning_ignore_restore("return_value_discarded")

	_show_root = root_check_button.button_pressed
	_show_effective = effective_check_button.button_pressed
	_show_loaded = loaded_check_button.button_pressed

	_on_add_edit_text_changed(line_edit.text)
	_update_clear_all_enabled()

	if resource_edit_mode or operation_mode == OperationMode.EDITOR:
		if resource_edit_mode:
			_apply_mode_ui()
	# Runtime only: follow InputManager merges. Never touch the autoload in the
	# editor — on plugin disable it can still pass is_instance_valid as a proxy
	# without the real script/signals, which errors on .input_map_changed.
	if not Engine.is_editor_hint() and not resource_edit_mode:
		if is_instance_valid(InputManager):
			if not InputManager.input_map_changed.is_connected(_on_input_map_changed):
				@warning_ignore("return_value_discarded")
				InputManager.input_map_changed.connect(_on_input_map_changed)

	refresh()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(InputManager):
		if InputManager.input_map_changed.is_connected(_on_input_map_changed):
			InputManager.input_map_changed.disconnect(_on_input_map_changed)


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass


## Rebuild the tree from the active view toggles and InputManager / edit_map.
func refresh() -> void:
	if _refreshing:
		return
	if not is_instance_valid(tree):
		return
	_refreshing = true
	# Always clear the flag — a mid-refresh error must not permanently freeze the tree.
	_refresh_tree()
	_refreshing = false


func _refresh_tree() -> void:
	var selected_key: String = ""
	var selected_col: int = 0
	var selected: TreeItem = tree.get_selected()
	if selected:
		selected_key = str(selected.get_meta(&"__select_key", selected.get_text(0)))
		selected_col = tree.get_selected_column()

	var collapsed: Dictionary = {}
	_collect_collapsed(tree.get_root(), collapsed)

	tree.clear()
	var root: TreeItem = tree.create_item()

	# Resource / multi-file editor: one path root per open map.
	if resource_edit_mode or (operation_mode == OperationMode.EDITOR and not _get_open_maps().is_empty()):
		_populate_open_map_roots(root, collapsed, selected_key, selected_col)
		return

	var section_count: int = 0
	if _show_root:
		section_count += 1
	if _show_effective:
		section_count += 1
	if _show_loaded:
		section_count += 1
	var multi_section: bool = section_count > 1

	if _show_root:
		var parent: TreeItem = root
		if multi_section:
			parent = _make_section_item(root, "Root Actions", &"section_root")
		var target := _get_target_map()
		# Path header for the file being edited (actions nest under it).
		if target != null:
			parent = _make_map_root_item(parent, target, collapsed, selected_key, selected_col)
		_populate_map_actions(
				parent,
				target,
				true,
				"root",
				collapsed,
				selected_key,
				selected_col,
				target
		)
		if parent != root and parent != null:
			_apply_map_root_collapsed(parent, collapsed)

	if _show_effective:
		var parent: TreeItem = root
		if multi_section or not _show_root:
			parent = _make_section_item(root, "Effective Actions (read-only)", &"section_effective")
		var effective := _get_effective_map()
		_populate_map_actions(
				parent,
				effective,
				false,
				"effective",
				collapsed,
				selected_key,
				selected_col,
				effective
		)

	if _show_loaded:
		var parent: TreeItem = root
		if multi_section or not _show_root:
			parent = _make_section_item(root, "Loaded Actions (read-only)", &"section_loaded")
		var responder_root := _get_responder_root()
		if responder_root:
			_populate_responder_branch(
					parent,
					responder_root,
					"loaded",
					collapsed,
					selected_key,
					selected_col
			)
		else:
			var empty: TreeItem = tree.create_item(parent)
			empty.set_text(0, "(InputManager responder tree not available)")
			empty.set_selectable(0, false)


func _populate_open_map_roots(
		root: TreeItem,
		collapsed: Dictionary,
		selected_key: String,
		selected_col: int
) -> void:
	var maps := _get_open_maps()
	if maps.is_empty():
		var empty: TreeItem = tree.create_item(root)
		empty.set_text(0, "(no CustomInputMap selected)")
		empty.set_selectable(0, false)
		return
	for map: CustomInputMap in maps:
		if map == null:
			continue
		var map_item := _make_map_root_item(root, map, collapsed, selected_key, selected_col)
		var key_prefix := str(map_item.get_meta(&"__select_key"))
		_populate_map_actions(
				map_item,
				map,
				true,
				key_prefix,
				collapsed,
				selected_key,
				selected_col,
				map
		)
		# Collapse only after children exist; default is expanded so actions are visible.
		_apply_map_root_collapsed(map_item, collapsed)


## Compatibility: load a flat editable list from a map (forces root view data).
func load_from_custom_map(map: CustomInputMap, _builtins_prefix: String = "ui_") -> void:
	_set_open_maps([map] if map != null else [])
	edit_map = map
	_current_map = map
	_show_root = true
	if is_instance_valid(root_check_button):
		root_check_button.set_pressed_no_signal(true)
	refresh()


func set_operation_mode(mode: OperationMode) -> void:
	if operation_mode == mode:
		return
	operation_mode = mode
	match operation_mode:
		OperationMode.EDITOR:
			# Writable resource editing; runtime views off unless caller re-enables.
			_show_root = true
			if resource_edit_mode:
				_show_effective = false
				_show_loaded = false
		OperationMode.MONITOR:
			# Live inspection: prefer effective map; mutations are ignored by host.
			resource_edit_mode = false
			open_maps.clear()
			_show_root = false
			_show_effective = true
			_show_loaded = true
			apply_edit_map_to_engine = false
	if is_node_ready():
		_apply_mode_ui()
		refresh()


## Configure for editing a [CustomInputMap] asset (editor plugin bottom panel).
## Replaces the open list with [param map] only. Use [method open_map] to add more.
func configure_for_resource(map: CustomInputMap) -> void:
	resource_edit_mode = true
	operation_mode = OperationMode.EDITOR
	apply_edit_map_to_engine = false
	_show_root = true
	_show_effective = false
	_show_loaded = false
	edit_map = map
	_current_map = map
	open_maps.clear()
	if map != null:
		open_maps.append(map)
	if is_node_ready():
		_apply_mode_ui()
		refresh()


## Add [param map] as another editable root (multi-file). No-op if already open.
func open_map(map: CustomInputMap) -> void:
	if map == null:
		return
	resource_edit_mode = true
	operation_mode = OperationMode.EDITOR
	if not open_maps.has(map):
		open_maps.append(map)
	edit_map = map
	_current_map = map
	if is_node_ready():
		_apply_mode_ui()
		refresh()


## Replace the full open-map list (multi-file editor).
func set_open_maps(maps: Array[CustomInputMap]) -> void:
	resource_edit_mode = true
	operation_mode = OperationMode.EDITOR
	_set_open_maps(maps)
	edit_map = open_maps[0] if not open_maps.is_empty() else null
	_current_map = edit_map
	if is_node_ready():
		_apply_mode_ui()
		refresh()


## Future: attach to a running game's InputManager and show effective/loaded maps.
func configure_for_monitor() -> void:
	operation_mode = OperationMode.MONITOR


func _apply_mode_ui() -> void:
	var toggles: Node = get_node_or_null(^"VBoxContainer/ViewToggles")
	if toggles is CanvasItem:
		# EDITOR resource tooling: hide toggles. MONITOR: show effective/loaded.
		(toggles as CanvasItem).visible = (operation_mode == OperationMode.MONITOR)
	if is_instance_valid(root_check_button):
		root_check_button.set_pressed_no_signal(_show_root)
	if is_instance_valid(effective_check_button):
		effective_check_button.set_pressed_no_signal(_show_effective)
	if is_instance_valid(loaded_check_button):
		loaded_check_button.set_pressed_no_signal(_show_loaded)


func _apply_resource_edit_ui() -> void:
	_apply_mode_ui()


func load_from_engine(_builtins_prefix: String = "ui_") -> void:
	# Snapshot engine into a temporary display via effective view.
	_show_effective = true
	if is_instance_valid(effective_check_button):
		effective_check_button.set_pressed_no_signal(true)
	refresh()


func show_message(message: String) -> void:
	if _message == null:
		_message = AcceptDialog.new()
		add_child(_message)
	_message.dialog_text = message
	_message.popup_centered()


#                  ██       ██████   ██████  ██   ██ ███████                   #
#                  ██      ██    ██ ██    ██ ██  ██  ██                        #
#                  ██      ██    ██ ██    ██ █████   ███████                   #
#                  ██      ██    ██ ██    ██ ██  ██       ██                   #
#                  ███████  ██████   ██████  ██   ██ ███████                   #
func                        __________LOOKS__________              ()->void:pass


func _ensure_button_icons() -> void:
	# TreeItem buttons size to the texture; scale once for layout.
	_button_icon_add = IconCache.at_size(IconCache.get_icon(&"ADD"), TREE_BUTTON_SIZE)
	_button_icon_edit = IconCache.at_size(IconCache.get_icon(&"EDIT"), TREE_BUTTON_SIZE)
	_button_icon_remove = IconCache.at_size(IconCache.get_icon(&"REMOVE"), TREE_BUTTON_SIZE)
	_button_icon_revert = IconCache.at_size(IconCache.get_icon(&"RELOAD"), TREE_BUTTON_SIZE)

		# Real Button controls can keep the source icon; expand_icon handles fit.
	add_button.icon = IconCache.get_icon(&"ADD")


func _title_bg() -> Color:
	if has_theme_color(&"dark_color_2", &"Editor"):
		return get_theme_color(&"dark_color_2", &"Editor")
	return Color(0.106, 0.106, 0.106, 1.0)


func _subsection_fill() -> Color:
	# Prefer editor subsection stylebox colour when present.
	if has_theme_color(&"prop_subsection_stylebox_color", &"Editor"):
		return get_theme_color(&"prop_subsection_stylebox_color", &"Editor")
	return Color(0.196, 0.196, 0.196, 1.0)


func _apply_action_row_chrome(item: TreeItem) -> void:
	# Transparent bg colour (engine prop_subsection is alpha 0); StyleBoxes paint the bar.
	var transparent := Color(1, 1, 1, 0)
	item.set_custom_bg_color(0, transparent)
	item.set_custom_bg_color(1, transparent)
	item.set_custom_stylebox(0, _sb_subsection_left)
	item.set_custom_stylebox(1, _sb_subsection_right)


#               ███████ ██ ██   ████████ ███████ ██████  ███████               #
#               ██      ██ ██      ██    ██      ██   ██ ██                    #
#               █████   ██ ██      ██    █████   ██████  ███████               #
#               ██      ██ ██      ██    ██      ██   ██      ██               #
#               ██      ██ ███████ ██    ███████ ██   ██ ███████               #
func                        _________FILTERS_________              ()->void:pass

func _has_filters() -> bool:
	return (
			not filter_name_line_edit.text.is_empty()
			or _listener_get_event(event_listener_line_edit) != null
	)


func _update_clear_all_enabled() -> void:
	clear_all_button.disabled = not _has_filters()


func _should_display_action(action_name: String, events: Array) -> bool:
	var search_ev := _listener_get_event(event_listener_line_edit)
	var event_match := true
	if search_ev != null:
		event_match = false
		for v: Variant in events:
			var ev: InputEvent = v
			if ev != null and ev.is_match(search_ev, true):
				event_match = true
				break
	var name_filter := filter_name_line_edit.text.strip_edges()
	return event_match and (name_filter.is_empty() or name_filter.is_subsequence_ofn(action_name))


## Safe access while EventListenerLineEdit may be a tool-script placeholder.
func _listener_get_event(listener: Object) -> InputEvent:
	if listener == null or not is_instance_valid(listener):
		return null
	if not listener.has_method(&"get_event"):
		return null
	return listener.call(&"get_event") as InputEvent


func _listener_clear_event(listener: Object) -> void:
	if listener == null or not is_instance_valid(listener):
		return
	if listener.has_method(&"clear_event"):
		listener.call(&"clear_event")
	elif listener is LineEdit:
		(listener as LineEdit).clear()


func _format_input_event_text(event: InputEvent, include_device: bool = true) -> String:
	if event == null:
		return ""
	# Static helper on the preloaded script (safe during class_name placeholder windows).
	if _EventListenerScript != null:
		return str(_EventListenerScript.get_event_text(event, include_device))
	return event.as_text()



#                       ████████ ██████  ███████ ███████                       #
#                          ██    ██   ██ ██      ██                            #
#                          ██    ██████  █████   █████                         #
#                          ██    ██   ██ ██      ██                            #
#                          ██    ██   ██ ███████ ███████                       #
func                        __________TREE___________              ()->void:pass

func _make_section_item(parent: TreeItem, title: String, key: StringName) -> TreeItem:
	var item:TreeItem = tree.create_item(parent)
	item.set_text(0, title)
	item.set_selectable(0, false)
	item.set_selectable(1, false)
	item.set_meta(&"__section", true)
	item.set_meta(&"__select_key", String(key))
	item.set_custom_color(0, Color(0.75, 0.85, 1.0))
	return item


func _make_map_root_item(
		parent: TreeItem,
		map: CustomInputMap,
		_collapsed: Dictionary,
		selected_key: String,
		selected_col: int
) -> TreeItem:
	var item: TreeItem = tree.create_item(parent)
	var path := _map_display_path(map)
	# Prefer stable path key over instance id (ids change across reloads).
	var select_key := "map:%s" % path
	item.set_text(0, path)
	item.set_tooltip_text(0, path)
	item.set_meta(&"__map", map)
	item.set_meta(&"__map_root", true)
	item.set_meta(&"__select_key", select_key)
	item.set_custom_color(0, Color(0.75, 0.85, 1.0))
	# Selectable so "add action" context can follow the chosen file root.
	item.set_selectable(0, true)
	item.set_selectable(1, false)
	# Leave expanded until children are attached (see _apply_map_root_collapsed).
	item.collapsed = false
	if selected_key == select_key:
		item.select(0)
	return item


func _apply_map_root_collapsed(map_item: TreeItem, collapsed: Dictionary) -> void:
	if map_item == null:
		return
	var select_key := str(map_item.get_meta(&"__select_key", ""))
	# File roots default to expanded so nested actions are never hidden on first open.
	map_item.collapsed = bool(collapsed.get(select_key, false))


func _map_display_path(map: CustomInputMap) -> String:
	if map == null:
		return "(no map)"
	if not map.resource_path.is_empty():
		return map.resource_path
	if not map.resource_name.is_empty():
		return "%s (unsaved)" % map.resource_name
	return "(unsaved CustomInputMap)"


func _collect_collapsed(item: TreeItem, out: Dictionary) -> void:
	if item == null:
		return
	if item.collapsed and item.has_meta(&"__select_key"):
		out[item.get_meta(&"__select_key")] = true
	var child := item.get_first_child()
	while child:
		_collect_collapsed(child, out)
		child = child.get_next()


func _item_is_editable(item: TreeItem) -> bool:
	return item != null and item.get_meta(&"__editable", false)


func _populate_map_actions(
		parent: TreeItem,
		map: CustomInputMap,
		editable: bool,
		key_prefix: String,
		collapsed: Dictionary,
		selected_key: String,
		selected_col: int,
		owner_map: CustomInputMap = null
) -> void:
	if parent == null:
		return
	if map == null:
		var empty:TreeItem = tree.create_item(parent)
		empty.set_text(0, "(no map)")
		empty.set_selectable(0, false)
		return

	var action_names:Array[StringName] = map.get_action_names()
	if action_names.is_empty():
		var empty:TreeItem = tree.create_item( parent )
		empty.set_text( 0, "(no actions)" )
		empty.set_selectable( 0, false )
		if owner_map != null:
			empty.set_meta( &"__map", owner_map )
		return

	for action_name:StringName in action_names:
		var events:Array = []
		for ev:InputEvent in map.get_action_events( action_name ):
			if is_instance_valid( ev ):
				events.append( ev )
		if not _should_display_action( String( action_name ), events ):
			continue
		var info:ActionInfo = ActionInfo.new()
		info.name = String( action_name )
		info.action = {
			&"events": events,
			&"deadzone": map.get_action_deadzone( action_name ),
		}
		info.editable = editable
		_add_action_item(
				parent,
				info,
				"%s/%s" % [key_prefix, info.name],
				collapsed,
				selected_key,
				selected_col,
				owner_map if owner_map != null else map
		)


func _populate_responder_branch(
		parent: TreeItem,
		responder: Responder,
		key_prefix: String,
		collapsed: Dictionary,
		selected_key: String,
		selected_col: int
) -> void:
	var node_key := "%s/%s" % [key_prefix, responder.name]
	var node_item := tree.create_item(parent)
	var label := String(responder.name)
	if not responder.active:
		label += " (inactive)"
	if responder.input_map == null:
		label += " — no map"
	elif not responder.contributes_map():
		label += " — not contributing"
	node_item.set_text(0, label)
	node_item.set_meta(&"__responder", true)
	node_item.set_meta(&"__select_key", node_key)
	if responder.input_map != null:
		node_item.set_meta(&"__map", responder.input_map)
	node_item.collapsed = collapsed.get(node_key, false)
	node_item.set_custom_color(0, Color(0.85, 0.85, 0.7))

	if responder.input_map != null:
		_populate_map_actions(
				node_item,
				responder.input_map,
				false,
				node_key,
				collapsed,
				selected_key,
				selected_col,
				responder.input_map
		)

	for child: Node in responder.get_children():
		if child is Responder:
			var child_resp: Responder = child
			_populate_responder_branch(
					node_item,
					child_resp,
					node_key,
					collapsed,
					selected_key,
					selected_col
			)


func _add_action_item(
		parent: TreeItem,
		action_info: ActionInfo,
		select_key: String,
		collapsed: Dictionary,
		selected_key: String,
		selected_col: int,
		owner_map: CustomInputMap = null
) -> void:
	var events: Array = action_info.action.get("events", [])
	var deadzone: float = action_info.action.get("deadzone", 0.5)
	var action_item := tree.create_item(parent)
	action_item.set_meta(&"__action", action_info.action)
	action_item.set_meta(&"__name", action_info.name)
	action_item.set_meta(&"__editable", action_info.editable)
	action_item.set_meta(&"__select_key", select_key)
	if owner_map != null:
		action_item.set_meta(&"__map", owner_map)
	action_item.collapsed = collapsed.get(select_key, false)

	# Joined rounded bar on cols 0–1 (engine prop_subsection_stylebox_left/right).
	_apply_action_row_chrome(action_item)

	# Column 0 — Action Name
	action_item.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
	action_item.set_text(0, action_info.name)
	action_item.set_editable(0, action_info.editable)
	if action_info.icon:
		action_item.set_icon(0, action_info.icon)

	# Column 1 — Deadzone
	action_item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	action_item.set_range_config(1, 0.0, 1.0, 0.01)
	action_item.set_range(1, deadzone)
	action_item.set_editable(1, action_info.editable)

	# Column 2 — all action buttons (engine packs these in one column)
	if action_info.has_initial:
		var deadzone_eq: bool = (
				action_info.action_initial.get("deadzone", null)
				== action_info.action.get("deadzone", null)
		)
		var initial_events: Array = action_info.action_initial.get("events", [])
		var action_events: Array = action_info.action.get("events", [])
		var events_eq := _event_arrays_equal(initial_events, action_events)
		var action_eq := deadzone_eq and events_eq
		action_item.set_meta(&"__action_initial", action_info.action_initial)
		action_item.add_button(
				2, _button_icon_revert, ItemButton.REVERT_ACTION, action_eq or not action_info.editable,
				"Cannot Revert - Action is same as initial" if action_eq else "Revert Action"
		)
	action_item.add_button(
			2, _button_icon_add, ItemButton.ADD_EVENT, not action_info.editable, "Add Event"
	)
	action_item.add_button(
			2, _button_icon_remove, ItemButton.REMOVE_ACTION, not action_info.editable,
			"Remove Action" if action_info.editable else "Cannot Remove Action"
	)

	if selected_key == select_key:
		action_item.select(selected_col)

	for evnt_idx: int in range(events.size()):
		var event: InputEvent = events[evnt_idx]
		if event == null: continue
		var event_key:String = "%s#%d" % [select_key, evnt_idx]
		var event_item:TreeItem = _add_action_event(
				action_item, action_info, event, evnt_idx, event_key, owner_map)
		if selected_key == event_key:
			event_item.select(selected_col)


func _add_action_event(
			action_item:TreeItem,
			action_info:ActionInfo,
			event:InputEvent,
			evnt_idx:int,
			event_key:String,
			owner_map: CustomInputMap = null,
) -> TreeItem:
	var event_item := tree.create_item(action_item)
	event_item.set_meta(&"__event", event)
	event_item.set_meta(&"__index", evnt_idx)
	event_item.set_meta(&"__editable", action_info.editable)
	event_item.set_meta(&"__select_key", event_key)
	if owner_map != null:
		event_item.set_meta(&"__map", owner_map)

	# Column 0 — event label + type icon
	event_item.set_text(0, _format_input_event_text(event, true))
	event_item.set_icon(0, IconCache.for_event(event))
	event_item.set_icon_max_width(0, TREE_BUTTON_SIZE.x)
	# Column 1 — empty (align under deadzone)
	# Column 2 — edit + remove (same column as action-row buttons)
	event_item.add_button(
			2, _button_icon_edit, ItemButton.EDIT_EVENT, not action_info.editable, "Edit Event"
	)
	event_item.add_button(
			2, _button_icon_remove, ItemButton.REMOVE_EVENT, not action_info.editable, "Remove Event"
	)
	return event_item





# ██████  ██████   █████   ██████     ██    ██████  ██████   ██████  ██████    #
# ██   ██ ██   ██ ██   ██ ██          ██    ██   ██ ██   ██ ██    ██ ██   ██   #
# ██   ██ ██████  ███████ ██   ███ ████████ ██   ██ ██████  ██    ██ ██████    #
# ██   ██ ██   ██ ██   ██ ██    ██ ██  ██   ██   ██ ██   ██ ██    ██ ██        #
# ██████  ██   ██ ██   ██  ██████  ██████   ██████  ██   ██  ██████  ██        #
func                        ________DRAG_DROP________              ()->void:pass

func _get_drag_data_fw(at_position: Vector2) -> Variant:
	var selected := tree.get_item_at_position(at_position)
	if selected == null:
		selected = tree.get_selected()
	if selected == null or not _item_is_editable(selected):
		return null
	if not selected.has_meta(&"__action") and not selected.has_meta(&"__event"):
		return null

	var label := Label.new()
	label.text = selected.get_text(0)
	tree.set_drag_preview(label)

	var drag_data := {}
	if selected.has_meta(&"__action"):
		drag_data["input_type"] = "action"
	if selected.has_meta(&"__event"):
		drag_data["input_type"] = "event"
	drag_data["source"] = selected.get_instance_id()
	tree.set_drop_mode_flags(Tree.DROP_MODE_INBETWEEN)
	return drag_data


func _can_drop_data_fw(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	var d: Dictionary = data
	if not d.has("input_type"): return false
	var source_id: int = d.get("source", 0)
	var source: TreeItem = instance_from_id(source_id)
	var selected := tree.get_selected()
	var item := tree.get_item_at_position(at_position)
	if selected == null or item == null or item == source:
		return false
	if not _item_is_editable(selected) or not _item_is_editable(item):
		return false
	# Never drag across different map files.
	if _map_from_item(selected) != _map_from_item(item):
		return false
	if d["input_type"] == "action" and item.has_meta(&"__event"):
		return false
	if d["input_type"] == "event" and item.get_parent() != selected.get_parent():
		return false
	return true


func _drop_data_fw(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data_fw(at_position, data):
		return
	var selected := tree.get_selected()
	var target := tree.get_item_at_position(at_position)
	if target == null:
		return
	var drop_section := tree.get_drop_section_at_position(at_position)
	var drop_above := drop_section == -1
	var d: Dictionary = data

	if d["input_type"] == "action":
		_set_mutation_context(selected)
		var relative_to: String = target.get_meta(&"__name")
		var action_name: String = selected.get_meta(&"__name")
		action_reordered.emit(action_name, relative_to, drop_above)
	elif d["input_type"] == "event":
		_set_mutation_context(selected.get_parent())
		var current_index: int = selected.get_meta(&"__index")
		var target_index: int = target.get_meta(&"__index")
		var parent_action: Dictionary = selected.get_parent().get_meta(&"__action")
		var new_action: Dictionary = parent_action.duplicate(true)
		var events: Array = new_action.get("events", [])
		var new_events: Array = []
		for i: int in range(events.size()):
			if i == current_index:
				continue
			elif i == target_index:
				if drop_above:
					new_events.append(events[current_index])
					new_events.append(events[target_index])
				else:
					new_events.append(events[target_index])
					new_events.append(events[current_index])
			else:
				new_events.append(events[i])
		new_action["events"] = new_events
		action_edited.emit(selected.get_parent().get_meta(&"__name"), new_action)


#    ██ ███    ██ ██████  ██    ██ ████████     ███    ███  █████  ██████      #
#    ██ ████   ██ ██   ██ ██    ██    ██        ████  ████ ██   ██ ██   ██     #
#    ██ ██ ██  ██ ██████  ██    ██    ██        ██ ████ ██ ███████ ██████      #
#    ██ ██  ██ ██ ██      ██    ██    ██        ██  ██  ██ ██   ██ ██          #
#    ██ ██   ████ ██       ██████     ██        ██      ██ ██   ██ ██          #
func                        ________INPUT_MAP________              ()->void:pass

func _get_open_maps() -> Array[CustomInputMap]:
	var out: Array[CustomInputMap] = []
	# Do not use is_instance_valid on Resources — editor proxies can fail that check
	# (or pass it without a usable script), same class of bug as InputManager.
	for m: CustomInputMap in open_maps:
		if m != null and not out.has(m):
			out.append(m)
	if out.is_empty() and edit_map != null:
		out.append(edit_map)
	return out


func _set_open_maps(maps: Array) -> void:
	open_maps.clear()
	for v: Variant in maps:
		if v is CustomInputMap:
			var m: CustomInputMap = v
			if m != null and not open_maps.has(m):
				open_maps.append(m)


func _map_from_item(item: TreeItem) -> CustomInputMap:
	var walk := item
	while walk != null:
		if walk.has_meta(&"__map"):
			var m: Variant = walk.get_meta(&"__map")
			if m is CustomInputMap:
				return m as CustomInputMap
		walk = walk.get_parent()
	return null


func _set_mutation_context(item: TreeItem) -> void:
	var map := _map_from_item(item)
	if map != null:
		_current_map = map
		edit_map = map


func _get_mutation_map() -> CustomInputMap:
	if _current_map != null:
		return _current_map
	return _get_target_map()


func _get_target_map() -> CustomInputMap:
	if _current_map != null:
		return _current_map
	if edit_map != null:
		return edit_map
	var opened := _get_open_maps()
	if not opened.is_empty():
		return opened[0]
	if resource_edit_mode:
		return null
	var rr := _get_responder_root()
	if rr != null and rr.input_map != null:
		return rr.input_map
	return null


func _get_effective_map() -> CustomInputMap:
	if Engine.is_editor_hint() or not is_instance_valid(InputManager):
		return null
	return InputManager.effective_map


# FIXME: because this function is used in multple places, return a dictionary
# of error types, and messages. That way we can respond in a very specific way
# depending on what the error is.
# Either that or perform more granular checking, so the caller can discern
# their own way.
func _check_new_action_name(action_name: String) -> String:
	if action_name.is_empty():
		return "Action name cannot be empty."
	if not _is_action_name_valid(action_name):
		return "Invalid action name. It cannot contain '/', ':', '=', '\\' or '\"'."
	if _map_has_action(_get_mutation_map(), action_name):
		# If the target exists, then scroll to it
		# optionally trigger an edit.
		return "An action with the name '%s' already exists." % action_name
	return ""


func _map_has_action(map: CustomInputMap, action_name: String) -> bool:
	if map == null:
		return false
	return map.has_action(StringName(action_name))


func _target_has_action(action_name: String) -> bool:
	return _map_has_action(_get_target_map(), action_name)


func _submit_new_action(action_name: String) -> void:
	var candidate := action_name.strip_edges()
	if candidate.is_empty():
		return
	# Prefer the map under the current tree selection when multi-file is open.
	var selected := tree.get_selected() if is_instance_valid(tree) else null
	if selected != null:
		_set_mutation_context(selected)
	var err := _check_new_action_name(candidate)
	if not err.is_empty():
		show_message(err)
		return
	if _get_mutation_map() == null:
		show_message("No input map available. Select a CustomInputMap resource.")
		return
	# Emit first so host can read the name; clear after so text_changed
	# does not race a second submit with an empty string.
	action_added.emit(candidate)
	line_edit.clear()
	_on_add_edit_text_changed(line_edit.text)


#   ██ ███    ██ ██████  ██    ██ ████████     ███    ███  ██████  ██████      #
#   ██ ████   ██ ██   ██ ██    ██    ██        ████  ████ ██       ██   ██     #
#   ██ ██ ██  ██ ██████  ██    ██    ██        ██ ████ ██ ██   ███ ██████      #
#   ██ ██  ██ ██ ██      ██    ██    ██        ██  ██  ██ ██    ██ ██   ██     #
#   ██ ██   ████ ██       ██████     ██        ██      ██  ██████  ██   ██     #
func                        ________INPUT_MGR________              ()->void:pass

func _get_responder_root() -> Responder:
	if Engine.is_editor_hint() or not is_instance_valid(InputManager):
		return null
	return InputManager.responder_root


func _host_refresh(map: CustomInputMap = null) -> void:
	if map == null:
		map = _get_mutation_map()
	if map == null:
		return
	if apply_edit_map_to_engine and not Engine.is_editor_hint():
		map.apply_to_engine()
	# Runtime only: rebuild merged engine map when we edited the live root layer.
	if not resource_edit_mode and not Engine.is_editor_hint():
		var rr := _get_responder_root()
		if rr != null and is_instance_valid(InputManager):
			if map == rr.input_map or edit_map == null:
				InputManager.rebuild_input_map()
	# Notify editor / save pipeline that the resource mutated (once).
	map.emit_changed()
	resource_modified.emit(map)
	refresh()


#       ██ ███    ██ ████████ ███████ ██████  ███    ██  █████  ██             #
#       ██ ████   ██    ██    ██      ██   ██ ████   ██ ██   ██ ██             #
#       ██ ██ ██  ██    ██    █████   ██████  ██ ██  ██ ███████ ██             #
#       ██ ██  ██ ██    ██    ██      ██   ██ ██  ██ ██ ██   ██ ██             #
#       ██ ██   ████    ██    ███████ ██   ██ ██   ████ ██   ██ ███████        #
func                        ________INTERNAL_________              ()->void:pass

static func _is_action_name_valid(action_name: String) -> bool:
	if action_name.is_empty():
		return false
	# Match engine ActionMapEditor: reject / : " = \ and control chars.
	for i: int in range(action_name.length()):
		var c: int = action_name.unicode_at(i)
		if c < 32:
			return false
		match c:
			0x2F, 0x3A, 0x22, 0x3D, 0x5C:
				return false
	return true


static func _event_arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		var ea: InputEvent = a[i]
		var eb: InputEvent = b[i]
		if ea == null and eb == null:
			continue
		if ea == null or eb == null:
			return false
		if not ea.is_match(eb, true):
			return false
	return true
