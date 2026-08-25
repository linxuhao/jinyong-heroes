# 华山论剑 (Huashan Sword Tournament)

A **Godot 4** single-player wuxia cultivation + turn-based tactics RPG. You boot into a **main menu** (mouse-first), create your own character **before** the tutorial, fight a keyboard-completable tutorial duel as the orchestrated Yang Guo, and then walk the six-segment line: **tutorial win → transition → sect selection → cultivation (36 months) → map → ending**.

## What this round delivers — 全按钮化 ("UI that explains itself")

Playtesting surfaced six UX defects that all share one shape: the interface **implies** an interaction the engine does not actually support (keyboard-only transitions presented as button-navigable rows, a cached-pointer mouse attack, tooltip-only descriptions). This round makes every on-screen action a real, clickable button and makes the UI self-describing. All seven fixes reuse the existing convergence pattern (buttons delegate to the SAME handler the keyboard uses — the keyboard degrades to a shortcut, never a second logic path):

1. **Mouse click-to-attack fixed at the event level.** `scripts/characters/player.gd` `_handle_click_targeting(event)` now converts the **click event's own** viewport coordinates (`get_canvas_transform().affine_inverse() * event.position`) instead of re-querying the viewport-cached `get_global_mouse_position()`. Identity-safe today, camera-proof later. *(Code correct by inspection; the end-to-end click-to-attack harness proof is still open — see Verification Status and Recorded Debt #6.)*
2. **Creation screen is fully button-driven.** Four new phase-navigation buttons — `AttrBackButton` (返回菜单 → `GameManager.enter_menu()`), `AttrNextButton` (→ `_on_accept`), `TraitBackButton` (→ `_on_move_left`), `TraitNextButton` (→ `_on_move_right`) — each wired to the existing keyboard handler, with the `pressed_connected` snapshot extended to all four.
3. **Trait descriptions now exist in data.** `trait_data.gd` `TraitDef.description` + all 13 机制 rows, verbatim from `design/40_progression.md` §2.2.
4. **Attribute descriptions now render.** `creation.gd` `_ATTR_DESCS` + `AttrDescLabel` (气血 = 根骨 × 5, 内力值 = 内力 × 2, …) from `design/40_progression.md` §7.1.
5. **Skill descriptions are visible and Chinese.** `battlefield.gd` skill `desc` data switched to the Chinese 文案 from `design/20_content.md`; a persistent `SkillDescLabel` shows the default guidance 点击招式按钮,查看招式说明 until a skill is selected, then its description (tooltips remain a bonus).
6. **Movement-range highlight.** `scripts/ui/move_range_highlight.gd` is a green BFS that mirrors `player._try_move` exactly (walkable tiles, unoccupied landings, 身轻如燕 slide-through at cost 2) — the displayed set **equals** the executable set. Green is asserted numerically distinct from the blue skill-reach and red target highlights via `fill_color` observables.
7. **Battle verbs are clickable.** `EndTurnButton` (结束回合 → the same `CombatManager.end_current_turn()` Space calls) and `AttackButton` (出招 (J) → the same `player._try_keyboard_attack()` J calls), gate-guarded and disabled off-turn.

**Coverage:** 6 new scenarios appended to `playtest/_common.yaml` `scenario_order` (38 total): `click_targeting_fixed`, `creation_traits_back_next_buttons`, `creation_back_to_menu_walk`, `skill_description_visible`, `movement_range_highlight`, `battle_end_turn_attack_buttons`. The 32 pre-existing scenario files stay byte-identical; `_common.yaml` is append-only.

## Quick Start

1. Open the project in **Godot 4.4+** (`project.godot` `config/features` records `4.7`).
2. Run the import/compile pass so Godot produces `.import` sidecars (the harness `--compile` step does this; in the editor it happens on open).
3. Press **F5** (or *Run Project*). The game boots into the **main menu**.
4. Click **新的冒险** (or arrow + Enter to navigate), create your character with the mouse (now with per-phase Back/Next buttons), then confirm to enter the tutorial.

## How to Play

| Action | Input |
|--------|-------|
| Menu / settings navigation | Arrow keys + **Enter** — or **click** the entry |
| Creation attribute / trait / phase | Click the ±/toggle/nav buttons — or the same keys the buttons delegate to |
| Move (one tile per press, 4-tile budget) | WASD / Arrow keys |
| Select technique | **1–8** (9–12 with 左右互搏; or click the HUD skill buttons) |
| Execute technique / basic attack | **J** (`attack_confirm`) or click **出招 (J)**; left-click an enemy targets the same way |
| End turn | **Space** or click **结束回合** |
| Advance tutorial | Enter / Space |
| Pause / unpause | Escape or click **Pause** |

