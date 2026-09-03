# 技术架构设计 — jinyong-nav (R5 navigation-and-consequence)

> Base repo: `/home/linxuhao/.AItelier/projects/jinyong-assets` (Godot 4.4, GDScript). Date: 2026-09-03.
> Inputs: Project Brief (R5 owner verdict, L4), Step 1 SOTA report (verified by review), repo reads done in this step.
> Everything below pins **properties and node names**, never line numbers (brief line numbers have drifted through R2–R4).

---

## 1. Overview

R5 makes every choice show its consequence **before** it is committed (rendered from data, touch-reachable), gives every uncommitted selection screen a zero-delta return path, fixes the no-trainable-gongfa path so it returns to ACTION_PICK **without advancing the month**, puts the character/equipment/gongfa panel on the battle and ending screens, and completes visible battle feedback (floating damage text + combat log, point-cost and move-range previews). Irreversible commits (sect join, year-end sect switch, travel-to-ending) gain confirmations; the battle pause button gains a real menu (continue / return-to-main-menu with second confirmation).

Design principles, all inherited from the SOTA report and repo precedent:

1. **Reuse pinned in-repo precedents, build no new systems.** Facility-screen effect summary (`map.gd::_facility_effect_summary`) and skill-card summary (`skill_button.gd::effect_summary`) are the C1 renderer templates. `roster_panel.tscn` is reused verbatim for C4 (it already self-contains `RosterOpenButton` + dim + close). `_delete_armed` two-press pattern is the confirmation template. `move_hint_label.gd` "self-driving poller" is the template for adding UI over a host screen without editing the host.
2. **Data-rendered consequences, never hand-written literals.** Every consequence string is composed from `CardData.TABLE` / `EventData` option effects / `ProgressionGongfaData` (SECTS, PRACTICE_TO_MASTER, GRADE_BY_YEAR) / `ProgressionMath.work_income` / `MapData` slot accessors / `creation.gd::_step_cost` — pinned by computed booleans, not literals.
3. **Locked files are never edited.** Six-file lock = `scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`. Both collision points (map C1/C3, battle C4) are resolved **outside** the locked files (§3). If an implementation task discovers it cannot proceed without editing a locked file, it **STOPs and reports** — it does not edit.
4. **Three verbatim gates byte-untouched and green:** `facility_use_reusable.yaml` (49/49), `map_node_event_shaolin.yaml` (32/32), `map_battle_node_huashan.yaml` (41/41).
5. **RNG lifeline untouched:** `save_load_roundtrip` (14/14) and `event_travel_effects` (19/19). All new paths (desc rendering, back, confirm-arm) perform **zero RNG operations** — they are pure reads plus phase/focus writes.
6. **Red-first discipline:** every new/re-derived nail is run red first (temporary-revert method, `record_measured_red_first_and_reconcile` precedent), four values recorded (failing frame / first failing assert / exact error / green asserts before red), fix landed, red run once more, then green. Records go in `final/_red_first_5x.md` + each scenario header.

Scope limits (explicit non-goals kept): nicknames (R4), new battles/NPCs, gongfa count, actions per month (R6), numeric balance. Already-passing screens untouched except where named: character-creation attribute formatting (only the **point-cost** fix is added), facilities screen, battle skill bar labels. UX-14 (pre-battle loadout) stays OPEN. Tutorial dialogs are **not** given a new exit this round (「跳过教程」 already is their exit; they are informational, not uncommitted selection screens — noted for the UX backlog, not implemented).

---

## 2. Constraint collisions and their resolution (decision records for 90_decisions)

### 2.1 map.gd is locked, but C1 (node-type hint) and C3 (travel-to-ending confirm) live on the map screen

**Decision: scene-layer implementation (Track B) is the primary path. No map.gd edit is made or required.** An owner unlock request (R3b precedent, `final/unlock_record_r3b_huashan.md`) is documented as an *optional later simplification*, not a dependency.

Everything the two features need is reachable without touching map.gd:

- **Data accessors are public on `MapData`:** `node_ids()`, `node_def(node)`, `is_adjacent()`, `is_end_node()`, `active_event_id(node)`, `active_battle_id(node)`, `active_facility_id(node)`.
- **Map state is public on the MapScreen node:** `current_node_id`, `focus_id`, `phase`, `map_status_text`.
- **Buttons are stable scene nodes:** `map.tscn` → `TravelBox/TravelButton0..2` (fixed pool of 3, static geometry, `focus_mode = 0`).
- **The poller pattern already exists:** `move_hint_label.gd` resolves its host fresh every frame and never stores the ref — proven by `map_hint_single` 7/7 and the movement highlight nails.

New file `scripts/segments/map_travel_hints.gd` (self-driving poller, attached to a new node in `map.tscn`) provides:

