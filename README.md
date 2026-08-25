# 华山论剑 (Huashan Sword Tournament)

A **Godot 4** single-player wuxia cultivation + turn-based tactics RPG. You boot into a **main menu** (mouse-first), create your own character **before** the tutorial, fight a keyboard-completable tutorial duel as the orchestrated Yang Guo, and then walk the six-segment line: **tutorial win -> transition -> sect selection -> cultivation (36 months) -> map -> ending**.

> ⚠️ **Verification status: not yet deployable - downstream gates pending.** This round's deliverable (creation-screen re-layout pass 2 + native-size health-bar readability) is fully implemented and integration-verified at the code level, with pre-fix probe evidence recorded, but the objective gates (compile, vision, unit tests, full playtest) run **after** the Final Verifier and their report files do not exist at this step. `final/verify_report.json` records `all_goals_met: false` / `ready_for_deploy: false` for that reason. See [Verification Status](#verification-status).

## What this round delivers - 捏人屏排版返工 + 血条真实尺寸可读 (jinyong-layout-r2)

The previous layout round fixed the creation screen's **row-internal** rhythm (value label right-aligned against its `-`/`+` cluster - correct, kept) but left the **whole-screen** layer broken: the five attribute rows filled the full 560px container, flinging the label + `-`/`+` clusters to the far right edge (ink ≈ x 608..760) while the nav buttons and description text sat far left - and the then-current `points_attrs_gap_ok` stayed green through all of it because it compared **container** rects (both nominally centered at 480). Independently, the floating health bar read as a solid green rectangle at the native 960×704 size (vision gate Q5 17/26). This round:

1. **Creation screen re-layout, pass 2 (row-level shrink-center).** `scenes/segments/creation.tscn` gives every row `size_flags_horizontal = 4` (SHRINK_CENTER): `AttrRow0..4`, `AttrNavRow`, `TraitNavRow`, and each of `TraitToggle0..12`; `AttrLabel`'s minimum width now hugs its text (its `horizontal_alignment = 2` + expand-fill pair is untouched - the row-internal half that was already correct); the phase description labels (`AttrDescLabel` / `TraitDescLabel`) become center-aligned (`horizontal_alignment = 1`). Every visible leaf's ink now lands on the **x=480 axis** in all three phases. **Property-only edits: no node renames, no reparents, no new nodes** - the five creation scenarios' pinned paths are untouched. The battle top bar (`TopStrip`, strip clamping, top-text layout) is correct from last round and deliberately untouched.
2. **Health bar readable at the native 960×704 size.** Same nodes, same types (`ProgressBar` + `EmptyCap` ColorRect + `StyleBoxFlat`), geometry/contrast only: bar **8→12 px tall**, widget **68×20→68×24**, empty cap **6→10 px** (empty-slot area 48→120 px² authored, ×2.5), track halo **4→6 px**, hover offset −28→−32 (unchanged 8 px hover gap). The cap is a **constant design element** (like a border) - the fill stays truthfully driven by `value / max_value`; no faked HP. No zoomed evidence: acceptance is on native frames.
3. **"Where is the visible content" made decidable - measured on INK.** `scripts/segments/creation.gd` adds six leaf-ink observables (`attr_cluster_center_ok` / `attr_cluster_width_ok` / `nav_cluster_center_ok` / `trait_cluster_center_ok` / `desc_center_ok` / `desc_alignment_ok`) computed per frame from label **text** rects (`Font.get_string_size`, honoring alignment) and button rects - never container rects - and reworks `points_attrs_gap_ok`'s internals to compare PointsLabel's text rect against the phase's first-row ink cluster (same var name, same yaml assert lines). Pre-fix probe values are recorded with A/B labels in `final/creation_probe_notes.md` and `final/health_bar_probe_notes.md`: every A-class fact was **observed red on the un-fixed layout** (e.g. `attr_cluster_center_ok == false` @f30 - the "split across the screen" defect this round kills), so a recurrence of that layout turns the gate red immediately.
4. **Contract wiring (append-only / in-place).** `playtest/_common.yaml` surface gains `HealthBar.bar_height / empty_area_px / empty_cap_px` and the six `CreationScreen` cluster vars; `creation_layout_readability.yaml` and `ui_geometry_readability.yaml` are extended in place (existing asserts byte-identical); `tests/test_playtest_contract_smoke.py` gains `test_creation_rework_and_bar_surface_contract`; `tests/test_health_bar.gd` is geometry-synced (68×24 / 12 px / expand 6 / cap 10). **No new scenario files** - `scenario_order` and `ROUND_SCENARIOS` are unchanged (44 scenarios).

