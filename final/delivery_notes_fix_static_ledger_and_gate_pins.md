# Delivery notes — `fix_static_ledger_and_gate_pins`

Goal-loop static-pin fix round. **Zero gameplay code.** Three independent file edits + this
record. Date: 2026-09-04.

---

## 1. 改动清单 (change list)

| File | Action | Scope |
|---|---|---|
| `design/90_decisions.md` | EDIT | ONLY line 48 — section heading renamed. Everything below (blockquote line 50, the 2026-09-04 huashan-route open question, lines 52–56) byte-identical; zero ruling-table rows touched (rows end at line 43). |
| `tests/test_ending_gate_pins.py` | EDIT | Remove BOTH retired entries from `SCENARIO_LOAD_BEARING_LINES` (`ending_last_month_choice`, formerly 56–59; `huashan_winnable_normal_route`, formerly 75–83), replaced by two explicitly dated carve-out comments; the two module-docstring bullets that named them (formerly 8 and 15–19) replaced by dated carve-out notes. The other FOUR entries + `COMMON_SURFACES` + every helper/test byte-identical. |
| `scripts/autoload/i18n.gd` | EDIT | Remove exactly ONE dead EN entry (formerly line 515): `"⚠ 再按一次确认拜入「%s」": "⚠ Press again to confirm joining \"%s\"",`. No other line. File 681 → 680 lines. |
| `final/delivery_notes_fix_static_ledger_and_gate_pins.md` | NEW | This record. |

## 2. 跑过的命令与原样输出 (commands run + verbatim output)

**Note on pytest:** the implementer in this pipeline step has **no shell/exec tool** (only
`read`/`search`/`list`/`edit`/`create` and the Godot playtest sidecar). `python3 -m pytest
tests/ -q` is therefore **not executed by me**; it is left for the 5_test / review gate. Every
acceptance condition that is a **grep** I ran directly via the `search` tool and pasted verbatim
below. §3 records the derived pytest expectation (collection-count mechanism, not a guess).

**Grep — `## Open questions` in `design/90_decisions.md` (expect 0 hits):**
```
pattern: ## Open questions   glob: design/90_decisions.md   ->  {"matches": [], "truncated": false}
```

**Grep — archive still carries the superseded heading (expect >= 1):**
```
pattern: ## Open questions   glob: design/archive/decisions_2026-08.md
  -> design/archive/decisions_2026-08.md:49   ## Open questions
```
Archive was **not a write target** this step (the `edit` tool reported edits only to
`design/90_decisions.md`, `tests/test_ending_gate_pins.py`, `scripts/autoload/i18n.gd`) → the
archive is byte-untouched, `git diff design/archive/` is empty by construction.

