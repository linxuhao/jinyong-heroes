# Delivery notes — facility_playtest_scenario (jinyong-facility)

Task: land the 58th play-test scenario `facility_use_reusable` and grow the
append-only play-test contract around it (surface whitelist + actions +
scenario_order + ROUND_SCENARIOS + a hard anti-deletion pin), and record the
red-then-green window for the facility content type.

Dependency order note: this task depends on `map_facility_phase` (already
landed — `scripts/segments/map.gd` carries the FACILITY phase, the
`facility_id` / `facility_use_count` / `last_facility_effect_types` surface
vars, `_enter_facility` / `_use_facility` / `_leave_facility`, and the
`debug_grant_silver` debug action; `scripts/data/facility_data.gd` and the
`use_facility` / `debug_grant_silver` input actions exist). It does **not**
depend on `map_data_facility_flip`, which has **NOT** landed: every node's
facility slot is still `declared`, so `MapData.active_facility_id()` returns
`""` everywhere. This is the red-then-green window — this scenario is delivered
and its red run recorded **before** the flip lands.

## Files changed

- `playtest/facility_use_reusable.yaml` — NEW (58th scenario). Basename ==
  `name:` == `facility_use_reusable`.
- `playtest/_common.yaml` — append-only, three edits: MapScreen surface block
  gains `facility_id` / `facility_use_count` / `last_facility_effect_types`
  (after `events_resolved_count`); `actions:` gains `use_facility` /
  `debug_grant_silver` (after `debug_spend_player_qi`); `scenario_order:` gains
  `facility_use_reusable` at the tail (after `camera_transform_follows_unit`).
- `tests/test_playtest_contract_smoke.py` — `ROUND_SCENARIOS` gains
  `facility_use_reusable` at the tail (two-place sync); new
  `test_facility_use_reusable_surface_contract()` with the hard anti-deletion
  pin.
- `scripts/segments/map.gd` — MINIMAL runtime-error fix in the landed
  `map_facility_phase` code (documented in detail below). This task's scenario is
  the first thing to exercise the facility effect path, so this bug was only
  reachable through it.
- `final/delivery_notes_facility.md` — this file.

Untouched (by design): `playtest/map_node_event_shaolin.yaml`,
`playtest/spine_to_ending.yaml`, `tests/fixtures/playtest_assert_superset.json`,
`scripts/data/map_data.gd` (the slot flip is a sibling task), and every
camera / coordinate file. The one `.gd` exception is the minimal two-site
runtime-error fix in `scripts/segments/map.gd` documented below — the landed
facility effect path crashed and this scenario is its only exerciser.

## The scenario's two halves

- **Arrival half (permanent negative assertion — the definitional property).**
  Arriving at 少林 fires `night_rain` (EVENT phase) and does NOT enter the
  facility: `phase == "EVENT" and phase != "FACILITY"`, `facility_id == ""`,
  `facility_use_count == 0`, re-asserted after the event resolves (resolving an
  event cannot smuggle a facility use in). This is what makes "facility is not a
  second event" mechanically observable forever.
