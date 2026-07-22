# Plan: Host session boundary for Input Map Editor

**Status:** implemented (decision **B**, with main-screen caveat)  
**Date:** 2026-07-23  
**Scope:** `plugin.gd`, `host_session.gd`, `settings/`, `inspector_plugin.gd` — not domain systems  
**Out of scope:** auto-restart via `set_plugin_enabled`, style pass on `input_map_editor.gd`

**Decision B notes:** Dock ↔ Inspector rehosts in-process. Transitions that
touch **Main screen** still require disable/re-enable (Godot registers main
tabs at plugin enable only).

---

## 1. Problem (locked)

Three host APIs share one plugin, but **ProjectSettings `host_mode` was treated as live truth** for attach, runtime, and teardown. After a mid-session change, desired config and applied tree diverge. Teardown that re-reads settings can skip the real host and leave broken state (or crash paths via deferred/null callables).

Related smells (same layer):

| Smell | Effect |
|-------|--------|
| Dual `InputMapEditor` in inspector mode | Hidden primary panel + per-parse inspector editor |
| `RefCounted` settings owning `ProjectSettings` signal | Needs explicit `shutdown()`; PREDELETE is unreliable |
| Deferred work without cancel | Unload/reload races |
| Mode enum as primary control for safety | Wrong key; instances are truth |

---

## 2. Goals

1. **Desired vs applied** are separate, named, and enforced in code.
2. **Detach never reads ProjectSettings** (or settings mirror fields).
3. **One editor ownership model per host** — no idle dual panel in inspector mode.
4. **Deferred work is session-scoped** and no-ops after detach begins.
5. Host change is either **safe rehost** or **apply-on-next-enable only** — no half-live mode.
6. Domain resources (`CustomInputMap`, `InputAction`, panel mutators) stay untouched unless a host bug forces a one-line call-site fix.

### Non-goals

- Live hot-swap of host without an explicit rehost path.
- Moving host preference to EditorSettings in v1 of this plan (optional later).
- Full rewrite of `input_map_editor.gd`.
- Self-reload of the EditorPlugin.

---

## 3. Target architecture

```
┌─────────────────────────────────────────────────────────────┐
│ EditorPlugin                                                │
│  desired_host  ← read ProjectSettings only at attach/rehost │
│  session       ← AppliedHost (nullable)                     │
│  dirty_maps, export_plugin, inspector signal wiring         │
└───────────────────────────┬─────────────────────────────────┘
                            │ owns
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ AppliedHost (plain data + methods, or small inner class)    │
│  kind: DOCK | MAIN_SCREEN | INSPECTOR                       │
│  panel: InputMapEditor | null   # dock/main only            │
│  dock: EditorDock | null                                    │
│  inspector_plugin: EditorInspectorPlugin | null             │
│  attach(plugin, desired) / detach(plugin)                   │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
      EditorDock      main screen        InspectorPlugin
      + panel         + panel            creates own editors
```

### Naming (mandatory)

| Name | Meaning | Mutated when |
|------|---------|--------------|
| **Desired host** | Preference in ProjectSettings | User edits settings; never drives detach |
| **Applied host** | What is in the editor tree now | Only `attach` / `detach` / `rehost` |
| **Session id** | Monotonic int for deferred guards | Bumped when detach starts |

Delete the ambiguous single concept “current host mode” from control flow. Helpers may remain as thin wrappers over `session.kind` only.

---

## 4. AppliedHost protocol

### 4.1 Attach

```
pre:  session == null
in:   desired = read_desired_host()  # ProjectSettings once
do:   session = AppliedHost(kind: desired)
      match kind:
        DOCK:        create panel, wrap EditorDock, add_dock
        MAIN_SCREEN: create panel, add to main screen, hide until _make_visible
        INSPECTOR:   create inspector_plugin only (no primary panel)
post: session.kind == desired; instances match kind
```

**Rule:** ProjectSettings is read **only** at the start of attach (and optional rehost). After that, all host questions use `session`.

### 4.2 Detach

```
pre:  session may be null (idempotent)
do:   bump session_id (cancel deferred)
      if session == null: return
      # Instance-driven — ignore desired entirely
      if session.inspector_plugin: remove_inspector_plugin; clear
      if session.dock: remove_dock; reparent panel out; free dock
      if session.panel:
           disconnect resource_modified if connected
           remove from parent if any
           queue_free panel
      session = null
post: no owned host nodes; session == null
```

**Rules:**

- Never call `read_host_mode()` / `_opts.host_mode` inside detach.
- Always clear every non-null host slot (dock **and** inspector plugin), not `match kind` only — belt and braces if attach partially failed.
- `_exit_tree` = detach session + disconnect global inspector signals + settings teardown + clear dirty list.

