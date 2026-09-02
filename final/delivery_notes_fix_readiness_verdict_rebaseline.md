# Delivery Notes — fix_readiness_verdict_rebaseline

> Date: 2026-09-02 · Card: `fix_readiness_verdict_rebaseline` · Outcome: **STOP-and-report**
> (the card's third, sanctioned outcome — neither band-wrong (i) nor band-right (ii) is executed)

## Measured red (official gate, quoted verbatim)

`playtest_summary.md` (2026-09-02): `huashan_readiness_warning` **20/21**.
- f260 `RosterPanel.readiness_text == "华山评估：战备不足"` → observed **`华山评估：势均力敌`**.
- f350 STRING differential pin is GREEN.

## The three measured numbers (recorded BEFORE any edit)

### 1. The fresh profile's readiness_power on THIS exact boot = **45**

The scenario boot (f110–f150) presses **five `move_right`** with **no `move_up`/`move_down`** in between
(verified: `playtest/huashan_readiness_warning.yaml:88-102`). In the ATTRS phase, `_on_move_right()`
(`scripts/segments/creation.gd:495-504`) increments the **focused attr row** — which stays row 0 = `bone`
throughout (no row movement). Starting from the creation defaults `{"bone":10,"inner":10,"agility":10,
"wisdom":10,"fortune":10}` (`creation.gd:34`), five `move_right` make **bone 15, others 10** — exactly the
brief's "真实新档 根骨 15、0 大成".

With `mp = 0` (2 D arts unmastered) and empty gear, `BattleSetup.derive_stats` (`battle_setup.gd:46-59`):
- `max_health = bone*5 + 6*mp + gear.health = 15*5 + 0 + 0 = 75`
- `initiative = agility + 3*mp + gear.initiative = 10 + 0 + 0 = 10`
- `attack_damage = 10 + bone + gear.attack = 10 + 15 + 0 = 25`

`ProgressionMath.readiness_power` (`progression_math.gd:65-69`):
`floor(75/5) + floor(25) + floor(10/2) = 15 + 25 + 5 = **45**`.

### 2. Provenance of the current bands `{even: 38, strong: 55}`

`scripts/data/map_data.gd:64` `HUASHAN_BAR = {"even": 38, "strong": 55}`, set by the M3' re-derivation
(`design/40_progression.md` §M3', measured 2026-09-02, real-save, seeds 20260901..20260905). The M3' seed
rows that produced the thresholds:
- **lowest** (creation-fresh, five attrs 10, 0 mastered) → power **35** → weak (5/5 seeds)
- **balanced** (attrs 11 post-creation + 1 D mastered, mp=1) → power **40** → even (5/5 seeds)
- **strong** (5 A mastered + grown attrs) → power **124** → strong (5/5 seeds)

`even = 38` sits strictly between the lowest power (35) and the balanced power (40); `strong = 55` sits
strictly below the strong power (124). Both thresholds are the M3' measured assignments.

### 3. Band arithmetic — unsatisfiable

For THIS boot's fresh profile (power **45**) to land **weak**, we need `even ≥ 46`.
For the M3' **balanced** assignment (power **40** → even) to hold, we need `even ≤ 40`.
`40 < 46` ⇒ **no single `even` value satisfies all three M3' assignments simultaneously**
(fresh-boot 45 → weak / balanced 40 → even / strong 124 → strong).

## Decision: STOP-and-report (card's third outcome)

The card's rule: "If NO single `even` value satisfies all three M3' assignments simultaneously, STOP and
report the conflict — do not fudge a threshold." That is exactly the situation. **Neither sanctioned
outcome is executed:**

- **(i) BAND WRONG — NOT executed.** Raising `even` above 45 would break the M3' balanced assignment
  (power 40 would fall into weak) — the card-prohibited fudge. Note: the M3' "creation-fresh 35 → weak"
  assignment is **still valid and still unit-pinned** (`tests/test_battle_setup_readiness.gd:141-144`:
  five-10 profile → `huashan_weak`, green). The drift is in the **scenario boot's attr allocation**
  (bone 15, not five-10), not in the bands.
- **(ii) BAND RIGHT — NOT executed.** Rewriting the f260 literal to `势均力敌` would move the line to
  green while leaving a **vacuous differential** (see below). Card-prohibited.

## Full line-by-line derivation

1. Boot presses five `move_right` (f110–f150), no row movement → bone 15 / others 10
   (`huashan_readiness_warning.yaml:88-102`, `creation.gd:34`, `creation.gd:495-504`).
2. `derive_stats` with mp=0, empty gear → max_health 75, initiative 10, attack_damage 25
   (`battle_setup.gd:46-59`).
3. `readiness_power = floor(75/5) + floor(25) + floor(10/2) = 45` (`progression_math.gd:65-69`).
4. `BattleSetup.readiness` (`battle_setup.gd:67-78`): 38 ≤ 45 < 55 → `huashan_even` → **势均力敌**,
   matching the official observed string exactly.
5. Unsatisfiability: fresh-boot 45→weak needs `even ≥ 46`; M3' balanced 40→even needs `even ≤ 40`;
   `40 < 46` ⇒ no single `even` satisfies all three M3' assignments.
6. Both sanctioned outcomes are card-prohibited fudges (see Decision above).

## f350 vacuous-differential note (pre-existing defect, recorded as a handoff)

`playtest/huashan_readiness_warning.yaml:176` asserts `readiness_text != "华山评估：战备不足"` — it
compares against the **stale literal**, not against the f260 captured string. On today's tree it is
**vacuously green** (both 45 and 47 differ from `战备不足`). Moreover, after 2 practice months
`mp = 1` → `power = floor(81/5) + 25 + floor(13/2) = 16 + 25 + 6 = **47**` — still in the even band, so
"growth changes the verdict" is **unsatisfiable on this boot** (the stale comments at `yaml:121-122`
"attrs 11 / power 37" and `yaml:170-171` "power 35 < even 37" assumed a power 35→37 crossing that the
actual boot never produces).

**Handoff:** the closure card `fix_honesty_records_reconcile` should upgrade f350 into a property pin that
compares against the **f260 captured string** (never a power literal). This card does not fix it — it is
recorded here as a pre-existing defect, not something this card introduced or is expected to fix.

## Cross-card note (so the two measurements are not read as conflicting)

`fix_huashan_route_honest_red` (a later row) feeds `mp` into `attack_damage`/`move_range` per the unlock
ruling. A creation-fresh profile has `mp = 0`, so **this boot's weak-band assignment is unaffected** by
that change. Grown-profile bands are re-verified post-unlock in that card's M3'' table. This card's
measurement (fresh-boot power 45 → even) and that card's M3'' re-derivation are therefore **not in
conflict** — they measure different profiles (fresh boot vs grown routes).

## Artifacts delivered / withheld

- **Delivered:** `final/delivery_notes_fix_readiness_verdict_rebaseline.md` (this file) + one dated
  2026-09-02 note row appended to `design/40_progression.md` §M3' (existing M3' table rows untouched).
- **Withheld (per the card's STOP-and-report clause):** `scripts/data/map_data.gd` (HUASHAN_BAR stays
  `{"even": 38, "strong": 55}`), `playtest/huashan_readiness_warning.yaml` (f260 literal and f350 line
  byte-identical), the scenario registries, and `design/99_changelog.md` (no changelog row this card;
  the closure is recorded after the owner rules on the conflict).

## Zero game-code edits

This card makes **zero** edits to `scripts/data/map_data.gd`, `playtest/huashan_readiness_warning.yaml`,
the scenario registries (`playtest/_common.yaml`, `tests/test_playtest_contract_smoke.py`), or
`design/99_changelog.md`. Six-file lock and three verbatim gates untouched. Zero new RNG ops (no game-code
change at all). HUASHAN_BAR / readiness_power are never re-tuned to force a string green — the string
follows the band, and the band follows the measurement; here the measurement landed on the stop condition.

## Interface contract (unchanged by construction)

- `RosterPanel.readiness_text` keeps publishing `华山评估：<verdict>` from the single formula source
  `BattleSetup.readiness` → `ProgressionMath.readiness_power(derive_stats(profile))`.
- `MapData.HUASHAN_BAR` stays `{"even": 38, "strong": 55}`.
- The f260 weak-band literal and the f350 differential line stay byte-identical.
- Consumed by `fix_honesty_records_reconcile` (C4 closure: record the reported conflict, not a green);
  superseded by `fix_huashan_route_honest_red`'s post-unlock M3'' re-derivation.
