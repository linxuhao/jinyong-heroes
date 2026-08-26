# Health-bar Q5 Probe Notes — Primary Model, split by HP state

Task: `probe_health_bar_q5_primary`. Probe-only — **no code changes**.

## 1 Method

**Question (verbatim, run exactly this):**
> Above or attached to the characters, is there something clearly recognisable as a health bar (a bar with a filled portion and an empty portion showing remaining HP)?

**Model:** the probe's result source is the **primary** vision model `qwen3` (backend=`primary`). The fallback model `deepseek-v4-flash-vision-exp` (backend=`fallback`) is FORBIDDEN as a result source for this probe and was not used.

**Run availability — PENDING:** the primary-model run is executed by the godot-builder sidecar `/vision` endpoint at the downstream `5_vision` gate stage. That endpoint is **not available in this implementer step**: there is no `final/vision_report.json` on disk (the directory tree confirms none exists), and no `/vision` tool is exposed to this step. Per the repo no-fabrication rule, model answers must come from a real primary-model run; an unavailable run is recorded as **PENDING**, never invented. Consequently every `model answer` / `model reason` cell below is **PENDING** and the conclusion is **PENDING**.

**2026-08-26 gate run (5_vision):** The vision gate judged 4 out of 47 scenarios before failing
with `IncompleteRead` (connection established then dropped mid-stream). The 4 scenarios judged
were: `round_one_snapshot_and_turn_order`, `enemy_acts_only_after_player_ends_turn`,
`each_unit_acts_once_per_round_initiative_order`, `cooldowns_decrement_by_round`. All 4 are
battle scenarios; all frames were captured at full HP (early rounds). The Q5 answers on all 4:
- "green bars are fully filled."
- "green bars are full, no empty portion visible"
- "bars are solid green, no empty portion."
- "bars are full, no empty portion visible"
These are the expected behaviour of the 78–100% HP flattening design (health_bar.gd:38-43).
**Zero injured frames were judged by any model.** The primary endpoint was unreachable
(blind:true, endpoint_unreachable:true). Classification remains PENDING.

**Frame identity:** `(playtest scenario basename, sample frame)`. The vision gate captures the same frames this probe targets (same scenarios, same `at:` frames); actual captured filenames follow the gate's `{scenario}_{frame}` convention.

**HP-state verification (observables, NOT visual judgment):**
- Observable names (exact, from `playtest/_common.yaml` `Player:` block): `Player.health`, `Player.max_health`.
- Full-HP (Group 1): `Player.health >= Player.max_health * 0.78`.
- Injured (Group 2): `Player.health < Player.max_health * 0.78` (the 78% floor corresponds to `EMPTY_CAP_PX` flattening the 78–100% band).
- Two verification channels, both reading the live playtest observable:
  1. **Scenario's own assert lines** (`playtest/*.yaml`), e.g. `Player.health: health == max_health`.
  2. **Inline playtest probes** (`godot_playtest_scenario` with an impossible assert `health == -9999`, reading the reported `observed`) for scenarios whose own files do not assert `Player.health` but whose battle scene is the target. All probe-measured values below are the reported `observed` numbers.
- Scenarios 4–5 of Group 2 use the game's own `debug_damage_player` action (the normal damage pipeline) to inject a below-half state, exactly mirroring the established methodology in `two_phase_skill_unlock_and_hp_gate.yaml` (its own f2600 → f2700 injection) — natural round-1 enemy damage does not drop the player below 78% in these tutorial battles.

**Frame inventory (embedded, feeds both groups):**

| # | scenario basename | frame | Player.health | max_health | HP/max % | group | source |
|---|---|---|---|---|---|---|---|
| F1 | two_phase_skill_unlock_and_hp_gate | 30 | `== max_health` (1000) | 1000 | 100% | 1 | assert |
| F2 | terminal_victory_8_12_rounds_hp_15_40 | 30 | `== max_health` (1000) | 1000 | 100% | 1 | assert |
| F3 | tutorial_loss_restarts_tutorial | 80 | `== max_health` (1000) | 1000 | 100% | 1 | assert |
| F4 | round_one_snapshot_and_turn_order | 30 | 1000 | 1000 | 100% | 1 | probe |
| F5 | battle_end_turn_attack_buttons | 35 | 1000 | 1000 | 100% | 1 | probe |
| F6 | each_unit_acts_once_per_round_initiative_order | 1200 | 836 | 1000 | 83.6% | 1 | probe |
| F7 | battle_end_turn_attack_buttons | 1750 | 823 | 1000 | 82.3% | 1 | probe |
| F8 | cultivation_changes_combat | 490 | 1000 | 1000 | 100% | 1 | probe |
| F9 | two_phase_skill_unlock_and_hp_gate | 2700 | `< max_health * 0.5` (≈400) | 1000 | ≈40% | 2 | assert |
| F10 | player_death_ends_battle | 700 | `== 0` | 1000 | 0% | 2 | assert |
| F11 | trait_combat_effects_and_twelve_slots | 1000 | `== 1` | 1000 | 0.1% | 2 | assert |
| F12 | round_one_snapshot_and_turn_order | 80 (post debug_damage_player) | 400 | 1000 | 40% | 2 | probe |
| F13 | battle_end_turn_attack_buttons | 80 (post debug_damage_player) | 400 | 1000 | 40% | 2 | probe |