### 4.3 Rehost (phase 2)

```
rehost():
  desired = read_desired_host()
  if session != null and session.kind == desired: return
  detach()
  attach(desired)
```

Called only from an explicit user action or a single settings handler that **does not** nest rehost (guard with `_rehosting` flag). Prefer toaster: “Host updated.” No `set_plugin_enabled`.

If rehost is deferred to phase 2, phase 1 behaviour for desired change:

- Persist setting.
- **Do not** update applied session.
- **Do not** spam warnings on every ProjectSettings noise — one toast when desired ≠ applied.
- Next `_enter_tree` (manual disable/enable) applies desired.

### 4.4 Runtime queries

| Question | Source |
|----------|--------|
| `_has_main_screen` while session live | `session.kind == MAIN_SCREEN` |
| `_has_main_screen` before enter / after exit | `read_desired_host()` (engine may query early) |
| `_make_visible` | session is MAIN_SCREEN and panel valid |
| Raise / auto_raise | session kind + dock/panel instances |
| Active editor | INSPECTOR → bound inspector editor; else session.panel |
| `inspector_can_handle` | session.kind == INSPECTOR |

---

## 5. Panel ownership

### Dock / main screen

- Exactly one `InputMapEditor` owned by the session.
- Plugin methods that edit maps use `session.panel` only.

### Inspector

- **No** hidden primary panel.
- Inspector plugin creates editors in `_parse_begin` as today.
- Plugin keeps a **weak** current inspector editor ref for dirty/sync:
  - `bind_inspector_editor(editor)` sets current.
  - On detach: disconnect `resource_modified` if still connected; null ref.
  - On new `_parse_begin`: rebind; disconnect previous if still valid.

### Height / min size

- Dock/main: apply `panel_min_height` to session.panel only.
- Inspector: keep fit-to-inspector logic in inspector plugin; read min height via static `InputMapEditorSettings.read_panel_min_height()` (no need for live settings object).

---

## 6. Settings redesign

### 6.1 Split responsibilities

| Piece | Role |
|-------|------|
| Static helpers | `read_*`, `register_all`, legacy purge (call once from plugin enter) |
| Live prefs (optional) | `auto_raise`, `panel_min_height` only |
| Host desired | ProjectSettings key; **not** a live driver for tree ownership |

### 6.2 Preferred shape (phase 1b)

- Drop long-lived `RefCounted` that connects to `ProjectSettings.settings_changed` **or** keep it only if plugin is the sole owner of connect/disconnect in `_enter_tree` / `_exit_tree` (no PREDELETE disconnect).
- Registration: `InputMapEditorSettings.register_project_settings()` static, called from plugin enter, not constructor side-effects if we can avoid double-register noise.
- Desired host change detection:
  - Compare `read_desired_host()` to `session.kind` when settings change.
  - If different: mark “pending host change”; toast once; save project settings if we still want immediate persist.

### 6.3 What stays ProjectSettings (v1)

Keep keys as-is for migration:

- `input_map_editor/host_mode`
- `input_map_editor/auto_raise`
- `input_map_editor/default_deadzone`
- `input_map_editor/panel_min_height`

Optional later: move `host_mode` to EditorSettings (per-user layout).

---

## 7. Deferred / unload safety

1. **`_session_id:int`** on the plugin; increment at start of detach (and rehost).
2. Every `call_deferred` captures `id` and returns if `id != _session_id` or session cleared as required.
3. Paths to cover:
   - `_clear_suppress`
   - settings sync / live emit enable
   - any deferred refresh on the panel
4. **`_shutting_down:bool`** set true for the whole `_exit_tree`; event handlers early-out.
5. Inspector plugin: disconnect `resized` when control is freed or plugin removed (store Callable; disconnect in cleanup).

---

## 8. File-level work breakdown

| File | Change |
|------|--------|
| `plugin.gd` | Introduce session (inner class or `host_session.gd`); rewrite attach/detach/exit; guard deferred; stop creating panel in inspector mode |
| `host_session.gd` (new, optional) | `AppliedHost` attach/detach pure of ProjectSettings |
| `settings/input_map_editor_settings.gd` | Static-first API; remove or narrow RefCounted PS listener; desired-vs-applied docs |
| `inspector_plugin.gd` | Cleanup path for resized; rebind contract; no dependency on hidden primary panel |
| `README.md` | Desired vs applied; rehost or disable/enable; inspector has no dock panel |
| `docs/host_session_plan.md` | This plan; mark status as phases complete |
| Domain systems | **No change** unless forced |

Keep public resource API and export plugin as-is.