**Runtime note (probed, not derived):** Godot clamps a `ProgressBar`'s `size.y` to its theme minimum (~22 px) once it enters the scene tree, so the battle gate reads `bar_height ≈ 22` and `empty_area_px` 132→220 px² across the fix; the authored 12 px / 120 px² contract is pinned on the tscn + headless unit-test path, and the runtime A-class proof is `empty_cap_px` 6→10 (see `final/health_bar_probe_notes.md`). Both paths are green post-fix.

## Quick Start

1. Open the project in **Godot 4.4+** (`project.godot` `config/features` records `4.7`).
2. Run the import/compile pass so Godot produces `.import` sidecars (the harness `--compile` step does this; in the editor it happens on open).
3. Press **F5** (or *Run Project*). The game boots into the **main menu**.
4. Click **新的冒险** (or arrow + Enter to navigate), create your character with the mouse (a single button-driven surface), then confirm to enter the tutorial.

## How to Play

| Action | Input |
|--------|-------|
| Menu / settings navigation | Arrow keys + **Enter** - or **click** the entry |
| Creation attribute / trait / phase | Click the ±/toggle/nav buttons - keyboard is a shortcut on the same surface |
| Move (primary) | **Left-click** an empty highlighted tile; the player walks there |
| Undo this turn's movement | **Right-click** - returns to the turn-start tile and refunds the budget (refused after you act) |
| Move (shortcut) | WASD / Arrow keys (one tile per press, 4-tile budget) |
| Select technique | **1–8** (9–12 with 左右互搏; or click the HUD skill buttons) |
| Execute technique / basic attack | **J** (`attack_confirm`) or click **出招 (J)**; left-click an enemy targets the same way |
| End turn | **Space** or click **结束回合** |
| Advance tutorial | Enter / Space |
| Pause / unpause | Escape or click **Pause** |

- Every turn = move up to your movement range **plus** one action, in any order. The green highlight shows every tile you can still reach.
- Left-click an enemy tile attacks; left-click an empty walkable tile moves; left-click your own tile is a no-op; clicking an unreachable tile says 走不到那里.
- Once you act (attack / skill / item), the turn's movement is committed - right-click undo is refused (已出手,无法退回). Ending the turn commits too.
- Press `J` (or click 出招) with no skill selected to basic-attack the **nearest adjacent** enemy.
- Select a skill with `1`–`8` (or `9`–`12`), then press `J` to fire it; `SkillDescLabel` shows the skill's Chinese description, the hint line tells you the next step, and the grid highlight shows reachable + target tiles.
- **Two-phase unlock** (tutorial only): techniques `5`–`8` (Melancholy Palms) lock until **round 4**; technique `8` requires HP **below 50%**. A rejected selection says why instead of doing nothing.
- Each unit acts once per round in initiative order: Yang Guo (88) -> East Heretic (85) -> Central Divine (80) -> South Emperor (76) -> North Beggar (74) -> West Poison (70).
- Defeat all five Grandmasters to win; let your health reach zero to lose.

## The Flow (state machine)

```
MENU ──新的冒险──▶ CHARACTER_CREATION ──confirm (creation_entry=="MENU")──▶ TUTORIAL ──done──▶ BATTLE
  │                       │                                                                    │ WON
  │ 设置                 (creation_entry=="TRANSITION", legacy/test-only)                       ▼
  ▼                       ▼                                                             TRANSITION (2 pages)
SETTINGS ──返回──▶ MENU  SECT_SELECTION ◀──TRANSITION (last page: creation_done ? SECT_SELECTION : CHARACTER_CREATION)
  │                          │
  ▼                          ▼
(quit)                  CULTIVATION ──▶ MAP ──▶ ENDING
                           ▲ save/load (STABLE_STATES)
MENU ──读取存档──▶ load_slot(1) ok & segment ∈ STABLE_STATES -> direct state set (bypasses SEGMENT_PREDECESSORS)
```

