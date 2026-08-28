# jinyong — Wuxia Crossover Tactics (Godot 4)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. This is a fan-crossover brawler, not
a recreation of any single novel. You create your own nobody, borrow the fully
mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, receive a chance to join a great
sect, spend three in-game years (36 cultivation periods) training, and finally
walk the jianghu map to an ending (`design/00_overview.md`).

Visuals are deliberately **color blocks** (placeholder art; 96×128 portraits on
64 px tiles are the frozen art contract). UI text is Chinese, rendered with the
bundled NotoSansSC font (SIL OFL, see `assets/fonts/LICENSE_OFL.txt`). The
project is at roadmap stage 3 (game content) with the stage-2 interaction layer
hardened: every mouse/info defect reported by playtesters this round is fixed
and pinned by assertions.

## Latest round: interaction-defects — three measured mouse/info defects fixed

Three player-measured interaction defects (A: floating health bar ate
right-clicks; B: portrait a full tile above its cell / nameplate on the legs /
portrait clicks did not target; C: trait descriptions showed only on click),
plus the real-input coverage net, a touch-reachable undo, and three small
fixes. All changes are additive; the frozen constants (`TILE_SIZE = 64`,
`BOARD_TOP_MARGIN_Y = 92`, the `STRIP_BOTTOM + 2 = 94` bar clamp, and the
96×128 portrait art size) are untouched, and no existing play-test assertion
was weakened.

- **Defect A — the floating health bar's `Bar` (ProgressBar) ate right-clicks
  at the player's own feet.** `Bar` inherited Godot's default `mouse_filter =
  STOP`, so a right-press on the feet tile (exactly where a player aims to
  retreat) was swallowed in the GUI phase before `player._unhandled_input`
  could run. Fix: `mouse_filter = 2` (IGNORE) in `scenes/ui/health_bar.tscn` +
  a per-frame re-assert in `scripts/ui/health_bar.gd::update_health` beside
  the two existing sibling assertions, with the rule written in the comment:
  **no descendant of a floating HUD control may be STOP**. The whole
  `health_bar.tscn` subtree audit table and the enemy `ClickTarget` verdict
  (measured, not commented: `gui_input` fires 0 times — dead for routing,
  cannot eat events; node kept as the harness click anchor) are recorded in
  `design/30_presentation.md`. New scenario
  `playtest/click_move_undo_feet.yaml` right-clicks **exactly `Player +0,0`**
  (the feet, inside the old dead zone) and asserts the retreat;
  `click_move_undo_right.yaml` (which clicks `Player +64,0`) is untouched.

- **P0 real-input coverage net (round-owner re-scope).** The round that
  reported these defects also found that a 57/57-green headless suite could
  not see a full-screen STOP hole in the real boot scene (`menu.tscn`
  `SegmentHost` — fixed and player-confirmed). What landed in this repo:
  Layer 1, permanent per-press differential observables in `player.gd`
  (`debug_right_input_events` / `debug_undo_events` / `debug_gui_eater`,
  backed by `scripts/ui/input_census.gd`), pinned by the new
  `playtest/input_click_differential.yaml`; Layer 2, the `InputGate` autoload
  (`scripts/autoload/input_gate.gd`, activated only by the env var
  `AITELIER_INPUT_GATE_REPORT`, self-drives to the battle state and publishes
  the nine-key report the AItelier sidecar `/x11_input_smoke` endpoint
  consumes — the sidecar half landed outside this repo). Honest boundary,
  recorded in `design/90_decisions.md` + the delivery notes: the web
  browser→engine bridge is manual-only; a skipped gate run is recorded as an
  OPEN coverage gap, never green.

- **Touch-reachable undo.** Phones have no right-click, so 「右键退回」 was
  unreachable on touch. New HUD 「退回」 `UndoButton` delegates to the **same
  shared undo entry** as the right-click (same 4-condition gate, same
  「已出手，无法退回」 lock rule), and its `disabled` state mirrors
  `undo_available` every frame. Pinned by `playtest/undo_button_retreat.yaml`.

