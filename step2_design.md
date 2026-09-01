# Technical Architecture Design — R3 "Meaningful Numbers: Choices Must Shape the Ending"

> Architect step, 2026-09-01. Inputs: Project Brief (R3), Step-1 SOTA report (verified
> against the current post-R2 tree, review verdict `passed: true`), `design/` archive
> (verbatim input constraint), and direct reads of every touched file on today's tree.
> All file paths are repo-root-relative (`./scripts/...`). All code anchors were
> re-read on the current tree today unless explicitly cited as a prior round's
> official measurement.

---

## 0. Round identity and the one pre-existing assumption this design resolves

**Resolved Step-1 Assumption #2 first (the most consequential open question):**
the brief's phrase "tune only MapBattleData data or battle numbers" is implemented
as **player-side only**. `scripts/data/map_battle_data.gd` and
`scripts/battlefield.gd` (where the five greats' HP/damage/initiative literally
live) are BOTH in the six-file jinyong-huashan lock ledger, so the Huashan
difficulty fix routes **exclusively through the player-side battle-number surface
`scripts/data/battle_setup.gd::derive_stats`** (a sanctioned extension surface per
the brief's Technical Constraints). **No scope unlock is requested or required.**
Contingency (recorded, not designed): if the measured win rate with sanctioned
levers cannot be lifted off zero without weakening the fight's challenge, the
implementer escalates to the round owner for an explicit `map_battle_data.gd`
data unlock — it is NOT pre-authorized by this design.

The six locked files this round must not move by one byte:
`scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`,
`scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`,
`scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`.
The three verbatim-protected gates (`facility_use_reusable`,
`map_node_event_shaolin`, `map_battle_node_huashan`) stay byte-identical.

---

## 1. Overview

Four problems, four fixes, one shared principle: **every fix is measured first on
the current tree, then landed, then pinned by a choice-differential nail** (never
a `== 90`-style literal).

| # | Problem (verified shape) | Fix shape (this design) | Core new component |
|---|---|---|---|
| P1 | Ending tier = equal-weight sum of 5 attrs vs 90/60 (`map_data.gd:68-75`, `ending.gd:16-21`); a growth route saturates tier 3 mid-journey | Multi-axis ending evaluation: attrs + art mastery + deeds (travel/work), computed fresh at the ending screen from persisted profile data; thresholds re-derived from measured 36-month yield curves | `scripts/data/ending_logic.gd` (NEW, pure static) |
| P2 | `fortune` has zero consumers while `creation.gd:21` promises 「影响事件与奇遇(游历事件可重掷)」; hook `yearly_event_reroll` (`trait_data.gd:29`) is repo-wide unreferenced | Implement the promise literally: a **travel-event reroll** on the cultivation 游历 channel with a fortune-scaled yearly budget; `deep_fortune` trait grants +1 | `TraitEffects.fortune_reroll_budget()` + reroll action in `cultivation.gd` |
| P3 | `work` = flat +10 silver (dominated by the free `gr_silver_30` card), `practice` = +1 (≤ free `gr_practice_2` card) | Each action gets a unique measured niche: work scales with mastery (only scalable repeatable silver), practice becomes +2 and is the only **target-chosen** advancement, cultivate stays the only attribute source, travel stays the only item/event source | `_apply_action` rebalance + yield surfaces + measured curves |
| P4 | Huashan finale: normal-route profile (measured `max_health = 135`, official jinyong-huashan run) vs five greats (95–130 HP, initiative 70–85) = dead before acting; no screen says what is needed | (a) **Winnability** via the sanctioned `derive_stats` extension: cultivation output (mastered arts) feeds player battle numbers; (b) **advance warning**: a readiness verdict computed by `BattleSetup.readiness()` and rendered on the roster panel + cultivation monthly body | `battle_setup.gd` extension (sanctioned surface) |

Design-change discipline: every numeric formula this round touches is listed in
§9 (设计变更) with old → new and the measurement that justifies it. Provisional
constants are marked **PROVISIONAL — set by measurement task M1/M2**, never
hard-pinned by gates.

---

## 2. Verified ground-truth anchors (re-read today, 2026-09-01)

- `scripts/segments/ending.gd:16-22` — tier = `MapData.ending_tier(sum of 5 attrs)`;
  renders ONLY tier title/text; `_render()` writes `BodyLabel.text`.
- `scripts/data/map_data.gd:68-75` — `ENDING_TIERS` rows `{tier, min_total, title, text}`,
  90/60/0, top-down first-row-wins (`ending_tier` at :115-119). `map_data.gd` is **editable**
  (it is NOT in the six-file lock).
- `scripts/data/battle_setup.gd:36-48` — `derive_stats` consumes bone/inner/agility
  (+ gear via `EquipmentData.sum_bonuses`); wisdom/fortune absent. `build_character`
  (:59-114) is the live caller path for encounter AND map battles
  (`battlefield.gd` calls `BattleSetup.build_character(SaveManager.profile)` in both
  `_setup_encounter_battle` and `_setup_map_battle` — verified in the jinyong-huashan
  round record; the call site itself is locked, the callee is editable).
- `scripts/data/trait_effects.gd` — pure-static helper home; `practice_gain(wisdom, roll)`
  is wisdom's sole consumer; `SaveManager.rng` op-order contract documented in-header.
- `scripts/data/event_logic.gd:21-31` — `draw_unseen_id(profile, rng)` = exactly ONE
  `rng.randi_range` draw (empty-pool reset branch = zero RNG); `validate_option` /
  `apply_option_effects` = zero RNG (R2 lifeline).
- `scripts/segments/cultivation.gd` (editable) — `_apply_action` :393-408
  (practice +1 / cultivate 1 randf → +1..3 / work +10 / travel draws), `_on_accept`
  :247-322 (ACTION_PICK cases 0-6; case 3 = travel draw + `_sync_surface()`),
  `_after_action` :413-428 = the single month-advance path, `_advance_year` :455-463
  (year reset point), empty-GONGFA soft-lock exit :287-301 (zero RNG, must survive),
  `_sync_surface` publishes `CultivationScreen.*` observables (event_title/event_body
  publish at :862-866).
- `scripts/data/player_profile.gd` — pure data layer; `to_dict`/`from_dict` (:97-230)
  is the additive-schema precedent: `equipped` was added with legacy-default repair
  ("a LEGACY save with no `equipped` key → keep the three-empty slot default: no
  crash, nothing wiped"). `flags` from_dict DROPS unknown keys (only
  `tutorial_done`/`events_seen` survive) — **new deed counters must be first-class
  profile fields, not `flags` entries.**
- `scripts/data/card_data.gd:28-66` — free monthly card yields: `gr_silver_30` +30
  silver, `gr_practice_2` +2 practice (×2 in deck), `gr_attr_*` +1 attr — the
  structural dominance evidence for P3.
- `scripts/data/trait_data.gd:29` — `deep_fortune` (福缘深厚, cost 5, hook
  `yearly_event_reroll`, description 「游历事件每年可重掷一次」).
- `scripts/segments/creation.gd:14-22` — `_ATTR_DESCS` incl.
  `"fortune": "影响事件与奇遇(游历事件可重掷)"` (the on-screen promise).
- Official measured anchor (jinyong-huashan, 2026-09-01, official 5_compile run):
  a fully-played 36-month profile hero enters the map duel with
  `max_health = 135`; `map_battle_node_huashan` 41/41 pins
  `max_health != 1000 and max_health > 0`, `turn_order.size() == 6`,
  `tutorial_battle == false` — these stay verbatim-green under this design.
- RNG lifelines that must stay green: `save_load_roundtrip` 14/14,
  `event_travel_effects` 19/19 (op order of the seeded stream).
- Harness surfaces already whitelisted (`playtest/_common.yaml`):
  `CultivationScreen.{month, month_before_accept, status_text, attr_*, gongfa_count,
  mastered_count, event_id, event_title, event_body, events_seen_count,
  last_effect_types, focused_option_text, phase, ...}`, `MapScreen.{silver,
  attr_*, events_resolved_count, map_status_text, event_open_silver, last_use_*,
  last_apply_attr_value, facility_id, ...}`, `EndingScreen.{tier, ...}`,
  `RosterPanel.*`, `UiOcclusionWatch.{violations, violations_text, scan_ok}`.

---

## 3. Architecture (component relations and data flow)

```
                       ┌──────────────────────────── cultivation month loop (editable) ───────────────────────────┐
                       │                                                                                            │
  monthly card draw    │   _apply_action(kind)                        EVENT phase (travel)                          │
  CardData (unchanged) │   ├─ practice → +2 practice, chosen art ─┐           │ draw_unseen_id (1 RNG)             │
  SaveManager decks    │   ├─ cultivate → attr +1..3 (1 randf)    │           │ [NEW] reroll (event_reroll input)  │
  (unchanged decks)    │   ├─ work → silver = f(mastered) ────────┤           │  budget = TraitEffects.            │
                       │   └─ travel → interactive event          │           │   fortune_reroll_budget(fortune,   │
                       │   ALL FOUR increment profile.deeds ──────┘           │            deep_fortune)           │
                       └──────────────┬─────────────────────────────────────┴──────────────┬─────────────────────┘
                                      │                                                     │
                                      ▼                                                     ▼
                     PlayerProfile (editable, additive schema)                    seeded SaveManager.rng
                     ├─ attrs / gongfa / silver / inventory / equipped (unchanged)  (op-order lifeline:
                     ├─ deeds {work_months, cultivate_months, practice_months,      old paths untouched; the only
                     │         travel_resolved, silver_earned}   ← NEW, persisted    new draw sits on a NEW
                     └─ flags (unchanged semantics)                                  player-initiated input)
                                      │
              ┌───────────────────────┼─────────────────────────────────────────────┐
              ▼                       ▼                                             ▼
  scripts/data/ending_logic.gd   scripts/data/battle_setup.gd                  scripts/segments/ending.gd
  (NEW pure static)              (sanctioned extension)                        (editable)
  evaluate(profile, deeds) ->   derive_stats(profile) EXTENDED:               renders tier + axis summary
    {score, axes, tier, summary}   max_health/energy/initiative gain           (evaluation_text, score)
  MapData.ENDING_TIERS             a mastered-arts cultivation term              ▲
    re-thresholded (min_score)     readiness(profile) -> verdict band            │ warning surface
                                   MapData.HUASHAN_BAR (NEW data)  ─────────► scripts/ui/roster_panel.gd (editable)
                                                                              + CultivationScreen body line (year ≥ 3)
```

Data-flow invariants:

1. **One evaluation function, three readers.** `EndingLogic.evaluate(profile, deeds)`
   is the single scoring path; `ending.gd` renders it, the playtest nails assert on
   it, and the unit suite exercises it headlessly. No duplicated tier math.
2. **Deeds are persisted, never derived from session mirrors.** `map.gd`'s session
   mirrors (`map_events_resolved_count`, `settled_node_events`) are session-scoped
   by R2 design and live in a **locked** file — the ending must not depend on them.
   Deeds count only cultivation-channel events (`profile.deeds.travel_resolved`),
   which `cultivation.gd` owns end-to-end.
3. **Zero new RNG on old paths.** Deed increments, work scaling, practice +2, the
   ending evaluation, and readiness are pure arithmetic. The ONLY new RNG draw in
   the round is the reroll's second `draw_unseen_id` call, which executes only when
   the player presses the new reroll input — old timelines (which never press it)
   keep byte-identical streams.
4. **Warning surfaces read the same math the fight uses.** `readiness()` wraps
   `derive_stats()`; the preview can never drift from the actual duel numbers
   because there is one formula source.

---

## 4. Design decisions (with rejected alternatives)

### D1 — Ending evaluation: multi-axis score, thresholds from measured curves (P1)

`scripts/data/ending_logic.gd` (NEW, pure static, mirrors `EventLogic`/`TraitEffects`
conventions: no autoloads, no scene tree, unit-testable):

```
evaluate(profile, deeds) -> Dictionary:
  axes = {
    "attrs":    bone + inner + agility + wisdom + fortune,          # existing sum, kept
    "mastery":  Σ over profile.gongfa where mastered: GRADE_POINTS[grade]   # D=1 C=2 B=3 A=4
    "deeds":    W_TRAVEL * deeds.travel_resolved + W_SILVER * deeds.silver_earned
  }
  score = round(axes.attrs * K_ATTR + axes.mastery * K_MASTERY + axes.deeds)
  tier  = MapData.ending_tier(score)          # same first-row-wins scan
  return {score, tier, axes, summary}         # summary = per-axis lines for the screen
```

- `MapData.ENDING_TIERS` rows gain `min_score` (replacing `min_total` as the scan
  key); titles/texts stay (they are pinned copy elsewhere — reuse, never rewrite).
  `ending_tier(total)` becomes `ending_tier_score(score)`; the old function is
  removed together with its caller in the same task (no dead dual path).
- **Why axes and not just higher thresholds:** with thresholds alone, "choices
  matter" still dies the moment one axis saturates. Mastery and deeds keep growing
  through month 36 *by construction* (mastery needs 4–10 practice months per art;
  deeds accrue per action), so a choice in month 36 still moves `score`.
- **Why deeds are cultivation-channel-only** (rejected: counting map node events /
  battle wins): `map.gd` and `GameManager` are locked; their counters are
  session-scoped and would silently zero on reload — a persisted-deed design that
  silently reads zero after a reload would make the ending lie. Limitation recorded
  in `design/40_progression.md` by 5_design.
- **Tuning targets (the gate is these differentials, never the constants):**
  - T-1 two divergent seeded playthroughs (work-heavy vs practice/travel-heavy)
    reach **different** `{tier, score}` records.
  - T-2 a month-36 action flip changes the evaluation record on a
    boundary-straddling seeded save.
  - T-3 a creation-maximized profile that then plays zero-growth months cannot
    reach tier 3 (the early-freeze hole stays closed at the TOP as well).
  - T-4 a normally-played balanced route reaches tier 2 comfortably (measured
    median over ≥ 5 seeded runs, recorded in `design/40_progression.md`).
  - Constants `K_*`, `W_*`, thresholds: **PROVISIONAL — M2 measurement sets them**;
    the implementer records the measured curves before freezing values, exactly as
    the equipment round recorded its tier anchor derivation.

### D2 — Fortune consumer: implement the screen promise verbatim (P2, option (a))

- `scripts/data/trait_effects.gd` gains the pure-static consumer:
  `fortune_reroll_budget(fortune: int, has_deep_fortune: bool) -> int` =
  `1 + floor(max(0, fortune - 10) / 10) + (1 if has_deep_fortune else 0)`
  (PROVISIONAL curve; tiers at fortune 10/20/30 → 1/2/3 yearly rerolls, +1 trait).
  This is the sanctioned `trait_effects.gd` extension surface; the trait hook
  `yearly_event_reroll` finally gets its reader (`profile.has_trait("deep_fortune")`).
- `scripts/segments/cultivation.gd` EVENT phase: new `rerolls_left` surface +
  reroll affordance (keyboard action `event_reroll` + a code-built
  `EventRerollButton` rendered in the existing event options flow, visible only
  when `rerolls_left > 0`). Pressing it: decrement the year-scoped counter
  (`profile.flags` is wrong for this — see the D-schema note below), re-draw
  `event_id = EventLogic.draw_unseen_id(profile, SaveManager.rng)` (ONE draw, the
  same op the original draw used), publish `event_title`/`event_body` via the
  existing `_sync_surface()`, receipt via `status_text` (new i18n string with the
  remaining count). The reroll budget counter lives in `profile.deeds`
  (`rerolls_used_this_year`, zeroed in `_advance_year` — the editable year-reset
  point), so it survives save/load for free.
- `scripts/segments/creation.gd::_ATTR_DESCS["fortune"]` is updated to the
  implemented mechanic, verbatim-consistent with the trait description:
  「影响事件与奇遇(福缘越高，每年游历事件可重掷次数越多)」 (PROVISIONAL wording;
  final wording lands with the i18n task). The `creation_attr_effect_info`
  scenario's copy pins are re-derived in the same task (documented change table —
  this is the one sanctioned existing-scenario touch outside the protected trio).
