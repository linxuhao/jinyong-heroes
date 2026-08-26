# Battle-HUD Info Probe Notes — pre-fix structural red + post-fix surface present + label-rect disjointness (UX-03/04/05)

**Task:** `docs_closure` (jinyong-hud round, 2026-08-26). Probe-only — **no code changes
here**. The round's code (skill-button info layer, lock-reason derivation, health-bar HP
number) is landed by sibling tasks (`skill_button_*`, `hud_*`, `health_bar_*`,
`contract_wiring`, `unit_tests_info`); this file records the **pre-fix structural read**,
the **post-fix surface-present read**, and a **geometric label-rect disjointness probe**
for `CostLabel` / `InfoLabel` / `FahuiLabel` in `scenes/ui/skill_button.tscn`.

Per the repo's honest-measurement rule: **no gate number is claimed that was not run.**
No `compile_report.json` / `playtest_report.json` / `playtest_summary.md` /
`vision_report.json` / `test_report.json` exists on disk at write time, so every gate
count below is marked **UNVERIFIED** with its target stated. The label-rect probe is a
**geometric read of authored rects** (the numbers the `.tscn`/design specify), framed as
**projected, not measured rendered ink** — the playtest scenarios are what measure the
live variables at runtime.

---

## 1. Pre-fix structural read — A-class red by structure (no measured gate required)

Before this round the battle HUD's surface (the playtest-whitelisted observable set in
`playtest/_common.yaml`) exposed **no** cost / effect / lock-reason / HP-number
observables. This is an **A-class red by structural read**: the four `SkillButton`
observables and the three `HealthBar` observables are **additive this round** (they did
not exist before), so no playtest assertion could possibly pin their visibility.

| Observable (additive this round) | Pre-fix (structural) | Where it lives now |
|---|---|---|
| `SkillButton1..12.cost_text` | **absent** (no such var on the surface) | surface-whitelisted; written by `skill_button.setup()` from `SkillData.cost` |
| `SkillButton1..12.effect_text` | **absent** | surface-whitelisted; = `skill.description` (Chinese) |
| `SkillButton1..12.effect_summary_text` | **absent** | surface-whitelisted; short on-face summary from existing `SkillData` numbers |
| `SkillButton1..12.lock_reason_text` | **absent** | surface-whitelisted; written per-frame by `hud.gd` from the tutorial phase-lock predicate |
| `HealthBar.hp_text` | **absent** | surface-whitelisted; `cur/max` written in `setup()`/`update_health()` |
| `HealthBar.hp_value` / `HealthBar.hp_max` | **absent** | surface-whitelisted; numeric mirrors for `max_health`-relative asserts |

The three UX items are exactly these three information gaps:

- **UX-03** — skill button shows only name + 「发挥 ×1.3」, no effect description, no
  inner-force cost → `cost_text` / `effect_text` / `effect_summary_text` absent.
- **UX-04** — slots 5–8 show only 「锁定」, no lock reason or unlock condition →
  `lock_reason_text` absent.
- **UX-05** — health bar shows no number → `hp_text` / `hp_value` / `hp_max` absent.

This is A-class in the same sense as the jinyong-events round's `events_seen_count`
("absent before this round"): the red is the **absence of the observables on the
surface**, provable by reading the pre-round `_common.yaml` — no runtime gate required.
(B-class guards — the existing `state_text` / `state_tag_text` / `state_luma` /
`fahui_text` asserts on the 46 pre-existing scenarios — stay green because, with current
data, every new derivation takes the empty/false branch: all costs 0 → `no_energy`
never fires; `lock_reason_text` is non-empty only on the already-locked slots 5–8
pre-round-4; `waiting` override unchanged.)

---

## 2. Post-fix surface-present read

The four `SkillButton` vars are now whitelisted on every `SkillButton1`..`SkillButton12`
block, and the three `HealthBar` vars on the `HealthBar` block, of
`playtest/_common.yaml`; the three new scenarios are registered at the end of
`scenario_order` **and** in `ROUND_SCENARIOS` (same order — the two-place sync rule):

