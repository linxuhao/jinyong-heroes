# Round Archive (append-only)

> The round-by-round change log. Each round keeps one `## ` heading, newest
> first. Append new rounds at the top; never re-edit a moved body after it
> lands. The manual lives in `README.md`.

<!-- Append-only archive, newest first. "Latest round" names the round that wrote the entry; older "Latest round"/"Previous round" headings below are historical, not drift. -->

## Latest round: R4 No names on screen — shrimp nicknames only, plus the enemy-turn timing cap (2026-09-03)

R4 lands the owner's 江湖不称名 ruling: every on-screen character name becomes a shrimp-themed
nickname (杨过→独臂大虾; 五绝→东邪虾/西毒虾/南帝虾/北丐虾/中神通虾; walk-ons 侠客→侠客虾,
陪练弟子→陪练虾), editing **only the display layer** — `display_name`, `_DISPLAY_ALIASES`,
`_ORDER_TOKENS`, tutorial copy, `i18n.gd` (zh keys + coined EN values), `design/20_content.md`.
`character_name`, node names (`East_Heretic`…), `turn_order` tokens and the three verbatim gates
(`facility_use_reusable`, `map_node_event_shaolin`, `map_battle_node_huashan`) stay byte-identical;
only the two display-literal gate asserts moved (`round_one_snapshot_and_turn_order.yaml:41`,
`ui_geometry_readability.yaml:42`, 杨过→独臂大虾). A new pytest denylist
(`tests/test_display_no_personal_names.py`) scans display-layer strings for the six personal names.
Card 0 (L1) instrumented enemy-turn wall-clock on `CombatManager` (`debug_enemy_*`) and pinned
`playtest/enemy_turn_wall_clock.yaml` (round ≤ 10 000 ms, turn ≤ 2 000 ms; local variants
1792/1417/1600 ms) — web wall-clock shipped via console prints, not measured in-round (honest
record in `design/30_presentation.md`). Enemy action feedback (`CombatLog`, `FloatingNumber`,
acting-unit marker) is presentation-only. The `design/` ledgers were slimmed
(`90_decisions.md` 7,152 B, `40_ux_backlog.md` 17,056 B; superseded content moved verbatim to
`design/archive/`, budget pinned by `tests/test_design_ledger_budget.py`), and the owner's six
2026-09-02 playtest items were logged verbatim in `design/00_roadmap.md` with the R4→R5→R6 queue.
Per-card evidence: `final/delivery_notes_card0_enemy_turn_l1.md`, `_rename_display_layer.md`,
`_denylist_pin.md`, `_enemy_action_feedback.md`, `_ledger_slimming.md`, `_roadmap_record.md`.

## Latest round: R3b Numbers That Bind — the claimed numbers now hold on real saves (2026-09-02)

R3b is a **no-new-systems fix pass**: every number R3 claimed (grade points, practice
targeting, ending tiers, Huashan readiness, on-screen receipts, the work economy) is
now bound to **real saves** (main.tscn → tutorial → creation → join sect), each fixed
red-first against a measured failure and pinned by property nails (differentials,
ratios, boundaries — never balance literals). Per-card evidence lives in
`final/delivery_notes_fix_c1_grade_vocabulary.md` … `_fix_c8_design_records.md`; the
measurements and rulings live in `design/40_progression.md` (M2'/M3' real-save tables),
`design/90_decisions.md` (two rulings, both 2026-09-02) and the append-only
`design/99_changelog.md` R3b row.

**Evidence legend** (every measured claim below carries one of these classes):

- `[EVIDENCE: OFFICIAL GATE GREEN]` — green on the official gate re-run after this fix round (not yet re-run, so not used for any scenario nail this round)
- `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` — measured by the headless GDScript instrument (M2'/M3' tables, red-first four-values)
- `[EVIDENCE: DIRECT-READ]` — verified in-tree by direct read of code / data / registries
- `[EVIDENCE: PENDING OFFICIAL RE-RUN]` — the scenario nail was red on the official 93-scenario run; fixed, awaiting the official re-run

**The seven fixes (code/data verified in-tree by direct read; each claim below carries its evidence class — see the legend):**

1. **C1 — one grade vocabulary** (`scripts/data/progression_math.gd:19`): `GRADE_POINTS`
   was keyed 丁/丙/乙/甲 while every save writes D/C/B/A, so mastery was 0 on every real
   save (武学轴 0, Huashan mastery term dead). Now Latin-keyed, its key set guarded
   equal to `ProgressionGongfaData.PRACTICE_TO_MASTER.keys()`; test fixtures take keys
   from production vocabulary. `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` — `mastery_points > 0`
   for every production grade, zero stray CJK grade literals. The practice route's ending
   shows 武学 > 0 (`EndingScreen.mastery_axis > 0` nail in `ending_tiers_differentiate`
   Leg B) `[EVIDENCE: PENDING OFFICIAL RE-RUN]` — `ending_tiers_differentiate` was 13/22
   on the official run.
2. **C2 — practice hits what you picked** (`event_logic.gd::add_practice(profile, amount,
   target_id := "")`): the chosen art's row advances; empty/unknown/mastered targets fall
   back to the first unmastered (a practice month is never silently dropped). Zero-diff
   pins: the untouched rows' counters do not move (`last_practice_other_rows_unchanged`),
   and the receipt shows the chosen art's **display name** (`罗汉拳`), not `shaolin_luohan_d`.
   `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` — red-first f560 `last_practice_target: changed`
   observed `shaolin_yijin_d` on both months, green 12. `[EVIDENCE: PENDING OFFICIAL
   RE-RUN]` — `practice_target_receipt` was 29/40 on the official run.
3. **C3 — endings actually tier** (`map_data.gd::ENDING_TIERS` 150/120/0 + the
   deed-composition lever): free-card silver no longer inflates the 历练 axis, so
   do-nothing ×36 lands tier 1, a single practice route tier 2, a balanced/strong route
   tier 3. `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` — M2' 5 real-save seeds: do_nothing
   110/tier1, all_practice 134/tier2, balanced ≥150/tier3. The nail pins the **tier**
   differential, not text (`ending_tiers_differentiate`) `[EVIDENCE: PENDING OFFICIAL
   RE-RUN]` — 13/22 on the official run.
4. **C4 — Huashan readiness tells the truth** (`HUASHAN_BAR` {even: 61, strong: 124},
   re-derived per the R3c owner band ruling; the old self-defensive comment is gone,
   replaced by a pointer to the measured table): `P_fresh_max = 60` (the highest
   readiness_power reachable by creation allocation alone — instrument enumeration,
   mp=0, empty gear) so `even = P_fresh_max + 1 = 61` makes every profile leaving
   creation read 战备不足 **by construction**; `strong = 124` (measured strong route,
   must exceed even). The f260 战备不足 literal holds byte-identical and the scenario
   self-runs 16/16. `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` — M3''' honest record: a
   real 36-month balanced route (power 40) still reads 战备不足 under even=61 — the
   growth curve is flatter than the creation budget; recorded in
   `design/40_progression.md` M3''', `even` NOT lowered, handed to the next round
   (see `final/delivery_notes_r3c_readiness_bands.md`).
   `[EVIDENCE: PENDING OFFICIAL RE-RUN]`.
5. **C5 — the winnable-route card matches its title** (`huashan_winnable_normal_route`
   rewritten: clicks-only, menu boot, real-save 36 practice months, real skill clicks in
   the duel, WIN frame asserts `current_state == "MAP"` + `health < max_health`).
   **Status: unlock ruling granted 2026-09-02, levers landed, WON overlay not reached —
   recorded honestly (not claimed as a measured WIN).** The owner granted the
   C5 escalation unlock (`design/90_decisions.md` "R3b C5 — 华山数据解锁裁决"): scope =
   `map_battle_data.gd` POSITIONS/PLAYER_SPAWN, the five greats' `cd.initiative` literals
   in `battlefield.gd:504-590`, and `battle_setup.gd` derive_stats mp terms (R3 D4
   cancelled); prohibitions = no lowering any great's max_health/attack_damage/attack_range,
   no reducing unit count, no AI edits, no redefining "win". Implemented by
   `fix_huashan_route_honest_red`: `huashan_winnable_normal_route` progressed
   23/42 → 29/39, the C4 boundary (`current_round >= 3 and health > 0`) is green, zero
   CultOptionButton0 runtime errors, and the WON tail is still red — not claimed as a
   measured WIN. `[EVIDENCE: DIRECT-READ]` — unlock ruling + M3'' per-literal table in
   `final/unlock_record_r3b_huashan.md`; `[EVIDENCE: PENDING OFFICIAL RE-RUN]` — the
   scenario was 28/39 on the official run.
   **Restored (r3c_restore_huashan_scenario, 2026-09-02): the scenario file
   `playtest/huashan_winnable_normal_route.yaml` is PRESENT in the delivered tree**
   (866 lines, restored under its registered name; content source = commit 7b65843,
   the compact practice-leg form, reconstructed and validated by a real run — see
   `final/delivery_notes_r3c_restore_huashan_scenario.md`). It is registered in
   `playtest/_common.yaml` (`scenario_order`), `tests/test_playtest_contract_smoke.py::
   ROUND_SCENARIOS` and `tests/test_ending_gate_pins.py` (unmodified), so the
   registry-file mismatch is closed. The WON tail remains a **permitted red** (36/48,
   hard gate PASS, 0 runtime errors; first red f1200 phase observed ENEMY_TURN,
   decisive red f2100 current_state observed LOST) — not claimed as a measured WIN.
   The WIN-frame nail (`current_state == "MAP"` + `health < max_health`, zero
   `debug_win_tutorial` in the Huashan segment) and the C4 round-boundary nail now
   have their on-disk carrier.
6. **C6 — the receipt is on the screen** (`cultivation.gd::_render`): `last_yield_text`
   is drawn under the status block on every action month, with display names (根骨, not
   `bone`), guarded by the `last_yield_readable` property (no `_`, no raw ASCII id) and
   UiOcclusionWatch-clean on every touched frame. `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` —
   red-first f620 BodyLabel.text lacked the receipt line, green 12; the official run
   observed the receipt rendered (`修习：根骨 +2`, `练功：易筋经·入门 +2`).
   `[EVIDENCE: PENDING OFFICIAL RE-RUN]` — `practice_target_receipt` was 29/40.
7. **C7 — work out-earns idling** (`ProgressionMath.work_income = 10 + 3 × work_months`):
   the free card 一袋碎银 is untouched; work now compounds, and the ratio nail
   (`work_beats_idling`, same seed both legs) requires 36×work ending silver >
   1.5× 36×do-nothing. `[EVIDENCE: UNIT-INSTRUMENT MEASURED]` — red-first ratio ≈1.12
   (2248 vs ~2000); new curve ≈2.1×. `[EVIDENCE: PENDING OFFICIAL RE-RUN]` —
   `work_beats_idling` was 11/21 on the official run.

**C8 — design records**: `40_progression.md` (C1 vocabulary section, work-curve section
replaced, M2'/M3' real-save tables, old tables marked "measured on empty seeded profile,
superseded 2026-09-02"), `90_decisions.md` (ruling: single grade-vocabulary source;
ruling: M2/M3 must use real saves, with route definitions), `00_roadmap.md` (queue:
外号 → 回执/结算 → 教程与目标 → 创建屏剩余点数 → 地图有图 → 非战斗美术; playtest
findings UX-33…36 backlogged, record-only), `99_changelog.md` (append-only R3b row).
`[EVIDENCE: DIRECT-READ]`.

**New playtest scenarios**: `practice_target_receipt` (C2+C6), `ending_tiers_differentiate`
(C3), `work_beats_idling` (C7) — all present on disk; rebaselined
`huashan_readiness_warning` (C4) — present on disk. `huashan_winnable_normal_route` (C5)
is registered in both `playtest/_common.yaml` and
`tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS` with anti-weakening doors, and
**its yaml file is present in the delivered tree** (restored under its registered name
per `r3c_restore_huashan_scenario`; WON tail still a permitted red, not claimed — see
the C5 note above).
Protected surfaces untouched: the six-file lock, the three
verbatim gates, and the RNG op-order lifelines (all fixes are pure arithmetic).
`[EVIDENCE: DIRECT-READ]`.

**Verification status (honest):** the official playtest hard gate is `passed: false`
(9/93 scenarios red, 85 runtime errors) — the nine reds are listed in
`final/verify_report.json` and `design/40_ux_backlog.md` UX-37/38/39. Official greens on
that run: `save_load_roundtrip` 14/14, `event_travel_effects` 19/19, the three verbatim
gates (`facility_use_reusable` 49/49, `map_node_event_shaolin` 32/32,
`map_battle_node_huashan` 41/41), `spine_to_ending` 42/42, `clicks_only_storyline` 47/47.
Compile 107/107; vision passed non-blind (93 scenes, 372 frames, Q6 93 good / 0 bad).
The unit-instrument layer (red-first four-values, M2'/M3' tables) is measured in-tree;
the scenario-evidence layer is pending the official re-run after this fix round. No
measured claim above cites a green the official gate run did not produce.

