# 技术架构设计 — Fully Clickable: Every-State Touch Reach (jinyong, Godot 4)

**Date:** 2026-08-30 · **Step:** 2 (Architect) · **Input:** Project Brief + Step 1 SOTA report
(`step1_sota.md`) + full code read of `scripts/segments/cultivation.gd` (905 lines),
`scripts/segments/map.gd` (578), `scripts/segments/sect_select.gd` (80),
`scripts/segments/transition.gd` (66), `scripts/segments/creation.gd` (792),
`playtest/_common.yaml`, `playtest/clicks_only_storyline.yaml`, the design archive.

All file paths below are **repo-root-relative** (`./scripts/...`). All file:line
references were read from the working tree on 2026-08-30 (not quoted from memory).

---

## 0. One-paragraph summary

This round makes the button pool the **only** rendering of every option list
(cultivation / map / sect_select — creation is already single-surface), moves the
keyboard selection onto the buttons themselves (modulate highlight, creation
precedent), fixes the `GONGFA_PICK` empty-list dead-end with a tappable exit that
delegates through the **existing** `_on_accept()` (zero forked phase logic), adds a
clicks-only nail scenario that proves `GONGFA_PICK → ACTION_PICK` **actually
transitions** (with measured, not predicted, first-red values), adds a property-based
coverage gate that **traverses the phase machine** and asserts every reachable
player-choice state produces ≥ 1 wired tappable control, lands the carried-over
`tails_corrections` card (README Q6 71/0 + one pointer line in the walkthrough
delivery note), and updates the design archive (new `design/31_touch_coverage.md`,
rule in `30_presentation.md`, decisions in `90_decisions.md`, changelog row).

No numbers, no battle rules, no camera/coord changes, no new assets.

---

## 1. Verified baseline (do not re-investigate)

### 1.1 The duplicated-UI defect (measured, `▶` sites)

| File | `▶`/duplication site | What is duplicated |
|---|---|---|
| `scripts/segments/cultivation.gd` | `:798` `:802` (card hint lines), `:807` (ACTION_PICK rows), `:821` (GONGFA_PICK rows), `:828` (ATTR_PICK rows), `:836` `:838` (EVENT rows), `:845` (YEAR_END rows), `:853` (SECT_SWITCH rows), `:864` (`_card_rows`) | `_rebuild_options_box()` `:534-590` builds `CultOptionButton{i}` with the SAME labels in the SAME order |
| `scripts/segments/map.gd` | `:513-514` (EVENT option rows), `:523` (`▶ ` + facility action label), `:536` (`▶ %s（此处）` TRAVEL marker), `:537-538` (`（可前往）` focus marker) | `EventOptionButton0/1` (`:477-486`), `FacilityUseButton` text (`:490-496`), `TravelButton{i}` texts (`:469-476`) |
| `scripts/segments/sect_select.gd` | `:70` (row marker) | `SectButton0..4` texts (`:77-80`) carry the same display names |
| `scripts/segments/creation.gd` | **already single-surface** — only `▶` mention is the runtime probe (`cursor_markers_visible`, `:70`, recomputed each `_render`) | none — the precedent to copy |

### 1.2 The `GONGFA_PICK` dead-end (measured)

- `cultivation.gd::_rebuild_options_box` `:534-590`; `box.visible = not labels.is_empty()` `:579`
  → zero options ⇒ hidden box ⇒ zero tappable controls.
- `GONGFA_PICK` branch builds labels from `_unmastered_ids()` `:553-562` → all-mastered
  profile ⇒ zero buttons.
- The only exit is keyboard: `_on_accept()` `:221-229`
  (`if ids.is_empty(): phase = "ACTION_PICK"`).
- On-screen hint `:815-816` 「暂无未大成武功，改选修习吧。」 says nothing about the exit
  (the keyboard hint 「上下选择，回车苦练」 sits in the `else` branch only).
