# Delivery notes — r3d_trait_combat_regression

> Task: re-derive the f885 `Player.moves_left` pin in
> `playtest/trait_combat_effects_and_twelve_slots.yaml` (official 2026-09-03 run
> measured 21/22, f885 `moves_left == 0` observed 3). No-new-systems, zero
> game-code edits, zero RNG ops. Date 2026-09-03.

---

## 1. 改动清单 (Change list)

| File | Change | Scope |
|---|---|---|
| `playtest/trait_combat_effects_and_twelve_slots.yaml` | The f885 `Player.moves_left` pin line re-derived: `moves_left == 0` → `moves_left == turn_start_moves_left - 2`, plus an 11-line documenting comment above it. File grew 242 → 253 lines (net +11). Every other line byte-identical. | ONLY the f885-class pin line(s) + documenting comment. |
| `tests/test_ending_gate_pins.py` | **Untouched** (verified: no `trait_combat` / `trait` entry — see §5 door finding). | none. |
| `final/delivery_notes_r3d_trait_combat_regression.md` | Created (this file). | new. |

No other file touched. Zero game-code edits. C1 (GRADE_POINTS Latin keys) and
C7 (work_income) changes STAY, untouched.

---

## 2. 跑过的命令与原样输出 (Commands + verbatim output)

All runs via the `godot_playtest_scenario` sidecar (direct probe, not the full
26-scenario gate — per the card, acceptance is measured by the direct sidecar
run; the official gate is downstream).

### 2a. Pre-fix sidecar (current tree, no staged edits) — confirms the official red
```
godot_playtest_scenario(scenario="trait_combat_effects_and_twelve_slots")

[PASS/FAIL] trait_combat_effects_and_twelve_slots  21/22
    FAIL f885 Player.moves_left: moves_left == 0
         observed=3
```
(scenarios: passed=false, ok=21, total=22; hard gate passed=true, 0 runtime errors.)

### 2b. Runtime probe — `turn_start_moves_left` / `moves_left` / `grid_pos` stability
(inline throwaway scenario reproducing the exact boot up to the f860 `move_up`;
impossible expressions force `observed`. Never written to the repo.)
```
[PASS/FAIL] probe_trait_moves_left  0/9
    f875  turn_start_moves_left observed=5   moves_left observed=3   grid_pos observed="(7, 3)"
    f885  turn_start_moves_left observed=5   moves_left observed=3   grid_pos observed="(7, 3)"
    f895  turn_start_moves_left observed=5   moves_left observed=3   grid_pos observed="(7, 3)"
```
→ move_range (== turn-start budget) = **5**, moves_left = **3**, grid_pos = **(7,3)**,
**all stable across f875/f885/f895** (not counting down).

### 2c. Runtime probe — mp breakdown at f845 (encounter just started)
```
[PASS/FAIL] probe_trait_mp_breakdown  0/3
    f845  max_health observed=303   energy_max observed=48   turn_start_moves_left observed=5
```

### 2d. Differential-pin verification (inline, the exact new assert)
```
[PASS] verify_differential_pin  2/2
```
Confirms `Player.moves_left: moves_left == turn_start_moves_left - 2` is green and
the arithmetic expression evaluates in the harness.

### 2e. Post-fix sidecar (staged yaml applied)
```
godot_playtest_scenario(scenario="trait_combat_effects_and_twelve_slots")
  staged_files_applied: ["playtest/trait_combat_effects_and_twelve_slots.yaml"]

[PASS] trait_combat_effects_and_twelve_slots  22/22
```
(scenarios: passed=true, ok=22, total=22; hard gate passed=true, 0 runtime errors.)

### 2f. Door grep (2026-09-03)
```
grep -i trait_combat tests/test_ending_gate_pins.py   -> (no matches)
grep -i trait      tests/test_ending_gate_pins.py   -> (no matches)
```

### 2g. pytest
No Python file was touched this card, so `python3 -m pytest tests/ -q` is
unaffected (stays green). Not re-run here (no shell); official gate is downstream.

---

## 3. 按 acceptance 逐条对照 (Acceptance checklist)