- **Defect B visual — the nameplate now reads as belonging to the portrait.**
  The health bar/nameplate moved from the feet (where it sat on the shins) to
  the **portrait top**: the widget bottom sits 4 px above the per-frame
  `sprite_top`. The `STRIP_BOTTOM + 2 = 94` clamp is retained, and the
  measured top-row landing is documented (`design/30_presentation.md` +
  in-code): top-row units (Central_Divine, West_Poison, `sprite_top == 92`)
  get their bar clamped to y 94..118 over the hair/forehead band
  `[92, 132]` — the face of a 128 px portrait starts ≈ `sprite_top + 40` and
  is **not** covered. Because a raised nameplate removes the last visual
  cue of "who stands on which tile", a new **ground marker** landed in the
  same change: `scripts/ui/tile_markers.gd` — a click-inert Node2D overlay
  mounted **after** `Characters` in `scenes/battlefield.tscn` (the measured
  route where all six markers, including the top row, stay visible), painting
  a low-alpha gold ellipse with a thin outline at each living unit's tile.

- **Defect B hit — the 5-step click priority rule** (`player.gd::
  handle_world_click`, pure predicates `resolve_click_step` /
  `attack_reach_covers`, unit-pinned by `tests/test_click_priority.gd`):
  (1) enemy occupies the clicked tile → attack; (2) an **in-reach** enemy
  whose live clamped portrait rect contains the point → attack (closes the
  "attacking along the portrait never hits" complaint for enemies you can
  actually reach); (3) reachable empty tile in the move-range highlight →
  move; (4) an **out-of-reach** enemy's rect → select (never a silent move);
  (5) own tile no-op / else move. The operative guarantee: **an out-of-reach
  enemy's portrait rect can never make a reachable empty tile unclickable** —
  the rejected "grid → rect → move" rule did exactly that (measured
  `click_move_undo_right` 10→6, `click_move_commit_lock` 9→1,
  `move_target_affordance` 18→11, because top-row Central_Divine's clamped
  art covers tiles (7,2)/(7,3)) and is recorded as rejected in
  `design/90_decisions.md`. The hit rect is the **live clamped**
  `portrait_ink_rect` (published per-frame on player and enemies), never the
  naive feet−128 assumption. Pinned by
  `playtest/click_portrait_body_targets_enemy.yaml` (reachable body-centre
  click → damage + `acted == true`, with an out-of-reach negative control
  that must not silently move) and `playtest/health_bar_above_portrait.yaml`
  (bar-vs-portrait geometry incl. the top-row clamped landing, and
  `tile_marker_count == 6`).

- **Defect C — trait descriptions preview on hover.** Every
  `TraitToggle{0..12}` now carries `mouse_entered`/`mouse_exited` wiring;
  hovering previews that trait's description in `TraitDescLabel` through a
  display-only `trait_hover_index` (−1 on exit, and reset whenever
  `phase != "TRAITS"`), reverting to the focused `trait_index`'s entry on
  exit. Hover **never** writes `trait_index` (keyboard focus / toggle
  target), never triggers a toggle, and never touches the focus `modulate` —
  pinned by `playtest/trait_hover_preview.yaml` (driven by the harness's
  motion-only `hovers:` syntax) and
  `tests/test_trait_hover_preview.gd`.

- **Small fixes.** `final/delivery_notes.md`'s mis-attributed heading
  corrected to `jinyong-mainline(主线事件) (2026-08-27)`; the map screen now
  shows **exactly one** operation hint (the footer `HintLabel` kept, the
  duplicated panel trailing line removed — rationale in
  `design/90_decisions.md`「地图提示一屏一条」, with a changelog row
  explaining why the previous round's byte-identical "unification" was
  changed); the MAP EVENT branch's half-width comma unified to full-width
  「上下选择，回车定夺」. The new `playtest/map_hint_single.yaml` pins both
  halves in both phases (TRAVEL: footer carries the hint and `BodyLabel`
  does not repeat it; EVENT: footer hidden, full-width prompt in the panel).

- **Regression net.** Seven scenarios appended this round (58 → 65,
  append-only; none of the frozen yamls modified):
  `click_move_undo_feet`, `input_click_differential`,
  `undo_button_retreat`, `click_portrait_body_targets_enemy`,
  `health_bar_above_portrait`, `trait_hover_preview`, `map_hint_single`.
  Two-place contract sync (`playtest/_common.yaml` `scenario_order` +
  `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS`); the
  GDScript unit registry grows 20 → 22 files
  (`test_click_priority.gd`, `test_trait_hover_preview.gd`); the
  `hovers:` motion-only syntax is documented in the `_common.yaml` header.

