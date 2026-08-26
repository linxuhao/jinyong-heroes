# Delivery notes — jinyong-hud (battle HUD "说人话": skill-button info + lock reasons + health numbers)

Round: **jinyong-hud**, 2026-08-26. This file is the round's closing record. The
round is **presentation-only**: no combat rule change, no value change, no art
asset, no geometry-constant edit to `health_bar.gd` / `health_bar.tscn` /
`tests/test_health_bar.gd`. The round's code was landed by sibling tasks
(`skill_button_*`, `hud_*`, `health_bar_*`, `contract_wiring`, `unit_tests_info`);
this task (`docs_closure`) records docs, evidence and the honest-OPEN backlog state.

## 1. Round summary

Three UX items, all **information missing** (roadmap stage 2 — the player can read it):

1. **UX-03 — skill button shows only name + 「发挥 ×1.3」, no effect description, no
   inner-force cost.** Added `cost_text` (renders 「无消耗」 with current data — see
   §5), `effect_text` (= the skill's Chinese description, surfaced on-face and as the
   tooltip) and `effect_summary_text` (short on-face summary derived only from
   existing `SkillData` numbers). New `no_energy` insufficient-inner-force button
   state (palette entry luma 0.6629, ≥ 0.10 from `phase_locked`'s 0.5306 and every
   other state; Chinese tag 「内力不足」) — visually distinct from 锁定 by
   construction, but **cannot fire with current data** (all costs 0, pool 180).
2. **UX-04 — locked slots 5–8 show only 「锁定」, no lock reason / unlock condition.**
   Added `lock_reason_text`, derived per-frame by the HUD from the **same** tutorial
   phase-lock predicate (`tutorial_battle and i >= 4 and current_round < 4`):
   「第 4 轮解锁」 while locked, `""` otherwise (encounter battles and rounds ≥ 4
   render nothing — never a hardcoded always-on string).
3. **UX-05 — health bar shows no number.** Added `HpLabel` (child of `Bar`, full-rect
   anchors, centered, font 9, `mouse_filter=2`) rendering `cur/max`, with observables
   `hp_text` / `hp_value` / `hp_max` written in `setup()` and `update_health()`.
   **No geometry constant in `health_bar.gd` / `health_bar.tscn` /
   `test_health_bar.gd` is touched** — the 68×24 widget, Bar 64×12 @(2,12),
   `EMPTY_CAP_PX`, expand margins and `STRIP_BOTTOM` stay byte-identical.

Scenarios: **47 → 50** (new `skill_button_effect_info.yaml`,
`locked_slot_unlock_reason.yaml`, `health_bar_numbers.yaml`, registered at the end of
`scenario_order` and `ROUND_SCENARIOS` in the same order — two-place sync).

## 2. A/B classification

### A-class (red before fix — by structural read, no measured gate required)

| Observable | A/B | Pre-fix (structural) | Evidence |
|---|---|---|---|
| `SkillButton1..12.cost_text` / `effect_text` / `effect_summary_text` / `lock_reason_text` | **A** | **absent** from the surface (no such vars before this round) | `final/hud_info_probe_notes.md` §1; `playtest/_common.yaml` |
| `HealthBar.hp_text` / `hp_value` / `hp_max` | **A** | **absent** from the surface | `final/hud_info_probe_notes.md` §1; `playtest/_common.yaml` |

The A-class red is the **absence of the observables on the surface** — no playtest
assertion could pin their visibility before this round. No absolute-HP literal
anywhere: health asserts are expressed via `hp_max` (e.g. `hp_value == hp_max`,
`hp_value < hp_max * 0.5`).

### B-class (regression guard — green before and after)

| Observable | A/B | Value |
|---|---|---|
| existing `state_text` / `state_tag_text` / `state_luma` / `fahui_text` / `cooldown_label_text` asserts on the 46 pre-existing scenarios | **B** | stay byte-identical — with current data every new derivation takes the empty/false branch (all costs 0 → `no_energy` never fires; `lock_reason_text` non-empty only on slots 5–8 pre-round-4; `waiting` override unchanged) |
| `SkillButton1.fahui_text == "发挥 ×1.3"` | **B** | regression-pinned in `skill_button_effect_info.yaml` (the narrowed `FahuiLabel` rect still renders the same text) |
| frozen health-bar geometry pins (`size==(68,24)`, `bar_width==64`, `bar_height==12`, `empty_area_px`, `empty_cap_px`, expand margin) | **B** | re-pinned additive in `tests/test_health_bar_text.gd` (new file — proves the additive label changed no constant) |
| `spine_to_ending` | **B** | target fully green (target below) |

## 3. Gate results

**Honest state at write time (2026-08-26): none of the gate-report artifacts
(`compile_report.json` / `playtest_report.json` / `playtest_summary.md` /
`vision_report.json` / `test_report.json`) is on disk.** The pipeline's gate steps
run after this task stage. Per the repo's no-fabrication rule every gate count below
is marked **UNVERIFIED** with its target stated; no count is invented.

| Gate | Target | Status at write time |
|---|---|---|
| Compile (`/compile`) | 0 errors across the whole repo | **UNVERIFIED** — no `compile_report.json` on disk |
| Playtest (`/playtest`) | **50 scenarios, spine_to_ending fully green**; existing suites not red; only `terminal_victory_8_12_rounds_hp_15_40` may stay red (sanctioned balance deferral) | **UNVERIFIED** — no `playtest_report.json` / `playtest_summary.md` on disk |
| Vision (`/vision`) | 6/6 questions pass on native 960×704 frames | **UNVERIFIED** — no `vision_report.json` on disk |
| Unit tests (`/test`) | GDScript suite pass (existing 12 + new `test_skill_button_info.gd` / `test_health_bar_text.gd`) | **UNVERIFIED** — no `test_report.json` on disk |