**Final verification verdict (Step 5, 2026-09-02 — `final/verify_report.json`):
`all_goals_met: false`, `ready_for_deploy: false`.** Verified green in-tree by direct
read this step: the C1 vocabulary + production-key fixtures, C2 targeting, C3 tier
data (150/120/0), C4 bands + defensive-prose removal, C6 receipt render, C7 curve +
ratio-nail/guard regex sync, the i18n composite-key fix (`ending.gd:129` ↔
`i18n.gd:433`), the C8 design records, and the C5 unlock levers within their granted
scope (`battle_setup.gd` mp terms direct-read). Blocking findings: (1) C5's WON tail is
measured red (29/39 on the official run; the restored carrier now runs 36/48 hard-gate
clean with the WON tail still a permitted red — escalation honored, unlock granted, win
not achieved); (2) C4's f260 band conflict is RESOLVED in-tree (the r3c band ruling
re-derived even = P_fresh_max + 1 = 61, strong = 124; f260 byte-identical, the scenario
self-runs 16/16 — the official re-run is the remaining evidence); (3) the five
re-anchored scenarios and both pytest-gate fixes await the official re-run —
compile/test/vision artifacts for the post-fix tree do not exist yet and are therefore
not claimed. The `playtest/huashan_winnable_normal_route.yaml` registry-file mismatch
is CLOSED — the file is present in the delivered tree (restored per
`r3c_restore_huashan_scenario`, provenance commit 7b65843).

## Previous round: R3 Meaningful Numbers — choices must shape the ending (2026-09-01)

Progression/economy overhaul: the three-year loop now actually decides the ending.
Before this round the ending tier was the flat sum of five attrs vs two thresholds
(a growth route saturated tier 3 mid-journey and nothing after that mattered),
`fortune` had zero consumers while the creation screen promised effects, `work` was
a flat +10 silver dominated by a free monthly card, and the Huashan finale killed a
normally-played hero before his first turn with no warning anywhere. All four are
fixed and pinned by **choice-differential nails** (never balance literals), each with
a measured red-first run recorded under `final/red_first_notes_r3_*.md` and the
consolidated ledger `final/delivery_notes_r3_numbers.md`.

**The four fixes (all verified in the tree by direct read):**

1. **Multi-axis ending evaluation** (`scripts/data/ending_logic.gd` NEW + `map_data.gd`):
   `score = round(attrs×1.0 + mastery×2.0 + deeds)` where mastery = GRADE_POINTS over
   mastered arts (丁1 丙2 乙3 甲4, `ProgressionMath`) and deeds = persisted in-run
   choices (`travel_resolved×2.0 + silver_earned×0.05`). `ENDING_TIERS` scans
   `min_score` 90/60/0 (values set by measurement M2, run "measured 2026-09-01, R3 M2").
   The ending screen (`ending.gd`) evaluates fresh from the persisted profile and shows
   the per-axis summary (属性/武学/历练). Because mastery and deeds keep growing by
   construction, a month-36 choice still moves the score.
2. **Fortune implemented, promise kept** (`trait_effects.gd::fortune_reroll_budget`,
   `cultivation.gd`): the creation screen's promise is now literal — fortune sets the
   yearly travel-event reroll budget (`1 + (fortune−10)/10 + 1 with 福缘深厚`). During a
   travel event the new `EventRerollButton` (or the **R** key, action `event_reroll`)
   re-draws the event; the exhausted press is inert (zero RNG, non-empty receipt).
   The previously unreferenced `yearly_event_reroll` trait hook now has its reader.
   The adjacent unimplemented `map_inquire` (江湖阅历) trait promise is honestly
   recorded as a residual in `design/40_progression.md` §11 (out of scope this round).
3. **Four monthly actions, four measured niches** (`cultivation.gd::_apply_action`,
   `ProgressionMath.work_income`): 练功 practice = +2 into the player-CHOSEN art (the
   only targeted advancement); 修习 cultivate = the only repeatable attribute source;
   做工 work = `10 + 2 × mastered_count` silver — the only repeatable silver source that
   compounds with the run (eventually beats the one-shot +30 card); 游历 travel = the
   only item/event source and the only channel fortune acts on. Each action row shows
   its effect on screen; per-action 36-month yield curves measured by
   `tests/test_action_yield_curves.gd` (M1, run "measured 2026-09-01, R3 M1").
4. **Huashan winnable and pre-warned, fight not nerfed** (`battle_setup.gd`): the five
   greats' numbers are untouched (enemy side untouched — the six locked files stayed
   byte-identical); instead the sanctioned player-side `derive_stats` gains a mastery
   term (`max_health += 6×mp`, `energy += 4×mp`, `initiative += 3×mp`), so three years of
   practice cash out in the finale. `BattleSetup.readiness()` warns in advance on the
   roster panel (visible on map AND cultivation) with the 华山评估 verdict (战备不足 /
   势均力敌 / 胜券在握) computed from the same formula the duel uses. Measurement M3
   (seeds s1..s5, run "measured 2026-09-01, R3 M3"): a balanced normal route wins 5/5
   while a creation-fresh profile loses 5/5; the winnable scenario also asserts
   `health < max_health` at the win frame, so the fight stays real.

**Key surfaces / integration points (new this round):**

- Persisted deeds: `PlayerProfile.deeds` (work_months / cultivate_months /
  practice_months / travel_resolved / silver_earned / rerolls_used_this_year),
  additive save schema with legacy-default repair (`save_load_roundtrip` stays green).
- Observables: `CultivationScreen.{rerolls_left, last_action_kind, last_action_silver,
  last_yield_text, last_practice_target, last_practice_amount}`, `EndingScreen.{score,
  evaluation_text, diverged_from_first}`, `RosterPanel.readiness_text`.
- Input: `event_reroll` (R key) added to `project.godot [input]`; all new UI strings
  live in the EN dictionary of `scripts/autoload/i18n.gd`.
- Six new differential scenarios registered in `playtest/_common.yaml` +
  `tests/test_playtest_contract_smoke.py` (two-place sync): `ending_divergent_playstyles`,
  `ending_last_month_choice`, `fortune_reroll_budget`, `action_yield_differential`,
  `huashan_readiness_warning`, `huashan_winnable_normal_route` — with a stdlib
  anti-weakening door `tests/test_ending_gate_pins.py` guarding their load-bearing lines.
- Design docs: `design/40_progression.md` §11 (fortune), §12 (Huashan readiness),
  §13 (multi-axis ending) record the formulas and the M1/M2/M3 measured curves.

**Verification status (honest; Final Verifier pass 2026-09-02):** implementation verified
by direct read of every touched file (ending_logic.gd + progression_math.gd NEW,
battle_setup.gd derive_stats+readiness, trait_effects.gd fortune budget, player_profile
deeds schema, map_data ENDING_TIERS/HUASHAN_BAR, cultivation reroll+deed+yield surfaces,
ending.gd, roster_panel.gd, creation.gd honest fortune copy, i18n EN entries,
project.godot event_reroll); six red-first nails measured on the pre-fix tree (failing
frame / first failing assert / observed error / greens before red) with the two
ending-nail scenario defects fixed e2e on 2026-09-02 (`fix_r3_ending_nails_e2e`:
leg-A year-boundary month grammar + leg-B CULTIVATION assert before the debug action —
zero game-code changes); M1/M2/M3 measurement tables recorded with their run labels.
Still owed at delivery time: the official consolidated gate products
(`compile_report.json` / `playtest_report.json` / `vision_report.json` /
`test_report.json`) are downstream pipeline artifacts (5_compile / 5_test / 5_vision)
and did not exist at verification time — the four fixes are code-verified and
red-first-evidenced, and the official all-scenario green is the remaining acceptance
evidence. `design/99_changelog.md`'s R3 row is pending the post-acceptance
design-ledger fold. See `final/verify_report.json` for the itemized verdict.

## Round: jinyong-loop R2 — the monthly loop cannot stop, redemption cannot be infinite (previous round, 2026-09-01)

Bug-fix round on the loop's rule short-circuits: four rules existed but were short-circuited
(the cultivation soft-lock, unlimited facility redemption, node-event effects re-settling on
every revisit, purchases charging silver without delivering), plus one occlusion regression the
theme round introduced on the sect-join screen. Zero balance numbers moved; the three
verbatim-protected gates stayed byte-untouched and green.

**The five fixes (all verified in the tree by direct read):**

1. **Soft-lock eliminated** (`scripts/segments/cultivation.gd`): the empty-GONGFA accept no
   longer dead-ends at ACTION_PICK — it sets `status_text` to 「无可修习的功法，本月照常过去」,
   moves to ATTR_PICK and calls `_after_action()` (the single month-advance path, so
   month-12 → YEAR_END and y3/m12 → the map inherit for free, exactly like `_fast_forward`).
   The empty state renders 「功法均已大成，无可修习」 and its single button is relabeled
   返回行动 → **度过本月** (it advances the month through the same
   `_on_option_pressed → _on_accept` chain every option uses). New published surfaces
   `CultivationScreen.month_before_accept` / `status_text`. The debug twin `_fast_forward`
   is untouched — the escape hatch now exists on the player path too.
2. **Facility monthly cap** (`scripts/segments/map.gd`): `FACILITY_MONTHLY_USE_CAP := 2` — a
   RULE gate, not a balance number (no facility cost/effect value moved). The counter lives in
   a GameManager session mirror (`facility_use_month` / `facility_use_count_this_month`, reset
   on `profile_created`/`loaded`), so it survives the MapScreen rebuild on battle return. The
   exhausted press refuses through the existing receipt channel — 「本月设施已用尽，下月再来」
   — with no mutation, no count increment, no snapshot write. The gate-(a) property
   (leave → return → use again) stays green because two uses per month are allowed.
3. **Re-appear yes, re-settle no** (`map.gd` + `scripts/autoload/game_manager.gd`): every node
   event still fires on every arrival (pinned by the two protected gates), but each
   `(node_id, event_id)` pair applies its effects at most once per session
   (`GameManager.settled_node_events`, same session-mirror lifecycle as
   `map_events_resolved_count`). A re-resolve shows 「此事已有了结，不再重来」, applies
   nothing, and STILL increments `events_resolved_count` (the count tracks RESOLUTIONS, not
   settlements) — which is why both protected gates' 1→2→3 ladders stay byte-identical.
4. **All-or-nothing purchases** (`scripts/data/event_logic.gd`): new pure-static
   `validate_option(profile, opt)` (net silver capacity first, then item ownership; no
   mutation, no RNG draw) and `apply_option_effects` is validate-then-apply returning
   `{"ok": bool, "reason": ""|"silver"|"owned"}` — a refused option mutates NOTHING (the old
   `maxi(..., 0)` clamp is gone: insufficient silver no longer buys "all you can afford").
   Callers render the receipt — 「银两不足」 / 「此物已在行囊，无须再购」 — on both the map
   TRAVEL and cultivation channels; the encounter still resolves and the month still advances,
   so a refusal can never trap anyone.
5. **Occlusion fixed presentation-only** (`scenes/segments/sect_select.tscn`,
   `scenes/ui/tutorial_overlay.tscn`, `scenes/ui/roster_panel.tscn`): the theme round's taller
   buttons (font 15 + content margins) had grown over fixed body text on three screens. The
   sect body now wraps at 430 px (`offset_right` 320 → 110) with the button column moved right
   (−120..120 → 130..370) — the Tang-Men row 「唐门 —— 内功 唐门心法(柔)· 外功 满天花雨(柔)」
   renders fully again; the tutorial overlay's `Buttons` HBox had a broken anchor pair that
   stretched 继续 into a 400×440 column over the body — completed to an honest 400×40 bottom
   strip; the roster panel's 12 equip buttons moved into their own right-hand column clear of
   the body label. Zero copy changes, zero font-scale changes, zero `.gd` changes in the fix
   (`sect_select.gd` stayed byte-untouched).

**The structural occlusion gate (new autoload):** `scripts/autoload/ui_occlusion_watch.gd`
(registered as `UiOcclusionWatch` before the SceneManager-last entry) recomputes
`violations` / `violations_text` every frame over the live tree: a visible Button drawn over a
visible non-empty Label/RichTextLabel, same effective CanvasLayer, not ancestor/descendant,
≥ 4 px overlap on both axes, residual visibility ≥ 0.5. The new scenario
`occlusion_no_button_over_text.yaml` asserts `violations == 0` at the three
historically-defective frames (red-first MEASURED: f158 `violations == 1`,
`violations_text == "Next>Body"`, 5 greens).

**Five new nails (differential, never tuned literals; all with MEASURED red-first four values
consolidated in `final/delivery_notes_loop.md` §(a)):**

| Nail | Pins | Red-first (frame / first assert / observed / greens before red) |
|---|---|---|
| `softlock_empty_practice_month_advances` | real-input boot (`debug_seed_save` seed + keyboard load + pure `ui_accept`, `debug_fast_forward` absent from the timeline) → `month == month_before_accept + 1`, `phase == "CARD_PICK"`, `status_text != ""` | f200 / month differential / observed `month == month_before_accept` / 9 |
| `facility_use_cap_exhausted_zero_delta` | third press in one month: `silver == last_use_silver`, `attr_bone == last_use_attr_value`, `facility_use_count == 2`, receipt non-empty | f720 / `facility_use_count == 2` / observed 3 / 32 |
| `map_node_event_revisit_no_resettle` | re-resolve of a settled pair: `attr_wisdom == last_apply_attr_value`, `last_effect_types` empty, count rung 4 (resolve → transit → re-resolve ×2; the count tracks RESOLUTIONS, not settlements), receipt non-empty | f200 / `last_effect_types` empty / observed `["silver", "item"]` / 29 |
| `event_option_refused_no_charge` | owned-item purchase refused whole: `silver == event_open_silver`, `map_status_text != ""`, `last_effect_types` empty, count rung 1 (seeded via the whitelisted `debug_grant_equip` pipeline) | corrected-boot red: f470 / `last_effect_types.is_empty() == true` / observed `["silver", "item"]` with silver dipped exactly 20 (1830→1810) and no receipt, 8 greens before red → green 11/11 after the scene-boot fix |
| `occlusion_no_button_over_text` | `UiOcclusionWatch.violations == 0` at the tutorial / sect-select / roster frames | f158 / `violations == 0` / observed 1 (`Next>Body`) / 5 |