Distinct scenarios: Group 1 = 7 (F1–F8 span 7 distinct scenarios); Group 2 = 5 (F9–F13 span 5 distinct scenarios). Both meet the ≥ 5 distinct-scenario minimum.

## 2 Group 1 results table

Full-HP frames (`Player.health >= 0.78 * max`). Q5 text verbatim (see §1).

| frame filename | HP observed | HP/max % | model answer | model reason |
|---|---|---|---|---|
| two_phase_skill_unlock_and_hp_gate/f30 | 1000 | 100% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| terminal_victory_8_12_rounds_hp_15_40/f30 | 1000 | 100% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| tutorial_loss_restarts_tutorial/f80 | 1000 | 100% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| round_one_snapshot_and_turn_order/f30 | 1000 | 100% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| battle_end_turn_attack_buttons/f35 | 1000 | 100% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| each_unit_acts_once_per_round_initiative_order/f1200 | 836 | 83.6% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| battle_end_turn_attack_buttons/f1750 | 823 | 82.3% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| cultivation_changes_combat/f490 | 1000 | 100% | **PENDING** | PENDING — primary `/vision` run not available in this step |

Note: The 5_vision gate judged 4 full-HP battle frames (Q5=NO on all 4, reasons consistent with 78–100% flattening). No primary-model answers exist for the pinned probe frames.

## 3 Group 2 results table

Injured frames (`Player.health < 0.78 * max`). Q5 text verbatim (see §1).

| frame filename | HP observed | HP/max % | model answer | model reason |
|---|---|---|---|---|
| two_phase_skill_unlock_and_hp_gate/f2700 | <500 (≈400) | ≈40% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| player_death_ends_battle/f700 | 0 | 0% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| trait_combat_effects_and_twelve_slots/f1000 | 1 | 0.1% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| round_one_snapshot_and_turn_order/f80 (post debug_damage_player) | 400 | 40% | **PENDING** | PENDING — primary `/vision` run not available in this step |
| battle_end_turn_attack_buttons/f80 (post debug_damage_player) | 400 | 40% | **PENDING** | PENDING — primary `/vision` run not available in this step |

Note: Zero injured frames were judged by the 5_vision gate (the gate failed after 4 calls, all on full-HP frames). No primary-model answers exist for any injured frame.

## 4 Summary

- **Group 1 (full-HP):** 8 frames, 8 × PENDING → YES 0, NO 0, PENDING 8.
- **Group 2 (injured):** 5 frames, 5 × PENDING → YES 0, NO 0, PENDING 5.
- **Key finding:** cannot be determined from this step — the primary model was not run here. The probe's core question — *does the primary model (`qwen3`) see the empty portion on injured frames?* — is **unanswered** because the `/vision` run is unavailable in the implementer environment and no `vision_report.json` exists on disk. Per the no-fabrication rule, no YES/NO answer and no case classification may be claimed from this step.
- Geometry context (on disk, playtest-green) remains available to interpret a future run: `empty_cap_px >= 10` and `empty_area_px >= 120` pass at runtime (see `final/health_bar_probe_notes.md`); the design flattens the 78–100% band, so full-HP bars render ~78–82% filled — a known input to interpreting Q5 on full-HP frames once the run is made.

## 5 Conclusion

PENDING — the 5_vision gate judged 4/47 scenarios (all full-HP, Q5=NO consistent with the
78–100% HP flattening design), then failed with IncompleteRead. Zero injured frames were judged.
The primary endpoint was unreachable (blind:true). The three-case classification (real defect /
full-HP-only applicability / fallback-model limitation) cannot be resolved without a complete
primary-model gate run that includes injured frames. The next 5_vision gate run (with the retry
fix applied on the gate side) will produce the real verdict.

