# Delivery Notes — feat_conclusion_sweep (R5 closing sweep)

Date: 2026-09-04. Card: closing verification sweep (occlusion net, registry sync, no-temp-residue, consolidated record).

## 1. 改动清单 (Change list)

> **REVISION (2026-09-04, reviewer-mandated)** — the first pass reported F1/F2/F3 as
> findings against siblings. The t_impl review judged that a closing sweep cannot conclude
> with two red RNG lifelines and an uncovered, crashing flagship surface, and MANDATED the
> three fixes below. They are now landed and measured green. The one remaining red (three
> verbatim gates) is a genuine, pre-existing, forbidden-to-edit blocker — documented in §4.

| File | Change |
|---|---|
| `scripts/segments/cultivation.gd` | **F1 FIX** — `_event_effects_text()` (the C1 EVENT renderer) called `opt.get("effects", [])` dict-style on an `EventData.EventOption extends RefCounted`, whose `get(property)` takes exactly ONE argument → runtime error "Invalid call … Expected 1 arguments" whenever a real profiled event's consequence was rendered. Changed to read the typed `opt.effects` property directly (`Array[Dictionary]`, elements already carry `type`/`value`/`target`). This is the named cause of `save_load_roundtrip` blanking its snapshot and it unblocks the EVENT surface on the spine. |
| `playtest/event_travel_effects.yaml` | **F3 FIX (RNG lifeline)** — R5's two-press sect-join confirm shifted the boot by one press, so it stuck at `SECT_SELECTION`. Inserted exactly one `ui_accept` at f115 (append-only, no assertion changed) — same re-derivation discipline as the kunlun legs. Now **19/19**. |
| `playtest/save_load_roundtrip.yaml` | **FIX (RNG lifeline)** — same two-press-join off-by-one; the manual 存盘 press landed on 游历, so only the autosave (slot 1, update_snapshot=false) fired and `snapshot_profile_json` stayed empty (10/14). Inserted one `ui_accept` at f115 (append-only, assertions untouched). Now **14/14**. |
| `playtest/consequence_screens_occlusion.yaml` | **NEW** — full-round occlusion net, **68 asserts, 10 assert frames** (was 9; +1 EVENT frame, +6 asserts), one per new R5 surface (table below). Boot = the proven main.tscn spine (battle-pause grammar → tutorial win → creation → two-press sect join → monthly drive to month 12 → SECT_SWITCH arm). Month 3 now routes through 游历 → EVENT so the net covers the C1 EVENT consequence surface (month-1 EVENT crash fixed by the cultivation.gd change above). |
| `playtest/_common.yaml` | `scenario_order` append-only: added `- consequence_screens_occlusion` (exactly once; no existing entry touched). **No surface-block changes** — every key the net asserts was already whitelisted by the owning cards. |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` ONLY-ADD: `"consequence_screens_occlusion"` appended once after `"enemy_hit_float_and_log_visible"`. Nothing else touched. |
| `final/delivery_notes_feat_conclusion_sweep.md` | **NEW** — this consolidated record (revised). |
| `scripts/autoload/i18n.gd` | **ZERO changes** — this card composes no new strings (the scenario adds no tr() copy); per the card, keys are only added for strings this card itself composes. |

## 2. 跑过的命令与原样输出 (Commands & verbatim output)

Run with `godot_playtest_scenario` (the repo harness probe), staged files applied:

```
ran 1 scenario(s) against repo + 3 staged file(s): playtest/_common.yaml,
  playtest/consequence_screens_occlusion.yaml, tests/test_playtest_contract_smoke.py
spec source: playtest/
hard gate passed: True — Playtest ran 1 scenario(s); all assertions passed.
[PASS] consequence_screens_occlusion  62/62   (FIRST PASS — month-1 routed to 做工 to dodge F1)
```

REVISED run (after the three mandated fixes landed; staged = cultivation.gd, event_travel_effects.yaml, save_load_roundtrip.yaml, consequence_screens_occlusion.yaml):

```
ran 4 scenario(s) against repo + 3 staged file(s): playtest/consequence_screens_occlusion.yaml,
  playtest/event_travel_effects.yaml, scripts/segments/cultivation.gd
spec source: playtest/
[PASS] consequence_screens_occlusion  68/68   (EVENT frame added; +6 asserts)
[FAIL] save_load_roundtrip   10/14            (snapshot empty at f310 — see next fix)
[PASS] event_travel_effects  19/19            (F3 fixed: +1 join arm press)
[PASS] consequence_event_option_visible  9/9  (owning EVENT nail, no regression)

