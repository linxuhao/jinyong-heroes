# step2_design — Main Menu, Creation-Before-Tutorial, Save/Load Chain Repair

## 1. Overview

This run delivers three coupled features on the Godot 4.7 wuxia game "Huashan Sword Tournament":

1. **A real main menu** (mouse-first, keyboard-compatible) with four entries — 新的冒险 / 读取存档 / 设置 / 退出 — as the new launch entry point (`project.godot run/main_scene` → `res://scenes/menu.tscn`).
2. **Character creation moved before the tutorial** (design order segment 0), so the real flow is `MENU → 捏人 → 教程战 → 穿越 → 选门派 → …`; the tutorial protagonist stays the orchestrated Yang Guo (settled, not an open question).
3. **Save/load chain repair** — instrument the six `io_error` sites with real error codes, harden the atomic-write protocol, fix load-while-hosted staleness, and wire the menu's 读取存档 entry to a proper load route.

**Hard constraint (the load-bearing wall of this design):** the 27 existing playtest scenario files stay **byte-identical** and the in-scope ones stay/return **green**. This is achieved by the already-released per-scenario `scene:` boot capability of the harness (see the comment block at the top of `playtest/_common.yaml`): the shared default `scene:` stays `res://scenes/main.tscn`, so every existing scenario boots exactly as today — zero file edits, absolute frames unmoved. The menu/creation/settings screens are name-tested headlessly by **new additive scenario files** that carry their own `scene:` line. **No headless/env-var/`--skip-menu` branching exists anywhere** — the menu is not bypassed in test; it is the thing being tested (the reviewer's hard veto from SOTA).

Note on language: this document's prose is English per pipeline convention; the **in-game UI strings are quoted Chinese data values** mandated by `design/30_presentation.md` (界面文字一律中文) and pinned by existing playtest assertions — they are not translated.

## 2. Design-change declarations (for `5_design`)

The `design/` record is **not edited this run**; these updates are declared for `5_design` to apply after final verification:

| # | Change | Why |
|---|---|---|
| D1 | `design/40_progression.md` §1: "真正的 `PlayerProfile` 在下一段由玩家创建" → the real profile is created at **segment 0 (捏人), before the tutorial**; the tutorial still uses the separate orchestrated Yang Guo profile (`20_content.md` 编排数值, unchanged). | `00_overview.md` already mandates the 2026-08-24 order (捏人 first); §1 still describes the old order. |
| D2 | `design/40_progression.md` §2 heading "第 3 段 · 开局:捏人 + 选门派" → 捏人 has moved to segment 0; segment 3 is 选门派 only. | Same order change. |
| D3 | `tutorial_done` flag semantics flip: set **false** at creation (`SaveManager.new_profile()`), set **true** at tutorial completion (`TutorialManager._finish_tutorial()`). "保留一条教程已完成的标记" (40_progression §1) is preserved — only *when* the mark is written changes. | Creation now happens before the tutorial; the old "creation is only reachable after the tutorial" comment is factually wrong. |
| D4 | `STABLE_STATES` stays `["CULTIVATION", "MAP"]`; MENU/SETTINGS are deliberately **never saveable** states. Documented, not changed — prevents a future run from "helpfully" adding them. | Menu/settings screens have no saveable progress; keeping the save domain tight protects the atomic-write guard. |

No numbers in `20_content.md` change. No changes to `00_overview.md` (it already describes the menu and the reorder).

## 3. Architecture diagram (text)

```
                    ┌─────────────────────────── boot: menu.tscn (real launches) ───────────────────────────┐
                    │  menu.tscn = persistent shell copy (root "Main" + SceneHost + SegmentLayer/SegmentHost │
                    │  + HUDLayer/HUD + TutorialLayer/TutorialOverlay) + authored MenuPanel under SegmentHost│
                    └──────────────────────────────────────────────┬────────────────────────────────────────┘
                                                                     │ MenuPanel._ready:
                                                                     │   1. hide HUDLayer
                                                                     │   2. SceneManager.claim_boot(self,"menu")   (sets _current_node, current_scene)
                                                                     │   3. GameManager.enter_menu()               (state MENU; swap no-ops, already hosted)
                    ┌────────────────── main.tscn boot (all 27 scenarios; byte-identical path) ──────────────┐
                    │  main.tscn untouched; GameManager.current_state defaults TUTORIAL,                      │
                    │  SceneManager.current_scene == "none" → its deferred _ready still swaps to battlefield  │
                    └─────────────────────────────────────────────────────────────────────────────────────────┘

GameManager state machine (extended in place):

        MENU ──新的冒险──▶ CHARACTER_CREATION ──confirm (creation_entry=="MENU")──▶ TUTORIAL ──tutorial done──▶ BATTLE
         │                      │                                                        ▲                        │
         │ 设置                (creation_entry=="TRANSITION", legacy/test-only)            │ LOST → retry        │ WON
         ▼                      ▼                                                        └─── request_retry     ▼
      SETTINGS ──返回──▶ MENU  SECT_SELECTION ◀──TRANSITION (last page, creation_done==true)              TRANSITION (2× ui_accept;
         │                            │                                                                      last page branches on
         ▼                            ▼                                                                      GameManager.creation_done)
      (quit)                      CULTIVATION ──▶ MAP ──▶ ENDING
         ▲                            │ save/load (STABLE_STATES)
      MENU ──读取存档──▶ load_slot(1) ok & segment ∈ STABLE_STATES → direct state set (bypasses SEGMENT_PREDECESSORS)

Legacy boot flow (27 scenarios, byte-identical): TUTORIAL → BATTLE → WON → TRANSITION →(creation_done=false)→
CHARACTER_CREATION → SECT_SELECTION → CULTIVATION → MAP → ENDING.
```

**Boot-claim protocol** (the one ordering-sensitive piece): autoload `_ready` runs before the main scene enters the tree; the main scene's `_ready` runs before the first process frame; `SceneManager._ready()` resumes on `await get_tree().process_frame` after that. Therefore the MenuPanel's `_ready` (which claims the boot) always lands before SceneManager's deferred default swap. SceneManager's `_ready` becomes `if current_scene == "none": swap_to("battlefield")` — for main.tscn boots nothing changes (current_scene is "none"); for menu.tscn boots the claim suppresses the default battlefield swap.

## 4. State machine (GameManager, extended in place)

New states (NOT in `SEGMENT_STATES`, NOT in `SEGMENT_PREDECESSORS`, never saveable):

- `STATE_MENU = "MENU"`, `STATE_SETTINGS = "SETTINGS"`.

Routing flags (boot defaults preserve the legacy path exactly):

- `creation_entry: String = "TRANSITION"` — the discriminator for creation confirm. Set to `"MENU"` by `menu_new_adventure()`; stays `"TRANSITION"` in the legacy flow (boot default). Reset in `restart_game()`.
- `creation_done: bool = false` — set true when creation confirms via the MENU entry; read by the TRANSITION screen's last-page advance: `creation_done ? SECT_SELECTION : CHARACTER_CREATION`. Reset in `restart_game()`. Boot-default false pins the 27 scenarios' `TRANSITION → CHARACTER_CREATION` route.

New methods (each guarded to its legal state; all mirror the existing "set state + emit `state_changed`" shape — none of them goes through `enter_segment`, so `SEGMENT_PREDECESSORS` is never consulted for menu routes):

| Method | Guard | Effect |
|---|---|---|
| `enter_menu()` | none (idempotent) | `current_state = MENU` + emit. Used by MenuPanel boot claim. |
| `menu_new_adventure() -> bool` | `current_state == MENU` | `creation_entry = "MENU"`; state → CHARACTER_CREATION + emit. |
| `menu_open_settings() -> bool` | `current_state == MENU` | state → SETTINGS + emit. |
| `menu_close_settings() -> bool` | `current_state == SETTINGS` | state → MENU + emit. |
| `menu_load_game() -> bool` | `current_state == MENU` | `SaveManager.load_slot(1)`; if ok **and** `SaveManager.segment ∈ STABLE_STATES`: `clear_battle()`; `current_state = SaveManager.segment`; emit. Else return false (menu shows the Chinese failure hint; entry stays enabled for retry). |
| `menu_quit()` | — | `get_tree().quit()`. |
| `finish_creation()` | called from creation CONFIRM | `creation_entry == "MENU"` → `creation_done = true`; state → TUTORIAL + emit (SceneManager swaps to battlefield; `battlefield.gd`'s `_ready` defers `TutorialManager.start()`, which drives TUTORIAL→BATTLE). Else → `enter_segment("SECT_SELECTION")` — **byte-identical legacy call**. |

Changed table: `SEGMENT_PREDECESSORS["SECT_SELECTION"]` becomes `[STATE_CHARACTER_CREATION, STATE_TRANSITION]` (additive — the legacy `CHARACTER_CREATION → SECT_SELECTION` edge is untouched). `restart_game()` additionally resets `creation_entry` / `creation_done`. `_unhandled_input` (WON/LOST) unchanged.

`TUTORIAL` is deliberately not a segment state — the new flow reaches it by direct state set (same shape as `WON`/`LOST` routing), and the tutorial's own completion protocol (`TutorialManager._finish_tutorial() → GameManager.start_battle()`) is reused untouched.

## 5. Component specifications

### C1 — MenuShell: `scenes/menu.tscn` (NEW)
- Root `Main` (Node2D) with **exactly the same host paths as main.tscn**: `Camera`, `SceneHost`, `SegmentLayer/SegmentHost` (full-rect Control in CanvasLayer), `HUDLayer` + HUD instance, `TutorialLayer` + TutorialOverlay instance — or `SceneManager._find_host()` fails with `host_missing`.
- Plus one authored instance of `scenes/ui/menu_panel.tscn` under `SegmentHost`.
- No root script: the boot-claim lives in MenuPanel (`_ready`), which is guaranteed to run before SceneManager's post-frame resume.
- **Known hazard (documented, accepted):** the shell node block is duplicated from main.tscn. main.tscn cannot be refactored into a shared base this run (byte-identity constraint), so any future shell change must touch both files.

### C2 — MenuPanel: `scripts/ui/menu_panel.gd` + `scenes/ui/menu_panel.tscn` (NEW)
- **Responsibility:** the four-entry menu; single activation path for mouse and keyboard; boot claim; load-availability surface.
- **Structure:** `Panel`/`ColorRect` backdrop (color-block style, existing `global_theme.tres` font — no new assets), `VBoxContainer` with `Button` nodes `MenuEntry0..3` (texts 新的冒险 / 读取存档 / 设置 / 退出), a `Label` hint. All buttons `focus_mode = FOCUS_NONE` — **deliberate**: keyboard `ui_accept` is handled only by the panel's `_unhandled_input`, so no button-native press can double-activate and no focus fights the global WON/LOST listeners.
- **Surface vars:** `focused_entry: int = 0`, `hint_text: String = ""`, `load_available: bool`.
- **Interface (script API):**
  - `_ready()`: (1) hide `/root/Main/HUDLayer` (the swap protocol only toggles HUD when a swap runs; boot shows none); (2) `SceneManager.claim_boot(self, "menu")`; (3) `GameManager.enter_menu()` (its emit reaches SceneManager, whose `swap_to("menu")` no-ops because the claim already set `current_scene`); (4) `_refresh_load_availability()` + `_render()`.
  - `_unhandled_input(event)` — active only when `GameManager.current_state == "MENU"`: `move_up`/`move_down` cycle `focused_entry` (mod 4), `ui_accept` → `_activate_entry(focused_entry)`; each handled event calls `set_input_as_handled()`.
  - `_process(_delta)` — harness-only: `debug_click_menu_entry` → `_activate_entry(focused_entry)` (the **same function** the `Button.pressed` signals call); `debug_seed_save`/`debug_delete_save` → `_refresh_load_availability()`.
  - `_activate_entry(i)` — 0 → `GameManager.menu_new_adventure()`; 1 → `if not GameManager.menu_load_game(): hint_text = _failure_hint(); _render()`; 2 → `GameManager.menu_open_settings()`; 3 → `GameManager.menu_quit()`. Button `pressed` → `_activate_entry(0..3)`.
  - `_failure_hint()` — maps `SaveManager.last_error`: `no_save` → 没有找到存档; `bad_json`/`bad_schema`/`bad_version` → 存档已损坏，无法读取; else 读取失败.
- **Load availability rule (hard):** `load_available = SaveManager.has_save_file(1)` (autosave slot) — **file existence, never `SaveManager.has_save`**, which is session-memory (set only by a successful `save_slot` this session). `MenuEntry1.disabled = not load_available`; hint shows 没有找到存档 when unavailable. A failed load keeps the entry enabled (retry) and shows the failure hint.

### C3 — SceneManager boot-claim + menu/settings entries (`scripts/autoload/scene_manager.gd`, MODIFIED)
- `SCENE_MAP` += `"MENU": "menu"`, `"SETTINGS": "settings"`; `SCENE_PATHS` += `"menu": "res://scenes/ui/menu_panel.tscn"`, `"settings": "res://scenes/ui/settings_panel.tscn"` (preloaded at startup like all others).
- New `claim_boot(node: Node, scene_key: String) -> void`: no-op unless `current_scene == "none" and _current_node == null`; sets `_current_node = node; current_scene = scene_key; last_error = ""`. The claimed node is freed by the normal `_do_swap` teardown on swap-away — the authored panel behaves exactly like a hosted scene.
- `_ready()` tail becomes:
  ```
  await get_tree().process_frame
  _find_host()
  if current_scene == "none":
      swap_to("battlefield")
  ```
  main.tscn boots: `current_scene == "none"` → default swap fires, byte-identical. menu.tscn boots: claim already set `current_scene = "menu"` → skip. Direct segment boots (e.g. creation.tscn): no `/root/Main` → `host_missing`, scene left alone — exactly today's behavior.
- Everything else (`_do_swap`, `pending_swap`, `_teardown_battle_refs`, HUD toggle `next_is_battle`) unchanged.

### C4 — Creation reorder + mouse UI (`scripts/segments/creation.gd` + `scenes/segments/creation.tscn`, MODIFIED)
- **Routing branch:** CONFIRM (`_on_accept`, after `confirmed = true; SaveManager.new_profile(attrs, trait_ids)`) now calls `GameManager.finish_creation()` instead of `GameManager.enter_segment("SECT_SELECTION")` directly. `finish_creation()` reproduces the legacy call byte-for-byte when `creation_entry != "MENU"` (boot default), so the 11/11 `creation_budget_clamp_and_traits` scenario and `spine_to_ending` see identical behavior.
- **Mouse UI (hybrid, single source of truth):** the existing keyboard handlers (`_on_move_left` / `_on_move_right` / `_on_accept` / `_toggle_trait`, plus `attr_index`/`trait_index`) stay exactly as-is. Add per-phase button groups to `creation.tscn`:
  - ATTRS: `AttrRow0..4`, each an HBox with `Label` (attr name+value, rendered by `_render`'s existing text model or a row label) + `Button` `AttrMinus0..4` / `AttrPlus0..4` → `_focus_attr(i); _on_move_left()` / `_on_move_right()` (`.tscn` connection with `binds=[i]`).
  - TRAITS: `TraitToggle0..12` → `trait_index = i; _toggle_trait(i); _render()`.
  - CONFIRM: `ConfirmButton` → `_on_accept()`; `BackButton` → phase back (`_on_move_left()` semantics).
  - `_render()` toggles which group is visible per phase. Keyboard text menu (`BodyLabel`) unchanged.
- New script methods: `_focus_attr(i)`, `_on_attr_minus_pressed(i)`, `_on_attr_plus_pressed(i)`, `_on_trait_toggle_pressed(i)` — one-line callables into the existing private handlers (the pressed→handler link is engine-guaranteed; the handlers themselves are what the keyboard scenario already pins).
- `_process`: harness-only `debug_click_creation_widget` → `_on_attr_plus_pressed(attr_index)` (the exact bound callable of the focused row's + button) — proves convergence without a mouse-synthesis harness extension.
- Clamps (`ATTR_MIN/ATTR_MAX`, tiered pricing) unchanged; `confirmed` guard unchanged; `points_left` semantics unchanged.

### C5 — Transition branch (`scripts/segments/transition.gd`, MODIFIED)
- Only the last-page routing line changes: `GameManager.enter_segment("SECT_SELECTION" if GameManager.creation_done else "CHARACTER_CREATION")`.
- Page count (2), advance cadence (1 × `ui_accept` per page), `lines_shown`/`done` surface semantics, and every absolute frame in `spine_to_ending` are untouched. `creation_done` defaults false → legacy route byte-identical. The 穿越 narrative content stays as-is this run (content change is not in scope; if a future run adds lines they must fit the existing 2-advance cadence or be deferred — recorded for the PM).

### C6 — SaveManager: flag flip + instrumentation + hardening (`scripts/autoload/save_manager.gd`, MODIFIED)
- **`tutorial_done` flip (D3):** `new_profile()` sets `profile.flags["tutorial_done"] = false` (comment updated); `restart_game()`'s redundant explicit reset stays (harmless) with its comment corrected. `TutorialManager._finish_tutorial()` sets it `true` (C7-adjacent, in `tutorial_manager.gd`) — no scenario asserts this flag, so zero observable impact on the 27.
- **Instrumentation (mandatory BEFORE any root-cause claim — the brief's 先取值再动手):** new surface vars `last_io_error_code: int = 0`, `last_io_error_text: String = ""`, `debug_user_dir_path: String = OS.get_user_data_dir()`, `debug_user_dir_exists: bool = false`. A private `_record_io_error()` captures `FileAccess.get_open_error()` → `error_string()` (or `DirAccess.get_open_error()` at the two dir-op sites) and sets `last_error = "io_error"`. All six sites call it: empty-JSON guard, `FileAccess.open(tmp, WRITE) == null`, step-2 `_apply_save_dict` fail, `copy_absolute` fail, `rename_absolute` fail, step-5 re-validate fail.
- **User-dir self-heal:** public `ensure_user_dir() -> bool` — `DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))`, then records `debug_user_dir_exists`. Called in `_ready()` and at the top of `save_slot()` (and by SettingsManager before its ConfigFile save). Kills the top IO failure candidate (missing `user://` root → `FileAccess.open` WRITE returns null) unconditionally and safely.
- **Step-5 leftover-file hole (rollback completion):** on step-5 re-validate failure, `_restore_bak` currently no-ops when no `.bak` exists, leaving the invalid `real` file behind (→ later `bad_schema`/`bad_json` on load). Fix:
  ```
  if not _apply_save_dict(_read_json(real)):
      if FileAccess.file_exists(bak):
          _restore_bak(bak, real)
      else:
          _remove_file(real)
      last_error = "io_error"
      return false
  ```
  Invariant after the fix: a failed save never leaves a promoted-but-invalid `real` file. (The `month == 4` staleness is a separate scene-refresh issue — C8.)
- **`loaded` signal + file-existence helper:**
  - `signal loaded(slot: int)` — emitted on `load_slot()` success (before `return true`).
  - `func has_save_file(s: int) -> bool` — `s in 1..3 and FileAccess.file_exists("user://save_%d.json" % s)`.
- `has_save` semantics **unchanged** (session-memory; the playtest surface contract keeps it). Splitmix64 constants untouched (never touch the IO path — do not attribute IO failures to them without evidence).

### C7 — Load entry + load refresh
- **GameManager load entry** (C0 above, `menu_load_game()`): `load_slot(1)` → validate `SaveManager.segment ∈ STABLE_STATES` (hostile-save hardening; a file claiming `segment: "MENU"` is refused as `bad_schema`) → `clear_battle()` → direct state set + emit, **bypassing `SEGMENT_PREDECESSORS`** (loading from the menu into CULTIVATION/MAP is not a predecessor-legal edge and must not be gated by that map).
- **CultivationScreen refresh** (`scripts/segments/cultivation.gd`, MODIFIED): `_ready()` connects `SaveManager.loaded` → `_on_loaded()` which runs `_sync_surface(); _render()`. `_sync_surface()` already reads `year`/`month` from the restored `SaveManager.profile.cultivation` (verified line 636-638), so the observed `month == 4` staleness (load-while-cultivation-is-already-hosted → `swap_to` no-ops → stale counters) disappears: the restored month replaces the stale one. Fresh-instance loads (from the menu) already re-sync in `_ready()` — the signal covers only the same-scene case, which is exactly the `save_load_roundtrip` red.
- **Save-while-pending discipline:** unchanged — `save_slot` still refuses while `SceneManager.pending_swap` (the existing scenarios already respect the spacing; new scenarios inherit the same spacing discipline).

### C8 — Settings: `scripts/autoload/settings_manager.gd` (NEW) + `scripts/ui/settings_panel.gd` + `scenes/ui/settings_panel.tscn` (NEW)
- **SettingsManager (autoload, inserted after AudioManager and before SceneManager — SceneManager must stay the LAST entry, its header comment says why):**
  - Persistence: `user://settings.cfg` via `ConfigFile`; fields `sfx_volume_db` (default 0.0), `music_volume_db` (default −10.0, matching AudioManager's current constant), `fullscreen` (default false).
  - API: `set_sfx_volume_db(v)`, `set_music_volume_db(v)` (clamped to `[-40.0, +6.0]`), `set_fullscreen(b)`, `reset_to_defaults()`. Each setter applies + persists.
  - `_apply()`: `AudioManager.set_sfx_volume_db(...)` / `set_music_volume_db(...)`; fullscreen applied only when `DisplayServer.get_name() != "headless"` (`get_window().mode = Window.MODE_FULLSCREEN/WINDOWED`) — a platform-API guard, **not** a behavior branch of main.tscn (the veto covers only the menu-vs-tutorial decision; volume is pure data and safe headless).
  - `_ready()`: `_load()` then `_apply()` (runs after AudioManager's `_ready`, so the players exist).
  - `_process()`: harness-only `debug_reset_settings` → `reset_to_defaults()` (deterministic starting point for the scenario, since `settings.cfg` persists across processes on the same user dir).
- **AudioManager additions** (`scripts/autoload/audio_manager.gd`, MODIFIED): mirror surface vars `sfx_volume_db: float = 0.0` / `music_volume_db: float = -10.0` and setters that assign to the mirror **and** the players' `volume_db` (null-guarded). No bus layout is introduced — the repo owns exactly two players (SFXPlayer 0 dB, MusicPlayer −10 dB); bus-based mixing is only worth it when ducking/mixing exists.
- **SettingsPanel:** keyboard + mouse hybrid, same pattern as the menu. Rows: 音效音量 / 音乐音量 / 全屏 / 返回. `move_up/down` cycle `focus_index` (0..3); `move_left/right`: vol rows ±3 dB (clamped by SettingsManager), 全屏 toggles; `ui_accept`: 返回 → `GameManager.menu_close_settings()`; Buttons (`Button0..3`, `FOCUS_NONE`-free focus handled by the panel) mirror the same handlers. Guarded to `current_state == "SETTINGS"`. Surface: `SettingsPanel: [visible, focus_index]`; values asserted on `SettingsManager`/`AudioManager`.
- **Playtest asserts persisted intent, not window state:** volume asserts read `SettingsManager.*` and `AudioManager.*`; fullscreen asserts read `SettingsManager.fullscreen` only (headless has no window).

### C9 — `project.godot` (MODIFIED)
- `run/main_scene` → `"res://scenes/menu.tscn"`.
- `[autoload]` += `SettingsManager="*res://scripts/autoload/settings_manager.gd"` inserted **before** SceneManager (SceneManager remains last).
- `[input]` += five unbound harness-only actions (empty event lists, the repo's established DEBUG pattern): `debug_click_menu_entry`, `debug_click_creation_widget`, `debug_seed_save`, `debug_delete_save`, `debug_reset_settings`. Every one of them drives the same code path the corresponding mouse/kb action drives, or seeds/deletes test fixtures — none branches game behavior.

### C10 — DEBUG save fixture (`scripts/autoload/game_manager.gd`, MODIFIED)
- `_process()` additions (harness-only):
  - `debug_seed_save`: no-op unless state is MENU/SETTINGS; `var prev = current_state; current_state = STATE_CULTIVATION; SaveManager.autosave(); current_state = prev` — **no `state_changed` emission** (no swap triggered). Runs through `save_slot`'s real atomic pipeline (the repo rule "injection walks the normal pipeline").
  - `debug_delete_save`: `SaveManager.delete_slot(1)` (existing public API) — makes the "no save → entry disabled" assertions deterministic against a dirty user dir from earlier runs.

### C11 — Documentation & delivery notes (`README.md`, MODIFIED)
- Menu entry/keys (arrows + Enter, mouse), 读取存档 behavior + failure hints, settings (volume/fullscreen), updated boot description, new debug actions, and the **explicit debt record** (see §9).

## 6. Data flow — save/load chain (post-repair)

```
save (CULTIVATION menu row 存盘)                        load (menu entry 1 / cultivation 读档)
──────────────────────────────                        ─────────────────────────────────────
SaveManager.ensure_user_dir()                         GameManager.menu_load_game()          [from menu]
save_slot(1): STABLE_STATES ✓, !pending_swap ✓          └─ SaveManager.load_slot(1)
  1. JSON.stringify dict (non-empty guard)                   ├─ file exists?  no  → last_error="no_save" → menu hint
  2. write tmp → get_open_error()/error_string() recorded    ├─ parse/schema/version validate (fresh-profile fallback, coded error)
  3. re-read+validate tmp                                    └─ ok → _apply_save_dict (seed→rng→profile→decks→segment)
  4. backup old real → copy_absolute (recorded on fail)          → loaded.emit(1)
  5. remove old, rename tmp→real (recorded on fail)              → segment ∈ STABLE_STATES ✓
  6. re-read+validate real; on fail: restore bak OR remove real      → clear_battle(); current_state=segment; state_changed →
     (no invalid promoted file survives)                              SceneManager swap → scene _ready reads restored profile
  → snapshots, slot=1, has_save=true, last_error=""              CultivationScreen already hosted? loaded → _sync_surface()
                                                                  (month/year refreshed — fixes the month==4 staleness)
```

**Mandated diagnostic sequence (PM task, before any root-cause claim):** land C6 instrumentation first, then run single-scenario `godot_playtest_scenario save_load_roundtrip` (and `cultivation_month_cycle_and_deck_bookkeeping` for its f200 probe) on the staged overlay (~50 s each), and read the observed `last_io_error_code`/`last_io_error_text`/`debug_user_dir_exists`. The C6 fixes (user-dir ensure + step-5 rollback completion) are correct regardless of the observed code and land unconditionally; the root-cause *narrative* goes into the delivery notes from the observed values, not from conjecture.

## 7. Irreversible-operation safety & rollback

- **Save files are the only user-state writes.** The existing protocol is already backup→execute→verify→delete shaped; this run only (a) adds a verify-then-delete completion where the rollback path had a hole (C6 step-5 fix — the *invalid* file is removed only after re-validation failed and only when no backup exists to restore), and (b) makes the user dir self-heal. No schema migration, no version bump (`SAVE_VERSION` stays 1 — the save dict shape is unchanged).
- **`project.godot` main-scene change** is a single reversible line; rollback = revert the line to `res://scenes/main.tscn` (menu remains reachable for tests via per-scenario `scene:`), so the menu can be reverted independently of everything else.
- **Protected files:** `scenes/main.tscn`, all 27 existing `playtest/<scenario>.yaml`, and every `design/*` file are untouched this run; the acceptance check is `git diff --stat` showing **only new files** under `playtest/` plus the append-only `_common.yaml` additions. If a diff ever shows an existing scenario file modified, the implementer has violated the hard constraint and must revert before anything else.
- **Rollback for the whole feature set:** every behavior delta is gated behind boot-default flags (`creation_entry == "TRANSITION"`, `creation_done == false`) or additive tables; reverting menu.tscn + the project.godot line + the two default-guarded branches restores the legacy boot flow exactly.

## 8. Playtest contract (observable surface + scenario skeletons — PM fills frames/thresholds)

### 8.1 `playtest/_common.yaml` — append-only edits (every existing line stays byte-identical; the default `scene:` line untouched)
- `actions:` append: `debug_click_menu_entry`, `debug_click_creation_widget`, `debug_seed_save`, `debug_delete_save`, `debug_reset_settings`.
- `surface:` append:
  - `MenuPanel: [focused_entry, hint_text, load_available]`
  - `MenuEntry0..3: [visible, disabled, size, mouse_filter]`
  - `SettingsPanel: [visible, focus_index]`
  - `SettingsManager: [sfx_volume_db, music_volume_db, fullscreen]`
  - `AudioManager: [sfx_volume_db, music_volume_db]`
  - under the existing `SaveManager:` block append: `last_io_error_code`, `last_io_error_text`, `debug_user_dir_exists`
  - `AttrPlus0: [visible, size, mouse_filter]`, `TraitToggle0: [visible, size, mouse_filter]`, `ConfirmButton: [visible, size, mouse_filter]`
- `scenario_order:` append the five new scenario names.

### 8.2 New scenario files (each self-contained; `scene:` per file)
1. **`main_menu_entries.yaml`** — `scene: res://scenes/menu.tscn`. Press `debug_delete_save` early, then: all four `MenuEntry*` `visible == true`, `size.x > 0 and size.y > 0`, `mouse_filter == 0` (MOUSE_FILTER_STOP); `MenuPanel.load_available == false`; `MenuEntry1.disabled == true`; `hint_text.contains("存档") == true` (remember the repo rule: comparison operators mandatory, `== true` for String.contains). Keyboard: `move_down ×2` → `focused_entry == 2`; `ui_accept` → `SettingsPanel.visible == true`; back via 返回 → `MenuPanel.visible == true`, `GameManager.current_state == "MENU"`. Then `debug_click_menu_entry` (focus 0) → `GameManager.current_state == "CHARACTER_CREATION"` and `SceneManager.current_scene == "creation"` — the debug-click path is the same `_activate_entry` the buttons call.
2. **`menu_to_creation_to_tutorial_order.yaml`** — `scene: res://scenes/menu.tscn`. Order proof, **state asserts only, never absolute frame numbers**: `ui_accept` (menu → CHARACTER_CREATION) → `ui_accept` (ATTRS→TRAITS) → `move_right` (TRAITS→CONFIRM) → `ui_accept` (confirm) → assert `GameManager.current_state == "TUTORIAL"`, `SceneManager.current_scene == "battlefield"`, `GameManager.creation_done == true` (surface add: `GameManager: [creation_done, creation_entry]`). Then the existing tutorial cadence: `ui_accept ×7` → `debug_win_tutorial` → WON → `ui_accept` → TRANSITION → `ui_accept ×2` → assert `current_state == "SECT_SELECTION"` (the `creation_done` skip — **no second creation**) — this scenario is the real-flow proof the brief demands.
3. **`creation_mouse_interaction.yaml`** — `scene: res://scenes/segments/creation.tscn` (direct boot, assert from f30 per the verified capability). ATTRS phase: `AttrPlus0.visible == true`, `mouse_filter == 0`, `size.x > 0`; `debug_click_creation_widget` → `CreationScreen.attrs["bone"] == 11` and `points_left == 29` (the same bound callable as the + button); repeat to clamp: presses past 20 leave `attrs["bone"] == 20` (clamp via the same handler). Keyboard sanity: `move_right` after resetting focus produces the identical delta (convergence proof; the full keyboard path stays pinned by the existing 11/11 scenario).
4. **`menu_load_continues.yaml`** — `scene: res://scenes/menu.tscn`. `debug_delete_save` → `debug_seed_save` → `MenuPanel.load_available == true`, `MenuEntry1.disabled == false`; focus 1 (`move_down`) + `debug_click_menu_entry` → `current_state == "CULTIVATION"`, `CultivationScreen.visible == true`, `CultivationScreen.month == 1` (restored profile). Optionally re-seed with a modified month via the fixture if PM wants a non-1 month (fixture spec in C10 allows writing the default profile only — month 1 is the deterministic assertion).
5. **`settings_panel.yaml`** — `scene: res://scenes/menu.tscn`. `debug_reset_settings` (deterministic baseline), `move_down ×2` + `ui_accept` → `SettingsPanel.visible == true`; `move_right` → `SettingsManager.sfx_volume_db == 3.0` and `AudioManager.sfx_volume_db == 3.0`; `move_down`, `ui_accept` (全屏) → `SettingsManager.fullscreen == true` (persisted intent only — no window assert headless); `move_down`, `ui_accept` (返回) → `current_state == "MENU"`, `MenuPanel.visible == true`.

PM fills exact `at` frames (respecting the ~2-frame post-swap spacing discipline and the f2999 cap) and any additional structural asserts; **scenario 2 must never hard-code frame numbers into its asserts** — the frames only sample, the asserts only check state order.

## 9. Recorded debt (delivery notes must state these plainly)

1. **`spine_to_ending` and `creation_budget_clamp_and_traits` walk a test-only path** (TUTORIAL WON → TRANSITION → CHARACTER_CREATION → SECT_SELECTION), which no longer exists in the real flow. A 27-file rewrite is deliberately not undertaken. Follow-up: convert `creation_budget_clamp_and_traits` to a direct `creation.tscn` boot; keep `spine_to_ending` as the boot-flow spine proof.
2. **Mouse-click testing is structural + handler-convergence, not coordinate hit-testing.** The DPE harness has no coordinate input; extending `godot_playtest` to synthesize `InputEventMouseButton` via `Input.parse_input_event` is a tooling change outside this repo. Until then the `debug_click_*` actions + `mouse_filter == 0`/rect asserts are the pragmatic honest stand-in (engine-guaranteed pressed→handler link).
3. **Shell duplication:** menu.tscn duplicates main.tscn's shell node block (forced by main.tscn's byte-identity). Future shell edits must touch both.
4. **`has_save` is session-memory**; menu availability is file existence. Do not "fix" one by pointing at the other.
5. Out-of-scope pre-existing reds (`two_phase_skill_unlock_and_hp_gate` 18/20, `terminal_victory_8_12_rounds_hp_15_40` 4/6, `each_unit_acts_once_per_round_initiative_order` 6/12, `dot_resolves_at_victim_turn_start` 2/8, `ui_geometry_readability` 23/24, `sect_switch_same_school_connects` 6/8) are **not** this run's targets and must not be "fixed" via assertion edits; in-scope targets: `save_load_roundtrip` (9/13 → all green), `cultivation_month_cycle_and_deck_bookkeeping` (15/17 → all green) via code only, with `has_save`/`last_error` observed values recorded in the delivery notes.

## 10. Tech stack & assets

- **Godot 4.7 GDScript + text-authored `.tscn`** — no plugins, no new engine features. Scenes are authored as diffable text (established repo practice); no code-builds-scene.
- **ConfigFile** (`user://settings.cfg`) for settings persistence; existing `global_theme.tres` + NotoSansSC font; color-block style per roadmap stage.
- **No new art/audio assets this run** — the menu/settings screens reuse the existing theme and color blocks (roadmap: 简单美术 as default; no asset generation until the vertical-slice decision).
- Harness: `godot_playtest_scenario` + per-file scenarios (no `playtest_spec.yaml` monolith; the loader prefers `playtest/`).

## 11. Task decomposition boundaries (for the PM)

Independent workstreams, sized so each lands green incrementally:

| Task | Files | Depends on | Risk |
|---|---|---|---|
| T1 | `scripts/autoload/settings_manager.gd` (NEW), `scripts/autoload/audio_manager.gd`, `project.godot` (autoload + input actions) | none | low |
| T2 | `scripts/autoload/scene_manager.gd` (claim_boot, guard, SCENE_MAP/PATHS) | none | medium — ordering-sensitive; verify main.tscn boot unchanged via `spine_to_ending` |
| T3 | `scripts/autoload/game_manager.gd` (states, flags, menu_* methods, finish_creation, restart resets, DEBUG save fixtures, SEGMENT_PREDECESSORS extension) | none | medium — legacy path must stay byte-identical |
| T4 | `scenes/menu.tscn`, `scripts/ui/menu_panel.gd`, `scenes/ui/menu_panel.tscn` (NEW) | T2, T3 interfaces | medium — boot-claim ordering |
| T5 | `scripts/segments/creation.gd`, `scenes/segments/creation.tscn` (buttons + finish_creation call) | T3 | low — 11/11 must stay green |
| T6 | `scripts/segments/transition.gd` (branch) | T3 | low — spine frames pinned |
| T7 | `scripts/autoload/tutorial_manager.gd` (tutorial_done=true at finish) | none | trivial |
| T8 | `scripts/autoload/save_manager.gd` (flip, instrumentation, ensure_user_dir, step-5 fix, loaded signal, has_save_file) | none | medium — **instrument first, probe, then claim root cause** |
| T9 | `scripts/segments/cultivation.gd` (loaded → _sync_surface) | T8 (signal) | low |
| T10 | `playtest/_common.yaml` (append-only) + 5 new scenario files | T1–T9 | medium — assertion-operator rule, spacing discipline |
| T11 | `README.md` + delivery notes (debt records) | all | trivial |

## 12. Extensibility considerations

- **Menu entries are data-shaped** (`ENTRIES` array in the panel) — adding a 5th entry is one row + one `match` arm; the harness surface pattern (`MenuEntryN`) extends trivially.
- **The load entry (`menu_load_game`) is the future "continue" seam**: any later in-game "return to menu" state can reuse it verbatim (it validates segment ∈ STABLE_STATES and bypasses the predecessor map by design).
- **SettingsManager** is the single persistence point for future prefs (key rebinding, language) — add a ConfigFile section, no new components.
- **`claim_boot`** generalizes: any future full-screen boot scene (splash, title cinematic) claims the boot the same way, keeping SceneManager's single-hosted-scene invariant.
- Deliberately **not** built: a generic "any state → any state" FSM (overdesign — menu routes are closed and enumerated), bus-based audio (no mixing exists), coordinate mouse synthesis in the harness (tooling outside the repo), and a save schema migration (no schema change).

## 13. Deliverable summary

| File | Status |
|---|---|
| `scenes/menu.tscn`, `scenes/ui/menu_panel.tscn`, `scenes/ui/settings_panel.tscn` | NEW |
| `scripts/ui/menu_panel.gd`, `scripts/ui/settings_panel.gd`, `scripts/autoload/settings_manager.gd` | NEW |
| `project.godot`, `scripts/autoload/{game,scene,save,audio,tutorial}_manager.gd`, `scripts/segments/{creation,transition,cultivation}.gd`, `scenes/segments/creation.tscn`, `README.md` | MODIFIED (additive where possible) |
| `playtest/_common.yaml` | APPEND-ONLY (default `scene:` line untouched) |
| `playtest/{main_menu_entries,menu_to_creation_to_tutorial_order,creation_mouse_interaction,menu_load_continues,settings_panel}.yaml` | NEW |
| `scenes/main.tscn`, all 27 existing `playtest/*.yaml`, `design/*` | UNTOUCHED (hard constraint) |

Acceptance: 27 existing scenario files byte-identical; in-scope reds (`save_load_roundtrip`, `cultivation_month_cycle_and_deck_bookkeeping`) green via code only; new scenarios green; compile gate clean; real launches land on the menu; headless harness runs the same code paths.