1. **Node-type hint (C1):** each frame, resolve the focused neighbor the same way `_travel()` does (focus index → `MapData` neighbor of `current_node_id`), classify it from the slot accessors (`battle` → 华山=战斗, `facility` → 少林/武当=门派设施, `event` → 事件, `is_end_node` → 此去即结局), and render one line into a **new** `TravelHintLabel` (placed under `TravelBox`, y ≈ 600–640 — free space, no overlap with `HintLabel` footer at −56..−16). All type words via `tr()`. This label is a consequence line, not a second hint: `map_hint_single`'s assertions read the existing footer `HintLabel` and stay untouched.
2. **Travel-to-ending gate (C3):** when the focused/travel-target neighbor `MapData.is_end_node() == true` and the gate is not confirmed:
   - **Mouse path:** a `TravelGateShield` Control (child of the hint node) is positioned each frame over that one `TravelButton{i}`'s `get_global_rect()` with `mouse_filter = STOP`; it swallows the first press, opens the confirm dialog, and the underlying button never fires (map.gd's `_on_travel_pressed` is never reached — no map.gd edit, no rollback).
   - **Keyboard path:** the sibling's `_unhandled_input` runs before the host's (children process unhandled input before the root) and consumes `ui_accept` while the end-node target is focused and unconfirmed — blocking `_travel()` exactly once, then opening the dialog.
   - **Confirm dialog:** opaque panel + dim (roster_panel precedent) with `确认启程` / `返回`; body text names the end node and states 此去即结局. On 确认: hide shield + dialog, then re-dispatch the *public* signal `btn.pressed.emit()` on the covered button (single documented re-dispatch; no private-method call, no map.gd edit). On 返回: hide shield, state unchanged, zero delta.
   - The gate is **inert for every non-end node**: the three verbatim gates' map legs (shaolin event, huashan battle, facility) never see it; `spine_to_ending`, `clicks_only_storyline`, `work_beats_idling` and the ending-leg scenarios *do* cross it and get a one-press timeline insertion each (§6.3).
3. **Observables:** `travel_hint_text: String`, `travel_gate_visible: bool`, `travel_gate_armed: bool` on the MapScreen surface (via the sibling node, whitelisted in `_common.yaml`).

Coupling honesty: the sibling reads two public vars of the host (`current_node_id`, `focus_id`) and one public API class (`MapData`). If a future round renames those, the sibling degrades to "no hint, no gate" (guards on null) — it cannot corrupt travel. This is recorded as the accepted trade-off vs. editing a locked file.

### 2.2 battlefield.gd is locked, but C4 wants the roster panel in battle

**Decision: the panel entry lives entirely in the HUD/panel layer, and the battle instance is READ-ONLY.**

- `roster_panel.tscn` self-contains `RosterOpenButton` (top-right), `RosterDim` (STOP while open), `RosterCloseButton`, tap-outside close. Instancing it into `scenes/ui/hud.tscn` puts the entry on the battle screen with zero battlefield.gd involvement — exactly the review-suggested resolution.
- **Read-only in battle and at the ending** (reviewer suggestion adopted): `roster_panel.gd` gains `@export var read_only: bool = false`; when true, `_remap_equip_buttons()` binds **zero** pool buttons (`equip_button_count == 0`, equip section shows a 只读 marker). Rationale: equip writes `SaveManager.profile.equip()`; mid-battle profile writes would make the zero-diff pin ambiguous and touch save state during combat. Cultivation/map instances keep interactive equip (`roster_equip_free_action` 36/36 stays green and untouched).
- **Input shield while open:** the dim layer already blocks mouse (STOP = only interaction surface). For keys, `hud.gd` (unlocked) gains an `_unhandled_input` guard: while `RosterPanel.is_open`, consume unhandled input (keyboard must not reach battlefield handlers through a panel the locked host does not know about). Same guard added in `ending.gd`.
- **Zero-diff pin:** open → close leaves `CombatManager.is_paused`, `current_round`, `turn_order`, `active_unit_name`, `Player.health` unchanged and zero runtime errors. The panel never touches CombatManager.
- Geometry: the panel instance's `RosterOpenButton` is repositioned per-instance (editable-instance offset in `hud.tscn`, e.g. below the top-right button stack: PauseButton y8–44, EndTurnButton y96–132 → open button y48–84) so it does not collide with the pause/end-turn stack; `UiOcclusionWatch` frames cover it.

If implementation discovers the panel cannot be made zero-diff without battlefield.gd cooperation → **STOP and report** per the brief's own C4 rule.

### 2.3 game_manager.gd is locked — battle "return to main menu" route

The pause menu must route to the main menu using an **existing public API only** (no locked-file edit). Candidates verified present: `GameManager.enter_segment("MENU")` (public, used by map.gd for ENDING) and `GameManager.restart_game()` (existing full-reset path; per the huashan round it also clears `map_battle_id`). W0 probe task (§9) decides: prefer `enter_segment("MENU")` if the state guard accepts a BATTLE source; otherwise `restart_game()`. The confirm copy already promises 本局进度将丢失, so the reset semantics are honest either way. If **neither** public route works from BATTLE → STOP and report (no locked edit, no scene_manager.swap_to hack that would desync state).

---

## 3. Architecture

