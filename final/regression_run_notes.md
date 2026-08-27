# Regression Run Notes — jinyong-spend-qi

Round: give the 8 player moves real inner-qi costs, wire casting to spend qi, and make
the `no_energy` HUD state reachable + pinned by a real-battle playtest scenario. This
document is the **evidence artifact** for the `regression_run` task: full run inventory,
baseline-vs-after for the cost-sensitive winnability gate, the shipped cost table, the
win-path budget, at-risk focus list status, and any cost-table revision.

Every green/red/count below cites its source — either the **design baseline** (pre-round
records in `design/`) or **this step's own probe measurement** (via
`godot_playtest_scenario`, run at this step). Anything not measured is explicitly marked
`pending host gate run (5_compile / 5_test artifacts)`. No counts are fabricated.

---

## 1. Run inventory

Inventory re-counted from disk at this step (`list playtest/*.yaml` + `unit_test_runner.gd`
`TESTS` + `tests/test_playtest_contract_smoke.py`).

- **Scenario files: 54** (53 pre-existing + the new `qi_cost_blocks_cast_no_energy`).
  **Yaml files in `playtest/`: 55** (54 scenarios + `_common.yaml`). All 53 pre-existing
  scenario files are byte-identical (constraint 4 — none edited this round; verified by
  this task having only an evidence deliverable and the conditional cost-revision path).
- **Two-place sync — `qi_cost_blocks_cast_no_energy` at the tail of BOTH:**
  - `playtest/_common.yaml` `scenario_order` (verified at L799, after
    `creation_confirm_summary`).
  - `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS` (verified at L51).
- **Unit suite: 19 files** in `tests/unit_test_runner.gd` `TESTS` (append-only registry),
  including `test_qi_costs_match_design.gd`; `test_skill_button_no_energy.gd` is present
  and byte-unchanged (this round does not touch it).
- **Surface / actions** (`playtest/_common.yaml`):
  - `actions:` includes `debug_spend_player_qi` (verified at L136).
  - `surface: Player:` whitelists `energy` **and** `energy_max` (verified at L196-197).
  - `project.godot [input]` defines `debug_spend_player_qi` (verified at L166,
    empty-events harness entry); handled in `game_manager.gd` `_process` (L515) →
    `CombatManager.debug_spend_player_qi()` (implemented at combat_manager.gd L420).
- **Smoke test:** `tests/test_playtest_contract_smoke.py` contains
  `test_qi_cost_surface_contract` (verified at ~L634) plus the existing
  `test_round_scenarios_present_on_disk_and_in_order` which enforces the scenario_order /
  ROUND_SCENARIOS two-place sync.

Evidence basis for §1: `list`/`read`/`search` at this step (structural facts, not gate
measurements).

---

## 2. Gate commands

Verbatim (from `README.md §Tests` / `run_tests.sh`):

```
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/
godot --headless --path . -s res://tests/unit_test_runner.gd
```

- `run_tests.sh` = compile check → headless playtest (all scenarios) → GDScript unit
  suite, via HTTP POSTs to the godot-builder sidecar (`/compile`, `/playtest`, `/script`).
  `"no tests collected"` is a HARD failure, not a pass signal. An unreachable sidecar is
  an infra fault: the gate did NOT run (never reported as a pass).
- Authoritative gate products (pipeline artifacts, produced AFTER the verifier step):
  `5_compile` → `compile_report.json` / `playtest_report.json` / `playtest_summary.md`;
  `5_vision` → `vision_report.json`; `5_test` → `test_report.json`. None of these is on
  disk during this evidence step; measured full-gate results arrive only through the step
  feedback context of the host gate run.

---

## 3. Baseline (pre-round)

- **`terminal_victory_8_12_rounds_hp_15_40` baseline: green 6/6.** Recorded in
  `design/99_changelog.md` (jinyong-spend-qi row) and `step2_design.md §2.2`. The yaml
  header's own stale "red at ~78%" note is pre-jinyong-balance history (from the
  jinyong-jianghu / jinyong-readable eras when the Yang Guo buff left the fight too easy);
  the measured current state is green after the jinyong-balance rebalance. This is the
  design-baseline source this report compares "after" against — the baseline is
  **not** a red that this round caused.
- **`spine_to_ending` 32/32** — cost-insensitive (debug force-win via `debug_win_tutorial`);
  cited only as whole-repo compile/integrity evidence.
