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

---

# Delivery notes — jinyong-mainline(主线事件) (2026-08-27)

## Round record — main story node events wired

This round wires content events into the five main story nodes (无名谷 / 洛阳 / 武当 /
襄阳 / 昆仑) so every stop on the journey has content, keeps the ending reachable,
unifies the map-page bottom hint with the panel text, and records the persistent-text
audit. Single lever: mainline node event binding. No numeric/balance tuning, no combat
change, no monthly-cultivation-loop change, no new art, no new event prose (all text is
verbatim from the existing 16-row `event_data.gd` pool).

### 1. Binding result — 4 of 5 mainline nodes carry live deterministic content

`scripts/data/map_data.gd` `NODES` event slots (all `status: "active"`, literal
`event_id` rows — never a pool draw, keeping the two channels' `events_seen`
independent):

| Node id | Node | event_id (verbatim pool row) | option A |
|---|---|---|---|
| `wuming_valley` | 无名谷 | `tomb_bed` 古墓寒玉 | attr inner +2 |
| `luoyang` | 洛阳 | `merchant` 行商路过 | silver −20 + item (no attr) |
| `wudang` | 武当 | `quanzhen_scripture` 全真抄经 | attr wisdom +2 |
| `xiangyang` | 襄阳 | `dragon_scrap` 降龙残谱 | practice +4 |

`kunlun` (昆仑) is an explicit, argued **NON-trigger**: its event slot stays
`{"status": "declared", "event_id": ""}`. The ending IS the terminal's content, and the
structural guarantee is routing-first order in `map.gd::_travel()` — it routes an end
node to ENDING (and sets `ended = true`) BEFORE `_maybe_start_entry_event()`, so a
future end-node event can never silently break the ending. The pre-existing branch
binding `shaolin=night_rain` is unchanged from the previous round.

Result: **4 of 5** mainline nodes live; 昆仑 is a deliberate, argued non-trigger.

### 2. The two authorized yaml re-budgets + the single literal re-base

Only **two** existing scenario yamls were modified (the round owner's exception, written
up first in `design/`): `playtest/spine_to_ending.yaml` and
`playtest/map_node_event_shaolin.yaml`. The other **53** scenario yamls were untouched;
only the two new scenarios were appended (55 → 57 total).

- **`spine_to_ending.yaml`** — the map leg now resolves the 洛阳/武当/襄阳 node entry
  events en route to 昆仑: `move_right`/`ui_accept` pairs at f420/f430 (洛阳, asserts
  `phase == "EVENT"` / `event_id == "merchant"` at f440), f460/f470 (武当, f480), f500/f510
  (襄阳, f520 + `events_resolved_count == 2`), f540/f550 (昆仑 — end-node routing to ENDING
  runs before entry content), and the ENDING block moved f520 → **f580** with its assert
  lines verbatim (`current_state == "ENDING"`, `tier >= 1 and tier <= 3`, EndingScreen /
  Backdrop visible+size). Everything at f400 and earlier is byte-unchanged. The scenario
  remains the six-segment connectivity proof with the ending reachable.
- **`map_node_event_shaolin.yaml`** — the 洛阳 outbound stop and the return-leg re-fire
  each cost one inserted resolve press. The `events_resolved_count` ladder is now pinned
  1 (f460, 洛阳 outbound) → 2 (f560, 少林) → 3 (f630, 洛阳 return); last assert f660.
- **The single literal re-base:** `MapScreen.events_resolved_count: events_resolved_count
  == 1` → `== 2` at 少林 (f560), counterbalanced by the NEW `== 1` ladder pin at 洛阳
  outbound (f460) — still an exact equality, never `>=`, so the ladder is tightened, not
  relaxed. The superset pin in the smoke test machine-enforces that every pre-edit assert
  line of both edited scenarios still exists.

### 3. Hint unification

`scenes/segments/map.tscn` `HintLabel.text` is now byte-identical to the
`map.gd::_render()` panel string: `左右/上下选择相邻去处，回车启程` (full-width `，`
U+FF0C). Pinned at f30 of `playtest/map_node_event_mainline_return.yaml`
(`HintLabel.text == "左右/上下选择相邻去处，回车启程"`), which also proves the active
无名谷 binding does NOT fire at boot.