The whole game runs inside one persistent shell: `SceneManager` (an autoload) listens to `GameManager.state_changed` and swaps exactly one active scene under the shell's `SceneHost` (Node2D for the battlefield) or `SegmentHost` (full-rect Control for segment scenes). `GameManager.current_state` is the playtest-visible FSM state.

**Two shell scenes exist.** `scenes/menu.tscn` is the real launch entry (a shell-identical copy of `main.tscn` plus an authored `MenuPanel`); its panel's `_ready` claims the boot before SceneManager's deferred default battlefield swap. `scenes/main.tscn` is untouched and still boots the legacy flow - that is what keeps all pre-existing scenarios frame-identical. **No headless/env-var/`--skip-menu` branching exists anywhere**.

| Segment | Scene | What happens |
|---|---|---|
| 0. Creation | `creation` | 30-point attribute buy (tiered pricing, 10–20) + trait/flaw toggles + per-phase Back/Next buttons - one mouse-driven button surface (keyboard is a shortcut) |
| 1. Tutorial | `battlefield` | Yang Guo vs the Five Greats (keyboard-completable tutorial) |
| 2. Transition | `transition` | Full-screen Chinese text pages -> next segment |
| 3. Sect select | `sect_select` | Pick one of five sects -> its 丁 internal + 丁 external gongfa |
| 4. Cultivation | `cultivation` | 36 monthly cycles: card draws + 练功/修习/做工/游历 + year-end stay/switch + 存盘/读档/删档 |
| 5. Map / ending | `map` -> `ending` | Node-graph map (adjacency-checked moves) -> tiered ending text |

## Main Menu & Settings

**Menu entries** (single activation path - mouse `pressed`, keyboard `ui_accept`, and the harness `debug_click_menu_entry` action all converge on `_activate_entry(i)`): 0 新的冒险 / 1 读取存档 / 2 设置 / 3 退出.

**Load availability is file existence** (`SaveManager.has_save_file(1)`), never session-memory `has_save`. **Settings screen** (音效音量 / 音乐音量 / 全屏 / 返回): volumes step ±3 dB clamped to [−40, +6] dB, persisted via `SettingsManager` -> `user://settings.cfg`; fullscreen is applied only when not headless.

## Save / Load

Saves live at `user://save_<slot>.json` (plain JSON, 3 slots, versioned schema, atomic `.tmp` -> validate -> `.bak` rollback -> promote -> re-validate -> drop backup). The save carries the RNG seed + `rng_state` + the per-category deck lists, so a reload replays the identical card sequence. `STABLE_STATES` is `["CULTIVATION", "MAP"]`.

## Chinese Font Theme

