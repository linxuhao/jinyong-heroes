# Regression Run Notes — jinyong-spend-qi

Round: give the 8 player moves real inner-qi costs, wire casting to spend qi, and make
the `no_energy` HUD state reachable + pinned by a real-battle playtest scenario. This
document is the **evidence artifact** for the `regression_run` task: full run inventory,
baseline-vs-after for the cost-sensitive winnability gate, the shipped cost table, the
win-path budget, at-risk focus list status, and any cost-table revision.

Every green/red/count below cites its source — the **design baseline** (pre-round
records in `design/`), a **structural fact verified by direct read** at this step, or
**host gate feedback** (the `5_compile` / `5_test` / `5_vision` artifacts, which are
produced after this step). This evidence step has no godot binary and no shell, so no
full-gate measurement is possible here; anything not measured is explicitly marked
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

### 6.1 Gate results — all pending host gate run

No full-gate measurement is possible at this step: this evidence step has no godot binary,
no shell, and no `5_compile` / `5_test` / `5_vision` artifacts on disk. The authoritative
gate products are produced AFTER the verifier step and arrive only through the host gate
run's step feedback context; none was supplied in this step's context.

Therefore EVERY gate result below is `pending host gate run (5_compile / 5_test artifacts)`:

- Full playtest run of all **54 scenarios** (the 53 pre-existing + the new
  `qi_cost_blocks_cast_no_energy`) — `pending host gate run`.
- **`spine_to_ending` 32/32** (debug force-win; cost-insensitive) — `pending host gate run`.
- **`terminal_victory_8_12_rounds_hp_15_40`** — the cost-sensitive winnability gate —
  `pending host gate run`. If the host gate measures it RED, that is a **cost-table defect**
  per the fallback rule: revise the qi costs in `design/20_content.md` +
  `scripts/battlefield.gd` + `tests/test_qi_costs_match_design.gd` (never HP/damage/
  cooldowns/enemies — one lever this round), never silently accept a red.
- **GDScript unit suite 19/19** (`run_tests.sh` + `godot --headless ... unit_test_runner.gd`) —
  `pending host gate run`.
- **pytest smoke suite** incl. `test_qi_cost_surface_contract` and
  `test_round_scenarios_present_on_disk_and_in_order` (`python3 -m pytest tests/`) —
  `pending host gate run`.
- **Compile gate** (`/compile`) and **vision gate** (`5_vision` `vision_report.json`) —
  `pending host gate run`.

First-round all-pending is the correct honest state for an evidence step whose code was
delivered by sibling tasks; it is not a failure.

### 6.3 Baseline-vs-after for `terminal_victory_8_12_rounds_hp_15_40`

- **Baseline (pre-round, design records): green 6/6** (`design/99_changelog.md`
  jinyong-spend-qi row / `step2_design.md §2.2`). This is the only non-pending source for
  the baseline 6/6 — it is a design-archive record, not a this-step measurement.
- **After: `pending host gate run (5_compile / 5_test artifacts)`.** The measured "after"
  state is not available at this step; it will arrive with the host gate run's
  `playtest_summary.md` / `test_report.json`. This avoids misattributing any pre-existing
  red to the cost table (the yaml header's stale "red at ~78%" note is pre-jinyong-balance
  history; the design-recorded baseline is green 6/6).
- Conclusion: **deferred to the host gate run.** If it measures `terminal_victory` red,
  treat that as a cost-table defect and revise costs only (never HP/damage/cooldowns/
  enemies — see §7 / §9).

---

## 7. Cost revision (if any)