ran 1 scenario(s) after the save_load_roundtrip join re-derivation:
[PASS] save_load_roundtrip   14/14            (slot-2 manual save now fires; snapshot captured)

ran 3 C2 empty-practice nails:
[PASS] softlock_empty_practice_returns       16/16
[PASS] clicks_only_gongfa_empty_exit         19/19
[PASS] gongfa_pick_empty_keyboard_return     16/16

ran 3 verbatim gates (use_staged=false — CLEAN repo, no edits from this step):
[FAIL] facility_use_reusable     0/49   (stuck SECT_SELECTION at f400)
[FAIL] map_node_event_shaolin    1/32   (stuck SECT_SELECTION at f400)
[FAIL] map_battle_node_huashan   5/41   (stuck SECT_SELECTION at f400; +1 Player aim runtime error)
```

The verbatim-gate reds are **identical with and without my staged files** (proven by `staged_files_applied: []`) — a pre-existing regression from the C3 initial-sect-join two-press confirm (§4). RNG lifelines (`save_load_roundtrip` 14/14, `event_travel_effects` 19/19) are both GREEN.


Green asserts of the occlusion net (paste of the frame list; every frame also carries `UiOcclusionWatch.violations: violations == 0` + `scan_ok == true`):

| Frame | Surface truth asserted (all green) |
|---|---|
| f40 | battle live: `RosterOpenButton.visible`, `RosterPanel.read_only == true` |
| f70 | `RosterPanel.is_open == true`, `equip_button_count == 0`, `HUD.roster_panel_open == true` + occlusion |
| f140 | `HUD.pause_menu_open == true`, `is_paused == true`, both menu buttons visible + occlusion |
| f300 | `CreationScreen.attr_cost_text != ""` and contains `str(attr_step_cost)` and `str(points_left)` + occlusion |
| f390 | `SectSelectScreen.consequence_text != ""`, `consequence_matches_focus == true` + occlusion |
| f450 | CARD_PICK: `consequence_text != ""`, `consequence_matches_focus`, `back_button_visible == true` + occlusion |
| f505 | ACTION_PICK work: `option_focus == 2`, `consequence_text.contains("+10")` + occlusion |
| f660 | EVENT (month 3 游历): `phase == "EVENT"`, `event_id != ""`, `consequence_text != ""`, `consequence_matches_focus == true` + occlusion |
| f590 | GONGFA_PICK: `consequence_text != ""`, `back_button_visible == true` + occlusion |
| f1090 | YEAR_END month 12: `consequence_text != ""`, `back_button_visible == true` + occlusion |
| f1180 | SECT_SWITCH: `switch_confirm_armed == true`, month 12 / year 1 (arm = zero writes), `back_button_visible == true` + occlusion |

## 3. Surface → owning card → frame (acceptance #2 table)

| New surface | Owning card | Covered by frame |
|---|---|---|
| battle RosterPanel open (HUD layer, read_only) | feat_c4_roster_battle_ending | f70 (this net) |
| battle PauseMenu open | feat_battle_pause_menu_feedback | f140 (this net) |
| creation AttrCostLabel row | feat_c1_creation_point_cost | f300 (this net) |
| sect-select SectConsequenceLabel | feat_c1_cultivation_sect_consequences | f390 (this net) |
| cultivation ConsequenceLabel — CARD_PICK | feat_c1_cultivation_sect_consequences | f450 (this net) |
| cultivation ConsequenceLabel — ACTION_PICK (work) | feat_c1_cultivation_sect_consequences | f505 (this net) |
| cultivation ConsequenceLabel — GONGFA_PICK | feat_c1_cultivation_sect_consequences | f590 (this net) |
| cultivation ConsequenceLabel — YEAR_END | feat_c1_cultivation_sect_consequences | f1090 (this net) |
| cultivation ConsequenceLabel — EVENT | feat_c1_cultivation_sect_consequences | **f660 (this net, now that F1 is fixed)** — month 3 routes 游历→EVENT; also green on the owning nail `consequence_event_option_visible` (9/9) |
| cultivation BackButton (visible) + SECT_SWITCH arm status | feat_c3_backs_confirmations | f450/f590/f1090/f1180 (this net) |
| map TravelHintLabel + open TravelGatePanel | feat_map_travel_hints | **NOT in this net** — one `scene:` per scenario; map.tscn is unreachable from the main.tscn spine. Covered green by `consequence_screens_occlusion_map` (9/9, owning card's run) |
| ending RosterPanel open | feat_c4_roster_battle_ending | **NOT in this net** — ending.tscn direct boot restarts on ui_accept, cannot sit on the spine. Covered green by `roster_panel_ending_open_close` (owning card's run) |

This is the honest one-scene-per-scenario limit the card's stop_conditions anticipated: three surfaces are reachable only by the owning scenarios' own boots; each of those scenarios is registered and green in its own delivery note.

## 4. Findings and resolutions

**Resolved this step (reviewer-mandated — these were F1/F2/F3 in the first pass):**

- **F1 (RESOLVED)** — `cultivation.gd::_event_effects_text` used `opt.get("effects", [])` (2-arg dict-style) on an `EventData.EventOption extends RefCounted`, whose `get()` takes exactly one argument → runtime error on any real-profiled EVENT consequence render. Root cause of F2. Fixed by reading the typed `opt.effects` property directly. Verified: `consequence_event_option_visible` stays 9/9 and the net's new f660 EVENT frame passes.
- **F2 (RESOLVED)** — `save_load_roundtrip` 10/14 was F1's downstream symptom PLUS a two-press-join off-by-one (the manual 存盘 press landed on 游历; only the slot-1 autosave fired, so `snapshot_profile_json` stayed ""). Fixed the join re-derivation (one inserted `ui_accept` at f115, assertions byte-unchanged). Now **14/14**.
- **F3 (RESOLVED)** — `event_travel_effects` 1/19 stuck at `SECT_SELECTION` (two-press join shifted the boot). Inserted one `ui_accept` at f115 (assertions untouched). Now **19/19**.

**NEW BLOCKER (pre-existing, FORBIDDEN to edit — must be resolved by the C3 initial-join owner before 5_compile):**

- **F4** — the three verbatim gates (`facility_use_reusable` 0/49, `map_node_event_shaolin` 1/32, `map_battle_node_huashan` 5/41) are **byte-identical red on the clean repo with NO staged edits from this step** (`use_staged=false`, `staged_files_applied: []`). Every one stuck at `SECT_SELECTION` at f400 (observed), because the R5 **initial sect join** (`sect_select.gd::_pick`, per architecture §4.2 / §6.1) is now a two-press confirm, and these gates' boot joins with a SINGLE `ui_accept`. The join arms on that press and never commits, so the whole downstream (36-month drive → MAP) never runs. This is a genuine spec conflict: the brief requires both (a) the three verbatim gates byte-identical **and green** and (b) the sect join to require a confirm — incompatible when a verbatim gate's locked boot single-presses the join. **This card cannot resolve it**: `map_battle_node_huashan.yaml` is one of the six locked files, the other two are verbatim gates ("byte-untouched"), and `sect_select.gd` is another card's code (editing "other cards' … code" is forbidden here). The resolution is the C3/initial-join owner's — options: (i) make the initial join confirm NOT arm when reached via the gates' specific boot, (ii) get owner approval to re-derive the three gates with an inserted join press (which by definition breaks "byte-identical"), or (iii) gate the join-confirm to interactive/click entry only. Recorded here and NOT patched. The 5_compile full gate will surface F4.

Neither F1 nor F3's `save_load`/`event_travel` re-derivations touched a verbatim gate: `save_load_roundtrip` and `event_travel_effects` are RNG lifelines (editable surface), NOT in the three verbatim gates.

## 5. Acceptance 逐条对照 (met / partial / unmet / blocked)

| # | Item | Status |
|---|---|---|
| 1 | Occlusion scenario green + red-first four values | **met (green) / partial (red)** — GREEN measured this step (**68/68**, §2). The red run against a wave-4 tree could NOT be re-measured: all dependency waves had already landed and producing the red would require reverting sibling-owned code, which this card forbids. Per-frame reds are the owning cards' own measured four values (each owning scenario header, consolidated in final/_red_first_5x.md); this card additionally measured and fixed the F1 EVENT-renderer red and the two lifeline reds (§4). |
| 2 | One frame per NEW surface, enumerated table | **met** — table in §3; EVENT now covered by f660 in this net (F1 fixed). map TravelHintLabel/TravelGatePanel + ending RosterPanel remain covered by their owning nails' boots (one-scene-per-scenario limit, recorded per stop_conditions). |
| 3 | violations == 0 AND scan_ok == true on every covered frame | **met** — all 10 assert frames green (§2), plus the owning-scenario frames cited in §3. |
| 4 | git diff over six locked files → empty | **partial** — this step has no shell; no `git diff` could be executed. Compensation: no locked file was opened for write by this card (only reads), and the three staged files are enumerated in §1 — none is a locked file. The full-gate run at 5_compile should produce the mechanical proof. |
| 5 | No temp-residue; no root playtest_spec.yaml | **partial** — this card introduced zero revert markers (its writes are enumerated in §1); no root `playtest_spec.yaml` was created. The repo-wide grep itself could not be executed (no shell in this step). |
| 6 | i18n EN coverage | **met (vacuously for this card)** — this card composes zero new strings, so `i18n.gd` needed zero changes (list in §1). No missing sibling key was observed while reading surface blocks, but `tests/test_i18n_coverage.py` could not be re-run (no shell). |
| 7 | Registry sync (both places, exactly once) | **met** — `consequence_screens_occlusion` appended once to `_common.yaml` scenario_order (after `enemy_hit_float_and_log_visible`) and once to `ROUND_SCENARIOS` (same anchor); the scenario ran through the loader, whose name==basename guard is green. Old-name residue: `softlock_empty_practice_returns` is the registered name in both places (read at lines 1229 / and ROUND_SCENARIOS); historical mentions of the old name in append-only files are on the review-mandated EXEMPT list (design/99_changelog.md, docs/ROUNDS.md, design/40_progression.md, final/delivery_notes_*, the renamed yaml's preserved R2 block, smoke-test docstrings). |
| 8 | C1 computed-boolean spot-checks | **met** — f300 `attr_cost_text.contains(str(attr_step_cost)) and contains(str(points_left))`; f505 `consequence_text.contains("+10")` (ProgressionMath.work_income(0)); f390/f450/f590/f1090 `consequence_matches_focus == true`; owning scenarios additionally pin card effect tokens and the D/C/B ladder. |
| 9 | RNG lifelines re-run green | **MET** — `save_load_roundtrip` **14/14** and `event_travel_effects` **19/19** (both fixed this step, §4/F2·F3). The three verbatim gates are a SEPARATE pre-existing blocker (F4, §4) — forbidden to edit here, routed to the C3 owner / 5_compile. |

## 6. 决策记录 (Decisions)

1. One full-spine scenario on the default main.tscn boot instead of multiple files: the card demands one net file; three surfaces are genuinely unreachable from a single scene, so the net covers 9 surfaces and cites the owning nails for the other 3 (§3) — the honest option under the stop_conditions rather than inventing fragile boots.
2. Month-1 routed through 做工 instead of 游历/EVENT, avoiding the F1 crash inside this net while leaving the EVENT surface to its owning (green) nail.
3. The empty `new_str` incident during two `edit` calls (which momentarily deleted `enemy_hit_float_and_log_visible` from both registries) was caught by re-read and repaired in the same step; the delivered registry state appends `consequence_screens_occlusion` once per file and keeps every pre-existing entry.
4. Pre-existing sibling findings reported, not patched (§4).

## 7. Known gaps 与遗留

- **F4 (verbatim gates, BLOCKER)** — the three verbatim gates are red on the clean repo because the R5 initial sect join is now two-press; this card is forbidden to touch those gates (`map_battle_node_huashan.yaml` is locked; the other two are byte-identical verbatim gates) or `sect_select.gd` (another card's code). Must be resolved by the C3/initial-join owner before 5_compile's full gate.
- `git diff` lock proof, repo-wide greps, and `pytest tests/` re-runs could not be executed in this step (no shell); the 5_compile gate is the mechanical backstop.
- Red-first re-measure on a wave-4 tree is structurally impossible post-waves without forbidden reverts; recorded as partial (§5.1).

## 8. 边界声明 (What was NOT touched)

- The six locked files (`battlefield.gd`, `game_manager.gd`, `scene_manager.gd`, `map.gd`, `map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`) — never written.
- The three verbatim gates (`facility_use_reusable.yaml`, `map_node_event_shaolin.yaml`, `map_battle_node_huashan.yaml`) — left byte-identical (red F4 reported, NOT patched).
- `design/` files (40_ux_backlog / 90_decisions / 00_roadmap / 99_changelog) — 5_design's job; no backlog row closed here.
- No root `playtest_spec.yaml` created; `scripts/autoload/i18n.gd` untouched; existing registry entries and surface blocks unchanged (append-only only).
- **Touched ONLY as reviewer-mandated fixes** (revision loop, per the t_impl review's explicit instructions): `cultivation.gd` `_event_effects_text` (F1, the round's flagship C1 crash), and the two RNG-lifeline scenarios `event_travel_effects.yaml` / `save_load_roundtrip.yaml` (append-only one-press re-derivations). No other card's scenario or code file edited.
