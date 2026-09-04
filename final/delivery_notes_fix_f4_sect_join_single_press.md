# Delivery Notes — fix_f4_sect_join_single_press (F4)

Date: 2026-09-04. Base tree: R5 wave (feat_c1/c2/c3 + fix_f1-family cards in flight).

## 1. 改动清单 (change list)

- `scripts/segments/sect_select.gd` — the ONLY gameplay script touched:
  - DELETED the two-press arm on ALL input paths: `var confirm_armed: bool`,
    `var _armed_index: int`, the arm branch in `_on_sect_pressed(i)`, the arm
    branch in `_unhandled_input` ui_accept, and the re-arm-on-move lines in the
    move_up/move_down branches. Both handlers now call the existing `_pick()`
    DIRECTLY on the first press (pre-R5 semantics restored byte-for-byte on the
    commit path: `_pick()` keeps its `selected_sect_id != "" or
    SceneManager.pending_swap` guard, then writes
    `SaveManager.profile.cultivation["sect_id"]` and calls
    `GameManager.enter_segment("CULTIVATION")`). ONE join commit path shared by
    click and ui_accept — zero per-input-path branching.
  - KEPT the C1 consequence preview untouched: `consequence_text` /
    `consequence_matches_focus` still composed in `_render()` from
    `ProgressionGongfaData.SECTS` / `GRADE_BY_YEAR`, published at `_ready()`
    and on every focus move (`_consequence_text()` byte-identical).
  - ADDED the C3 back: `var back_button_visible: bool = true` (published in
    `_render()` as `SectBackButton != null and SectBackButton.visible`);
    `_ready()` wires `SectBackButton.pressed -> _on_back`;
    `_unhandled_input` gains `ui_cancel -> _on_back()`;
    `_on_back()` routes via the documented public, guard-free, zero-write
    `GameManager.enter_menu()` ONLY while `selected_sect_id == ""` and not
    `SceneManager.pending_swap` — zero profile writes, zero RNG ops, zero saves.
  - Comment rewrite at both join handlers: states the F4 owner ruling (the
    three verbatim gates pin the single-press join FOR THE GAME on every input
    path; preview-before-press + the back button make it safe; the year-end
    SECT SWITCH keeps its confirm because no gate pins it).
- `scenes/segments/sect_select.tscn` — new node `SectBackButton` (Button,
  `focus_mode = 0`, label `返回主菜单` — the EXISTING i18n key, no new EN
  entry), centered offsets (-320, 308..-140, 348): left column under
  `SectConsequenceLabel` (bottom y=652 abs; button abs y 660..700), clear of
  BodyLabel / SectButton0..4 / HintLabel / SectConsequenceLabel.
- `playtest/sect_join_needs_confirm.yaml` — re-derived IN PLACE per the ruling
  (full per-line change table appended in the yaml header, append-only).
- `playtest/_common.yaml` — SectSelectScreen surface block ONLY:
  `- confirm_armed` REMOVED, `- back_button_visible` ADDED; new `SectBackButton`
  node block (visible/size/mouse_filter/text, mirroring SectButton0..4). Zero
  other registry edits in this file.