Previous rounds: jinyong-nodes (five main story nodes get content),
jinyong-map-events (node entry-content + shared `EventLogic` + map EVENT
phase), jinyong-spend-qi (real inner-qi costs), jinyong-clarity
(creation-screen information layer), jinyong-hud (battle-HUD information
layer), jinyong-events (event pool 4 → 16 rows), plus the owner's hand-added
华山 battle node (`map_battle_node_huashan`, the first non-event battle entry
on the map). All recorded in `design/99_changelog.md` and the `final/*`
notes history.

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
whose **descriptions now preview on hover**; a confirm page listing the final
values) → tutorial battle as a fully mastered Yang Guo vs the Five Masters
(you are meant to win) → transition → sect choice → 36-month cultivation →
the jianghu map. In battle: left-click a highlighted empty tile to move,
left-click an enemy (its own tile **or** the drawn portrait body of an enemy
in reach) to attack, right-click **or the HUD 「退回」 button** to retreat to
the turn-start tile until you act (acting locks the move), 结束回合 to end the
turn; each unit's nameplate rides above its portrait head and a gold ground
marker under its feet marks the occupied tile; casting a move spends its
inner-qi cost (内力: N in the top strip; a too-expensive move greys into
「内力不足」; the free basic 重剑无锋 always stays available). On the map,
左右/上下 cycle the adjacent nodes and 回车 travels — the one on-screen hint
lives in the footer; every mainline stop opens its node event on arrival
(洛阳 行商路过 / 武当 全真抄经 / 襄阳 降龙残谱; 无名谷 fires on the return
trip; 少林 off the 洛阳 branch fires 破庙夜雨) — resolve with
上下选择，回车定夺 to continue. Entering 昆仑 routes straight to the tiered
ending (end-node routing runs before entry content, so nothing can block it),
and events fire only on travel — never on boot or load, so save/load
roundtrips don't re-trigger.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check → headless playtest of all 65 scenarios → GDScript unit
suite). It fails loudly when the sidecar is unreachable — the code then ships
unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (incl. the superset pin)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite (22 files)
godot --headless --path . -s res://tests/test_cultivation.gd  # SceneTree-style suites
```

## Key interfaces

- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`, `get_enemies_alive()`), `CombatManager` (battle state:
  `tutorial_battle`, `current_round`, `phase`, `is_player_turn()`, the qi
  spend path `spend_unit_energy(unit, cost)` + the `debug_spend_player_qi()`
  drain fixture), `GridManager` (grid / movement planning,
  `world_to_grid` / `grid_to_world` / `clamp_sprite_offset`), `SaveManager`
  (profile, slots, `rng`, autosave), `InputGate` (real-input gate — inert
  unless the env var `AITELIER_INPUT_GATE_REPORT` is set; then self-drives to
  the battle state and publishes the nine-key JSON report
  `ready / player_world / grid / moves_left / raw_left / handled_left /
  raw_right / handled_right / eater` for the windowed X11 smoke endpoint).
  `SceneManager` must stay the LAST autoload entry (compile ordering).
- **Battle click priority (Defect B)**: `Player.resolve_click_step(
  click_point, click_tile, player_grid, enemies, reachable,
  selected_skill_index, skills) -> int` and
  `Player.attack_reach_covers(player_grid, enemy_grid,
  selected_skill_index, skills) -> bool` — pure statics (headlessly
  unit-testable) implementing the 5-step rule above; the live clamped
  hit rect is `portrait_ink_rect` (Rect2) published per-frame on `Player`
  and every `Enemy` alongside `sprite_top` / `portrait_sprite_pos` /
  `portrait_tex_size`.
- **Floating health bar** (`scripts/ui/health_bar.gd`,
  `scenes/ui/health_bar.tscn`): anchored above the portrait top
  (`bar_anchors_sprite_top` true when the unclamped desired bottom ==
  `sprite_top − 4`), clamped to `STRIP_BOTTOM + 2 = 94`; every node in the
  subtree is `mouse_filter = IGNORE` (root/Bar/EmptyCap/HpLabel set
  explicitly in the tscn and re-asserted every update; NameLabel rides the
  Label class default IGNORE) so it can never eat a board click. Observables:
  `bar_width` / `bar_height` / `bar_top` / `bar_bottom` /
  `bar_anchors_sprite_top` / `hp_text` / `hp_value` / `hp_max` /
  `hp_text_width_ok` / `empty_area_px` / `empty_cap_px`.
