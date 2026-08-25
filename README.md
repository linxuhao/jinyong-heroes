# 华山论剑 (Huashan Sword Tournament)

A **Godot 4** single-player wuxia cultivation + turn-based tactics RPG. You boot into a **main menu** (mouse-first), create your own character **before** the tutorial, fight a keyboard-completable tutorial duel as the orchestrated Yang Guo, and then walk the six-segment line: **tutorial win → transition → sect selection → cultivation (36 months) → map → ending**.

> ⚠️ **Verification status: FAILED — not ready for deploy.** This round's primary deliverable (click-driven battle movement — left-click move / right-click undo / commit lock) does not work end-to-end: `click_move_to_tile` 1/10, `click_move_undo_right` 6/11, `click_move_commit_lock` 1/9. The vision gate also failed (Q5 health-bar readability, 20/28 battle scenarios). Passing: the focus-mode fix (`battle_focus_arrow_keys` 9/9) and the creation single-surface (`creation_single_ui` 16/16). See [Verification Status](#verification-status).

## What this round delivers — 点击驱动移动 (click-driven battle movement)

Playtesting reported two defects: (1) arrow keys "intermittently" stop moving the player in battle, and (2) the creation screen still shows two stacked operation surfaces (the keyboard `▶` cursor list *plus* the mouse button group). Both are fixed this round, plus battle movement is re-centered on the mouse:

1. **Focus-mode fix (the arrow-key death).** Every battle clickable — `EndTurnButton` / `AttackButton` / `PauseButton` in `scenes/ui/hud.tscn`, the root `SkillButton` in `scenes/ui/skill_button.tscn` (covers SkillButton1..12), and the tutorial-overlay buttons — now explicitly sets `focus_mode = 0` (FOCUS_NONE). A clicked button can no longer hold keyboard focus, so Godot's GUI focus navigation stops swallowing the `ui_up`/`ui_down` actions that `move_up`/`move_down` bind to, and the arrow key deterministically reaches `player._unhandled_input`. *(This is the same discipline the menu/settings/creation scenes already followed — the battle HUD was the one place that forgot.)*
2. **Left-click moves, right-click undoes.** `scripts/characters/player.gd` extends the proven `handle_world_click` convergence point: a left-click on a living enemy still attacks (enemy-first resolution preserved), but a left-click on an empty walkable tile now walks there via `_try_move_to` — resolved into a cardinal step sequence by the new pure planner `GridManager.plan_movement` and executed **one `_try_move` call per step** (the same budget/occupancy/身轻如燕 rules as the arrow keys — no forked movement logic). A right-click (`handle_world_right_click`) animates the unit back to the turn-start tile and refunds the budget.
3. **Trial → undo → commit (试走 → 反悔 → 出手即锁定).** `CombatManager.begin_turn` snapshots `turn_start_grid` / `turn_start_moves_left` / `turn_start_moved`; `player.undo_available` is recomputed every frame. A successful action (the engine sets `acted`) commits the movement — right-click undo is refused with 「已出手,无法退回」. **Commit blocks undo, not movement**: after acting you can still move (design `10_systems.md` §5.1 move+act order-free is pinned), only the undo affordance dies.
4. **Creation screen is one surface.** `scenes/segments/creation.tscn` drops the keyboard `▶` cursor text model (`BodyLabel` removed) and adds `PointsLabel` (剩余点数). The `MouseBox` button set is the **single** visible interaction surface; keyboard degrades to a pure shortcut layer acting on that surface (row focus + `±` / toggle / accept). `creation.gd` exposes `cursor_markers_visible` — a runtime scan that is `false` exactly when no `▶` marker renders — as the gate-judged proof the second surface is gone.
5. **Click-aware movement-range highlight.** `scripts/ui/move_range_highlight.gd` now expresses the "trying" state: `start_tile` (where right-click returns to) and `undo_available` are polled per frame and drawn as a bright edge marker that dims once the move is committed. The reachable-set hide condition is unchanged.