- **Choice half (positive, active + reusable).** After `debug_grant_silver`,
  the player's explicit `use_facility` key enters FACILITY (`facility_id ==
  "shaolin_wooden_men"`, count still 0 — entered, not yet used), `ui_accept`
  uses it once (`facility_use_count == 1`, `silver: changed`, `attr_bone:
  changed`, `last_facility_effect_types == ["silver","attr"]`), `move_down`
  leaves, and after travelling away and back the facility is used again
  (`facility_use_count == 2`, `attr_bone: changed`).

## RED-RUN RECORD (required by the acceptance criterion)

The red-then-green nail must be observed **before** `map_data_facility_flip`
lands. At the moment this task delivers, that is exactly the repo state: the
facility slot is still `declared` on every node, so `MapData.active_facility_id()`
returns `""` everywhere and the `use_facility` opt-in door in `map.gd` (guarded
by `MapData.active_facility_id(current_node_id) != ""`) never opens.

This scenario was run against the pre-flip repo via `godot_playtest_scenario`
(real boot, my staged edits overlaid). The run was clean — `hard_passed: true`,
zero runtime errors — and the result is **34/47: the arrival half fully green,
the choice half fully red**. The measured red values from that run (recorded
verbatim from the probe, the acceptance criterion's "红值记录"):

| assert | expects | measured (red, pre-flip) |
|---|---|---|
| f570 `MapScreen.phase` | `"FACILITY"` | `"TRAVEL"` |
| f570 `MapScreen.facility_id` | `"shaolin_wooden_men"` | `""` |
| f600 `MapScreen.facility_use_count` | `1` | `0` |
| f600 `MapScreen.last_facility_effect_types` | `["silver","attr"]` | `[]` |
| f760 `MapScreen.phase` | `"FACILITY"` | `"TRAVEL"` |
| f760 `MapScreen.facility_id` | `"shaolin_wooden_men"` | `""` |
| f790 `MapScreen.facility_use_count` | `2` | `0` |

All 13 failing asserts are the choice half; every one reads exactly the
absent/empty state. The arrival half (the permanent negative assertion) passes:
arriving at 少林 stays in EVENT (`phase == "EVENT" and phase != "FACILITY"`),
`facility_id == ""`, `facility_use_count == 0`, both at the arrival frame and
after the event resolves.

Root cause of the red: `use_facility` is a no-op because
`MapData.active_facility_id("shaolin") == ""` (slot still `declared`), so the
phase never leaves TRAVEL, `facility_id` never becomes non-empty, and
`facility_use_count` never increments. The **arrival half stays green** — it
asserts exactly the empty/absent state, which is true both before and after the
flip. Once `map_data_facility_flip` lands, the choice half turns green while the
arrival half stays green — the two halves together are the definitional
property, made permanent by the anti-deletion pin.

One-time vs standing: this red signature is ONE-TIME evidence — it vanishes the
moment the flip lands and protects nothing afterwards. The standing guard is the
arrival-half negative assertion (kept adjacent to the positive half in the same
scenario) plus the hard anti-deletion pin in
`test_facility_use_reusable_surface_contract` requiring `phase != "FACILITY"`
and `facility_use_count == 0` to survive in the file text.

## Runtime-error fix in the landed map.gd facility effect path (documented)

The FIRST probe run exposed a genuine runtime error in the already-landed
`map_facility_phase` code, reachable only through this scenario (nothing else
drives `use_facility` / `debug_grant_silver`):

```
Invalid assignment of property or key 'effects' with value of type 'Array'
on a base object of type 'RefCounted (EventOption)'   [scripts/segments/map.gd]
```

`EventData.EventOption.effects` is typed `Array[Dictionary]`
(scripts/data/event_data.gd:10), but `_use_facility()` and `_debug_grant_silver()`
assigned a plain untyped `Array` (`opt.effects = fdef.effects.duplicate(true)`
and `opt.effects = [{...}]`). GDScript refuses that at runtime — the facility
could never be used, and the hard gate would fail on the runtime error. Fixed
both sites to coerce element-by-element into the typed array with the canonical
`opt.effects.assign(...)`. This is a surgical two-site fix, not a redesign; it
keeps the sibling's stated architecture (route effects through
`EventLogic.apply_option_effects`) intact. After the fix the run is clean
(`hard_passed: true`) with only the intended pre-flip choice-half red remaining.
No assertion was weakened, and no playtest contract threshold was changed.

## Contract compliance

- Surface whitelist grows only (3 new MapScreen vars + 2 new actions).
- `scenario_order` tail grows only; `ROUND_SCENARIOS` tail matches (two-place
  sync, same order). The tail is now 58 entries (was 57).
- Every timeline `at:` is a single integer; every 4-space dotted assert line
  carries a comparison operator or the changed/unchanged differential token;
  zero absolute game-value literals (`silver` / `attr_bone` only ever `changed`).
  Last `at:` is 810 <= 2999.
- Anti-deletion pin + the static corridor (`phase != "FACILITY"` and
  `facility_use_count == 0` must both be in the file) are live.
- No `*_ClickTarget` anchors, no camera / coordinate edits, no arrival-dispatch
  wiring of the facility, no changes to any existing `_common.yaml` entry or to
  `map_node_event_shaolin.yaml` / `spine_to_ending.yaml` / the superset fixture.
- Facility effects stay in the closed {silver, attr} domain via the landed
  FacilityData def and the shared EventLogic path — no new economy.

---

# Delivery notes — facility_result_pin (jinyong-facility) · 2026-08-29

Task: land the differential nail for the **"facility result is never rendered"**
defect FIRST, so its red is measured before the rendering fix
(`facility_result_render`, a sibling task) lands. This task adds **no rendering
logic** — it only makes the result a read-stable, whitelisted, published surface
observable and nails it with `changed` differentials that are RED while the
rendering is absent.

Root cause being fixed (human frame review 2026-08-29):
`scripts/segments/map.gd` writes `facility_use_count` / `last_facility_effect_types`
into surface vars but NOTHING renders them, so after using a facility the player
sees zero change — the 8 post-use frames are md5-identical
(`e5010a5095349f67913d15f888e1a18f`) and the map frames 550/620/810 are
md5-identical too (`6dd9d444ecc47005cf781c5d4c5c29f7`).

## Files changed

- `scripts/segments/map.gd` — NEW surface var `var facility_result_text: String = ""`
  beside the existing facility three (facility_id / facility_use_count /
  last_facility_effect_types). `_sync_surface()` gains one publish line
  (`facility_result_text = ""`), the read-stable publish point the `changed` nail
  reads. **No business value is ever assigned and `_render()` is untouched** —
  the var stays `""` constant, which is exactly why the `changed` nail below is
  RED.
- `playtest/_common.yaml` — MapScreen surface block appends `facility_result_text`
  after `last_facility_effect_types` (append-only; nothing removed).
- `playtest/facility_use_reusable.yaml` — the two existing "after a use" frames
  (at: 600 where `facility_use_count == 1`, at: 790 where `facility_use_count ==
  2`) each gain `MapScreen.facility_result_text: facility_result_text != ""`;
  `description:` gains the "using the facility must produce a VISIBLE result"
  rationale. The arrival-half
  negative pins (`phase != "FACILITY"`, `facility_use_count == 0`) are untouched.
- `tests/test_playtest_contract_smoke.py` — `FACILITY_SURFACE_VARS` grows 3 → 4
  (appends `facility_result_text`); `test_facility_use_reusable_surface_contract`
  adds a verbatim pin that the scenario file carries a
  `facility_result_text != ""` line, and gives all three verbatim pins
  (that one + `phase != "FACILITY"` + `facility_use_count == 0`) a
  self-explaining failure message with the rename/rewrite escape hatch.
- `design/30_presentation.md` — the gate-principle section gains the sibling rule
  "形态闸门必须自我解释" (morphological gates must self-explain), dated 2026-08-29,
  with the recorded cause (the prior `test_facility_copy_location.py` allowlist
  pardoned the very violation it existed to prevent and guaranteed a red on any
  one-character change).
- `final/delivery_notes_facility.md` — this section.

Untouched (by design): `scripts/data/facility_data.gd`, `scripts/data/map_data.gd`,
`project.godot`, the camera / coordinate layer (`camera_follower.gd` / `coord.gd` /
`ink_world_dx/dy` / `camera_offset_y`), `camera_transform_follows_unit.yaml`,
`portrait_grid_alignment.yaml`, `spine_to_ending.yaml`, and the superset fixture.
This task adds **zero new UI copy** (`facility_result_text` stays `""`), so
`tests/test_i18n_coverage.py` and the §433 copy-location guard are untouched, and
writing any CJK literal into `map.gd` would be out of scope.

## PRE-FIX RED VALUE (recorded — the acceptance criterion)

The `facility_result_text != ""` value-inequality was run against the current
tree (via `godot_playtest_scenario`, staged edits overlaid; real boot). Because
the var is published but never set, it reads `""` at every frame — the
value-inequality is RED at both use frames. The harness output for the two
failing asserts, verbatim:

```
at:600 MapScreen.facility_result_text: facility_result_text != ""
  -> FAILED
     observed=""