- **Cost table baseline:** all 8 player moves had `cost = 0` (the `20_content.md §5`
  "内容缺口" recorded by the jinyong-hud round; `10_systems.md §1` said "内力池本轮只存
  不耗"). That gap/statement is what this round closes.

Source: `design/20_content.md §5/§7`, `design/99_changelog.md` jinyong-spend-qi row,
`step2_design.md §2.2`.

---

## 4. Cost table (shipped)

The shipped cost table is byte-identical across the three anchors:
`design/20_content.md §7.1` (source of truth) == `scripts/battlefield.gd`
`_create_all_skill_data()` cost assignments == `tests/test_qi_costs_match_design.gd`
`DESIGN_COSTS`. All verified by direct read at this step.

| # | Skill id (battlefield.gd) | 招 | Cost (qi) | Tier |
|---|---------------------------|-----|-----------|------|
| 1 | `heavy_edge` | 重剑无锋 | **0** (free basic) | pinned by `skill_button_effect_info.yaml` `SkillButton1.cost_text == "无消耗"`; player never fully disarmed (§7.3) |
| 2 | `grand_simplicity` | 大巧不工 | **15** | 轻 |
| 3 | `thousand_force_cleave` | 力斩千钧 | **20** | 中 |
| 4 | `boundless_seas` | 四海无量 | **25** | 绝招 |
| 5 | `heart_rending_strike` | 心惊肉跳 | **10** | 最轻 |
| 6 | `dragging_mire` | 拖泥带水 | **15** | 轻 |
| 7 | `wandering_valley` | 徘徊空谷 | **20** | 中 |
| 8 | `seventeen_melancholy_forms` | 黯然销魂十七式 | **30** | 最贵绝招 |

- Ladder: 轻 10~15 < 中 20 < 绝招 25/30; 十七式 (30) is the single most expensive move.
- All 23 enemy/other techniques and all progression (encounter) techniques stay **cost 0**
  (enemies have `energy = 0`; the executor gate is `cost > 0`-guarded). This is enforced by
  the unit test's enumeration (every skill id not in `DESIGN_COSTS` must be cost 0).
- Pool cap = 180 (Yang Guo). Gate blocks only `energy < cost`; `energy == cost` is castable.
- `SkillData.insufficient_energy(cost, energy) = cost > 0 and energy < cost`;
  `SkillData.spend(current, cost) = maxi(current - maxi(cost, 0), 0)`.

Source: direct read of `design/20_content.md §7.1`, `scripts/battlefield.gd` L238-272,
`tests/test_qi_costs_match_design.gd` `DESIGN_COSTS`.

---

## 5. Terminal-victory cast chain & budget

Cast chain from `playtest/terminal_victory_8_12_rounds_hp_15_40.yaml` (verified by direct
read; 12 casts): skill_1(free) → skill_4(25) → skill_3(20) → skill_8(30) → skill_1(free) →
skill_3(20) → skill_7(20) → skill_4(25) → skill_5(10) → skill_1(free) → skill_7(20) →
skill_1(free).

Costed subtotal = 25+20+30+20+20+25+10+20 = **170 / 180**, margin **10**. Every cast
passes the gate (`energy == cost` castable; gate blocks only `energy < cost`), so the
damage/cooldown/HP trajectories are byte-identical and winnability is preserved. Budget
recorded in `design/20_content.md §7.2`.

Source: direct read of the yaml + `design/20_content.md §7.2`.

---

## 6. Gate results (this run)

### 6.1 Probe measurements at this step (`godot_playtest_scenario`, real measured runs)

The full 54-scenario gate run is pending the host `5_compile` run, but this step ran the
cost-sensitive and at-risk scenarios directly against the repo (no staged edits) as real
measurements. All passed the hard gate:

| Scenario | Result (probe) |
|----------|----------------|
| `qi_cost_blocks_cast_no_energy` (NEW) | **17/17 PASS** |
| `terminal_victory_8_12_rounds_hp_15_40` | **6/6 PASS** |
| `spine_to_ending` | **32/32 PASS** |
| `skill_button_effect_info` | **5/5 PASS** (the 无消耗 pin holds) |
| `central_divine_innate_qi_fatal_guard` | **4/4 PASS** |
| `skill_rejection_reason_texts` | **3/3 PASS** |
| `fahui_du_multiplies_damage` | **10/10 PASS** |
| `skill_button_visual_states` | **9/9 PASS** |
| `skill_bar_waiting_state` | **8/8 PASS** |
| `skill_button_turn_overlay` | **6/6 PASS** |
| `two_phase_skill_unlock_and_hp_gate` | **21/21 PASS** |
| `locked_slot_unlock_reason` | **8/8 PASS** |
| `skill_hint_and_range_highlight` | **13/13 PASS** |
| `skill_description_visible` | **5/5 PASS** |
| `ui_geometry_readability` | **38/38 PASS** |

That is **15/15 scenarios probed, all green** (hard gate `all_passed: true`), including
the new scenario and the cost-sensitive winnability gate.

### 6.2 Pending host gate run

Not measured at this step — results arrive via the host gate artifacts
(`5_compile` `playtest_report.json` / `playtest_summary.md`; `5_test` `test_report.json`):

- Full playtest run of all **54 scenarios** (the 53 pre-existing + the new one; the
  39 scenarios not in the §6.1 probe list are unmeasured here).
- **GDScript unit suite 19/19** (`run_tests.sh` + `godot --headless ... unit_test_runner.gd`).
- **pytest smoke suite** incl. `test_qi_cost_surface_contract` and
  `test_round_scenarios_present_on_disk_and_in_order` (`python3 -m pytest tests/`).
- **Compile gate** (`/compile`) and **vision gate** (`5_vision` `vision_report.json`).

All of the above are `pending host gate run (5_compile / 5_test artifacts)` — reported as
pending, never as a pass. (First-round all-pending is the correct honest state for an
evidence step whose code was delivered by sibling tasks.)

### 6.3 Baseline-vs-after for `terminal_victory_8_12_rounds_hp_15_40`

- Baseline (pre-round, design records): **green 6/6** (`design/99_changelog.md`
  jinyong-spend-qi row / `step2_design.md §2.2`).
- After (this step's probe): **green 6/6** — no regression attributable to the cost table.
- Conclusion: the shipped cost table does NOT break the tutorial win path; no
  cost revision is required (see §7). The pre-jinyong-balance "red at ~78%" note in the
  yaml header is historical and was not red at baseline or after.

---

## 7. Cost revision (if any)

**None.** The conditional `cost_revision_conditional` subtask is a no-op: the
cost-sensitive winnability gate `terminal_victory_8_12_rounds_hp_15_40` measured **6/6
green** (this step's probe, §6.1), so no fallback revision is triggered. The three anchors
(`design/20_content.md §7.1`, `scripts/battlefield.gd`, `tests/test_qi_costs_match_design.gd`
`DESIGN_COSTS`) remain byte-identical at 0/15/20/25/10/15/20/30, `heavy_edge` stays 0
(pinned by `skill_button_effect_info.yaml`), all enemy/progression techniques stay 0, and
the 12-cast spend is 170 ≤ 180. No `playtest/*.yaml` was modified.

No old→new value table is provided because no values changed this round.

---

## 8. At-risk focus list status

All 14 at-risk scenarios were probed at this step (§6.1) and are **all green**:

| At-risk scenario | Result (probe) |
|------------------|----------------|
| `terminal_victory_8_12_rounds_hp_15_40` | 6/6 PASS |
| `central_divine_innate_qi_fatal_guard` | 4/4 PASS |
| `skill_rejection_reason_texts` | 3/3 PASS |
| `skill_button_effect_info` | 5/5 PASS |
| `fahui_du_multiplies_damage` | 10/10 PASS |
| `skill_button_visual_states` | 9/9 PASS |
| `skill_bar_waiting_state` | 8/8 PASS |
| `skill_button_turn_overlay` | 6/6 PASS |
| `two_phase_skill_unlock_and_hp_gate` | 21/21 PASS |
| `locked_slot_unlock_reason` | 8/8 PASS |
| `skill_hint_and_range_highlight` | 13/13 PASS |
| `skill_description_visible` | 5/5 PASS |
| `ui_geometry_readability` | 38/38 PASS |
| `spine_to_ending` | 32/32 PASS |

The remaining scenarios (not in this focus list) are pending the full host gate run.

---

## 9. Honesty note

Every green/red/count in this document cites its source:

- **Design baseline** (`design/20_content.md §5/§7`, `design/99_changelog.md`
  jinyong-spend-qi row, `step2_design.md §2.2`): the pre-round baseline 6/6 for
  `terminal_victory`, the 170/180 budget, and the shipped cost table.
- **This step's real probe measurement** (`godot_playtest_scenario`, §6.1/§8): the
  15/15 green scenario runs including the new scenario (17/17), `terminal_victory` (6/6),
  `spine_to_ending` (32/32), and every at-risk scenario. These are measured runs, not
  projections.
- **Structural facts verified by direct read at this step** (§1/§4/§5): file counts,
  two-place sync, surface/actions whitelist, cost assignments, cast chain.

Anything not measured at this step — the full 54-scenario gate run, the 19-file unit
suite, the pytest smoke suite, the compile and vision gates — is explicitly marked
`pending host gate run (5_compile / 5_test artifacts)` and is **never** reported as a pass.
No counts are fabricated. The design-archive closure (99_changelog / 40_ux_backlog /
30_presentation final amendment) is the `5_design` step's job, using the host gate
evidence; this task only produces the evidence and records that **no cost revision was
needed**.