```
Autoloads (unchanged unless named):  GameManager (LOCKED)  SceneManager (LOCKED)  SaveManager
                                     CombatManager (unlocked)  I18n  UiOcclusionWatch  InputGate

CULTIVATION SCREEN  scenes/segments/cultivation.tscn + scripts/segments/cultivation.gd  [EDIT]
  C2: GONGFA_PICK empty branch -> return to ACTION_PICK (no _after_action, month/silver zero delta)
  C1: ConsequenceLabel (new) + pure _consequence_text(phase, index) fed by CardData/EventData/
      ProgressionGongfaData/ProgressionMath; inline effect suffix on card/work option labels
  C3: BackButton (new) + ui_cancel -> _on_back() per-phase map; EVENT explicitly excluded
      two-press confirm arm on the empty-practice exit button is NOT needed (it is a return, not a commit)

SECT SELECT  scripts/segments/sect_select.gd  [EDIT]
  C1: consequence area for focused sect (gongfa list + three-year teaching from ProgressionGongfaData)
  C3: two-press armed confirm on join (first press arms, zero writes; second press commits)

CREATION  scripts/segments/creation.gd  [EDIT - point cost only]
  C1: per-attribute +/- buttons show next-point cost from _step_cost(v) and remaining points (always visible)

MAP SCREEN  scenes/segments/map.tscn  [EDIT scene only] + scripts/segments/map_travel_hints.gd  [NEW]
  map.gd itself: NOT EDITED (locked). Sibling poller: node-type hint + ending travel gate (§2.1)

YEAR-END (inside cultivation.gd phases YEAR_END / SECT_SWITCH)
  C1: switch consequence text (keeps learned gongfa; next-year grade from new sect, data-composed)
  C3: back (YEAR_END -> ACTION_PICK at month 12; SECT_SWITCH -> YEAR_END); confirm on the sect-switch
      commit (the irreversible write inside _resolve_sect_switch) — first pick press arms, second commits

BATTLE HUD  scenes/ui/hud.tscn + scripts/ui/hud.gd + scripts/ui/pause_button.gd  [EDIT]
  + scripts/ui/pause_menu.gd  [NEW]   + scripts/ui/roster_panel.gd  [EDIT: read_only export]
  C4: RosterPanel instance (read_only) + input shield + zero-diff pins
  C3: pause opens PauseMenu (继续 / 返回主菜单); main-menu item needs a second press; route via
      existing public GameManager API (§2.3); is_paused semantics unchanged (existing pins safe)
  Feedback: combat_log.gd / floating_number.gd already exist and are hooked in combat_manager.gd
      (unlocked) with debug counters — audit + gap-fill only, no rebuild

ENDING  scenes/segments/ending.tscn + scripts/segments/ending.gd  [EDIT]
  C4: RosterPanel instance (read_only, 查看角色 entry = the panel's own RosterOpenButton) + input shield

DATA SOURCES (read-only, never edited): card_data.gd, event_data.gd, progression_gongfa_data.gd,
  progression_math.gd, map_data.gd, facility_data.gd, equipment_data.gd, trait_data.gd

I18N  scripts/autoload/i18n.gd  [EDIT: EN table only-add]

PLAYTEST  playtest/_common.yaml [surface only-add + scenario_order] · 3 re-derived nails · ~24 new yamls
          tests/test_playtest_contract_smoke.py [ROUND_SCENARIOS sync — the second registry place]
```

Data flow for a consequence render (all C1 screens): focus change (keyboard cycle, mouse hover, or initial render) → `_consequence_text(phase, focus_index)` composes from data modules via `tr()` → description Label text + `consequence_text`/`consequence_matches_focus` surface vars updated → nail asserts changed + non-empty + computed boolean. Commit still happens on the existing single press/accept path (one-tap commit is pinned by existing scenarios; touch reachability comes from always-visible inline suffixes, matching the facility/skill-bar precedents).

---

## 4. Component specs

### 4.1 `scripts/segments/cultivation.gd` (edit — C2, C1, C3)

Responsibilities: monthly phase machine (unchanged shape), plus three additive channels.

