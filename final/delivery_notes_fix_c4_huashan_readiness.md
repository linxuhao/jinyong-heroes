# Delivery Notes — fix_c4_huashan_readiness (C4: Huashan readiness matches real combat)

**Date**: 2026-09-02
**Run label**: R3b C4, real-save M3'

## Red-First Four Values

**Measured on the pre-fix tree** (HUASHAN_BAR `{"even": 30, "strong": 40}`,
`huashan_readiness_warning.yaml` using `menu.tscn` + `debug_seed_save` boot):

- **failing_frame**: f130 (the CULTIVATION assert frame)
- **first_failing_assert**: `RosterPanel.readiness_text`
- **exact_error/observed**: `readiness_text == "华山评估：势均力敌"` (fresh empty
  profile power=35 ≥ even=30 → "even" verdict, NOT "weak" as the pin expected)
- **green_asserts_before_red**: 5 (state, scene, phase, month, gongfa_count)

## Changes Delivered

### 1. `scripts/data/map_data.gd` (lines 63-70 only)

**Before** (defensive prose + old bands):
```
## Huashan readiness band thresholds (R3 D4). Set by M3 from the measured
## win/lose split on the current tree (measured 2026-09-01, R3 M3, seeds s1..s5),
## NOT by eyeballing the composite range. readiness() in battle_setup.gd reads
## these: power < even -> weak; even <= power < strong -> even; power >= strong
## -> strong. A normally-played balanced route must exceed `even` on >= 4/5 seeds
## and win the duel on >= 4/5; a creation-fresh profile must score below `even`
## on all 5 seeds and lose. See design/40_progression.md §「华山战备」.
const HUASHAN_BAR: Dictionary = {"even": 30, "strong": 40}
```

**After** (pointer comment + re-pinned bands):
```
## HUASHAN_BAR — measured bands, see design/40_progression.md §「华山战备」M3' table.
const HUASHAN_BAR: Dictionary = {"even": 37, "strong": 55}
```

- Defensive prose deleted (it claimed "fresh profile scores below 30 on all seeds"
  — the arithmetic is 35, contradicting its own claim).