On-disk (non-gate) facts verified directly this round: the three new scenario files
exist with `name:` == basename, single-integer `at:` values, and every assert line
carries a comparison operator; the four `SkillButton` vars are whitelisted on all
`SkillButton1..12` blocks and the three `HealthBar` vars on the `HealthBar` block of
`playtest/_common.yaml`; the three names are appended to `scenario_order` **and**
`ROUND_SCENARIOS` in the same order (50 scenario files on disk).

## 4. Probe evidence (measured / projected)

- **Pre-fix structural read (A-class):** the battle-HUD surface exposed no
  cost/effect/lock-reason/HP-number observables before this round — recorded in
  `final/hud_info_probe_notes.md` §1.
- **Post-fix surface-present read:** the four `SkillButton` vars + three `HealthBar`
  vars are whitelisted and pinned by the three new scenarios —
  `final/hud_info_probe_notes.md` §2.
- **Label-rect disjointness probe (projected, not rendered ink):** `CostLabel`
  (26,2)-(62,14) sits between HotkeyLabel (ends x=24) and StateTag (~starts x=72);
  `InfoLabel` (56,34)-(102,46) is adjacent to the narrowed `FahuiLabel`
  (0,34)-(56,46) at x=56, all within the 104 px button. `final/hud_info_probe_notes.md`
  §3 frames this as authored-rect geometry; the runtime playtest asserts the `text`
  observables, the vision gate reads the rendered frame.

## 5. Content-gap note (named explicitly)

**The inner-force costs do not exist anywhere in the game.** `design/10_systems.md §1`
states verbatim: 「内力池本轮只存不耗。」…「招式**不消耗内力**——`20_content.md`
里没有一招标了消耗。」 No technique in the tutorial battle (or progression data)
defines an inner-force cost. Therefore:

- `SkillData.cost` was added as a **schema-only** field defaulting to **0** (= "cost
  undefined"); `battlefield.gd` `_skill()` call sites were **not** modified (no number
  invented in place).
- With current data (all costs 0) `cost_text` renders **「无消耗」** — the only honest
  value.
- The per-skill inner-force costs are a **CONTENT GAP** for the 养成 round, recorded in
  the new `design/20_content.md §5 「内力消耗缺口」` (the 8 player techniques — 玄铁剑法
  重剑无锋/大巧不工/力斩千钧/绝招·四海无量 + 黯然销魂掌 心惊肉跳/拖泥带水/徘徊空谷/绝招·黯然销魂十七式 —
  all listed as cost undefined (0)). The `no_energy` button state is deferred until a
  round defines real costs so it can actually fire and be tested.

## 6. UX disposition

Recorded in `design/40_ux_backlog.md` per the **conditional-OPEN logic** (backlog rule
2: CLOSED needs an action **+ evidence path**, and evidence means a **gate result** —
which runs after this task):

- **UX-03 / UX-04 / UX-05 — fix landed, still OPEN with the note 「修复已落,post-fix
  闸门证据待验」.** The fix is on disk (observables + scenarios + probe notes), but the
  post-fix green pass is a gate artifact (`playtest_summary.md`) that does not exist at
  write time. **`CLOSED(jinyong-hud)` is NOT written here** — the evidence-driven CLOSED
  transition is single-writer owned by the post-gate `backlog_closure` task, which reads
  the measured report after `regression_run`. An honest OPEN beats an evidence-less
  CLOSED (the UX-01b precedent). UX-06 / UX-07 / UX-08 remain OPEN and untouched.

## 7. Evidence chain

| Artifact | Role |
|---|---|
| `final/hud_info_probe_notes.md` | pre-fix structural A-class red + post-fix surface-present read + CostLabel/InfoLabel/FahuiLabel rect-disjointness probe (projected) |
| `playtest/skill_button_effect_info.yaml` | UX-03 — `effect_text != ""`, `cost_text == "无消耗"`, `effect_summary_text != ""`, `fahui_text == "发挥 ×1.3"` |
| `playtest/locked_slot_unlock_reason.yaml` | UX-04 — `lock_reason_text != ""` on slots 5–8, `== ""` on unlocked, flips at round 4 |
| `playtest/health_bar_numbers.yaml` | UX-05 — `hp_text != ""`, `== str(hp_max)+"/"+str(hp_max)`, `hp_value < hp_max*0.5` post-injection (max_health-relative) |
| `playtest/_common.yaml` | surface (+4 vars × SkillButton1..12, +3 vars HealthBar) + `scenario_order` tail (47 → 50) |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` + `test_hud_info_surface_contract` (contract pin) |
| `tests/test_skill_button_info.gd`, `tests/test_health_bar_text.gd` | new additive unit tests (palette separation, formatters, frozen-geometry regression pin) |
| `design/20_content.md §5` | 「内力消耗缺口」 content-gap record (quotes §1 verbatim, 8 techniques listed cost undefined (0), no_energy deferral) |
| `design/30_presentation.md` | appended skill-button info-line rows + HP-number-on-bar row (geometry constants untouched) |
| `design/99_changelog.md` | this round's row appended (2026-08-26) |
| `design/40_ux_backlog.md` | UX-03/04/05 keep OPEN + 「修复已落,post-fix 闸门证据待验」; dated 记录 line; **no `CLOSED(jinyong-hud)`** |

**Gate gap (honest):** no `compile_report.json` / `playtest_report.json` /
`playtest_summary.md` / `vision_report.json` / `test_report.json` exists on disk at
this delivery; all gate counts in §3 are marked UNVERIFIED with targets and are to be
confirmed by the pipeline's downstream gates. No gate count is invented.