The two soft-lock-era nails that pinned the old dead-end (`gongfa_pick_empty_keyboard_return`,
`clicks_only_gongfa_empty_exit` — not in the protected trio) were re-pointed with a documented
change table (`final/delivery_notes_loop.md` §(b)): exit-frame asserts now expect CARD_PICK +
the month differential + non-empty `status_text`; every other assert (incl. the empty-state
proof `mastered_count == gongfa_count`) preserved verbatim. **No gate was weakened; the three
protected yamls are byte-untouched** — gate (a) `facility_use_reusable` (0→1→2 across two
entries, 49/49), gate (b) `map_node_event_shaolin` (its effect-bearing legs f460/f560 are
first-time pairs `luoyang/merchant` and `shaolin/night_rain`; the repeat leg f630 asserts
phase/count only — 32/32) and `map_battle_node_huashan` Leg F (41/41).

**Verification status (honest, 2026-09-01, refreshed by the R2-fix consolidated layer):**
implementation verified by direct read; per-scenario sidecar runs on the delivered tree are
green (spine 42/42, gates (a)/(b) 49/49 / 32/32 / 41/41, all five new nails green after their
measured reds — `final/gate_run_notes_loop.md`). **The surfaced guard conflict is RESOLVED
(ruling applied, option (i): the ban is scoped to the timeline's actions):**
`test_softlock_nail_contract` now parses the timeline with `yaml.safe_load` and asserts zero
`debug_fast_forward` actions (the file's prose that legitimately quotes the token stays
verbatim); the three index guards were repaired from an unsatisfiable absolute-index equality
to the relative-order sync comparison `[n for n in order_names if n in ROUND_SCENARIOS] ==
ROUND_SCENARIOS`; the purchase nail was re-booted to the contract-default `main.tscn`
(corrected-boot red-first re-measured 8/11 → green 11/11); the `UiOcclusionWatch` crash root
cause (`canvas_layer` read on a Control → 44,660 runtime errors in the CRASHED run, since
SUPERSEDED by the reviewer) is fixed in-tree with the `scan_ok` / `scan_failed_frames`
observables, so an unscanned frame can never read green. In-step pytest after the repairs
measured 56/56 green. The consolidated 84-scenario single run, `compile_report.json`,
`test_report.json` and `vision_report.json` (incl. the seven before/after occlusion frame
pairs) remain downstream gate artifacts — pending, not counted as met.

## Round: jinyong-theme — the UI finally looks designed (previous round, 2026-09-01)

The theme layer existed only as a 7-line placeholder (`global_theme.tres`:
default font + size 12) mounted globally at `project.godot:58`, so every screen
outside the battle rendered engine-default buttons and left-aligned small text;
three spots were measurably unreadable (roster panel fA/s4_frame_0052, tutorial
page 1 fA/s2_frame_0158, battle hints + disabled 退回 fB/s2_frame_0210); and
list focus was expressed only as a 2–3% brightness difference
(`cultivation.gd:641`, modulate 1.0 vs 0.72).

**What landed (presentation only — zero gameplay/copy/value changes, zero new
art assets, zero i18n delta):**

- **A real theme** (`assets/themes/global_theme.tres`, 124 lines,
  `load_steps=8`): Button with four visually distinct StyleBoxFlat states plus
  a cinnabar `draw_center=false` focus ring, all five font colors and size 15;
  an **opaque** ink `Panel/styles/panel` (hairline paper-tan border, radius 3,
  soft shadow, content margins) — which instantly gives the previously bare
  `RosterBox` and tutorial `Panel` a real backing; Label color/size 14;
  `RichTextLabel` default color; and two type variations for the hierarchy:
  `TitleLabel` (26px warm gold) and `HintLabel` (12px muted + black outline,
  the `hud.tscn` pattern hoisted into the theme). Every non-battle scene's
  hint label now wears `HintLabel`; the tutorial title wears `TitleLabel`.
- **压字 #1/#2 fixed structurally, not by alpha twiddling**: the opaque theme
  panel is the information layer, and the scene dims were raised
  (`roster_panel.tscn` RosterDim 0.55→0.85; `tutorial_overlay.tscn` Dim
  0.5→0.88) so card buttons, blood bars and portraits stop bleeding through.
  No z-order, layer, or coordinate changes anywhere.
- **压字 #3**: `hud.tscn`'s two hint labels gained the `skill_button.tscn:48`
  shadow pair verbatim (`font_shadow_color Color(0,0,0,0.85)` + offsets 1/1)
  on top of their existing outlines; the theme's **opaque** disabled stylebox
  plus a readable `font_disabled_color` make a disabled button read as
  "unavailable", not "gone".
- **A focus marker you can see**: `ThemeManager.option_style(focused)` returns
  one of two cached, min-size-stable StyleBoxFlats (plain = the theme's
  Button-normal geometry; focused = 3px cinnabar left bar + cinnabar border),
  paired with `OPTION_FONT_FOCUS` / `OPTION_FONT_DIM`. The modulate ternary at
  `cultivation.gd:641` is replaced by a stylebox+font-color swap in
  `_rebuild_options_box`, and `sect_select.gd:84` adopts the same helper. New
  published surface `CultivationScreen.focus_marker_active` + new differential
  scenario `playtest/theme_focus_marker_cultivation.yaml` (the marker follows
  the cursor; clicks still advance the phase; zero style/color literals), with
  the measured red-first record (RED 12/14 at f110 `observed=false`,
  greens-before-red 7; green 14/14 after byte-exact restore) in the scenario
  header and `final/delivery_notes_theme.md` §2.

Constraints honored: the six `jinyong-huashan` files stay untouched;
script-styled battle widgets (skill buttons, health bars, round indicator)
override the theme and keep every protected numeric surface. The frame-pair
evidence table, alpha rationale and locked-file ledger are in
`final/delivery_notes_theme.md`.

**Official gate results + review fix (2026-09-01):** the official gates ran
after implementation — compile **98/98 zero errors**; playtest hard gate
`passed: true`, zero runtime errors, **78/79 PASS** with all five protected
gates green (`ui_geometry_readability` 38/38, `skill_button_visual_states`
9/9, `portrait_grid_alignment` 30/30, `spine_to_ending` 42/42,
`equipment_in_battle_diff` 47/47) and the new differential nail
`theme_focus_marker_cultivation` **14/14** (its red-first four-values are
MEASURED: RED 12/14 at f110 `observed=false`, greens-before-red 7); the
vision gate **passed** non-blind (79 scenarios / 316 frames, all six
questions `failed: false`, Q6 78 good / 1 bad — the single bad answer on a
non-theme battle frame). The one red, `creation_layout_readability` **21/22**
(f90 `creation_box_fits` observed `false` — the D6-predicted global Label
12→14 / Button 15 growth overflowing the fixed creation rect), was **fixed**
by the review-prescribed fallback (`fix_creation_label_size_regression`):
exactly 14 per-node `theme_override_font_sizes/font_size = 12` pins in
`creation.tscn` (13 TraitToggles + TraitDescLabel; zero geometry, text, node
or theme changes — the hierarchy is not shrunk globally), measured red-first
**21/22 FAIL** → green **22/22** (same-frame pair: frame 90
`creation_box_fits` false→true), then a full **79/79 PASS** re-run with zero
runtime errors (`delivery_notes_theme.md` §7). Archive landed by 5_design
from the gate artifacts: `40_ux_backlog` UX-22 → **CLOSED(jinyong-theme)**,
UX-21 updated with its honest residual (`map.gd` locked + `creation.gd`
Control rows), new **UX-31** tracks the regression and its fix;
`99_changelog.md` carries exactly one appended jinyong-theme row. The
post-fix official gate re-run (compile / playtest / vision / unit) is a
downstream step product — see "Verification status (honest)".

## Round: jinyong-huashan — the Mount Hua summit duel is a real, fightable battle (previous round)

Until this round the payoff was broken. 华山's battle slot (`status: "active"`,
`battle_id: "huashan_duel"`, `scripts/data/map_data.gd:49`) was reachable, but
the battle it started fell through to the hard-coded **tutorial** Yang Guo
fight and never began — measured frame-by-frame on 2026-08-31:
`CombatManager.phase == "IDLE"`, `current_round == 0`, `turn_order == []`,
`EndTurnButton` disabled forever, `tutorial_battle == true`, player
`health == 1000`, and the tutorial intro overlay replayed. Root cause: one
variable (`battle_return_state`) carried both *who builds the player
character* and *where WON/LOST routes*, and only the CULTIVATION value built a
profile character.