- **C2 — empty GONGFA branch.** In `_on_accept()`'s `"GONGFA_PICK"` arm (currently ~:375-389): empty `ids` → `status_text = tr("功法均已大成，已返回行动重选")` (new i18n key), `phase = "ACTION_PICK"`, reset the ACTION_PICK option focus to the practice entry, `_sync_surface()` + `_render()`, and **no `_after_action()` call**. The self-justifying comment block describing the burned-month exit is rewritten to describe the return (content-located grep for 照常过去 / soft-lock prose; also fix any other comment still describing the old behavior — the brief's `:720-724` pointer is drifted). The empty-state button label returns to `tr("返回行动")` (existing key) — a return button must not call itself 度过本月. The **non-empty** practice path is byte-identical (regression pin: `practice_target_receipt` 43/43, `cultivation_month_cycle_and_deck_bookkeeping` 17/17).
- **C1 — consequence renderer.** New `ConsequenceLabel` node in `cultivation.tscn` (below the option button column; autowrap; HintLabel-adjacent styling; must keep `creation_layout_readability`-class geometry safe and `UiOcclusionWatch` clean). New pure function `_consequence_text(phase: String, index: int) -> String` composed per phase:
  - `CARD_PICK` / `YEAR_AUGMENT`-staged cards: effect fields from `CardData.TABLE` (effect_type / effect_value / effect_target; items via existing `CardData.display_name_of`).
  - `ACTION_PICK` work option: exact numbers `"银两 +%d"` from `ProgressionMath.work_income(month)`; additionally the work button label gets the same inline suffix (skill-bar precedent, always visible for touch).
  - `GONGFA_PICK`: focused gongfa's mastery grant — what 大成 unlocks (grade from `ProgressionGongfaData`, current 练度, grant text from data).
  - `EVENT`: focused option's cost+gain from `option.effects` (silver delta, item names, attr gains) — the 银两不足 case becomes visible **before** the click.
  - `YEAR_END` 另投他派 / `SECT_SWITCH`: keeps learned gongfa; next-year teaching grade comes from the new sect (`ProgressionGongfaData.GRADE_BY_YEAR`), composed, not hand-written.
  Card option labels also gain a short inline effect suffix (data-composed) so touch users see consequences with zero interaction. Update sites: `_cycle_focus()`, `_render()`, and initial option rebuild. Observables: `consequence_text: String`, `consequence_matches_focus: bool` (recomputed true only when the text was composed from the focused item's data — the computed boolean the nails assert).
- **C3 — back.** New visible `BackButton` in `cultivation.tscn` (visible only in ATTR_PICK / GONGFA_PICK / CARD_PICK / YEAR_END / SECT_SWITCH; hidden in ACTION_PICK / EVENT), wired to new `_on_back()`; `_unhandled_input` gains `ui_cancel` → `_on_back()` **with an explicit EVENT early-out** (the no-exit ruling). Back targets: GONGFA_PICK/ATTR_PICK/CARD_PICK → ACTION_PICK; YEAR_END → ACTION_PICK (month stays 12; `_after_action()` at month 12 re-enters YEAR_END on the next committed action — verified: its month-12 branch sets YEAR_END without advancing, so backing out cannot skip the year-end); SECT_SWITCH → YEAR_END. Back performs **only** phase + focus-index writes; month/silver/profile untouched. Observables: `back_button_visible: bool`, `back_target_phase: String`.
- Keep `tests/test_touch_option_surface_gate.gd` (every reachable player-choice phase yields ≥1 visible wired control) green — the back button additions only add controls.

### 4.2 `scripts/segments/sect_select.gd` (edit — C1, C3)

- C1: focused sect's consequence area (BodyLabel suffix or dedicated label): gongfa list + three-year teaching composed from `ProgressionGongfaData.SECTS` / `PRACTICE_TO_MASTER` / `GRADE_BY_YEAR`; observable `consequence_text` + `consequence_matches_focus`.
- C3: `_pick()` currently commits on first press (`_on_sect_pressed` → `_pick()`, and ui_accept → `_pick()`). Change to the `_delete_armed` two-press pattern: first press on a sect sets `focus_index`, renders, and arms (`confirm_armed = true`, status line `tr("⚠ 再按一次确认拜入「%s」")`); **zero writes**; second press on the same sect commits (existing path, byte-identical commit). Pressing a different sect re-arms to the new one. Keyboard ui_accept arms/confirms symmetrically. Observable: `confirm_armed: bool`.

### 4.3 `scripts/segments/creation.gd` (edit — C1 point cost only)

Beside each attribute ± button (exact node names per `creation.tscn` — implementer confirms; trait toggles are `TraitToggle0..12` and stay untouched), render the **next-point cost** and remaining budget, computed from `_step_cost(v)` and `points_left` (e.g. `＋1 需 2 点 · 剩 28`; decrement shows the refund). Always visible → touch-safe; hover preview channel (`trait_hover_index`) untouched. Observable: `attr_cost_text: String` (+ per-row `attr_step_cost: int`). No other creation change.

### 4.4 `scripts/segments/map_travel_hints.gd` (new) + `scenes/segments/map.tscn` (scene edit only)

Full spec in §2.1. Node additions: `MapTravelHints` (Control, script above, mouse_filter IGNORE) with children `TravelHintLabel` (Label) and `TravelGateShield` (Control, STOP-when-armed) and the confirm dialog (`TravelGatePanel` + `TravelGateConfirmButton` / `TravelGateBackButton` + dim). Observables: `travel_hint_text`, `travel_gate_visible`, `travel_gate_armed`. Guards: host/`MapData` lookups null-safe; when `phase != "TRAVEL"`-equivalent (EVENT/FACILITY open) the hint hides and the gate disarms. Facility/event prose untouched (the `test_facility_copy_location.py` prose guard stays green — type words are chrome, not facility prose).

### 4.5 `scripts/ui/pause_button.gd` + `scripts/ui/pause_menu.gd` (new) + `scenes/ui/hud.tscn`

- `pause_button.gd` keeps its exact contract (`CombatManager.toggle_pause()`, text sync via `paused`/`unpaused` signals — no assertion reads the text today). One addition: when a toggle results in paused, also open the pause menu; menu's 继续 calls the same `toggle_pause()` (net effect identical to today's second press, plus a visible menu).
- `PauseMenu` (new node in `hud.tscn`, script `pause_menu.gd`): opaque panel + dim, children `PauseContinueButton`, `PauseMainMenuButton`. 返回主菜单 uses the two-press arm (`confirm_armed`, status `tr("⚠ 再按一次确认返回主菜单，本局进度将丢失")`); on confirm → route per §2.3. Opening the menu never writes combat state; `is_paused` is owned by the existing toggle exactly as before.
- Observables on HUD: `pause_menu_open: bool`, `pause_menu_armed: bool`.

### 4.6 `scripts/ui/roster_panel.gd` (edit) + `scenes/ui/hud.tscn` / `scenes/segments/ending.tscn` / `scripts/ui/hud.gd` / `scripts/segments/ending.gd`

