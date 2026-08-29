# jinyong — Wuxia Crossover Tactics (Godot 4)

**▶ Play it in your browser: https://linxuhao.github.io/jinyong-heroes/**
(中文/English — auto-detected from your browser language, switchable in 设置/Settings)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. This is a fan-crossover brawler, not
a recreation of any single novel. You create your own nobody, borrow the fully
mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, receive a chance to join a great
sect, spend three in-game years (36 cultivation periods) training, and finally
walk the jianghu map to an ending (`design/00_overview.md`).

Visuals use **placeholder art** (96×128 portraits on 64 px tiles are the frozen
art contract). UI text is Chinese, rendered with the bundled NotoSansSC font
(SIL OFL, see `assets/fonts/LICENSE_OFL.txt`). The project is at roadmap
stage 3 (game content); the board's visibility belongs to a **following
camera**, and sprites only stand on their own tiles.

## Latest round: jinyong-facility — the third map-node content type lands

The jianghu map had three declared entry-content types — `event`, `battle`,
`facility` — but only the first two were implemented. Facility was `declared`
on all six nodes (a `declared` / `""` slot, no behaviour). This round defines
and implements the **facility content type** at 少林 (shaolin) and 武当 (wudang),
the two sect nodes, while the remaining five nodes honestly stay `declared`.

The **definitional distinction** from the event slot is the round's reason for
being: *event is passive content that auto-fires on arrival; facility is
something the player actively chooses to use and can use repeatedly.* This is
made mechanically real — not just documented:

- **A new data module** (`scripts/data/facility_data.gd`, `class_name
  FacilityData`): mirrors `EventData.TABLE` byte-for-byte — `const TABLE` with
  2 rows, `def(id)` / `all()` / `for_node(node_id)` / `silver_cost(def)` /
  `_build(row)` builders. Two facilities (placeholder magnitudes, NOT tuned —
  phase 5 owns numerical tuning):
  - `shaolin_wooden_men` (木人巷): silver −8 → 根骨 (bone) +2
  - `wudang_meditation` (紫霄静修): silver −8 → 内力 (inner) +2
  Effects use ONLY the closed domain {silver, attr, practice, none} — zero new
  economy. This file is the single sanctioned text source for facility prose
  (the §433 rule: no inline anecdotes in `map_data.gd` / `map.gd`).
- **Two slots flipped** (`scripts/data/map_data.gd`): shaolin + wudang
  facility slots `declared → active` with their `facility_id`s. New
  `active_facility_id(id)` accessor (symmetric with `active_event_id` /
  `active_battle_id`, typo-safe inert). `declared_gap_types()` is **unchanged**
  — it auto-reflects the flip: shaolin/wudang → `[battle]` (facility dropped);
  luoyang/wuming_valley stay `[battle, facility]`; kunlun stays
  `[event, battle, facility]` (terminal guarantee); huashan stays
  `[event, facility]`.
- **A new FACILITY phase** (`scripts/segments/map.gd`): opt-in, keyboard-driven
  (no new click target, no `*_ClickTarget`, no `mouse_filter` work). In TRAVEL,
  the `use_facility` key (bound to **F**) enters FACILITY **only if**
  `MapData.active_facility_id(current_node_id) != ""`. In FACILITY, `ui_accept`
  uses the facility (pay silver cost via the gate, apply effects, stay in
  FACILITY so it can be used again); `move_down` / `move_left` leaves. The
  facility **never** auto-fires on arrival and is **never** wired into the
  arrival dispatch (`_maybe_start_entry_event()` / `_maybe_start_entry_battle()`
  are unchanged) — this is the definitional property. Effects route through the
  **same** `EventLogic.apply_option_effects` pure-static path events use (silver
  cost-gate, `PlayerProfile` mutators), so facility is a new *door* into
  existing systems, not a parallel system. Surface observables
  `facility_id` / `facility_use_count` / `last_facility_effect_types` are
  published via `_sync_surface()` (the existing convention, not recomputed).
- **New player-facing input action** `use_facility` (physical **F**) +
  **debug-only** `debug_grant_silver` (funds the profile for the facility
  scenario's cost precondition; routes silver through the normal
  `EventLogic.apply_option_effects` pipeline, never a bare field assignment).