- Every turn = move up to your movement range **plus** one action, in any order. The green highlight shows every tile you can still reach.
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
| 0. Creation | `creation` | 30-point attribute buy (tiered pricing, 10–20) + trait/flaw toggles + per-phase Back/Next buttons — mouse-clickable, before the tutorial |
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
- **Movement-range highlight** (`MoveRangeHighlight`, NEW): green BFS mirror of `_try_move`; observables `visible` / `tile_count` / `fill_color`.
- **Range/target highlight** (`RangeHighlight`): blue reachable tiles + red valid targets, mirroring `player.can_skill_hit()`; `fill_color` observable added for the green-vs-blue distinctness assert.
- **Action hint line** (`ActionHintLabel`): shows 按 J 出招 / 点击目标 after a selection and a specific Chinese reason on every rejection.
- **Skill description label** (`SkillDescLabel`, NEW): always-visible; default guidance → selected skill's Chinese description.
- **Battle action buttons** (NEW): `EndTurnButton` (结束回合) + `AttackButton` (出招 (J)) in the top-right column under `PauseButton`, gate-guarded and disabled off-turn; geometry observables `hud_button_overlap` / `hud_desc_overlap` assert they never overlap existing HUD widgets.
- **Skill bar**: up to 12 `SkillButton` nodes (default 2 arts / 8 slots; 左右互搏 = 3 arts / 12). Each shows name, hotkey, 发挥 ×N.N, and a cooldown/state overlay.
- **Health bars** (`HealthBar`): 64 px wide, name label above, green→yellow→red by HP fraction.
- **Round indicator**: 回合 N, 行动: <name> · 移动 <m>, 顺序: <Chinese names>.

## Project Structure

```
├── project.godot                 # Engine config, autoloads, input map, theme, run/main_scene -> menu.tscn
├── playtest/                     # Headless playtest contract, one file per scenario (38)
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
└── tests/                        # 16 test_*.gd + unit_test_runner.gd (unwired this round)
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager`, `SaveManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`, `ThemeManager`, `SettingsManager`, `SceneManager` (kept **last**).

### Input actions (`project.godot` `[input]`)

`move_up/down/left/right`, `skill_1`..`skill_12`, `attack_confirm` (J), `end_turn` (Space), `pause_game` (Escape), `tutorial_next` (Enter), plus the harness-only DEBUG actions (`debug_fast_forward` / `debug_win_tutorial` / `debug_lose_tutorial` / `debug_step_month` / `debug_grant_art` / `debug_enter_encounter` / `debug_poison_player` / `debug_damage_player` / `debug_click_menu_entry` / `debug_click_creation_widget` / `debug_seed_save` / `debug_delete_save` / `debug_reset_settings`).

> **Naming caveat:** `basic_attack` exists as two different strings — the input action was renamed to `attack_confirm`; the engine action string `"basic_attack"` (AI decisions + `CombatManager.execute_action`) is unchanged.

### `GameManager` public API

`get_state()`, `start_battle()` (tutorial-gated), `start_encounter()`, `end_battle(won)`, `request_continue`/`request_retry`, `restart_game()`, `clear_battle()`, `release_stale_units()`, `enter_segment(state)`, and the menu surface `enter_menu()` / `menu_new_adventure()` / `menu_open_settings()` / `menu_close_settings()` / `menu_load_game()` / `menu_quit()` / `finish_creation()`.

### `SaveManager` public API

`save_slot(s)` / `load_slot(s)` / `autosave()` / `delete_slot(s)`, `has_save_file(s)`, `ensure_user_dir()`, `new_profile(attrs, traits)`, `apply_seed(seed)`, `draw_cards(monthly)`; surface vars `seed`, `last_error`, `slot`, `has_save`, deck counts, roundtrip observables, and `last_io_error_code` / `last_io_error_text` / `debug_user_dir_exists`. Signal: `loaded(slot)`.

### New playtest surface (this round, append-only in `_common.yaml`)

`MoveRangeHighlight` (visible / tile_count / fill_color), `EndTurnButton` + `AttackButton` (visible / size / mouse_filter / disabled), `SkillDescLabel` (visible / text), `AttrBackButton` / `AttrNextButton` / `TraitBackButton` / `TraitNextButton` (visible / size / mouse_filter), `AttrDescLabel` / `TraitDescLabel` (visible / text), `RangeHighlight.fill_color`, `HUD.pressed_connected` / `HUD.hud_button_overlap` / `HUD.hud_desc_overlap`, and the `CreationScreen.pressed_connected` keys for the four new nav buttons.