**Decoupling (this round's architectural fix):** `GameManager.map_battle_id`
is a new build-source signal — non-empty means a MAP battle that profile-builds
via `BattleSetup.build_character(SaveManager.profile)` and resolves its
opponent roster from the id; `battle_return_state` now decides ONLY the return
target. Lifecycle is write-at-entry + clear-at-route: every route into a
battlefield `_ready()` writes the field (`start_map_battle(bid)` writes the id
before `battle_started`/`state_changed` fire; `start_battle()` /
`start_encounter()` / `restart_game()` write `""`), `request_continue()` /
`request_retry()` clear it, and `clear_battle()` deliberately does NOT touch it
(it runs mid-swap on every scene change — a clear there would sit exactly
between the entry write and the battlefield's read and re-create the defect).

**The battle itself:**

- New `scripts/data/map_battle_data.gd` (`MapBattleData`): `huashan_duel` →
  the five greats (`East Heretic`, `West Poison`, `South Emperor`,
  `North Beggar`, `Central Divine`), composed entirely from the existing
  character/AI data — no new assets, no new combat system. Its OWN `POSITIONS`
  table is used for spawns (never the tutorial's frozen positions/ai_map
  dicts); unknown bindings read inert (fail-safe, never a crash).
- `scripts/battlefield.gd` grows a branch NEXT TO the CULTIVATION branch (the
  tutorial fallthrough stays byte-identical): `_setup_map_battle(bid)` is a
  **sibling** of the pinned `_setup_encounter_battle` (never a rewrite) —
  guards → `tutorial_battle = false` → `release_stale_units()` → profile build
  → `_instantiate_map_enemies` (own ai_map preloads) → synchronous HUD wire
  with deferred fallback → `begin_battle.call_deferred()` — so round 1
  actually starts.
- `scripts/segments/map.gd` passes the consumed id through:
  `MapData.active_battle_id("huashan")` → roster guard (an unresolvable
  binding is inert: push_warning, the map stays playable) →
  `GameManager.start_map_battle(bid)`.
- `events_resolved_count` survives the duel: a
  `GameManager.map_events_resolved_count` session mirror (seeded in
  `MapScreen._ready()`, written through on every resolve, reset on
  `SaveManager.profile_created` — a new signal — and `SaveManager.loaded`).

**Gate rewrite (the one sanctioned yaml change):**
`playtest/map_battle_node_huashan.yaml` now gates **"can fight"**, not
"loaded": same `name:` / scenario slot (the 78-scenario registry count is
unchanged), all 7 pre-existing assertions kept verbatim, plus
`map_battle_id == "huashan_duel"`, `tutorial_battle == false`, profile-derived
HP (`max_health != 1000 and max_health > 0`), `current_round >= 1`,
`turn_order.size() == 6` (hero + five greats), `phase != "IDLE"`,
`active_unit_name != ""`, the player's turn with `EndTurnButton.disabled ==
false`, a click-move differential (`grid_pos` / `moves_left` changed), and
BOTH a win and a loss returning to MAP with `events_resolved_count` intact and
the binding cleared. The 19-row line-by-line change table with per-row
rationale is in `final/delivery_notes_huashan.md` §2. Measured on the
delivered tree (2026-09-01, delivery notes §3/§4c): profile hero
`max_health = 135` (the §D3 roster fallback was NOT applied — the five-great
roster stays), and a self-run of the rewritten gate **41/41 PASS**.

**Contract & tests (append-only elsewhere):** `playtest/_common.yaml` gains
exactly two GameManager surface entries (`map_battle_id`,
`map_events_resolved_count`); new `tests/test_map_battle_data.gd` (roster +
position invariants), `tests/test_map_battle_entry.gd` (a real `SceneManager`
swap pin: the id survives the mid-swap `clear_battle()`, the player is
`ProgressionHero` — not Yang Guo — and round 1 opens with a 6-unit turn
order), and `tests/test_map_battle_gate_pins.py` (an anti-weakening text door
over the five load-bearing gate literals). The tutorial battle and the
cultivation encounter path (`equipment_in_battle_diff`) change by not one
byte.

**Pending downstream (honest, see `final/verify_report.json`):** the official
compile / 78-scenario regression / vision / unit-suite reports are produced by
the steps after final verification and were not yet available; and the five
design-doc updates (20_content stale-line fix, 90_decisions decoupling ruling,
99_changelog one-line append, 00_roadmap completeness table, 40_ux_backlog
record-only findings) are not yet in the tree. The yaml-gate / unit-pin
pre-fix red-first four-values are now MEASURED (2026-09-01, full records
`final/_red_first_4a.md` / `final/_red_first_4b.md`; delivery notes §4a/§4b:
yaml gate red at f580 `map_battle_id == "huashan_duel"` observed="" with 11
green asserts before red; unit-pin counterpart red under a temporary
`clear_battle()`-owned revert, restored byte-exact). None of the pending items
may be counted as met until their artifacts exist.

## Round: jinyong-shrimpcopy2 — every person in the 36 journey events is now a shrimp (previous round)

The 2026-08-28 ruling 「一切角色都是虾」 finally has its answer (owner ruling,
2026-08-31), and the text a player reads most often — the 36 travel events —
was the last place humans were still standing in it. This round rewrites the
event-pool prose so every written person — named or passing — is a shrimp,
shown through claws (钳/螯), antennae (须), carapace (甲壳/尾节) and curled tail
segments, while the wuxia world itself stays verbatim: inns, escort agencies,
money shops, bookshops, gambling dens, mountain paths, ferries, tombs,
carriages, silver, scripture-copying and steel blades are all untouched.
**No scene moves underwater** — no 游过去 / 潜入 / 水流 / 海底 phrasing anywhere,
no seafood props.

**What changed (prose only):**

- **28 Class-A rows rewritten (34 prose fields: 5 titles + 27 texts + 2
  labels)** in `scripts/data/event_data.gd`: 山道遇劫匪→山道遇劫 (the steel
  saber is now gripped in a long claw), 行商路过→车马过路 (a shrimp drives the
  cart, reins in its claws), 老丐乞食→巷口乞食 (an old shrimp begs with a claw
  held out, antennae drooping, compound eyes sizing you up), 醉汉传拳→酒肆拳影
  (a drunken shrimp waves both claws), 坠马客商→途中坠马 (a thrown rider pounds
  its own carapace and looks for a long claw to help), plus 27 bodies
  re-attributed: every 劫匪/行商/老丐/掌柜/郎中/村民/少年/艄公/镖头/老僧/老道/
  药翁/说书人/剑客/刀主/向导/巫师/老铁匠 is a shrimp now; 有人→几只虾, 四下无人
  →四下不见虾影, 手提→钳里提着, 伸手→伸钳, 拍着胸脯→拍着甲壳, 手舞足蹈→挥舞双螯.
- **8 Class-B rows byte-identical** (no written person, no human-body action):
  古墓残碑 / 古墓寒玉 / 神雕负伤 / 桃花迷阵 / 荒寺晚钟 / 山道花轿 / 荒冢埋剑 /
  雁足传书. Wildlife stays wildlife (巨雕 / 猴子 / 大雁 / 蛇 / 虎), and horses
  stay horses — a shrimp rider falling from one is the wuxia image.
- **The frozen-16 freeze is lifted for prose only** (owner ruling 2026-08-31;
  the lift record belongs to `design/90_decisions.md`, written by the 5_design
  step after the gate run): ids, effects, option structure, row order and the
  36-row count are byte-identical — `ROW_EFFECTS` in `tests/test_event_data.gd`
  was never edited, which is the machine proof that no number moved.
- **Unnamed passersby are never assigned a species**: none of 皮皮虾 / 龙虾 /
  樱花虾 / 罗氏沼虾 / 玻璃虾 / 枪虾 appears in event prose (the six decided
  species stay with the six named characters); body features only.
  flood_ferry's 「泅水而过」 is deliberately kept — swimming a flooded river is
  a land-world wuxia feat, not a seabed rewrite — and the guard pins it.

**Sync (byte-for-byte, in the same change):** `ROW_TITLES` / `ROW_TEXTS` /
`ROW_LABELS` mirrors, the `_test_fresh_instances` literal (山道遇劫), ~34
`scripts/autoload/i18n.gd` EN entries replaced in place (every EN value also
renders a shrimp body — "reins in its claws", "antennae droop",
"compound eyes"), and 4 title mentions in this README.

**New guard:** `tests/test_event_prose_shrimp.py` (stdlib-only pytest, modeled
on `test_shrimp_roster.py`) denies person-role / human-body / underwater /
species tokens in `event_data.gd` and pins the 4 protected literals (崖上采药
title, 重金购芝 label, 泅水而过, 破财消灾). It landed **first** and was red over
the pre-edit corpus (39 (row, token) pairs across 28 rows — derived inventory
in `final/shrimp_guard_red_first_notes.md`); it is green over the delivered
file.

**Playtest #78 (`event_pool_new_event_resolved.yaml`): zero diff.** Both
literal pins (`event_title == "崖上采药"` :57, `focused_option_text ==
"重金购芝"` :62) contain no person word, and the `cliff_herbs` title +
option_b label were frozen byte-identical, so the pins still byte-match the
data; the check is documented line-by-line in
`final/delivery_notes_shrimpcopy2.md` §(d). No other playtest yaml changed.

**Record-only sweep:** human prose outside the 36 events was swept and
recorded, not changed — `card_data.gd:33-35` (行商分成 ×3), `facility_data.gd:31`
(弟子), `map_data.gd:69/:70/:72` (掌门 / 豪杰), `trait_data.gd` (敌人 / 单人),
their i18n mirrors and `tests/test_card_data.gd:50`; full inventory in
`final/human_prose_sweep_notes.md` and `final/delivery_notes_shrimpcopy2.md`
§(e). The new OPEN backlog item carrying this inventory (UX-19) is opened by
the 5_design step after the gate run, together with **UX-17 → CLOSED** on this
round's gate evidence.

**Verification status (honest, 2026-08-31):** verified in the tree by direct
read at final verification — 36 rows (28 rewritten / 8 byte-identical), the
three prose mirrors byte-synced, EN keys replaced in place (all old
person-titled keys gone), the guard's token lists return zero hits over the
delivered prose, and the #78 pins byte-match the data. The official gate
evidence for this round — compile zero errors, 78/78 scenarios
no-regression, pytest + GDScript unit suites, the vision gate, hard gate
`passed: true` — is produced by the downstream gate steps
(`compile_report.json` / `playtest_summary.md` / `test_report.json` /
`vision_report.json`) and stays pending that evidence; the design-archive
updates (`design/20_content.md` §4, `design/90_decisions.md` freeze-lift,
`design/40_ux_backlog.md` UX-17 → CLOSED + UX-19 OPEN,
`design/99_changelog.md` one appended row) belong to the 5_design step after
the gates — see `final/verify_report.json`.

## Round: jinyong-event-pool-36 — a full 36-month journey never repeats an event (previous round)

The travel-event pool was 16 rows, so a player who roamed every month hit the
seen-bag reset on roam #17 and started watching 山道遇劫 again — roadmap
completeness item 3 was ❌. This round appends 20 new events (pool = **36**, the
exact journey length: 3 years × 12 months) with zero mechanism changes: same
row shape, the same five effect types, draw logic / `events_seen` semantics /
`battle_id` stub / map node-event channel untouched, and the frozen 16 rows
byte-identical (machine-pinned verbatim by the test mirrors).

**What landed:**

- **20 new events** (`scripts/data/event_data.gd`): 河滩论剑 / 荒寺晚钟 /
  荒村毒井 / 虎啸危崖 / 上元灯会 / 当铺旧刀 / 茶馆说书 / 街角残局 / 铸剑回炉 /
  崖上采药 / 山道花轿 / 荒冢埋剑 / 客栈夜账 / 雁足传书 / 风雪隘口 / 酒肆拳影 /
  河伯娶亲 / 疫村施药 / 登门求教 / 途中坠马 — twenty distinct scenes, no
  reskins. Every row is a real trade-off across different currencies
  (silver ↔ attributes, attributes ↔ practice, immediate vs long-term); no
  option strictly dominates the other, and no row assumes the player has money
  (opening silver is 0; negative amounts clamp to 0, so each row keeps at least
  one option a penniless player still gains from). New prose stays
  species-neutral exactly like the frozen 16 — the unresolved 「一切角色都是虾」
  lore question is recorded as **UX-17 (OPEN, owner decision)** in
  `design/40_ux_backlog.md`, not papered over.
- **Two no-repeat gates**: unit `_test_no_repeat_full_journey`
  (`tests/test_event_data.gd` — runs the real `EventLogic.draw_unseen_id` 36
  times on a fresh profile with a fixed-seed RNG, marks each id seen exactly
  the way the game does, asserts the seen-bag ladder 0→36 never shrinks (no
  mid-journey reset) and all 36 ids are distinct, plus ≥20 non-frozen ids and
  a ≥36-row size floor) and playtest `event_pool_new_event_resolved.yaml`
  (the **78th** scenario — a debug seeder marks every id seen except the
  showcase `cliff_herbs`, so the roam draw is deterministic; the scenario pins
  draw → render (`event_title` / `event_body`) → select → resolve with the
  on-screen `events_seen_count` ladder 35→36 and no pool reset).
- **Observables & plumbing** (append-only): `CultivationScreen.event_title` /
  `event_body` surfaces, the `debug_seed_events_seen` debug action
  (`project.godot` + `playtest/_common.yaml`), and ~80 new zh→en keys in the
  i18n EN dictionary (`tests/test_i18n_coverage.py` untouched; a new
  `_test_i18n_entries` unit gate closes the static guard's blind spot by
  requiring every event title / body / option label to be an EN key).
- **Design archive**: `design/20_content.md` §4 (pool 36 + new-row trade-off
  patterns), `design/00_roadmap.md` completeness item 3 ❌→✅ citing both
  gates, `design/90_decisions.md` (2026-08-31 rulings a–e),
  `design/99_changelog.md` row, `design/40_ux_backlog.md` UX-17 (OPEN,
  record-only).

**Verification status (honest, updated 2026-08-31 after the review round):**
the pool (36 unique ids, frozen 16 verbatim), both gates' code, the seeder,
the i18n entries and all five design-doc updates are verified in the tree by
direct read. The playtest scenario's red-first four values were **measured**
via the temporary-rollback protocol (fail frame **f140** /
`events_seen_count == 35` / observed 16 on the 16-row pool / **2** green
asserts before red — `final/delivery_notes_event_pool_playtest.md`), and the
unit gate's red-first values are structurally derived, not sidecar-measured
(the unit-suite leg was unreachable at implementation time —
`final/delivery_notes_event_pool.md`). The first official gate run then
measured the new scenario **13/15** (f200 `event_title` / `event_body`
observed empty — the two new render surfaces; draw / select / resolve and the
35→36 ladder were green; recorded as **UX-18 OPEN** in
`design/40_ux_backlog.md`). The review blocker was root-caused and **fixed in
the tree**: `_on_accept` ACTION_PICK case 3 published the drawn id without
re-syncing the surfaces, so `cultivation.gd:256` now calls `_sync_surface()`
the moment the roam draw lands, the publication (raw zh, matching the zh
playtest pins) carries a defensive `push_warning` for unknown ids
(:862-866), a unit pin `_test_event_title_body_surface`
(`tests/test_cultivation.gd:314`) guards the publish/clear pair, and the
stale file headers in `event_data.gd` now read 36 rows. **The post-fix official re-run has since landed** (2026-08-31, recorded in
`design/40_ux_backlog.md`): **78/78 scenarios PASS**, hard gate
`passed: true`, zero runtime errors, `event_pool_new_event_resolved` **15/15**
(f200 `event_title == "崖上采药"` / `event_body != ""` green after the
`_sync_surface()` fix), and the vision gate passed with Q6 78 good / 0 bad.

## Round: jinyong-equipment-battle — gear you drew can now be equipped, and it fights (previous round)

The 12 equipment cards (铁剑…长剑 / 布衣…软猬甲 / 草鞋…凌波靴) were inventory
dead ends: drawn, displayed, never equippable. This round gives the profile
three slots (兵刃/护甲/鞋履), a touch-only equip surface on the roster panel,
one tier formula, and feeds equipped gear into real encounters.

**What landed:**

- **Save model** (`scripts/data/player_profile.gd`): `equipped` — a plain
  String-keyed Dictionary `{"weapon","armor","boots"}` (JSON-lossless, same
  hard constraint as every other field). `equip()` validates slot / id-in-
  inventory / category match (an armor id can never enter the weapon slot);
  `unequip_slot()` clears; `from_dict()` coerces defensively and repairs
  equipped ⊆ inventory on load, so **legacy saves without `equipped` load as
  three empty slots — no crash, nothing wiped**. No autosave: equipment is a
  free action, following the cultivation save/load model.
- **One formula, one place** (`scripts/data/equipment_data.gd`): tier parsed
  from the id suffix (`eq_sword_1..4 → 1..4`, malformed ids degrade to 0);
  bonuses are category-keyed constants only — weapon → attack `+2×tier`,
  armor → health `+5×tier`, boots → initiative `+2×tier` plus `+1` move at
  tier ≥ 3. Never 12 hand-written per-item literals. The full derivation is
  archived in `design/40_progression.md` §9 (directions, per-tier steps,
  attribute-equivalent anchors, movement threshold, phase-5 re-tune surface).
- **Gear enters battle** (`scripts/data/battle_setup.gd`): `derive_stats`
  adds the equipment bonuses (empty-equipped output is bit-identical to the
  base formulas — the reversibility baseline), `build_character` mirrors
  `gear_attack/health/initiative/move_bonus` onto the CharacterData, and the
  stale "no live caller yet" header was replaced with the real one
  (`battlefield.gd:651` → `BattleSetup.build_character(SaveManager.profile)`).
  Equip before an encounter and the derived stats differ; unequip and they
  return to baseline.
- **Roster panel goes interactive** (`scripts/ui/roster_panel.gd` +
  `scenes/ui/roster_panel.tscn`): a 装/卸 button pool on the 物品 rows
  (focus_mode 0, clicks-only — no parallel keyboard-cursor list,
  `cursor_markers_visible == false` preserved). Equipping consumes no month,
  no action, no phase; the previous round's read-only guarantee was
  deliberately superseded (the panel now writes exactly one profile surface —
  `equipped` — and nothing else), recorded in the panel header.
- **Contracts & tests**: two new playtest nails (`roster_equip_free_action.yaml`
  free-action + panel-level reversibility; `equipment_in_battle_diff.yaml`
  real event grant → click equip → real encounter → `changed` → unequip →
  baseline), append-only surface observables (RosterPanel equipped_*/equip_*
  counts, Player gear_* bonuses, EquipButton blocks), static contract test +
  `tests/test_roster_equipment_guards.py` (no-autosave scan, focus_mode=0,
  surface appends), three new GDScript unit files (formula matrix, profile
  round-trip/hostile/validation, battle-setup legacy equality + per-slot
  direction + reversibility), i18n entries 「装上/卸下」.

**Verification status (honest, updated 2026-08-31 after the review round):**
implementation, unit-test registration, contract appends, i18n, AND the
design-archive updates are all verified in the tree by direct read
(`40_progression.md` §8 equipped row + §9 formula/derivation;
`90_decisions.md` 2026-08-31 ruling explicitly superseding the 2026-08-30
jinyong-roster ruling (e) with the old text preserved; `99_changelog.md`
append-only row; `30_presentation.md` equipment section). Both review
blockers are resolved in the tree:

- The `tests/test_roster_equipment_guards.py` no-autosave guard now strips
  `#`-comment lines before scanning (the `roster_panel.gd:8` doc-comment
  legitimately names the method; two regression pins cover both directions —
  comment-only lines are inert, a real non-comment call still reds).
- `equipment_in_battle_diff.yaml` was root-caused and REWRITTEN: the MAP
  (huashan) battle reuses the tutorial battlefield (`battle_return_state !=
  "CULTIVATION"` never calls `BattleSetup.build_character(profile)`), so the
  gear diff was unreachable there by ANY frame layout. All three encounter
  legs now run the REAL cultivation-encounter path (`debug_enter_encounter` →
  `battlefield.gd:651`); the item is granted via `debug_grant_equip` →
  `EventLogic.apply_option_effects` (never a bare profile write). Red-first
  four values MEASURED: fail frame **f560** / first failing assert
  **`Player.gear_attack_bonus: gear_attack_bonus > 0`** / exact error
  **`FAIL f560 Player.gear_attack_bonus: gear_attack_bonus > 0 (observed=0)`**
  / **46** green before red; post-restore green **47/47** (2026-08-31 sidecar;
  scenario header RED-FIRST EVIDENCE block +
  `final/delivery_notes_equipment.md`). `roster_equip_free_action` measured
  **36/36** with its own measured red-first (f110 / `equipped_weapon changed
  since frame 0` / exact error in the delivery notes / 35 green before red).

**Official gate evidence (2026-08-31, read by 5_review from the landed step
artifacts): compile 95/95 scripts, 0 errors; playtest 77/77 scenarios PASS,
0 runtime errors, hard gate `passed: true` — including
`equipment_in_battle_diff` 47/47, `roster_equip_free_action` 36/36,
`spine_to_ending` 42/42, `save_load_roundtrip` 14/14 and
`cultivation_changes_combat` 30/30; vision gate passed (all six questions
`failed: false`).** One review-round blocker remained after those runs:
`tests/test_roster_equipment_guards.py::test_no_autosave_guard_strips_comment_lines`
expected `"var y = 1"` while the comment-stripping helper preserves the code
line's trailing newline. Fixed test-side exactly as prescribed (the assertion
now reads `assert result_mixed.strip() == "var y = 1"`; the helper and the
other four guards are unchanged; no game code, scenario or threshold
touched). Its official 44/44 pytest re-run and the GDScript unit-suite
re-run are produced by the downstream `test_report.json` (5_test), so that
one criterion stays pending that artifact — everything above is green on
landed evidence. UX-16 is CLOSED on the 47/47 gate evidence
(`design/40_ux_backlog.md`).