- **A new playtest scenario** (`playtest/facility_use_reusable.yaml`, the 58th
  in the round contract): pins **BOTH halves** of the definitional property in
  adjacent frames:
  - **Arrival half (permanent negative assertion):** arriving at 少林 fires the
    `night_rain` EVENT and does NOT enter a facility —
    `phase == "EVENT" and phase != "FACILITY"`, `facility_id == ""`,
    `facility_use_count == 0`, re-asserted after the event resolves (resolving
    an event cannot smuggle a facility use in). This is what makes "facility is
    not a second event" mechanically observable forever.
  - **Choice half (positive, active + reusable):** `debug_grant_silver` funds
    the profile, the player's explicit `use_facility` key enters FACILITY
    (`facility_id == "shaolin_wooden_men"`, count still 0 — entered, not yet
    used), `ui_accept` uses it once (`facility_use_count == 1`, `silver: changed`,
    `attr_bone: changed`, `last_facility_effect_types == ["silver","attr"]`),
    `move_down` leaves, and after travelling away and back the facility is used
    again (`facility_use_count == 2`, `attr_bone: changed` again).
- **Red-then-green record (required by the acceptance criterion):** the scenario
  was run against the pre-flip repo (every node's facility slot still
  `declared`). Measured result: **34/47** — arrival half fully green, choice
  half fully red (`phase` read `"TRAVEL"` not `"FACILITY"`, `facility_id` read
  `""` not `"shaolin_wooden_men"`, `facility_use_count` read `0` not `1`/`2`).
  After the flip, `facility_use_reusable` is **47/47 green**. The measured red
  values are recorded in `final/delivery_notes_facility.md`.
- **Permanent guards** (the definitional property must survive future rounds):
  - **Anti-deletion pin** (`tests/test_playtest_contract_smoke.py
    ::test_facility_use_reusable_surface_contract`): requires the scenario file
    text to contain both a `phase != "FACILITY"` line and a
    `facility_use_count == 0` line — so the permanent negative assertion itself
    cannot quietly disappear.
  - **§433 copy-location guard** (`tests/test_facility_copy_location.py`,
  adopted this round): a stdlib-only pytest scanning `map_data.gd` / `map.gd`
  for prose-length (≥4 CJK) string literals not in an allowlist, with a
  cross-check that no data-module prose is duplicated into the map files. Makes
  "facility prose lives only in its data module" a mechanical rule, not just a
  documentation sentence.
- **Authorized shaolin scenario re-baseline** (`playtest/map_node_event_shaolin.yaml`
  + `tests/fixtures/playtest_assert_superset.json`): shaolin's `facility` slot
  flipped to active, so `entry_declared_gap_types` at shaolin drops `facility`.
  The gap assert at f560 is tightened to `has("battle") and not has("facility")`;
  f460 (luoyang) stays `has("battle") and has("facility")` as the control. The
  superset fixture was updated FIRST with a documented exception, so the smoke
  test stays green through the edit.
- **Spine stays green by construction:** `playtest/spine_to_ending.yaml` walks
  武当 (a facility node). The facility never auto-fires and never consumes input
  on arrival, so the spine is invisible to it.
- **Documentation** (docs-first, in sync): `design/20_content.md` §8.1 six-node
  table + §8.3 gap note 2 + NEW §10 (facility content type: definition, data
  rows, arrival-never-enters invariant, observability/guards, red value record);
  `design/00_roadmap.md` completeness entries 2 (facility → ✅ at shaolin/wudang)
  and 4 (portrait-geometry four gaps → ✅, stale ❌ corrected); `design/99_changelog.md`
  row (2026-08-29); `design/90_decisions.md` five rulings (a–e: event/facility
  precedence, re-baseline exception, §433 guard conclusion, red-then-green is
  one-time, facility reuse upper limit is a PENDING phase-5 numerical decision).

Previous rounds: camera-owns-visibility (following camera owns visibility,
clamp deleted, canvas-transform click mapping, portrait-grid alignment),
interaction-defects (floating-bar STOP filter, feet-tile undo, real-input
coverage, touch undo, nameplate/ground marker, 5-step click priority, trait
hover preview), jinyong-nodes (five main story nodes get content),
jinyong-map-events (node entry-content + shared `EventLogic` + map EVENT
phase), jinyong-spend-qi (real inner-qi costs), jinyong-clarity (creation-screen
information layer), jinyong-hud (battle-HUD information layer), jinyong-events
(event pool 4 → 16 rows), plus the owner's hand-added 华山 battle node. All
recorded in `design/99_changelog.md`.

## Requirements

- Godot 4.x. No external dependencies, no build step.

## Install

```bash
git clone <this repo> jinyong && cd jinyong
# open project.godot in the Godot 4 editor (import happens automatically)
```

## Run

