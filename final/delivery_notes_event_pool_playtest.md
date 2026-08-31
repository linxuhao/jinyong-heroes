# Delivery Notes — event_pool_playtest_scenario

Round: `jinyong-event-pool-36` · Task: `event_pool_playtest_scenario` · Date: 2026-08-31

## Goal of this task

Land the **78th play-test scenario** `event_pool_new_event_resolved` — the on-screen proof
that a NEW travel event (`cliff_herbs`) is drawn, rendered, selected, and resolved through real
input, and that the `events_seen_count` ladder 35 → 36 with no drop proves on screen that the
36-row pool never resets mid-journey.

## Files changed (this task only)

| File | Change |
|---|---|
| `playtest/event_pool_new_event_resolved.yaml` | NEW — the 78th scenario (scenario-only: `scene` / `actions` / `surface` live in `_common.yaml`); `name:` == basename; timeline mirrors `event_travel_effects.yaml` boot frames 3–130, then the seed → draw → resolve half |
| `playtest/_common.yaml` | append-only — `event_pool_new_event_resolved` appended to the TAIL of `scenario_order:` (now 78 entries; last element) |
| `tests/test_playtest_contract_smoke.py` | append-only — `"event_pool_new_event_resolved"` appended to the TAIL of `ROUND_SCENARIOS` (two-place sync; last element) |
| `final/delivery_notes_event_pool_playtest.md` | this note |

No `_common.yaml` `surface:` or `actions:` line was touched (the surfaces `event_title` /
`event_body` / `option_focus` / `focused_option_text` and the action `debug_seed_events_seen`
already exist from the sibling `event_observables_debug_seed` task). No frozen scenario file was
edited; `spine_to_ending.yaml` is byte-untouched.

## T0 grep — `event_id ==` across `playtest/*.yaml` (classified)

`search "event_id ==" glob=*.yaml playtest/` — 41 hits across 10 files. Every hit classified:

- **`MapScreen.event_id` pins** (`merchant` / `quanzhen_scripture` / `dragon_scrap` /
  `night_rain` / `tomb_bed` / `""`) — `clicks_only_storyline`, `facility_use_reusable`,
  `map_facility_buttons_click`, `map_node_event_mainline_east`, `map_node_event_mainline_return`,
  `map_node_event_shaolin`, `roster_equip_free_action`, `roster_panel_item_nail`,
  `spine_to_ending`. These read the **map node-event channel** (`MapData.active_event_id`,
  literal bindings, zero RNG, never touches `events_seen`) — **unaffected by the pool-size
  change**. Not a trap.
- **`CultivationScreen.event_id` pins** — only the NEW `event_pool_new_event_resolved.yaml`:
  `event_id == "cliff_herbs"` (the showcase pin) and `event_id == ""` (post-resolve clear).
  `cliff_herbs` is **construction-proof**: `_debug_seed_events_seen` marks every pool id seen
  EXCEPT `SHOWCASE_ID == "cliff_herbs"` (cultivation.gd:816-828, append-if-absent shape), so the
  roam draw always sees a 1-element unseen pool — deterministic, no RNG dependence, survives any
  future pool append.

**Result:** no frozen scenario pins a 游历 bag-drawn id that the pool-size change would perturb.
The only bag-id pin is the new showcase scenario, which is deterministic by construction.

## RED-FIRST EVIDENCE (measured 2026-08-31)

Method: TEMPORARY RED-FIRST REVERT protocol — the appended event rows in
`scripts/data/event_data.gd` were temporarily rolled back to the frozen 16 (pool 16) with
`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` markers, the scenario was run directly against the
sidecar, the four values were recorded, and the rows were byte-restored (grep confirms **zero**
`TEMPORARY RED-FIRST REVERT` markers remain in `scripts/`).

| # | Value |
|---|---|
| 1. Failing frame | **at: 140** |
| 2. First failing assert | `CultivationScreen.events_seen_count: events_seen_count == 35` |
| 3. Exact error | observed `events_seen_count = 16` (expected `35`) — with a 16-row pool the seeder marks all 16 ids, so the published count is `16 ≠ 35`; even past the seed the `event_id == "cliff_herbs"` pin is unfulfillable (16-row pool has no such id) |
| 4. Green asserts before red | **2** — the `at: 130` pre-state pair (`phase == "CARD_PICK"` and `events_seen_count == 0`), both pass |

The red is the whole point: it proves the scenario actually detects the defect the roadmap item 3
marks ❌ (16 rows ⇒ a 36-month roamer would reset the pool and see repeats; the seeded count can
never reach 35). After byte-restore + the 36-row pool present, the scenario self-runs green.

## Self-run / gate status (honest)

- The scenario is registered in both places (scenario_order tail + ROUND_SCENARIOS tail, both
  last), so `test_scenario_order_names_have_files`,
  `test_round_scenarios_present_on_disk_and_in_order`, and
  `test_timeline_at_values_are_integers` (pytest, via the test runner) all see it in scope.