- **Ground markers** (`scripts/ui/tile_markers.gd`, `TileMarkers` node in
  `scenes/battlefield.tscn`, drawn after `Characters`): click-inert Node2D
  overlay painting one ellipse per living unit; observables
  `tile_marker_count` / `tile_marker_visible`.
- **Creation screen** (`scripts/segments/creation.gd`): `phase`, `points_left`,
  `attrs`, `trait_ids`, `trait_index` (keyboard focus / toggle target —
  hover never writes it), `trait_hover_index` (display-only hover preview,
  −1 when unset), `hover_connected` (per-toggle `mouse_entered`/`mouse_exited`
  wiring snapshot), `hp_value` / `hp_text` / `confirm_summary_text`.
- **Input differential observables** (`scripts/characters/player.gd`):
  `debug_input_events` / `debug_right_input_events` (raw presses reaching
  `_input`), `debug_click_events` / `debug_undo_events` (entries into
  `handle_world_click` / `handle_world_right_click`),
  `debug_gui_eater` (predicted top GUI eater at the last press, via
  `InputCensus.top_eater`), `debug_last_raw_event_pos` /
  `debug_last_click_grid`. `Enemy.debug_click_target_fires` counts
  ClickTarget `gui_input` fires (measured 0 — dead for routing).
- **HUD** (`scripts/ui/hud.gd`): EndTurn / Attack / **UndoButton** (退回,
  delegates to the shared undo entry, `disabled` mirrors `undo_available`);
  observables incl. `pressed_connected["UndoButton"]`,
  `hud_button_overlap`, `undo_desc_overlap`.
- **Map entry-content layer**: `MapData.NODES` rows carry
  `entry_content = {event|battle|facility: {status, <type>_id}}`;
  `MapData.active_event_id(id)` (non-empty iff slot active AND the event def
  exists), `MapData.declared_gap_types(id)`. Five live deterministic event
  bindings (wuming_valley/luoyang/wudang/xiangyang + shaolin) + the active
  battle slot at 华山; source of truth `design/20_content.md` §8.
  `MapScreen` (`scripts/segments/map.gd`): `phase` (TRAVEL|EVENT), `event_id`,
  `event_focus`, `events_resolved_count`, profile mirrors for differential
  asserts. End-node routing to ENDING runs before entry content; the
  operation hint lives **only** in the footer `HintLabel` (hidden during
  EVENT).
- **Shared event resolution**: `EventLogic` (`scripts/data/event_logic.gd`,
  pure statics) — `draw_unseen_id(profile, rng)` (no-repeat bag),
  `apply_option_effects(profile, opt)` (silver/attr/item/practice/none, zero
  RNG calls). Event text lives only in `scripts/data/event_data.gd`
  (`EventData.TABLE`, 16 rows, 2 options each).
- **Qi-cost layer**: `SkillData.cost` / `insufficient_energy` / `spend`;
  `Player.energy` / `energy_max`; `_execute_skill()` gates and deducts on the
  single cast path.
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections), the
  observable-surface whitelist and `scenario_order`; each
  `playtest/*.yaml` is one scenario (name == basename, single-integer `at:`,
  a comparison operator or changed/unchanged token on every assert line).
  `clicks:` entries are `<Node>[ +dx,dy][ left|right|middle]` (Control
  anchors resolve by `get_global_rect()` centre, Node2D anchors by node
  position); `hovers:` entries are **motion-only** (same anchor grammar, no
  button token — a button token is a hard failure) so hover can be pinned
  without a press; a same-frame hover is pushed before any click.
- **Unit tests**: GDScript files with a top-level `static func run() -> bool`
  are collected by `tests/unit_test_runner.gd`'s explicit append-only `TESTS`
  registry (22 files as delivered, incl.
  `tests/test_click_priority.gd` and `tests/test_trait_hover_preview.gd`),
  run headless via
  `godot --headless --path . -s res://tests/unit_test_runner.gd`.
  SceneTree-extending integration suites (`test_cultivation.gd`,
  `test_encounter.gd`, `test_save_manager.gd`, `test_game_manager_fsm.gd`)
  are driven with their own `-s` invocation. The pytest smoke
  (`tests/test_playtest_contract_smoke.py`) statically pins the scenario
  contract, the two-place sync, and the "assertions only added" rule for the
  authorized-edited yamls (`test_edited_scenarios_assert_superset` against
  `tests/fixtures/playtest_assert_superset.json`).