Open the project in the Godot 4 editor and press Play — the game boots into
the main menu (新的冒险 / 读取存档 / 设置 / 退出). Headless:

```bash
godot --path .
```

Flow: main menu → character creation (fixed 30-point budget: five attributes
with live effect explanations and current HP; 13 innate trait/flaw toggles
whose descriptions preview on hover; a confirm page listing the final values)
→ tutorial battle as a fully mastered Yang Guo vs the Five Masters (you are
meant to win) → transition → sect choice → 36-month cultivation → the
jianghu map. In battle the **camera follows the acting unit** and keeps it in
the unobstructed band between the top bar and the action bar (the far side of
the board waits off-screen; that is normal framing): left-click a highlighted
empty tile to move, left-click an enemy (its own tile **or** the drawn
portrait body of an enemy in reach) to attack, right-click **or the HUD
「退回」 button** to retreat to the turn-start tile until you act (acting
locks the move), 结束回合 to end the turn; each unit's nameplate rides at its
portrait head (flipping below the head for top-row units) and a gold ground
marker under its feet marks the occupied tile; casting a move spends its
inner-qi cost (内力: N in the top strip; a too-expensive move greys into
「内力不足」; the free basic 重剑无锋 always stays available). On the map,
左右/上下 cycle the adjacent nodes and 回车 travels — the one on-screen hint
lives in the footer; every mainline stop opens its node event on arrival
(洛阳 行商路过 / 武当 全真抄经 / 襄阳 降龙残谱; 无名谷 fires on the return
trip; 少林 off the 洛阳 branch fires 破庙夜雨) — resolve with
上下选择，回车定夺 to continue. **At 少林 and 武当 (the two sect nodes), press
F to enter the sect facility** (木人巷 / 紫霄静修): 回车 uses it once (pays
silver, gains an attribute — reusable as long as you can pay), 上下 leaves.
The travel hint shows a `门派设施：…（F 使用）` line when a facility is
available at the current node. Entering 昆仑 routes straight to the tiered
ending (end-node routing runs before entry content, so nothing can block it),
and events fire only on travel — never on boot or load, so save/load
roundtrips don't re-trigger.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check → headless playtest of all scenarios → GDScript unit
suite). It fails loudly when the sidecar is unreachable — the code then ships
unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (incl. the superset pin + copy-location guard)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite (23 files)
godot --headless --path . -s res://tests/test_cultivation.gd  # SceneTree-style suites
```

## Key interfaces

- **Camera ownership** (`scripts/camera_follower.gd`, attached to the
  `Camera` node of `main.tscn` / `menu.tscn`): follows
  `CombatManager.get_active_unit()` during `STATE_BATTLE`, clamps to the
  no-blank range derived from `GridManager.board_rect()` + viewport + HUD
  rects, and publishes the playtest surface `Camera.camera_position`,
  `camera_x_lo/hi`, `camera_y_lo/hi`, `hud_band_top/bottom`,
  `active_unit_screen_y`, `active_unit_world_y`, `viewport_half_y`,
  `follow_target_id`, `follow_target_is_active`.
- **Coordinate mapping** (`scripts/coord.gd`, `class_name Coord`): pure
  statics `world_to_screen(world, viewport)` / `screen_to_world(screen,
  viewport)` over the **canvas** transform (the one that contains the
  camera). The health-bar follow and the follower's published screen y both
  go through it; click entries already map through
  `get_canvas_transform().affine_inverse()`.
- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`, `get_enemies_alive()`), `CombatManager` (battle state:
  `tutorial_battle`, `current_round`, `phase`, `is_player_turn()`,
  `get_active_unit()`, the qi spend path `spend_unit_energy(unit, cost)` +
  the `debug_spend_player_qi()` drain fixture), `GridManager` (grid /
  movement planning, `world_to_grid` / `grid_to_world` / **`board_rect()`** —
  the single board-rect source; `clamp_sprite_offset` is deleted),
  `SaveManager` (profile, slots, `rng`, autosave), `InputGate` (real-input
  gate — inert unless the env var `AITELIER_INPUT_GATE_REPORT` is set).
  `SceneManager` must stay the LAST autoload entry (compile ordering).