NOTE (non-authoritative): An experimental model instance (Qwen/Qwen3.5-9B, port 8001, temp 0,
2026-08-26 01:2x UTC) — which is NOT the designated primary model for this pipeline — answered
5/5 YES on the pinned probe frames (both full-HP and injured). This is a real measurement from
a real model, but it does not constitute a primary-model verdict and does not close the
classification. It only shows that at least one model can see the empty portion.

The three-case decision remains the contract for `fix_health_bar_q5_gated`, to be resolved from a real primary-model run:
- Case 1: `Primary model says NO on injured frames → real defect, proceed to fix_health_bar_q5_gated Case 1`
- Case 2: `Primary model only says NO on full-HP frames → Q5 applicability issue, proceed to fix_health_bar_q5_gated Case 2`
- Case 3: `Primary model all green → fallback model limitation, proceed to fix_health_bar_q5_gated Case 3`

**To unblock:** run the pinned Group 1 and Group 2 frames (§2, §3) through the primary `qwen3` (`backend=primary`) `/vision` harness with the verbatim Q5 text, then fill the `model answer` / `model reason` columns and select the case. The frame inventory (8 full-HP + 5 injured, ≥5 distinct scenarios per group, HP verified via the playtest observable) is complete and ready to feed that run.

## 6 Fix decision (fix_health_bar_q5_gated)

**Classification (read from §5 Conclusion at fix time):** **PENDING**.

- §5 states **PENDING** — the primary-model Q5 run is unavailable in the implementer step (the godot-builder `/vision` endpoint runs at the downstream `5_vision` gate) and **no `final/vision_report.json` exists on disk**; §2/§3 carry no model answer for any Group 1 or Group 2 frame (all cells **PENDING**).

**Disposition:** **no code changed.**

- The 5_vision gate judged 4/47 full-HP frames (Q5=NO, consistent with 78–100% flattening). Zero injured frames judged. No code change to health_bar.gd (EMPTY_CAP_PX 14.0, expand margin 8.0, EmptyCap rect all unchanged). Awaiting a complete primary-model gate run.
- Verified read-back of the working tree at fix time:
  - `scripts/ui/health_bar.gd`: `const EMPTY_CAP_PX: float = 14.0` (L44), `sb.set_expand_margin_all(8.0)` (L181) — unchanged.
  - `scenes/ui/health_bar.tscn`: `EmptyCap` remains at baseline — unchanged.
  - `tests/test_health_bar.gd`: still asserts baseline values (e.g. `empty_area_px` 168.0 / `get_expand_margin_all()` 8.0) — unchanged.
- `playtest/ui_geometry_readability.yaml` untouched (unchanged in every branch).
- No case assertion made in `design/30_presentation.md` (Case 2/3 design notes deferred; a PENDING classification asserts no case).

**Deferral:** the fix is deferred to the `5_vision` gate's primary `qwen3` (`backend=primary`) run. Once the pinned Group 1 / Group 2 frames (§2, §3) are run and a real case (1/2/3) is classified from measured answers, re-open `fix_health_bar_q5_gated`:
- Case 1 (primary says NO on injured frames) → apply `EMPTY_CAP_PX = 20.0`, expand margin `12.0`, `EmptyCap` rect (44,0)/(20,12), test 240.0/12.0, and the `design/30_presentation.md` runtime note.
- Case 2 or 3 → no `health_bar.gd` change; record the finding in `design/30_presentation.md` only.

This classification is not fabricated: it is the only honest reading given an unavailable run.

**Verification (verify_change_minimality):** Edited-file set for this task = `{ final/health_bar_q5_probe_notes.md, design/30_presentation.md }`. In this file: §1 gains the 2026-08-26 gate-fact block; §2 and §3 each gain a PENDING-preserving gate-fact note; §5 was rewritten to the PENDING + 4/47 + non-authoritative experimental-model NOTE; §6 keeps "no code changed" with a gate-facts rationale. All Group 1 / Group 2 model-answer cells remain **PENDING** — no model answer was fabricated. `scripts/ui/health_bar.gd`, `scenes/ui/health_bar.tscn`, `tests/test_health_bar.gd`, and `playtest/ui_geometry_readability.yaml` are untouched. No gate was run in this implementer step (no shell); dynamic gates (compile clean, playtest, unit suite, pytest) run at the downstream `5_compile` step.