| UX | Scenario evidence path | Observable pinned |
|---|---|---|
| UX-03 | `playtest/skill_button_effect_info.yaml` | `effect_text != ""`, `cost_text == "无消耗"`, `effect_summary_text != ""`, `fahui_text == "发挥 ×1.3"` (regression) |
| UX-04 | `playtest/locked_slot_unlock_reason.yaml` | `lock_reason_text != ""` on slots 5–8 (round < 4), `== ""` on unlocked slots, flips to `""` at round 4 |
| UX-05 | `playtest/health_bar_numbers.yaml` | `hp_text != ""`, `hp_text == str(hp_max)+"/"+str(hp_max)`, `hp_value == hp_max`, `hp_value < hp_max*0.5` post `debug_damage_player` — all relative to `max_health`, zero absolute HP literals |

**Gate status (honest): UNVERIFIED.** The three scenario files exist on disk and their
`name:` == basename, `at:` are single integers, and every assert line carries a
comparison operator (verified by static read + the `tests/test_playtest_contract_smoke.py`
contract pin). Their **green pass is a gate artifact** (`playtest_summary.md`) that does
not exist at write time — no count is invented.

---

## 3. Label-rect disjointness probe (CostLabel / InfoLabel / FahuiLabel) — projected

The skill button is **104×48** with four pre-existing live labels (HotkeyLabel /
FahuiLabel / StateTag / CooldownLabel) plus a hidden overlay. The two new labels must
not overlap those or push text out (no-ellipsis rule: `clip_text=false`,
`text_overrun_behavior=0` everywhere; a too-long string paints over the neighbour, per
`skill_button.gd` setup() comment). This probe reads the **authored rects** specified in
`scenes/ui/skill_button.tscn` (per `step2_design.md §2.4`) — it is a **geometric
read, projected not rendered ink**; the runtime playtest asserts the `text` observables,
the vision gate reads the rendered frame.

| Node | rect (x1,y1)-(x2,y2) | width | note |
|---|---|---|---|
| HotkeyLabel (existing) | (2,2)-(24,14) | 22 | top-left key hint |
| `CostLabel` (NEW) | (26,2)-(62,14) | 36 | top band between HotkeyLabel (ends x=24) and StateTag text (~starts x=72); 36 < 48 gap |
| StateTag text (existing) | ~(72,..) | — | no overlap: CostLabel right edge 62 < 72 |
| CooldownLabel (existing) | — | — | separate band, unchanged |
| `FahuiLabel` (existing, rect narrowed only) | (0,34)-(56,46) | 56 | 「发挥 ×1.3」 ≈ 50 px fits 56 px; right edge 56 |
| `InfoLabel` (NEW) | (56,34)-(102,46) | 46 | bottom-right; left edge 56 = FahuiLabel right edge → adjacent, not overlapping; right edge 102 < 104 |
| Button | (0,0)-(104,48) | 104 | all labels inside |

**Pairwise disjointness (projected):**

- `CostLabel` vs `HotkeyLabel`: CostLabel x ∈ [26,62], HotkeyLabel x ∈ [2,24] → disjoint (gap 26−24 = 2).
- `CostLabel` vs `StateTag`: 62 < ~72 → disjoint.
- `FahuiLabel` vs `InfoLabel`: FahuiLabel x ∈ [0,56], InfoLabel x ∈ [56,102] → adjacent at x=56, no overlap; same y-band [34,46].
- All four live labels within the 104 px button (right edge ≤ 102).

**Fallback discipline:** if a runtime frame probe shows ink overlap, the fix order is to
**shorten the summary** (effect_summary cap ≤ 6 CJK chars) or **drop InfoLabel font to
8** — never widen a label into a pinned sibling's rect, never use an ellipsis. The only
existing-child rect touched is `FahuiLabel`'s (narrowed 0..104 → 0..56), which nothing
pins (the pinned geometry is the Button size and `skill8_right_edge`; the no-ellipsis
asserts read the `text` vars, not label rects).

---

## 4. Honest limits

- **No gate was run in this task.** Compile, playtest (incl. the three new scenarios),
  vision and unit gates all run at downstream `5_compile` / `5_vision` steps; their
  counts are **UNVERIFIED** at write time.
- The label-rect probe is **authored-rect geometry, projected** — not measured rendered
  ink. Only the playtest `text`-observable asserts and the vision gate can confirm the
  actual on-frame rendering.
- The `no_energy` insufficient-inner-force state is real, palette-distinct and
  unit-tested, but **cannot fire with current data** (all costs 0, pool 180) — it is
  deferred until a round defines real inner-force costs (see `design/20_content.md §5`).
