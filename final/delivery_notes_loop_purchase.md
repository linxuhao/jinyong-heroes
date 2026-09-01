# Delivery Notes — fix_purchase_nail_scene_boot (jinyong-loop R2, D4)

> Date: 2026-09-01
> Task: fix the purchase nail's wrong boot scene, redo its red-first under the corrected boot.
> Scope: `playtest/event_option_refused_no_charge.yaml` + `final/delivery_notes_loop_purchase.md`.
> `scripts/data/event_logic.gd`: temporary revert measured then restored byte-identically (zero residue).

## 1. The mis-boot root cause (official 5_compile run, 2026-09-01)

`playtest/event_option_refused_no_charge.yaml` measured **0/11** in the official run — the only
scenario in the whole 84-scenario run with genuinely failing assertions. Measured failures:

- at f400 `GameManager.current_state` observed **TUTORIAL** (expected MAP);
- every MapScreen assert failed with `node not found: MapScreen`.

**Root cause:** the file carried a `scene: res://scenes/menu.tscn` override (line 69) while its
timeline was copied verbatim from the facility-cap nail's proven boot (7 tutorial-intro ui_accepts
at f3..f15 → `debug_win_tutorial` at f20 → WON overlay continue → transition accepts → sect pick →
cultivation → `debug_grant_equip` → `debug_fast_forward` → MAP) — a boot authored for the
CONTRACT-DEFAULT `main.tscn`. `facility_use_cap_exhausted_zero_delta.yaml` has NO `scene:` line
(it inherits `scene: res://scenes/main.tscn` from `playtest/_common.yaml`) and its assertions all
passed in the same official run (33/33). Booting `menu.tscn` instead desynchronized the entire
timeline (the ui_accepts walked the menu/creation screens instead of the tutorial intro pages) and
the run stranded in TUTORIAL forever.

## 2. Fix actions applied

1. **Deleted** the `scene: res://scenes/menu.tscn` line — the file now inherits the contract
   default `res://scenes/main.tscn`, exactly like the green facility nail whose boot it mirrors.
   The timeline is byte-identical to that proven boot up to f220; the only insertions are
   `debug_grant_equip` at f260 (between the facility boot's f220 accept and its f280
   `debug_fast_forward`) — kept.
2. **Corrected** the description prose: "Boots menu.tscn" → "Boots the contract-default main.tscn"
   (a copy fix in a non-protected scenario file, not a game-UI copy change).
3. **Filled the red-first block** with MEASURED four values from a real red run under the corrected
   boot (see §3) — no placeholders, no data spliced from the old mis-booted run.
4. **Frames re-baselined** from the measured green run: the corrected main.tscn boot reaches MAP at
   f400 exactly as the facility nail does, so the existing `at:` frames (f400/f440/f470) needed no
   change — verified by the 11/11 green run.
5. **No `debug_grant_silver` funding added** — the measured green run's receipt is the OWNED
   wording (此物已在行囊，无须再购), not 银两不足 (see §4).

## 3. Red-first redo — MEASURED four values (corrected boot)

The official 0/11 red was measured for the WRONG reason (the scene mismatch), not the owned-refusal
revert. With the boot fixed, the documented TEMPORARY RED-FIRST REVERT was applied to
`scripts/data/event_logic.gd` and the CORRECTED scenario was run via the direct
`godot_playtest_scenario` sidecar.

**Revert applied (both functions, marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`):**
- `validate_option()` → `return ""` unconditionally (so map.gd's `_resolve_node_event` REFUSED
  path never fires and the APPLIED path runs);
- `apply_option_effects()` → the old unconditional-charge shape (silver applies regardless with the
  `maxi(..., 0)` clamp, item appends only when absent, no refusal receipt).

**Measured red run (corrected boot, revert applied):** `event_option_refused_no_charge` **8/11**.

| # | Value | Measured |
|---|---|---|
| failing_frame | 470 | first failing assert at f470 |
| first_failing_assert | `MapScreen.last_effect_types` — `last_effect_types.is_empty() == true` | observed `["silver", "item"]` (effects applied, not refused) |
| exact_error/observed | at f470, three asserts red | `last_effect_types.is_empty() == true` → observed `["silver", "item"]`; `silver == event_open_silver` → observed `1810` (event_open_silver `1830` — dipped by exactly 20, the old unconditional charge); `map_status_text != ""` → observed `""` (no refusal receipt) |
| green_asserts_before_red | 8 | f400 `current_state == "MAP"` + `visible == true`; f440 `phase == "EVENT"` + `event_id == "merchant"` + `current_node_id == "luoyang"` + `silver == event_open_silver`; f470 `phase == "TRAVEL"` + `events_resolved_count == 1` |

**Restore:** `event_logic.gd` restored byte-identically; `grep scripts/ "TEMPORARY RED-FIRST
REVERT"` → **zero hits** (verified). Re-run GREEN: **11/11**.

## 4. Owned-vs-silver honesty check

The nail's stated purpose is to pin the OWNED refusal (`EventLogic.validate_option` returns
"owned" because `eq_sword_3` was granted into inventory at f260). `validate_option` checks net
silver capacity FIRST, then item ownership — so if the post-fast-forward balance at the merchant
were < 20, the SILVER reason would fire instead and the nail would pass for the wrong reason.