### 4. Persistent-text audit

Audited: only one site. The MAP segment has exactly two persistent Label text nodes —
BodyLabel (fully re-rendered on every phase by map.gd::_render(), including the EVENT
branch) and HintLabel (visibility toggled by _apply_hint_visibility(), whose phase !=
'EVENT' allow-list-by-negation already yields for any future phase). No other persistent
text exists in the segment; the only phase-switch stale-promise site was HintLabel, fixed
and re-pinned this round.

The audit is scoped to the MAP segment's TRAVEL↔EVENT switch (this round's single lever);
other segments' phase switches are outside this round's scope.

### 5. Honest gate-evidence stance

This note records design intent, the on-disk binding/frame facts, and the audit result —
nothing is invented. The compile / unit / playtest / vision verdicts are all **pending /
not measured by this task**; measured PASS/FAIL counts belong to the downstream
`5_compile` (`compile_report.json` / `playtest_report.json` / `playtest_summary.md`),
`5_test` (`test_report.json`) and `5_vision` (`vision_report.json`) gate artifacts, which
do not exist when this task runs. No `N/N PASS` count is asserted for any scenario here.

---

# Delivery notes — interaction-defects(交互缺陷) (2026-08-28)

Round record — three measured mouse/info interaction defects fixed (A: floating health
bar's Bar control ate right-clicks; B: portrait a full tile above its cell / nameplate on
the legs / portrait clicks did not target; C: trait descriptions showed only on click),
plus the real-input coverage net, touch undo, and three small fixes. Docs card: records
only; all code/YAML landed upstream this round, gate evidence pending (closing entries
are written by the post-gate evidence step).

## What changed per item

- **Defect A audit residue:** the delivered `scenes/ui/health_bar.tscn` has **no** explicit
  `mouse_filter` line on `NameLabel` — it rides the Label class-default IGNORE; the audit
  conclusion "no STOP descendant in the subtree" stands. Enemy `ClickTarget` verdict: the
  `debug_click_target_fires` counter is landed in `enemy.gd` (L123/L346) and pinned by
  `input_click_differential` (`== 0`); the measured verdict is the downstream gate's
  (evidence pending). The node is **kept**: it is the harness click anchor that
  `click_move_commit_lock.yaml` resolves by name; its `mouse_filter` left unchanged
  (zero diff).
- **P0 coverage net Layer 1:** permanent differential observables in `player.gd` —
  `debug_right_input_events`, `debug_undo_events`, `debug_gui_eater` — backed by
  `scripts/ui/input_census.gd` (`InputCensus.top_eater`, ported from the deleted
  InputProbeOverlay). A STOP control reappearing under the feet now reddens headless.
- **P0 coverage net Layer 2:** `scripts/autoload/input_gate.gd` (`InputGate` autoload,
  activated by the env var `AITELIER_INPUT_GATE_REPORT`, self-drives to the battle state,
  publishes the nine-key report, registered before `SceneManager`). The windowed X11
  sidecar half is LANDED in AItelier (`abb1358`), outside this repo's boundary.
- **UndoButton (touch undo):** HUD 「退回」 button driving the same shared undo entry,
  same lock rule; `SkillDescLabel` shifted down 40 px.
- **Defect B visual:** the nameplate re-anchored from the feet (`-32`) to the portrait
  top (`sprite_top - 4 - size.y`), the `STRIP_BOTTOM + 2 = 94` clamp retained; new
  `TileMarkers` ground-marker overlay (`scripts/ui/tile_markers.gd`) mounted in
  `scenes/battlefield.tscn` AFTER `Characters`, so the occupied tile stays readable
  (visible for all six units including the top row, click-inert by construction).
- **Defect B hit:** `portrait_ink_rect` published per-frame on player and enemies; the
  5-step priority resolver in `handle_world_click` (see below), plus the pure
  `attack_reach_covers` predicate.
- **Defect C:** `trait_hover_index` (separate preview channel, −1 on exit and when
  phase != TRAITS) with `mouse_entered`/`mouse_exited` wired on every `TraitToggle{i}`;
  it influences only `TraitDescLabel` — never `trait_index`, never toggle, never the
  focus `modulate`.