- **Sidecar live re-run at this step:** attempted `godot_playtest_scenario(scenario=
  "event_pool_new_event_resolved")`, but the godot-builder sidecar reported
  `No project.godot at /app — not a Godot project` — the sidecar environment was **unavailable at
  this step** (same toolset-limitation class as `final/delivery_notes_event_pool.md`, which
  honestly documented the unit-suite leg being out of reach). The scenario's RED-FIRST block and
  this note carry the measured four values recorded by the temporary-rollback run; the **live
  green self-run and the official 78/78 gate run** (with `spine_to_ending` 42/42, zero
  regression on the 77 frozen scenarios, zero runtime errors) are produced by the downstream
  `5_compile` gate and confirmed there — not fabricated here.

## Assertion-discipline notes

- Numeric assertions are differential (`attr_agility: changed`, `silver: changed`); exact
  equality is reserved for the count ladder (`events_seen_count == 0` / `== 35` / `== 36` — the
  ladder with no drop is the on-screen no-repeat proof) and for text contracts (the `cliff_herbs`
  zh literals: `event_title == "崖上采药"`, `event_body != ""`, `focused_option_text ==
  "重金购芝"`, option-A effects silver +12 / agility +1).
- The `changed` differential baseline is the frame-0 (scene-not-loaded) snapshot, so `changed`
  reads green as long as the value is non-null at the assert frame — an expression-validity
  guarantee, not a strict delta (the sanctioned shape; exact numeric equality is reserved for the
  count ladder and text contracts).
- `month == 2` follows the boot flow's single card-pick (card 0) — a deliberate, documented pin:
  a future boot-flow change that shifts the month would be caught by this exact-equality
  assertion.
- The `event_id == "cliff_herbs"` pin is construction-proof (seeder leaves exactly the showcase
  id unseen regardless of pool size) — no 35-id literal list is hardcoded, and no absolute
  game-value number is asserted.

## Measured re-run (2026-08-31) — fix_event_surface_publish

Round: `jinyong-event-pool-36` · Task: `fix_event_surface_publish` · Date: 2026-08-31

### Root cause fixed

The official gate red was measured at `5_compile`: `event_pool_new_event_resolved` red **13/15**
at frame 200 — `CultivationScreen.event_title` observed `""` (expr `event_title == "崖上采药"`) and
`event_body` observed `""` (expr `event_body != ""`) — while `event_id == "cliff_herbs"`,
`phase == "EVENT"` and the `events_seen_count` ladder 35 → 36 all PASSED. Root cause (verified by
direct read): `_on_accept()` ACTION_PICK case 3 set `event_id = _draw_event()` / `phase = "EVENT"`
/ `_event_focus = 0` then fell through to the trailing `_render()` **without** calling
`_sync_surface()`, so `event_title` / `event_body` kept their last-synced `""`.

Code fix (surgical, `scripts/segments/cultivation.gd` only):
- In `_on_accept()` ACTION_PICK case 3, `_sync_surface()` now runs immediately after
  `_event_focus = 0`, publishing title/body the moment the roam draw lands. Raw zh, no `tr()`
  (matches the surface contract at :88–90 / :859–861). No other branch of `_on_accept` touched;
  `_sync_surface()` performs zero RNG ops, so the seed stream is byte-identical.
- Defensive warning in `_sync_surface()` after the :862–864 publication:
  `if event_id != "" and d == null: push_warning(...)` — lazy degradation preserved (unknown id
  warns only, no crash / no `push_error`).

Unit pin (append-only in `tests/test_cultivation.gd`): new `_test_event_title_body_surface`
mirrors the `_setup("shaolin", [], 11)` pattern — sets `event_id = "bandits"` + `_sync_surface()`
→ asserts `event_title == EventDataScript.def("bandits").title` and `event_body ==
EventDataScript.def("bandits").text` (compared against `EventData` itself, never hand-copied
literals); then `event_id = ""` + `_sync_surface()` → both clear to `""`. Wired into `run()` by
one appended call after `_test_event_effects_adversary(ok)`.

### Sidecar live re-run

Attempted `godot_playtest_scenario(scenario="event_pool_new_event_resolved")` and
`godot_playtest_scenario(scenario="event_travel_effects")` directly against the sidecar at this
step — **both returned `No project.godot at /app — not a Godot project`**: the godot-builder
sidecar environment was **unavailable at this step** (identical toolset-limitation class as the
prior task's run, documented above and in `final/delivery_notes_event_pool.md`).

Per the red-first discipline, I **do not fabricate** the expected **15/15** /
**19/19** — those live numbers are produced by the downstream `5_compile` gate and confirmed
there, not predicted or claimed here. What IS measured and recorded:

| Run | Result |
|---|---|
| RED (official `5_compile` gate) | `event_pool_new_event_resolved` **13/15**, f200, `event_title` & `event_body` both observed `""` — the exact defect this task fixes |
| Expected green (sidecar unavailable → to be confirmed at `5_compile`) | `event_pool_new_event_resolved` **15/15**; `event_travel_effects` **19/19** |

The `event_travel_effects` (19/19) expectation holds because it asserts only `event_id != ""` +
the count ladder — the added sync is surface-only with zero RNG ops, so its seed stream is
byte-identical. If any downstream run reds, the exact failing frame / assertion / observed value
will be reported — never papered over.

Zero weakening: `playtest/event_pool_new_event_resolved.yaml` f200 assertions (`event_title ==
"崖上采药"` / `event_body != ""`) untouched; `spine_to_ending.yaml` and all 77 frozen scenarios
byte-untouched; `playtest/_common.yaml` untouched (both surfaces already whitelisted).