**Verified on the measured green run:** the receipt is the OWNED wording
`此物已在行囊，无须再购` (probed via an inline scenario asserting an impossible value on
`map_status_text` at f470 — observed the owned wording). The red-run evidence independently
confirms balance ≥ 20: under the revert, silver dipped by exactly 20 from 1830 → 1810, so the
post-fast-forward balance at the merchant was ≥ 20. **No `debug_grant_silver` funding was needed.**

## 5. Blast radius

Re-ran the two co-boot scenarios via the sidecar after the fix — both stay green:

- `facility_use_cap_exhausted_zero_delta` — **33/33** (same boot route, unchanged);
- `map_node_event_revisit_no_resettle` — **33/33**.

This route resolves the merchant event and grants `eq_sword_3` into inventory; no co-running
scenario on this boot asserts NOT owning it (the equipment-round nails assert ownership/equip
state, not absence).

## 6. Red-line self-check

- `playtest/facility_use_reusable.yaml`, `playtest/map_node_event_shaolin.yaml`,
  `playtest/map_battle_node_huashan.yaml` — **byte-untouched** (verbatim-protected trio).
- `scripts/data/event_logic.gd` — landed content byte-identical to the pre-task baseline (the
  validate-then-apply logic is a LANDED, passing repair; the revert was temporary and measured
  only, restored byte-identically, zero residue).
- No balance numbers moved.
- The five landed fixes (soft-lock, facility cap, re-settlement split, all-or-nothing, occlusion)
  are untouched — this task touched only the one broken scenario yaml and its delivery notes.
- Out of scope (not touched here): the `ui_occlusion_watch.gd:58` runtime error that hard-fails
  the whole official run — that is the occlusion-watch subtask's fix surface.

---

# Delivery Notes — fix_purchase_nail_name_contract (jinyong-loop R2, D4 guard pin repair)

> Date: 2026-09-01
> Task: repair the two doubled-backslash regexes in
> `tests/test_playtest_contract_smoke.py::test_event_option_refused_nail_contract`
> (the name==basename pin and the integer-`at` pin), which were vacuous and could never evaluate
> their intended property. `playtest/event_option_refused_no_charge.yaml` is NOT edited.

## 1. The failing assert (official 5_test 2026-09-01)

The official review verdict rejected the round on one test:
`tests/test_playtest_contract_smoke.py::test_event_option_refused_nail_contract` FAILED with
`assert None` (55 passed / 1 failed). All other gates were green on the current tree
(5_compile: 84/84 playtest PASS, hard gate passed True, 0 runtime errors; 5_vision passed
non-blind; compile 99/99).

## 2. Ground-truth reads (byte-exact, verified 2026-09-01)

**(a) The yaml side is already correct — do NOT edit it.** `playtest/event_option_refused_no_charge.yaml`
line 78 reads, byte-for-byte at column 0, with no suffix and no inline comment:

```
name: event_option_refused_no_charge
```

This is byte-equal to the basename `event_option_refused_no_charge`. The reviewer's "fix the yaml
name line" hypothesis is therefore refuted by the file itself.

**(b) The real defect is in the guard's regex source.** Both pins were authored with DOUBLED
backslashes inside raw strings, so the compiled patterns search for literal `\s` (backslash + s)
and can never match. Guard source lines, byte-exact BEFORE repair:

- line 2168: `rf"^name:\\s*{name}\\s*$"`  (two literal backslashes before each `s`)
- line 2171: `r"\\bat\\s*:\\s*([^,}\\s]+)"`  (two literal backslashes throughout)