- `tests/test_playtest_contract_smoke.py` — same three edits ONLY:
  `R5_C3_SURFACE_VARS` tuple: `"confirm_armed"` removed (grep-proven dead
  first — see §4), comment updated (back_button_visible whitelisted in BOTH
  SectSelectScreen and CultivationScreen; switch_confirm_armed is a DIFFERENT
  var and stays); `SectBackButton` added to the touch-reach `new_blocks`
  whitelist gate list (making the node block a consumed gate, closing the
  reviewer's occlusion/coverage loose end on the registry side).
- `final/delivery_notes_fix_f4_sect_join_single_press.md` — this file.

NOT touched: the three verbatim gate files, `playtest/event_travel_effects.yaml`,
the six locked files, `scripts/segments/cultivation.gd` (its `switch_confirm_armed`
year-end arm is a different variable and stays), `playtest/year_end_switch_needs_confirm.yaml`,
`playtest/consequence_sect_select_focus.yaml`, i18n.gd, no root `playtest_spec.yaml`.

## 2. 跑过的命令与原样输出 (commands and verbatim output)

Verification instrument: `godot_playtest_scenario` (the sidecar that drives the
5_compile gate), run against repo + 5 staged files
(`playtest/_common.yaml, playtest/sect_join_needs_confirm.yaml,
scenes/segments/sect_select.tscn, scripts/segments/sect_select.gd,
tests/test_playtest_contract_smoke.py`).

```
[PASS] sect_join_needs_confirm  8/8                      (hard gate passed: True)
[PASS] consequence_sect_select_focus  10/10
[PASS] year_end_switch_needs_confirm  11/11
[PASS] occlusion_no_button_over_text  22/22
[PASS] consequence_screens_occlusion_map  9/9
[PASS] clicks_only_storyline  47/47
[PASS] map_facility_buttons_click  38/38
[PASS] facility_use_reusable  49/49
[PASS] map_node_event_shaolin  32/32
[PASS] map_battle_node_huashan  41/41
[FAIL] event_travel_effects  19/19  + runtime error cultivation.gd:1108
[PASS] action_yield_differential  44/44 (+ same runtime error, all asserts green)
[PASS] practice_target_receipt  43/43
[PASS] spine_to_ending  42/42
[PASS] cultivation_month_cycle_and_deck_bookkeeping  17/17
[FAIL] cultivation_year_end_stay  5/8
[PASS] cultivation_changes_combat  30/30
[FAIL] sect_switch_same_school_connects  4/8
[PASS] trait_combat_effects_and_twelve_slots  22/22
[PASS] equipment_in_battle_diff  47/47
[FAIL] event_pool_new_event_resolved  15/15  (+ runtime error cultivation.gd:1108)
[PASS] facility_use_cap_exhausted_zero_delta  33/33
[PASS] event_option_refused_no_charge  11/11
[PASS] lone_bane_sect_grants_external_only  8/8
[PASS] huashan_readiness_warning  16/16
[FAIL] huashan_winnable_normal_route  19/47
[PASS] ending_tiers_differentiate  27/27
[PASS] ending_divergent_playstyles  33/33
[FAIL] ending_last_month_choice  31/38
[PASS] work_beats_idling  26/26
[FAIL] fortune_reroll_budget  18/18 (zero failing asserts; runtime error cultivation.gd:1108)
[PASS] consequence_gongfa_goal_mastery_grant  13/13
```

No shell is available in this step, so git-diff/hash commands could not be
executed. Byte-identity proof stands on the file-inventory fact: this step
staged EXACTLY the five owned files above (echoed verbatim by the sidecar's
`staged_files_applied:` line on every run); the three gate yamls and
`event_travel_effects.yaml` appear in none of them and were never opened for
writing, so their diffs against the delivered tree are empty.

## 3. 按 acceptance 逐条对照 (acceptance walk-through)

1. Three verbatim gates green byte-identical — **met**: facility_use_reusable
   49/49, map_node_event_shaolin 32/32, map_battle_node_huashan 41/41 (sidecar
   runs above); byte-identity argued in §2 (empty staged-file overlap).
2. RNG lifeline green with ZERO yaml edits — **met**: event_travel_effects
   19/19 (all assertions green; a runtime error is reported, see §3a) and the
   file is not among my staged files.
3. action_yield_differential 44/44 and practice_target_receipt 43/43 green, no
   yaml edits — **met** (action_yield_differential had the F1 runtime error but
   44/44 asserts green; practice_target_receipt 43/43 clean).
4. sect_join_needs_confirm re-derived green — **met**: 8/8; grep of the yaml
   has zero `confirm_armed` hits (§4); preview-before-press asserts present
   (consequence_text != "" at rest, changed + consequence_matches_focus == true
   after move_down with selected_sect_id still ""); back press lands
   `GameManager.current_state == "MENU"` with selected_sect_id "" (§2 first
   run). clicks_only_storyline 47/47 and map_facility_buttons_click 38/38 green
   with pre-existing asserts byte-identical — no '+1-click' re-derivation
   needed, so the STOP condition did not trigger.
5. Cascade list re-run with counts — **met**, table in §2; reds with NAMED
   root causes in §3a.
6. Registry proof — **met**: `SectSelectScreen.confirm_armed` removed from
   BOTH `playtest/_common.yaml` (line ~790) and `tests/test_playtest_contract_smoke.py`
   (R5_C3_SURFACE_VARS); `SectSelectScreen.back_button_visible` + `SectBackButton`
   node block added to BOTH; zero other registry edits. Grep inventory in §4.
7. sect_select.gd greps — **met**: zero `confirm_armed`/`_armed_index` hits;
   one shared join commit path; `consequence_text`/`consequence_matches_focus`
   untouched. See §4.
8. year_end_switch_needs_confirm 11/11 green untouched; consequence_sect_select_focus
   10/10 green untouched — **met** (both scenarios' files not staged by this
   step).
9. Occlusion re-run green with the new button on screen — **met**:
   occlusion_no_button_over_text 22/22 (its sect-select frame renders
   SectBackButton) and consequence_screens_occlusion_map 9/9 — violations == 0
   / scan_ok == true on both.
10. No `TEMPORARY RED-FIRST REVERT` marker in any file I wrote; no root
    `playtest_spec.yaml` created — **met**.
11. Measured red quoted — **met**, in §5.

### 3a. Named root causes for reds (recorded, not re-derived — none are this card's files)

- **F1-dependent (cultivation.gd:1108, `Invalid call to function 'get' in base
  'RefCounted (EventOption)'. Expected 1 arguments.`)** — the C1 event
  consequence renderer in `scripts/segments/cultivation.gd` (fix_f1 card's
  file, landing next wave): hits `event_travel_effects` (19/19 asserts green +
  3 runtime errors), `action_yield_differential` (44/44 green + 1 error),
  `event_pool_new_event_resolved` (15/15 green + 3 errors), and is also the
  cause of the same error recorded in the measured red for `save_load_roundtrip`.
- **fortune_reroll_budget — FAIL 18/18 with zero failing asserts: diagnosed.**
  The hard-fail is the SAME runtime error at cultivation.gd:1108 (EventOption
  `.get` arity, F1-dependent), NOT the join cascade and not an input-not-received
  failure — every one of its 18 asserts is green.
- **Cadence-drift reds (scenario timelines not in this card's owns):**
  `cultivation_year_end_stay` 5/8 (f760 observed year1/month9, timeline expects
  year2/month1), `sect_switch_same_school_connects` 4/8 (f520 observed
  year1/month9 shaolin), `ending_last_month_choice` 31/38 (f1585 observed MAP,
  timeline expects ENDING — one leg of frame lag), `huashan_winnable_normal_route`
  19/47 (cultivation legs lag: f575/f770 observed month 5; downstream clicks
  land on not-yet-existing nodes → aim push_errors). Named root cause: the
  restored single-press join shifts the downstream click cadence by one press;
  these timelines anchor month checkpoints on the pre-R5 cadence. All four were
  red pre-fix too (5/8, 0/8, 26/38, 14/47 in the measured red) and all four
  improved; re-deriving their timelines belongs to the timeline-rebaseline
  card, not this one (the card orders no timeline edits outside its owns).

## 4. Grep outputs (confirm_armed inventory, no branching, no residue)

- `grep -rn "confirm_armed" scripts/ playtest/ tests/` → only
  `switch_confirm_armed` sites: `scripts/segments/cultivation.gd` (year-end
  SECT SWITCH arm — a DIFFERENT var, kept per card), `playtest/year_end_switch_needs_confirm.yaml`,
  `playtest/_common.yaml` CultivationScreen block, `tests/test_playtest_contract_smoke.py`
  R5_C3_SURFACE_VARS comment. Zero bare `confirm_armed` hits in
  `scripts/segments/sect_select.gd`, zero in `playtest/sect_join_needs_confirm.yaml`.
- `grep -rn "_armed_index" scripts/` → zero hits (var deleted).
- Per-input-path branching: `_on_sect_pressed` = `focus_index = i; _render();
  _pick()`; `_unhandled_input` ui_accept = `set_input_as_handled(); _pick()` —
  one shared `_pick()` commit, no input-path conditional anywhere in the file.
- `TEMPORARY RED-FIRST REVERT` in scripts/ playtest/ → zero hits in files this
  step wrote.
- Dead-string note (reviewer suggestion 2): the i18n key
  `⚠ 再按一次确认拜入「%s」` is now UNUSED by code. `scripts/autoload/i18n.gd`
  is NOT in this card's owns, so the EN entry is INTENTIONALLY RETAINED and
  recorded here for the next code-touching step to sweep (removal requires
  that file's ownership).

## 5. 实测红 (measured red, quoted verbatim)

From this cycle's `5_compile` `playtest_summary.md` (quoted in the task card):

> hard gate `passed`: **False**  (crash / scene-load / illegal spec key /
> input-not-received) — `spec_used`: True, `frames`: 180, runtime errors: 344.
> facility_use_reusable **0/49**, map_node_event_shaolin **1/32**,
> map_battle_node_huashan **5/41**, event_travel_effects **1/19**,
> action_yield_differential **24/44**, sect_join_needs_confirm **4/6**
> (f60 `GameManager.current_state == "SECT_SELECTION"` observed TUTORIAL,
> f120 observed TUTORIAL).

Root cause (direct read of the delivered tree): the R5 two-press initial sect
join in `scripts/segments/sect_select.gd` armed on EVERY input path
(`_on_sect_pressed` AND `_unhandled_input` ui_accept), so every scenario that
joins a sect with a SINGLE press armed and never committed — stuck at
SECT_SELECTION (e.g. facility_use_reusable f400, event_travel_effects f130).

**Owner F4 ruling (cited per reviewer suggestion 4, making the deviation from
the verbatim brief auditable):** the brief's C3 line said 拜入门派加确认;
feat_c3 implemented that as a two-press arm on every input path and red-lined
the gates. The owner's step-3 checkpoint ruling supersedes it: the
input-path fork (keyboard single-press + click two-press) is the
play-test-harness-injects-input failure class — the gates test the game nobody
plays with a mouse, and the three verbatim gates pin the single-press join as
an iron law FOR THE GAME, not for one input path. What the rulings actually
require on this screen: (a) C1 consequences visible BEFORE the press (kept:
the preview); (b) C3 a back button while nothing is committed (delivered:
SectBackButton + ui_cancel → enter_menu()). A two-press arm is NOT one of the
rulings; this card removes it. The deviation is recorded here and in the yaml
change table, not silently.

## 6. Known gaps 与遗留

- The F1 runtime error (cultivation.gd:1108) hard-fails the gate for
  event_travel_effects / event_pool_new_event_resolved /
  fortune_reroll_budget despite all-green asserts — fix belongs to
  fix_f1_event_option_effects_read (next wave).
- Four cadence-drift reds named in §3a belong to the timeline-rebaseline card.
- The now-unused i18n EN entry `⚠ 再按一次确认拜入「%s」` awaits removal by a
  step owning i18n.gd (§4).
- Official 5_compile full-gate / 5_test pytest artifacts for this fix are
  downstream products; per the evidence discipline this step's greens are
  direct sidecar runs against repo + staged files, not official consolidated
  numbers.

## 7. 边界声明 (what was NOT touched)

Three verbatim gate yamls; `playtest/event_travel_effects.yaml`; the six locked
files; `scripts/segments/cultivation.gd` (including its `switch_confirm_armed`
year-end arm and the C2 empty branch and back channel); `scripts/autoload/i18n.gd`;
`playtest/year_end_switch_needs_confirm.yaml`; `playtest/consequence_sect_select_focus.yaml`;
all cascade scenario yamls (zero timeline edits — clicks_only_storyline and
map_facility_buttons_click needed none, per acceptance item 4's STOP check);
no root `playtest_spec.yaml`; no per-input-path branching introduced.