- Rejected: (a) removing the promise instead — the brief prefers a real consumer
  and the mechanism already has a defined hook and trait; (b) fortune-scaled event
  pool weighting — that changes `draw_unseen_id` op order (lifeline) for a benefit
  the screen never promised; (c) wiring `map_inquire` too — out of scope (recorded
  by Step 1 as record-only).
- Honest boundary recorded for 5_design: `map_inquire` (江湖阅历) remains
  unimplemented after this round — the creation-screen TRAIT list is not touched by
  this round; only the ATTR promise is resolved. The residual stays recorded.

### D3 — Four monthly actions, four measured niches (P3)

Mechanism edits in `cultivation.gd::_apply_action` (+ action-list copy), all
zero-new-RNG:

| Action | Now (measured shape) | New niche (PROVISIONAL constants) | Why it is unique |
|---|---|---|---|
| 练功 practice | +1 practice, target art chosen | **+2 practice** into the player-CHOSEN art | the only action where the player picks WHICH art advances (cards dump into first-unmastered); the only path up the 甲 prereq cascade |
| 修习 cultivate | wisdom-gated +1..3 attr | unchanged (kept) | the only repeatable attribute source among the four |
| 做工 work | flat +10 silver | **+10 + 2 × mastered_count** silver | the only action whose yield *compounds with the run*; strictly the best repeatable silver source (a free card is one-shot, the economy deck exhausts) |
| 游历 travel | event draw | unchanged draw; **now interacts with fortune (reroll budget) and feeds `deeds.travel_resolved`** | the only item source and the only action fortune acts on |