## Technical Notes

- **Godot version**: targets 4.4; `config/features` records `4.7` — pre-existing, compiles/runs under the current toolchain.
- **Stable initiative sort**: decorate-sort-undecorate with a registration-index tie-break.
- **Freed-object safety**: `is_instance_valid()` before every `as` cast / typed assignment; scene swaps await the outgoing scene's `tree_exited`.
- **Tween safety**: `_await_tween_safe()` caps every action tween at 0.25 s.
- **Deterministic AI**: zero RNG — pure priority lists.
- **Seeded RNG**: one `RandomNumberGenerator` owned by `SaveManager`, seeded from `mix_seed(system_entropy)` (splitmix64 finalizer — frozen).
- **Rounding**: `round()` half away from zero; `45 * 1.3` = 58.5 → 59. Percentages never take the fhd multiplier.
- **Highlight layering**: `RangeHighlight` and `MoveRangeHighlight` sit between `GridLines` and `Characters`; translucent fills (alpha ≤ 0.28) keep grid lines readable.

## Testing

```bash
./run_tests.sh
```

Runs a compile check, a headless playtest against the `playtest/` contract (38 scenarios), then the Godot unit tests under `tests/`. A passing run requires a clean compile, zero runtime errors, `empty_round_stalls == 0`, and every assertion green (except the deliberately-red `terminal_victory_8_12_rounds_hp_15_40` difficulty window).

## Verification Status

**Downstream gate results (as recorded in the `5_review` verdict — the authoritative gate evidence):**

| Gate | Result |
|---|---|
| Compile (`5_compile`) | **PASSED** — 0 errors, 66 GDScript scripts parsed |
| Full playtest | **PARTIAL** — hard gate passed (0 runtime errors, `empty_round_stalls == 0`); **36/38** scenario assertion groups green |
| Vision / readability (`5_vision`) | **FAILED** — `passed: false`, `blind: true`, `unparseable_response` (0/7 questions answered) |
| Unit tests (`5_test`) | **NOT A PASS** — `no_tests_collected: true` (Godot tests under `tests/` unwired) |

**Verdict: NOT deployable** (`all_goals_met: false`, `ready_for_deploy: false` in `final/verify_report.json`).

The two red playtest scenarios are `terminal_victory_8_12_rounds_hp_15_40` (5/6 — the deliberate difficulty contract, left red) and **`click_targeting_fixed` (0/2 — `Player.acted` did not change, `Central_Divine.health` stayed 130)**. Success criterion 1 (a harness-proven click-to-attack path with an observed damage value) is therefore **not met**: the C1 coordinate fix is present and correct by inspection, but the end-to-end click proof is contradicted — delivery notes claim a green 2/2 probe (with the added `Central_Divine_ClickTarget` Control hit-surface), while the authoritative gate run shows 0/2 red. A full-suite re-run flipping `click_targeting_fixed` green is required before this round is deployable.

## Recorded Debt

1. **`spine_to_ending` and `creation_budget_clamp_and_traits` walk a test-only path** (TUTORIAL WON → TRANSITION → CHARACTER_CREATION → SECT_SELECTION) that no longer exists in the real flow. Follow-up: convert `creation_budget_clamp_and_traits` to a direct `creation.tscn` boot.
2. **Shell duplication**: `menu.tscn` duplicates `main.tscn`'s shell node block (forced by `main.tscn`'s byte-identity). Future shell edits must touch both.
3. **`has_save` is session-memory**; menu availability is file existence. Do not "fix" one by pointing at the other.
4. **Segment-2 穿越 narrative content is deferred** — roadmap stage-3 content.
5. **Unit-test gate reports `no_tests_collected`** — the Godot unit tests under `tests/` are unwired; that is NOT a pass signal. `5_test` currently reports `passed: true` on `no_tests_collected: true` — treat that as skipped/unrun, never as a pass. Wiring is deferred to a separate round.
6. **Click-to-attack harness proof (success criterion 1) is NOT established.** The C1 fix is correct by inspection (`player.gd` `_handle_click_targeting(event)` → `get_canvas_transform().affine_inverse() * event.position`; `get_global_mouse_position` absent from the `.gd` files), and a `ClickTarget` Control hit-surface was added to enemies. But the authoritative gate run shows `click_targeting_fixed.yaml` 0/2 red (`Player.acted` unchanged, `Central_Divine.health` 130 unchanged), while `final/delivery_notes.md` claims a green 2/2 probe (observed 91). Re-establish the proof with a full-suite run that flips `click_targeting_fixed` green — do NOT ship on the "no runtime errors" fallback, and do NOT take a single-scenario probe as the gate result.