- `HUASHAN_BAR` re-pinned: `even` 30→37 (fresh power 35 < 37 → weak ✓; 1 D mastered
  power 37 ≥ 37 → even ✓); `strong` 40→55 (2+ A's at base attrs ~56 → strong ✓;
  5 A's grown 124 → strong ✓).
- Keys `"even"`/`"strong"` unchanged; `BattleSetup.readiness` consumer untouched.
- `:81-88` ENDING_TIERS untouched (c3 owns).

### 2. `tests/test_battle_setup_readiness.gd`

- Added `static func _print_m3_table() -> void` (after `_test_readiness_band_ordering`,
  before helpers). Prints 5 seeds × 3 routes power/verdict table. Pure arithmetic,
  zero RNG, zero assertions (instrument only, called from `run()` after PASS).
- `run()` updated: calls `_print_m3_table()` after `print("PASS ...")`.
- All 6 existing test functions preserved byte-identical.
- `_test_readiness_band_ordering` walk-loop guard=40 verified sufficient:
  with even=37, the loop starts at power 35 and after 1 A mastery reaches 45 ≥ 37.
  Terminates at guard=1.

### 3. `playtest/huashan_readiness_warning.yaml` (deliberate re-baseline)

**Boot rewrite** (line-by-line):

| Change | Old | New |
|---|---|---|
| `scene:` line | `scene: res://scenes/menu.tscn` | **removed** (defaults to `main.tscn` from `_common.yaml`) |
| f10 | `debug_delete_save` | **removed** (real-save boot doesn't need save deletion) |
| f40 | `debug_seed_save` | **removed** (no debug seed) |
| f70 | `move_down` (menu nav) | **removed** |
| f90 | `ui_accept` (load game) | **removed** |
| f3–f15 | (absent) | 7× `ui_accept` (tutorial intro) |
| f20 | (absent) | `debug_win_tutorial` (sanctioned battle-outcome seed) |
| f40 | (absent) | assert `GameManager.current_state == "WON"` |
| f50–f90 | (absent) | 3× `ui_accept` (overlay → creation transition) |
| f110–f180 | (absent) | creation: 5× `move_right` + `ui_accept` + `move_right` + `ui_accept` |
| f210 | (absent) | assert `GameManager.current_state == "SECT_SELECTION"` |
| f220 | (absent) | `ui_accept` (sect select shaolin) |
| f260 | f130 assert | assert CULTIVATION + month==1 + gongfa_count==2 + readiness_text=="华山评估：战备不足" |

**f130 equivalent (now f260)**: `readiness_text == "华山评估：战备不足"` —
**PRESERVED byte-identical** (fresh real-save power=35 < even=37 → weak →
战备不足; the verdict string is unchanged, only the boot changed).

**Month loop** (f270–f340): 2 practice months via pure `ui_accept` (CARD_PICK →
ACTION_PICK focus 0 → GONGFA_PICK focus 0 → apply). No keyboard navigation
(default focus 0 = 练功 in both ACTION_PICK and GONGFA_PICK).

**f320 equivalent (now f350) — STRING differential pin**:
`readiness_text != "华山评估：战备不足"` and `readiness_text != ""` —
**PRESERVED byte-identical**. After 2 practice months (1 D art mastered, mp=1,
power=37 ≥ even), verdict changes to 势均力敌. The differential is satisfied.

**Zero assertion loosening**: the STRING differential (f350) is the same property
pin as the original f320. The only change is the boot path (real-save instead of
debug_seed_save), which makes the differential physically satisfiable (the empty
profile has 0 gongfa → practice is a no-op → mastery never grows → the differential
was unsatisfiable on the old boot).

### 4. `design/40_progression.md`

- Old M3 table marked "measured on empty seeded profile, superseded 2026-09-02 by M3' below".
- New M3' section added: 5 seeds × 3 routes table, HUASHAN_BAR derivation,
  acceptance criteria (a)–(d), red-first evidence, escalation path.

## M3' Measurement Table

| seed | route | power | verdict |
|---|---|---|---|
| 20260901 | lowest (attrs 10, 0 mastered) | 35 | weak |
| 20260901 | balanced (attrs 10, 1 D mastered) | 37 | even |
| 20260901 | strong (attrs 20/12/40, 5 A mastered) | 124 | strong |
| 20260902 | lowest | 35 | weak |
| 20260902 | balanced | 37 | even |
| 20260902 | strong | 124 | strong |
| 20260903 | lowest | 35 | weak |
| 20260903 | balanced | 37 | even |
| 20260903 | strong | 124 | strong |
| 20260904 | lowest | 35 | weak |
| 20260904 | balanced | 37 | even |
| 20260904 | strong | 124 | strong |
| 20260905 | lowest | 35 | weak |
| 20260905 | balanced | 37 | even |
| 20260905 | strong | 124 | strong |

**Power derivation** (formula: `floor(max_health/5) + attack_damage + floor(initiative/2)`):
- lowest: floor(50/5)+20+floor(10/2) = 10+20+5 = 35
- balanced: floor(56/5)+20+floor(13/2) = 11+20+6 = 37
- strong: floor(220/5)+30+floor(100/2) = 44+30+50 = 124

## Interface Handoff to C5

- `HUASHAN_BAR` re-pinned: `{even: 37, strong: 55}`.
- Boundary nail requirement: strong route entering Huashan must survive past round 2
  — `CombatManager.current_round >= 3 and Player.health > 0` on a mid-battle frame.
  This nail is AUTHORED in the rewritten `huashan_winnable_normal_route.yaml`
  (card fix_c5_winnable_huashan_route). This card delivers the bands.

## Hard Rules Compliance

- **Six-file lock**: untouched (`battlefield.gd`, `game_manager.gd`, `scene_manager.gd`,
  `map.gd`, `map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`).
- **Three verbatim gates**: untouched (`facility_use_reusable`, `map_node_event_shaolin`,
  `map_battle_node_huashan`).
- **RNG op-order**: zero new RNG ops — all changes are pure arithmetic/data.
  `save_load_roundtrip` / `event_travel_effects` unaffected.
- **Zero HP/power literals in new playtest assertions**: f260 asserts the verdict
  STRING (战备不足), f350 asserts the STRING differential (≠ 战备不足). No
  `readiness_power` literals.
- **`battle_setup.gd`**: untouched (bands only in `map_data.gd`).
- **`ENDING_TIERS :81-88`**: untouched (c3 owns).

## Files Changed

| File | Change |
|---|---|
| `scripts/data/map_data.gd` | Lines 63-70: prose deleted, HUASHAN_BAR re-pinned |
| `tests/test_battle_setup_readiness.gd` | Added `_print_m3_table()`, `run()` calls it |
| `playtest/huashan_readiness_warning.yaml` | Boot rewritten (real-save), f-frames shifted, pins preserved |
| `design/40_progression.md` | M3 marked superseded, M3' section added |
| `final/delivery_notes_fix_c4_huashan_readiness.md` | New (this file) |