**No revision triggered from this step's evidence; the decision is deferred to the host
gate run.** The conditional `cost_revision_conditional` subtask is NOT exercised at this
step: there is no measured `terminal_victory_8_12_rounds_hp_15_40` gate result here (§6),
so neither a "revision" nor a "no revision needed" conclusion may be asserted as a
measured fact. The shipped three anchors (`design/20_content.md §7.1`,
`scripts/battlefield.gd`, `tests/test_qi_costs_match_design.gd` `DESIGN_COSTS`) are
byte-identical at 0/15/20/25/10/15/20/30 (verified by direct read, §4), `heavy_edge` stays
0 (pinned by `skill_button_effect_info.yaml`), all enemy/progression techniques stay 0,
and the design-recorded 12-cast spend is 170 ≤ 180 (§5).

When the host gate run supplies `terminal_victory` feedback:
- If **green** → no revision; the `cost_revision_conditional` subtask is a no-op.
- If **red** → revise qi costs only (never HP/damage/cooldowns/enemies), the three anchors
  byte-identical, `heavy_edge` stays 0, keep the 12-cast spend ≤ 180, and record the
  old→new values + rationale here in §7 with the re-submission noted in §6.

No old→new value table is provided yet because no measured result has triggered a revision.

---

## 8. At-risk focus list status

All 14 at-risk scenarios below are the Step-1/Step-2 focus list whose timelines interact
with the new qi costs. Their measured status is `pending host gate run (5_compile /
5_test artifacts)` — none is measured at this step (no godot binary / no shell / no gate
artifacts on disk). The design-recorded baseline for each is green (see
`design/99_changelog.md` and prior-round closure rows), but that is a design baseline, not
a this-step measurement.

| At-risk scenario | Status (this step) |
|------------------|--------------------|
| `terminal_victory_8_12_rounds_hp_15_40` | pending host gate run (design baseline green 6/6) |
| `central_divine_innate_qi_fatal_guard` | pending host gate run |
| `skill_rejection_reason_texts` | pending host gate run |
| `skill_button_effect_info` | pending host gate run |
| `fahui_du_multiplies_damage` | pending host gate run |
| `skill_button_visual_states` | pending host gate run |
| `skill_bar_waiting_state` | pending host gate run |
| `skill_button_turn_overlay` | pending host gate run |
| `two_phase_skill_unlock_and_hp_gate` | pending host gate run |
| `locked_slot_unlock_reason` | pending host gate run |
| `skill_hint_and_range_highlight` | pending host gate run |
| `skill_description_visible` | pending host gate run |
| `ui_geometry_readability` | pending host gate run |
| `spine_to_ending` | pending host gate run (design baseline 32/32, cost-insensitive) |

All other scenarios are likewise pending the full host gate run. No PASS count is claimed
for any scenario at this step.

---

## 9. Honesty note

Every claim in this document cites its source, and nothing is presented as measured that
was not:

- **Design baseline** (`design/20_content.md §5/§7`, `design/99_changelog.md`
  jinyong-spend-qi row, `step2_design.md §2.2`): the pre-round baseline green 6/6 for
  `terminal_victory`, the 32/32 `spine_to_ending` note (cost-insensitive), the 170/180
  win-path budget, and the shipped cost table. These are design-archive records, not
  this-step measurements.
- **Structural facts verified by direct read at this step** (§1/§4/§5): the 54-scenario /
  55-yaml inventory, the two-place sync (scenario_order + ROUND_SCENARIOS), the
  surface/actions whitelist (`energy_max`, `debug_spend_player_qi`), the cost assignments
  (0/15/20/25/10/15/20/30), and the 12-cast chain. These are facts, not gate verdicts.
- **Gate results**: every scenario / unit / smoke / compile / vision result is
  `pending host gate run (5_compile / 5_test artifacts)` (§6/§8). No PASS count for any
  scenario is claimed at this step, because no gate measurement is possible here (no godot
  binary, no shell, no gate artifacts on disk). None of these is reported as a pass.

The cost-revision decision is deferred to the host gate run's measured `terminal_victory`
feedback (§6/§7). No counts are fabricated. The design-archive closure (99_changelog /
40_ux_backlog / 30_presentation final amendment) is the `5_design` step's job, using the
host gate evidence; this task only produces the evidence and defers the revision decision
to that measured run.
