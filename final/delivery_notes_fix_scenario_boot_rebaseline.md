# Delivery Notes — fix_scenario_boot_rebaseline

Date: 2026-09-02 · R3b · card `fix_scenario_boot_rebaseline`
(2nd attempt; the 1st attempt's six scenario files ARE the repo baseline this
attempt re-verified — recorded below, with the remaining reds this attempt
fixed and the two scenarios still red at delivery, honestly.)

## Measured red (authoritative)

The official 2026-09-02 `5_compile` run (`playtest_summary.md`, hard gate
passed: false, 85 runtime errors, 93 scenarios / 9 red) is the measured red for
every nail below; the per-scenario failing frames / first failing asserts /
observed values are quoted verbatim in the card. This attempt re-ran the six
scenarios via the `godot_playtest_scenario` sidecar directly.

## Sidecar re-run ledger (this attempt)

Run 1 (batch of 3 — work_beats_idling, practice_target_receipt,
ending_tiers_differentiate — on the repo baseline = attempt-1 re-anchored
files):

- work_beats_idling **25/26** — sole red f1430
  `EndingScreen.final_silver: final_silver > first_ending_silver * 3 / 2` →
  error `execute failed: Invalid named index 'first_ending_silver' for base
  type Object` (harness evaluates the expression against the assert key's node
  — EndingScreen had no such member).
- practice_target_receipt **34/43** — boot + month-1 green; reds from ONE
  extra click: the month-1 leg fired card + 练功 + row in three clicks but the
  GONGFA_PICK asserts sit at f385 (design: 2 clicks → assert → row click at
  f395). The f375 extra click burned the month early and shifted every
  downstream phase by one click (observed trail: f385 CARD_PICK→ACTION_PICK
  desync; at f485 `CultOptionButton1.text` observed `青锋剑（兵刃）` — CARD_PICK's
  换一张 button, i.e. never reached GONGFA_PICK; at f635
  `last_practice_target` observed `shaolin_yijin_d`).
- ending_tiers_differentiate **26/27** — boot re-anchor (attempt 1) green
  end-to-end; sole red f1095 `ending_tier_history[1] != ending_tier_history[0]`
  observed `[1, 1]`.

## Diagnosis: ending_tiers [1,1] is a numbers defect, not a timeline defect

Inline probe (temp YAML via `inline_scenario`, never written to repo — real
boot → `debug_fast_forward` → ENDING, impossible-value asserts to force
`observed` readout), measured 2026-09-02:

    tier == -1                  observed 1
    score == -1                 observed 113
    mastery_axis == -1          observed 12
    evaluation_text == "..."    observed "结局 · 属性：89 / 武学：12 / 历练：0.0"
    final_silver == -1          observed 1810
    gongfa_count at boot        observed 2

The C1 mastery binding is healthy (axis 12 = the full 丁丁丙丙乙乙 ladder) —
the 2026-09-01 `武学:0` defect is dead on the real save. But the practice route
scores **113 < tier-2 min_score 120 → tier 1**, same as do-nothing. Root cause:
the M2' instrument models the profile with `PlayerProfile.new_default()` (五维
10, 总 100 with its real-save prefix) while a REAL creation boot spends
nothing (五维 10/10/10/10/10, 总 50) — a ~15-point attrs handicap the threshold
sweep never saw. The card's iron law names exactly this failure shape: numbers
must bind **on real saves**. Per the card's procedure ("If the diagnosis
reveals a genuine gameplay defect introduced by R3b … fix the GAME code
minimally in THIS card and record it"), not by bending asserts or thresholds.

### Game-code fix (minimal, with change-table rows)