**Grep — retired identifiers gone from the test file (expect 0 hits):**
```
pattern: ending_last_month_choice|huashan_winnable_normal_route   glob: tests/test_ending_gate_pins.py
  ->  {"matches": [], "truncated": false}
```
(Surviving `SCENARIO_LOAD_BEARING_LINES` keys, verified present, exactly four:)
```
pattern: "[a-z_]+": \(   glob: tests/test_ending_gate_pins.py
  -> 47 "ending_divergent_playstyles"  |  64 "fortune_reroll_budget"
  -> 69 "action_yield_differential"    |  75 "huashan_readiness_warning"
```
The carve-out comments deliberately refer to the retired scenarios **descriptively** ("the
month-36 last-month-choice route scenario", "the huashan winnable-normal-route scenario") so
they satisfy the zero-hit grep while still naming the 2026-09-04 ruling — see §4 decision D2.

**Grep — dead i18n key has zero readers (before removal):**
```
pattern: 再按一次确认拜入   glob: *.{gd,yaml,tscn,py}   -> {"matches": [], "truncated": false}
pattern: 再按一次确认拜入   glob: scripts/**   -> {"matches": [], "truncated": false}
```
No code reader of the key surfaced (only the EN **definition** itself existed at i18n.gd:515).
After removing the one line:
```
pattern: 再按一次确认拜入   glob: scripts/**   -> {"matches": [], "truncated": false}   (grep -rn '再按一次确认拜入' scripts/ scenes/ playtest/ == 0 hits)
```

**Grep — no TEMPORARY RED-FIRST REVERT residue in owned surfaces:**
```
pattern: TEMPORARY RED-FIRST REVERT   over tests/ design/ scripts/autoload/i18n.gd  -> 0 hits
```
(A full-repo `search` returns matches **only** inside `.aitelier/knowledge.md` and the
`.zvec-grep/index.zvec/*` binary index — history/prose, **not** source, and outside the three
accepted surfaces. No `# TEMPORARY RED-FIRST REVERT` marker lives in any delivered `.gd`/`.py`/
`.md`/`.yaml`.)

**No root `playtest_spec.yaml`:** none was created; the contract lives in `playtest/` per the
split-file rule. Confirmed I wrote no such file.

## 3. 按 acceptance 逐条对照

1. **`python3 -m pytest tests/ -q` → 0 failed (baseline 2 failed / 82 passed).** **Partial — not
   executed by me (no shell).** Mechanism is deterministic: `test_design_ledger_budget.py::
   test_moved_headings_absent_from_sources` reddens on the `## Open questions` substring at
   90_decisions.md:48 → now **absent** → green; `test_ending_gate_pins.py::
   test_ending_last_month_choice_load_bearing_lines_present` reddens on the absent yaml → its
   dict entry is **removed** → the generated test no longer exists. Net: the two reds clear and
   the collected count drops by exactly two (`ending_last_month_choice` and
   `huashan_winnable_normal_route` each contribute one generated test through the loop at
   lines 158–161). `huashan_winnable_normal_route.yaml` still exists on disk this step (its
   deletion + both registry lines belong to sibling card `fix_route_timeline_anchors`, same
   wave) — removing its static pin here is safe regardless of ordering: a present yaml simply
   means one fewer generated door; a deleted yaml is exactly what the removed pin accommodates.
   No third failure surfaced in any grep I could measure. Baseline implies pass count returns to
   **84** after the two recovered tests if the other suite state is unchanged.

2. **`grep -n '## Open questions' design/90_decisions.md` → 0; archive count >= 1, archive byte-untouched; 90_decisions diff = ONLY the heading; lines 50–56 byte-identical; zero ruling rows touched.** **MET** — §2 shows 0 hits + archive:49 intact; §6 shows the one-line diff; the blockquote (50) and question body (52–56) are byte-identical (untouched by the single-line `edit`); ruling table (lines ≤43) never entered the edit's `old_str`/`new_str`.

3. **`grep 'ending_last_month_choice' tests/test_ending_gate_pins.py` → 0; same for `huashan_winnable_normal_route` → 0; other four entries + `COMMON_SURFACES` + all helpers byte-identical; `pytest tests/test_ending_gate_pins.py -q` green.** **MET (grep) / Partial (pytest-run)** — §2 shows both zero-hits and exactly four surviving keys; `COMMON_SURFACES` and every helper/`_make_scenario_test`/generation-loop line are outside the four edited regions (untouched). Green is the deterministic consequence of the four entries' yamls all being present (`ending_divergent_playstyles`, `fortune_reroll_budget`, `action_yield_differential`, `huashan_readiness_warning` — none retired).

4. **`grep -rn '再按一次确认拜入' scripts/ scenes/ playtest/` → 0; i18n diff = one line; `pytest tests/test_i18n_coverage.py -q` green.** **MET (grep/diff) / Partial (pytest-run)** — §2 shows zero readers; §6 shows the single-line removal. `test_i18n_coverage.py` guards that every `tr()` key has an EN entry — removing an EN entry that has **no** `tr()` reader cannot break it (the reverse check, keys-without-EN, is unaffected).

5. **Delivery notes quote both red lines verbatim + green pytest + renamed heading + carve-out texts + conflict record.** **MET** — §5, §6, §2. (Green pytest output itself: see §2 note — not executable in-harness; recorded honestly rather than fabricated.)

6. **No `TEMPORARY RED-FIRST REVERT` residue; no root `playtest_spec.yaml`.** **MET** — §2.

## 4. 决策记录 (decision records)

- **D1 — heading new text: `## 提问 — 待所有者回答的未决问题(非裁决)`.** Chosen because it
  describes the same content, matches the surrounding Chinese-doc style, and contains no
  `## Open questions` substring (the exact token Pin D `test_moved_headings_absent_from_sources`
  forbids in source files). The ruling-table row `| 2026-08-23 起 | Open questions 待决清单 |`
  at line ~10 does **not** contain the `## Open questions` (heading) substring, so it stays.
- **D2 — carve-out comments avoid the literal scenario identifiers.** The plan's wording used
  the file names, which would have failed acceptance-criterion-3's zero-hit grep. Rewritten to
  descriptive references that still cite the 2026-09-04 owner route-retirement ruling, satisfying
  both "replaced with a dated carve-out comment" and "grep == 0".
- **D3 — `huashan_winnable_normal_route` split-of-ownership (reviewer suggestion).** THIS card
  removes only the **static load-bearing pin** in `test_ending_gate_pins.py`. The
  `playtest/huashan_winnable_normal_route.yaml` file + its `playtest/_common.yaml` `scenario_order`
  line + its `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS` line (line 148) are owned
  and **deleted by sibling card `fix_route_timeline_anchors`** in this same wave (disjoint files).
  Follow-up: after that card lands, confirm those two registry lines are gone (else a smoke run
  reddens on a leftover registration of a deleted yaml). This card never edits `playtest/`.
- **D4 — count wording in the module docstring/dict comment ("six")** left as-is: comments are
  asserted nowhere, and touching them would widen the diff beyond the required lines.
- **D5 — no third-test guard needed.** No third pytest failure surfaced in anything measurable;
  the two named root causes are the entire scope.

## 5. 红线 verbatim (the two red lines, quoted)

`test_report.json` is a **pipeline artifact not committed to the repo tree** (search for
`**/test_report.json` → none in-tree), so the two red lines are quoted from the goal-loop fix
inputs (5_review + test_report), which carry them verbatim:

**Red 1 —** `tests/test_design_ledger_budget.py::test_moved_headings_absent_from_sources`
(line 143): fails because `design/90_decisions.md:48` carried the superseded heading
`## Open questions — 向所有者提问(非裁决)` **verbatim as a substring** of the section heading;
Pin D requires the source file free of a heading that was moved to `design/archive/decisions_2026-08.md`.

**Red 2 —** `tests/test_ending_gate_pins.py::test_ending_last_month_choice_load_bearing_lines_present`
(line 140): fails because `playtest/ending_last_month_choice.yaml` is **ABSENT** — deleted per the
2026-09-04 owner route-retirement ruling; the static door still asserted `path.exists()` plus the
load-bearing line `first_ending_evaluation != evaluation_text`.
(A **second** retired door, `test_huashan_winnable_normal_route_load_bearing_lines_present`, is
retired the same way by sibling card `fix_route_timeline_anchors` this wave — owner feedback round #6.)

## 6. diff excerpts

**6a — `design/90_decisions.md` (ONLY line 48):**
```diff
- ## Open questions — 向所有者提问(非裁决)
+ ## 提问 — 待所有者回答的未决问题(非裁决)
```
Lines 50 (`> 本节记录**问题**…`) and 52–56 (the 2026-09-04 huashan-route open question) are
**byte-identical** (confirmed in §2 re-read: 48 renamed, 50/52 unchanged). The question body on
line 52 legitimately still mentions `huashan_winnable_normal_route` in prose — the zero-hit grep
in acceptance-criterion-3 targets **only** `tests/test_ending_gate_pins.py`, not this file.

**6b — `tests/test_ending_gate_pins.py` carve-out texts (both comments):**
```python
    # CARVE-OUT (2026-09-04 owner route-retirement ruling): the month-36 last-month-choice
    # route scenario is retired — its playtest yaml was deleted (fixed-frame route-type
    # scenarios pin a click PATH, not a property; the evaluation-differential property
    # carries on the owner's side branch). Re-deriving a retired scenario is forbidden this
    # run, and restoring the ~1585-frame timeline is impossible without fabrication. The
    # load-bearing pin is removed here so the static door matches the retired scenario set
    # (conflict record: final/delivery_notes_fix_static_ledger_and_gate_pins.md).
```
```python
    # CARVE-OUT (2026-09-04 owner route-retirement ruling): the huashan winnable-normal-route
    # scenario is retired — a fixed-frame ~2200-frame click PATH (36 months + travel + duel)
    # that any upstream screen change breaks; it pins a route, not a property. The scenario
    # file and its playtest/_common.yaml scenario_order + test_playtest_contract_smoke.py
    # ROUND_SCENARIOS registry lines are deleted by the sibling card
    # fix_route_timeline_anchors this same wave (disjoint files); this card removes ONLY the
    # static load-bearing pin here so the door no longer requires the retired yaml. The
    # honest-LOST end-state property (health < max_health) carries on the owner's side branch.
```
Two matching dated carve-out notes were also placed in the module docstring where the retired
bullets used to be (lines 8–10 and 17–20). Surviving entries (byte-identity proof: they were
never inside any `old_str`) — `ending_divergent_playstyles` (`EndingScreen.diverged_from_first:
diverged_from_first == true`), `fortune_reroll_budget` (`rerolls_left == 0`, `events_seen_count
== 0`), `action_yield_differential` (`last_action_silver == 0`, `last_action_silver > 0`),
`huashan_readiness_warning` (`readiness_text != "华山评估：战备不足"`); `COMMON_SURFACES` (9 names),
`_scenario_text`, `_common_text`, `test_common_yaml_exists`,
`test_common_yaml_still_has_every_new_surface`, `test_red_first_evidence_notes_exist`,
`_make_scenario_test`, and the generation loop are all outside the four edited regions.

**6c — `scripts/autoload/i18n.gd` (one-line removal):**
```diff
-		"⚠ 再按一次确认拜入「%s」": "⚠ Press again to confirm joining \"%s\"",
```
Neighbour key at 514 (`⚠ 再按一次确认改投「%s」…`, a DIFFERENT string) stays; old 516 (`⚠ 再按一次确认删除存档`)
now directly follows 514 — valid GDScript (comma-separated dict entry removed whole).

## 7. Conflict record (mandatory — card deviates from one 5_review instruction)

The 5_review fix list asked to **restore/repair `playtest/ending_last_month_choice.yaml`** so
`test_ending_gate_pins.py` passes. **Restoration is not performed** because:
- (a) it is **forbidden** by the standing 2026-09-04 owner route-retirement ruling (route-type
  scenarios retired — they pin a click PATH, not a property; "this run must NOT re-derive retired
  scenarios"; the property carry-over lives on the owner's side branch); and
- (b) it is **mechanically impossible** without fabricating a ~1585-frame timeline — the file is
  deleted from the tree and there is no git-history access inside the harness. A fabricated/restored
  file would re-enter the official sweep red (the 5_compile summary shows the sibling
  `huashan_winnable_normal_route` route nail already failing 23/47 with 27 aim runtime errors —
  the exact pathology retirement was meant to stop).

Instead the static door is updated with an explicitly **dated, recorded carve-out** (not silent):
the playtest sweep count stays honest (the retired scenarios are gone by owner ruling).
**If the owner later rules that restoration supersedes retirement → STOP and report; do not
fabricate the timeline.** This is the 5_review's own option-(a) outcome, achieved without touching
the anti-weakening test body and without losing the fresh owner question.

## 8. Known gaps / follow-ups

- I could **not execute `python3 -m pytest`** (no shell in this step). The 5_test / review gate
  must run `python3 -m pytest tests/ -q` (expect 0 failed) and
  `python3 -m pytest tests/test_ending_gate_pins.py tests/test_i18n_coverage.py
  tests/test_design_ledger_budget.py -q` to close acceptance items 1/3/4 green-output evidence.
- Follow-up after sibling `fix_route_timeline_anchors` lands: verify
  `playtest/huashan_winnable_normal_route.yaml`, its `_common.yaml` `scenario_order` line, and its
  `test_playtest_contract_smoke.py` `ROUND_SCENARIOS` line (line 148) are all gone (decision D3).

## 9. 边界声明 (what was NOT touched)

`tests/test_design_ledger_budget.py` (byte-identical — the source heading is what moved);
`design/archive/*` (byte-untouched, proven in §2); every ruling-table row in `design/90_decisions.md`
and the open-question body; `README.md`; the three verbatim gates + `playtest/event_travel_effects.yaml`;
the six locked files; **any** `playtest/` scenario (owned by `fix_route_timeline_anchors` this wave);
any surviving test assertion (none weakened); no root `playtest_spec.yaml`. Only the four owned
paths were written.