**Coverage:** 5 new scenarios appended to `playtest/_common.yaml` `scenario_order` (43 total): `battle_focus_arrow_keys`, `click_move_to_tile`, `click_move_undo_right`, `click_move_commit_lock`, `creation_single_ui`. The 38 pre-existing scenario files stay byte-identical; `_common.yaml` is append-only. The static pytest contract (`tests/test_playtest_contract_smoke.py`) now also pins the new surface observables and the offset `clicks:` targets.

## Quick Start

1. Open the project in **Godot 4.4+** (`project.godot` `config/features` records `4.7`).
2. Run the import/compile pass so Godot produces `.import` sidecars (the harness `--compile` step does this; in the editor it happens on open).
3. Press **F5** (or *Run Project*). The game boots into the **main menu**.
4. Click **新的冒险** (or arrow + Enter to navigate), create your character with the mouse (a single button-driven surface), then confirm to enter the tutorial.

## How to Play

| Action | Input |
|--------|-------|
| Menu / settings navigation | Arrow keys + **Enter** — or **click** the entry |
| Creation attribute / trait / phase | Click the ±/toggle/nav buttons — keyboard is a shortcut on the same surface |
| Move (primary) | **Left-click** an empty highlighted tile; the player walks there |
| Undo this turn's movement | **Right-click** — returns to the turn-start tile and refunds the budget (refused after you act) |
| Move (shortcut) | WASD / Arrow keys (one tile per press, 4-tile budget) |
| Select technique | **1–8** (9–12 with 左右互搏; or click the HUD skill buttons) |
| Execute technique / basic attack | **J** (`attack_confirm`) or click **出招 (J)**; left-click an enemy targets the same way |
| End turn | **Space** or click **结束回合** |
| Advance tutorial | Enter / Space |
| Pause / unpause | Escape or click **Pause** |

- Every turn = move up to your movement range **plus** one action, in any order. The green highlight shows every tile you can still reach.
- Left-click an enemy tile attacks; left-click an empty walkable tile moves; left-click your own tile is a no-op; clicking an unreachable tile says 走不到那里.
- Once you act (attack / skill / item), the turn's movement is committed — right-click undo is refused (已出手,无法退回). Ending the turn commits too.
- Press `J` (or click 出招) with no skill selected to basic-attack the **nearest adjacent** enemy.
- Select a skill with `1`–`8` (or `9`–`12`), then press `J` to fire it; `SkillDescLabel` shows the skill's Chinese description, the hint line tells you the next step, and the grid highlight shows reachable + target tiles.
- **Two-phase unlock** (tutorial only): techniques `5`–`8` (Melancholy Palms) lock until **round 4**; technique `8` requires HP **below 50%**. A rejected selection says why instead of doing nothing.
- Each unit acts once per round in initiative order: Yang Guo (88) → East Heretic (85) → Central Divine (80) → South Emperor (76) → North Beggar (74) → West Poison (70).
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
MENU ──读取存档──▶ load_slot(1) ok & segment ∈ STABLE_STATES → direct state set (bypasses SEGMENT_PREDECESSORS)
```

The whole game runs inside one persistent shell: `SceneManager` (an autoload) listens to `GameManager.state_changed` and swaps exactly one active scene under the shell's `SceneHost` (Node2D for the battlefield) or `SegmentHost` (full-rect Control for segment scenes). `GameManager.current_state` is the playtest-visible FSM state.

**Two shell scenes exist.** `scenes/menu.tscn` is the real launch entry (a shell-identical copy of `main.tscn` plus an authored `MenuPanel`); its panel's `_ready` claims the boot before SceneManager's deferred default battlefield swap. `scenes/main.tscn` is untouched and still boots the legacy flow — that is what keeps all pre-existing scenarios frame-identical. **No headless/env-var/`--skip-menu` branching exists anywhere**.

| Segment | Scene | What happens |
|---|---|---|
| 0. Creation | `creation` | 30-point attribute buy (tiered pricing, 10–20) + trait/flaw toggles + per-phase Back/Next buttons — one mouse-driven button surface (keyboard is a shortcut) |
| 1. Tutorial | `battlefield` | Yang Guo vs the Five Greats (keyboard-completable tutorial) |
| 2. Transition | `transition` | Full-screen Chinese text pages → next segment |
| 3. Sect select | `sect_select` | Pick one of five sects → its 丁 internal + 丁 external gongfa |
| 4. Cultivation | `cultivation` | 36 monthly cycles: card draws + 练功/修习/做工/游历 + year-end stay/switch + 存盘/读档/删档 |
| 5. Map / ending | `map` → `ending` | Node-graph map (adjacency-checked moves) → tiered ending text |

## Main Menu & Settings

**Menu entries** (single activation path — mouse `pressed`, keyboard `ui_accept`, and the harness `debug_click_menu_entry` action all converge on `_activate_entry(i)`): 0 新的冒险 / 1 读取存档 / 2 设置 / 3 退出.

**Load availability is file existence** (`SaveManager.has_save_file(1)`), never session-memory `has_save`. **Settings screen** (音效音量 / 音乐音量 / 全屏 / 返回): volumes step ±3 dB clamped to [−40, +6] dB, persisted via `SettingsManager` → `user://settings.cfg`; fullscreen is applied only when not headless.