## Verification status (honest)

The only authoritative gate evidence is the pipeline step products —
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` — pipeline artifacts, not repo files; none is on disk at
the verifier step (the gates run after it). In short:

- Every implementation-level goal of this round is direct-read verified:
  the Bar filter fix + per-frame re-assert + subtree audit + measured
  ClickTarget verdict, the feet-tile undo scenario (with
  `click_move_undo_right.yaml` untouched), the nameplate re-anchor with the
  retained clamp and documented top-row landing, the click-inert
  after-`Characters` ground marker, the live-clamped `portrait_ink_rect` +
  5-step priority resolver (rejected rule recorded with its measured
  numbers), the body-centre click scenario with its negative control, the
  hover-preview channel that never touches `trait_index` / toggle /
  `modulate`, the three small fixes, the six-scenario two-place sync, and
  the design/changelog/delivery-notes records.
- The round's **measured** pass — all 65 scenarios green (the 58 pre-existing
  plus the 7 new ones; the acceptance net `click_move_undo_right`,
  `click_move_commit_lock`, `move_target_affordance`, `click_move_to_tile`
  included), compile zero errors, pytest smoke green, the 22-file unit suite
  green, and the vision gate on the new presentation elements — is
  **pending the downstream gate run, not claimed**. The last fully measured
  final-tree run (jinyong-nodes: 57/57 scenarios, 77/77 scripts) predates
  this round's changes.
- One minor docs-vs-code discrepancy found and recorded in
  `final/verify_report.json`: `design/30_presentation.md`'s audit table and
  the delivery notes say `NameLabel` gained an **explicit**
  `mouse_filter = 2` line in `health_bar.tscn`; the delivered tscn has no
  such line (NameLabel rides the Label class default IGNORE — no STOP hole
  either way, so the audit's conclusion stands; only the "explicit
  declaration" detail is inaccurate).
- If the downstream playtest gate reddens any existing scenario, that is a
  regression by this round's constraint: fix the resolver/clamp interplay or
  make the offending change inert — never remove or relax an assertion, and
  never modify `click_move_undo_right.yaml` (or any frozen yaml) to route
  around a defect.

## Repository layout

- `scripts/` — game code: `autoload/` (GameManager, CombatManager,
  GridManager, SaveManager, **InputGate**, SceneManager-last, …),
  `characters/` (`player.gd` incl. the click-priority resolver and the
  differential observables, `enemy.gd` incl. `portrait_ink_rect` /
  `debug_click_target_fires`), `data/` (map/event/skill/trait data,
  `event_logic.gd`), `ui/` (HUD, **health_bar.gd**, **tile_markers.gd**,
  **input_census.gd**, highlights, visibility probe), `segments/`
  (creation / cultivation / map / …), `ai/`, `battlefield.gd`
- `scenes/` — Godot scenes: `ui/` (hud, health_bar), `segments/`
  (creation, map, …), `battlefield.tscn` (draw order: highlights →
  Characters → **TileMarkers**), `main.tscn`, `menu.tscn`
- `playtest/` — 65 headless playtest scenarios + the `_common.yaml` contract
  (66 yaml files); frozen yamls are append-only (the two historically
  authorized edits stay machine-pinned by the superset fixture)
- `tests/` — GDScript unit suites (22 files in the TESTS registry, incl.
  `test_click_priority.gd` / `test_trait_hover_preview.gd`, + SceneTree-style
  integration suites), `test_playtest_contract_smoke.py` and the frozen
  `fixtures/playtest_assert_superset.json` baseline
- `design/` — the design archive (`00_overview.md` … `99_changelog.md`);
  this round's records: `10_systems.md` §5.1 (undo shared entry),
  `30_presentation.md` (mouse_filter audit table + ClickTarget verdict,
  nameplate/ground-marker, 5-step priority rule), `90_decisions.md`
  (priority rule, P0 root cause, single map hint), `40_ux_backlog.md`
  (round record), `99_changelog.md` (interaction-defects row)
- `final/` — per-round delivery notes and probe notes; the
  interaction-defects section of `delivery_notes.md` records what changed,
  the new assertions, and the Defect B priority rule
- `assets/` — color-block textures, seed portraits, NotoSansSC font, audio
