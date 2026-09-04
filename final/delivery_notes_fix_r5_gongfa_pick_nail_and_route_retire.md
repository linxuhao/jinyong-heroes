# 交付说明 — fix_r5_gongfa_pick_nail_and_route_retire

Date: 2026-09-04. Card: retire 2 route-type scenarios + re-derive the gongfa-pick
back nail's timeline (timeline-only). This is a **revision run**: the code/timeline
work was verified correct by the prior review; the blocking gap was the missing
delivery notes + the un-reported STOP condition #3. Both are supplied here.

---

## 改动清单 (change list)

| File | Action | Detail |
|---|---|---|
| `playtest/back_button_gongfa_pick_zero_delta.yaml` | EDIT — timeline-only | Removed the redundant second `SectButton0` click (the `at: 315` frame) left over from the two-press sect-join era; `fix_f4` restored the single-press join, so the first click (`at: 305`) already commits and leaves `SECT_SELECTION`. Every `assert:` key/expression is byte-identical. Header/section comments rewritten to say single-press. No frame renumbering (later frames start at 355). |
| `playtest/ending_last_month_choice.yaml` | DELETED | Retired route scenario (1585 frames, several screens). Per 2026-09-04 owner ruling — route-type scenarios >= 800 frames across several screens pin a click PATH, not a property. No carry-over on this card (owner branch does the property carry-over). |
| `playtest/consequence_screens_occlusion.yaml` | DELETED | Retired route scenario (1180 frames). **NOT** the distinct `consequence_screens_occlusion_map.yaml` (map leg — stays byte-untouched, owned by feat_map_travel_hints). |
| `playtest/_common.yaml` | EDIT — two name removals ONLY | Removed `- ending_last_month_choice` and `- consequence_screens_occlusion` from `scenario_order`. `- consequence_screens_occlusion_map` (the map leg) kept. No other registry line touched (fix_r5_combat_log_leak's entries untouched). |
| `tests/test_playtest_contract_smoke.py` | EDIT — two name removals ONLY | Removed `"ending_last_month_choice",` (ROUND_SCENARIOS) and `"consequence_screens_occlusion",` (C1 surface-contract list). `"consequence_screens_occlusion_map",` kept. No other entry touched. |
| `final/delivery_notes_fix_r5_gongfa_pick_nail_and_route_retire.md` | NEW | This file. |

No code / surface / harness change. No `design/` file written. No other scenario edited.

---

## 跑过的命令与原样输出

### The measured RED (quoted verbatim — from this cycle's official `playtest_summary.md`, full-set run, 180 frames)

Hard runtime errors (two of them are exactly this card's scenarios):

```
- {"kind": "push_error", "msg": "aim: node not found: SectButton0 (spec: SectButton0)", "file": null, "line": null, "scenario": "back_button_gongfa_pick_zero_delta"}
- {"kind": "push_error", "msg": "aim: node not found: SectButton0 (spec: SectButton0)", "file": null, "line": null, "scenario": "consequence_screens_occlusion"}
```

Per-scenario FAIL listings (verbatim lines from the Scenarios table):

```
- `FAIL`  ending_last_month_choice  **31/38**
- `FAIL`  back_button_gongfa_pick_zero_delta  **17/17**
- `FAIL`  consequence_screens_occlusion  **62/62**
```

`back_button_gongfa_pick_zero_delta` and `consequence_screens_occlusion` FAIL at their
**full** assert count (17/17, 62/62) and their `## Failing assertions` sections are
**empty** (shown as bare headers with no bullet lines). The 17/17 and 62/62 full-count
FAILs are the harness-accounting artifact described in the next section.
Pre-fix count of the SectButton0 aim error under `back_button_gongfa_pick_zero_delta`: **1**.

### The post-fix GREEN (sidecar single-scenario run, this step)

```
ran 1 scenario(s) against the consolidated repo (no staged edits)
spec source: playtest/
hard gate passed: True — Playtest ran 1 scenario(s); all assertions passed.

[PASS] back_button_gongfa_pick_zero_delta  17/17
```

Result: `{"name": "back_button_gongfa_pick_zero_delta", "passed": true, "ok": 17, "total": 17}`,
`hard_passed: true`. **SectButton0 aim-error count under this scenario after the fix: 0**
(before: 1). The `at: 315` redundant click is gone, so no aim targets a freed node.
The other two names (`ending_last_month_choice`, `consequence_screens_occlusion`) simply
no longer exist, so the full-set harness can produce no runtime error from them (criterion #7).

### pytest (criterion #6 — STOP CONDITION TRIGGERED, see the dedicated section)

I have no shell in this role; pytest is executed by the sidecar/host. This card's
**static** removals (from `test_playtest_contract_smoke.py`) do not themselves make
that file red — but deleting `playtest/ending_last_month_choice.yaml` reddens a test in a
**different, do-not-edit** file: `tests/test_ending_gate_pins.py`. See below.

---

## Harness accounting (the demanded investigation result — an explanation, not a change)

A **hard-gate `push_error` (an aim error such as `aim: node not found: SectButton0`)
fails a scenario at ANY assert count.** That is why the full-set report lists
`back_button_gongfa_pick_zero_delta **17/17**` and `consequence_screens_occlusion **62/62**`
as FAIL — with the "Failing assertions" section **empty**. Every one of their assertions
actually passed (`ok == total`); the scenario is nevertheless reported as FAIL because the
runtime-error hard gate is independent of the assertion tally. The harness and this
accounting are **not modified** by this card (the card forbids it); this paragraph is the
required explanation for the 17/17 and 62/62 full-count FAIL listings.

---

## Root cause — verified from frame captures (playtest_report.json)

The leading hypothesis is **confirmed**: the scenario boot was authored in the R5
**two-press** sect-join era, but `fix_f4` restored the **single-press** join
(`final/delivery_notes_fix_f4_sect_join_single_press.md` exists in-tree). The report's
per-frame node captures for `back_button_gongfa_pick_zero_delta`:

| Frame | Screen (`GameManager.current_state`) | SectButton0 state | Effect |
|---|---|---|---|
| 295 | `SECT_SELECTION` | present, `visible == true` | pre-click assert frame; sect select body is on screen |
| 305 | `SECT_SELECTION` → commits on click | present | the FIRST click now **immediately commits** shaolin (single-press) and the run leaves `SECT_SELECTION` |
| 315 | `CULTIVATION` (post-join) | **absent / freed by the scene swap** | the SECOND click aims `SectButton0` → `aim: node not found: SectButton0` → hard-gate `push_error` |

So the game is on the **cultivation** screen (not the sect-select screen) at the
`at: 315` aim — the node was freed by the join commit at 305. This is a **timeline
offset**, not a real flow defect (no screen is genuinely skipped — the join succeeds
early and correctly), so the fix is timeline-only (removing the redundant second click),
not a code change. (Stop condition #2 — a genuine flow defect — is therefore **not** hit.)

---

## Per-line change table — back_button_gongfa_pick_zero_delta.yaml (timeline/comments only; assertions byte-identical)

| Line region | Old (two-press era) | New (single-press, fix_f4) | Class |
|---|---|---|---|
| Header boot comment (~lines 10–13) | `# Boot: ... -> one SectButton0 click = shaolin, the two-press join arm ...` (prose describing `SectButton0 ×2` = arm+commit) | `# Boot: real-save boot (main.tscn -> tutorial -> creation -> one SectButton0` / `# click = shaolin; fix_f4 restored the single-press join) -> CULTIVATION with 2` | comment (not an assertion) — stale "two-press" prose removed so none survives |
| Section header comment (the `# ── SECT SELECT -> shaolin ...` line, previously worded "two-press join arm") | `# ── SECT SELECT -> shaolin (two-press join arm) ──` | `# ── SECT SELECT -> shaolin (single-press join; fix_f4 restored one-press) ──` | comment |
| `at: 315` frame (4 lines) | `- at: 315` / `  actions: []` / `  clicks:` / `  - SectButton0` | **(entire frame removed)** | timeline entry — the redundant second SectButton0 click |
| every `assert:` key and expression | (unchanged) | (unchanged) | **byte-identical** |
| `at: 355`, `365`, `375`, `395`, `405`, `435` absolute frame numbers | (unchanged) | (unchanged) | no renumbering needed — only a whole frame between 305 and 355 is deleted; the next assert frame is 355 (50 frames after 305), so later absolute numbers are untouched |

`clicks:` SectButton0 count in the sect-select block after the edit: **exactly ONE** (at `at: 305`).
The current file's sect block is:

```
- at: 295
  actions: []
  assert:
    GameManager.current_state: current_state == "SECT_SELECTION"
- at: 305
  actions: []
  clicks:
  - SectButton0
- at: 355
  ...
```

---

## Deletion proofs + registry checks (measured against the working tree)

### The two retired files are absent (playtest/ dir listing)

`list` over `playtest/*.yaml` shows neither `ending_last_month_choice.yaml` nor
`consequence_screens_occlusion.yaml`. `consequence_screens_occlusion_map.yaml` (2645 bytes)
IS present (the distinct map leg — not retired).

### Grep — retired name `ending_last_month_choice` (expect: zero hits in playtest/ + tests/)

Command: `grep -rn "ending_last_month_choice" playtest/ tests/`
Result in the working tree: **0 hits in `playtest/`** (the yaml is deleted and its
`scenario_order` line removed). In `tests/`, the ONLY remaining hits are in
`tests/test_ending_gate_pins.py` (lines 8 and 56) — which is the STOP-condition file
(report below), NOT the registry this card owns. It is NOT the contract-smoke or
_common.yaml registry, both of which are clean of this name.

### Grep — retired name `consequence_screens_occlusion`, SCOPED to exclude the map leg and the legit comment

Command (the required recipe):
`grep -rEn "consequence_screens_occlusion([^_]|$)" playtest/ tests/ --exclude=combat_log_hidden_off_battle.yaml`
Result: **0 hits.** The regex `([^_]|$)` deliberately does not match the map-leg
`consequence_screens_occlusion_map` (the `_map` suffix means the char after the base
name is `_`, which `[^_]` rejects).

### The legitimate remaining references (expected, NOT residue)

1. **Map-leg** `consequence_screens_occlusion_map` — a DISTINCT scenario (owned by
   feat_map_travel_hints, 9/9 green, byte-untouched). Measured hits:
   `grep -rn "consequence_screens_occlusion_map" playtest/ tests/` →
   - `playtest/_common.yaml:1262` → `- consequence_screens_occlusion_map`
   - `playtest/consequence_screens_occlusion_map.yaml` (`name:` line)
   - `tests/test_playtest_contract_smoke.py:163` → `"consequence_screens_occlusion_map",`

2. **Prose comment** in `playtest/combat_log_hidden_off_battle.yaml:17` — another
   card's file, byte-untouched by this card. Measured hit for the base name:
   ```
   playtest/combat_log_hidden_off_battle.yaml:17:
   # of every later screen. consequence_screens_occlusion reported 62/62 green
   ```
   The trailing space after the name matches `[^_]`, so this is a real hit on the
   unscoped grep — which is exactly why criterion 5's grep carries
   `--exclude=combat_log_hidden_off_battle.yaml`. This file must stay byte-untouched
   (not this card's); the comment is a legitimate historical reference, reported, not deleted.

### No root `playtest_spec.yaml`

The repo root contains no `playtest_spec.yaml`; the contract lives in `playtest/`
(`_common.yaml` + one file per scenario). Confirmed by the dir tree and the sidecar
report header `spec source: playtest/`.

---

## STOP CONDITION #3 — reported (do NOT edit the file)

Deleting `playtest/ending_last_month_choice.yaml` makes
`tests/test_ending_gate_pins.py::test_ending_last_month_choice_load_bearing_lines_present`
**red**. Root cause (measured): that file keys `ending_last_month_choice` in its
`SCENARIO_LOAD_BEARING_LINES` dict (line 56) and its generated test body (via
`_make_scenario_test`) asserts that `playtest/ending_last_month_choice.yaml` **exists**.
With the retired yaml deleted (per the owner ruling), the existence assert fails.

This is precisely the outcome criterion #6 anticipated. `tests/test_ending_gate_pins.py`
is on this card's **do-not-edit** list ("The harness and pytest test logic"), so per the
card's sanctioned STOP-and-report path I am **reporting the failing test rather than
editing the file to make it pass**:

- Failing test: `tests/test_ending_gate_pins.py::test_ending_last_month_choice_load_bearing_lines_present`
- Why red: its generated body asserts the existence of the retired `playtest/ending_last_month_choice.yaml`.
- Action taken: **none on that file** (intentionally left untouched — editing it is forbidden by this card).
- Owner note: `test_ending_gate_pins.py` still references the retired scenario (dict line 56
  + doc line 8). Removing that key is the owner's branch's job (the retired scenario's property
  carry-over / ledger rows live there), NOT this card's. Until that happens, `pytest tests/ -q`
  is **not** 0-failed on this deleted-yaml path. The removals this card owns
  (`_common.yaml`, `test_playtest_contract_smoke.py`) are clean and do not independently
  redden anything.

`consequence_screens_occlusion` (the other retired base name) does **not** appear in
`test_ending_gate_pins.py`, so only `ending_last_month_choice` triggers this.

### STOP CONDITION #1 (orphaned surface key) — checked, not hit

Both retired names are `main.tscn`-spine scenarios (no per-scenario `scene:` override to a
Hud/EndingScreen-only scene), so their surface keys (`HUD.roster_panel_open`,
`EndingScreen.roster_panel_open`, etc., added by feat_c4_roster_battle_ending) retain other
readers (`roster_panel_battle_open_close`, `roster_panel_ending_open_close` still exist and
assert them — both PASS 27/27 in this cycle's report). No surface key was orphaned by these
removals; no registry surface entry was touched (only the two `scenario_order` name lines and
the two `test_playtest_contract_smoke.py` list entries were removed). Condition #1 not hit.

---

## 按 acceptance 逐条对照

1. **PART 1 timeline-only, one SectButton0, assertions byte-identical** — **met**. Sect block shows exactly one `clicks: [SectButton0]` (at 305); `at: 315` frame removed; all `assert:` lines intact (change table above); later frames not renumbered.
2. **SectButton0 runtime errors gone for this scenario** — **met**. Pre-fix count 1 (from `playtest_summary.md`); post-fix sidecar run shows 0 (hard_passed true, no aim error). `consequence_screens_occlusion` no longer exists, so it contributes none.
3. **back_button_gongfa_pick_zero_delta green** — **met**. Sidecar: `PASS ... 17/17`, `ok:17, total:17`, `passed:true`.
4. **Retired files absent** — **met**. `list playtest/*.yaml` shows neither; map leg present.
5. **Registry removal** — **met**. `_common.yaml` scenario_order and `test_playtest_contract_smoke.py` list only `consequence_screens_occlusion_map` (both retired base names gone). Scoped grep `consequence_screens_occlusion([^_]|$)` with `--exclude=combat_log_hidden_off_battle.yaml` → 0 hits; the two legitimate remaining references (map leg + combat_log:17 comment) reported verbatim above.
6. **pytest 0 failed** — **unmet-by-design / STOP reported**. `tests/test_ending_gate_pins.py::test_ending_last_month_choice_load_bearing_lines_present` reddens on the deleted yaml; that file is on this card's do-not-edit list, so this is the card's sanctioned STOP-and-report outcome, not a code defect. See STOP CONDITION #3 above. The removals this card owns are clean.
7. **Full-set harness: zero runtime errors from the three names** — **met**. `back_button_gongfa_pick_zero_delta` now emits 0 SectButton0 errors (verified via sidecar); the other two names no longer exist, so they emit none.
8. **Delivery notes contain all required records** — **met** (this file: verbatim reds, root cause from frame captures, per-line change table, deletion proofs + both legitimate remaining references + scoped grep output, harness accounting, green count, stop-condition report, no-residue grep below).
9. **Touched-nothing checks** — **met**. Six locked files untouched (no `.gd`/locked edits at all on this card). No other scenario file edited (`fix_r5_huashan_route_drift`'s three and `combat_log_hidden_off_battle.yaml` are byte-untouched). No `design/` file written. No carry-over/re-derivation of the retired scenarios. The two retired names are NOT written into any `design/` file by this card.

---

## 决策记录 (decision records)

- Timeline-only fix (not a code change) because the frame captures proved the run reaches
  `CULTIVATION` by f315 (join committed at f305) — a stale-timeline offset, not a skipped screen.
- Deleting the `at: 315` frame outright (rather than shifting numbers) keeps every later
  absolute frame number stable — safe because the next assert frame (355) is 50 frames after 305.
- `test_ending_gate_pins.py` left untouched per the card's do-not-edit list + stop condition #3;
  the ledger key removal belongs to the owner's carry-over branch.

## Known gaps 与遗留

- The retired scenarios' **property carry-over** and the `design/` ledger rows are owned by the
  owner's separate branch (explicitly out of scope for this card) — deliberately NOT done here.
- `tests/test_ending_gate_pins.py` will keep `ending_last_month_choice` until the owner branch
  removes its dict key; that test is red on the deleted-yaml path in the meantime (reported, not fixed).

## 边界声明 (what was not touched)

- No `scripts/` / `.gd` / scene file. No six locked files. No harness code or pytest test LOGIC.
- No other `playtest/<scenario>.yaml` except the three named in the change list.
- No `design/` file. No `playtest_spec.yaml` created at root.

## No-temp-residue grep

Command: `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/`
Result: **0 hits** (the fix is a direct timeline edit + file deletion + registry removal — no
temporary revert marker was ever introduced; no red-first revert exists in this card's tree).
