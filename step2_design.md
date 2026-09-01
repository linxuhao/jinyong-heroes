# 技术架构设计 — jinyong-loop R2 (rule short-circuits + sect-join occlusion)

> Round: R2 bug-fix on the existing Godot 4 repo `/home/linxuhao/.AItelier/projects/jinyong-assets`.
> Four rule short-circuits in the monthly/map loop + one UI occlusion regression.
> **Zero balance-number changes. All numeric gates stay verbatim and green.**
> All findings below were re-verified by direct code read on 2026-09-01 (event_logic.gd, cultivation.gd, map.gd, sect_select.tscn, the gate yamls, _common.yaml, game_manager.gd, player_profile.gd, event_data.gd).

## 概述

Five fixes, one shared theme: **a rule that exists is being short-circuited** — the month-advance
rule (soft-lock), the facility-use bound rule (unlimited redemption), the once-per-visit
settlement rule (node events), the pay-what-you-get rule (purchases), and the
no-control-overlaps-body rule (sect-join, tutorial-overlay and roster-panel screens). Each fix restores the rule at the exact
short-circuit point, reusing an in-repo pattern; none touches a balance number, a protected
file, or one of the three verbatim-pinned gates.

Design decisions (the reviewer's Step-1 flags are each resolved explicitly):

| # | Decision | Chosen | Why (and which alternative was rejected) |
|---|---|---|---|
| D1 | Soft-lock exit shape | Empty-GONGFA accept → status message + `phase="ATTR_PICK"` + `_after_action()` (month advances through the single advance path); empty-branch button relabeled 返回行动 → 度过本月; **no** default attribute grant | Mirrors `_fast_forward:698-705`'s transition+advance. NOT calling `_apply_action({"kind":"cultivate"})` like the debug twin: that would inject a new reward (+1..3 attr) and one RNG op — a balance-behavior change, banned. The two soft-lock-era nails pin the dead-end and get re-pointed (change table in §5.1); they are NOT in the verbatim-protected trio |
| D2 | Facility limit form | **Per-month cap = 2** (constant `FACILITY_MONTHLY_USE_CAP`), epoch pair in the GameManager session mirror | Surveyed every facility-bearing scenario: `facility_use_reusable` (2 uses, 2 entries, month 36) and `map_facility_buttons_click` (2 uses, 2 entries, month 36) — max 2 uses/month anywhere → cap 2 keeps all green and actually bounds the exploit (measured: 40 presses → +81 bone becomes ≤ 2 uses = +4/month). Per-entry-1 also survey-clean but only slows the farm 3× (leave→F re-enter per use); per-month-1 reds gate (a) outright. Reviewer's boundary-risk note answered by the survey table in §5.2 |
| D3 | Re-settlement suppression key | Session mirror keyed by **`"<node_id>/<event_id>"`** per (node, event) pair | Reviewer flag resolved: an event-id-global flag would let a cultivation bag-draw of `night_rain` suppress the shaolin node binding — the two channels are documented independent (§8.2). Re-show stays unconditional; suppression hits only the effect application; `events_resolved_count` still increments (the count tracks RESOLUTIONS — gate (b) pins count==3 on re-fire legs) |
| D4 | Purchase refusal semantics | Validate-then-apply inside `EventLogic.apply_option_effects` (returns a status); a refused option **resolves the encounter with nothing applied** + on-screen receipt (map: panel closes → TRAVEL; cultivation: month still advances; facility: unchanged — its own pre-check stays) | "Refusal keeps the panel open" (facility-shape verbatim) was rejected for the map EVENT phase: that phase has no leave key, so an all-refused event (e.g. a broke player at pool event `dali_market`, both options −18/−14) would be a NEW soft-lock, and every scripted pick's affordability would become load-bearing against a PROTECTED gate. Refusal-resolves is trap-proof and timeline-proof: count still increments, so gate ladders cannot shift even if some scripted pick turns out unaffordable |
| D5 | Occlusion fix surface | Three scene-geometry fixes, presentation-only: `scenes/segments/sect_select.tscn` (BodyLabel `offset_right 320 → 110`, SectButton0..4 x `(-120..120) → (+130..+370)`); `scenes/ui/tutorial_overlay.tscn` (complete the `Buttons` HBox's broken anchor pair — add `anchor_top = 1.0` + `anchor_right = 1.0`, `offset_right 500 → -100` — turning the accidental 440px-tall column over the Body into an honest 400×40 bottom strip); `scenes/ui/roster_panel.tscn` (RosterBodyLabel `offset_right -16 → -180`, EquipButton0..11 x `+311` — the 12 equip buttons move into their own right-hand column clear of the body text) | The brief protects `sect_select.gd` but NOT the `.tscn`s (reviewer-verified). Reviewer R1's full 312-frame sweep confirmed the same jinyong-theme button inflation (opaque bg + font 15 + margins) occludes THREE screens, all mechanism-identical. Numbers are read off the current files: tutorial `Buttons` writes `anchors_preset = 8` but only `anchor_bottom = 1.0`, so its real anchors are (0,0,0,1) and offsets (100/−56/500/−16) compute to global x 280..680 × y 96..536 — exactly the measured s15_frame_0072 bar (x≈281-352 = Next's min width); roster buttons (local x 165..301, y 16..194) sit INSIDE the body label's rect (16..624). Narrowing the sect body is REQUIRED, not optional: the Tang-Men row's text extends past x=+120. No font scale, no copy, zero .gd changes in the fix |
| D6 | Occlusion gate | New engine-side autoload `scripts/autoload/ui_occlusion_watch.gd` + one `project.godot [autoload]` append; every frame it scans the live tree and publishes `violations: int` + `violations_text: String`; predicate = the reviewer's rule made precise: **a visible Control whose rect intersects a visible non-empty Label/RichTextLabel's rect, draws over it, and is not its ancestor ⇒ red** (same effective CanvasLayer, draw-order by sibling index below the lowest common ancestor); harness nails assert the published property (`violations == 0` per screen) — zero coordinate literals | Reviewer R1 orders a structural gate because vision-Q6 tests truncation, not occlusion — that is how 79/79 coexisted with three occlusions. The generic check CANNOT live harness-side: `aitelier/tools/godot_playtest/impl.py` is an external sidecar not in this repo (asserts are single-node `Expression`s over whitelisted surfaces), so the predicate is computed in-game and the harness keeps its existing grammar. The literal "任一可见 Control" needs exactly two qualifiers to avoid red-on-every-screen: every Label legitimately sits ON its ancestor Panel (containment ≠ covering), and z-order decides who covers whom (the tutorial Dim ColorRect overlays every layer-0 label by design — cross-CanvasLayer pairs are excluded). These qualifiers are part of the gate's spec, not a weakening; any further scoping forced by a first-red surprise is documented in delivery notes per the reviewer's bounded-plan clause |

## 设计变更 (for `5_design` to fold into `design/` after acceptance)

1. `20_content.md` §8.3 item 5 (repeat-re-fire policy) is amended: **re-appear yes, re-settle no** —
   node events still fire on every travel arrival and every resolution still increments
   `events_resolved_count`, but each `(node_id, event_id)` pair applies its effects at most once
   per session.
2. `90_decisions.md` ruling (e) ("facility reuse cap = PENDING for stage 5") is DECIDED this
   round: per-month 2, framed as a **rule gate, not a balance number** (it bounds a rule
   short-circuit; no facility cost/effect value moved).
3. `EventLogic.apply_option_effects` contract changes `-> void` → `-> Dictionary`
   (`{"ok": bool, "reason": ""|"silver"|"owned"}`); all three callers updated. The clamp-to-0
   silver semantics are removed (insufficient balance now refuses the whole option) — this is a
   rule repair, not a balance change; no cost value moved.
4. Cultivation empty-practice exit: the dead-end return is replaced by month-advance + feedback;
   the two nails that pinned the dead-end are re-pointed (§5.1 change table).
5. Occlusion geometry in three scenes (numbers in D5): `scenes/segments/sect_select.tscn`,
   `scenes/ui/tutorial_overlay.tscn`, `scenes/ui/roster_panel.tscn` — presentation-only,
   zero .gd changes, global theme and all copy untouched.
6. **Theme-round occlusion addendum (reviewer R1)**: the occlusion regression is not one screen
   but three — tutorial overlay (worst: the new player's first screen, a full-width opaque
   button bar through the body text), roster panel (卸下 covers the 悟性 attribute row), and
   sect select (5 scenario instances, not 1: s13_0210 / s16_0620 / s17_0240 / s20_0104 /
   s28_0325) — all caused by the same jinyong-theme button inflation. This round also lands a
   structural occlusion gate (D6) that is RED on the unfixed tree and GREEN after, as the
   reviewer explicitly requires. The gate is gate infrastructure, not part of the fix: the fix
   itself still touches zero script logic.

## 架构图

No new systems — five surgical insertions into the existing data flow:

```
                       ┌─ i18n.gd EN dict  (7 new strings, Chinese-keyed)
                       │
 CultivationScreen ────┤ D1: _on_accept GONGFA_PICK empty branch
 (cultivation.gd)      │     empty → status_text + ATTR_PICK + _after_action()   [month advances]
                       │ D4: _apply_event_option → EventLogic status → receipt or apply
                       │     (EVENT pick still consumes the month — no trap)
                       │
 MapScreen ────────────┤ D2: _use_facility → monthly-cap epoch check → refuse-with-receipt | apply
 (map.gd)              │ D3: _resolve_node_event → settled?(node,event) → suppress-with-receipt
                       │                                            → validate (D4) → refuse-with-receipt | apply+settle
                       │
 EventLogic ───────────┘ D4: apply_option_effects = validate-then-apply, returns status
 (event_logic.gd)            (pure-static; ZERO new RNG ops — seeded streams untouched)

 GameManager ─────── D2/D3 session mirrors (proven map_events_resolved_count pattern):
 (game_manager.gd)     facility_use_month/facility_use_count_this_month, settled_node_events: Dictionary
                       reset on SaveManager.profile_created / loaded (same site as map_events_resolved_count)

 UiOcclusionWatch ── D6: per-frame scan of the live tree → violations / violations_text
 (NEW autoload,       button-over-text predicate, same effective layer + draw order +
 ~90 lines)           ≥4 px both axes + residual-visibility ≥ 0.5; consumed by the occlusion nail

 playtest harness ─── 5 new scenario files + 2 re-pointed nails + surface appends in
 (playtest/*.yaml)     _common.yaml + ROUND_SCENARIOS sync in tests/test_playtest_contract_smoke.py
```

Data flow invariants preserved: RNG op order unchanged everywhere (validation and suppression
add zero RNG draws — the deterministic-stream lifeline that `event_travel_effects` 19/19 and
`save_load_roundtrip` 14/14 depend on); save-schema untouched (mirrors are session-scoped,
exactly like `map_events_resolved_count` at `game_manager.gd:131`).

## 组件列表

### 1. `scripts/data/event_logic.gd` — all-or-nothing core (D4)
- 职责: one shared validate-then-apply resolution path for map node events, cultivation 游历
  events, and facilities.
- 接口:
  ```gdscript
  static func validate_option(profile: PlayerProfile, opt: EventData.EventOption) -> String
      # returns "" if deliverable, "silver" if net silver cost > balance, "owned" if any
      # item effect targets an id already in profile.inventory. Pure arithmetic, no mutation,
      # no RNG.
  static func apply_option_effects(profile: PlayerProfile, opt: EventData.EventOption) -> Dictionary
      # pass 1: validate_option; if refused return {"ok": false, "reason": <"silver"|"owned">}
      #         with ZERO profile mutation.
      # pass 2: apply all effects exactly as today (silver WITHOUT the maxi(...,0) clamp —
      #         balance already proven sufficient; attr / item / practice as-is).
      #         returns {"ok": true, "reason": ""}.
  ```
  `add_practice` / `draw_unseen_id` untouched byte-for-byte.
- Caller contract: map `_resolve_node_event` and cultivation `_apply_event_option` compose the
  receipt string from the returned reason via `tr()`; facility `_use_facility` keeps its own
  pre-check (unchanged) and is behavior-preserving under the new validation (no item effects,
  its silver pre-check already refuses first).

### 2. `scripts/segments/cultivation.gd` — soft-lock exit (D1) + cultivation receipt (D4)
- 职责: the empty-practice branch must advance the month with visible feedback; event-option
  refusals must explain themselves.
- 接口 / exact edit points:
  - `_on_accept()` first line: `month_before_accept = month` (new published var, int).
  - `_on_accept()` GONGFA_PICK branch (`:272-280`): when `_unmastered_ids().is_empty()`:
    `status_text = tr("无可修习的功法，本月照常过去")`; `phase = "ATTR_PICK"`; `_attr_focus = 0`;
    `_after_action()` — then `return`. NO `_apply_action` call (no free gain, no RNG op).
    `_after_action` inherits month-12 → YEAR_END and y3/m12 → finish-to-map for free.
  - `_rebuild_options_box()` empty-GONGFA label construction (the single label line only —
    the theme-owned stylebox swap at :582-646 is NOT touched): `tr("返回行动")` → `tr("度过本月")`.
  - GONGFA_PICK render branch: when the unmastered list is empty, the body gains the line
    `tr("功法均已大成，无可修习")`.
  - `_apply_event_option()` (`:484-493`): capture the returned status; on refusal set
    `status_text = tr("银两不足")` / `tr("此物已在行囊，无须再购")` by reason; skip effect
    application; **still mark seen** (the encounter happened — keeps `events_seen_count`
    ladders in `event_travel_effects` immune to any refused draw) and still let the caller's
    `_after_action()` run (the pick IS the month's action — no trap).
  - `status_text: String = ""` new var, rendered as an appended body line whenever non-empty,
    cleared at the top of `_on_accept()`.
  - `_fast_forward` / `_debug_step_month` empty branches (`:698-705`, `:752-756`) stay
    byte-identical (debug twins are not the defect).

### 3. `scripts/segments/map.gd` — facility cap (D2) + settled split (D3) + refusal receipts (D4)
- 职责: bound facility redemption per month; decouple event re-appearance from re-settlement;
  render refusal/suppression receipts.
- 接口 / exact edit points:
  - New const `FACILITY_MONTHLY_USE_CAP := 2` (rule gate, not balance).
  - `_use_facility()` (`:298-332`): after the existing silver pre-check (unchanged), insert the
    epoch check — `if GameManager.facility_use_month != SaveManager.profile.cultivation["month"]:`
    reset the pair; if `facility_use_count_this_month >= FACILITY_MONTHLY_USE_CAP`: reuse the
    `_facility_refused` + `facility_result_text = tr("本月设施已用尽，下月再来")` refusal shape,
    **no** count increment, **no** mutation. On success also publish the snapshot surfaces
    `last_use_silver` / `last_use_attr_value` (profile.silver / the facility's target attr,
    post-apply) — written ONLY on success, they are the zero-delta anchors.
  - `_resolve_node_event()` (`:257-277`) becomes three paths, all ending
    `event_id=""; phase="TRAVEL"; count+=1; mirror write-through; autosave; sync; render`:
    1. **settled**: `GameManager.is_node_event_settled(current_node_id, event_id)` →
       `last_effect_types = []`, receipt `map_status_text = tr("此事已有了结，不再重来")`,
       nothing applied. (Gate (b) re-fire legs keep their exact phase/count asserts.)
    2. **refused**: `validate_option(...)` returns a reason → receipt by reason
       (`tr("银两不足")` / `tr("此物已在行囊，无须再购")`), nothing applied, `last_effect_types = []`.
       Count still increments (the encounter was resolved; its effects were not delivered) —
       this is what makes every existing timeline ladder immune to affordability.
    3. **applied**: apply, mark settled via `GameManager.settle_node_event(current_node_id, event_id)`,
       publish `last_apply_attr_value` (only when the option carries an `attr` effect) — the
       revisit-nail zero-delta anchor.
  - `_maybe_start_entry_event()` (`:219-227`): publish `event_open_silver = profile.silver` —
    the purchase-nail zero-delta anchor (re-show stays unconditional; nothing else changes).
  - `map_status_text: String = ""` new var, rendered by `_render()` when non-empty, cleared by
    `_travel()` / `_enter_facility()`.

### 4. `scripts/autoload/game_manager.gd` — session mirrors (D2/D3)
- 职责: survive MapScreen rebuilds (battle return) and profile boundaries without touching the
  save schema — the proven `map_events_resolved_count` pattern (`:125-131`).
- 接口:
  ```gdscript
  var facility_use_month: int = -1
  var facility_use_count_this_month: int = 0
  var settled_node_events: Dictionary = {}          # keys "<node_id>/<event_id>" -> true
  func is_node_event_settled(node_id: String, event_id: String) -> bool
  func settle_node_event(node_id: String, event_id: String) -> void
  ```
  All three reset at the exact site where `map_events_resolved_count` resets
  (SaveManager.profile_created / loaded). Session-scoped only, never persisted — documented
  consequence: a loaded save may re-settle once per session, identical to the existing count
  mirror's behavior.

### 5. `scripts/autoload/i18n.gd` — 7 new EN-dict entries
Chinese-keyed, appended to the existing EN dict (guarded by `tests/test_i18n_coverage.py`):
`功法均已大成，无可修习` / `度过本月` / `无可修习的功法，本月照常过去` / `此物已在行囊，无须再购` /
`此事已有了结，不再重来` / `本月设施已用尽，下月再来` (reuse the existing `银两不足` for the
purchase-silver refusal — same wording the brief names as the reference). No U+2026 ellipsis
characters (repo-wide rule).

### 6. `scenes/segments/sect_select.tscn` — occlusion fix 1 of 3 (D5)
- 职责: presentation-only de-overlap; `sect_select.gd` untouched; global theme untouched.
- 接口: BodyLabel `offset_right: 320 → 110`; SectButton0..4 `offset_left: -120 → 130`,
  `offset_right: 120 → 370` (width 240 and all y offsets preserved); HintLabel x
  `-200..200 → -100..100` (its ~10-glyph text ≈ 130 px renders fully and stays centered —
  `clip_text` default false, so a narrower rect hides nothing). Result: body wraps at 430 px
  (every row clear of x=+110), buttons at global x 610..850, hint rect 380..580 — NO
  button/label rect intersection remains on this screen, so the D6 gate reads 0 here honestly,
  not by tolerance. All five body rows (incl. the Tang Men row) render fully. Acceptance needs
  before/after same-frame pairs for ALL FIVE pinned sect frames (s13_0210 / s16_0620 /
  s17_0240 / s20_0104 / s28_0325), not one.

### 7. `scenes/ui/tutorial_overlay.tscn` — occlusion fix 2 of 3 (D5, reviewer R1)
- 职责: presentation-only repair of the new player's first screen; `tutorial_step.gd` /
  `tutorial_manager.gd` untouched; theme values (dim 0.88, colors, fonts) untouched.
- 缺陷机制 (read off the file; matches the measured s15_frame_0072 bar x≈281-352 / y≈95-537):
  the `Buttons` HBoxContainer (`:52-58`) writes `anchors_preset = 8` but overrides ONLY
  `anchor_bottom = 1.0` — anchor_left/top/right stay 0.0 — so the container's real anchors are
  (0, 0, 0, 1) and its offsets (100 / −56 / 500 / −16) compute to a 400 × 440 px column at
  global x 280..680 × y 96..536, directly over the Body RichTextLabel (x 200..760, y 216..452).
  The HBox stretches children to its own height, so `Next`'s `size = Vector2(160, 36)` acts
  only as a minimum and the opaque 继续 button renders as the measured full-height bar.
- 接口 / exact edits: complete the anchor pair — add `anchor_top = 1.0` and
  `anchor_right = 1.0`, change `offset_right 500 → -100` (offsets then read as insets from the
  panel's bottom-right corner). Result: an honest 400 × 40 px bottom strip at global
  x 280..680 × y 496..536 — the same horizontal span the original layout intended — 44 px
  clear below the body rect (bottom y=452). Buttons keep their ~36 px min height inside the
  40 px strip. After the fix NO tutorial page can occlude its body regardless of body length.
- 实测边界 (recorded per the reviewer's instruction): official frames captured only the
  WELCOME page of the 7 tutorial pages, so the other 6 pages' occlusion is geometric inference.
  The implementer MEASURES what the runs actually show and records it in the delivery notes —
  the D6 watch covers every captured frame of every page regardless.

### 8. `scenes/ui/roster_panel.tscn` — occlusion fix 3 of 3 (D5, reviewer R1)
- 职责: presentation-only de-overlap; `roster_panel.gd` untouched (published surfaces
  `is_open` / `body_text` / counts unchanged); theme untouched.
- 缺陷机制: RosterBodyLabel spans local x 16..624 × y 16..208 (full box width), while the 12
  equip pool buttons sit at local x 165..301 × y 16..194 — INSIDE the body rect — so the
  卸下/装上 buttons cover the right half of the composed rows (measured: the 悟性 cell of the
  attribute row is hidden at s75_frame_0110; 悟性 governs learning speed).
- 接口 / exact edits: RosterBodyLabel `offset_right: -16 → -190` (body x 16..450);
  EquipButton0..11 shift right by +297 — `offset_left 165/211/257 → 462/508/554`,
  `offset_right 209/255/301 → 506/552/598`, all y offsets unchanged. Result: the body wraps at
  434 px and the buttons occupy their own right-hand column (global x 622..758, right margin
  42 px inside the 640 px box) — no button/label rect intersection remains. Scenario clicks
  aim at nodes (`EquipButton0 +0,0` grammar), so no timeline changes; `refresh()` re-binds
  pool buttons by index, not position.

### 9. `scripts/autoload/ui_occlusion_watch.gd` + one `project.godot [autoload]` line — the structural occlusion gate (D6, reviewer R1)
- 职责: make "a visible control covers body text" an observable PROPERTY instead of a
  vision-judge opinion. NEW autoload only — no existing script is modified (the three fixes
  stay presentation-only). Registered as `UiOcclusionWatch` in `project.godot` `[autoload]`.
- 接口:
  ```gdscript
  extends Node
  ## Recomputed every frame over the live scene tree (pure reads; zero RNG draws).
  var violations: int = 0
  var violations_text: String = ""   # occluder>label pairs, e.g. "Next>SectBody"
  ```
- Predicate (the reviewer's rule made precise; ~90 lines): RED pair = a visible **Button** B
  and a visible **Label/RichTextLabel** L with non-empty text, where
  (1) same effective CanvasLayer — cross-layer pairs are out of scope: the tutorial/roster
  dims (0.88 / 0.85 alpha over a whole screen) are this game's DESIGNED vocabulary for
  covering inactive screens, not defects;
  (2) B is neither an ancestor nor a descendant of L — a label's own panel/frame is
  containment, not covering;
  (3) B draws over L (B is later in Godot's draw order, compared at the lowest common
  ancestor's sibling index);
  (4) the two rects intersect ≥ 4 px in BOTH axes (a graze is not occlusion);
  (5) L is actually readable on screen: residual visibility through overlying translucent
  controls `Π(1 − alpha)` ≥ 0.5 (the dims push under-labels to 0.12–0.15 → excluded; the
  three defect labels sit on opaque panels at 1.0).
  Scope statement (the bounded plan the reviewer accepts): all three measured defects are
  button-over-text, and in this game's vocabulary an interactive button on top of prose is
  always a defect while Panel/ColorRect overlaps are the designed backdrop/dim layer — so the
  gate watches button-over-text and says so; it does not claim to catch non-button
  container-over-label overlaps.
- Harness contract: `playtest/_common.yaml` `surface:` appends
  `UiOcclusionWatch: [violations, violations_text]` (append-only). The generic check cannot
  live harness-side — `aitelier/tools/godot_playtest/impl.py` is an external sidecar, and its
  asserts are single-node `Expression`s over the whitelisted surface — so the predicate is
  computed engine-side and the harness asserts the published property with its existing
  grammar. No coordinate literals anywhere.
- Nail: new scenario `occlusion_no_button_over_text` (real input down the spine) asserting
  `violations == 0` at the tutorial-overlay frame (WELCOME page), the sect-select frame, and
  the roster-open frame — three property asserts. RED on the current tree (R1's sweep measured
  the three overlaps; this round re-measures its own red run), GREEN after D5. Frames are
  re-baselined from the measured red run; delivery notes carry the red-first four values plus
  the SEVEN before/after pairs (5 sect + 1 tutorial + 1 roster).

### 10. Playtest contract (repo's own harness — `playtest/_common.yaml` + per-scenario files)
- 职责: pin the four repaired rules with differential nails; re-point the two soft-lock-era nails.
- 契约 (all appends additive; two-place sync with `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS`):
  - New surfaces (append to `_common.yaml` `surface:`):
    `MapScreen: [map_status_text, event_open_silver, last_apply_attr_value, last_use_silver, last_use_attr_value]`,
    `CultivationScreen: [month_before_accept, status_text]`,
    `UiOcclusionWatch: [violations, violations_text]`.
  - No new actions (all needed tokens already whitelisted: `ui_accept`, `move_right`,
    `use_facility`, `debug_seed_save`, `debug_grant_silver`, `debug_grant_equip`,
    `debug_fast_forward`, `debug_win_tutorial`).
  - Zero-delta grammar (no `== 8`-style literals): each nail compares a live value against a
    success-only snapshot surface. Snapshot vars update ONLY on success, so `silver ==
    last_use_silver` after a refused/exhausted press is true iff the press changed nothing.
  - Scenario skeletons (frames are re-baselined from the red-first runs; asserts here are the
    contract, frames are measured):
    - `softlock_empty_practice_month_advances` — boots main flow, `debug_seed_save` seed
      prefix (sanctioned seed action, same role as `debug_win_tutorial`; **`debug_fast_forward`
      FORBIDDEN**), real `ui_accept` drive: CARD_PICK → 练功 → empty GONGFA_PICK → accept.
      Asserts: `CultivationScreen.month == month_before_accept + 1` (true differential, zero
      literals), `phase == "CARD_PICK"`, `status_text != ""`.
    - `facility_use_cap_exhausted_zero_delta` — mirrors `facility_use_reusable`'s sanctioned
      seed prefix; enter → use (count 1) → leave → re-enter → use (count 2) → leave → re-enter
      → use (EXHAUSTED). Asserts: `facility_use_count == 2` (ladder rung, gate-(a) style),
      `silver == last_use_silver`, `attr_bone == last_use_attr_value`,
      `facility_result_text != ""`.
    - `map_node_event_revisit_no_resettle` — resolve quanzhen_scripture at 武当 (apply:
      wisdom +2), travel 洛阳↔武当 (transit merchant applies once — unaffected), re-fire at
      武当, resolve again (suppressed). Asserts: `attr_wisdom == last_apply_attr_value`,
      `last_effect_types == []`, `map_status_text != ""`, `events_resolved_count == 3` (rung).
    - `event_option_refused_no_charge` — seed `eq_sword_3` via whitelisted
      `debug_grant_equip` (CULTIVATION-scoped, `cultivation.gd:821`) → fast-forward to MAP →
      travel to 洛阳 → merchant opens → assert `silver == event_open_silver` → pick
      买下长剑 (owned → refused) → assert `phase == "TRAVEL"`,
      `silver == event_open_silver`, `map_status_text != ""`, `events_resolved_count == 1`.
  - Re-pointed nails (NOT in the verbatim-protected trio; full change table recorded in delivery
    notes, huashan-round precedent):
    - `gongfa_pick_empty_keyboard_return.yaml`: f77 text assert 返回行动 → 度过本月; f200 block
      `phase == "ACTION_PICK"` → `phase == "CARD_PICK"` + `month == month_before_accept + 1` +
      `status_text != ""`. All other asserts (f170 GONGFA_PICK/empty-state block incl.
      `mastered_count == gongfa_count`, `pressed_connected`) preserved verbatim.
    - `clicks_only_gongfa_empty_exit.yaml`: f125 text assert → 度过本月; f138 block re-pointed
      identically. All other asserts preserved.
  - Occlusion gate (reviewer R1): PRIMARY = the structural property gate — new
    `occlusion_no_button_over_text` scenario asserting `UiOcclusionWatch.violations == 0` at
    the tutorial-overlay frame (WELCOME page), the sect-select frame, and the roster-open frame
    (property, zero coordinate literals; RED before D5, GREEN after). ACCEPTANCE EVIDENCE =
    same-frame before/after pairs in the delivery notes for ALL SEVEN defect instances — the
    five sect frames (s13_0210 / s16_0620 / s17_0240 / s20_0104 / s28_0325) + tutorial
    (s15_frame_0072) + roster (s75_frame_0110). Coordinate-literal asserts
    (`offset_right == 110` etc.) are FORBIDDEN by R1 — a legal layout re-tweak would
    falsely red them. Do not lean on the vision gate — Q6 asks truncation, not occlusion,
    which is exactly how 79/79 coexisted with three overlaps.

## 技术栈

- Godot 4.4 / GDScript (existing repo; no engine, addon, or asset-tooling changes).
- Existing playtest harness (`playtest/_common.yaml` + per-scenario yaml +
  `aitelier/tools/godot_playtest/impl.py`); append-only discipline.
- stdlib pytest static guards (`tests/test_playtest_contract_smoke.py` shape) + GDScript unit
  suite for the EventLogic validate/apply contract (follow `tests/test_event_data.gd`'s harness;
  pin: insufficient silver → zero mutation; owned item → zero mutation; deliverable → applied).
- No new dependencies. `linter_manifest.json` covers the non-GDScript text files (`.gd` is
  host-gated via `gdscript_check`).

## 红线与守护 (hard constraints carried into every task)

1. **Verbatim-protected, byte-untouched**: `playtest/facility_use_reusable.yaml`,
   `playtest/map_node_event_shaolin.yaml`, `playtest/map_battle_node_huashan.yaml`.
2. **Protected files**: `assets/themes/global_theme.tres`, `scenes/ui/hud.tscn`,
   `scripts/autoload/theme_manager.gd`, `scripts/segments/sect_select.gd`, the focus-style
   stylebox-swap portion of `cultivation.gd::_rebuild_options_box`, the six huashan-round files.
   **R1 amendment (2026-09-01, authority = reviewer feedback round #1)**:
   `scenes/ui/tutorial_overlay.tscn` and `scenes/ui/roster_panel.tscn` are unlocked for THIS
   round's presentation-only geometry repairs (D5 components 7/8) — the theme-round protection
   barred collateral damage from theme work, and the same reviewer now orders these two scenes
   fixed. Only container anchor/offset/width lines may change in them (no colors, no fonts, no
   dim values, no node adds/removes, no copy, no script edits); `sect_select.gd` stays fully
   protected; `global_theme.tres` and `hud.tscn` stay byte-untouched.
3. **No balance numbers move**: `event_data.gd` / `facility_data.gd` / `card_data.gd` values,
   `MapData.ENDING_TIERS`, Huashan difficulty. `FACILITY_MONTHLY_USE_CAP` is a rule gate.
4. **Gate safety analysis (already done, re-verified at T6's full run)**: suppression legs change
   only effects, never phase/count (gates (b) legs assert phase/count only — f460/f630 in the
   shaolin gate; huashan Leg F). Refusal-resolves keeps every ladder immune to affordability.
   The facility cap survey (D2) shows max 2 uses/month in every scenario. Mandatory T6 check:
   if any non-protected scenario still reds on a new refusal path, add
   `debug_grant_silver` funding to its seeding prefix (additive, asserts untouched); if a
   PROTECTED scenario reds, STOP and surface to the driver.
5. **Pre-landing**: run `git log` and confirm the jinyong-theme merge has landed before touching
   `cultivation.gd` (in-tree evidence already shows `ThemeManager.option_style` consumption at
   `cultivation.gd:649-651` / `sect_select.gd:88-89`; the brief requires the explicit check).
6. **Red-first discipline**: each new nail carries four measured values (failing frame / first
   failing assert / exact error / green asserts before red) from a temporary revert marked
   `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`, restored byte-identically afterwards
   (`repo_apply` is `git add -A` — no revert residue). The occlusion fix's before-state IS the
   red measurement (current tree shows the occlusion at f210).
7. **Rollback**: all edits are plain file edits in git — revert path is `git checkout -- <file>`;
   no data migration, no irreversible operation anywhere in this round.

## 扩展性考虑

- The settled-event mirror is the seam for a future save-persistent "visited" ledger (R3+):
  swap the GameManager dictionary for a profile field; the map-side call sites do not change.
- `validate_option` is the single choke-point if R3 adds cost types (the 5-type domain is
  closed today).
- The snapshot-surface zero-delta grammar generalizes to any future "must not change X" nail.
- The per-month facility epoch pair naturally extends to per-month action budgets later.
- Deliberately NOT designed now (out of scope, per brief/R3): ending thresholds, attribute
  formulas, card rewards, Huashan difficulty, remaining declared battle/facility slots,
  pool-event re-show policy (bag events never re-draw within 36 months).

## 给 PM 的任务分解建议 (dependency-ordered)

- **T1 Soft-lock**: cultivation.gd D1 edits + 2 i18n strings + re-point 2 nails + new
  `softlock_empty_practice_month_advances` (red-first). Independent.
- **T2 Facility cap**: game_manager epoch pair + map.gd D2 + 1 i18n string + new
  `facility_use_cap_exhausted_zero_delta` (red-first). Independent.
- **T3 Settled split**: game_manager settled set + map.gd D3 resolve paths + 1 i18n string +
  new `map_node_event_revisit_no_resettle` (red-first). Touches `_resolve_node_event` — land
  before/with T4.
- **T4 All-or-nothing**: event_logic.gd contract + cultivation/map callers' receipts + 1 i18n
  string + unit pin + new `event_option_refused_no_charge` (red-first). Depends on T3's
  `_resolve_node_event` shape (same function).
- **T5 Occlusion**: sect_select.tscn offsets + frame pair (+ optional additive geometry asserts
  after impl.py verification). Independent; presentation-only.
- **T6 Sync & verification**: `_common.yaml` (surfaces + scenario_order) ↔
  `ROUND_SCENARIOS` two-place sync, new pytest anti-weakening guards (each nail must contain its
  differential expression; the soft-lock nail must NOT contain `debug_fast_forward`), full
  79+4-scenario gate run, blast-radius survey sign-off, delivery notes with the four red-first
  records + the nail change table + the occlusion frame pair.
