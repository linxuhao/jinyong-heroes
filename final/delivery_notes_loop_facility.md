# Delivery Notes — jinyong-loop R2 · facility_monthly_cap

**Date:** 2026-09-01
**Task:** `facility_monthly_cap` — cap facility uses at 2 per profile month with
an on-screen exhausted receipt, so silver can no longer be converted into
unlimited ending score at zero month cost.

## 1. What was built

The facility defect (`scripts/segments/map.gd:298-332`): `_use_facility()` had a
silver pre-check but NO use cap, no cooldown, no month cost; the FACILITY-phase
`ui_accept` re-used immediately. Measured by the driver: 少林木人巷 40 presses
(~10s) → bone 10→91, silver 1844 left, ending jumped lowest → highest tier.

The fix (design D2) is a **per-month cap = 2** — a RULE GATE, not a balance
number (no facility cost/effect value moves; `facility_data.gd` byte-untouched):

1. **`scripts/autoload/game_manager.gd`** — two session mirrors
   `facility_use_month: int = -1` and `facility_use_count_this_month: int = 0`,
   reset in the SAME handler as `map_events_resolved_count`
   (`_reset_map_events_resolved_count`, connected to `SaveManager.loaded` /
   `profile_created`). Session-scoped only — never persisted, no save-schema
   change. This is the proven `map_events_resolved_count` pattern (`:125-131`):
   the MapScreen is rebuilt on return from a map battle, so its own per-month
   counter would reset to 0; the mirror carries the (month, count) pair across
   the swap.
2. **`scripts/segments/map.gd`** — new `const FACILITY_MONTHLY_USE_CAP := 2`.
   In `_use_facility()`, AFTER the existing silver pre-check (kept byte-identical,
   `:324-331` — its refusal logic not moved), the epoch check:
   - if `GameManager.facility_use_month != SaveManager.profile.cultivation["month"]`:
     write the month into the mirror and zero the counter;
   - if `GameManager.facility_use_count_this_month >= FACILITY_MONTHLY_USE_CAP`:
     reuse the existing refusal shape — `_facility_refused = true` and
     `facility_result_text = tr("本月设施已用尽，下月再来")` (the panel prints this
     var — the same on-screen receipt channel the brief names as the reference),
     NO count increment, NO profile mutation, NO snapshot write, `_sync_surface()`
     + `_render()` + return.
   - On SUCCESS: write the epoch pair (month + incremented counter) into
     GameManager, keep the existing `facility_use_count += 1` and result text,
     and publish the success-only snapshot surfaces `last_use_silver` (=
     `SaveManager.profile.silver` post-apply) and `last_use_attr_value` (=
     `SaveManager.profile.get_attr(_facility_target_attr(fdef))` post-apply).
     `_facility_target_attr` reads the attr target off the def's effects
     (shaolin → "bone", wudang → "inner") so the snapshot stays literal-free.
3. **`scripts/autoload/i18n.gd`** — one EN-dictionary append (Chinese-as-key):
   `本月设施已用尽，下月再来` → "Facility uses exhausted this month, come back
   next month". No U+2026 ellipsis.
4. **`_sync_surface()` deliberately does NOT mirror `last_use_silver` /
   `last_use_attr_value`** — same precedent as `facility_result_text`; mirroring
   there would wipe the exhausted-frame value and break the zero-delta proof.

## 2. Files changed

