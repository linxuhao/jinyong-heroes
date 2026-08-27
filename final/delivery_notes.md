# Delivery notes — jinyong-clarity (character-creation "说人话": attribute effects + current HP + confirm summary)

Round: **jinyong-clarity**, 2026-08-27. This file is the round's closing record. The
round is **presentation-only**: no game-rule change, no numeric-value change, no art
asset, and no edit to any frozen creation-page geometry constant. The round's code was
landed by sibling tasks (`creation_info_labels`, `creation_clarity_scenarios`,
`verify_report_tombstone`); this task (`backlog_record`) records docs, evidence and the
honest-OPEN backlog state. Scenarios went **50 → 53** (`creation_attr_effect_info` /
`creation_hp_value_displayed` / `creation_confirm_summary`, appended to `scenario_order`
and `ROUND_SCENARIOS` in the same order — two-place sync).

## 1. Round summary

Three UX items, all **information missing** (roadmap stage 2 — the player can read it):

1. **UX-06 — ATTRS rows 内力 / 身法 / 悟性 / 福缘 show only name+value, no effect
   explanation.** The existing `AttrDescLabel` desc slot was **re-purposed from
   "focused attribute's desc" to an at-rest all-five effects list**:
   `attr_effects_text()` joins `_attr_label(key) + ":" + _attr_desc(key)` for the five
   `PlayerProfile.ATTR_KEYS` with `" · "`. Every segment is **verbatim from the
   existing `_ATTR_DESCS`** (`design/10_systems.md §1` meanings + `design/40_progression.md
   §7` formulas) — zero invented wording. `attr_index` still drives the row focus
   highlight and the `+ / -` target; only the desc channel's content semantics changed.
   The at-rest default focus (`bone`) still contains 「气血 = 根骨 × 5」, so the
   existing `creation_traits_back_next_buttons` assert `AttrDescLabel.text.contains("气血")`
   stays green.
2. **UX-07 — ATTRS page shows the formula 「气血 = 根骨 × 5」 but not the current HP.**
   New additive `HpValueLabel` (Label, ATTRS-gated, `mouse_filter=2`) directly below
   `AttrDescLabel`, rendered `text = "当前气血 %d"`. New observables
   `CreationScreen.hp_value` (= `hp_from_bone(attrs["bone"])` = `attrs["bone"] * 5`, the
   `design/40_progression.md §7` formula) and `hp_text` (= the exact rendered format).
   Every numeric assert is **relative** to the live `attrs` dict (`hp_value ==
   attrs["bone"] * 5`), zero absolute HP literals — the health_bar_numbers discipline.
3. **UX-08 — CONFIRM page shows only 剩余点数 + two buttons, no final attribute
   values.** New additive `ConfirmSummaryLabel` as the **first child** of `ConfirmBox`,
   one `名 值` line per attribute (`confirm_summary_text_from(attrs)`, five lines joined
   with `\n`), above 确认踏上江湖, CONFIRM-gated. Observable
   `CreationScreen.confirm_summary_text` pinned per-attribute with relative asserts
   (`contains("根骨 " + str(attrs["bone"]))`). The `points_attrs_gap_ok` CONFIRM-phase
   first-row ink cluster was re-pointed from `ConfirmButton.get_global_rect()` to
   `ConfirmSummaryLabel.get_global_rect()` — **same observable name, same yaml assert
   lines**, a measured-quantity change per the jinyong-layout-r2 precedent, with the
   existing `ConfirmButton` fallback retained.

`playtest/_common.yaml` surface additions: `CreationScreen` gains `hp_value` /
`hp_text` / `confirm_summary_text`; new node blocks `HpValueLabel` (`visible`, `text`)
and `ConfirmSummaryLabel` (`visible`, `text`). Frozen creation geometry
(`AttrRow0..4` 44px, `AttrDescLabel` 48px min, `MouseBox` 560×480, `AttrBox` sep 10,
`ConfirmBox` sep 12, `ConfirmButton` 240×44 / `BackButton` 160×44) is **byte-untouched**.

## 2. A/B classification

### A-class (red before fix — by structural read, no measured gate required)