- **Small fixes:** the delivery-notes round heading (L166) corrected — round name
  `jinyong-nodes`→ the actual authoring round, date `2026-08-29`→`2026-08-27` (this
  file, round name and date only, body untouched); map hint is now one per screen (footer
  `HintLabel` kept, panel trailing line removed); the MAP EVENT branch uses the
  full-width comma 「上下选择，回车定夺」.

## NEW assertions (five scenarios, by name)

1. `input_click_differential` — per-press raw-vs-handled differential; feet-tile
   right-click reaches the undo path with an empty GUI eater; the enemy-tile leg pins
   `debug_click_target_fires == 0` (the counter is landed; the measured verdict is the
   downstream gate's — evidence pending, not claimed here).
2. `undo_button_retreat` — UndoButton wiring/geometry, disabled-state mirroring, click →
   retreat via the shared entry.
3. `click_portrait_body_targets_enemy` — clicking a **reachable** enemy's drawn portrait
   body center attacks it (health drops / `acted == true`), with an out-of-reach negative
   control.
4. `health_bar_above_portrait` — bar bottom above `sprite_top` for mid-board units; the
   top-row documented landing for Central_Divine (`bar_top == 94`, face untouched);
   `tile_marker_count == 6`.
5. `trait_hover_preview` — hover previews the description, `trait_index` untouched,
   revert on exit.

## Defect B priority rule

Five-step resolution of a left-click at world point P (in `handle_world_click`):
(1) enemy on the clicked tile → attack; (2) an **in-reach** enemy whose live drawn
portrait rect contains P → attack (this closes the reachable-body gap); (3) reachable
empty tile in the move-range highlight → move; (4) an **out-of-reach** enemy's rect →
select (no silent move); (5) own tile no-op / else move. The operative guarantee:
**an out-of-reach enemy's portrait rect can never make a reachable empty tile
unclickable** — the rejected "grid → rect → move" rule did exactly that (measured
`click_move_undo_right` 10→6, `click_move_commit_lock` 9→1, `move_target_affordance`
18→11, because top-row Central_Divine's clamped art covers tiles (7,2)/(7,3)) and is
recorded as rejected in `design/90_decisions.md`.

## P0 honest coverage boundary

The **web browser bridge is manual-only** — it cannot be exercised server-side; it is
covered by the shared engine path, the player confirmation already in hand, and a manual
checklist. The **X11 windowed gate covers the desktop window layer** end-to-end (real
`menu.tscn` boot → OS event → engine → handler → state change); real-hardware touch is
only partially covered (xdotool injects mouse events). **A skipped gate run is recorded
as an OPEN coverage gap, never green.**

## Verify-only confirmations (docs card)

- `playtest/map_hint_single.yaml` exists and pins both halves: the footer
  `HintLabel.text == "左右/上下选择相邻去处，回车启程"` and `BodyLabel` NOT containing
  「回车启程」; EVENT leg pins the footer hidden and `BodyLabel` containing the
  full-width 「上下选择，回车定夺」. `scripts/segments/map.gd:236` confirmed already
  using the full-width 「，」.
- `InputProbeOverlay` has **zero live references**: no preload/load of
  `input_probe_overlay.gd`, no `[node name="InputProbeOverlay"]` or matching ext_resource
  in `scenes/ui/hud.tscn`. The only remaining mentions are the intentional
  port-attribution comment in `scripts/ui/input_census.gd:5` and design docs — not live
  references, and left untouched.
- `scenes/ui/hud.tscn` still parses (ext_resources precede sub_resources).

## Fix-loop note (docs alignment)

This fix loop restored `ui_geometry_readability` (35/38 → target 38/38) **without touching
any assertion**: `follow_delta` stays `<= 24` at **both** legs (f30 L39 / f85 L80; the yaml
is byte-untouched) because the top-row nameplate now **flips** below the portrait
(`bar_anchors_below_portrait`) instead of being clamped into the strip, and
`hint_nameplate_overlap == false` was restored solely by shrinking `SkillDescLabel`
(`offset_bottom` 396 → 384; landed box `offset_top 280 / offset_bottom 384`), clearing
North_Beggar (11,8)'s raised nameplate. **No assertion was deleted, relaxed or
re-baselined.**