The whole UI ships in Chinese under one global font theme: `assets/themes/global_theme.tres` (Noto Sans SC via res:// path, `default_font_size = 12`), wired through `ProjectSettings gui/theme/custom` + `ThemeManager` fallback. **No per-node font overrides.** Display layer only - `character_name`, node names, skill ids, state strings and turn-order names stay canonical English.

## The Five Grandmasters (deterministic AI)

Each enemy is driven by a distinct AI controller (`scripts/ai/*.gd`) that decides **once per enemy turn** via a deterministic priority list - no timers, no RNG: West Poison (poison/reflect), North Beggar (brawler/−15% damage taken), East Heretic (ranged seals/counter), South Emperor (ranged healer/regen), Central Divine (shield/dispel, survives the first fatal blow at 1 HP via 先天罡气).

## Turn System

- **Round snapshot**: living units sorted by effective initiative descending (decorate-sort-undecorate insertion sort for determinism).
- **Turn-start lifecycle** (exact order): cooldown decrement (int rounds) -> DoT/status ticks -> constant regen -> the unit acts.
- **Trial / undo / commit**: `begin_turn` records `turn_start_grid` / `turn_start_moves_left` / `turn_start_moved`; a right-click restores them (animated). `acted == true` (set only on successful execution) or end-turn commits the movement - after that, right-click undo is refused but further movement is still allowed.
- **Damage pipeline**: attack side `round(base × buffs × fa_hui_du)` -> defense side `round(output × (1 − DR))`. 发挥度 applies to damage/heal/shield/DoT-tick values only - never cooldown, range, knockback, or duration; percentages never take the multiplier.
- **Melee vs ranged**: decided by the declaring external art's **weapon class**, never by shape/reach/damage.
- **Pause** is a boolean gate (no `Engine.time_scale`).

## 功法 (Gongfa) Data Structure

`scripts/data/gongfa_data.gd` models internal/external martial arts. Every art exposes `get_fa_hui_du(unit)` - the real 甲乙丙丁 prerequisite cascade, interval 0.6~1.3 (missing prereq count -> base [1.0, 0.85, 0.7, 0.6], then +0.1 × same-attribute mastered arts up to 3). The tutorial's protected 1.3 comes out of this same cascade via `TutorialFillers.fill()`. The progression ladder registers 5 sects × (internal+external) × 丁丙乙 plus the hand-authored 甲 pool; `TraitEffects.practice_gain(wisdom, roll)` maps the 悟性-tier 修习 lookup table.

## Encounter Battles

`GameManager.start_encounter()` (distinct from tutorial-gated `start_battle()`) sets `battle_return_state = "CULTIVATION"`, builds the player from `SaveManager.profile`, spawns a deterministic sparring partner, and skips the tutorial overlay. `request_retry()` / `request_continue()` route LOST/WON back to `battle_return_state`.

## Trait Effects

Pure static math lives in `scripts/data/trait_effects.gd`; engine hooks live in `CombatManager` / `player.gd` / `battlefield.gd`. 杀 heals 20% of HP loss (capped 15% max/round); 破 gives gongfa practice ×1.5; 狼 gives attack ×(1+0.08×living) and DR 0.05×living; 铁布衫 survives the first lethal blow at 1 HP; 身轻如燕 slides through an enemy tile (cost 2); 左右互搏 raises the equipment cap to 3 external arts (12-slot bar). Each trait carries a `description` (Chinese 机制 文案) rendered by `TraitDescLabel`.

## HUD

- **Top strip** (`TopStrip`): full-width 0..92px semi-transparent dark `StyleBoxFlat` band (`mouse_filter = 2`, drawn behind everything) hosting 回合数 / 行动条 / 出手顺序 / 技能提示 / 内力, pairwise non-overlapping. `PauseButton` stays top-right on the band; `EndTurnButton` / `AttackButton` / `SkillDescLabel` sit below it. *(Correct as of the previous round - untouched this round.)*
- **Grid overlay** (`GridLines`): 1 px semi-transparent cell boundaries across the 15×11 board plus a border ring.
- **Movement-range highlight** (`MoveRangeHighlight`): green BFS mirror of `_try_move`; observables `visible` / `tile_count` / `fill_color` plus `start_tile` / `undo_available` trying-state markers.
- **Range/target highlight** (`RangeHighlight`): blue reachable tiles + red valid targets, mirroring `player.can_skill_hit()`; `fill_color` observable for the green-vs-blue distinctness assert.
- **Action hint line** (`ActionHintLabel`): shows 按 J 出招 / 点击目标 after a selection and a specific Chinese reason on every rejection. Lives inside the top strip.
- **Skill description label** (`SkillDescLabel`): always-visible; default guidance -> selected skill's Chinese description.
- **Battle action buttons**: `EndTurnButton` (结束回合) + `AttackButton` (出招 (J)) in the top-right column under `PauseButton`, gate-guarded and disabled off-turn. **All battle clickables are `focus_mode = 0`**.
- **Skill bar**: up to 12 `SkillButton` nodes (default 2 arts / 8 slots; 左右互搏 = 3 arts / 12). Each shows name, hotkey, 发挥 ×N.N, and a cooldown/state overlay.
- **Health bars** (`HealthBar`): 64 px wide, **12 px tall bar** (68×24 widget; the battle scene's theme min-size makes the runtime bar render ~22 px tall), name label above (semi-transparent backing), green->yellow->red by HP fraction, **fixed 10 px empty cap** and **6 px track halo** so the empty slot reads at the native 960×704 size; floating bars clamp **below the top strip** (`top ≥ 94`) with an 8 px hover gap above the character's feet.
- **Round indicator**: 回合 N, 行动: <name> · 移动 <m>, 顺序: <Chinese names>.

## Project Structure

```
├── project.godot                 # Engine config, autoloads, input map, theme, run/main_scene -> menu.tscn
├── playtest/                     # Headless playtest contract, one file per scenario (44)
│   ├── _common.yaml              #   shared scene / actions / surface + scenario_order
│   └── <scenario>.yaml           #   basename == name:
├── run_tests.sh                  # CLI gate: compile + headless playtest + unit tests
├── design/                       # Authoritative design archive (00..99)
├── assets/                       # characters / terrain / backdrop / audio / fonts / themes / seed_manifest
├── scenes/
│   ├── menu.tscn                 # persistent shell + authored MenuPanel (real launch entry)
│   ├── main.tscn                 # untouched persistent shell (legacy boots)
│   ├── battlefield.tscn player.tscn enemy.tscn
│   ├── ui/ (menu_panel, settings_panel, hud, health_bar, skill_button, tutorial_overlay)
│   └── segments/ (creation / transition / sect_select / cultivation / map / ending)
├── scripts/
│   ├── battlefield.gd grid_lines.gd
│   ├── autoload/ (game_manager, scene_manager, save_manager, settings_manager, grid_manager,
│   │              combat_manager, tutorial_manager, theme_manager, audio_manager)
│   ├── characters/ (player.gd, enemy.gd)
│   ├── ai/ (ai_base + 5 Grandmaster controllers + ai_sparring)
│   ├── data/ (character_data, skill_data, gongfa_data, player_profile, trait_data, trait_effects,
│   │          tutorial_fillers, encounter_data, progression_gongfa_data, card_data, event_data,
│   │          map_data, battle_setup)
│   ├── segments/ (creation, transition, sect_select, cultivation, map, ending)
│   └── ui/ (menu_panel, settings_panel, hud, health_bar, skill_button, round_indicator,
│             pause_button, tutorial_step, range_highlight, move_range_highlight)
└── tests/                        # test_*.gd + unit_test_runner.gd + test_playtest_contract_smoke.py
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager`, `SaveManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`, `ThemeManager`, `SettingsManager`, `SceneManager` (kept **last**).

### Input actions (`project.godot` `[input]`)

`move_up/down/left/right`, `skill_1`..`skill_12`, `attack_confirm` (J), `end_turn` (Space), `pause_game` (Escape), `tutorial_next` (Enter), plus the harness-only DEBUG actions (`debug_fast_forward` / `debug_win_tutorial` / `debug_lose_tutorial` / `debug_step_month` / `debug_grant_art` / `debug_enter_encounter` / `debug_poison_player` / `debug_damage_player` / `debug_click_menu_entry` / `debug_click_creation_widget` / `debug_seed_save` / `debug_delete_save` / `debug_reset_settings`).

> **Naming caveat:** `basic_attack` exists as two different strings - the input action was renamed to `attack_confirm`; the engine action string `"basic_attack"` (AI decisions + `CombatManager.execute_action`) is unchanged.

### Mouse clicks (harness-verified)

The playtest harness posts **real** `InputEventMouseButton` events. The `clicks:` spec is `"<Node>[ +dx,dy][ left|right|middle]"`: `Central_Divine_ClickTarget` = left-click that node's screen center; `Player +64,0` = left-click one tile right of the player (TILE_SIZE = 64); `Player +0,0 right` = right-click the player's own tile. Click coordinates are converted in the handler via `get_canvas_transform().affine_inverse() * event.position` (never the viewport-cached `get_global_mouse_position()`). World clicks on tiles must go through `_input` relays (Godot's GUI picker does not route to Controls under Node2D ancestors).

### `GameManager` public API

`get_state()`, `start_battle()` (tutorial-gated), `start_encounter()`, `end_battle(won)`, `request_continue`/`request_retry`, `restart_game()`, `clear_battle()`, `release_stale_units()`, `enter_segment(state)`, and the menu surface `enter_menu()` / `menu_new_adventure()` / `menu_open_settings()` / `menu_close_settings()` / `menu_load_game()` / `menu_quit()` / `finish_creation()`.

### `SaveManager` public API

`save_slot(s)` / `load_slot(s)` / `autosave()` / `delete_slot(s)`, `has_save_file(s)`, `ensure_user_dir()`, `new_profile(attrs, traits)`, `apply_seed(seed)`, `draw_cards(monthly)`; surface vars `seed`, `last_error`, `slot`, `has_save`, deck counts, roundtrip observables, and `last_io_error_code` / `last_io_error_text` / `debug_user_dir_exists`. Signal: `loaded(slot)`.

### Playtest surface observables

**Battle top-bar observables** - `HUD.top_text_pairwise_overlap` / `top_text_in_strip` / `top_strip_alpha` / `hint_hpbar_overlap` / `hpbar_strip_overlap`; `TopStrip.visible` / `size`; `HealthBar.name_backing_alpha`. **Creation-layout observables (row rhythm, round jinyong-layout)** - `CreationScreen.attr_rows_uniform` / `attr_label_alignment_ok` / `points_attrs_gap_ok` / `phase_skeleton_same` / `creation_in_viewport` / `creation_box_fits`. **Creation leaf-ink observables (this round, jinyong-layout-r2)** - `CreationScreen.attr_cluster_center_ok` / `attr_cluster_width_ok` / `nav_cluster_center_ok` / `trait_cluster_center_ok` / `desc_center_ok` / `desc_alignment_ok`, plus the reworked internals of `points_attrs_gap_ok` (same name/asserts; now measured on ink). **Health-bar readability observables (this round)** - `HealthBar.bar_height` / `empty_area_px` / `empty_cap_px`. (Plus the prior rounds' `Player.turn_start_*` / `undo_available`, `MoveRangeHighlight.start_tile` / `undo_available`, `CreationScreen.cursor_markers_visible`, `PointsLabel.visible` / `text`, and `focus_mode` on the battle buttons.)

## Technical Notes

- **Godot version**: targets 4.4; `config/features` records `4.7` - pre-existing, compiles/runs under the current toolchain.
- **Stable initiative sort**: decorate-sort-undecorate with a registration-index tie-break.
- **Freed-object safety**: `is_instance_valid()` before every `as` cast / typed assignment; scene swaps await the outgoing scene's `tree_exited`.
- **Tween safety**: `_await_tween_safe()` caps every action tween at 0.25 s.
- **Deterministic AI**: zero RNG - pure priority lists.
- **Seeded RNG**: one `RandomNumberGenerator` owned by `SaveManager`, seeded from `mix_seed(system_entropy)` (splitmix64 finalizer - frozen).
- **Rounding**: `round()` half away from zero; `45 * 1.3` = 58.5 -> 59. Percentages never take the fhd multiplier.
- **Highlight layering**: `RangeHighlight` and `MoveRangeHighlight` sit between `GridLines` and `Characters`; translucent fills (alpha ≤ 0.28) keep grid lines readable.
- **Movement path planning**: `GridManager.plan_movement(from, budget, slide_ok)` is a pure relaxation BFS under the exact `_try_move` cost model (walkable + unoccupied landing at cost 1, 身轻如燕 slide-through at cost 2).
- **Overlap convention**: a pair "overlaps" iff the two rects intersect after each is inset 1px on all sides (`_inset_overlap`); hidden widgets are skipped, never asserted; all battle rects share the layer-10 scale-1 coordinate space (no Node2D↔Control conversion).
- **Ink, not slots (this round's measurement discipline)**: a Container's `get_global_rect()` measures the *slot*, not the *ink* - any assertion built on container rects can be satisfied by content hugging one corner of the slot. Position observables measure what actually draws: label **text** sub-rects via `Font.get_string_size` (honoring `horizontal_alignment`) and button rects. Row-internal rhythm (label hugging `-`/`+`) and whole-screen centering (row-level `SHRINK_CENTER`) are two layers, pinned separately.
- **Full-screen host discipline**: HUD hosts and full-rect hosts explicitly declare `mouse_filter`; all clickables `focus_mode = 0` (the changelog's two hard-won disciplines).
- **ProgressBar theme min-size clamp (probed)**: once a `ProgressBar` enters the scene tree, Godot raises `size.y` to its theme minimum (~22 px) - the authored 12 px survives only on the headless instantiate path (`tests/test_health_bar.gd`). The runtime empty-slot readability therefore rests on the cap width (10 px -> 220 px² at runtime).

## Testing

```bash
./run_tests.sh
```

Runs a compile check, a headless playtest against the `playtest/` contract (44 scenarios), then the Godot unit tests under `tests/`. A passing run requires a clean compile, zero runtime errors, `empty_round_stalls == 0`, and every assertion green (except the deliberately-red `terminal_victory_8_12_rounds_hp_15_40` difficulty window).

Additionally, the static pytest gate (`tests/test_playtest_contract_smoke.py`, standard-library only, no Godot) verifies the contract integrity: `scenario_order` ↔ scenario-file completeness, the round scenarios present on disk and ordered, the surface whitelist + `clicks:`-owner contract, `test_topbar_layout_surface_contract` (previous round's top-bar/creation observables), and **`test_creation_rework_and_bar_surface_contract`** (this round's `HealthBar.bar_height` / `empty_area_px` / `empty_cap_px` + the six `CreationScreen` leaf-ink vars).

## Verification Status

**Step 5 (Final Verifier) verdict - NOT YET DEPLOYABLE (downstream gates pending).**

The implementation is complete and integration-verified at the code level (per-component audit in `final/verify_report.json` `verified_subtasks`): the creation screen's row-level shrink-center layout, the six leaf-ink observables plus the ink-based `points_attrs_gap_ok` internals, the health-bar geometry trio (`bar_height` / `empty_area_px` / `empty_cap_px` observables included), the `test_health_bar` geometry sync, the append-only surface + in-place yaml extensions, and the new smoke-test function are all present and mutually consistent. Node identity is preserved (no renames/reparents on pinned paths; no new scenario files, so `scenario_order` / `ROUND_SCENARIOS` are untouched). **Pre-fix probe evidence is recorded** (`final/creation_probe_notes.md`, `final/health_bar_probe_notes.md`): every A-class observable was observed red on the un-fixed layout - including `attr_cluster_center_ok == false` @f30, the assertion that pins the "content split across the screen" defect.

**However, the objective gates run AFTER this step and their evidence does not exist yet:**

- Compile (`compile_report.json`): **not yet produced** - cannot confirm 0 errors.
- Playtest hard gate, 44 scenarios / 43-green baseline + the new asserts (`playtest_report.json` / `playtest_summary.md`): **not yet produced**. The implementer's delivery notes record a green chain, but per the constraints the authoritative source is the report files themselves.
- Vision gate six questions incl. Q5 native-size health-bar readability, 17/26 -> pass (`vision_report.json`): **not yet produced**.
- Unit tests / pytest incl. `test_creation_rework_and_bar_surface_contract` and the synced `test_health_bar` (`test_report.json`): **not yet produced**.

Per the no-guessing rule, `all_goals_met` and `ready_for_deploy` stay `false` until `5_review` judges those reports.

Do not ship until:

- the full 44-scenario playtest is green with the 43-green baseline preserved (only `terminal_victory` 5/6 red), the extended `creation_layout_readability` asserts green (13 old + 9 new), and the extended `ui_geometry_readability` asserts green (29 old + 3 new);
- `empty_round_stalls == 0` and runtime errors 0;
- pytest is green (including `test_creation_rework_and_bar_surface_contract`);
- the vision gate six questions all pass on **native 960×704 frames** (Q5 must show the health bar's filled + empty portions without zoom);
- the GDScript unit suite is green with the synced `test_health_bar` geometry (12/12).

## Recorded Debt

1. **`spine_to_ending` and `creation_budget_clamp_and_traits` walk a test-only path** (TUTORIAL WON -> TRANSITION -> CHARACTER_CREATION -> SECT_SELECTION) that no longer exists in the real flow. Follow-up: convert `creation_budget_clamp_and_traits` to a direct `creation.tscn` boot.
2. **Shell duplication**: `menu.tscn` duplicates `main.tscn`'s shell node block (forced by `main.tscn`'s byte-identity). Future shell edits must touch both.
3. **`has_save` is session-memory**; menu availability is file existence. Do not "fix" one by pointing at the other.
4. **Segment-2 穿越 narrative content is deferred** - roadmap stage-3 content.
5. **Unit-test gate wiring is deferred** - the Godot unit tests under `tests/` are still unwired into `run_tests.sh`; the static `test_playtest_contract_smoke.py` is the one genuine pytest signal in the meantime.
6. ~~Changelog gap~~ **Resolved**: `design/99_changelog.md` now carries both rounds' rows (`jinyong-layout` and `jinyong-layout-r2`, 2026-08-25).