| Observable | A/B | Pre-fix (structural) | Evidence |
|---|---|---|---|
| `MouseBox/AttrBox/HpValueLabel` node | **A** | **absent** from the scene tree (`creation.tscn` full-file search 0 matches) | `final/creation_info_probe_notes.md` §1 |
| `MouseBox/ConfirmBox/ConfirmSummaryLabel` node | **A** | **absent** from the scene tree (ConfirmBox children were only ConfirmButton + BackButton) | `final/creation_info_probe_notes.md` §2 |
| `CreationScreen.hp_value` / `hp_text` / `confirm_summary_text` | **A** | **absent** from `creation.gd` and the `CreationScreen:` surface block (whole-file search 0 matches) | `final/creation_info_probe_notes.md` §3 |
| `AttrDescLabel` at-rest content | **A** | shows **only the focused attribute's desc** (`_attr_desc("bone")` = 「气血 = 根骨 × 5」); the other four effects never appear at rest | `final/creation_info_probe_notes.md` §4 |
| `points_attrs_gap_ok` CONFIRM cluster | **A** | resolves `MouseBox/ConfirmBox/ConfirmButton.get_global_rect()` (pre-re-point) | `final/creation_info_probe_notes.md` §5 |

The A-class red is the **absence of the new information on the creation surface** — no
playtest assertion could pin the current HP / per-attribute effects / confirm summary
before this round. All new numeric asserts are **relative** expressions
(`hp_value == attrs["bone"] * 5`, `contains("根骨 " + str(attrs["bone"]))`).

### B-class (regression guard — green before and after)

| Observable | A/B | Value |
|---|---|---|
| the seven existing creation/menu scenarios (`creation_single_ui`, `creation_layout_readability`, `creation_mouse_interaction`, `creation_traits_back_next_buttons`, `creation_budget_clamp_and_traits`, `creation_back_to_menu_walk`, `menu_to_creation_to_tutorial_order`) | **B** | byte-untouched yamls, target fully green |
| `spine_to_ending` | **B** | target fully green |
| frozen creation geometry pins (`attr_rows_uniform`, `attr_label_alignment_ok`, `attr_cluster_center_ok`, `attr_cluster_width_ok`, `nav_cluster_center_ok`, `trait_cluster_center_ok`, `desc_center_ok`, `desc_alignment_ok`, `phase_skeleton_same`, `creation_in_viewport`, `creation_box_fits`, `points_attrs_gap_ok`) | **B** | re-pointed CONFIRM cluster keeps the same observable + same yaml assert lines; no geometry constant edited |
| `cursor_markers_visible == false` | **B** | all new text is plain Chinese, no `▶` glyph |

## 3. Gate results

**No gate was run by this task.** This task has no shell; the gates (`5_compile` /
`5_test` / `5_vision`) run after the implementation tasks land. Every gate cell below
is recorded as **pending / not measured** — nothing is claimed or invented. The only
gate evidence that counts is the pipeline's step products
(`5_compile` `compile_report.json` / `playtest_report.json` / `playtest_summary.md`,
`5_test` `test_report.json`, `5_vision` `vision_report.json`).

| Gate | Result |
|---|---|
| Compile (`5_compile` `compile_report.json`) | **pending** (not measured by this task) |
| Unit tests (`5_test` `test_report.json`) | **pending** (not measured by this task) |
| Playtest (`5_compile` `playtest_summary.md`) | **pending** — `playtest_summary.md` is not on disk at write time; per-scenario counts for `creation_attr_effect_info` / `creation_hp_value_displayed` / `creation_confirm_summary` will be cited here only when that report exists and is read |
| Vision (`5_vision` `vision_report.json`) | **pending** (not measured by this task) |

The repo's `final/verify_report.json` is **not** cited as evidence: it has been
replaced by a tombstone pointer note (see `design/90_decisions.md` and
`design/99_changelog.md`) stating it does **not** represent current delivery and that
the authoritative gate evidence is the pipeline step products.

## 4. Probe evidence

The pre-fix **A-class baseline** comes from `final/creation_info_probe_notes.md`
(structural read of code + scene + surface, not a runtime run): `HpValueLabel` and
`ConfirmSummaryLabel` nodes absent, the three observables absent from the
`CreationScreen` block, `AttrDescLabel` showing only the focused attribute's desc at
rest, and the pre-fix `points_attrs_gap_ok` CONFIRM cluster resolving `ConfirmButton`.
That file is the honest absent-before record the post-fix delivery consumes. No gate
was run by the probe task either (per hud_info_probe_notes.md §1 discipline).

## 5. Content-gap note (named explicitly)