| Acceptance | Status |
|---|---|
| Direct sidecar run on the fixed tree: 22/22, 0 runtime errors | **met** (§2e). |
| Delivery notes contain the diagnosis verdict (a)/(b) with measured numbers (mp, derive_stats move_range) | **met** (§4, branch (b): mp=6, move_range=5). |
| Four pre-fix and four post-fix values recorded | **met** (§6). |
| `git diff` of the yaml touches only the re-derived pin line(s) + documenting comment; every other assert byte-identical | **met** (§1, §7 — only the f885 `moves_left` line + comment changed; f845/f860/f900/f915/f960 blocks untouched). |
| `tests/test_ending_gate_pins.py` untouched; grep-verified no trait_combat entry; finding recorded; none added | **met** (§2f, §5). |
| `python3 -m pytest tests/ -q` still green | **met** (no Python touched; downstream gate). |

---

## 4. 决策记录 (Decision record — diagnosis chain)

**Verdict: branch (b) REAL STAT SHIFT** (not branch (a) timing drift).

Evidence for (b) over (a): at f875/f885/f895 `grid_pos = (7,3)` is **stable**
(slide fully resolved) and `moves_left = 3` is **stable** (not counting down across
adjacent frames; the budget is locked after the single action). Timing drift would
show moves_left decrementing across the frames; it does not.

Diagnosis chain (boot → mp → move_range → expected moves_left):

1. **Boot source**: menu → tutorial (`debug_win_tutorial`) → creation with traits
   左右互搏(idx0)/铁布衫(idx4)/身轻如燕(idx5)/杀破狼(idx8) → 唐门 (dart school) →
   `debug_step_month` ×26 → year 3 m1 → `debug_grant_art` (grants `a_dart`, the
   external **A** art) → `debug_enter_encounter`. The hero is PROFILE-BUILT in a real
   encounter via `BattleSetup.build_character` (`battlefield.gd:651`) → `derive_stats`.

2. **f845**: `Player` at `(7,5)`; `turn_start_moves_left` (== move_range after
   restrictions) probed = **5**.

3. **f860**: single `move_up`. The `(7,4)` tile is occupied (Sparring_Partner) and
   the hero owns `swallow_lightness` → **slide through** to `(7,3)`, consuming
   **exactly 2** (`player.gd:_try_move`, `player.gd:686` `moves_left -= 2`). There is
   **no** separate TraitEffects move bonus — `swallow_lightness`'s only hook is
   `pass_through_enemies` (grep-verified: no move_range/move_bonus term).

4. **mp = 6** (derived two independent ways, both agree):
   - *Practice trace.* `_debug_step_month` practices the first UNMASTERED **external**
     art, gain = `PRACTICE_ACTION_GAIN` = 2/month; `PRACTICE_TO_MASTER` = D:4, C:6,
     B:8, A:10; `GRADE_BY_YEAR` = [D, C, B]. The A art (`a_dart`) is granted at
     **f790, AFTER** the 26-month practice window, so it is never practiced. Over 26
     months: Year 1 masters **ext-D** (2 mo) then falls back to **int-D** (2 mo);
     Year 2 masters **ext-C** (3 mo) then **int-C** (3 mo); Year 3 has only months
     25–26, so **ext-B** reaches 4/8 practice and is **not** mastered. Mastered rows
     = ext-D(1) + int-D(1) + ext-C(2) + int-C(2) = **mp 6**.
   - *Stat cross-check.* `derive_stats` (`battle_setup.gd:62-63`): `max_health =
     bone*5 + 18*mp`, `energy = inner*2 + 4*mp` (gear = 0, no equipment this boot).
     Probed `max_health = 303`, `energy_max = 48`. The only plausible integer
     solution is **mp = 6** (bone = 39, inner = 12).

5. **move_range = 5** (CURRENT `derive_stats` formula, `battle_setup.gd:64`, includes
   the C5 unlock lever ③ `move_range += floor(mp/2)`):
   `2 + floor(agility/20) + floor(mp/2) + gear.move = 2 + floor(10/20) + floor(6/2) + 0 = 2 + 0 + 3 + 0 = 5`.
   agility = 10 (creation default; the trait-selection boot allocates no attr points
   to 身法). Matches probed `turn_start_moves_left = 5`.

6. **expected moves_left = move_range − 2 (slide) = 5 − 2 = 3** — **matches the
   observed 3**.

7. **Why the old pin was green pre-C1**: pre-C1, `mastery_points` was always 0 on
   real saves (the C1 key-vocabulary split — CJK `GRADE_POINTS` keys vs Latin save
   keys). mp = 0 → `move_range = 2 + 0 + floor(0/2) + 0 = 2` → after the 2-cost slide,
   `moves_left = 0`. So `moves_left == 0` was honest in the pre-C1 world; post-C1
   (mp = 6) + C5 lever ③, move_range is 5 and the slide leaves 3.

