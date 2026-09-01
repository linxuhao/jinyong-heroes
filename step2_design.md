# 技术架构设计 — jinyong-loop R2 (rule short-circuits + sect-join occlusion)

> Round: R2 bug-fix on the existing Godot 4 repo `/home/linxuhao/.AItelier/projects/jinyong-assets`.
> Four rule short-circuits in the monthly/map loop + one UI occlusion regression.
> **Zero balance-number changes. All numeric gates stay verbatim and green.**
> All findings below were re-verified by direct code read on 2026-09-01 (event_logic.gd, cultivation.gd, map.gd, sect_select.tscn, the gate yamls, _common.yaml, game_manager.gd, player_profile.gd, event_data.gd).

## 概述

Five fixes, one shared theme: **a rule that exists is being short-circuited** — the month-advance
rule (soft-lock), the facility-use bound rule (unlimited redemption), the once-per-visit
settlement rule (node events), the pay-what-you-get rule (purchases), and the
no-control-overlaps-body rule (sect-join screen). Each fix restores the rule at the exact
short-circuit point, reusing an in-repo pattern; none touches a balance number, a protected
file, or one of the three verbatim-pinned gates.

Design decisions (the reviewer's Step-1 flags are each resolved explicitly):

| # | Decision | Chosen | Why (and which alternative was rejected) |
|---|---|---|---|
| D1 | Soft-lock exit shape | Empty-GONGFA accept → status message + `phase="ATTR_PICK"` + `_after_action()` (month advances through the single advance path); empty-branch button relabeled 返回行动 → 度过本月; **no** default attribute grant | Mirrors `_fast_forward:698-705`'s transition+advance. NOT calling `_apply_action({"kind":"cultivate"})` like the debug twin: that would inject a new reward (+1..3 attr) and one RNG op — a balance-behavior change, banned. The two soft-lock-era nails pin the dead-end and get re-pointed (change table in §5.1); they are NOT in the verbatim-protected trio |
| D2 | Facility limit form | **Per-month cap = 2** (constant `FACILITY_MONTHLY_USE_CAP`), epoch pair in the GameManager session mirror | Surveyed every facility-bearing scenario: `facility_use_reusable` (2 uses, 2 entries, month 36) and `map_facility_buttons_click` (2 uses, 2 entries, month 36) — max 2 uses/month anywhere → cap 2 keeps all green and actually bounds the exploit (measured: 40 presses → +81 bone becomes ≤ 2 uses = +4/month). Per-entry-1 also survey-clean but only slows the farm 3× (leave→F re-enter per use); per-month-1 reds gate (a) outright. Reviewer's boundary-risk note answered by the survey table in §5.2 |
| D3 | Re-settlement suppression key | Session mirror keyed by **`"<node_id>/<event_id>"`** per (node, event) pair | Reviewer flag resolved: an event-id-global flag would let a cultivation bag-draw of `night_rain` suppress the shaolin node binding — the two channels are documented independent (§8.2). Re-show stays unconditional; suppression hits only the effect application; `events_resolved_count` still increments (the count tracks RESOLUTIONS — gate (b) pins count==3 on re-fire legs) |
| D4 | Purchase refusal semantics | Validate-then-apply inside `EventLogic.apply_option_effects` (returns a status); a refused option **resolves the encounter with nothing applied** + on-screen receipt (map: panel closes → TRAVEL; cultivation: month still advances; facility: unchanged — its own pre-check stays) | "Refusal keeps the panel open" (facility-shape verbatim) was rejected for the map EVENT phase: that phase has no leave key, so an all-refused event (e.g. a broke player at pool event `dali_market`, both options −18/−14) would be a NEW soft-lock, and every scripted pick's affordability would become load-bearing against a PROTECTED gate. Refusal-resolves is trap-proof and timeline-proof: count still increments, so gate ladders cannot shift even if some scripted pick turns out unaffordable |
| D5 | Occlusion fix surface | `scenes/segments/sect_select.tscn` geometry only: BodyLabel `offset_right 320 → 110`, SectButton0..4 x `(-120..120) → (+130..+370)` | The brief protects `sect_select.gd` but NOT the `.tscn` (reviewer-verified). Narrowing the body is REQUIRED, not optional: the Tang-Men row's text extends past x=+120, so merely sliding the buttons right would still cover the tail. Autowrap at 430 px forces every row to wrap before x=+110; buttons at +130.. clear it. No font scale, no copy, no script change |

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
5. `scenes/segments/sect_select.tscn` button column and body width geometry (numbers in D5).

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

 playtest harness ─── 4 new scenario files + 2 re-pointed nails + surface appends in
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

### 6. `scenes/segments/sect_select.tscn` — occlusion (D5)
- 职责: presentation-only de-overlap; `sect_select.gd` untouched; global theme untouched.
- 接口: BodyLabel `offset_right: 320 → 110`; SectButton0..4 `offset_left: -120 → 130`,
  `offset_right: 120 → 370` (width 240 and all y offsets preserved). Result: body text wraps at
  430 px (every row clear of x=+110), buttons occupy absolute x 610..850 inside the 960 viewport,
  20 px gutter. All five body rows (incl. the Tang Men row) render fully.

### 7. Playtest contract (repo's own harness — `playtest/_common.yaml` + per-scenario files)
- 职责: pin the four repaired rules with differential nails; re-point the two soft-lock-era nails.
- 契约 (all appends additive; two-place sync with `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS`):
  - New surfaces (append to `_common.yaml` `surface:`):
    `MapScreen: [map_status_text, event_open_silver, last_apply_attr_value, last_use_silver, last_use_attr_value]`,
    `CultivationScreen: [month_before_accept, status_text]`.
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
  - Occlusion gate: PRIMARY = same-frame before/after pair (current-tree f210 sect frame vs
    post-fix f210) recorded in the delivery notes — the brief's sanctioned evidence.
    OPTIONAL additive geometry asserts (`BodyLabel: offset_right == 110`,
    `SectButton0: offset_left == 130` — two single-node property asserts that together prove
    non-overlap) appended additively to `spine_to_ending.yaml`'s f210 block ONLY after the
    implementer verifies `impl.py` resolves node properties (in-repo asserts already read
    `visible`/`text` properties; cross-node expressions remain unverified and are NOT relied on).
    Do not lean on the vision gate — Q6 asks truncation, not occlusion.

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
2. **Protected files**: `assets/themes/global_theme.tres`, `scenes/ui/{roster_panel,tutorial_overlay,hud}.tscn`,
   `scripts/autoload/theme_manager.gd`, `scripts/segments/sect_select.gd`, the focus-style
   stylebox-swap portion of `cultivation.gd::_rebuild_options_box`, the six huashan-round files.
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