## Save / Load

Saves live at `user://save_<slot>.json` (plain JSON, 3 slots, versioned schema, atomic `.tmp` → validate → `.bak` rollback → promote → re-validate → drop backup). The save carries the RNG seed + `rng_state` + the per-category deck lists, so a reload replays the identical card sequence. `STABLE_STATES` is `["CULTIVATION", "MAP"]`.

> Root cause of the long-broken 存档链 (measured 2026-08-24, not inferred): writes never failed — `JSON.parse_string()` parses every number as **float**, and `_apply_save_dict()`'s `is int` gate rejected the just-written file, mislabeled `io_error` even though `FileAccess.get_open_error()` returned OK. Second, `month == 4` on load was a **write being clobbered** (cultivation autosaves *after* advancing the month), not a read failure. Fixed: the step-2/step-5 validate paths re-validate correctly, `rng.state` stores as String (64-bit int exceeds 2^53 float precision), and all six `io_error` sites latch `last_io_error_code`/`last_io_error_text`.

## Chinese Font Theme

The whole UI ships in Chinese under one global font theme: `assets/themes/global_theme.tres` (Noto Sans SC via res:// path, `default_font_size = 12`), wired through `ProjectSettings gui/theme/custom` + `ThemeManager` fallback. **No per-node font overrides.** Display layer only — `character_name`, node names, skill ids, state strings and turn-order names stay canonical English.

## The Five Grandmasters (deterministic AI)

Each enemy is driven by a distinct AI controller (`scripts/ai/*.gd`) that decides **once per enemy turn** via a deterministic priority list — no timers, no RNG: West Poison (poison/reflect), North Beggar (brawler/−15% damage taken), East Heretic (ranged seals/counter), South Emperor (ranged healer/regen), Central Divine (shield/dispel, survives the first fatal blow at 1 HP via 先天罡气).

## Turn System

- **Round snapshot**: living units sorted by effective initiative descending (decorate-sort-undecorate insertion sort for determinism).
- **Turn-start lifecycle** (exact order): cooldown decrement (int rounds) → DoT/status ticks → constant regen → the unit acts.
- **Trial / undo / commit** (new this round): `begin_turn` records `turn_start_grid` / `turn_start_moves_left` / `turn_start_moved`; a right-click restores them (animated). `acted == true` (set only on successful execution) or end-turn commits the movement — after that, right-click undo is refused but further movement is still allowed.
- **Damage pipeline**: attack side `round(base × buffs × fa_hui_du)` → defense side `round(output × (1 − DR))`. 发挥度 applies to damage/heal/shield/DoT-tick values only — never cooldown, range, knockback, or duration; percentages never take the multiplier.
- **Melee vs ranged**: decided by the declaring external art's **weapon class**, never by shape/reach/damage.
- **Pause** is a boolean gate (no `Engine.time_scale`).

## 功法 (Gongfa) Data Structure

`scripts/data/gongfa_data.gd` models internal/external martial arts. Every art exposes `get_fa_hui_du(unit)` — the real 甲乙丙丁 prerequisite cascade, interval 0.6~1.3 (missing prereq count → base [1.0, 0.85, 0.7, 0.6], then +0.1 × same-attribute mastered arts up to 3). The tutorial's protected 1.3 comes out of this same cascade via `TutorialFillers.fill()`. The progression ladder registers 5 sects × (internal+external) × 丁丙乙 plus the hand-authored 甲 pool; `TraitEffects.practice_gain(wisdom, roll)` maps the 悟性-tier 修习 lookup table.

## Encounter Battles

`GameManager.start_encounter()` (distinct from tutorial-gated `start_battle()`) sets `battle_return_state = "CULTIVATION"`, builds the player from `SaveManager.profile`, spawns a deterministic sparring partner, and skips the tutorial overlay. `request_retry()` / `request_continue()` route LOST/WON back to `battle_return_state`.

## Trait Effects

Pure static math lives in `scripts/data/trait_effects.gd`; engine hooks live in `CombatManager` / `player.gd` / `battlefield.gd`. 杀 heals 20% of HP loss (capped 15% max/round); 破 gives gongfa practice ×1.5; 狼 gives attack ×(1+0.08×living) and DR 0.05×living; 铁布衫 survives the first lethal blow at 1 HP; 身轻如燕 slides through an enemy tile (cost 2); 左右互搏 raises the equipment cap to 3 external arts (12-slot bar). Each trait now also carries a `description` (Chinese 机制 文案) rendered by `TraitDescLabel`.

## HUD

- **Grid overlay** (`GridLines`): 1 px semi-transparent cell boundaries across the 15×11 board plus a border ring.
- **Movement-range highlight** (`MoveRangeHighlight`): green BFS mirror of `_try_move`; observables `visible` / `tile_count` / `fill_color` plus the new `start_tile` / `undo_available` trying-state markers.
- **Range/target highlight** (`RangeHighlight`): blue reachable tiles + red valid targets, mirroring `player.can_skill_hit()`; `fill_color` observable added for the green-vs-blue distinctness assert.
- **Action hint line** (`ActionHintLabel`): shows 按 J 出招 / 点击目标 after a selection and a specific Chinese reason on every rejection.
- **Skill description label** (`SkillDescLabel`): always-visible; default guidance → selected skill's Chinese description.
- **Battle action buttons**: `EndTurnButton` (结束回合) + `AttackButton` (出招 (J)) in the top-right column under `PauseButton`, gate-guarded and disabled off-turn; geometry observables `hud_button_overlap` / `hud_desc_overlap` assert they never overlap existing HUD widgets. **All battle clickables are `focus_mode = 0`** (no battle Control can ever hold keyboard focus and eat the arrow keys).
- **Skill bar**: up to 12 `SkillButton` nodes (default 2 arts / 8 slots; 左右互搏 = 3 arts / 12). Each shows name, hotkey, 发挥 ×N.N, and a cooldown/state overlay.
- **Health bars** (`HealthBar`): 64 px wide, name label above, green→yellow→red by HP fraction.
- **Round indicator**: 回合 N, 行动: <name> · 移动 <m>, 顺序: <Chinese names>.

## Project Structure

```
├── project.godot                 # Engine config, autoloads, input map, theme, run/main_scene -> menu.tscn
├── playtest/                     # Headless playtest contract, one file per scenario (43)
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
└── tests/                        # test_*.gd + unit_test_runner.gd (unwired this round) + test_playtest_contract_smoke.py
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager`, `SaveManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`, `ThemeManager`, `SettingsManager`, `SceneManager` (kept **last**).

### Input actions (`project.godot` `[input]`)

`move_up/down/left/right`, `skill_1`..`skill_12`, `attack_confirm` (J), `end_turn` (Space), `pause_game` (Escape), `tutorial_next` (Enter), plus the harness-only DEBUG actions (`debug_fast_forward` / `debug_win_tutorial` / `debug_lose_tutorial` / `debug_step_month` / `debug_grant_art` / `debug_enter_encounter` / `debug_poison_player` / `debug_damage_player` / `debug_click_menu_entry` / `debug_click_creation_widget` / `debug_seed_save` / `debug_delete_save` / `debug_reset_settings`).

> **Naming caveat:** `basic_attack` exists as two different strings — the input action was renamed to `attack_confirm`; the engine action string `"basic_attack"` (AI decisions + `CombatManager.execute_action`) is unchanged.

### Mouse clicks (harness-verified)

The playtest harness posts **real** `InputEventMouseButton` events. The `clicks:` spec is `"<Node>[ +dx,dy][ left|right|middle]"`: `Central_Divine_ClickTarget` = left-click that node's screen center; `Player +64,0` = left-click one tile right of the player (TILE_SIZE = 64); `Player +0,0 right` = right-click the player's own tile. Click coordinates are converted in the handler via `get_canvas_transform().affine_inverse() * event.position` (never the viewport-cached `get_global_mouse_position()`). World clicks on tiles must go through `_input` relays (Godot's GUI picker does not route to Controls under Node2D ancestors).

### `GameManager` public API

`get_state()`, `start_battle()` (tutorial-gated), `start_encounter()`, `end_battle(won)`, `request_continue`/`request_retry`, `restart_game()`, `clear_battle()`, `release_stale_units()`, `enter_segment(state)`, and the menu surface `enter_menu()` / `menu_new_adventure()` / `menu_open_settings()` / `menu_close_settings()` / `menu_load_game()` / `menu_quit()` / `finish_creation()`.

### `SaveManager` public API

`save_slot(s)` / `load_slot(s)` / `autosave()` / `delete_slot(s)`, `has_save_file(s)`, `ensure_user_dir()`, `new_profile(attrs, traits)`, `apply_seed(seed)`, `draw_cards(monthly)`; surface vars `seed`, `last_error`, `slot`, `has_save`, deck counts, roundtrip observables, and `last_io_error_code` / `last_io_error_text` / `debug_user_dir_exists`. Signal: `loaded(slot)`.

### New playtest surface (this round, append-only in `_common.yaml`)

`Player.turn_start_grid` / `turn_start_moves_left` / `turn_start_moved` / `undo_available`; `MoveRangeHighlight.start_tile` / `undo_available`; `CreationScreen.cursor_markers_visible`; `PointsLabel.visible` / `text`; `focus_mode` on `EndTurnButton` / `AttackButton` / `PauseButton` / `SkillButton1` (representative — all 12 skill buttons share the instanced scene).

## Technical Notes

- **Godot version**: targets 4.4; `config/features` records `4.7` — pre-existing, compiles/runs under the current toolchain.
- **Stable initiative sort**: decorate-sort-undecorate with a registration-index tie-break.
- **Freed-object safety**: `is_instance_valid()` before every `as` cast / typed assignment; scene swaps await the outgoing scene's `tree_exited`.
- **Tween safety**: `_await_tween_safe()` caps every action tween at 0.25 s.
- **Deterministic AI**: zero RNG — pure priority lists.
- **Seeded RNG**: one `RandomNumberGenerator` owned by `SaveManager`, seeded from `mix_seed(system_entropy)` (splitmix64 finalizer — frozen).
- **Rounding**: `round()` half away from zero; `45 * 1.3` = 58.5 → 59. Percentages never take the fhd multiplier.
- **Highlight layering**: `RangeHighlight` and `MoveRangeHighlight` sit between `GridLines` and `Characters`; translucent fills (alpha ≤ 0.28) keep grid lines readable.
- **Movement path planning**: `GridManager.plan_movement(from, budget, slide_ok)` is a pure relaxation BFS under the exact `_try_move` cost model (walkable + unoccupied landing at cost 1, 身轻如燕 slide-through at cost 2). Click-move drains the returned step list one `_try_move` call per step, so budget bookkeeping is byte-identical to the keyboard path.

## Testing

```bash
./run_tests.sh
```

Runs a compile check, a headless playtest against the `playtest/` contract (43 scenarios), then the Godot unit tests under `tests/`. A passing run requires a clean compile, zero runtime errors, `empty_round_stalls == 0`, and every assertion green (except the deliberately-red `terminal_victory_8_12_rounds_hp_15_40` difficulty window).

Additionally, the static pytest gate (`tests/test_playtest_contract_smoke.py`, standard-library only, no Godot) verifies the contract integrity: `scenario_order` ↔ scenario-file completeness, the 5 round scenarios present on disk and ordered, and the surface whitelist + `clicks:`-owner contract for both the click-targeting and click-move rounds.

## Verification Status

**Step 5 (Final Verifier) verdict — FAILED (not ready for deploy).**

Downstream gate evidence is now available (`5_review`) and it contradicts the implementation-level claim that click-driven movement works end-to-end. The round's PRIMARY deliverable is non-functional.

**Gate results:**

- Compile: **passed** (0 errors).
- Pytest contract (`tests/test_playtest_contract_smoke.py`): **passed** (5 passed).
- Playtest runtime hard gate: **passed** (no crash / scene-load / illegal-spec-key / input_dead; runtime errors 0).
- Vision gate: **FAILED** — `vision_report.json` `passed: false`; Q5 (health bars recognisable, `design/30_presentation.md` 可读性硬要求 #4) answered NO in 20/28 battle scenarios.

**Behavioral assertions (the decisive ones):**

- `battle_focus_arrow_keys` 9/9 ✅ — focus-mode fix verified (click a button, then an arrow key still moves the player).
- `creation_single_ui` 16/16 ✅ — creation is a single surface (`cursor_markers_visible == false`).
- `click_targeting_fixed` 2/2 ✅ — node-targeted click-attack still works.
- `click_move_to_tile` 1/10 ❌ — `Player.debug_click_events` stays 0; the `Player +dx,dy` left-click never reaches the handler; `grid_pos` stays `(7,5)`, `moves_left` stays 4.
- `click_move_undo_right` 6/11 ❌ — `grid_pos` never changes from `(7,5)`.
- `click_move_commit_lock` 1/9 ❌ — `acted` never true; `Central_Divine.health` stays 130.

**Root-cause hypothesis (must be confirmed and fixed):** player-anchored offset clicks (`Player +64,0` / `Player +0,-192`) fail while node-targeted clicks (`Central_Divine_ClickTarget`) succeed — the offset addressing / canvas-transform conversion for Player-anchored targets, or the click-move handler itself, is broken.

`final/verify_report.json` records `all_goals_met: false` / `ready_for_deploy: false`. Do not ship until:

- the three click-move scenarios (`click_move_to_tile` / `click_move_undo_right` / `click_move_commit_lock`) are green,
- the vision Q5 health-bar failure is fixed or explicitly dispositioned and `5_vision` is re-run to a parseable `passed: true`,
- the full 43-scenario playtest is re-run with the 37-green baseline preserved plus all 5 new scenarios green (only `terminal_victory` 5/6 red), `empty_round_stalls == 0`, runtime errors 0.

## Recorded Debt

1. **`spine_to_ending` and `creation_budget_clamp_and_traits` walk a test-only path** (TUTORIAL WON → TRANSITION → CHARACTER_CREATION → SECT_SELECTION) that no longer exists in the real flow. Follow-up: convert `creation_budget_clamp_and_traits` to a direct `creation.tscn` boot.
2. **Shell duplication**: `menu.tscn` duplicates `main.tscn`'s shell node block (forced by `main.tscn`'s byte-identity). Future shell edits must touch both.
3. **`has_save` is session-memory**; menu availability is file existence. Do not "fix" one by pointing at the other.
4. **Segment-2 穿越 narrative content is deferred** — roadmap stage-3 content.
5. **Unit-test gate reports `no_tests_collected`** — the Godot unit tests under `tests/` are unwired; that is NOT a pass signal. `5_test` currently reports `passed: true` on `no_tests_collected: true` — treat that as skipped/unrun, never as a pass. Wiring is deferred to a separate round (the static `test_playtest_contract_smoke.py` is the one genuine pytest signal in the meantime).