- **Alignment observables** (`player.gd` / `enemy.gd`): `portrait_ink_rect`
  (Rect2, live unclamped foot-anchored ink), `ink_world_dx` / `ink_world_dy`
  (derived from the rect only; both 0 = the portrait stands on its own tile),
  `camera_offset_y` (published by the follower = `viewport_half_y −
  camera_position.y`; units only declare the field, never compute it),
  `sprite_top` (= feet − tex height once unclamped; negative on row 1),
  `portrait_sprite_pos` / `portrait_tex_size` /
  `portrait_bar_pos` / `health_bar_screen_y` / `health_bar_world_y`, plus the
  input-differential counters (`debug_input_events`, `debug_click_events`,
  `debug_right_input_events`, `debug_undo_events`, `debug_gui_eater`,
  `Enemy.debug_click_target_fires`).
- **Battle click priority**: `Player.resolve_click_step(...) -> int` and
  `Player.attack_reach_covers(...) -> bool` — pure statics implementing the
  5-step rule (own-tile enemy → attack; in-reach body → attack; reachable
  empty tile → move; out-of-reach body → select/no-op; own tile no-op),
  unit-pinned by `tests/test_click_priority.gd` against the unclamped
  geometry.
- **Floating health bar** (`scripts/ui/health_bar.gd`,
  `scenes/ui/health_bar.tscn`): follows its unit through
  `Coord.world_to_screen`; above-portrait anchor (bottom 4 px above
  `sprite_top`) with a flip below the ink bottom for top-band units
  (`bar_anchors_below_portrait`); `STRIP_BOTTOM + 2 = 94` retained only as
  the widget's internal floor — **geometry constants frozen**. Every node in
  the subtree is `mouse_filter = IGNORE` so it can never eat a board click.
  Observables: `bar_width/height/top/bottom`, `hp_text`, `hp_value`,
  `hp_max`, `hp_text_width_ok`, `empty_area_px`, `empty_cap_px`.
- **Ground markers** (`scripts/ui/tile_markers.gd`, `TileMarkers` node in
  `scenes/battlefield.tscn`, drawn after `Characters`): click-inert Node2D
  overlay painting one ellipse per living unit (kept for the 96-over-64
  horizontal overhang); observables `tile_marker_count` /
  `tile_marker_visible`.
- **Creation screen / map / events / qi costs**: `creation.gd` (`phase`,
  `points_left`, `attrs`, `trait_ids`, `trait_index`, `trait_hover_index`,
  `hp_value`/`hp_text`, `confirm_summary_text`); `MapData.NODES`
  entry-content + `active_event_id` / `active_battle_id` /
  **`active_facility_id`** / `declared_gap_types`, `MapScreen` EVENT +
  **FACILITY** phase; `EventLogic` pure statics over `EventData.TABLE` (16
  rows); `FacilityData.TABLE` (2 rows) + `silver_cost()` / `for_node()` /
  `def(id)`; `SkillData.cost` / `insufficient_energy` / `spend` with
  `Player.energy` / `energy_max`.
- **Sect facility** (`scripts/data/facility_data.gd` +
  `scripts/segments/map.gd`): `FacilityData.TABLE` is the single home for all
  facility prose (§433); `MapData.active_facility_id(id)` resolves a node's
  facility slot (typo-safe inert); `MapScreen` enters `FACILITY` phase only
  via the `use_facility` key (F) in TRAVEL — never on arrival. `_use_facility()`
  applies effects through `EventLogic.apply_option_effects` (the same path
  events use), with a silver cost-gate. Surface observables:
  `facility_id` / `facility_use_count` / `last_facility_effect_types`.
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections and
  `use_facility` / `debug_grant_silver`), the observable-surface whitelist
  (incl. the `Camera:` block, per-unit `ink_world_dx/dy`,
  `health_bar_screen_y/world_y`, and the facility vars
  `facility_id` / `facility_use_count` / `last_facility_effect_types`) and
  `scenario_order`; each `playtest/*.yaml` is one scenario
  (name == basename, single-integer `at:`, a comparison operator or
  changed/unchanged token on every assert line). `clicks:` entries are
  `<Node>[ +dx,dy][ left|right|middle]` — world-relative offsets resolved by
  the camera-aware harness anchor; `hovers:` entries are motion-only.
- **Unit tests**: GDScript files with a top-level `static func run() -> bool`
  are collected by `tests/unit_test_runner.gd`'s explicit append-only `TESTS`
  registry (23 files, incl. `test_facility_data.gd`, `test_click_priority.gd`
  re-based to the unclamped geometry, `test_health_bar.gd`), run headless via
  `godot --headless --path . -s res://tests/unit_test_runner.gd`.
  SceneTree-extending integration suites are driven with their own `-s`
  invocation. The pytest smoke (`tests/test_playtest_contract_smoke.py`)
  statically pins the scenario contract, the two-place sync, and the
  "assertions only added" rule for the authorized-edited yamls, plus the
  facility anti-deletion pin. `tests/test_facility_copy_location.py` guards
  the §433 copy-location rule.