- The self-justifying comment to rewrite: `cultivation.gd:529-533` ("The box hides when
  the phase offers nothing to pick (GONGFA_PICK with an empty unmastered list — the
  keyboard path auto-returns to ACTION_PICK there; a defensive EVENT with an
  unresolvable event id) …").
- Defensive-only zero-button state: `EVENT` with an unresolvable `event_id`
  (`:567-571` label build; `:833-840` render). Unreachable through the machine
  (every `event_id` comes from a validated pool draw / deterministic binding) — the
  survey records it as defensive; the coverage gate never reaches it.

### 1.3 What already exists and must be reused (not reinvented)

- **Single-surface precedent:** `creation.gd` — buttons are the only operation surface;
  keyboard focus is an int var driven by `_unhandled_input`; selection is expressed ON
  the button via `modulate` (focused row bright, others dimmed); click handlers delegate
  to the SAME keyboard handler; `cursor_markers_visible` publishes "no `▶` anywhere" as
  a machine-checkable observable.
- **Wired-ness contract:** `pressed_connected` dictionaries on CultivationScreen
  (`cultivation.gd:97`, re-snapshotted `:580/:590`), MapScreen (`map.gd:81`, filled
  `_wire_buttons` `:324-342`), SectSelectScreen (`sect_select.gd:14`, `:22-28`) — all
  already whitelisted in `playtest/_common.yaml`.
- **Clicks-only precedent:** `playtest/clicks_only_storyline.yaml` (47/47, zero
  keyboard actions, red-first evidence block in its header).
- **Harness truth:** `clicks:` is a real hit-test (`push_error` → hard-gate red on
  miss); `actions:` key injection bypasses the GUI phase. `debug_win_tutorial` is the
  one sanctioned non-click seed.
- **Rebuild discipline:** `cultivation.gd:518-540` — `remove_child` + `queue_free`
  (never `free()`) because a click re-enters the rebuild from inside the emitting
  button's own `pressed` emission. Any new button logic must preserve this.
- **Focus-mode rule:** every new button keeps `focus_mode = FOCUS_NONE`
  (`cultivation.gd:585` already does; the `battle_focus_arrow_keys` lesson).
- **No GUI focus:** zero uses of `grab_focus`/`focus_neighbor_*`/`has_focus` repo-wide;
  keep it that way (Step 1 §1.3/§2.2 — rejected for measured failure in this repo).

---

## 2. Architecture: one surface, one handler

Four rules, applied to all four segments (creation already complies):

1. **Buttons are the option surface.** `_render()` never prints an option row that
   duplicates a button. Descriptive text (event title/prose, facility cost summary,
   stats header, map overview, sect internal/external info lines, card category
   labels, HP/attr numbers) is untouched — only word-for-word duplicated option rows
   and the `▶` cursor glyph are removed.
2. **Selection lives on the button.** Keyboard focus stays an int var (no GUI focus);
   after every render the button at the focused index is highlighted (`modulate` full
   white `Color(1,1,1,1)`), all others dimmed (`Color(0.72,0.72,0.72,1)`) — the exact
   creation.gd idiom. Arrow keys move the var; the highlight follows.
3. **Clicks delegate.** Every click path continues to route through the existing
   handler chain (`_on_option_pressed` → `_on_accept`; `_on_travel_pressed` →
   `_travel`; `_on_sect_pressed` → `_pick`). Zero new phase logic.
4. **Every reachable player-choice state produces ≥ 1 wired tappable control.** The
   constructor guarantee (`_rebuild_options_box` / `_sync_click_buttons` /
   `_wire_sect_buttons`) is enforced by the coverage gate (§6), and the dead-end
   comment at `cultivation.gd:529-533` is rewritten to describe this guarantee.

Keyboard hints (「上下选择，回车执行」 etc.) are **kept** (rationale in §10 and
`90_decisions.md`): they are one-line operation summaries, not duplicated option rows;
removing them leaves desktop players without instructions, and UX-12 already records
the residual copy debt as a measured, open backlog item.

---

## 3. Component changes (the whole code diff, file by file)

### 3.1 `scripts/segments/cultivation.gd`

**(a) `_render()` — remove duplicated option rows + `▶` markers.**

| Phase | Removed from BodyLabel | Kept (descriptive, untouched) |
|---|---|---|
| YEAR_AUGMENT / CARD_PICK | `_card_rows(...)` output (name＋category rows = button labels verbatim) | phase title 【开年际遇】/【每月机缘】, hint 「左右选择，回车收取」 |
| ACTION_PICK | the 7 space-separated labels (`:805-808`) | 【本月行动】, the 删档 two-step warning `:809-810`, hint 「上下选择，回车执行」 |
| GONGFA_PICK | the per-art rows (`:818-822`) | 【练功】, hint 「上下选择，回车苦练」 (moved out of the `else` so it also shows when empty), **rewritten empty-list hint** (see (c)) |
| ATTR_PICK | the 5 `▶ 根骨 12` rows (`:826-829`) | 【修习】; attr values remain visible in the stats header `:790-792`; hint 「上下选择，回车修习（+1~+3）」 |
| EVENT | the two `▶ option` rows (`:836-839`) | 【游历 · 遇事】, event title + prose (`:834-835`), hint 「上下选择，回车定夺」 |
| YEAR_END | the two `▶ 留在本门/另投他派` rows (`:843-846`) | 【年关将至】, hint 「上下选择，回车决定」 |
| SECT_SWITCH | the 5 `▶ sect` rows (`:850-854`) | 【另投他派】, hint 「上下选择，回车拜入」 |

**(b) Selection on the button.** `_rebuild_options_box()` gains, after the existing
button-creation loop, a focus-resolution helper `_focused_index_for_phase() -> int`
(pure switch on `phase` returning the active focus var: `_card_focus` /
`_action_focus` / `_gongfa_focus` / `_attr_focus` / `_event_focus` / `_year_choice` /
`_switch_focus`) applied as `btn.modulate` — bright for `i == focused`, dim otherwise
(`btn.modulate` set inside the loop, using the helper; no new node, no theme edit,
no GUI focus).

**(c) `GONGFA_PICK` empty-list exit (the P0 fix).**
In `_rebuild_options_box()`'s GONGFA_PICK branch: when `ids.is_empty()`, append exactly
one label `tr("返回行动")` before the loop. The resulting `CultOptionButton0` clicks
through the untouched chain `_on_option_pressed(0)` → `_gongfa_focus = 0` →
`_on_accept()` → the existing empty branch `:223-224` sets `phase = "ACTION_PICK"`.
**No new transition code.** The empty-list hint at `:815-816` becomes
「暂无未大成武功。点击「返回行动」回到本月行动。」 (states the way out). The comment block
`:529-533` is rewritten to describe what the code now does, e.g.:
"Every player-choice phase leaves this box with at least one visible, wired button.
GONGFA_PICK with an empty unmastered list offers the single 返回行动 button whose
pressed path is the same `_on_option_pressed` → `_on_accept` chain every other option
uses (the empty branch inside `_on_accept` performs the return to ACTION_PICK)."
No keyboard branch changes (`_cycle_focus`/`_on_accept` bodies byte-identical).

**(d) New observables (surface, append-only).** Recomputed at the end of `_render()`:
- `cursor_markers_visible: bool` — true iff the composed BodyLabel text still contains
  `▶` (the creation.gd probe; the runtime proof the duplicated list is gone).
- `option_focus: int` — the active phase's focus var (via the same helper).
- `focused_option_text: String` — the label of the button at that index (empty if none).
All three are added to `playtest/_common.yaml`'s `CultivationScreen` surface block
(only-add).

### 3.2 `scripts/segments/map.gd`

**(a) EVENT panel** `:508-516`: remove the two `▶ option` rows by SHORTENING the
composite key itself: `tr("【%s】\n\n%s\n\n上下选择，回车定夺")` with args
`% [tr(def.title), tr(def.text)]`. The two option slots are **deleted from the key,
never fed `""`** — feeding empty strings renders 4 consecutive blank lines between
the event prose and the hint, which is exactly the dirt this round exists to remove.
The i18n EN entry is rewritten to the same 2-slot shape in the same commit (§8); the
guard maintenance that makes the key change legal is §7 (`tr()` call-site detection —
no allowlist entry is added for it).
**(b) FACILITY panel** `:517-531`: delete the `"▶ " + tr(fdef.action_label)` slot from
the composite key: `tr("【%s】\n\n%s\n\n%s\n\n%s")` with args
`% [tr(fdef.title), tr(fdef.text), summary, tr("回车使用 · 上下离开")]` — title, prose,
cost/effect summary (descriptive, stays) and the hint, one blank line between blocks,
matching the EVENT panel's rhythm. `FacilityUseButton` carries the verb. Same rule as
(a): slots are deleted, not blanked. The key is a 0-CJK format key today with no EN
entry and the coverage suite is green on that shape; the shortened key keeps exactly
that shape.
**(c) TRAVEL panel** `:532-556`: the node list is the **map overview — kept** (it lists
non-adjacent nodes too; it is descriptive, not an option list). Removed: the `▶`
glyph and the focus marker `（可前往）` (focus now lives only on the highlighted
`TravelButton{i}`; the overview list itself stays put, and the `elif focus_id`
branch collapses into the plain `  %s\n` row). Current-node row becomes
`tr("  %s（当前所在）\n") % name` — wording chosen for what it tells the player (you are
standing on this node, same register as the 「当前：%s」 line below the list), with the
2-space indent kept so node names stay column-aligned with the plain rows. Under §7
path 2 there is no length threshold to consider and none is considered. New EN entry
`  %s (current location)\n` (§8); the superseded keys' EN entries are deleted in the
same commit as their last call sites (§8's dead-copy rule).
**(d) Selection on the button.** In `_sync_click_buttons()`, set each visible
`TravelButton{i}`'s `modulate` bright when `nbrs[i] == focus_id`, dim otherwise; same
for `EventOptionButton{i}` (`event_focus`) and the two FACILITY buttons
(`FacilityUseButton` bright; `FacilityLeaveButton` stays the dim exit affordance).
**(e) New observable:** `cursor_markers_visible: bool` on MapScreen (recomputed at the
end of `_render()`; BodyLabel only — the footer `HintLabel` never contains `▶`).

### 3.3 `scripts/segments/sect_select.gd`

Remove the `▶` marker from the body rows (`:70`) and keep the per-sect info lines
(name —— 内功 X（attr） · 外功 Y（attr）) — they are descriptive, NOT word-for-word
duplicates of `SectButton{i}` texts (buttons carry the name only). Add the modulate
highlight on `SectButton{i}` per `focus_index` inside `_render()`. Add
`cursor_markers_visible: bool`. Keyboard branch (`:37-48`) byte-identical.

### 3.4 `scripts/segments/creation.gd` — parity check only

Already single-surface. No code change expected; the survey verifies focus-highlight
parity and records it. If (and only if) the survey finds a regression against the
§2 rules, the fix is scoped to the offending lines with before/after in delivery notes.

### 3.5 Explicit no-touch list (from the brief's non-goals)

`scripts/camera_follower.gd`, `scripts/coord.gd`, all `Coord` canvas-transform usage,
`ink_world_dx/dy`, `camera_offset_y`, `camera_transform_follows_unit.yaml`,
`portrait_grid_alignment.yaml`, `tests/test_playtest_contract_smoke.py::
_bad_timeline_at_values`, `tests/test_facility_copy_location.py`, no
`scripts/ui/roster_panel.gd`, no `toggle_roster` action, `card_data.gd::
display_name_of` untouched, no attribute/damage/price values changed,
`assets/themes/global_theme.tres` untouched.

### 3.6 Rulings for the adjacent files (recorded, no code change)

- `scripts/segments/transition.gd:65` 「继续 ▶」: **KEEP.** It is a glyph inside the
  button's own text (one surface, zero duplication), it is frozen i18n copy
  (`i18n.gd:120`), and no assertion depends on its removal. Recorded in
  `90_decisions.md`.
- `game_manager.gd` overlay (`ContinueButton` / `RetryButton`), `ending.gd`
  (`RestartButton`), `menu_panel.gd` / `settings_panel.gd`, `tutorial_manager.gd`
  (Next + SkipTutorial): already clickable with wired buttons — no change.

---

## 4. The GONGFA_PICK dead-end: player-visible walkthrough (acceptance criterion 8)

Enter 养成 → month 1 card → 本月行动 → tap 练功 → 【练功】 shows
「暂无未大成武功。点击「返回行动」回到本月行动。」 with ONE button 返回行动 → tap it →
back at 【本月行动】 → tap 修习/做工/游历 → keep playing. Zero keyboard.

---

## 5. New playtest scenario(s) + red-first protocol

### 5.1 `playtest/clicks_only_gongfa_empty_exit.yaml` (the nail)

- **Shape:** clicks-only (zero keyboard actions; no seed needed). Boot the same way
  sibling cultivation scenarios boot (implementer copies the boot shape of
  `playtest/cultivation_month_cycle_and_deck_bookkeeping.yaml` — direct segment boot
  with hermetic profile/seed via the established debug actions; autoloads load in
  scene-path mode). Fresh profile with no sect ⇒ `_grant_year_arts()` grants nothing ⇒
  `_unmastered_ids()` is empty ⇒ `GONGFA_PICK` is empty-list with zero setup.
- **Timeline skeleton (frames re-based by implementer to measured screen-ready timing,
  same discipline as the frame-timing fix):**
  1. click `CultOptionButton0` (card) → assert `CultivationScreen.phase == "CARD_PICK"`
     before, `"ACTION_PICK"` after.
  2. click `CultOptionButton0` (练功 is ACTION_PICK index 0) → assert
     `CultivationScreen.phase == "GONGFA_PICK"` **and**
     `CultOptionButton0.visible == true` **and**
     `CultOptionButton0.text == "返回行动"` (text contract, not a numeric) **and**
     `CultivationScreen.mastered_count == 0`-relative emptiness expressed as
     `CultivationScreen.gongfa_count == 0`… **No** — per the no-absolute-numbers rule:
     express "no unmastered arts" relatively: `CultivationScreen.mastered_count ==
     CultivationScreen.gongfa_count` (all owned arts mastered / none unmastered) plus
     `pressed_connected["CultOptionButton0"] == true`.
  3. click `CultOptionButton0` (the exit) → **assert
     `CultivationScreen.phase == "ACTION_PICK"`** — the phase-diff is the nail; a
     merely-present button does not satisfy it. Also assert
     `CultivationScreen.cursor_markers_visible == false` at both phases.
- **Header:** carries the RED-FIRST EVIDENCE block (measured values, see 5.3) and the
  self-run command, mirroring `clicks_only_storyline.yaml`'s header discipline.
- **Registration:** append to `playtest/_common.yaml` `scenario_order` (tail) **and**
  `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS` (two-place sync, both
  only-add), plus a new smoke pin function for its observable/keyboard-free shape.

### 5.2 `playtest/gongfa_pick_empty_keyboard_return.yaml` (cheap twin pin)

Same boot; two `ui_accept` presses; asserts `GONGFA_PICK` → `ACTION_PICK` by keyboard.
Protects the keyboard twin path of the same fix from future regression. Registered the
same two-place way. (If the implementer finds the keyboard return is already pinned by
an existing scenario, this file is optional — report either way.)

### 5.3 Measured-first-red protocol (hard condition, `implementer.md:23`)

1. Author the scenario FIRST, against the unfixed `cultivation.gd` (or apply a
   `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` to the empty-exit branch exactly as
   `red_first_evidence_measured` did for the overlay), then run
   `godot_playtest_scenario(scenario="clicks_only_gongfa_empty_exit.yaml")` via the
   external sidecar.
2. Record the four measured values — failing frame / first failing assert / exact
   error string / green asserts before red — into the scenario header AND
   `final/delivery_notes_touch_single_surface.md`. **Measured, never predicted.**
3. Land the fix, re-run: green with the phase-diff assert passing; restore any revert
   byte-identically.
4. The pipeline's `5_compile` gate later re-runs everything; the round does not
   pre-write gate numbers.

---

## 6. Coverage gate — property-based, traversal of the phase machine

**New file `tests/test_touch_option_surface_gate.gd`** (SceneTree-style integration
test, shaped like `tests/test_cultivation.gd`: hermetic fresh profile + seed,
`GameManager.current_state` forced, scene instantiated and added to root, fully
synchronous, no awaits). **Not** collected by `tests/unit_test_runner.gd` (it needs
autoloads); it is appended to the `run_tests.sh` integration-invocation list
(read `run_tests.sh`, copy the `test_cultivation` invocation line pattern).

**Property under test (game-level):** *every phase the machine itself reaches is
either exempted (no player action needed, documented) or its clickable-control
constructor produced ≥ 1 visible, wired (`pressed_connected` non-empty) control —
and no `▶` remains in the rendered body text.*

**Traversal = drive the machine through its own handlers** (the `match phase:`
dispatch arms are the adjacency table — no phase-name literal list):

1. **CultivationScreen:** from the boot phase, iterate to fixpoint with a guard
   counter: at each visited phase — (a) snapshot
   `OptionsBox.get_child_count() of visible Button children` +
   `pressed_connected` truthiness + `cursor_markers_visible == false`; (b) drive
   `_cycle_focus(1)` and `_on_accept()` (and once `_on_option_pressed(0)`) to discover
   successor phases; add unseen phases to the frontier. `debug_step_month`-style
   multi-phase months are reached exactly as manual play reaches them. Guard < 250
   iterations (same bound as `_fast_forward`).
2. **MapScreen:** boot `map.tscn`, then from `TRAVEL` drive `_on_travel_pressed(i)`
   legs to a node whose facility slot is active (`wudang`), through the EVENT opened on
   arrival (assert ≥ 2 wired `EventOptionButton`s), resolve it, enter via
   `_on_facility_enter_pressed()` (assert ≥ 2 wired FACILITY buttons — use AND leave),
   leave back to `TRAVEL`. Every visited phase: ≥ 1 visible wired control, no `▶`.
3. **SectSelectScreen:** boot `sect_select.tscn`; assert 5 visible wired
   `SectButton{i}` + `cursor_markers_visible == false`.
4. **Exclusion table, inside the gate** (a state is exempt iff **no input can change
   it** — pure display / auto-advance only): empty for all three machines today
   (`YEAR_AUGMENT/CARD_PICK/ACTION_PICK/GONGFA_PICK/ATTR_PICK/EVENT/YEAR_END/
   SECT_SWITCH` and `TRAVEL/EVENT/FACILITY` are all choice states; the gate still
   carries the table + the rule text so a future pure-display phase has a place to
   document itself). A new phase discovered by the traversal with zero buttons FAILS
   the gate with a self-explaining message (per the "形态闸门必须自我解释" rule):
   "new phase `<name>` produced 0 tappable controls — give it a clickable exit or add
   it to EXEMPT with a documented reason; do not weaken this gate".
5. **Scope note in the gate header + survey doc:** battle (HUD buttons + overlay,
   already covered by four click scenarios + `clicks_only_storyline`), creation
   (single-surface + `creation_single_ui`), menu/settings/tutorial/ending (stable
   button pools with existing scenarios) are outside the traversal's machines; the
   gate covers the three segments whose option pools are (re)built per render/state.

**Discipline (from `90_decisions.md` 2026-08-29):** after adding any `tests/*.gd`,
run an independent parse check BEFORE handing off — one parse error anywhere reds the
project-wide parse check and blinds every behavioral gate.

---

## 7. The copy-location guard — maintained, not dodged (round-owner-granted scope, 2026-08-30)

`tests/test_facility_copy_location.py` reds any ≥ 4-CJK double-quoted literal in
`map.gd` / `map_data.gd` that is not exempt. The previous draft treated the guard as
frozen and dodged it: composite keys kept byte-identical with `""` fed into the
removed option slots (4 blank lines on the EVENT panel, 2 on FACILITY) and copy
word-picked to stay under the threshold. That served the gate at the player's
expense. The round owner has explicitly unfrozen the guard for exactly two kinds of
maintenance (2026-08-30): (1) updating its exemptions for copy this round legitimately
shortens/deletes, or (2) implementing the file's own documented next step —
symbolizing the map.gd chrome via `tr()` call-site detection. **This design picks
path 2**, and explicitly forbids the behavior that made the guard a problem in the
first place: choosing words for their CJK count. Specification:

- **Detection, not whitelist, for map chrome.** `_cjk_literals()` keeps collecting
  every ≥ 1-CJK non-comment literal unchanged (the extraction-sanity floor logic
  stays intact). A new `_tr_call_literals(path)` helper collects the raw slices of
  literals appearing immediately after `tr(` on the same comment-stripped line
  (`tr\(\s*"((?:[^"\\\n]|\\.)*)"` — same per-line discipline as `_strip_comments`).
  In `test_no_inline_prose_in_map_files` the bad condition becomes
  `cjk >= PROSE_MIN_CJK and lit not in ALLOWED and lit not in tr_literals_of_that_file`
  — detection is ADDITIVE to ALLOWED, never a replacement: a non-tr ≥ 4-CJK literal
  still reds.
- **ALLOWED shrinks.** All nine chrome entries currently in ALLOWED are `tr()` first
  args in map.gd (verified 2026-08-30: the render templates at :515/:523/:532-555,
  `银两不足` :282, `修炼有得（第 %d 次）：%s` :304). Delete every entry that detection now
  covers; if any entry proves NOT to be a `tr()` first arg, it stays in ALLOWED and
  the delivery note says so. The module docstring's 此处/可前往 references and the
  per-entry comments are updated in the same edit.
- **The two symbol exclusions stay byte-identical.** The `ENDING_TIERS` block-skip and
  the `"display_name":` field-skip are the jinyong-panels acceptance this permission
  was meant to protect — untouched.
- **The anti-triviality floor is re-based, not weakened.** After the map.gd edits the
  collected literal set shrinks (two `▶`/`（可前往）` call sites deleted, one
  `（当前所在）` key added), so the `total >= 9` floor stops matching reality.
  Re-measure the extractor's count on the POST-EDIT tree and re-base the floor to
  that measured value with a dated comment (same discipline as the existing
  "measured 2026-08-30" comment), never below 3 — the floor exists to catch a broken
  extractor returning zero, and a measured re-base keeps it doing that job.
- **`test_no_prose_duplicated_from_data_modules` gains NO exemption.** It must keep
  comparing ALL ≥ 1-CJK literals of the map files against the data modules,
  INCLUDING `tr()` keys — otherwise a data-module sentence copied into map.gd and
  wrapped in `tr(...)` would evade both tests. Detection lives only in the first
  test. This is the no-weakening line of the whole maintenance.
- **Copy discipline unchanged (§433).** No prose moves into `map.gd` / `map_data.gd`;
  event/facility content copy still lives in `EventData.TABLE` /
  `FacilityData.TABLE`. Copy in map.gd must be a `tr()` key with an i18n entry —
  enforced from now on by structure (detection + `tests/test_i18n_coverage.py`), not
  by per-key whitelist upkeep.
- **No threshold word-picking.** Copy is chosen for what it tells the player
  (§3.2(c) 「当前所在」), never for its CJK count. The guard's failure message keeps its
  self-explaining escape hatch and now names the two legal fixes: make it a `tr()`
  key with an i18n entry, or move the copy to its data module.
- **Order of operations for the implementer:** land the guard change first and run
  `pytest tests/test_facility_copy_location.py` green on the PRE-edit tree (detection
  covers today's chrome, ALLOWED emptied, floor still satisfied), then edit `map.gd`,
  then re-run green on the POST-edit tree with the re-based floor. Any red in either
  run is investigated and reported, never absorbed.

### 7.1 Assertion-update policy (measured, not the brief's ~15 prediction)

Grep over `playtest/*.yaml` on 2026-08-30 for
`BodyLabel.text|ActionHintLabel.text|MoveHintLabel.text|HintLabel.text|MenuPanel.hint_text`
found 18 hits, **none of which pin a removed option row**: battle HUD rejection
reasons (`ActionHintLabel` ×8: `qi_cost_blocks_cast_no_energy`, `skill_hint_and_range_highlight`,
`skill_rejection_reason_texts`, `each_unit_acts_once…`), battle movement hints
(`MoveHintLabel` ×3: `move_target_affordance`), menu hint (`MenuPanel.hint_text` ×2:
`main_menu_entries`, `menu_load_continues` — descriptive, kept), map single-hint
invariant (`map_hint_single.yaml:30-31,43` — a NEGATIVE assert
`contains("回车启程") == false` that stays true, plus the EVENT hint line that stays),
and the footer text pin (`map_node_event_mainline_return.yaml:33`). **Expected
playtest-scenario assertion churn: zero edits.** The implementer re-runs the same grep
and reports the measured table in the delivery notes (before / after / equivalence
reason per line actually changed — possibly none), explicitly reconciling the brief's
~15 estimate against the measured set.

The §3.2 composite-key shortening rides on this same reconciliation: the shortened
EVENT key keeps the 「上下选择，回车定夺」 substring, so `map_hint_single.yaml:43`'s
`BodyLabel.text` contains-assert stays true; the footer pins read `HintLabel`, which
no body-key change touches. No playtest assert pins the deleted option rows or a
full-equality `BodyLabel.text` on a map panel — the grep above is the proof duty,
re-run after the key edits land.

**Unit tests that DO pin the duplication (must be re-targeted):**
- `tests/test_map_node_event.gd` `:388-408` — pins the `▶` marker in map EVENT body
  text → re-target to `EventOptionButton0/1` texts + `cursor_markers_visible == false`.
- `tests/test_map_facility_buttons.gd` `:431-437` — pins the FACILITY `▶ ` body
  advertisement → re-target to `FacilityUseButton.text` + `cursor_markers_visible ==
  false`.
Each re-target is listed before / after / equivalence-reason in the delivery notes.

---

## 8. i18n changes (`scripts/autoload/i18n.gd` EN dict — slot counts always match)

**Added:**

| zh key (call-site literal) | EN value |
|---|---|
| `返回行动` | `Back to Actions` |
| `暂无未大成武功。点击「返回行动」回到本月行动。` | `No unmastered arts to train. Tap "Back to Actions" to return to this month's actions.` |
| `  %s（当前所在）\n` | `  %s (current location)\n` |

**Rewritten in place (shortened key, EN value rewritten to the matching slot count in
the same commit — never a key whose EN value kept the old slot count):**

| key | before | after |
|---|---|---|
| EVENT composite | `【%s】\n\n%s\n\n%s\n%s\n\n上下选择，回车定夺` (4 slots), EN `[%s]\n\n%s\n\n%s\n%s\n\nUp/down to choose, Enter to decide` | `【%s】\n\n%s\n\n上下选择，回车定夺` (2 slots), EN `[%s]\n\n%s\n\nUp/down to choose, Enter to decide` |
| FACILITY composite | `【%s】\n\n%s\n\n%s\n%s\n\n%s` (5 slots, 0 CJK, no EN entry today) | `【%s】\n\n%s\n\n%s\n\n%s` (4 slots — keeps the 0-CJK / no-EN-entry shape) |

**Deleted (in the same commit as the call sites that used them):** the old 4-slot
EVENT entry, the old 5-slot FACILITY entry if present, `▶ %s（此处）\n`,
`  %s（可前往）\n`, 「暂无未大成武功，改选修习吧。」. Dead translations are where
slot-count mismatches hide; grep the call sites before deleting each entry.
Composed strings keep the `tr()` format-key convention and `tests/test_i18n_coverage.py`
stays green — every surviving call site keeps an entry, and removing an entry whose
last call site is gone cannot red a call-site→entry check.

---

## 9. Keyboard parity (what must NOT change)

- `_unhandled_input` bodies, `_cycle_focus`, `_on_accept`, `_pick`, `_travel`,
  `_resolve_node_event`, facility handlers: byte-identical.
- The GONGFA_PICK-empty keyboard exit (`cultivation.gd:223-224`) is untouched; the new
  button is its touch twin through the same handler.
- `focus_mode = FOCUS_NONE` on every button (existing convention; the new exit button
  inherits it from the shared creation loop at `cultivation.gd:585`).
- Existing keyboard scenarios must stay green unedited; `spine_to_ending.yaml`
  (42/42) is the byte-untouched proof. Any red is reported with cause — never
  papered over, no assertion weakened, no frozen yaml edited.

---

## 10. tails_corrections card (carried over, previously approved)

1. **`README.md` ~372-373:** the clause "two bad Q6 frames are parked as next-round
   review candidates and do not flip the gate" is factually wrong — the measured
   `vision_report.json` for the touch-reach round holds Q6 **good_answers 71 /
   bad_answers 0** (`scenarios_answered: 71`, `failed: false`, `failures: []`).
   Rewrite that clause to the measured 71/0 values (state: no Q6 bad answers that
   round; nothing parked). Everything else in the bullet (non-blind judge, 284
   frames, `passed: true`) stays.
2. **`final/delivery_notes_touch_reach_walkthrough.md`:** add **ONE line** at the top
   (after the Date/Task/Sources header block) pointing to
   `final/delivery_notes_touch_reach_red_first.md` as the authoritative MEASURED
   first-red values (f265 / first assert `ContinueButton.visible` / exact error
   `aim: node not found: ContinueButton (spec: ContinueButton)` / green-before-red 8).
   The predicted f180/5 table further down stays **byte-identical** — prediction vs
   measurement divergence is itself the record (brief-mandated).

---

## 11. Design-archive deliverables (5_design lands them; this run drafts the data)

- **NEW `design/31_touch_coverage.md`** — the survey (deliverable #1). Required table
  columns: `Segment | Phase/State | Clickable controls (file:line) | Touch-only exit?
  Y/N | Missing (if N) | Disposition this round`. Coverage: cultivation (8 phases),
  map (TRAVEL/EVENT/FACILITY + arrival dispatch), battle (BATTLE/WON/LOST overlay +
  combat phases — controls at hud.gd / game_manager.gd `:461+`), creation
  (ATTRS/TRAITS/CONFIRM), menu (4 entries), settings (5 rows), tutorial (7 steps),
  transition (2 pages), ending (RestartButton). Every row carries a file:line read
  from the post-change tree; the defensive `EVENT`-with-null-def states are recorded
  as unreachable-through-the-machine; deferred items (expected: none new; UX-12
  keyboard-hint copy remains OPEN with refreshed line numbers if they moved) go to
  `design/40_ux_backlog.md`.
- **`design/30_presentation.md`:** new rule in the pointer-reachability chapter:
  「每个需要玩家选择的状态都必须有可点出口」 + the single-surface rule (buttons are the
  only option surface; keyboard is a shortcut layer; selection is expressed on the
  button; `▶` cursor lists are gone).
- **`design/90_decisions.md`:** this round's rulings — (a) keyboard hints kept (reason);
  (b) transition 「继续 ▶」 kept (button-embedded glyph, not a duplicated list);
  (c) GONGFA_PICK exit delegates through `_on_accept` (no forked transition logic);
  (d) map TRAVEL node list kept as descriptive overview, focus markers removed;
  (e) selection highlight = modulate dim/bright (creation precedent; theme
  variations / ButtonGroup / GUI focus rejected per Step 1 §2);
  (f) coverage-gate exclusion rule + traversal scope;
  (g) the copy-location guard (`tests/test_facility_copy_location.py`) was MAINTAINED,
  not dodged: round-owner feedback (2026-08-30) unfroze it after the previous draft
  kept a 4-slot composite key alive with `""` slots — 4/2 consecutive blank lines
  rendered to the player so a whitelist could stay untouched. Path chosen: the file's
  own documented next step, `tr()` call-site detection for the map chrome (§7). The
  two symbol exclusions (`ENDING_TIERS`, `NODES[*].display_name`) stay byte-identical,
  no prose moves inline into map.gd (§433 unchanged), and no wording is picked to
  duck under the ≥ 4-CJK threshold. Rationale to record: per-key whitelist upkeep is
  what created the incentive to leave holes on the player's screen; detection removes
  the incentive structurally — copy in map.gd must be a `tr()` key with an i18n
  entry, or the guard reds it.
- **`design/99_changelog.md`:** one append row (run name e.g. `touch_single_surface`,
  date 2026-08-30).

**Delivery notes:** `final/delivery_notes_touch_single_surface.md` — per-screen
before/after, the measured affected-assertion table, re-targeted unit tests,
measured first-red values for the new nail, self-run observed values for every
new/changed scenario (hard condition), keyboard-hint rationale, and the
「肉眼可见」 walkthrough of §4.

---

## 12. Verification matrix (definition of done)

| Gate | Requirement |
|---|---|
| playtest | ALL scenarios green, incl. unchanged `clicks_only_storyline` (47/47 shape), `spine_to_ending`, `map_hint_single`, `map_facility_buttons_click`, `facility_use_reusable`, `creation_single_ui`; 2 new scenarios green; hard gate `passed: true`, 0 runtime errors |
| red-first | new nail's measured red values recorded before the fix (frame / assert / exact error / green count) |
| unit suite | GDScript suite green incl. re-targeted `test_map_node_event.gd` / `test_map_facility_buttons.gd` + new `test_touch_option_surface_gate.gd` (independent parse check run first) |
| pytest | `test_i18n_coverage.py` and `test_playtest_contract_smoke.py` (incl. new smoke pin + two-place sync) all green and unedited; `test_facility_copy_location.py` green after its granted-scope maintenance only (§7: `tr()` call-site detection + floor re-base; symbol exclusions and the data-module duplication test untouched) |
| archive | `design/31_touch_coverage.md` (file:line rows) + 30/90/99 updates + backlog refresh |
| tails | README Q6 71/0 + walkthrough pointer line landed |
| i18n | new keys in EN dict; coverage test green |

---

## 13. Suggested task decomposition (for PM)

1. `cultivation_single_surface` — 3.1(a)(b)(d) + i18n + surface adds + re-target
   cultivation-pinned unit tests if any.
2. `cultivation_gongfa_exit` — 3.1(c) + §4 walkthrough + comment rewrite.
3. `map_single_surface` — 3.2 (respect §7) + re-target the two map unit tests.
4. `sect_select_single_surface` — 3.3.
5. `nail_scenarios` — 5.1/5.2 + red-first protocol (5.3) + two-place registration.
6. `coverage_gate` — §6 gate + `run_tests.sh` wiring + parse check.
7. `tails_and_docs` — §10 + §11.

Order 1→2 can merge; 3/4/6 are independent; 5 depends on 2 (red must be measured on
the unfixed exit); 7 last. Every task carries its own delivery-notes slice.

## 14. Risks / known warts (accepted, documented)

- Map copy now rides on i18n: a shortened zh key and its slot-matched EN value must
  land in the same commit (a stale-slot translation renders broken text) — enforced
  by review plus `tests/test_i18n_coverage.py`; the survey records the before/after
  copy per panel.
- `modulate` is the least "themed" highlight (no border/fill change) — accepted; the
  theme holds fonts only and authoring styleboxes is out of scope (Step 1 §2.1/§2.3).
- The new observables (`option_focus` etc.) are mirrors of internal focus vars —
  they exist so playtest can assert game-level focus without reading underscore vars.
- If direct segment boot lacks a profile in the harness, the scenarios fall back to
  the sibling cultivation scenarios' established boot shape — implementer verifies
  against `cultivation_month_cycle_and_deck_bookkeeping.yaml` before authoring.