Per §2.2: `@export var read_only: bool = false`; instances in hud/ending set `read_only = true` and reposition `RosterOpenButton`; hosts gain the open-state input shield; `hud.gd`/`ending.gd` publish the panel's `is_open` through their existing surface style (mirroring `roster_panel_cultivation_open_close`). Existing cultivation/map instances unchanged (`read_only` defaults false → behavior identical).

### 4.7 `scripts/autoload/combat_manager.gd` (audit + gap-fill only) and battle feedback

R4 already landed the components and hooks: `combat_log.gd` (bottom-left 6-line log, own CanvasLayer), `floating_number.gd`, counters `debug_combat_log_lines` / `debug_float_numbers_spawned`, hit line `"%s → %s −%d (剩 %d)"`, and the status-caused zero-move line (`"%s 移动 0:被点穴封身"`). R5 work:
1. **Audit every damage-application path** in `combat_manager.gd` (unlocked) so each landed hit routes through the log/float hook helper (player→enemy, enemy→player, skill, counter, DoT). Gap-fill in unlocked files only.
2. If a hit path applies damage outside `combat_manager.gd` (e.g. directly in the locked `battlefield.gd`) → **STOP and report** that path; do not edit.
3. Verify/extend the pin that an enemy→player hit produces a log line and a spawned float (attacker, target, damage, remaining HP), and that a status-caused `移动 0` turn produces the explanatory log line (playtest #5 red: round-6 zero-move unexplained).
4. **Move-range preview on skill selection** (playtest #5 red): `range_highlight.gd` (blue, "selected-skill range/target highlight") and `player.gd::selected_skill_index` (unlocked) already exist; W0 first runs `skill_hint_and_range_highlight.yaml`. If selection already highlights reachable tiles, the deliverable is the verification record; if the highlight only appears later (post-aim), extend the trigger from the selection side (`player.gd` / `hud.gd` / `skill_button.gd` — all unlocked) so selecting a skill highlights its range cells **before** any cast. No battlefield.gd edit; if the trigger can only live there → STOP and report.

### 4.8 `scripts/autoload/i18n.gd` (EN table only-add)

Every new composed string goes through `tr()` at its composition site with a Chinese-as-key EN entry. New-string inventory (keys indicative, final copy at implementation):

| Key (zh) | Used by | Composed from |
|---|---|---|
| `返回` | back buttons (cultivation) | — |
| `功法均已大成，已返回行动重选` | C2 empty branch status | — |
| `⚠ 再按一次确认拜入「%s」` | sect join arm | sect display name |
| `⚠ 再按一次确认改投「%s」，本年授艺自此改宗` | sect-switch arm | sect display name |
| `此去即结局：踏上%s后，江湖故事将落幕。` | travel gate body | end node display_name |
| `确认启程` / `返回` | travel gate buttons | — |
| `继续` / `返回主菜单` / `⚠ 再按一次确认返回主菜单，本局进度将丢失` | pause menu | — |
| `查看角色` | ending roster entry (button label override if needed) | — |
| `战斗` / `门派设施` / 事件 / `此去即结局` | map node-type words | MapData slots |
| `%s — %s` | map hint line | node name + type |
| `银两 +%d` / `银两 −%d` (work/event suffixes; reuse existing keys where present) | card/event/work suffixes | ProgressionMath / option effects |
| `＋1 需 %d 点` / `−1 退 %d 点` / `剩 %d` | creation point cost | `_step_cost`, `points_left` |
| `大成后：%s` / `三年授艺：%s` | gongfa goal / sect teaching | ProgressionGongfaData |
| `（战斗中只读）` | roster read-only marker | — |

R4's already-landed log/float strings are not re-touched; any *new* feedback string follows the same tr() discipline.

---

## 5. C2 — the three re-derived nails (line-by-line change tables, no deletions, no kept burned-month assertion)

Code change (single source of all three): cultivation.gd GONGFA_PICK empty branch — old block `status_text=…本月照常过去 / phase="ATTR_PICK" / _attr_focus=0 / _after_action()` → new block `status_text=…已返回行动重选 / phase="ACTION_PICK" / option-focus reset / _sync_surface()+_render()`, **no `_after_action()`**; comment block rewritten; empty-state button label 度过本月 → 返回行动.

**Nail 1 — `softlock_empty_practice_month_advances.yaml` → renamed `softlock_empty_practice_returns.yaml`** (the name must not lie; coverage is re-derived, not deleted). Registry sync in both places (`playtest/_common.yaml` `scenario_order`, `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS`) + repo-wide filename grep (any other reference listed in the change table). The R2 header/evidence block is preserved verbatim and an R5 section is appended (append-only history).

| # | Old (R2, measured) | New (R5) | Why |
|---|---|---|---|
| 1 | `name: softlock_empty_practice_month_advances` | `name: softlock_empty_practice_returns` (file renamed) | name==basename guard; name must not assert the reversed behavior |
| 2 | assert `CultivationScreen.month == month_before_accept + 1` | assert `CultivationScreen.month == month_before_accept` | return without burning the month |
| 3 | assert `CultivationScreen.phase == "CARD_PICK"` (next month staged) | assert `CultivationScreen.phase == "ACTION_PICK"` | return target |
| 4 | — (absent) | assert `CultivationScreen.silver == silver_before_accept` (differential captured at f0/entry) | zero-delta completeness |
| 5 | assert `status_text != ""` | kept verbatim | the player still sees why |
| 6 | description prose ("the month advances") | rewritten to return semantics | prose/assert consistency |
| 7 | boot shape (menu.tscn + `debug_seed_save` no-sect zero-arts + keyboard load) | kept byte-identical | same construction of the empty state; zero `debug_fast_forward` |

**Nail 2 — `clicks_only_gongfa_empty_exit.yaml` (same name, re-derived).** Keeps the clicks-only boot shape and the phase-diff pin.

| # | Old | New | Why |
|---|---|---|---|
| 1 | description says 「返回行动」 while the assertion pins the month+1 exit (self-contradiction flagged by the brief) | description rewritten to match the new assertion (click 返回行动 → ACTION_PICK, month zero delta) | prose/assert consistency |
| 2 | button-label + exit asserts pinned by R2's re-pointing (度过本月 → month advances) | assert button text `返回行动`; after the click: `phase == "ACTION_PICK"`, `month == month_before`, `silver == silver_before` | return + zero delta, clicks-only |
| 3 | empty-state asserts (exactly one button, `mastered_count == gongfa_count`, wired, no ▶) | kept verbatim | empty-state coverage preserved |

**Nail 3 — `gongfa_pick_empty_keyboard_return.yaml` (same name, re-derived).** Keyboard twin.

| # | Old | New | Why |
|---|---|---|---|
| 1 | exit assert: ui_accept empty branch → (R2) month+1 / CARD_PICK | assert ui_accept → `phase == "ACTION_PICK"`, `month == month_before`, `silver == silver_before` | return + zero delta via keyboard |
| 2 | empty-state asserts (single 返回行动 button, `mastered_count == gongfa_count`, `pressed_connected` truthy, `cursor_markers_visible == false`) | kept verbatim (button label returns to 返回行动 — the original assertion text becomes true again) | empty-state coverage preserved |
| 3 | boot shape | kept byte-identical | same construction |

Regression pins around C2 (existing, untouched, must stay green): `practice_target_receipt` (non-empty practice path), `cultivation_month_cycle_and_deck_bookkeeping`, `work_beats_idling` (verified this step: its idle leg uses `debug_fast_forward`, **not** the empty-GONGFA button — the brief's ⚠ re-route is therefore **not needed**; recorded so PM does not re-derive it), `save_load_roundtrip` 14/14, `event_travel_effects` 19/19.

---

## 6. C3 — return paths, confirmations, and the kunlun-gate fallout

### 6.1 Return matrix (zero state delta = `phase` restored + `month` + `silver` unchanged; profile untouched)

| Screen | Visible back | ui_cancel | Back target | Note |
|---|---|---|---|---|
| ATTR_PICK | BackButton | yes | ACTION_PICK | cultivate action not applied |
| GONGFA_PICK | BackButton | yes | ACTION_PICK | both empty (via return button) and non-empty lists |
| CARD_PICK | BackButton | yes | ACTION_PICK | declines the month's staged card; month not advanced |
| YEAR_END | BackButton | yes | ACTION_PICK (month stays 12) | year-end re-offered on next committed action (verified `_after_action` month-12 branch does not advance) |
| SECT_SWITCH | BackButton | yes | YEAR_END | previous step |
| EVENT | **none — excluded** | **consumed as no-op** | — | no-exit ruling **reaffirmed** in code (explicit early-out) + new pin + 90_decisions entry |
| sect_select (initial join) | none | no | — | gets the join confirm instead (§4.2); brief lists only SECT_SWITCH for back |

### 6.2 Confirmation matrix (two-press arm; first press = zero writes, zero RNG)

| Irreversible commit | Where | Arm copy | Commit |
|---|---|---|---|
| Sect join | `sect_select.gd::_pick()` | `⚠ 再按一次确认拜入「%s」` | existing commit path byte-identical |
| Year-end sect switch | the sect pick inside `_resolve_sect_switch()` (the write site: `sect_id` + `_advance_year()`) — **decision**: the confirm sits at the irreversible write, not at the 另投他派 menu entry, because entering SECT_SWITCH is itself reversible (back → YEAR_END) | `⚠ 再按一次确认改投「%s」…` | existing `_advance_year()` path byte-identical |
| Travel to ending | map sibling gate (§2.1) | `此去即结局…确认启程` | re-dispatch of the same button press |
| Battle → main menu | pause menu item | `⚠ 再按一次确认返回主菜单，本局进度将丢失` | existing public GameManager route |

### 6.3 Mandated re-derivation of existing scenarios crossing the new ending gate

The confirm changes the input contract of end-node travel, so every timeline that travels to 昆仑 needs **one inserted confirm press** (assertions unchanged — add, never remove; same precedent as R2's authorized yaml re-points):

`spine_to_ending.yaml`, `clicks_only_storyline.yaml`, `work_beats_idling.yaml` (both legs), `ending_last_month_choice.yaml`, `ending_divergent_playstyles.yaml`, `ending_tiers_differentiate.yaml`. Each gets a per-line change table in its delivery notes; no assertion text changes; `tests/test_ending_gate_pins.py` / `test_playtest_contract_smoke.py` guards must stay green (they pin properties the inserted press does not alter). New nail `travel_to_ending_needs_confirm` pins the gate itself (first press → dialog visible, `current_state == "MAP"`, `current_node_id` unchanged; confirm → ENDING).

### 6.4 New C3/C4/feedback nails (one per screen, per the brief)

| Scenario (new file) | Pins |
|---|---|
| `back_button_attr_pick_zero_delta` | enter ATTR_PICK → back → `phase == "ACTION_PICK"`, month/silver zero delta |
| `back_button_gongfa_pick_zero_delta` | non-empty GONGFA_PICK → back → ACTION_PICK zero delta (complements the empty-path C2 nails) |
| `back_button_card_pick_zero_delta` | CARD_PICK → back → zero delta |
| `back_button_year_end_zero_delta` | YEAR_END → back → month 12 / phase ACTION_PICK zero delta + one leg proving year-end re-offers after a committed action |
| `back_button_sect_switch_zero_delta` | SECT_SWITCH → back → YEAR_END zero delta |
| `sect_join_needs_confirm` | first press arms (no writes: sect/state unchanged), second commits (diff) |
| `year_end_switch_needs_confirm` | first pick press arms (`sect_id`/year unchanged), second commits |
| `travel_to_ending_needs_confirm` | §6.3 |
| `battle_pause_menu_continue_zero_delta` | pause → menu visible; 继续 → unpaused; `CombatManager` zero diff |
| `battle_return_to_main_menu_needs_confirm` | first press arms (still BATTLE), second → `MENU` |
| `event_phase_no_exit_reaffirmed` | ui_cancel during EVENT → `phase == "EVENT"` unchanged, zero delta (the reaffirmation pin) |
| `roster_panel_battle_open_close` | battle: open → `RosterPanel.is_open`; close → CombatManager zero diff; occlusion 0 |
| `roster_panel_ending_open_close` | ending: open/close → zero diff |
| `enemy_hit_float_and_log_visible` | enemy→player hit: `debug_combat_log_lines` increments with attacker/target/damage/remaining line; `debug_float_numbers_spawned` increments; status zero-move line present |
| `skill_range_highlight_on_select` | selecting a skill highlights range tiles before cast (verify-or-extend per §4.7) |
| `consequence_screens_occlusion_clean` | `UiOcclusionWatch.violations == 0` and `scan_ok == true` on frames covering every new desc area/dialog/menu/panel |
| C1 set (§ per-screen): `card_pick_consequence_focus`, `event_option_consequence_visible`, `sect_select_consequence_focus`, `map_travel_node_type_hint`, `year_end_switch_consequence`, `work_income_inline_numbers`, `gongfa_goal_mastery_grant`, `trait_point_cost_visible` | each: focus item 2 → description `changed` + non-empty + computed boolean tying text to data (e.g. contains the card's `effect_value`, the event option's silver delta, `10 + 3×work_months`, the sect's teaching grade, `_step_cost` of the next point) + occlusion 0 |

Surface additions (`playtest/_common.yaml`, **only-add**, plus the same names in `tests/test_playtest_contract_smoke.py` surface checks — the two registry places): `CultivationScreen.consequence_text/consequence_matches_focus/back_button_visible/back_target_phase`, `SectSelectScreen.consequence_text/confirm_armed`, `CreationScreen.attr_cost_text/attr_step_cost`, `MapScreen.travel_hint_text/travel_gate_visible/travel_gate_armed`, `Hud.pause_menu_open/pause_menu_armed`, `RosterPanel.read_only`. No existing surface entry is removed or renamed.

---

## 7. 技术栈

- **Godot 4.4 / GDScript only.** Built-ins: `Button` (focus/pressed), `Label` description areas, `Control` overlays with `mouse_filter`, `PanelContainer` + dim for dialogs, per-frame `_process` pollers, `tr()`. No plugins, no addons, no new assets, no engine/asset-pipeline changes.
- **No new systems.** One new gameplay-adjacent script (`map_travel_hints.gd`), one new UI script (`pause_menu.gd`), one export flag (`roster_panel.gd`), everything else edits existing files.
- **Verification stack (unchanged):** owner playtest harness (`playtest/*.yaml`, per-scenario files, `clicks:` real hit-testing), `tests/test_playtest_contract_smoke.py` (+ registry sync in two places), GDScript unit tests, `UiOcclusionWatch`, pytest prose/gate guards, red-first via the temporary-revert method (`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`, byte-identical restore, zero residue grep).
- **Linter manifest:** `.gd` is intentionally **not** listed (host-controlled `gdscript_check` gate); `.py` → ruff, `.md`/`.json`/`.yaml` → basic.

## 8. 扩展性考虑

- The consequence renderer is one pure function per screen (`_consequence_text(phase, index)`) — a new monthly phase or a new card field extends it in one place, and the computed-boolean observable pattern carries to new nails without new machinery.
- The map sibling is deliberately generic: node typing reads slot accessors, so future map nodes/battle slots (world-breadth round) get hints and the end-gate for free; only `MapData` rows change.
- `roster_panel.read_only` is an export — a future battle-equip decision flips one instance flag, not a redesign.
- The pause menu is a plain panel with two buttons; future items (e.g. settings) append rows.
- Deliberately **not** built: a generic tooltip/preview framework, a confirmation-service singleton, a consequence DSL — all rejected as over-design against the "不加系统" rule and the two-press in-repo precedent.

## 9. PM decomposition hints (workstreams, with file-touch lists and dependencies)

- **W0 probe (no deliverable code):** headless-probe `GameManager.enter_segment("MENU")` from BATTLE vs `restart_game()` (records the chosen route + guard evidence); run `skill_hint_and_range_highlight.yaml` to record the current range-highlight state; confirm `creation.tscn` attr-button node names; grep the repo for `softlock_empty_practice_month_advances` references. Gates W6/W9/W4/W5 details respectively.
- **W1 C2** (cultivation.gd empty branch + comment fixes + 3 re-derived nails + i18n keys). Independent; do first (it re-anchors the file other tasks edit).
- **W2 C1 cultivation** (ConsequenceLabel + `_consequence_text` + card/work inline suffixes + 4 nails). After W1.
- **W3 C1 sect/year-end** (sect_select desc + year-end switch desc + 2 nails). After W1 (shares cultivation.gd phases).
- **W4 C1 creation point cost** (+1 nail). Independent.
- **W5 C3 backs + EVENT reaffirm** (BackButton + `_on_back` + ui_cancel + 6 nails). After W1.
- **W6 C3 confirms** (sect join + sect switch arms + 2 nails). After W3.
- **W7 map sibling** (map.tscn + map_travel_hints.gd + 1 C1 nail + gate nail + the six kunlun-leg re-derivations + occlusion frames). Independent; largest single task.
- **W8 C4 roster** (read_only export + hud/ending instances + shields + 2 nails). After W0 route decision not required; independent.
- **W9 battle feedback + pause menu** (audit/gap-fill + pause_menu + 3 nails). After W0.
- **W10 records & sweep** (i18n EN completeness check, `consequence_screens_occlusion_clean`, surface/registry sync verification, delivery notes, red-first record file; C5 design-record updates land via the 5_design step: 40_ux_backlog rows closed with gate numbers, four 90_decisions entries, 00_roadmap queue advance, 99_changelog append-only row).

## 10. 设计变更 (durable-record deltas this round mandates)

1. **90_decisions:** four new entries — (a) consequences rendered from data before commitment (per-screen channel, facility/skill-bar precedent); (b) uncommitted selection screens are returnable with zero state delta; (c) EVENT keeps its no-exit ruling (**reaffirmed**, referencing the archived ruling, not silently overturned); (d) **softlock = no way out, not "month frozen"** — explicitly replaces the 854–866-era ruling (now in `design/archive/decisions_2026-08.md`; the archive stays untouched, the new entry supersedes by content and cites it). A fifth record notes the map Track B decision and the C4 read-only decision.
2. **Prose/assert consistency fixes mandated by the brief:** cultivation.gd empty-branch self-defense comment rewritten; `clicks_only_gongfa_empty_exit.yaml` description aligned with its assertion; the renamed nail's name made truthful.
3. **40_ux_backlog:** rows this round closes get CLOSED with gate evidence; UX-14 stays OPEN (record-only); the tutorial-dialog observation is recorded honestly rather than implemented.
4. **00_roadmap / 99_changelog:** queue advanced; changelog append-only (one row, 2026-09-03).
5. No `design/20_content.md` numeric changes; no RNG/规则 changes beyond the named phase-machine branch.

## 11. Risks and STOP conditions

| Risk | Mitigation |
|---|---|
| Ending gate breaks the six kunlun-crossing scenarios | §6.3 one-press re-derivations with change tables; assertions only added |
| Sibling↔host coupling (focus_id/current_node_id) drifts in a future round | Null-safe degradation (no hint, no gate); coupling documented; map.gd stays byte-identical (machine-verifiable) |
| `map_hint_single` / shaolin / facility gates disturbed by the new label | New label is a separate node; gate inert off the end node; three verbatim gates run byte-untouched after W7 |
| Roster panel eats a board click in battle | Dim STOP is the only surface while open (existing pattern); keyboard shield while open; zero-diff pin |
| Battle→MENU route guard | W0 probe; two sanctioned routes; STOP if neither works |
| New buttons/desc areas regress geometry or occlusion | Occlusion scenario covers every new surface; per-screen nail asserts visibility; existing geometry gates (`ui_geometry_readability` 38/38) must stay green |
| Registry misses a renamed scenario | Repo-wide filename grep listed in the change table; pytest name==basename guard catches misses |
| Feedback gap only closable in battlefield.gd | STOP-and-report that path; deliver the rest |

**Standing STOP rules:** six locked files, three verbatim gates, RNG lifeline — any task that finds itself needing to edit them stops and reports instead. No `# TEMPORARY RED-FIRST REVERT` marker may remain in any delivered tree (grep zero hits).

## 12. Self-check against the brief

- C1 covered for all named screens incl. trait point cost and skill-range preview; already-good screens untouched. ✔
- C2 return + zero-delta, three nails re-derived line-by-line, no deletions, no kept month+1 assertion, non-empty path pinned, 90_decisions replacement entry. ✔
- C3 back on five screens + confirmations on three irreversible commits + pause menu + EVENT reaffirmed. ✔
- C4 entries on battle (HUD layer, read-only) and ending; zero-diff + occlusion pins; battlefield.gd untouched with STOP rule. ✔
- Feedback: floating text + log verified/completed on unlocked paths; 0-move explanation pinned. ✔
- C5 records, changelog append-only, contradictory prose fixed, red-first four-value discipline throughout. ✔