## Round: wuxia-shrimp-portraits — every character is now a shrimp (武虾, 2026-08-31)

The 2026-08-28 world ruling (`design/90_decisions.md`) — **all characters are
shrimp** — is now visible on screen: the six 96×128 character portraits were
swapped from human ink-wash martial artists to non-human shrimp bodies
(cartoon head + semi-realistic body). The PNGs are round INPUTS (never
generated, drawn, or rewritten by the pipeline); this round aligned every
record with them and re-measured the pinned portrait geometry.

**What landed:**

- **Roster complete** (`assets/characters/roster.json`): the four
  「待定虾种」 filled by owner ruling — east_heretic 樱花虾(正樱虾) /
  south_emperor 罗氏沼虾 / central_divine 玻璃虾 / yang_guo 枪虾 (one giant
  claw, the other side empty — 独臂) — and all six `art_status` flipped to
  `completed`. west_poison (皮皮虾) / north_beggar (龙虾) were already set and
  untouched; `yang_guo`'s title/note untouched (de-naming is a separate
  round → UX-15).
- **Two-layer seed manifest** (`assets/seed_manifest.json`): flat table →
  `subjects` (6 locked identities: id/name/species/appearance — **no seeds: a
  seed identifies an image, not a person**) + `images` (6 derived:
  subject + scene + path) + the 9 non-character asset records preserved.
  `style_block` is the split-register sentence that produced these six
  images (head fully cartoon / body semi-realistic).
- **Geometry re-measured, all green on the new art** (observed values in
  `final/delivery_notes_wuxia.md` §3; raw runs in
  `final/portrait_geometry_remeasure_notes.md` and
  `final/portrait_alpha_bbox_notes.md`): `portrait_grid_alignment` **30/30**
  — all 24 ink lines `ink_world_dx/dy = 0.0` at f40 and f820; six-unit
  eight-layer visibility `portrait_visible = true`, `portrait_fail_layer = ""`,
  `portrait_covered_frac = 0.0`; `camera_transform_follows_unit` **9/9**;
  `spine_to_ending` **42/42, 0 runtime errors**. Frozen scenarios run
  unmodified; no threshold loosened; no yaml/script/PNG edit.
- **Pixel-true footing check**, independent of the texture-rect pin: alpha
  bbox of all six PNGs — `bottom_gap = 0` (ink touches the bottom row;
  the transparent-bottom-padding blind spot does not exist in this set),
  h_center_offset 0 / −0.5, `east_heretic` top = 3 recorded as a deviation,
  not "fixed".
- **Texture-rect blind-spot finding**: `portrait_ink_rect` / `ink_world_dx/dy`
  derive from the 96×128 texture rect + the constant foot anchor
  `(0, −tex.y/2)`, not from alpha pixels — all-green proves foot-anchoring,
  not ink footing; this round's alpha-bbox check covers the gap. (Full record
  → `design/30_presentation.md`, landed by the 5_design step.)
- **Recipe archived**: how these six images were made — species table, exact
  style sentence, contamination words that pull shrimp into humanoid form,
  age/gender expression, asymmetry-as-positive, composition→post-process
  (bottom-align + horizontal-centre), remove_bg + border flood-fill hole
  repair — all in `final/delivery_notes_wuxia.md` §1, the verbatim archive of
  the transitional `WUXIA_ART_HANDOFF.md` (whose deletion is documented there:
  blocked by a step required-output guard; safe to delete by a step with
  authority).

**Status (honest, 2026-08-31): measured this round, verdict pending
downstream gates.** The geometry numbers above are real harness self-run
values, but the OFFICIAL evidence is produced after verification:
`5_compile`/`5_test` (compile 0 errors, all scenarios green, hard gate
passed, GDScript unit suite, pytest guards incl.
`tests/test_shrimp_roster.py`), `5_vision` (frame support for the
per-portrait descriptions — the delivery notes mark them
unverified-this-round), and `5_design` (the design-doc updates:
30_presentation style sync + art-direction record + 重画流程→已执行,
90_decisions species rulings, 40_ux_backlog UX-15, 99_changelog row,
roadmap item 5 ❌→✅, and the `WUXIA_ART_HANDOFF.md` deletion). Do not treat
this round as GREEN until those land.

## Round: jinyong-roster — the roster panel: what you own, finally visible (taps only) (previous round)

Everything the profile already stored but nothing ever rendered — five
attributes, silver, innate traits, current year/month and sect, every learned
gongfa (grade / practice / mastered), and every inventory item resolved to its
Chinese name — is now one tap away.

**What landed:**

