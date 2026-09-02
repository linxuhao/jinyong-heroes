# Delivery Notes — r3c_readiness_bands_fresh_max

## Date
2026-09-02

## Card
r3c_readiness_bands_fresh_max — Readiness bands: measure P_fresh_max, set
even = P_fresh_max + 1, fresh weak by construction.

## P_fresh_max derivation
Budget-optimal creation allocation under creation.gd's real rules
(START_POINTS 30, ATTR_MIN 10, ATTR_MAX 20, _step_cost 1 below 15 / 2 from 15 up):

- All 30 points into bone + agility.
- bone 10→20: 10→15 costs 5 (5 pts), 15→20 costs 10 (5 pts × 2) = 15 pts.
- agility 10→20: 10→15 costs 5, 15→20 costs 10 = 15 pts.
- power = floor(100/5) + 30 + floor(20/2) = 20 + 30 + 10 = 60.
- bone is most efficient (2 power/pt vs 0.5 power/pt for agility);
  inner / wisdom / fortune contribute 0 to readiness_power.

Instrument: `tests/test_battle_setup_readiness.gd::_print_p_fresh_max()`
enumerates the 11^5 allocation space and prints the budget-optimal allocation +
the integer. The instrument print is the record; hand arithmetic is verification
only.

## The three measured numbers
- **P_fresh_max = 60** (budget-optimal creation allocation: bone 20, agility 20,
  others 10).
- **even = 61** (= P_fresh_max + 1).
- **strong = 124** (measured 36-month strong-route power; must exceed even).

## The decision
- **even = P_fresh_max + 1 = 61**: every fresh profile is weak BY CONSTRUCTION
  (power <= P_fresh_max < even). The f260 literal
  `readiness_text == "华山评估：战备不足"` stays byte-identical — no yaml literal
  moves in the band-right outcome.
- **strong = 124**: the old "strong stays 55" ruling is infeasible under
  even = 61 (55 > 61 is false, breaking the `strong > even` ordering invariant).
  Re-derived from the measured strong-route power (124), which exceeds even.
- **Honest red**: the real 36-month balanced route (power 40) lands below even
  (61) → reads weak. Recorded in M3''' as "36-month balanced route reads weak —
  growth is flatter than creation's point spend" and handed to the next round.
  even is NOT lowered; the string follows the band and the band follows the
  measurement.
- **f350 re-anchored** to a real grown save (36-month fast-forward), property
  pin against the f260 verdict string (never a power literal).

## Files changed
- `scripts/data/map_data.gd` — HUASHAN_BAR.even = 61, strong = 124; pointer
  comment → M3'''.
- `tests/test_battle_setup_readiness.gd` — `_print_p_fresh_max()` instrument +
  `_p_fresh_max()` enumeration + P_fresh_max allocation → weak unit pin; the
  five-10 pin stays verbatim.
- `design/40_progression.md` — M3''' section (additive rows).
- `playtest/huashan_readiness_warning.yaml` — f260 byte-identical; f350
  re-anchored to a real grown save.