at:790 MapScreen.facility_result_text: facility_result_text != ""
  -> FAILED
     observed=""
```

So the scenario that was 47/47 green is now RED on exactly these two
value-inequality nails (45/47), the only red being the intended pre-fix
measurement. This is the ONE-TIME red signature required by the reviewer's
acceptance criterion: a green-only nail does not count. `facility_result_render`
(the sibling task) turns these two nails green by assigning the derived summary
text to `facility_result_text` at each use, replacing the `_sync_surface()`
publish line's constant `""`.

### Why `!= ""` rather than `changed` (measured, documented deviation)

The task card and t_plan prescribe `MapScreen.facility_result_text: changed`.
The harness's differential semantics are **baseline = the frame-0 snapshot**,
and at frame 0 the MapScreen is not yet loaded (the scenario boots through
tutorial → creation → cultivation before MAP), so `MapScreen.*` reads `null` at
frame 0. `changed` therefore compares `null → ""` at the use frames and reports
**changed** — trivially green, exactly the silent-false shape this project
guards against. Measured on the real tree:

```
at:600 MapScreen.facility_result_text: changed   -> PASS (baseline null at frame 0, current "")
```

The genuinely red-then-green differential for "the result text was not rendered"
is the value-inequality `facility_result_text != ""` (red while the var is
constant "", green after the render fix assigns the summary). The scenario, the
smoke-test pin, and this record therefore use `!= ""` — the equivalent new
assertion the escape hatch sanctions. The measured red values above are from
that `!= ""` form.

## Escape hatch on the verbatim pins (self-explaining gates)

All three verbatim anti-deletion pins in `test_facility_use_reusable_surface_contract`
now carry a failure message (not just a docstring) that states the gate exists
ONLY so the differential/definitional nail cannot be silently deleted, and that a
legitimate rename/rewrite must update the pin in the SAME change to match the
equivalent new assertion rather than keeping a dead old-text line or bypassing the
rename. This is the concrete application of the `design/30_presentation.md`
"形态闸门必须自我解释" rule this same task lands.

---

# `facility_result_render` — turning the two visible-result nails green

**Task:** make a facility use *visible on screen*, so that the pinned surface
observable and the string the player reads are literally the same variable.

## What the sibling pin task recorded (quoted, pre-fix)

From the `PRE-FIX RED VALUE` section above, verbatim — the state this task started from:

```
at:600 MapScreen.facility_result_text: facility_result_text != ""
  -> FAILED
     observed=""