---

## 9. Phases and acceptance criteria

### Phase 0 — Spec freeze (docs only)

- [x] This plan committed under `docs/host_session_plan.md`
- [x] User chose **B** (rehost), with main-screen engine caveat documented

### Phase 1 — Session boundary + instance detach

- [x] `host_session.gd` AppliedHost; latch kind at attach only
- [x] Detach instance-driven; never reads desired host
- [x] No primary panel when applied kind is INSPECTOR
- [x] `_has_main_screen` uses session when live, desired when not
- [x] Deferred guards (`_session_id`) + `_shutting_down`
- [x] Settings static API; plugin owns `settings_changed`
- [x] Inspector rebind + `cleanup()` / `unbind_inspector_editor`

**Manual accept (user):** matrix 1a–1i in editor log

### Phase 2 — In-process rehost (decision B)

- [x] `_rehost()` with `_rehosting` guard; dirty maps kept
- [x] Desired host change → save + rehost (not on noise before `_settings_live`)
- [x] **Caveat:** transitions involving main screen toast + require disable/enable
- [x] Dock ↔ Inspector full in-process rehost

**Manual accept (user):** 2c dock↔inspector; 2a/2b via disable/enable for main

### Phase 3 — Hardening

- [x] Inspector `resized` disconnect on cleanup / re-parse
- [x] Settings static register/read; plugin-owned signal
- [x] README desired vs applied + rehost table
- [ ] Optional: automated smoke for non-editor pieces only

### Phase 4 — Optional product follow-ups (explicit backlog)

- Host mode → EditorSettings.
- Single shared editor reparent strategy (only if dual-instance cost becomes real pain).
- Reduce `has_method`/`call` boundary to typed preload after reload is proven stable.

---

## 10. Test matrix (manual editor)

Run against a project with the addon enabled and a sample `CustomInputMap` `.tres`.

| ID | Start host | Action | Assert |
|----|------------|--------|--------|
| M1 | Dock | Disable plugin | No dock; log clean |
| M2 | Main | Disable plugin | No Input Map main tab content |
| M3 | Inspector | Select map, disable | Inspector back to default props path or empty custom |
| M4 | Dock | Set host=Main, disable, enable | Main only |
| M5 | Main | Set host=Dock, disable, enable | Dock only |
| M6 | Dock | Set host=Inspector, disable, enable | Inspector only; no dock |
| M7 | * | Mid-session host change (phase 1) | Applied unchanged; toast once; desired saved |
| M8 | * | Mid-session host change (phase 2) | Applied matches desired; one host only |
| M9 | Dock | Edit events, project save | Dirty + save external |
| M10 | Inspector | Edit events | `resource_modified` / save path works |
| M11 | Any | Rapid disable/enable 5× | No PREDELETE null; no SIGSEGV |
| M12 | Main | `_make_visible` via tab switch | Panel show/hide correct |

Log capture: full `godot.exe` + `--log-file` (not console stub).

---

## 11. Implementation order (suggested commits)

1. **docs:** this plan (+ decision note A/B when chosen).
2. **refactor:** extract attach/detach into session helpers without behaviour change (still latched).
3. **fix:** detach instance-only + deferred guards + inspector no primary panel.
4. **settings:** desired≠applied toast; host_mode not a live tree driver.
5. **(optional) rehost:** phase 2.
6. **harden:** inspector resized cleanup; static settings; matrix notes in README/test.

One logical concern per commit; no submodule noise.

---

## 12. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| `_has_main_screen` queried before enter with wrong desired | Document; read desired only when session null |
| Godot main-screen tab cache after kind change without full disable | Phase 2 rehost must mirror docs pattern; if flaky, force manual enable for main only |
| Inspector parse thrash on rebind | Disconnect old editor signals before bind |
| Partial attach failure | Detach clears all slots regardless of kind |
| Over-scope into domain | Code review: systems/ untouched |

---

## 13. Success definition

The host layer is correct when:

1. You can explain attach/detach without mentioning ProjectSettings except at attach entry.
2. Changing the dropdown while loaded cannot make detach free the wrong host.
3. Inspector mode does not construct a throwaway dock/main panel.
4. Unload under stress (host change + disable) produces no PREDELETE null and no signal-11 from plugin callables.
5. Domain map editing behaviour is unchanged for the happy path.

---

## 14. Open decision

**Reply with A or B (or amend):**

- **A — Apply on next enable only** (Phase 1 + 3). Safest; matches current UX copy.
- **B — In-process rehost** (Phase 1 + 2 + 3). Better UX; needs re-entrancy and dirty-list care.

Default if unspecified: **A**, then B as a follow-up PR.