**No content gap.** All five attribute effects have existing, in-repo definitions in
`_ATTR_DESCS` (`scripts/segments/creation.gd` L16–22), themselves verbatim from
`design/10_systems.md §1` meanings + `design/40_progression.md §7` formulas:

| key | label | `_ATTR_DESCS` (verbatim) |
|---|---|---|
| `bone` | 根骨 | 气血 = 根骨 × 5 |
| `inner` | 内力 | 内力值 = 内力 × 2 |
| `agility` | 身法 | 移动力 = 2 + 身法 ÷ 20(向下取整);先攻 = 身法 |
| `wisdom` | 悟性 | 决定学功法的速度(修习查表) |
| `fortune` | 福缘 | 影响事件与奇遇(游历事件可重掷) |

悟性 and 福缘 have `—` in the battle-derived column of `10_systems.md §1`, so their
displayed effects are the 养成 (cultivation) meanings exactly as defined — **nothing was
invented, and no gap is recorded in `design/20_content.md`** (the section stays silent
by design; this note is the honest "sourced verbatim, no gap" record instead).

## 6. UX disposition

Recorded in `design/40_ux_backlog.md` per backlog rule 2 (CLOSED must be an action with
measured gate evidence, not an inference):

- **UX-06 / UX-07 / UX-08 — fix landed, still OPEN with the note 「修复已落,post-fix
  闸门证据待验」.** The fixes are on disk (observables + scenarios + probe notes), but the
  post-fix green pass is a gate artifact (`playtest_summary.md`) that does not exist at
  write time. **`CLOSED(jinyong-clarity)` is NOT written by this task** — the
  evidence-driven CLOSED transition is single-writer owned by the post-gate `5_design`
  evidence step, which reads the measured `playtest_summary.md` per-scenario counts
  (`creation_attr_effect_info N/N`, etc.). An honest OPEN beats an evidence-less CLOSED
  (the UX-01b / jinyong-hud precedent).

## 7. Evidence chain

| Artifact | Role |
|---|---|
| `playtest/creation_attr_effect_info.yaml` | UX-06 — all five names + effect keywords + verbatim bone formula in `AttrDescLabel.text`, focus-cycling proves the list is at-rest |
| `playtest/creation_hp_value_displayed.yaml` | UX-07 — `HpValueLabel.visible/text != ""`, `hp_value == attrs["bone"] * 5` (relative), `hp_text == "当前气血 " + str(hp_value)`, change-tracking on move |
| `playtest/creation_confirm_summary.yaml` | UX-08 — per-attribute relative asserts on `confirm_summary_text`, CONFIRM geometry pins (`points_attrs_gap_ok` re-pointed cluster, `phase_skeleton_same`, `creation_box_fits`, `nav_cluster_center_ok`), phase-gating |
| `playtest/_common.yaml` | surface append (`CreationScreen.hp_value` / `hp_text` / `confirm_summary_text`; node blocks `HpValueLabel` / `ConfirmSummaryLabel`) + `scenario_order` tail (50 → 53) |
| `final/creation_info_probe_notes.md` | pre-fix structural A-class absence baseline (nodes / observables / at-rest desc / CONFIRM cluster) |
| `design/90_decisions.md` | verify_report.json tombstone decision (Out of scope — verdict-in-final/ rejected) |
| `design/99_changelog.md` | jinyong-clarity round row (2026-08-27) |
| `design/30_presentation.md` | 捏人屏 record update (all-five effects desc slot, `HpValueLabel`, `ConfirmSummaryLabel`) + 2026-08-27 amendment (D1 at-rest decision, `points_attrs_gap_ok` re-point) |
| `design/40_ux_backlog.md` | UX-06/07/08 keep OPEN + 「修复已落,post-fix 闸门证据待验」; dated 2026-08-27 jinyong-clarity 记录 line; **no `CLOSED(jinyong-clarity)`** |

**Honest closing note:** this task ran **no gate** — the compile / unit / playtest /
vision verdicts are all **pending / not measured** here, and no gate count has been
invented. The `final/verify_report.json` fossil was replaced by a tombstone pointer
note (carrying no verdict fields, `represents_current_delivery: false`) whose decision
is recorded in `design/90_decisions.md` and `design/99_changelog.md`; the pre-replacement
content remains recoverable via git history. All other `final/*` files were left
untouched. UX-06/07/08 stay **OPEN**; `CLOSED(jinyong-clarity)` is written only by the
post-gate `5_design` evidence step from measured `playtest_summary.md` counts.