at:790 MapScreen.facility_result_text: facility_result_text != ""
  -> FAILED
     observed=""
```

45/47 in that run: the two `facility_result_text != ""` nails were the only red, and
their cause was that `facility_result_text` was *published but never assigned* — the
only write to it sat in `_sync_surface()` as a constant `""`, and `_render()` printed
nothing from it. "A never-written observable reads exactly like an always-false one."

## What changed (5 write sites, all in the render path)

1. **`_sync_surface()` no longer touches the var.** The constant
   `facility_result_text = ""` publish line and its stale "facility_result_render
   replaces THIS line" comment are deleted; a comment now names the two real write
   sites and states why mirroring here would wipe the value (`_use_facility()` calls
   `_sync_surface()` *after* assigning — this was the highest-risk edit, and a silent
   re-creation of the defect if missed).
2. **`_enter_facility()`** resets `facility_result_text = ""` before
   `_sync_surface()` / `_render()`: entering is not using, and `facility_use_count`
   persists across visits, so without this a returning player would see last visit's
   result before doing anything (and the "entered, not yet used" state would be
   unobservable).
3. **`_use_facility()` refusal path** sets `facility_result_text = tr("银两不足")`
   (count still not incremented, no effects applied — unchanged behaviour).
4. **`_use_facility()` success path** sets, after `facility_use_count += 1`:
   `facility_result_text = tr("修炼有得（第 %d 次）：%s") % [facility_use_count, gains]`
   with `gains` taken verbatim from the existing `_facility_effect_summary(fdef)` —
   i.e. composed from `def.effects`, never from literals. Carrying the session use
   count is what makes use #1 read differently from use #2, so a second use cannot
   pass as the first one's text being re-displayed.
5. **`_render()` FACILITY branch** appends `"\n" + facility_result_text` when
   non-empty — the var itself, not a re-computation, so the observable and the screen
   cannot diverge. The superseded `if _facility_refused: body.text += tr("银两不足")`
   block is **deleted**: on refusal `_facility_refused == true` AND
   `facility_result_text == "银两不足"`, so keeping it printed the refusal twice while
   the observable held it once. `facility_result_text` is now the single render source
   for both the success result and the refusal (`_facility_refused` remains as internal
   state only, with its doc comment corrected).

Supporting, in the same commit (both are independent red sources — a green playtest
with a red static guard is still a failed build):

- `scripts/autoload/i18n.gd` — one new Chinese-as-key EN entry
  `"修炼有得（第 %d 次）：%s": "Cultivation gained (use #%d): %s"`. The already-present
  `银两不足` / `银两 −%d` / `根骨 +%d` / `内力 +%d` fragments are reused, not re-added.
  `tests/test_i18n_coverage.py` green.
- `tests/test_facility_copy_location.py` — the new template (6 CJK ideographs, over
  `PROSE_MIN_CJK`) added to `ALLOWED` in the sanctioned-facility-chrome block, with a
  comment saying it is the result-render format string, not narrative. It exists in no
  data module, so `test_no_prose_duplicated_from_data_modules` stays green.
- `tests/test_map_node_event.gd::_test_map_facility_phase()` — five relative pins on
  the var (never an exact Chinese string; the semantics are the pin, not the wording):
  empty after arrival, empty on entry (entering ≠ using), non-empty after use #1
  (stored as `first_result`), non-empty **and different from `first_result`** after
  use #2, and on the cost-gate refusal the count is unchanged while the text is
  non-empty and again differs from `first_result`; plus the re-entry reset with
  `facility_use_count > 0`.

## Measured post-fix numbers (from `godot_playtest_scenario`, repo + staged edits)

- `facility_use_reusable` — **PASS 49/49**, hard gate `passed: true`. Both
  `facility_result_text != ""` nails (at:600 after use #1, at:790 after use #2) now
  pass; the pre-fix observation for those two lines was `observed=""`. (The full-gate
  run at `5_compile` reports its own per-scenario totals; the count printed here is
  this step's single-scenario probe, so no number in this section is inferred.)
- `spine_to_ending` — **PASS 42/42** (six segments still connected).
- `map_hint_single` — **PASS 7/7** (the single-hint invariant holds with the extra
  result line: the travel hint is still hidden outside TRAVEL).
- `map_node_event_shaolin` — **PASS 32/32** (untouched scenario, no regression).

## Explicitly NOT touched

`playtest/facility_use_reusable.yaml` (byte-unchanged — the two nails were turned green
by the code, not by editing the exam), `playtest/_common.yaml`,
`tests/test_playtest_contract_smoke.py`, `scripts/data/map_data.gd`,
`scripts/data/facility_data.gd`, `project.godot` (so the `use_facility` (F) binding and
the debug action are unchanged), the camera / coordinate layer
(`camera_follower.gd`, `coord.gd`, `ink_world_dx/dy`, `camera_offset_y`,
`camera_transform_follows_unit.yaml`, `portrait_grid_alignment.yaml`),
`spine_to_ending.yaml`, the superset fixture and `design/*`. Facility enter / leave /
reuse semantics and all effect magnitudes are unchanged — **no number was tuned to turn
an assert green**; only the display of an already-computed effect changed.