- **`RosterOpenButton`「角色」** (top-right, `focus_mode = 0`) in BOTH stable
  segments — `scenes/segments/cultivation.tscn` and `scenes/segments/map.tscn`
  each instance `scenes/ui/roster_panel.tscn` as a node named `RosterPanel`.
  `scripts/ui/roster_panel.gd` reads `SaveManager.profile` and writes nothing:
  open/close never autosave, never consume a month or action, never touch a
  phase (each host's `_unhandled_input` gates on `RosterPanel.is_open`).
- **The panel** is a centered read-only box over a tap-outside dim layer:
  「人物」 (根骨/内力/身法/悟性/福缘, 银两, 先天特质, 第 N 年 N 月, 门派),
  「功法」 (per art: name, grade, 练度 practice/cap from
  `ProgressionGongfaData.PRACTICE_TO_MASTER`, 大成 marker), and 「物品」 (each
  `profile.inventory` id through the frozen `CardData.display_name_of`; an
  unknown id degrades lazily to the raw id — never a crash, never a
  `push_error`; empty sections render 「（无）」). Close via the 「关闭」
  button or by tapping outside. The panel has zero internal selectables, so it
  publishes `cursor_markers_visible == false` exactly like every segment.
- **Contract (append-only)**: four `Roster*` surface blocks in
  `playtest/_common.yaml`; two new scenarios at the `scenario_order` tail
  (73 → **75**) mirrored in `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS`;
  GDScript unit pins in `tests/test_roster_panel.gd` (compose purity, item
  name resolution, unknown-id degradation, honest empty states, read-only
  `to_dict()` invariance); every new string in the `scripts/autoload/i18n.gd`
  EN dictionary.
- **The correspondence nail, MEASURED red-first** (TEMPORARY RED-FIRST REVERT
  applied to `roster_panel.gd open()`, direct sidecar run, restored
  byte-identical): failing frame **f70**, first failing assert
  **`RosterPanel.is_open: is_open == true`**, exact error
  **`FAIL f70 RosterPanel.is_open: is_open == true` / `observed=false`**,
  **8** green asserts before red. The nail drives the REAL grant path (map
  `merchant` event → `EventLogic.apply_option_effects` → `eq_sword_3`
  青锋剑) and then clicks the panel open and asserts 「青锋剑」 inside
  `RosterBodyLabel.text`.
- **Design record**: `design/30_presentation.md` (roster panel section),
  `design/90_decisions.md` (seven rulings a–g), `design/40_ux_backlog.md`
  (UX-13 no-`equipped` field / UX-14 §9 loadout promise vs auto-equip — both
  OPEN, record-only), and the `design/99_changelog.md` `roster_panel` row.

**Status (updated 2026-08-31): the review blockers are fixed and both new
scenarios self-run green on the current tree** (sidecar runs, see
"Verification status (honest)" below): `roster_panel_item_nail` **36/36
PASS** — the f110 silver differential was resolved by funding silver BEFORE
the merchant event with the whitelisted `debug_grant_silver` action (frame
f35; grants 32 = 4 × max facility cost through
`EventLogic.apply_option_effects`, never a bare profile write, so merchant
`option_a` −20 leaves 12 and the frame-0-baseline `changed` holds).
`roster_panel_cultivation_open_close` **16/16 PASS, hard gate
`passed: true`, 0 runtime errors** — the month advance is now a real
clicks-only month (CultOptionButton0 card pick → CultOptionButton2 做工 →
`_after_action` calendar advance; the `debug_step_month` token was gated on
`GameManager.current_state`, which a direct scene boot never sets), and the
6 direct-boot runtime errors are eliminated by a
`save_manager.gd::_ensure_deck` deck-boot guard
(`if not decks.has(cat): _init_decks()`). Both scenarios' red-first evidence
is MEASURED (never predicted) — the nail's four values are in the bullet
above; the cultivation scenario's measured four values are **f50** /
**`RosterPanel.is_open: is_open == true`** / **`observed=false`** /
**4** green asserts before red. No official post-fix 75-scenario gate run
exists yet; the 75 in the counts below is the `scenario_order` registry
count, not a gate-measured green count.

## Round: touch-single-surface — buttons are the option list, every state has a tappable exit (previous round)

The touch-reach round gave every screen a button; player feedback (2026-08-30)
then showed the screens were *doubled*: the same option list rendered twice (a
`▶` cursor text row in `BodyLabel` **and** an identical row of buttons), and
one state had a button count of zero — `GONGFA_PICK` with no unmastered art
hid its whole button box, leaving Enter (`_on_accept`'s empty branch) as the
only exit. On a phone there is no Enter.

**What landed (keyboard branches byte-identical; clicks delegate to the same
handlers; no art assets; `focus_mode = FOCUS_NONE` kept):**

- **One surface, one rendering** — `cultivation.gd` / `map.gd` /
  `sect_select.gd` no longer print option rows (or the `▶` cursor) into
  `BodyLabel`; the button pool is the only option list. Descriptive text
  (event title/prose, facility cost summary, the map overview node list, stats
  header, sect info lines) is untouched. Selection lives **on the button**: the
  focused row is full-bright `modulate`, the rest dimmed (the creation.gd
  precedent) — arrow keys still move the focus var and the highlight follows
  (`map.gd:483/:494/:505/:510`, `sect_select.gd:84`, `cultivation.gd`
  `_rebuild_options_box`). `creation.gd` was already single-surface (parity
  check only). The transition screen's 「继续 ▶」 glyph stays: it lives inside
  the button's own text — one surface, no duplication (recorded in
  `design/90_decisions.md`).
- **GONGFA_PICK empty-list exit** — with no unmastered art the box builds one
  「返回行动」 button (`cultivation.gd:572-576`) whose press walks the SAME
  `_on_option_pressed → _on_accept` chain every other option uses (the existing
  empty branch `:235-238` returns to `ACTION_PICK`; no forked phase logic).
  The on-screen hint states the way out (「暂无未大成武功。点击「返回行动」
  回到本月行动。」), and the self-justifying comment at the old
  `cultivation.gd:529` is rewritten to describe the actual guarantee: every
  player-choice phase leaves the box with ≥ 1 visible, wired button.
- **New observables** (`playtest/_common.yaml` surface, only-add):
  `cursor_markers_visible` (false ⇒ no `▶` anywhere in the rendered body) on
  cultivation / map / sect_select, plus `option_focus` /
  `focused_option_text` on cultivation.
- **The clicks-only nail** — `playtest/clicks_only_gongfa_empty_exit.yaml`
  seeds a fresh no-sect save (the one sanctioned debug seed), loads it by
  CLICKING the menu's 读取存档 entry, then clicks-only through card → 练功 →
  the empty `GONGFA_PICK` (exactly one 返回行动 button, wired, no `▶`),
  clicks it, and asserts `CultivationScreen.phase == "ACTION_PICK"` — the
  phase really changed; a merely-present button would not satisfy it.
  Registered two places (`_common.yaml::scenario_order` tail +
  `ROUND_SCENARIOS` tail) with a new keyboard-free smoke pin; keyboard twin
  `gongfa_pick_empty_keyboard_return.yaml` pins the Enter path of the same fix.
- **Property-based coverage gate** — `tests/test_touch_option_surface_gate.gd`
  (SceneTree script; auto-discovered by `run_tests.sh`'s sidecar scan) drives
  the cultivation / map / sect_select phase machines through their OWN handlers
  and asserts every reached player-choice phase produced ≥ 1 visible, wired
  control and no `▶` marker — not a literal phase-name list. A future phase
  with zero buttons reds the gate with a self-explaining message; the EXEMPT
  table (no-input states only, with its rule text) lives inside the gate.
- **Copy guard maintained, not dodged** (round-owner-granted scope):
  `tests/test_facility_copy_location.py` now detects `tr()` call-site keys
  structurally (`_tr_call_literals`), the map-chrome ALLOWED entries are
  emptied, and the shortened map copy keys land in the same commit as their
  slot-matched `i18n.gd` EN values. No wording was chosen for its CJK count.
- **Design archive**: new `design/31_touch_coverage.md` (every segment × phase
  with file:line — every touch-only exit Y; defensive unreachable zero-button
  branches recorded, not treated as dead-ends); rule (g) in
  `design/30_presentation.md`; the round's rulings in
  `design/90_decisions.md`; the `design/99_changelog.md` row; the
  `design/40_ux_backlog.md` record (UX-11 / UX-12 stay OPEN, nothing newly
  deferred).
- **Tails corrections** (carried over card): the Q6 clause below now carries
  the measured values (good_answers 71 / bad_answers 0 — nothing parked), and
  `final/delivery_notes_touch_reach_walkthrough.md` points at
  `final/delivery_notes_touch_reach_red_first.md` for the authoritative
  measured first-red values while keeping the f180/5 prediction as the
  prediction-vs-measurement record.

**The visibly-fixed dead end:** enter 养成 → tap 练功 with no trainable art →
【练功】 shows one 返回行动 button → tap it once → back at 本月行动 → keep
playing. Zero keyboard.

## Round: touch-reach — the whole storyline is playable with taps only (previous round)

A real player (2026-08-29) hit a wall at the end of the tutorial: 「玩完需要回车继续，
但是我在手机上没有回车」. Investigation showed it was not one missing button — the
main storyline was **pointer-dead from the tutorial-end screen onward**. The
tutorial-end overlay is built in code (`GameManager._show_end_game_overlay`:
CanvasLayer + dim + Panel + Label, zero Buttons), and the five later segment
scenes (`transition` / `sect_select` / `cultivation` / `map` / `ending`) were
`Backdrop + Label` with zero Buttons. This stayed invisible to a 69/69-green
playtest contract because `actions:` key injection (`Input.parse_input_event`)
feeds `_input` directly and **bypasses GUI hit-testing** — a screen with zero
clickable controls still passes a key-driven scenario (same root as the recorded
SegmentHost full-rect swallow). This round closes both halves of that: the
missing controls, and the observation gap that hid them.

**What landed (additive only — every keyboard branch byte-identical; every new
button delegates to the same handler the key shortcut calls; no `*_ClickTarget`
anchors; no art assets; `focus_mode = FOCUS_NONE` everywhere so no double-fire):**

- **Tutorial-end overlay** (`scripts/autoload/game_manager.gd`): the code-built
  overlay now also builds `Panel/ContinueButton` and `Panel/RetryButton`
  (`pressed → request_continue` / `request_retry`, per-state visibility, synced
  in both the construction and the re-show branch). The prompt copy now
  describes a real, tappable action — 「胜利！华山论剑的胜者！点击「继续」进入江湖」 /
  「战败于华山论剑 点击「重试」再战」 — with the call-site literals and the
  `i18n.gd` EN-dictionary keys changed together (the old 「按回车…」 keys were
  used nowhere else).
- **transition**: `NextButton` → `_advance()` · **sect_select**: `SectButton0..4`
  → `focus_index` + `_pick()` · **cultivation**: an `OptionsBox` whose
  `CultOptionButton{i}` pool is rebuilt each render to mirror the current
  phase's options → set the phase's focus var + `_on_accept()` (one handler,
  two triggers; month advancement / gongfa / attr / event logic untouched) ·
  **map**: `TravelButton{i}` → `focus_id` + `_travel()`, `EventOptionButton0/1`
  → `event_focus` + `_resolve_node_event()`, and three **facility delegate
  buttons** `FacilityEnterButton` / `FacilityUseButton` / `FacilityLeaveButton`
  → the existing `_enter_facility()` / `_use_facility()` / `_leave_facility()`
  (delegation only — facility semantics, the F-key gate and the data modules
  are byte-untouched, per the two-outcome protocol in `design/90_decisions.md`) ·
  **ending**: `RestartButton` → `restart_game()`.
- **New surface observables**: `GameManager.end_overlay_pressed_connected`
  (both overlay buttons' wiring, refreshed in both branches) and
  `pressed_connected` on all five previously button-less segment screens —
  the click gate proves hittability for the buttons the route reaches;
  `pressed_connected` proves wiring for **every** button (e.g. `RetryButton`,
  which no WON run clicks).
- **The nail**: `playtest/clicks_only_storyline.yaml` walks the whole storyline
  — menu → creation → tutorial battle → **tutorial-end overlay** → transition →
  sect select → 36-month cultivation → map → events → ending → restart — with
  `clicks:` only (true GUI hit-testing; a screen without a hittable control is
  a hard red, never a silent skip). It contains **zero keyboard actions**: every
  timeline `actions:` entry is empty except one `debug_win_tutorial` battle
  outcome seed (an unbound DEBUG action consumed in `_process`, the same seed
  the keyboard spine uses; adjudicated in `design/90_decisions.md` (a)). The
  battle screen's own clickability is separately proven by
  `battle_end_turn_attack_buttons` / `click_targeting_fixed` /
  `undo_button_retreat` / `click_portrait_body_targets_enemy` plus an in-scenario
  real click on `AttackButton`.
- **Companion scenario**: `playtest/map_facility_buttons_click.yaml` proves the
  three facility delegate buttons by clicks while `facility_use_reusable.yaml`
  stays byte-untouched.
- **The clicks-only path paid for itself twice**: aligning it to screen-ready
  timing re-projected every `at:` frame and grew the tutorial-intro leg to 7
  `Next` clicks (`TutorialManager.STEP_COUNT == 7`), and it exposed a real game
  bug the keyboard path never hits — `cultivation.gd`'s `_rebuild_options_box()`
  called `free()` on the button mid-emission of its own `pressed` signal
  ("Attempted to free a locked object"; measured 21/47 red). Fixed minimally
  with `queue_free()` (no month-advance/phase logic change; seven related
  scenarios re-measured green, `spine_to_ending` 42/42 among them).
- **Contract guards** (append-only): both new scenarios appended to
  `playtest/_common.yaml::scenario_order` **and** `ROUND_SCENARIOS` in
  `tests/test_playtest_contract_smoke.py` (two-place sync); surface whitelist
  grew by the twelve new button blocks + the six `pressed_connected` vars; two
  new smoke pins — `test_clicks_only_storyline_is_keyboard_free` (any keyboard
  action in the clicks-only file is a hard red; self-explaining failure message)
  and `test_touch_reach_surface_contract` (the new observables cannot be
  silently deleted). The stale `*_ClickTarget` example in `_common.yaml`'s
  clicks-grammar docs was corrected to a unit-body anchor.
- **Red-first record (measured)**: the nail is authored to first go red at the
  tutorial-end overlay (`ContinueButton` did not exist pre-fix) — and it DID,
  measured: with the documented TEMPORARY RED-FIRST REVERT applied to
  `game_manager.gd`, a real direct harness invocation
  (`godot_playtest_scenario(scenario="clicks_only_storyline")`) ran
  **RED 8/47** — failing frame **265**, first failing assert
  **`ContinueButton.visible`**, exact error **`aim: node not found:
  ContinueButton (spec: ContinueButton)`**, green asserts before red **8**;
  after the byte-identical restore it re-ran **47/47 green**. Values live in
  `final/delivery_notes_touch_reach_red_first.md`, the scenario header and
  `design/00_roadmap.md` / `90_decisions.md`; the earlier f180/5 numbers were
  the structural prediction and are superseded (same screen, same first
  assert).
- **Measurement-only debts** (`design/40_ux_backlog.md`, no gates):
  **UX-11** — touch-target sizes of every storyline control at the 960×704
  design resolution (measure and record the smallest few; Material 48 dp /
  HIG 44 pt / WCAG 2.5.8 24 px as references only; no size threshold);
  **UX-12** — residual keyboard-only hint copy with re-verified line numbers
  (`i18n.gd` :350/:354/:359/:364/:369/:378/:380/:122-123, scene literals
  `transition.tscn:50` / `sect_select.tscn:49` / `cultivation.tscn:47` /
  `ending.tscn:48`, `sect_select.gd:75`) — every one of those screens *now has*
  a control; only the copy still names the keyboard route.
- **Docs-first archive**: `design/30_presentation.md` new pointer-reachability
  section (incl. the observation conclusion: key injection cannot see this
  defect class, `clicks:` can); `design/00_roadmap.md` Phase 2 update;
  `design/90_decisions.md` rulings (a)–(e); `design/99_changelog.md` row
  dated 2026-08-29.

### The storyline, tapped screen by screen

Recorded in `final/delivery_notes_touch_reach_walkthrough.md` (≈90 clicks,
zero keyboard):

| Screen | What was tapped |
|---|---|
| 主菜单 | `MenuEntry0` (新的冒险) |
| 捏人 · 属性/特质/确认 | `AttrNextButton` → `TraitNextButton` → `ConfirmButton` |
| 教程战 · 开场页 | `Next` ×7 |
| 教程战 · 战斗 | `AttackButton` (one real click; outcome seeded with `debug_win_tutorial` — see above) |
| 教程结算 overlay | `ContinueButton` ← **the first-red screen** |
| 过场 | `NextButton` ×2 |
| 拜师 | `SectButton0` (少林) |
| 养成 · 36 个月 | each month `CultOptionButton0` (选卡/年初培元/岁末留门) + `CultOptionButton2` (做工 → the month advances through the existing path); year-boundary extra clicks; checkpoints at y1m1 / y2m1 / y3m1 |
| 大地图 | `TravelButton0/1…` per leg (无名谷→洛阳→武当→襄阳→昆仑), `EventOptionButton0` at each entry event |
| 结局 | `RestartButton` → back to the tutorial, storyline closed by taps alone |

## Previous rounds

- **jinyong-facility** — the third map-node content type: `FacilityData.TABLE`
  (2 rows, closed effect domain, §433 single prose source), shaolin/wudang
  facility slots `declared → active`, opt-in `FACILITY` phase (F key in TRAVEL,
  never auto-fires on arrival — pinned by the permanent negative assertion in
  `facility_use_reusable.yaml`, red-then-green measured 34/47 → 49/49), effects
  via the shared `EventLogic.apply_option_effects`, plus the
  `test_facility_use_reusable_surface_contract` anti-deletion pin and the
  `test_facility_copy_location.py` §433 guard.
- Earlier: **camera-owns-visibility** (following camera owns visibility, clamp
  deleted, canvas-transform click mapping, portrait-grid alignment),
  **interaction-defects** (floating-bar STOP filter, feet-tile undo, real-input
  coverage, touch undo, nameplate/ground marker, 5-step click priority, trait
  hover preview), **jinyong-nodes** (five main story nodes get content),
  **jinyong-map-events** (node entry-content + shared `EventLogic` + map EVENT
  phase), **jinyong-spend-qi** (real inner-qi costs), **jinyong-clarity**
  (creation-screen information layer), **jinyong-hud** (battle-HUD information
  layer), **jinyong-events** (event pool 4 → 16 rows), plus the owner's
  hand-added 华山 battle node. All recorded in `design/99_changelog.md`.

## Verification status (honest)

**jinyong-loop R2 (this round, 2026-09-01) — implementation verified by direct read;
per-scenario sidecar evidence green; the 5_review cycle's consolidated gate products
LANDED (compile 99/99 scripts / 0 errors; 84/84 scenarios PASS, hard gate `passed: True`,
0 runtime errors; vision passed, Q6 84 good / 0 bad) with the three protected gates green
verbatim; its single pytest blocker (the purchase-nail name==basename pin) is FIXED in
the tree; the official 5_test re-run on the fixed tree is the one remaining pending
artifact:**

- **Verified in the tree (verifier direct read):** the four rule fixes at their exact edit
  points (`cultivation.gd:297-300` empty-GONGFA exit → status + ATTR_PICK + `_after_action()`,
  度过本月 relabel, the 功法均已大成 body line; `map.gd` FACILITY_MONTHLY_USE_CAP = 2 + epoch
  reset + exhausted refusal + three-path `_resolve_node_event` with all-paths count increment;
  `event_logic.gd` validate_option + validate-then-apply with the clamp removed;
  `game_manager.gd` session mirrors + run-boundary resets); the three presentation-only scene
  fixes (sect_select / tutorial_overlay / roster_panel, zero `.gd` changes in the fix); the
  `UiOcclusionWatch` autoload + registration; the six new i18n EN entries; the five new nails
  + two re-pointed nails with differential asserts; `_common.yaml` surface/scenario_order
  appends; `ROUND_SCENARIOS` two-place sync; the new anti-weakening guards; zero
  `TEMPORARY RED-FIRST REVERT` residue in any `.gd`; gate (a)/(b) byte-identity confirmed by
  read (ladders + pinned lines present).
- **Measured this round (sidecar runs, per `final/gate_run_notes_loop.md` and the fix notes):
  all five nails red-first four-values recorded (`final/delivery_notes_loop.md` §(a)) then
  green; protected gates 49/49 / 32/32 / 41/41; `spine_to_ending` 42/42;
  `save_load_roundtrip` 14/14; `event_travel_effects` 19/19; zero runtime errors in every
  recorded run.
- **Landed gate products (per the 5_review cycle's verdict on the delivered tree):**
  `compile_report.json` — 99/99 GDScript scripts parsed, 0 errors, 0 warnings;
  consolidated playtest run — hard gate `passed: True`, 180 frames, 0 runtime errors,
  **84/84 scenarios PASS**, the three protected gates green verbatim
  (`facility_use_reusable` 49/49, `map_node_event_shaolin` 32/32,
  `map_battle_node_huashan` 41/41) and all five new R2 nails green (15/15, 33/33,
  33/33, 11/11, 22/22) plus the two re-pointed empty-exit nails (18/18, 15/15);
  `vision_report.json` — passed non-blind (84 scenarios / 336 frames), all six
  questions `failed: false`, Q6 84 good / 0 bad, backing the seven before/after
  occlusion frame pairs together with the structural `UiOcclusionWatch` asserts.
- **5_review blocker FIXED (verified in-repo, 2026-09-01):** the review's pytest run
  showed 55 passed / 1 failed — `test_event_option_refused_nail_contract`'s
  name==basename regex did not match the scenario's `name:` line. Fixed at
  `playtest/event_option_refused_no_charge.yaml:78` (the line is now byte-equal to its
  basename); the guard itself is NOT weakened
  (`tests/test_playtest_contract_smoke.py:2133-2197` unchanged — the name==basename
  pin is the point of the guard); the post-fix pytest cache records zero failures
  (`.pytest_cache/v/cache/lastfailed == {}`). The review's record correction is also
  landed: `final/gate_run_notes_loop.md` no longer cites the nonexistent
  `tests/test_event_logic_refusal.gd` — it points at `tests/test_map_node_event.gd`'s
  cost-gate block (~:562-577, the zero-mutation refusal pins) plus the three playtest
  nails.
- **Pending downstream (the only unmet standard, not counted as met):** the OFFICIAL
  `test_report.json` (`5_test`) re-run on the fixed tree. Every other gate artifact for
  this round has landed (see above); the blocker fix's resolution is measured in-repo
  (byte-equal name line, guard intact, zero pytest-cache failures), but the owning
  gate's official artifact is produced after this step.
- **Documented constraint record:** the brief's `git log` theme-merge check was never
  executed (no shell anywhere in the round); in-tree `ThemeManager.option_style`
  consumption confirms the merge and the fix zones do not overlap the focus-style
  portion.

**jinyong-theme (previous round, 2026-09-01) — implementation verified by direct
read; the official PRE-fix gates landed (archived by 5_design) and the review
blocker (`creation_layout_readability` 21/22) is FIXED with measured
evidence; post-fix OFFICIAL gate artifacts pending:**

- **Landed and verified in the tree (verifier direct read):** the rewritten
  theme (`load_steps=8`; Button 4 states + focus ring + 5 font colors; opaque
  Panel; Label/RichTextLabel colors; TitleLabel/HintLabel variations applied
  across menu_panel + all 6 segment scenes + the tutorial title); roster and
  tutorial opaque backing + raised dims (0.85 / 0.88) with no geometry or
  z-order changes; the hud.tscn shadow pair on both hint labels;
  `ThemeManager.option_style` + the `cultivation.gd:641` / `sect_select.gd:84`
  swap (no `modulate` assignment remains in either file); the `_common.yaml`
  surface append with two-place contract-smoke sync; the new differential
  scenario; the MEASURED red-first four-values (f110 /
  `focus_marker_active == true` / `observed=false` / greens-before-red 7,
  second red f140, total FAIL 12/14; green 14/14 + 16/16 + 42/42 after
  byte-exact restore); the design-doc archive landed by 5_design from the gate
  artifacts (`40_ux_backlog`: UX-22 → CLOSED(jinyong-theme), UX-21 updated
  with its honest residual, UX-31 opened; the single `99_changelog.md`
  jinyong-theme row; `32_theme.md` / `90_decisions.md` / `00_roadmap.md`
  phase-4 numbers / `30_presentation.md` theme section); zero
  "TEMPORARY RED-FIRST REVERT" hits in scripts/ or scenes/.
- **Official PRE-fix gate results (recorded in the design docs by 5_design
  from the landed gate products):** compile 98/98 zero errors; playtest hard
  gate `passed: true`, zero runtime errors, 78/79 (all five protected gates
  green; `theme_focus_marker_cultivation` 14/14); vision gate passed
  non-blind (79 scenarios / 316 frames, six questions `failed: false`, Q6
  78 good / 1 bad on a non-theme battle frame). The single red
  (`creation_layout_readability` 21/22, UX-31) is fixed in the tree with
  measured red-first (21/22 FAIL) + green (22/22) + a full 79/79 sidecar
  re-run with zero runtime errors (`delivery_notes_theme.md` §7).
- **Still pending downstream (do not count as met):** the OFFICIAL post-fix
  gate artifacts (`compile_report.json` / `playtest_summary.md` /
  `vision_report.json` / `test_report.json` from 5_compile / 5_vision /
  5_test) do not exist at verification time — the 79/79 zero-regression on
  the final tree rests on the repair task's measured sidecar runs until the
  official gate re-runs; the post-fix vision Q6 re-check was NOT executed
  (§7.5: endpoint unreachable — honest record); the per-frame readability
  verdict on fA/s4_frame_0052, fA/s2_frame_0158 and fB/s2_frame_0210 belongs
  to 5_vision (or the accepted human frame-review fallback); locked-file
  byte-identity awaits the official 5_review repo diff; UX-31's final
  disposition and the post-fix archive row belong to 5_design. Full detail
  in `final/verify_report.json`.

**jinyong-huashan (this round, 2026-09-01) — implementation verified by direct
read; rewritten gate self-run green; official downstream gates not yet run:**

- **Landed and verified in the tree (verifier direct read):** the
  build-source/return-target decoupling (`map_battle_id` write-at-entry at all
  four battlefield `_ready()` routes — `start_map_battle(bid)`, `start_battle`,
  `start_encounter`, `restart_game` — clear-at-route in
  `request_continue`/`request_retry`, `clear_battle()` untouched);
  `MapBattleData` (five-great roster from existing data, own positions,
  fail-safe unknown binding); `_setup_map_battle` + `_instantiate_map_enemies`
  (profile build via `BattleSetup.build_character(SaveManager.profile)`,
  `tutorial_battle = false`, sync HUD wire with deferred fallback, deferred
  `begin_battle` kick — the pinned `_setup_encounter_battle` and the tutorial
  path untouched); `map.gd` roster guard + id pass-through +
  `events_resolved_count` mirror (with `SaveManager.profile_created` reset);
  the rewritten `map_battle_node_huashan.yaml` (all 7 old assertions kept
  verbatim + the "can fight" assertions); `_common.yaml` two-surface append;
  three new test files; the 19-row line-by-line gate-change table in
  `final/delivery_notes_huashan.md` §2. Measured (2026-09-01, delivery notes
  §3/§4c): profile hero `max_health = 135`; rewritten gate self-run **41/41
  PASS**; §D3 roster fallback NOT applied (five greats kept).
- **Not yet verifiable at this step (do not count as met):** the official
  compile / 78-scenario regression / vision / unit-suite reports are downstream
  step products (`compile_report.json` / `playtest_summary.md` /
  `vision_report.json` / `test_report.json`) that did not exist at verification
  time; the five design-doc updates (20_content / 90_decisions / 99_changelog /
  00_roadmap / 40_ux_backlog) are not in the tree. The yaml-gate / unit-pin
  pre-fix red-first four-values are MEASURED (2026-09-01,
  `final/_red_first_4a.md` / `final/_red_first_4b.md`; delivery notes
  §4a/§4b). Full detail in `final/verify_report.json` issues.

**jinyong-roster (this round, 2026-08-30; blockers fixed + both red-firsts
measured 2026-08-31) — delivery verified by direct read; both new scenarios
self-run green on the current tree; downstream gates pending:**

- **Landed and verified in the tree**: `scripts/ui/roster_panel.gd` +
  `scenes/ui/roster_panel.tscn` instanced as `RosterPanel` into BOTH segment
  scenes; host input gates (`cultivation.gd:149-150`, `map.gd:112-119`); the
  four `Roster*` surface blocks; `scenario_order` 73→75 + `ROUND_SCENARIOS`
  two-place sync; the i18n roster block (`i18n.gd:474-487`);
  `tests/test_roster_panel.gd` registered in the unit-suite registry; the
  facility anti-delete pin's FORM-gate failure message
  (`test_playtest_contract_smoke.py:1078-1086`, additive only); the five
  design-doc updates (30 / 40_ux_backlog UX-13+UX-14 / 90 / 99). MEASURED nail
  red-first: f70 / `RosterPanel.is_open: is_open == true` /
  `FAIL f70 RosterPanel.is_open: is_open == true` + `observed=false` /
  red-before-green **8** (scenario header RED-FIRST EVIDENCE block +
  `final/delivery_notes_roster.md` §1). `design/99_changelog.md` row :126
  re-verified to hold the measured touch_single_surface values verbatim
  (f140 / `CultOptionButton0.visible: visible == true` /
  `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)` /
  red-before-green 9) — no third correction row (append-only archive
  honored).
- **Fixed and self-run green (2026-08-31 sidecar runs, per
  `final/delivery_notes_roster.md` §2/§9/§10)**: the 2026-08-30 baseline reds
  (`roster_panel_item_nail` 35/36 at f110 `MapScreen.silver: changed`;
  `roster_panel_cultivation_open_close` 15/16 at f110
  `CultivationScreen.month: changed` plus 6 `save_manager.gd:365/:382`
  deck-table runtime errors) are all resolved on the tree:
  (1) `save_manager.gd::_ensure_deck` now boots the six decks on demand
  (`if not decks.has(cat): _init_decks()`) — a direct scene boot no longer
  indexes an uninitialized deck table; (2) the nail funds silver at f35 via
  the whitelisted `debug_grant_silver` action (32 = 4 × max facility cost,
  routed through `EventLogic.apply_option_effects` — never a bare profile
  write), so `silver: changed` is satisfiable; (3) the cultivation scenario's
  month advance is a real clicks-only month (CultOptionButton0 card pick →
  CultOptionButton2 做工 → `_after_action` advances the calendar), phase-gated
  and not state-gated. Measured self-run results on the fixed tree:
  `roster_panel_item_nail` **36/36 PASS** (青锋剑 pin green at f130),
  `roster_panel_cultivation_open_close` **16/16 PASS, hard gate
  `passed: true`, 0 runtime errors**. The cultivation scenario's RED-FIRST
  block is now MEASURED (no placeholder remains): fail frame **50** / first
  assertion **`RosterPanel.is_open: is_open == true`** / exact error
  **`observed=false`** / red-before-green **4** (TEMPORARY RED-FIRST REVERT on
  `roster_panel.gd open()`, direct sidecar run, restored byte-identical).
- **Pending downstream evidence (not producible at verification time — not
  guessed, counted as unmet)**: compile 0 errors; GDScript unit suite green;
  `tests/test_i18n_coverage.py` / `tests/test_playtest_contract_smoke.py` /
  `tests/test_facility_copy_location.py` green; the vision gate;
  `spine_to_ending` timing. Their reports (`compile_report.json`,
  `vision_report.json`, `test_report.json`) are pipeline artifacts produced
  after this step. No official POST-FIX 75-scenario playtest gate run exists
  yet — the registry count (75) is not a gate-measured green count; the
  latest OFFICIAL gate run (2026-08-30, pre-fix) measured 73/75 with the two
  scenario defects, and the 2026-08-31 fixes are evidenced by direct sidecar
  self-runs (36/36 and 16/16, 0 runtime errors) until the downstream gate
  re-run lands the official 75/75 count.

**touch-single-surface (previous round, 2026-08-30) — fully evidenced (red-first
MEASURED post-review + official gate run):**

- **Direct-read verified in the tree**: the single-surface renders (`▶` option
  rows deleted from the cultivation / map / sect_select bodies; selection on
  the button via `modulate`; keyboard focus vars and `_unhandled_input`
  branches byte-identical), the `GONGFA_PICK` empty-exit button + rewritten
  hint + rewritten comment (`cultivation.gd:542-550`), the new observables in
  the `_common.yaml` surface (only-add), the two new scenarios + two-place
  registration + the keyboard-free smoke pin, the traversal-based coverage
  gate (SceneTree script; `run_tests.sh` discovers every `extends SceneTree`
  script by property — no list edit needed), the maintained copy-location
  guard (`_tr_call_literals` detection, ALLOWED emptied, anti-triviality floor
  re-based, the two symbol exclusions untouched), the design-archive rows
  (30 (g) / 31 new / 40 / 90 / 99), and the tails corrections (README Q6
  measured 71/0; walkthrough pointer line with the f180/5 prediction
  preserved).
- **MEASURED first-red values landed (2026-08-30, after the review round)**:
  the `godot_playtest_scenario` sidecar was invoked with the TEMPORARY
  RED-FIRST REVERT applied to `scripts/segments/cultivation.gd` and the nail
  went RED as the brief requires — failing frame **f140**, first failing
  assert **`CultOptionButton0.visible: visible == true`**, exact error
  **`aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`**,
  **9** green asserts before red (f80 6 + f110 2 + the f140
  `phase == "GONGFA_PICK"` assert, which passes even with the revert). The
  earlier structural prediction (8 green before red) is preserved verbatim in
  the scenario header, explicitly marked superseded by the measured run. The
  revert was restored byte-identically (zero `TEMPORARY RED-FIRST REVERT`
  hits in `scripts/`) and both new scenarios re-ran GREEN on the restored
  tree: `clicks_only_gongfa_empty_exit` **16/16**,
  `gongfa_pick_empty_keyboard_return` **13/13** (hard gate `passed: true`).
  All values live in the scenario header's RED-FIRST EVIDENCE block and in
  `final/delivery_notes_touch_single_surface.md` (Part A §4/§5 + Part B §4/§5) —
  the `implementer.md:23` self-run hard condition is MET.
- **Downstream gates measured (read by `5_review` from the gate artifacts)**:
  compile **89/89** scripts, 0 errors; playtest **73/73** scenarios PASS, 0
  runtime errors, hard gate `passed: true` (including
  `clicks_only_gongfa_empty_exit` 16/16, `gongfa_pick_empty_keyboard_return`
  13/13, `spine_to_ending` 42/42, `clicks_only_storyline` 47/47,
  `facility_use_reusable` 49/49); vision gate **passed** (non-blind, 73
  scenarios / 292 frames, all six questions `failed: false`, Q6 text
  readability 73 good / 0 bad); GDScript unit suite **38/38** green
  (including the traversal coverage gate `tests/test_touch_option_surface_gate.gd`
  and the two re-targeted map unit tests); `tests/test_i18n_coverage.py` +
  `tests/test_playtest_contract_smoke.py` + `tests/test_facility_copy_location.py`
  green.

The rest of this section describes the previous (touch-reach) round.

The only authoritative gate evidence is the pipeline step products —
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` — pipeline artifacts, not repo files. The touch-reach
round's official full-suite run has executed (2026-08-30); its measured
results are transcribed into the design archive (`design/00_roadmap.md`,
`design/40_ux_backlog.md`, `design/30_presentation.md`) and were relayed by
`5_review`. In short:

- **Direct-read verified this round (touch-reach)**: the overlay buttons +
  re-show branch + `end_overlay_pressed_connected` in `game_manager.gd`; the
  five segment scenes' new buttons + `OptionsBox` + facility delegate buttons;
  `pressed_connected` on all six segment scripts; the two-sided copy edit
  (`game_manager.gd:203/:208` ↔ `i18n.gd:104/:105`) plus the new label keys;
  `clicks_only_storyline.yaml` (zero keyboard actions; single
  `debug_win_tutorial` seed) and `map_facility_buttons_click.yaml`; the
  two-place sync (`_common.yaml::scenario_order` tail + `ROUND_SCENARIOS`
  tail); the two new smoke pins; the extended `test_game_manager_fsm.gd`
  overlay pins; the design-archive records (30/40/00/90/99).
- **Red-first status (measured)**: the first-red and the post-fix green are now
  MEASURED — via direct per-scenario invocation of the same external sidecar
  the gate drives (not via the `5_compile` gate): RED 8/47 at f265
  (`ContinueButton.visible`, exact error `aim: node not found: ContinueButton
  (spec: ContinueButton)`, 8 green asserts before red) with the documented
  temporary revert applied, then GREEN 47/47 after the byte-identical restore;
  a second parse-clean measured run (frame-timing re-projection plus the
  `cultivation.gd` `free()` → `queue_free()` fix) re-measured the nail 47/47
  green with seven regression probes green (`spine_to_ending` 42/42,
  `map_facility_buttons_click` 38/38, `facility_use_reusable` 49/49, plus four
  cultivation/sect scenarios). The earlier f180/5 numbers were the structural
  prediction (superseded).
- **Official full-suite gate run (2026-08-30) — MEASURED**, transcribed into
  `design/00_roadmap.md` / `design/40_ux_backlog.md` /
  `design/30_presentation.md` (e) and relayed by `5_review`: playtest
  **71/71 scenarios PASS** (hard gate `passed: true`, `spec_used: true`,
  **0 runtime errors**) — incl. `clicks_only_storyline` **47/47** (zero
  keyboard actions), `map_facility_buttons_click` **38/38**, the keyboard-path
  proof `spine_to_ending` **42/42** (byte-untouched, still fully green),
  `facility_use_reusable` **49/49**, `tutorial_win_routes_to_transition`
  **8/8**, `tutorial_loss_restarts_tutorial` **5/5**; compile **88/88**
  scripts, zero errors; vision gate **passed** (non-blind, 71 scenarios /
  284 frames, all six questions `failed: false`; Q6 text-truncation question
  measured good_answers 71 / bad_answers 0 — no Q6 bad answers that round,
  nothing parked); the pytest smoke
  ran **31/32** in `5_review`'s pass — the single failure was a test-side
  false positive on a comment line, root-caused and fixed after that run
  (bullet below).
- **Gate runs for this round**: `design/99_changelog.md`'s
  `record_parse_lesson_and_reconcile` row records that the round's `5_compile`
  run measured `Parse failed — play-test skipped` (`spec_used: false`,
  `frames: 0`): a parse error in a new `tests/*.gd` file reds Godot's
  project-wide parse check, the playtest is skipped entirely, and the hard gate
  still reads `passed: true` with zero frames. That lesson is closed by the
  official parse-clean full run above (`spec_used: true`, 71/71 PASS).
- **Smoke-gate hardening (post-gate fix, 2026-08-30,
  `final/delivery_notes_fix_at_gate_strip_comments.md`)**:
  `tests/test_playtest_contract_smoke.py::test_timeline_at_values_are_integers`
  false-reded on a `#` comment — `clicks_only_storyline.yaml:99` carries a
  backtick-wrapped `` `at:` `` in prose and the old regex matched comments
  too, capturing the backtick and failing `isdigit()`. Root cause fixed in
  the TEST (the scenario file stays byte-identical): a pure
  `_bad_timeline_at_values()` helper now strips each line's `#` comment
  before applying the original regex + `isdigit()` check, the docstring's
  false "word-boundary-guarded, so `at` inside prose never matches" claim was
  deleted, and two regression pins were added — a real non-integer `at:`
  value still reds, and the exact backtick-in-comment case is inert. Net
  effect: two tests added, the gate property preserved (only comments are
  excluded from matching), no scenario or threshold touched.
- If the downstream playtest gate reddens any scenario, that is reported with
  its cause, never papered over: no assertion is removed or relaxed, no
  frozen yaml is edited to route around a defect, and thresholds are never
  loosened — numbers come from constants or fresh measurement only.

## Repository layout

- `scripts/` — game code: `autoload/` (GameManager incl. the end-game overlay
  buttons, CombatManager, GridManager, SaveManager, InputGate,
  SceneManager-last, …), `camera_follower.gd`, `coord.gd`, `characters/`
  (`player.gd`, `enemy.gd`), `data/` (map/event/facility data,
  `event_logic.gd`, `facility_data.gd`, player_profile, …), `ui/` (HUD,
  health_bar.gd, tile_markers.gd, input_census.gd, highlights, visibility
  probe), `segments/` (creation / cultivation / **map** / **transition** /
  **sect_select** / **ending**, all with tappable controls), `ai/`,
  `battlefield.gd`
- `scenes/` — Godot scenes: `ui/` (hud, health_bar), `segments/`
  (creation, map, transition, sect_select, cultivation, ending),
  `battlefield.tscn`, `main.tscn` / `menu.tscn`
- `playtest/` — 84 headless playtest scenarios + the `_common.yaml` contract
  (85 yaml files); incl. the clicks-only storyline spine and the facility
  click companion; frozen yamls are append-only (authorized edits stay
  machine-pinned by the superset fixture)
- `tests/` — GDScript unit suites (28 files in the TESTS registry),
  SceneTree-style integration suites (incl. `test_game_manager_fsm.gd` with
  the overlay-button pins), `test_playtest_contract_smoke.py` (incl. the
  keyboard-free pin + touch-reach surface contract),
  `test_facility_copy_location.py`, and the frozen
  `fixtures/playtest_assert_superset.json` baseline
- `design/` — the design archive (`00_overview.md` … `99_changelog.md`);
  this round's records: `30_presentation.md` pointer-reachability section,
  `40_ux_backlog.md` UX-11/UX-12 measurement debts, `00_roadmap.md` Phase 2
  update, `90_decisions.md` touch-reach rulings (a)–(e), `99_changelog.md`
  touch-reach row (2026-08-29)
- `final/` — per-round delivery notes and probe notes (this round's
  red-first evidence: `final/delivery_notes_touch_reach_red_first.md`;
  the taps-only walkthrough:
  `final/delivery_notes_touch_reach_walkthrough.md`; the facility round's
  red-then-green record: `final/delivery_notes_facility.md`; the
  event-pool round's gate evidence:
  `final/delivery_notes_event_pool.md` +
  `final/delivery_notes_event_pool_playtest.md`)
- `assets/` — placeholder textures, seed portraits, NotoSansSC font, audio

## R3b close-out record (2026-09-03)

R3b iteration-4 close-out (official run 91/93 green, hard gate passed, pytest 67/67, vision passed).
- C5: honest LOST close per the 2026-09-03 owner re-scope ruling — WIN carried to the world-breadth round with the 36/48 baseline; post-edit sidecar 47/47.
- trait_combat pin re-derived: verdict (b) real stat shift (mp = 6, move_range = 5); post-fix 22/22.
- README manualized: 1727 → 72 lines; format pin 5/5 passed.

Full record: `design/99_changelog.md` (2026-09-03 row) + `design/90_decisions.md` (2026-09-03 ruling).