Because each doubled form searches for literal backslash-s, the name pin returned `None` on every
file (green or not) — `assert None` — and the `at` loop body never ran (the pattern never matched).
This guard had never been exercised before: it previously redded earlier at the absolute-index
equality repaired by `fix_nail_contract_guards`, so the broken regex had never been reached.

Confirmed by search: these two lines are the ONLY doubled-backslash regexes in the file; every other
name/`at` regex (e.g. :615, :664, :667) uses the correct single-backslash form.

## 3. The two-line repair (tests/test_playtest_contract_smoke.py ONLY)

| Line | BEFORE (doubled) | AFTER (single) |
|---|---|---|
| 2168 | `rf"^name:\\s*{name}\\s*$"` | `rf"^name:\s*{name}\s*$"` |
| 2171 | `r"\\bat\\s*:\\s*([^,}\\s]+)"` | `r"\bat\s*:\s*([^,}\s]+)"` |

No other character in these two lines changes; every other line of `test_event_option_refused_nail_contract`
(the two presence asserts, the relative-order sync assert, the mandatory-line pins, the surface-block
checks) and every other function in the file stays byte-identical. The `+` quantifier at :2171 is
preserved from the original intent (as opposed to the `*` at :667) — an intentional choice, not a
normalization, so a future reader does not "normalize" it back. This is a REPAIR OF THE PIN, not a
weakening: before, both pins matched nothing (vacuous); after, the name pin fails exactly when a
scenario's name line deviates from its basename, and the at pin fails on any non-integer `at` value
(`match.group(1).isdigit()` False → `assert False`).

## 4. Regex proofs (in-memory; the real gate, since pytest cannot run in this step)

The doubled-backslash forms made both guards vacuous, so a green pytest alone could not prove the
fix works — these proofs are what establish the pins bite. Both are in-memory only; no disk mutation.

**(a) Positive — the repaired name pin matches the real yaml.**
`python3 -c "import re;print(bool(re.search(r'^name:\s*event_option_refused_no_charge\s*$',open('playtest/event_option_refused_no_charge.yaml',encoding='utf-8').read(),re.MULTILINE)))"`
prints **True**: with `re.MULTILINE`, `^` anchors to line 78's column 0, `event_option_refused_no_charge`
matches, `\s*$` matches end-of-line — a real match on the untouched file.

**(b) Negative 1 — the same name pin rejects a deviating name line.**
Applied to an in-memory copy whose name line is mutated to `name: event_option_refused_no_charge #wrong`,
the `\s*$` tail can no longer reach end-of-line (the ` #wrong` suffix intervenes) → returns **None**.
The pin therefore detects exactly the deviation it exists to catch.

**(c) Negative 2 — the repaired at pin catches a non-integer `at`.**
`re.search(r"\bat\s*:\s*([^,}\s]+)", '  at: x, press: ui_accept')` matches with `group(1) == 'x'`
(a non-integer), so `match.group(1).isdigit()` is False and the guard's `assert False` fires. The pin
therefore catches any non-integer timeline `at` value.

## 5. pytest result — NOT EXECUTED + reason

`python3 -m pytest tests/` could not be run in this step: **no shell/process-execution tool is
available in this environment** (only file read/write and the Godot playtest sidecar). No measured
pytest number is fabricated. Expected from the prior official run: 55 passed + 1 failed →
56/56 green after the two-line repair; but that remains a prediction, not a measurement, and is
recorded as such. Downstream 5_test re-runs the official target and records the exact result line.

Acceptance therefore rests on: (1) the two-line byte diff (§3), (2) the three regex proofs (§4a/b/c),
and (3) the runtime blast-radius check below.

## 6. Blast radius (measured)

- `playtest/event_option_refused_no_charge.yaml` — **untouched** (its name line is byte-correct; §2a).
- `playtest/facility_use_reusable.yaml`, `playtest/map_node_event_shaolin.yaml`,
  `playtest/map_battle_node_huashan.yaml` and every other playtest file — **untouched** (this task
  edited only the two guard lines in the pytest file).
- The playtest harness does not consume the yaml name field at runtime; the 84/84 playtest run passed
  with this file as-is. Re-verified on the repaired tree via the direct `godot_playtest_scenario`
  sidecar (with the staged pytest edit applied): `event_option_refused_no_charge` **11/11 PASS**,
  hard gate passed True — the runtime behavior is unchanged by this guard repair.
- No game code, scene, or runtime-behavior change; no balance numbers.