- The screen shows the difference: each ACTION_PICK row gets a one-line effect
  suffix (new i18n strings), and `CultivationScreen` publishes `last_action_kind`
  + `last_yield_text` (e.g. 「做工：银两 +14」) for the differential nails.
- Measurement instrument (M1): a GDScript unit harness
  (`tests/test_action_yield_curves.gd`, NEW) runs the REAL `_apply_action` math
  (static-extractable: the per-action yield helpers live in
  `scripts/data/progression_math.gd` — NEW pure static — so the curve measurement
  needs no scene) over 36 seeded months × 5 single-action strategies + 1 balanced
  strategy, and records the yield table into `design/40_progression.md` §3 (5_design).
  Playtest nails then pin the *differential* facts on screen, never the numbers:
  - N-3a: a work-month yields strictly more silver than each of the other three
    actions' silver yield, measured on the same seeded save (4 comparisons).
  - N-3b: a practice-month advances the targeted art's practice strictly more than
    a card-only month.
  - N-3c: pre-fix red evidence: on the current tree `work` (+10) ≤ one free card
    (`gr_silver_30` +30) — measured once, recorded as the red value.
- Rejected: tying work income to fortune (would double-book fortune's consumer);
  making travel grant practice (would erase practice's niche); raising work to a
  flat 30+ (still dominated by `art_silver_500` and re-opens the R2 silver→attr
  facility redemption pressure the cap just closed).

### D4 — Huashan winnable through the sanctioned stat surface, pre-warned on two editable screens (P4)

**Winnability (player-side battle numbers only):**

`scripts/data/battle_setup.gd::derive_stats` gains a cultivation term (PROVISIONAL
coefficients, finalized by M3):

```
m  = Σ over profile.gongfa mastered: 1                     (count)
mp = Σ over mastered arts: GRADE_POINTS[grade]             (D=1 C=2 B=3 A=4, same table as D1)
max_health  = bone*5      + 6*mp + gear.health      (135 → ~200+ on a normal route)
energy      = inner*2     + 4*mp + gear —           (finisher affordability late-run)
initiative  = agility      + 3*mp + gear.initiative  (25 → ~45-60: player acts before
                                                       the 70-initiative greats' second
                                                       wind, not before round 1 globals)
attack_damage / move_range / attack_range: UNCHANGED (keep the fight's texture)
```

- Why these levers: they are pure functions of the SAME persisted profile the
  ending reads — three years of practice/cultivate/work visibly cash out in the
  finale — and they live entirely in `battle_setup.gd` (editable, sanctioned).
  Enemy numbers, roster, positions, and the round-1 damage-floor layout in
  `MapBattleData`/`battlefield.gd` are untouched, so the fight's challenge is
  structurally intact (5 enemies, 560 total HP, same AI).
- `build_character` needs no signature change (it already calls `derive_stats`).
- Regression duties from this change (task T5's checklist):
  `equipment_in_battle_diff` 47/47 (gear differentials still `changed`),
  `cultivation_changes_combat` 30/30 (differentials, not literals),
  `map_battle_node_huashan` 41/41 **verbatim** (`max_health != 1000 and > 0`
  trivially holds; `turn_order.size() == 6` untouched),
  `terminal_victory_8_12_rounds_hp_15_40` 6/6 (tutorial path does not use
  `derive_stats` — verify by read, not by hope).
- Winnability proof (N-4c, the round's flagship nail): a seeded, normally-played
  route (balanced actions, no min-max) runs 36 months on screen, travels to 华山,
  and WINS the duel with real skill clicks + end turns (the same click grammar the
  existing `map_battle_node_huashan` win leg uses), asserting the WIN → MAP return.
  Red-first: the same route on the pre-fix tree measured LOSING (record the frame).
  Challenge preservation (never nerfed to triviality) is pinned structurally, not
  numerically: the same scenario asserts the player did NOT end at full health
  (`health < max_health` differential) — a fight won untouched is a red flag, and
  the assertion says so without pinning any HP literal.

**Advance warning (two editable surfaces, zero locked-file edits):**

- `BattleSetup.readiness(profile) -> {power: int, verdict_key: String}` where
  `power = max_health/5 + attack_damage + initiative/2` (PROVISIONAL composite) and
  `verdict_key ∈ {"huashan_weak", "huashan_even", "huashan_strong"}` against
  `MapData.HUASHAN_BAR = {"even": E, "strong": S}` (NEW const in the editable data
  layer; values set by M3 from the winnable-run measurement).
- Surfaces: `RosterPanel.readiness_text` (visible on map AND cultivation via the
  existing panel) + a `CultivationScreen` body line from year 3 month 1 onward —
  both render 「华山论剑评估：…」 so the warning exists for the ~30 months BEFORE
  the map even opens. All strings → `i18n.gd` EN dictionary.
- Differential nail (N-4a): two seeded profiles (creation-fresh vs mid-grown)
  produce **different** verdict strings (never a literal power number).

### D5 — Persistence: `profile.deeds`, additive with legacy repair (P1/P2/P3 carrier)

- New field `var deeds: Dictionary = {"work_months": 0, "cultivate_months": 0,
  "practice_months": 0, "travel_resolved": 0, "silver_earned": 0,
  "rerolls_used_this_year": 0}` — String keys only (JSON-lossless, per the
  `equipped` precedent comment in `player_profile.gd:24-29`).
- `to_dict()` adds `"deeds": deeds.duplicate()`; `from_dict` coerces each known
  key with `maxi(int(v), 0)` and **defaults missing keys to 0** (legacy saves load
  clean — mirrors the `equipped` repair philosophy; nothing wiped, nothing crashed).
- `save_load_roundtrip` 14/14 stays green: the field round-trips symmetrically.
- Increment points (all in editable files): `_apply_action` (per kind),
  `_apply_event_option` success path (`travel_resolved`, `silver_earned` when an
  event pays), `_apply_card` (`silver_earned` on silver cards), `_advance_year`
  (`rerolls_used_this_year = 0`).

### D6 — What is intentionally NOT built (scope discipline)

- No companion/party work, no sect-relations, no 同伴 recruitment (Out of scope).
- No new map nodes, no new battle slots, no `map.gd` edits of any kind (locked).
- No change to R2 rules: facility cap 2/month, no-re-settlement, all-or-nothing
  purchases, soft-lock exit — all preserved verbatim; deed/rebalance code must not
  touch `_resolve_node_event`, `FACILITY_MONTHLY_USE_CAP`, or `EventLogic`'s
  validate-then-apply contract.
- No UI theme/geometry work: `assets/themes/global_theme.tres`,
  `scenes/ui/{tutorial_overlay,roster_panel,hud}.tscn`,
  `scenes/segments/sect_select.tscn` untouched. The new reroll button and readiness
  lines are code-built controls inside existing containers in
  `scripts/segments/cultivation.gd` / `scripts/ui/roster_panel.gd` (their .tscn
  files stay unopened), and every touched frame re-asserts
  `UiOcclusionWatch.violations == 0 and scan_ok == true` inside the new nails.
- `ending.gd` gains text content only (existing `BodyLabel`, no new nodes) — the
  ending screen's geometry stays as-is.

### D7 — RNG-stream safety ledger

| Change | RNG ops added on old paths | New-path ops |
|---|---|---|
| deeds increments, work scaling, +2 practice | 0 | 0 |
| Ending evaluation / readiness | 0 | 0 |
| fortune reroll | 0 | 1 × `draw_unseen_id` per press (player-initiated only) |
| derive_stats extension | 0 | 0 |

`save_load_roundtrip` and `event_travel_effects` must re-run green in the
consolidated gate; the reroll nail declares its own seeded stream in its header.

---

## 5. Component list & interfaces (file-by-file, repo-root-relative)

| # | File | Status | Change |
|---|---|---|---|
| 1 | `scripts/data/progression_math.gd` | **NEW** | Pure static: `GRADE_POINTS`, `mastery_points(profile)`, `work_income(mastered_count)`, `deed_score(deeds)`, `readiness_power(stats)`. Zero autoload refs; consumed by 2/4/6; unit-tested headless. |
| 2 | `scripts/data/ending_logic.gd` | **NEW** | `evaluate(profile, deeds) -> {score, tier, axes, summary_lines}`; the ONLY tier-scoring path. |
| 3 | `scripts/data/player_profile.gd` | edit | `deeds` field + `to_dict`/`from_dict` additive repair (D5). |
| 4 | `scripts/data/map_data.gd` | edit | `ENDING_TIERS` → `min_score` rows (values from M2); NEW `HUASHAN_BAR` const; `ending_tier_score()` replaces `ending_tier()`. |
| 5 | `scripts/data/trait_effects.gd` | edit | NEW `fortune_reroll_budget(fortune, has_deep_fortune)` (pure). |
| 6 | `scripts/data/battle_setup.gd` | edit | `derive_stats` mastery terms (D4); NEW `readiness(profile)`; `_attr` untouched. |
| 7 | `scripts/segments/cultivation.gd` | edit | deed instrumentation; work/practice rebalance; ACTION_PICK copy lines; EVENT reroll affordance + `rerolls_left`/`last_action_kind`/`last_yield_text` surfaces; `_advance_year` reroll-budget reset; body line year ≥ 3. |
| 8 | `scripts/segments/ending.gd` | edit | compute via `EndingLogic.evaluate`; render axis summary into `BodyLabel` (existing node); surfaces `score`, `evaluation_text`. |
| 9 | `scripts/ui/roster_panel.gd` | edit | readiness line (`readiness_text`) via `BattleSetup.readiness` — warning visible on map + cultivation. |
| 10 | `scripts/segments/creation.gd` | edit | `_ATTR_DESCS["fortune"]` honest copy (D2); `_step_cost`/`START_POINTS` untouched. |
| 11 | `scripts/autoload/i18n.gd` | edit | EN-dict appends only (Chinese-as-key convention). |
| 12 | `project.godot` | edit | `[input]` action `event_reroll` (R key + ui_select alias). |
| 13 | `playtest/_common.yaml` | edit | **append-only**: surfaces (`CultivationScreen.rerolls_left/last_action_kind/last_yield_text`, `EndingScreen.score/evaluation_text`, `RosterPanel.readiness_text`) + `scenario_order` tail appends. |
| 14 | `playtest/ending_divergent_playstyles.yaml` | **NEW** | Nail N-1a (two playstyles → different evaluations). |
| 15 | `playtest/ending_last_month_choice.yaml` | **NEW** | Nail N-1b (month-36 flip changes evaluation). |
| 16 | `playtest/fortune_reroll_budget.yaml` | **NEW** | Nail N-2 (reroll replaces drawn event, budget decrements, exhausted state inert). |
| 17 | `playtest/action_yield_differential.yaml` | **NEW** | Nails N-3a/3b (per-action unique-yield differentials). |
| 18 | `playtest/huashan_readiness_warning.yaml` | **NEW** | Nail N-4a (verdict differs weak vs strong; occlusion watch on the touched frames). |
| 19 | `playtest/huashan_winnable_normal_route.yaml` | **NEW** | Nail N-4c (normal route wins the duel; asserts a non-trivial fight). |
| 20 | `tests/test_ending_logic.gd` | **NEW** | Unit: scoring monotonicity, tier scan, deeds schema, legacy-deeds defaults, divergence property. |
| 21 | `tests/test_action_yield_curves.gd` | **NEW** | M1 instrument: 36-month seeded per-strategy yield curves (the measurement run IS a test artifact). |
| 22 | `tests/test_battle_setup_readiness.gd` | **NEW** | Unit: derive_stats mastery terms, readiness bands, gear additivity preserved, tutorial-path isolation (by construction). |
| 23 | `tests/test_ending_gate_pins.py` | **NEW** | stdlib anti-weakening door over the new nails' load-bearing literals (mirrors `test_map_battle_gate_pins.py`). |
| 24 | `tests/test_playtest_contract_smoke.py` | edit | `ROUND_SCENARIOS` two-place tail sync + surface-append guards. |

Never touched: the six locked files, the three verbatim gates, `event_data.gd`,
`facility_data.gd`, `card_data.gd` values, theme/UI-geometry files,
`scenes/segments/map.tscn` (its `HintLabel.text` is text-contract-pinned),
`scripts/autoload/ui_occlusion_watch.gd`.

---

## 6. Playtest contract (Architect-owned observables + scenario skeletons)

Surfaces (all appended to `_common.yaml` — append-only):

```
CultivationScreen: rerolls_left, last_action_kind, last_yield_text   # + existing set
EndingScreen:      score, evaluation_text                            # tier already exposed
RosterPanel:       readiness_text
```

Scenario skeletons (PM fills thresholds; every nail is a differential, zero
balance literals; each carries a RED-FIRST EVIDENCE header block with the four
house values: failing frame / first failing assert / exact observed / greens
before red):

1. `ending_divergent_playstyles` — debug-seeded fresh save → 36 months of
   work-heavy clicks → ENDING: capture `score`/`tier`/`evaluation_text`; second
   leg (same seed, practice-heavy) → assert the evaluation record DIFFERS from
   leg 1. Skeleton asserts `EndingScreen.tier >= 1` early, then the differential.
2. `ending_last_month_choice` — seeded save near month 36 → leg A: month-36 work →
   record evaluation; debug-reload same save → leg B: month-36 练功 → assert
   evaluation record differs from leg A (same-frame comparison discipline).
3. `fortune_reroll_budget` — seed a profile with fortune ≥ 20 via the seeded
   creation path → travel draw → press `event_reroll` → assert `event_id`
   changed, `rerolls_left` decremented, `event_title`/`event_body` re-published;
   second leg: exhaust the budget → reroll press is inert (no change, receipt
   non-empty); third leg: `UiOcclusionWatch.violations == 0` on the reroll frame.
4. `action_yield_differential` — same seeded start, four one-month legs
   (work/practice/cultivate/travel): assert `last_yield_text` non-empty per leg
   and the silver differential `silver(work leg) > silver(each other leg)`;
   practice leg asserts the TARGET art's practice advanced (targeted-niche proof).
5. `huashan_readiness_warning` — boot a creation-fresh profile →
   `RosterPanel.readiness_text` == weak verdict; grant cultivation via the seeded
   month loop → verdict differs. (Differential on the verdict string, never on a
   power literal.)
6. `huashan_winnable_normal_route` — full seeded balanced route (clicks-only
   month grammar: `CultOptionButton0` + `CultOptionButton2`, year-boundary clicks)
   → map → travel to 华山 → fight with real skill clicks + `end_turn` → assert
   WIN → `current_state == "MAP"` → assert `health < max_health` at the win frame
   (fight was real). This is the round's flagship nail and the longest scenario;
   its frame budget follows the `map_battle_node_huashan` precedent (≤ 2999 hard cap).

GDScript unit suite (headless, seeded — the cheap differential workhorse):
`tests/test_ending_logic.gd` (divergence + monotonicity + legacy schema),
`tests/test_action_yield_curves.gd` (the M1 curves),
`tests/test_battle_setup_readiness.gd` (stat math + bands).

---

## 7. Measurement plan (M1–M3, red-first, all on the current post-R2 tree)

- **M1 — per-action yield curves** (`tests/test_action_yield_curves.gd`): 5
  single-action strategies + 1 balanced, 36 seeded months each; outputs
  silver earned / practice points / attr points / events resolved per strategy.
  Feeds D3's provisional constants; the table lands in `design/40_progression.md`
  §3 with the run label ("measured 2026-09-01, R3 M1, seeded run").
- **M2 — ending score curves**: the same runs scored by `EndingLogic.evaluate`
  BEFORE thresholds are chosen; thresholds set so T-1..T-4 (D1) hold; the chosen
  values + the curves are recorded with their run id.
- **M3 — Huashan readiness & win rate**: `tests/test_battle_setup_readiness.gd`
  + the winnable scenario run under ≥ 5 distinct seeds with a fixed competent
  input script; target: normal route wins on the majority of seeds while the
  creation-fresh profile still loses (challenge preserved). Both facts recorded
  with their runs. If the sanctioned levers cannot reach "has a chance" without
  trivializing the fight, STOP and escalate the recorded contingency (§0) — never
  silently weaken the roster.

Every nail's red is MEASURED on the pre-fix tree (temporary-revert discipline,
`TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` markers, restored byte-identically,
zero residue — house standard), never predicted. Any nail that cannot be measured
records 「未执行 + 原因」 honestly.

---

## 8. Regression-safety matrix (what must stay green and why it survives)

| Existing gate | Why it survives this design |
|---|---|
| `spine_to_ending` 42/42 | cultivation month flow untouched (only `_apply_action` internals + copy); ENDING asserts don't pin tier values. |
| `clicks_only_storyline` 47/47 | same; reroll button only exists in EVENT phase and is optional (never required to advance). |
| `save_load_roundtrip` 14/14 | `deeds` is additive + symmetric; `from_dict` legacy-repair mirrors the `equipped` precedent. |
| `event_travel_effects` 19/19 | zero new RNG on the travel path; reroll sits on a NEW input only. |
| `softlock_empty_practice_month_advances` 15/15 | the empty-GONGFA exit block is untouched (deed increments only wrap `_apply_action`, which the empty path never calls). |
| `facility_use_reusable` / `map_node_event_shaolin` / `map_battle_node_huashan` (verbatim trio) | none of the three files' bytes are touched; deed counters are separate from `events_resolved_count`; `map_battle_node_huashan`'s `max_health != 1000` holds under the new formula. |
| `terminal_victory_8_12_rounds_hp_15_40` 6/6 | tutorial battle uses编排数值, never `derive_stats` (verify by read in T5). |
| `equipment_in_battle_diff` 47/47, `cultivation_changes_combat` 30/30 | gear/attr differentials remain differentials; mastery terms only add. |
| `event_pool_new_event_resolved` 15/15 | draw → render → resolve chain untouched; reroll is an additional affordance, not a replacement. |
| `occlusion_no_button_over_text` 22/22 | new controls are code-built in existing layouts; the new nails re-assert `violations == 0` on their touched frames. |
| i18n coverage guards | every new string lands in the EN dictionary in the same task that adds it. |

---

## 9. 设计变更 (for 5_design to fold into `design/` after acceptance)

1. `design/40_progression.md` §7 (派生公式): `气血 = 根骨×5` →
   `气血 = 根骨×5 + 6×修为点` etc. (PROVISIONAL until M3); new §「结局评价」
   (multi-axis formula + measured curves + thresholds + run ids); new §「福缘」
   (reroll budget formula + the honest `map_inquire` residual); §3 monthly-action
   table updated to the four niches with the M1 yield table.
2. `design/20_content.md`: no content-table changes (event/facility/card data
   untouched); the Huashan §11 record gains the readiness/warning surface note.
3. `design/90_decisions.md`: rulings for D1–D4 incl. the rejected alternatives
   and the MapBattleData lock reading (§0).
4. `design/99_changelog.md`: one appended row (2026-09-01, this round).
5. `design/10_systems.md` §1 属性表: 福缘 row's 养成意义 gains the implemented
   reroll wording (matches the creation screen).

## 10. Rollback / reversibility

No irreversible operations exist in this design: no schema migration (additive
`deeds` with legacy defaults), no data rewrites (all data files byte-untouched),
no deletes. Rollback = revert the task's file set; legacy saves keep loading
(with deeds defaulting to 0 → tier computed from attrs+mastery only, never a
crash). The temporary red-first reverts follow the house
mark-and-restore discipline with zero-residue verification.

## 11. 扩展性考虑 (extension points, deliberately few)

- `EndingLogic.axes` is a dictionary — future rounds add axes (battle results,
  companion deeds) without touching the scan; `HUASHAN_BAR` generalizes to a
  per-battle-id requirement table when a second map battle lands.
- `TraitEffects.fortune_reroll_budget` is the single fortune hook site — new
  fortune consumers (event quality, encounter luck) slot next to it.
- `progression_math.gd` is the shared numeric home so D1 and D4 never drift apart.

## 12. 给 PM 的任务分解建议 (dependency-ordered)

1. `T1 schema` — `player_profile.deeds` + roundtrip tests (blocks everything).
2. `T2 math home` — `progression_math.gd` + unit tests (blocks T3/T5/T6).
3. `T3 actions` — cultivation deed instrumentation + work/practice rebalance +
   copy + surfaces; M1 curves; yield nails.
4. `T4 fortune` — `fortune_reroll_budget` + reroll affordance + input + i18n +
   nail; creation copy sync.
5. `T5 ending` — `ending_logic.gd` + `MapData` thresholds (after M2) + ending.gd
   summary + divergence/last-month nails.
6. `T6 huashan` — `derive_stats` extension + readiness + warning surfaces (after
   M3) + winnable scenario + anti-weakening pytest.
7. `T7 sync` — `_common.yaml`/`ROUND_SCENARIOS` sync, i18n sweep, pytest guards,
   consolidated red-first evidence file under `final/`.

Tasks 3/4/5/6 are parallelizable after 1+2; every task lands its own nail with
its own measured red before its green.