## Verification status (honest)

The only authoritative gate evidence is the pipeline step products —
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` — pipeline artifacts, not repo files; none is on disk at
the verifier step (the gates run after it). In short:

- **Direct-read verified this round**: `facility_data.gd` (2 rows, closed
  domain, EventData.TABLE mirror), `map_data.gd` (2 slots flipped, 5 stay
  declared, `active_facility_id` accessor, `declared_gap_types` auto-reflects),
  `map.gd` (FACILITY phase, opt-in via `use_facility`, never in arrival
  dispatch, effects via `EventLogic`, surface observables via `_sync_surface`,
  runtime-error fix applied), `facility_use_reusable.yaml` (both halves of the
  definitional property, red-then-green record 34/47 → 47/47), i18n (all 13 new
  strings in the EN dict), unit tests (`test_facility_data.gd` registered;
  `test_map_data.gd` per-node gap pins incl. the new wudang pin;
  `test_map_node_event.gd` facility phase negative assertions), the
  anti-deletion pin + §433 copy-location guard, the authorized shaolin
  re-baseline, and the design-archive records (§8.1/§8.3/§10 in sync,
  roadmap entries 2+4, changelog row, five decisions).
- **Pending the downstream gate run, not claimed**: the measured green of all
  69 playtest scenarios (incl. `facility_use_reusable` 47/47 and
  `spine_to_ending` six-segment connectivity), compile zero errors, the
  23-file unit suite, the pytest smoke (incl. the anti-deletion pin and the
  copy-location guard), the i18n coverage test, and the vision gate's human
  check that the facility panel renders legibly (no new geometry, but the
  verdict is not pre-declared).
- If the downstream playtest gate reddens any scenario, that is reported with
  its cause, never papered over: no assertion is removed or relaxed, no
  frozen yaml is edited to route around a defect, and thresholds are never
  loosened — numbers come from constants or fresh measurement only.

## Repository layout

- `scripts/` — game code: `autoload/` (GameManager, CombatManager, GridManager,
  SaveManager, InputGate, SceneManager-last, …), `camera_follower.gd`,
  `coord.gd`, `characters/` (`player.gd` incl. the click-priority resolver,
  the alignment observables and the differential counters, `enemy.gd` incl.
  `portrait_ink_rect` / `ink_world_dx/dy` / `debug_click_target_fires`),
  `data/` (map/event/**facility** data, `event_logic.gd`,
  `facility_data.gd`, player_profile, …), `ui/` (HUD, **health_bar.gd**,
  **tile_markers.gd**, input_census.gd, highlights, visibility probe),
  `segments/` (creation / cultivation / **map** / …), `ai/`, `battlefield.gd`
- `scenes/` — Godot scenes: `ui/` (hud, health_bar), `segments/`
  (creation, map, …), `battlefield.tscn` (draw order: highlights →
  Characters → TileMarkers), `main.tscn` / `menu.tscn` (the `Camera` node
  carries `camera_follower.gd`; HUD/Tutorial layers are non-following)
- `playtest/` — 69 headless playtest scenarios + the `_common.yaml` contract
  (70 yaml files); frozen yamls are append-only (the historically authorized
  edits stay machine-pinned by the superset fixture)
- `tests/` — GDScript unit suites (23 files in the TESTS registry, incl.
  **`test_facility_data.gd`**, `test_click_priority.gd` / `test_health_bar.gd`
  + SceneTree-style integration suites), `test_playtest_contract_smoke.py`,
  **`test_facility_copy_location.py`** (§433 guard), and the frozen
  `fixtures/playtest_assert_superset.json` baseline
- `design/` — the design archive (`00_overview.md` … `99_changelog.md`);
  this round's records: `20_content.md` §8.1/§8.3 + **§10** (facility content
  type definition, data rows, invariant, observability/guards, red value
  record), `00_roadmap.md` (completeness entries 2 + 4), `90_decisions.md`
  (five facility rulings a–e), `99_changelog.md` (the jinyong-facility row)
- `final/` — per-round delivery notes and probe notes (the facility round's
  red-then-green record lives in `final/delivery_notes_facility.md`; the
  verdict lives in `final/verify_report.json`; the round record lives in the
  design archive)
- `assets/` — placeholder textures, seed portraits, NotoSansSC font, audio