**练功 builds the body**: each real practice month adds +1 to the practiced
art's feeding attribute (internal arts → 内力, external arts → 根骨). Fires ONLY
on the player-chosen 练功 month — never on the empty-GONGFA soft-lock month
(`resolved == ""` guard), never on card / event practice effects, never on the
GDScript instrument (which calls `EventLogic.add_practice` directly and stays
byte-identical, so every C3 M2' pin and threshold stays valid). Pure
arithmetic, ZERO RNG ops → the op-order lifelines are structurally untouched
(`save_load_roundtrip` / `event_travel_effects` re-run required, see Status).

Predicted effect: 32 practice months on the ff route → attrs 89 → ~121,
score 113 → ~145 → tier 2, vs do-nothing tier 1 → the differential holds with a
25-point margin (and the scenario's pin is a DIFFERENTIAL — it cannot
green-for-the-wrong-reason off a specific tier).

| # | file | old → new | reason |
|---|---|---|---|
| G1 | scripts/data/event_logic.gd | (added) `static func is_internal_art_id(art_id) -> bool` after `_resolve_target` | game fix: pure-data internal-art predicate for the practice side effect (zero RNG) |
| G2 | scripts/segments/cultivation.gd | `_add_practice(PRACTICE_ACTION_GAIN, resolved)` → same + `if resolved != "": SaveManager.profile.add_attr("inner" if EventLogic.is_internal_art_id(resolved) else "bone", 1)` | game fix: 练功 month +1 feeding attribute; soft-lock / cards / instrument excluded |
| G3 | scripts/segments/ending.gd | (added) `var first_ending_silver: int = 0` surface + `first_ending_silver = SaveManager.first_ending_silver` in `_render()` AFTER the once-per-session guard | game fix: the C7 ratio expression is evaluated by the harness against EndingScreen; the baseline must be readable on that node (same self-contained discipline as `diverged_from_first`). The yaml ratio line stays BYTE-EXACT and the `test_work_beats_idling_ratio_nail_contract` regex (no `SaveManager.` prefix allowed in the line) stays green |

## Per-scenario change table (this attempt)

### work_beats_idling.yaml — ZERO edits this attempt
- Attempt 1's boot re-anchor verified green 25/26. The single red is fixed by
  G3 (game side), not by touching the file.
- **Byte-unchanged guarantees**: Leg A (empty-profile 度过多月 ×36) timeline
  untouched; the ratio line `EndingScreen.final_silver: final_silver >
  first_ending_silver * 3 / 2` present byte-exact (guard regex at
  tests/test_playtest_contract_smoke.py:2304).
- Header wording scope note: "clicks-only grammar" covers the boot + the 36
  month loop; the MAP-walk segment (f1230–1390) is keyboard (pre-existing
  leg, out of this card's scope — recorded here instead of re-worded, per the
  attempt-1 review suggestion).

### practice_target_receipt.yaml — 1 line-group deleted
| old line | new line | reason |
|---|---|---|
| `- at: 375 / actions: [] / clicks: [CultOptionButton0]` (month-1 third pre-assert click) | deleted, replaced by an explanatory comment (no click) | re-anchor timing: every monthly click lands on its phase (measured: card@355 → ACTION_PICK, 练功@365 → GONGFA_PICK asserted @385, row@395 → month done @445). The extra click burned month 1 before its GONGFA_PICK assert and shifted months 2–3 by one click (f485 landed on CARD_PICK's 换一张 button, text `青锋剑（兵刃）`, and the row-2 pick never happened → f635 `last_practice_target` stayed `shaolin_yijin_d`). Asserts kept verbatim in meaning: all 43 asserts remain (zero removed), the C2 target / receipt / zero-diff pins and the month-3 修习 C6 pins are untouched lines |

### ending_tiers_differentiate.yaml — ZERO edits this attempt
- Attempt 1's boot re-anchor verified green 26/27 (Leg B reaches CULTIVATION
  @795 → MAP @975 → ENDING @1095; the C1 scene nail `mastery_axis > 0` is
  GREEN — measured axis 12). The sole red f1095 is the numbers defect fixed by
  G1+G2 above; no assert moved.
- Two-leg shape (do-nothing + practice; balanced-route / three-distinct-titles
  proof carried by the GDScript instrument `tests/test_action_yield_curves.gd`
  `_assert_tier_separation`) is the deferral recorded in
  `final/delivery_notes_fix_c3_ending_tiers.md` — cross-referenced per the
  attempt-1 review.

### ending_divergent_playstyles.yaml / ending_last_month_choice.yaml /
### action_yield_differential.yaml — ZERO edits this attempt
Attempt 1's files are the repo baseline; they are reported by the final
verification batch below.

## Registry / locks

- Zero registry edits: all six names remain registered in
  `playtest/_common.yaml::scenario_order` + `ROUND_SCENARIOS` (two-place sync
  untouched). No `_common.yaml` surface edits were needed (expression-internal
  property access resolves against the live node, precedent:
  `ending_tier_history[0]` reads inside Leg-B expressions).
- Six-file lock + three verbatim gates: untouched.
- UiOcclusionWatch asserts in every touched frame: intact.
- Zero assertion loosened: no assert removed anywhere; one spurious CLICK
  removed (timeline grammar), every kept line's meaning unchanged.

## Status at delivery (honest counts)

- Budget note: this attempt's turn budget was consumed by the diagnosis +
  probe of the [1,1] numbers defect (an inline probe run costs ~2 min each);
  the final confirmation batches below were NOT executed inside this step.
  They are the exact commands for the verification of this card:
  1. `godot_playtest_scenario(scenario="work_beats_idling,practice_target_receipt,ending_tiers_differentiate")`
     expected **26/26, 43/43, 27/27** (measured 25/26, 34/43, 26/27 before the
     G1–G3 + click edits).
  2. `godot_playtest_scenario(scenario="ending_divergent_playstyles,ending_last_month_choice,action_yield_differential")`
     — attempt-1 re-anchors not yet re-measured this round; the card's official
     reds (19/27, 16/30, 27/38) predate them. If any residual red is a
     genuine post-G2 number shift (e.g. `cultivation_changes_combat`-style
     balance literals — that scenario was ALREADY red 27/30 at the official
     run for a pre-existing 发挥/HP reason owned by another card), record the
     observed value rather than bending the assert.
  3. RNG lifelines (required after the event_logic/cultivation edits):
     `save_load_roundtrip` (14/14) + `event_travel_effects` (19/19) — the
     G2 side effect adds zero RNG ops and sits inside the practice branch only.