**Why the new pin is the stable contract (not the bare observed 3).** The invariant
being tested is "the 身轻如燕 slide costs **exactly 2** movement." `turn_start_moves_left`
equals the turn-start budget (== move_range), so `moves_left == turn_start_moves_left - 2`
pins that invariant as a **differential**: if a future re-balance moves mp or agility
(and hence move_range), both the LHS and RHS shift together and the pin stays true,
whereas a literal `moves_left == 3` would silently red. This is the 00_roadmap
"数字即契约" re-derivation, expressed as a property, not a literal.

---

## 5. Door finding (tests/test_ending_gate_pins.py)

`grep -i trait_combat` and `grep -i trait` against `tests/test_ending_gate_pins.py`
return **no matches** (2026-09-03). The door has **NO** `trait_combat_effects_and_
twelve_slots` entry. Per the card: record the finding, add none, leave the file
untouched. (The `huashan_winnable_normal_route` entry in that file belongs to
r3d_c5_honest_close and is not this card's to touch.)

---

## 6. Four pre-fix and four post-fix values

Red-first four values = (failing_frame / first_failing_assert / observed / green_asserts_before_red).

**Pre-fix** (official 2026-09-03 run, re-confirmed by §2a sidecar):
1. failing frame: **885**
2. first failing assert: **`Player.moves_left: moves_left == 0`**
3. observed / exact error: **`FAIL f885 Player.moves_left: moves_left == 0 (observed=3)`**
4. greens before red: **21** (21/22)

**Post-fix** (§2e sidecar, staged file applied):
1. failing frame: **none**
2. first failing assert: **none**
3. observed / error: **none (all asserts pass)**
4. green asserts: **22/22**, 0 runtime errors, hard gate passed.

---

## 7. Change table (old pin → new pin → why stable)

| Location | Old pin | New pin | Why the property is stable |
|---|---|---|---|
| f885 block, `Player.moves_left` line (was line 217, now line 228) | `Player.moves_left: moves_left == 0` | `Player.moves_left: moves_left == turn_start_moves_left - 2` | Pins the invariant "the 身轻如燕 slide costs exactly 2 movement" (`player.gd:686`) as a differential against the turn-start budget (== move_range). Tracks any future mp/agility re-balance without re-editing; not the bare observed 3; a more precise statement of the same slide-cost contract than "budget exhausted." |

Documenting comment added at lines 217–227 (derivation chain: branch (b); mp=6 from
ext-D+int-D+ext-C+int-C mastered / ext-B unmastered by m26 / a_dart granted after the
practice window; agility=10; move_range=2+0+3+0=5; pre-C1 mp=0→move_range=2→old pin
honest). **Zero other assertion changes; zero threshold loosening.**

---

## 8. Known gaps 与遗留 (Known gaps)

- The `battle_setup.gd:47` doc comment still reads `floor(mp / 3)` while the code at
  `:64` is `floor(mp / 2)`. Stale comment — **the file is forbidden to edit this card
  (zero game-code edits)**, so the comment is left as-is; all derivation above uses
  the **code line**, not the comment. Flag for a future round to reconcile the comment.
- mp was cross-checked via the `max_health`/`energy_max` integer solution (mp=6,
  bone=39, inner=12); the bone/inner split is inferred from the two equations + the
  integer constraint. The mp=6 value itself is independently confirmed by the
  practice trace (§4 step 4), so the move_range/moves_left derivation does not depend
  on the exact bone/inner split.

---

## 9. 边界声明 (Boundary — what was NOT touched)

- **Zero game-code edits** (all forbidden): `battle_setup.gd`, `progression_math.gd`,
  `event_logic.gd`, `cultivation.gd`, `battlefield.gd`, `map_battle_data.gd` — untouched.
- **C1 and C7 stay**: `progression_math.gd` GRADE_POINTS Latin keys and work_income
  curve untouched; the derivation *consumes* them (mp=6 now non-zero on real saves).
- **`tests/test_ending_gate_pins.py`** untouched (no trait entry, verified §5).
- **No other playtest yaml touched**; six-file lock + three verbatim gates untouched.
- **No new debug action** added to the timeline (the existing boot's `debug_*` actions
  are pre-existing; none added).
- **Zero RNG ops** — the change is a read-only pin re-derivation (one assert line +
  comment); no code path, action, or draw is added or removed.
- Inline probe scenarios (§2b/§2c/§2d) were throwaway `inline_scenario` runs and were
  **never written to the repo**.
