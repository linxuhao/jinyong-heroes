# 华山论剑 (Huashan Sword Tournament)

A **Godot 4** single-player wuxia cultivation + turn-based tactics RPG. You boot into a **main menu** (mouse-first), create your own character **before** the tutorial, fight a keyboard-completable tutorial duel as the orchestrated Yang Guo, and then walk the six-segment line: **tutorial win -> transition -> sect selection -> cultivation (36 months) -> map -> ending**.

> ⚠️ **Verification status: NOT deployable - the vision gate produced no green verdict.** The three jinyong-events deliverables (the eight-layer portrait-visibility predicate + the 92 px clamp fix, the 16-row travel-event pool, the no-repeat bag observable + its new scenario) are landed and wired end-to-end with a measured pre-fix probe record (`final/portrait_cover_probe_notes.md`). The downstream gates have now run (as read by the `5_review` verdict from the gate reports): compile clean, pytest 10 passed, playtest hard gate passed with 46/47 green (only the deliberately-red `terminal_victory`), `portrait_visibility` 22/22, `event_travel_effects` 19/19 - **but the vision gate did not judge: it produced no green verdict (4/47 scenarios judged, all full-HP battle frames, zero injured frames)**, and no green vision re-run exists. Q5 is the single blocking item. See [Verification Status](#verification-status).

## What this round delivers - 事件从 4 条到 16 条 + 立绘可见性判据补洞 (jinyong-events)

This round adds **no new mechanics, no new effect types, no number changes, no map/topology/art changes** - it is content + closing two measured holes in the visibility predicate:

1. **Portrait-visibility predicate 6 -> 8 layers (`VisibilityProbe`).** `scripts/ui/visibility_probe.gd` gains `blank_texture` (asset-level alpha scan - a fully transparent resource renders nothing no matter how correct the geometry is; fail-open when the scan is unavailable) and `covered` (partial occlusion: a later-drawn opaque host hiding ≥ 25% of the ink rect, ≥ 64 px² absolute, max-single-coverer semantics) plus the public `covered_fraction()` helper. Every battle unit (`Player`, `East_Heretic`, `West_Poison`, `South_Emperor`, `North_Beggar`, `Central_Divine`) publishes **per frame**: `portrait_visible`, `portrait_fail_layer` (8 possible ids), `portrait_covered_frac`, and the **3-number probe** `portrait_sprite_pos` + `portrait_tex_size` + `portrait_bar_pos`.
   - **Measured pre-fix (f40, native 960×704, `final/portrait_cover_probe_notes.md`):** exactly one unit RED - **Central_Divine (王重阳)**: `portrait_visible=false`, `fail_layer="covered"`, `covered_frac=0.333333333333333`, `sprite_top=0.0` (the old `occluded` layer, full-enclosure-only, could never fire here - this is the partial-occlusion hole closing). **Player (杨过)** measured GREEN with internally consistent 3-number geometry (`sprite_pos [480,352]` + `tex_size [96,128]` + `bar_pos [446,320]` -> ink x∈[432,528], y∈[224,352], mid-board) - the earlier "nothing drawn there" reading was a human frame-reading artifact, dispositioned `frame-reading divergence, no fix` per the no-guess rule.
   - **The fix, only where the probe pointed:** `GridManager.clamp_sprite_offset`'s y lower bound gains the presentation constant `BOARD_TOP_MARGIN_Y = 92` (the existing top-strip bottom) so top-row portrait ink starts below the strip. One constant + one line; grid positions, movement, click-targeting and health-bar geometry untouched.
   - `design/40_ux_backlog.md`: **UX-01a CLOSED(jinyong-events) - 实测无缺陷**; **UX-01b CLOSED(jinyong-events)** - closure from the post-fix gate evidence (`playtest_summary.md`: `portrait_visibility` 22/22 green incl. `Central_Divine.portrait_covered_frac < 0.25`, read by the `5_review` verdict; backlog rule 2: closure is an action from evidence, not an inference).
2. **Travel-event pool 4 -> 16 (`EventData.TABLE`).** Twelve new hand-written Jin Yong-flavored rows (古墓寒玉 / 神雕负伤 / 桃花迷阵 / 蛇胆奇效 / 降龙残谱 / 渡口风波 / 镖行招募 / 大理市集 / 破庙夜雨 / 赌坊喧嚣 / 全真抄经 / 遗落的褡裢) join the four baseline rows. Every option uses **only the 5 implemented effect types** (`silver` / `attr` / `item` / `practice` / `none`), `attr` targets only the five attribute keys, `item` targets only real equipment ids (`eq_sword_2` / `eq_armor_2` / `eq_boots_2` - distinct per row, distinct from the baseline `eq_sword_3`), and each row's two options are real trade-offs (item-with-cost, item-vs-item, item-vs-attr, paid-vs-free attr, growth-vs-money, moral fortune-vs-silver - no two rows interchangeable). Pure data: resolution stays in `cultivation.gd` untouched.
3. **No-repeat bag made observable and provable.** `_draw_event()` already excluded `events_seen` and reset on pool exhaustion (never an empty draw, never a stall); this round adds the observable `CultivationScreen.events_seen_count`, the new scenario **`playtest/event_travel_effects.yaml`** (count ladder 0 -> 1 -> 2 -> 3 across three resolved 游历 travels, `event_id != ""` throughout, drawn ids deliberately never asserted - RNG-dependent), and deterministic GDScript unit tests (15-of-16 forced draw, all-16 pool reset, 32 fresh + 16 adversary effects-land cases). Scenarios **46 -> 47**.

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
- Once you act (attack / skill / item), the turn's movement is committed - right-click undo is refused (已出手，无法退回). Ending the turn commits too.
- Press `J` (or click 出招) with no skill selected to basic-attack the **nearest adjacent** enemy.
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

## Travel Events (游历) - the 16-row pool

Choosing **游历** in a cultivation month draws one event from `EventData.TABLE` (16 rows) and presents a **two-option real trade-off**. Resolution is entirely in `cultivation.gd`:

- **Effect vocabulary (hard contract, 5 types only):** `silver` (clamped at 0), `attr` (target ∈ bone/inner/agility/wisdom/fortune), `item` (target must be a real equipment id; dedup'd - already-owned grants no-op), `practice` (adds to the first unmastered gongfa; no-op when everything is mastered), `none`. Anything else would silently no-op = dead content, so `tests/test_event_data.gd::_test_effect_targets` pins the whitelists statically and `tests/test_cultivation.gd` proves all 48 option cases actually mutate profile state (fresh + adversary worst-case).
- **No-repeat bag:** `_draw_event()` builds the pool of TABLE ids **not** in `SaveManager.profile.flags["events_seen"]`; when the pool empties it clears the seen list and refills - a clean cycle restart, never an empty event, never a stall. Exactly **one `SaveManager.rng.randi_range` per travel** (RNG op order unchanged).
- **Observables:** `CultivationScreen.events_seen_count` (the sanitized bag size - grows by 1 per resolved 游历, drops to 0 on pool exhaustion) and `CultivationScreen.event_id` (the currently drawn event). Pinned by `playtest/event_travel_effects.yaml`'s count ladder.

## Portrait Visibility Probe (八层判据)

`scripts/ui/visibility_probe.gd` turns "the unit's portrait puts ink on the rendered 960×704 frame" into a decidable fact. Pure static functions - one predicate serves the probe matrix, the A-class red-before-fix assertions and the B-class regression guards. Layer order is cheap-to-expensive:

1. `hidden_in_tree` - the leaf's full visible chain is broken
2. `null_texture` - Sprite2D/TextureRect texture null or zero-sized
3. `blank_texture` - the texture resource has no pixel with alpha > 0 (asset-level scan, cached; fail-open when the scan is unavailable)
4. `zero_rect` - zero area / zero scale / near-transparent alpha chain
5. `off_viewport` - the ink rect does not intersect the viewport rect
6. `clipped` - a `clip_contents` ancestor does not enclose the ink rect
7. `occluded` - a later-drawn, mouse-visible Control **fully** covers it
8. `covered` - a later-drawn, mouse-visible Control covers **≥ 25%** (and ≥ 64 px²) of the ink rect (max-single-coverer; `occluded` is checked first so full enclosure keeps the precise id)

Every unit publishes `portrait_visible` / `portrait_fail_layer` / `portrait_covered_frac` / `portrait_sprite_pos` / `portrait_tex_size` / `portrait_bar_pos` per frame (the last three are the **3-number probe** - sprite `global_position` + texture size + health-bar `global_position` - the only sanctioned way to resolve a "numbers say it's there, frame says it isn't" contradiction, never pixel inference). The `covered` layer unlocked this round's single gated clamp fix: `GridManager.clamp_sprite_offset` keeps top-row ink below the 0..92 top strip (`BOARD_TOP_MARGIN_Y = 92`).

## Main Menu & Settings

**Menu entries** (single activation path - mouse `pressed`, keyboard `ui_accept`, and the harness `debug_click_menu_entry` action all converge on `_activate_entry(i)`): 0 新的冒险 / 1 读取存档 / 2 设置 / 3 退出.

**Load availability is file existence** (`SaveManager.has_save_file(1)`), never session-memory `has_save`. **Settings screen** (音效音量 / 音乐音量 / 全屏 / 返回): volumes step ±3 dB clamped to [−40, +6] dB, persisted via `SettingsManager` -> `user://settings.cfg`; fullscreen is applied only when not headless.

## Save / Load

Saves live at `user://save_<slot>.json` (plain JSON, 3 slots, versioned schema, atomic `.tmp` -> validate -> `.bak` rollback -> promote -> re-validate -> drop backup). The save carries the RNG seed + `rng_state` + the per-category deck lists, so a reload replays the identical card sequence. `events_seen` rides in `flags` (sanitized to non-empty Strings on load; old 4-row-era saves simply draw from the 16-row pool). `STABLE_STATES` is `["CULTIVATION", "MAP"]`.

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

- **Top strip** (`TopStrip`): full-width 0..92px semi-transparent dark `StyleBoxFlat` band (`mouse_filter = 2`, drawn behind everything) hosting 回合数 / 行动条 / 出手顺序 / 技能提示 / 内力, pairwise non-overlapping. `PauseButton` stays top-right on the band; `EndTurnButton` / `AttackButton` / `SkillDescLabel` sit below it.
- **Grid overlay** (`GridLines`): 1 px semi-transparent cell boundaries across the 15×11 board plus a border ring.
- **Movement-range highlight** (`MoveRangeHighlight`): green BFS mirror of `_try_move`; observables `visible` / `tile_count` / `fill_color` plus `start_tile` / `undo_available` trying-state markers.
- **Range/target highlight** (`RangeHighlight`): blue reachable tiles + red valid targets, mirroring `player.can_skill_hit()`; `fill_color` observable for the green-vs-blue distinctness assert.
- **Action hint line** (`ActionHintLabel`): shows 按 J 出招 / 点击目标 after a selection and a specific Chinese reason on every rejection. Lives inside the top strip.
- **Move-target affordance** (`MoveHintLabel`): state-following Chinese copy below the player's feet (左键点格移动 · 右键退回 -> 右键退回起点 · 出手即确认 -> 已出手 · 移动已确认), `mouse_filter = 2` so it never eats click-move / undo / targeting.
- **Skill description label** (`SkillDescLabel`): always-visible; default guidance -> selected skill's Chinese description.
- **Battle action buttons**: `EndTurnButton` (结束回合) + `AttackButton` (出招 (J)) in the top-right column under `PauseButton`, gate-guarded and disabled off-turn. **All battle clickables are `focus_mode = 0`**.
- **Skill bar**: up to 12 `SkillButton` nodes (default 2 arts / 8 slots; 左右互搏 = 3 arts / 12). Each shows name, hotkey, 发挥 ×N.N, and a cooldown/state overlay.
- **Health bars** (`HealthBar`): 64 px wide, **12 px tall bar** (68×24 widget; the battle scene's theme min-size makes the runtime bar render ~22 px tall), name label above (semi-transparent backing), green->yellow->red by HP fraction, **fixed 10 px empty cap** and **6 px track halo** so the empty slot reads at the native 960×704 size; floating bars clamp **below the top strip** (`top ≥ 94`) with an 8 px hover gap above the character's feet.
- **Portrait sprites**: top-row ink is clamped below the top strip (`GridManager.clamp_sprite_offset`, `BOARD_TOP_MARGIN_Y = 92` - this round's gated fix), and every unit's portrait is probe-observable per frame (see [Portrait Visibility Probe](#portrait-visibility-probe-八层判据)).
- **Round indicator**: 回合 N, 行动: <name> · 移动 <m>, 顺序: <Chinese names>.

## Project Structure

```
├── project.godot                 # Engine config, autoloads, input map, theme, run/main_scene -> menu.tscn
├── playtest/                     # Headless playtest contract, one file per scenario (47)
│   ├── _common.yaml              #   shared scene / actions / surface + scenario_order
│   └── <scenario>.yaml           #   basename == name:  (incl. event_travel_effects.yaml, this round)
├── run_tests.sh                  # CLI gate: compile + headless playtest + GDScript unit suite
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
│   ├── characters/ (player.gd, enemy.gd)          # both publish the 6 portrait-probe vars per frame
│   ├── ai/ (ai_base + 5 Grandmaster controllers + ai_sparring)
│   ├── data/ (character_data, skill_data, gongfa_data, player_profile, trait_data, trait_effects,
│   │          tutorial_fillers, encounter_data, progression_gongfa_data, card_data,
│   │          event_data (16-row travel-event pool), map_data, battle_setup)
│   ├── segments/ (creation, transition, sect_select, cultivation, map, ending)
│   └── ui/ (menu_panel, settings_panel, hud, health_bar, skill_button, round_indicator,
│             pause_button, tutorial_step, range_highlight, move_range_highlight,
│             move_hint_label, visibility_probe)
├── final/                        # probe notes + delivery notes + verify_report.json
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

### `VisibilityProbe` static API (this round)

`first_fail_layer(unit_root) -> String` ("" = visible; else one of the 8 layer ids), `portrait_visible(unit_root) -> bool`, `covered_fraction(unit_root) -> float` (worst single later-drawn opaque-host cover fraction, [0,1]), `leaf_rect(unit_root) -> Rect2`; constants `COVERED_AREA_FRAC = 0.25`, `COVERED_MIN_PX = 64.0`.

### `EventData` static API (this round)

`all() -> Array[EventDef]` (fresh instances, table order), `def(id) -> EventDef` (null when unknown). `EventDef` = `{id, title, text, option_a, option_b}`; `EventOption` = `{label, effects: Array[Dictionary], battle_id: null}`; each effect = `{"type": silver|attr|item|practice|none, "value": int, "target": String}`.

### Playtest surface observables

**Portrait-probe observables (all six battle units, this round)** - `portrait_visible` / `portrait_fail_layer` / `portrait_covered_frac` / `portrait_sprite_pos` / `portrait_tex_size` / `portrait_bar_pos`. **Cultivation event observables (this round)** - `CultivationScreen.events_seen_count` / `event_id`. **Battle top-bar observables** - `HUD.top_text_pairwise_overlap` / `top_text_in_strip` / `top_strip_alpha` / `hint_hpbar_overlap` / `hpbar_strip_overlap`; `TopStrip.visible` / `size`; `HealthBar.name_backing_alpha`. **Creation observables** - `CreationScreen.attr_rows_uniform` / `attr_label_alignment_ok` / `points_attrs_gap_ok` / `phase_skeleton_same` / `creation_in_viewport` / `creation_box_fits` plus the leaf-ink cluster vars (`attr_cluster_center_ok` / `attr_cluster_width_ok` / `nav_cluster_center_ok` / `trait_cluster_center_ok` / `desc_center_ok` / `desc_alignment_ok`). **Health-bar readability** - `HealthBar.bar_height` / `empty_area_px` / `empty_cap_px`. (Plus the prior rounds' `Player.turn_start_*` / `undo_available`, `MoveRangeHighlight.start_tile` / `undo_available`, `MoveHintLabel.state` / `text` / `visible`, `CreationScreen.cursor_markers_visible`, and `focus_mode` on the battle buttons.)

## Technical Notes

- **Godot version**: targets 4.4; `config/features` records `4.7` - pre-existing, compiles/runs under the current toolchain.
- **Stable initiative sort**: decorate-sort-undecorate with a registration-index tie-break.
- **Freed-object safety**: `is_instance_valid()` before every `as` cast / typed assignment; scene swaps await the outgoing scene's `tree_exited`.
- **Tween safety**: `_await_tween_safe()` caps every action tween at 0.25 s.
- **Deterministic AI**: zero RNG - pure priority lists.
- **Seeded RNG**: one `RandomNumberGenerator` owned by `SaveManager`, seeded from `mix_seed(system_entropy)` (splitmix64 finalizer - frozen). The travel-event draw consumes exactly one `randi_range` per 游历, so the seeded stream's op order is unchanged by the 4 -> 16 pool growth.
- **Rounding**: `round()` half away from zero; `45 * 1.3` = 58.5 -> 59. Percentages never take the fhd multiplier.
- **Highlight layering**: `RangeHighlight` and `MoveRangeHighlight` sit between `GridLines` and `Characters`; translucent fills (alpha ≤ 0.28) keep grid lines readable.
- **Movement path planning**: `GridManager.plan_movement(from, budget, slide_ok)` is a pure relaxation BFS under the exact `_try_move` cost model (walkable + unoccupied landing at cost 1, 身轻如燕 slide-through at cost 2).
- **Overlap convention**: a pair "overlaps" iff the two rects intersect after each is inset 1px on all sides (`_inset_overlap`); hidden widgets are skipped, never asserted; all battle rects share the layer-10 scale-1 coordinate space.
- **Ink, not slots**: a Container's `get_global_rect()` measures the *slot*, not the *ink*. Position observables measure what actually draws: label **text** sub-rects via `Font.get_string_size`, button rects, and (for portraits) the sprite's canvas-space transformed texture AABB (`VisibilityProbe._sprite_global_rect`).
- **Opaque-host convention**: a Control counts as a potential occluder/coverer iff `mouse_filter != MOUSE_FILTER_IGNORE` and it draws after the ink leaf (CanvasLayer -> effective z -> tree order). A unit's own subtree (its Sprite, its invisible ClickTarget) never counts.
- **Full-screen host discipline**: HUD hosts and full-rect hosts explicitly declare `mouse_filter`; all clickables `focus_mode = 0`.
- **Probe-first rule (先查明再修，不许猜)**: a protected-code fix (e.g. `clamp_sprite_offset`) is only unlocked by a measured fail-layer id from `final/portrait_cover_probe_notes.md`; all numbers quoted in delivery notes are probe-measured `observed` values, never derived.
- **ProgressBar theme min-size clamp (probed)**: once a `ProgressBar` enters the scene tree, Godot raises `size.y` to its theme minimum (~22 px) - the authored 12 px survives only on the headless instantiate path (`tests/test_health_bar.gd`).

## Testing

```bash
./run_tests.sh
```

Runs, against the godot-builder sidecar: a compile check, a headless playtest against the `playtest/` contract (**47 scenarios**), then the GDScript unit suite (the `/script` gate auto-discovers every `tests/*.gd` that `extends SceneTree` - `test_event_data.gd` and `test_cultivation.gd` included; an empty discovery is a hard failure, not a pass). A passing run requires a clean compile, zero runtime errors, `empty_round_stalls == 0`, and every assertion green (except the deliberately-red `terminal_victory_8_12_rounds_hp_15_40` difficulty window).

Additionally, the static pytest gate (`tests/test_playtest_contract_smoke.py`, standard-library only, no Godot) verifies the contract integrity: `scenario_order` ↔ scenario-file completeness, the round scenarios present on disk and ordered, the surface whitelist + `clicks:`-owner contract, the top-bar/creation/health-bar/affordance surface contracts, `test_timeline_at_values_are_integers` (every timeline `at:` in the round scenario files is a single integer), and **`test_event_content_surface_contract`** (this round: the six units' four new portrait vars + `CultivationScreen.events_seen_count` on the surface, `event_travel_effects.yaml` exists with `name:` == basename / integer `at:` values / comparison operators on every assert, and `portrait_visibility.yaml` carries the `covered_frac` lines).

## Verification Status

**Runtime gates have run - the vision gate produced no verdict, which blocks the round.** The gate results below are the `5_review` verdict's readings of the gate reports (`compile_report.json` / `test_report.json` / `playtest_summary.md` / `vision_report.json`); those report files are not persisted in the repo workspace, so nothing here is independently re-read. Unproduced or unreadable evidence is never reported as passed - the un-judged vision gate is carried forward as the blocking item, not buried.

**Measured (probe runs, `final/portrait_cover_probe_notes.md`, f40 native 960×704):**

- `Central_Divine`: `portrait_visible=false`, `portrait_fail_layer="covered"`, `portrait_covered_frac=0.333333333333333`, `sprite_top=0.0` - the A-class red that unlocked the clamp fix.
- `Player`: `portrait_visible=true`, all eight layers green, `covered_frac=0.104166666666667`, 3-number geometry self-consistent - "nothing drawn there" was a frame-reading artifact.
- `East_Heretic` / `West_Poison` / `South_Emperor` / `North_Beggar`: green, `covered_frac=0.166666666666667` (sub-threshold B-class guards).
- Dead-probe invariant clean: no unit sits on the `false` + `fail_layer==""` contradiction.

**Verified by direct code/contract audit at this step (Step 5):**

- `EventData.TABLE` holds **16 unique ids**; every effect type is within the 5-type vocabulary; every `attr` target within the five keys; every `item` target a real equipment id; `battle_id` null everywhere; `_build`/`_build_option` fresh-instance contract preserved.
- `cultivation.gd`: `events_seen_count` declared and synced in `_sync_surface()`; `_draw_event()` exclusion + pool-reset unchanged (one rng op per travel); `_apply_event_option()` match unchanged.
- `player.gd` / `enemy.gd` publish the covered-fraction and 3-number probe vars after the visibility verdict and before the `undo_available` recompute (the dead-probe abort class cannot recur through this path).
- `GridManager.clamp_sprite_offset` uses `BOARD_TOP_MARGIN_Y = 92` (one constant + one line; the taller-than-board guard unchanged).
- `playtest/portrait_visibility.yaml` extended in place (original 10 asserts byte-identical + 12 appended); `playtest/event_travel_effects.yaml` registered at the end of `scenario_order` **and** `ROUND_SCENARIOS` (same order, two-place sync rule); 47 scenario files on disk.
- `tests/test_event_data.gd` (`>= 16` + 16-row pins + `_test_effect_targets`) and `tests/test_cultivation.gd` (5 new event test functions incl. the 48 effects-land cases) wired into `run()`; `run_tests.sh`'s unit gate auto-discovers them.

**Gate results (as read by the `5_review` verdict from the gate reports):**

- **Compile (`5_compile`)**: passed - 69 scripts, 0 errors, 0 warnings.
- **Playtest (47 scenarios)**: hard gate passed - 0 runtime errors, `empty_round_stalls == 0`, crash / scene-load / spec-key / input checks clean; **1/47 failed assertions = only the deliberately-red `terminal_victory_8_12_rounds_hp_15_40`** (observed `Player.health` 783 outside the 15–40% window - the sanctioned balance deferral). This round's new/affected scenarios are green: `portrait_visibility` **22/22** (incl. `Central_Divine.portrait_covered_frac < 0.25` post-clamp-fix - the evidence that closed **UX-01b**) and `event_travel_effects` **19/19** (the no-repeat count-ladder proof).
- **Unit tests (`5_test`)**: pytest contract gate passed - 10 passed / 0 failures (incl. `test_event_content_surface_contract`). The GDScript suite (existing + this round's event tests, incl. the 48 effects-land cases) is wired into `run_tests.sh`'s `/script` gate; the review's gate summary does not quote its per-file results, so no per-file pass is claimed here.
- **Vision gate (`5_vision`): no green verdict produced.** The on-disk `vision_report.json` shows `blind:true, endpoint_unreachable:true` - the primary vision model endpoint was unreachable at gate time and the fallback failed mid-run after 4 calls (IncompleteRead). Only 4/47 scenarios were judged, all full-HP battle frames; the 4 Q5=NO answers are consistent with the documented 78–100% HP flattening design. Zero injured frames were judged. The next `5_vision` gate run (with the retry fix applied on the gate side) is expected to produce a green Q5 verdict. No code change to `health_bar.gd` was needed.

**Known Issues**

- **`terminal_victory_8_12_rounds_hp_15_40` is the one deliberately-red scenario** (balance tuning deferred per `design/00_roadmap.md` 「数值最后调」). It must not be reported as green until the window is actually met.
- **Vision Q5 (health bars recognisable) - gate did not judge (4/47 scenarios, all full-HP, zero injured).** The vision gate endpoint was unreachable at gate time (`blind:true, endpoint_unreachable:true`); the fallback failed after 4 calls (IncompleteRead). The 4 Q5=NO answers on full-HP frames are consistent with the 78–100% HP flattening design. Zero injured frames were judged - the classification (real defect / full-HP-only applicability / fallback-model limitation) remains PENDING. The next `5_vision` gate run is expected to produce the real verdict. Do not mark the round deployable until a green vision gate run exists.
- **UX-01b (王重阳 portrait partially covered by the top strip)**: fix landed (`BOARD_TOP_MARGIN_Y = 92`), pre-fix red measured, and **CLOSED(jinyong-events)** in `design/40_ux_backlog.md` from the post-fix gate evidence (`portrait_visibility` 22/22, `Central_Divine.portrait_covered_frac < 0.25`).

## Recorded Debt

1. **`design/20_content.md` has no section for the 16-event pool** - the round's closure constraint 「新增内容在 `design/20_content.md` 记一节」 is unmet; the event content lives in `scripts/data/event_data.gd` + tests + `final/delivery_notes.md` + the `99_changelog.md` row. A follow-up design pass should add it.
2. ~~**`design/30_presentation.md` still documents the six-layer predicate**~~ **Resolved**: `design/30_presentation.md` now documents the **eight-layer** predicate (2026-08-25 jinyong-events amendment block: `blank_texture` / `covered`, the 0.25 / 64 px² thresholds, max-single-coverer semantics, `covered_fraction()`).
3. **`spine_to_ending` and `creation_budget_clamp_and_traits` walk a test-only path** (TUTORIAL WON -> TRANSITION -> CHARACTER_CREATION -> SECT_SELECTION) that no longer exists in the real flow. Follow-up: convert `creation_budget_clamp_and_traits` to a direct `creation.tscn` boot.
4. **Shell duplication**: `menu.tscn` duplicates `main.tscn`'s shell node block (forced by `main.tscn`'s byte-identity). Future shell edits must touch both.
5. **`has_save` is session-memory**; menu availability is file existence. Do not "fix" one by pointing at the other.
6. **Segment-2 穿越 narrative content is deferred** - roadmap stage-3 content.
