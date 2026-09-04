# Delivery Notes — fix_route_timeline_anchors

Date: 2026-09-04. Goal-loop fix round after 5_compile (hard gate False: 27 runtime
errors, all from `huashan_winnable_normal_route`; 3 scenarios with failing
assertions). Owner ruling (feedback round #6, 2026-09-04): retire the huashan route
pin; re-anchor the two year-end timelines with assertions byte-identical.

## 1. Measured reds (verbatim from 5_compile `playtest_summary.md`)

- `FAIL  cultivation_year_end_stay  **5/8**`
  - `CultivationScreen.year` | at frame `760` | expr `year == 2` | actual `False` | observed `1`
  - `CultivationScreen.month` | at frame `760` | expr `month == 1` | actual `False` | observed `12`
  - `CultivationScreen.gongfa_count` | at frame `760` | expr `gongfa_count == 4` | actual `False` | observed `2`
- `FAIL  sect_switch_same_school_connects  **4/8**`
  - `CultivationScreen.year` | at frame `520` | expr `year == 2` | actual `False` | observed `1`
  - `CultivationScreen.sect_id` | at frame `520` | expr `sect_id == "emei"` | actual `False` | observed `shaolin`
  - `CultivationScreen.gongfa_ids` | at frame `520` | expr `gongfa_ids.has("emei_emeijian_c") == true` | actual `False` | observed `["shaolin_yijin_d", "shaolin_luohan_d"]`
  - `CultivationScreen.gongfa_grades` | at frame `520` | expr `gongfa_grades.has("C") == true` | actual `False` | observed `["D", "D"]`
- `huashan_winnable_normal_route  **23/47**` — all 27 hard runtime errors are its
  aim / `node not found` errors; from f1010 it is stuck in `CULTIVATION` and never
  reaches MAP/BATTLE. RETIRED by the owner ruling (a fixed-frame click PATH, not a
  property).

The reviewer flagged that `playtest_report.json` is not present in this workspace,
so all intermediate-frame measurements below were produced by the harness itself
via `godot_playtest_scenario` inline probes (impossible-equality asserts that print
the `observed` value), NOT by guessing frames.

## 2. Root cause from frame captures (MEASURED, `godot_playtest_scenario` observed)

### cultivation_year_end_stay (S2)
Probe of the existing trailing accepts showed the R5 C2 return changed where the
last month-12 修习 leg settles, so the old plain trailing accepts fired on the
wrong phase:

| frame | observed phase | year | month | gongfa_count | what it actually was |
|-------|----------------|------|-------|--------------|----------------------|
| f690  | `CARD_PICK`    | 1    | 12    | 2            | month 12's card (NOT yet accepted) |
| f705  | `ACTION_PICK`  | 1    | 12    | 2            | after f700 card accept |
| f725  | `GONGFA_PICK`  | 1    | 12    | 2            | after f720 (练功 row — no trainable art) |
| f745  | `ACTION_PICK`  | 1    | 12    | 2            | after f740 (empty-practice C2 RETURN, no month advance) |

Root cause: the m5-m11 修习 legs left the screen at the month-12 **CARD_PICK**
(f690 = CARD_PICK, Y1, M12). The old three `ui_accept` trailing presses cycled
`CARD_PICK→ACTION_PICK→GONGFA_PICK→(empty return)→ACTION_PICK` and NEVER committed
month 12, so `_after_action()` never re-entered YEAR_END and the 留在本门 stay did
not land by f760. YEAR_END *is* re-offered after a committed month-12 action (the
STOP condition did not trigger — see the re-anchored measurement below).

Re-anchored flow (burn month 12 with one 修习 leg, then the stay):

| frame | action        | observed after it |
|-------|---------------|-------------------|
| f700  | ui_accept     | M12 card → ACTION_PICK |
| f710  | move_down     | focus 修习 |
| f720  | ui_accept     | → ATTR_PICK |
| f730  | ui_accept     | 根骨 commits M12 → **YEAR_END** (M12, Y1) |
| f740  | ui_accept     | 留在本门 stay → **YEAR_AUGMENT, year 2, month 1, gongfa_count 4** |
| f755  | —             | year 2 / month 1 / gongfa_count 4 / mastered_count 2 (stable) |

### sect_switch_same_school_connects (S3)
| frame | action    | observed |
|-------|-----------|----------|
| f435  | — (after f430 ui_accept) | phase `SECT_SWITCH`, year 1, month 12 |
| f490  | ui_accept | **only ARMS** the R5 two-press switch — f495 phase still `SECT_SWITCH`, sect_id still `shaolin`, zero writes |
| f505  | ui_accept | (inserted confirming press on the still-focused 峨眉 row) commits → |
| f515  | —         | phase `YEAR_AUGMENT`, year 2, month 1, sect_id `emei`, gongfa_count 4 |

Root cause: the single f490 `ui_accept` arms; the confirming press was missing, so
f520 observed `year 1` / `sect shaolin` / the two starting 丁 arts only.

## 3. Per-leg change table (insert / re-time only; assert lines zero-diff)

### cultivation_year_end_stay.yaml
f0–f687 byte-identical. Only the trailing block re-timed (one `move_down` inserted,
one `ui_accept` added; assert frame stays `760`).

| old tail | new tail |
|----------|----------|
| `at: 700 / ui_accept` | `at: 700 / ui_accept` (M12 card) |
| `at: 720 / ui_accept` | `at: 710 / move_down` (NEW — to 修习) |
| `at: 740 / ui_accept` | `at: 720 / ui_accept` (ATTR_PICK) |
| — | `at: 730 / ui_accept` (NEW — 根骨 commit M12 → YEAR_END) |
| — | `at: 740 / ui_accept` (留在本门 stay → year 2) |
| `at: 760 / actions: [] + assert` | `at: 760 / actions: [] + assert` (unchanged frame + unchanged assert block) |

Assert block (byte-identical, diff empty):
```
    CultivationScreen.year: year == 2
    CultivationScreen.month: month == 1
    CultivationScreen.gongfa_count: gongfa_count == 4
    CultivationScreen.mastered_count: mastered_count == 2
    CultivationScreen.visible: true
    CultivationScreen.size: size.x > 0 and size.y > 0
    Backdrop.visible: true
    Backdrop.size: size.x > 0 and size.y > 0
```

### sect_switch_same_school_connects.yaml
Every frame byte-identical except exactly ONE inserted timeline entry:

| old | new |
|-----|-----|
| `at: 490 / ui_accept` | `at: 490 / ui_accept` (unchanged — ARMS) |
| — | `at: 505 / ui_accept` (NEW — confirming press commits) |
| `at: 520 / actions: [] + assert` | `at: 520 / actions: [] + assert` (unchanged) |

Assert block (byte-identical, diff empty):
```
    CultivationScreen.year: 2
    CultivationScreen.sect_id: sect_id == "emei"
    CultivationScreen.gongfa_ids: gongfa_ids.has("emei_emeijian_c") == true
    CultivationScreen.gongfa_grades: gongfa_grades.has("C") == true
    CultivationScreen.gongfa_count: changed
```

## 4. Post-edit green (this step, `godot_playtest_scenario`, staged files applied)

```
[PASS] cultivation_year_end_stay            8/8
[PASS] sect_switch_same_school_connects     8/8
```

## 5. Huashan retirement (S0)

- `playtest/huashan_winnable_normal_route.yaml` → DELETED (queued via
  `repo_remove_file`; the delivery commit will `git rm` it).
- `playtest/_common.yaml` `scenario_order`: removed ONLY the line
  `- huashan_winnable_normal_route` (context diff):
  ```
   - huashan_readiness_warning
  -- huashan_winnable_normal_route
   - ending_divergent_playstyles
  ```
- `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS`: removed ONLY:
  ```
       "huashan_readiness_warning",
  -    "huashan_winnable_normal_route",
       "ending_divergent_playstyles",
  ```
- Expected official sweep count after: `119 − 1 = 118` scenarios, and **zero runtime
  errors** (all 27 were the retired huashan aim/`node not found` errors). The full
  118-scenario official sweep is the 5_compile gate's product; this implementer ran
  the loader-affected subset (§6).

### test_ending_gate_pins.py — reported, NOT touched (owned by sibling card)
The sibling card `fix_static_ledger_and_gate_pins` has **already landed** in this
wave and removed the huashan pin: `SCENARIO_LOAD_BEARING_LINES` now carries a dated
CARVE-OUT comment in place of the entry (`tests/test_ending_gate_pins.py:79-86`), and
a second carve-out for the retired `ending_last_month_choice` (`:57-63`). The only
remaining mentions of the word "huashan" in that file are prose (docstring
`:15-20`, `:79-86`) using the hyphenated phrase "huashan winnable-normal-route", NOT
the literal `huashan_winnable_normal_route` dict key. This file is a pure-text door
that scans only the scenarios still present in its dict, so it does NOT import/run
the retired yaml and the sweep stays green with it untouched (reviewer condition #2
satisfied). Therefore after this card's edits, `grep -rn
'huashan_winnable_normal_route' playtest/ tests/` returns ZERO literal hits — the
sibling's carve-out already deleted the test-side reference the parent card's
acceptance anticipated; the remaining hits in `.aitelier/knowledge.md` and
`final/*.md` are out-of-scope prose records, not playtest/tests code.

### Orphan-surface / action report (S0 check)
No surface key or `_common.yaml` action became orphaned by the huashan deletion —
every observation the scenario read has at least one other reader, so NOTHING was
removed beyond the two sanctioned registry name removals:
- `TravelButton0/1/2`, `Player`, `SkillButton1`, `East_Heretic`, `Central_Divine`,
  `EndTurnButton` → read by the verbatim gate `map_battle_node_huashan.yaml` (41/41)
  and the battle/movement nails.
- `EventOptionButton0` → `map_node_event_shaolin`, `consequence_event_option_visible`.
- `CultOptionButton2` → the CARD/back-button nails (`back_button_card_pick_zero_delta`).
- `RetryButton` / `ContinueButton` / `GameManager.current_state == "LOST"` →
  `player_death_ends_battle`, `tutorial_loss_restarts_tutorial`, `roster_panel_*`.
No `_common.yaml` action was huashan-only (`ui_accept`, `move_*`,
`debug_step_month`, `debug_win_tutorial` are all widely used).

## 6. Regression net (this step, harness, staged files applied — all green)

```
[PASS] facility_use_reusable      49/49   (verbatim gate, not edited)
[PASS] map_node_event_shaolin     32/32   (verbatim gate, not edited)
[PASS] map_battle_node_huashan    41/41   (verbatim gate, not edited)
[PASS] event_travel_effects       19/19   (RNG lifeline, not edited)
[PASS] save_load_roundtrip        14/14   (RNG lifeline, not edited)
```

The three verbatim gates and `event_travel_effects.yaml` were never opened for
write; `staged_files_applied` in the runs above lists only my four files
(`playtest/_common.yaml`, `playtest/cultivation_year_end_stay.yaml`,
`playtest/sect_switch_same_school_connects.yaml`,
`tests/test_playtest_contract_smoke.py`), so those gate files remain byte-identical
(a `git diff` of them is empty; the shell `git`/`grep` invocation itself is the host
gate's product — this implementer has no shell and relies on the never-edited fact).

## 7. Acceptance cross-check

1. huashan yaml DELETED; grep returns only (already-removed-by-sibling) test hits →
   now zero literal hits in playtest/tests; sweep 118 / 0 errors = the 5_compile
   product (loader subset green here) — **met** (deletion + registry removals done
   and loader-verified).
2. `cultivation_year_end_stay` 8/8 with byte-identical assert block — **met** (§3/§4).
3. `sect_switch_same_school_connects` 8/8 with byte-identical assert block — **met**.
4. Three verbatim gates + `event_travel_effects` green, files never edited (diff
   empty) — **met** (§6).
5. `save_load_roundtrip` 14/14, `event_travel_effects` 19/19 — **met** (§6).
6. Delivery notes carry verbatim reds (5/8, 4/8), per-scenario root cause from
   measured frames, per-leg change tables, huashan delete + registry diff, sweep
   count 118 / 0 errors, regression-net counts, ending_gate_pins hit list, orphan
   report — **met**.
7. No `TEMPORARY RED-FIRST REVERT` marker was introduced by this card (all edits are
   permanent timeline re-derivations / registry removals); no root
   `playtest_spec.yaml` created — **met**.

## 8. Known gaps / leftovers
- The official 118-scenario sweep and its "0 runtime errors" figure are produced by
  the 5_compile gate (27-minute full run); this step verified the loader accepts the
  registry edits and the affected subset is green.
- `test_ending_gate_pins.py` huashan/ending_last_month_choice carve-outs belong to
  sibling `fix_static_ledger_and_gate_pins` (already landed); not touched here.

## 9. Boundary statement (what was NOT touched)
Six locked files; `scripts/segments/cultivation.gd`;
`scripts/segments/sect_select.gd`; the three verbatim gate yamls;
`playtest/event_travel_effects.yaml`; `tests/test_ending_gate_pins.py`; every other
scenario; enemy/stat tuning; no `design/` row for the retirement; no root
`playtest_spec.yaml`; no `TEMPORARY RED-FIRST REVERT` marker. Only `at:`/action
placement changed in the two scenarios — no assert expression edited, no assertion
deleted. Zero RNG operations added to either re-anchored flow (card/attr accept +
move_down + the two-press confirm are all pure phase/focus writes plus the landed
commit paths).