| File | Change |
|---|---|
| `scripts/autoload/game_manager.gd` | Session mirrors `facility_use_month` / `facility_use_count_this_month`, reset in the same handler as `map_events_resolved_count`. |
| `scripts/segments/map.gd` | `FACILITY_MONTHLY_USE_CAP := 2`; epoch check + exhausted branch in `_use_facility()`; success-only snapshots `last_use_silver` / `last_use_attr_value`; `_facility_target_attr` helper. Silver pre-check preserved verbatim. |
| `scripts/autoload/i18n.gd` | 1 EN-dictionary append (Chinese-as-key). |
| `playtest/_common.yaml` | Append-only: `last_use_silver` + `last_use_attr_value` to the MapScreen surface block; `facility_use_cap_exhausted_zero_delta` to the scenario_order tail. |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` tail append + new `test_facility_use_cap_nail_contract` anti-weakening guard. |
| `playtest/facility_use_cap_exhausted_zero_delta.yaml` | NEW — the differential zero-delta nail. |
| `final/delivery_notes_loop_facility.md` | This note. |

## 3. New nail — `facility_use_cap_exhausted_zero_delta`

Mirrors `facility_use_reusable`'s sanctioned seed prefix to reach shaolin TRAVEL
at month 36 (boot → tutorial win → `debug_fast_forward` → travel luoyang →
shaolin, resolving the intermediate merchant / night_rain events), then funds
with `debug_grant_silver` BEFORE any use so the silver pre-check never masks the
cap. The player then enters the facility THREE times at the same node
(`use_facility` enter / `ui_accept` use / `move_down` leave — `_leave_facility`
only switches phase, and the session-scoped GameManager mirror is not reset on
entry, so three entries in one month prove cross-entry persistence of the cap
without re-exercising the travel/event legs that gate (a) already covers).

- use #1: `facility_use_count == 1`, `silver: changed`, `attr_bone: changed`,
  success snapshots published.
- use #2: `facility_use_count == 2`, `silver: changed`, `attr_bone: changed`,
  snapshots re-published post-apply.
- EXHAUSTED press (use_facility re-enter + ui_accept): REFUSED — no count
  increment, no profile mutation, zero-delta proof.

Asserts are DIFFERENTIAL, zero tuned literals (never `== 8`-style):
- `MapScreen.facility_use_count: facility_use_count == 2` (unchanged by the
  refused press — a ladder rung, gate-(a) style).
- `MapScreen.silver: silver == last_use_silver` (the success-only post-use-2
  snapshot — true iff the press changed nothing).
- `MapScreen.attr_bone: attr_bone == last_use_attr_value` (same zero-delta).
- `MapScreen.facility_result_text: facility_result_text != ""` (the exhausted
  receipt is on screen).

Both sides of each zero-delta comparison are MapScreen properties, so each is a
legal single-node Expression over the whitelisted surface.

## 4. RED-FIRST evidence (measured, never predicted)

Measured via the `godot_playtest_scenario` sidecar with a TEMPORARY RED-FIRST
REVERT applied to `scripts/segments/map.gd` (the cap threshold `>= 2` changed to
`>= 999`, so the third press was NOT refused — it applied effects and bumped the
count to 3), then restored byte-identically.

| # | Value |
|---|---|
| 1. Failing frame | **f720** |
| 2. First failing assert | `MapScreen.facility_use_count: facility_use_count == 2` |
| 3. Exact error / observed | `FAIL f720 MapScreen.facility_use_count: facility_use_count == 2  observed=3` (the revert removed the cap, so the third press applied effects and pushed the count to 3) |
| 4. Green asserts before red | **32** (sidecar `ok: 32, total: 33`; all 32 passing asserts precede the first failing one) |

The revert was restored byte-identically (the `>= 999` marker removed, the
`>= FACILITY_MONTHLY_USE_CAP` line re-read). No revert residue remains in the
working tree.

## 5. Green self-run (measured, this step)

Via the `godot_playtest_scenario` sidecar on the delivered tree (repo + staged
files):

| Scenario | Result |
|---|---|
| `facility_use_cap_exhausted_zero_delta` | **33/33** PASS |
| `facility_use_reusable` (gate a) | **49/49** PASS |
| `map_facility_buttons_click` | **38/38** PASS |
| `spine_to_ending` | **42/42** PASS |
| `save_load_roundtrip` | **14/14** PASS |

All five hard-gate passed with zero runtime errors.

## 6. Gate-(a) safety analysis

`playtest/facility_use_reusable.yaml` (verbatim-protected) uses the facility
exactly 2× in month 36, as two SEPARATE entries (enter → use → leave → travel →
re-enter → use), asserting `facility_use_count == 1` then `== 2` with silver/attr
`changed` each time. A per-month cap of 2 allows both uses in the same month, so
gate (a) stays green verbatim. Survey (re-verified): `map_facility_buttons_click`
also uses at most 2× in one month (2 entries), so cap=2 keeps it green too.
"Once per node per game" is BANNED by the brief and was NOT chosen. The cap
actually bounds the exploit: the measured 40 presses → +81 bone becomes ≤ 2
uses = +4/month.

The new nail's three entries at the same node (no travel legs) prove
cross-entry persistence of the session mirror without re-exercising the
travel/event legs that gate (a) already covers — the omission is deliberate, not
a gap: gate (a) already proves the leave-and-return reuse path, and this nail
proves the cap persists across entries within a month.

## 7. Red lines honored

- **Verbatim-protected trio untouched**: `playtest/facility_use_reusable.yaml`,
  `playtest/map_node_event_shaolin.yaml`, `playtest/map_battle_node_huashan.yaml`.
- **Protected files untouched**: `assets/themes/global_theme.tres`,
  `scenes/ui/{roster_panel,tutorial_overlay,hud}.tscn`,
  `scripts/autoload/theme_manager.gd`, `scripts/segments/sect_select.gd`, the
  focus-style portion of `cultivation.gd::_rebuild_options_box`, the six
  jinyong-huashan files.
- **No balance numbers move**: `facility_data.gd` / `event_data.gd` /
  `card_data.gd` values, `MapData.ENDING_TIERS`, Huashan difficulty.
  `FACILITY_MONTHLY_USE_CAP` is a rule gate, not a tuning value.
- **No U+2026 ellipsis characters** in any new string.
- **Zero RNG ops added** — the cap check is pure arithmetic; the seeded RNG
  stream's op order is unchanged.
