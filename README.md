# 武林群侠大乱斗 — 招式打得出去,门派选得对

A **Godot 4** single-player wuxia cultivation + turn-based tactics RPG. Yang Guo faces the Five Grandmasters on a summit grid in a keyboard-completable tutorial duel, and behind it sits the full six-segment line: **tutorial win → transition → character creation → sect selection → cultivation (36 months) → map → ending**.

This round closes the playability gap a human tester hit (真人试玩): **the mechanism worked but the player didn't know how to fire** (`fahui_du_multiplies_damage` was 10/10 green because the script knows to move then `skill_1` then `basic_attack` — a human does not). It also finishes the two leftovers queued last round: the sect-select pick and the skill-bar turn states.

- **A HUD hint line** (`ActionHintLabel`) now tells the player what to do next: after selecting a technique it reads `按 J 出招 / 点击目标`, and every previously-silent rejection now shows a specific Chinese reason — **射程不够 / 冷却中 N 回合 / 须在半血以下 / 本回合无法用招 / 教程尚未解锁 / 该招式不存在**.
- **A range/target highlight** (`RangeHighlight`, a `Node2D` overlay) draws the selected skill's reachable tiles in translucent blue and valid enemy targets in red, driven by the player's own hit test so what you see is exactly what executes; it vanishes on deselect / toggle-off / use / battle exit.
- **The confirm key got a real name**: the input action `basic_attack` → **`attack_confirm`** (J / keycode 74 unchanged). The *engine* action string `"basic_attack"` (AI decisions + `CombatManager.execute_action`) is a different thing and stays byte-identical.
- **The skill bar now has a real "waiting" state**: on enemy-turn frames every visible button dims to a desaturated cool blue-gray (`state_palette("waiting")`, bg luma 0.26596) instead of silently falling through to the "ready" palette. The bug was that the override was nested inside the `elif hp_gated:` branch — dead code for every ready button.
- **The sect pick is fixed**: `cultivation_changes_combat` now presses `move_down` at frame 160 so the check at frame 200 pins `CultivationScreen.sect_id == "wudang"` (武当, the sword sect the scenario's 剑法 damage pins actually describe). No frame numbers were renumbered.

> **⚠️ Verification status: FAILED — do NOT ship this round.** `final/verify_report.json` reports `all_goals_met: false` / `ready_for_deploy: false`. Gates (per the `5_review` verdict): `5_compile` **passes** (62 scripts, 0 errors, 0 warnings); `5_test` reports "no Python sources, not applicable" (the GDScript suite is unwired — a declared non-goal, correctly not read as a pass). The playtest hard gate passes (no crash / scenes load / no `input_dead`), but **8/26 scenarios still fail assertions**, including one protected tutorial scenario and the game-cannot-be-won blocker — see the Testing section for the exact list. This round's new deliverables themselves are **green**: `skill_hint_and_range_highlight` 13/13, `skill_bar_waiting_state` 7/7, `skill_rejection_reason_texts` 3/3, `trait_combat_effects_and_twelve_slots` 22/22, the sect pick pins `sect_id == "wudang"`, and the vision gate classifies both encounter battles as `battle` (`passed: true`). What still blocks shipping: `two_phase_skill_unlock_and_hp_gate` 18/20 (a protected tutorial scenario), `ui_geometry_readability` 23/24 (`round_pause_overlap`, readability #6), the three declared-legacy scenarios (`terminal_victory` 4/6 — game cannot be won, `each_unit_acts_once` 6/12, `dot_resolves` 2/8), plus `save_load_roundtrip` / `cultivation_month_cycle_and_deck_bookkeeping` / `sect_switch_same_school_connects` regressions.
>
> `5_review` concurs with the do-not-ship verdict. ⚠️ **Data provenance:** the per-scenario counts above come from the `5_review` verdict (which read the compile-step `playtest_summary.md` / `vision_report.json`); the authoritative per-assertion source is `playtest_report.json` on disk, which this step cannot access — the PM must cite it before targeting fixes. The verdict is unaffected (8/26 failing is far from green).

## Quick Start

1. Open the project in **Godot 4.4+**.
2. Run the import/compile pass so Godot produces `.import` sidecars (the harness `--compile` step does this; in the editor it happens automatically on open).
3. Press **F5** (or click *Run Project*).
4. Advance the tutorial with **Enter / Space** (or click *Next*), then fight.

## How to Play

| Action | Input |
|--------|-------|
| Move (one tile per press, 4-tile budget) | WASD / Arrow keys |
| Select technique | **1–8** (9–12 with 左右互搏; or click the HUD skill buttons) |
| Execute selected technique / basic attack | **J** (`attack_confirm`; left-click an enemy to target the same way) |
| End turn | **Space** |
| Advance tutorial | Enter / Space |
| Pause / unpause | Escape |

- Every turn = move up to your movement range **plus** one action, in any order. Space ends the turn at any point.
- Press `J` with no skill selected to perform a basic attack on the **nearest adjacent** enemy.
- Select a skill with `1`–`8` (or `9`–`12`), then press `J` to fire it at the nearest valid target. The hint line tells you the next step, and the grid highlight shows the reachable + target tiles.
- **Two-phase unlock** (tutorial only): techniques `5`–`8` (Melancholy Palms) are locked until **round 4**; technique `8` (Seventeen Melancholy Forms) additionally requires HP **below 50%**. A rejected selection now says why instead of doing nothing.
- Each unit acts once per round in initiative order: Yang Guo (88) → East Heretic (85) → Central Divine (80) → South Emperor (76) → North Beggar (74) → West Poison (70).
- Defeat all five Grandmasters to win; let your health reach zero to lose.

## The Six-Segment Line

The whole game runs inside one persistent shell (`scenes/main.tscn`): a `SceneManager` autoload listens to `GameManager.state_changed` and swaps exactly one preloaded segment scene under the shell's `SceneHost` node (`GameManager.current_state` is the playtest-visible FSM state — `TUTORIAL → BATTLE → WON/LOST → TRANSITION → CHARACTER_CREATION → SECT_SELECTION → CULTIVATION → MAP → ENDING`). WON/LOST are transitions, not terminals.

| Segment | Scene | What happens |
|---|---|---|
| 1. Tutorial | `battlefield` | Yang Guo vs the Five Greats (keyboard-completable tutorial) |
| 2. Transition | `transition` | Full-screen Chinese text pages → character creation |
| 3. Creation | `creation` | 30-point attribute buy (tiered pricing, 10–20) + trait/flaw toggles |
| 4. Sect select | `sect_select` | Pick one of five sects → its 丁 internal + 丁 external gongfa |
| 5. Cultivation | `cultivation` | 36 monthly cycles: card draws + 练功/修习/做工/游历 + year-end stay/switch + 存盘/读档/删档 |
| 6. Map / ending | `map` → `ending` | Node-graph map (adjacency-checked moves) → tiered ending text |

**Saves** live at `user://save_<slot>.json` (plain JSON, 3 slots, versioned schema, atomic `.tmp` → validate → `.bak` rollback writes). The save carries the RNG seed + `rng_state` + the per-category deck `remaining`/`drawn` lists, so a reloaded save replays the identical card sequence.

### Debug actions (harness-only — no physical keys)

Defined in `project.godot` `[input]` with **empty event lists** (never visible in normal UI; the headless playtest triggers them via `Input.action_press`):

| Action | Effect |
|---|---|
| `debug_win_tutorial` | Wipe every living enemy through the real damage/death pipeline → `WON` |
| `debug_lose_tutorial` | Kill the player through the real damage/death pipeline → `LOST` |
| `debug_fast_forward` | In cultivation, advance all remaining months synchronously through the normal month path |
| `debug_step_month` | Advance exactly one month through the normal phase machine with fixed auto-choices (card 0; 练功 = first unmastered **external** art, else first unmastered art, else 修习 根骨; year-end stay). Reusable N times; one press also resolves a parked year-end. |
| `debug_grant_art` | Grant the 甲级 (A) art of the main external school (fallback: the sect's internal A) via the real `add_gongfa` path |
| `debug_enter_encounter` | In CULTIVATION, start an encounter battle (`start_encounter()`) |
| `debug_poison_player` | Apply Spirit Serpent poison to the player through the real apply_dot pipeline (tick round(8*1.3)=10, 2 rounds) |

## Chinese Font Theme

The whole UI ships in Chinese under one **global font theme** (design §2.1 — 界面文字一律中文):

- **`assets/themes/global_theme.tres`** — a committed `Theme` with `default_font` = the shipped Noto Sans SC FontFile (`res://assets/fonts/NotoSansSC-Regular.otf`, SIL OFL), referenced by **res:// path** and `default_font_size = 12`.
- Wired via `ProjectSettings gui/theme/custom`; the `ThemeManager` autoload installs the same font as `ThemeDB.fallback_font` at startup.
- **No per-node font overrides**; labels keep `text_overrun_behavior` = trim (never ellipsis).
- Display layer only: `character_name`, node names, skill ids, state strings and turn-order names stay canonical English. Chinese replaces only the rendered strings.

## The Five Grandmasters (deterministic AI)

Each enemy is driven by a distinct AI controller (`scripts/ai/*.gd`) that decides **once per enemy turn** via a deterministic priority list — no timers, no RNG:

| Grandmaster | Behaviour |
|-------------|-----------|
| West Poison (西毒欧阳锋) | Melee poison strikes, Toad Squat charge, line-AoE knockback; reflects melee damage (蛤蟆反震) |
| North Beggar (北丐洪七公) | High-damage Dragon Palm brawler with line/AoE knockback + Dog-Beating Staff at range 2; −15% all damage taken (丐帮铁骨) |
| East Heretic (东邪黄药师) | Ranged specialist — Falling Petals, technique/movement seals, Peach Blossom Maze zones, global initiative debuff; counters attacks from ≤3 tiles (弹指神通) |
| South Emperor (南帝段智兴) | Balanced ranged — Solar Finger ignores DR, heals self/ally (先天调息), regenerates each round and heals once below 40% (一阳续命) |
| Central Divine (中神通王重阳) | Defensive sword + shield (罡气护体), global dispel; survives the first fatal blow at 1 HP (先天罡气) |

## Turn System

- **Round snapshot**: living units sorted by effective initiative (身法, minus 20 while a 碧海潮生 debuff is active) descending, ties broken by registration order. Godot's `sort_custom` is unstable, so the engine uses a decorate-sort-undecorate insertion sort for determinism.
- **Turn-start lifecycle** (exact order): cooldown decrement (int rounds) → DoT/status ticks → constant regen (神雕之力 +26, 一阳续命 +13) → the unit acts.
- **Damage pipeline**: attack side `round(base × buffs × fa_hui_du)` → defense side `round(output × (1 − DR))`. 发挥度 applies to damage / heal / shield / DoT-tick values only — never cooldown, range, knockback, or duration. **Percentages never take the fhd multiplier** (design/40_progression.md): DR / hit / crit / trait percentages apply raw.
- **Melee vs ranged** (design/10_systems.md §2.2): decided by the declaring external art's **weapon class** (刀/剑/长兵/拳掌/轻功/横练 = melee; 指/暗器/奇门毒/乐器 = ranged) — never by shape, reach, or damage.
- **Pause** is a boolean gate (no `Engine.time_scale`).

## 功法 (Gongfa) Data Structure

`scripts/data/gongfa_data.gd` models internal/external martial arts. Internal arts produce the energy pool + a passive id; external arts produce technique lists.

Every art exposes `get_fa_hui_du(unit)` — the **real 甲乙丙丁 prerequisite cascade** (design/10_systems.md §3–§4), interval 0.6~1.3:

1. `unit == null` → the art's flat `fa_hui_du` field (pre-cascade default).
2. Otherwise: `missing` = count of lower-grade prerequisite slots in the same school with no mastered art (甲 needs 乙丙丁, 乙 needs 丙丁, 丙 needs 丁, 丁 needs none); `base = [1.0, 0.85, 0.7, 0.6][missing]`; if `base < 1.0` return it (prerequisites incomplete → no attribute bonus); else return `1.0 + 0.1 × min(same-attribute mastered arts, 3)`.

The pure cascade is the **ONLY** path — there is no 特判 bypass. The tutorial battle's protected 编排数值 1.3 comes out of this same cascade: `TutorialFillers.fill()` (scripts/data/tutorial_fillers.gd) appends real mastered filler arts (missing lower-grade same-school slots + same-attribute arts) to each tutorial unit, graded descending, until every art's prereqs are genuinely complete.

`GongfaData` carries a `mastered` flag; `CharacterData` carries the battle-side `traits` array. `scripts/data/battle_setup.gd` builds progression-side `CharacterData` from a `PlayerProfile` via the design §7 formulas: 气血 = 根骨×5, 内力值 = 内力×2, 移动力 = 2+floor(身法/20), 先攻 = 身法, 普攻 = 10+根骨, range 1 (melee school) / 2 (唐门/暗器). Profile traits are copied onto the CharacterData, and only the top **2** (or top **3** with 左右互搏) external arts by grade rank are equipped (grade ties break by profile order).

### Progression ladder (丁丙乙甲)

`scripts/data/progression_gongfa_data.gd` registers 5 sects × (internal + external) × 丁丙乙 = 30 generated arts, plus the **甲级 (A) ladder**:

- **4 hand-authored external A arts** (one per school, each with 4 real techniques incl. a `绝招` finisher):
  | Art | School | Attribute | Techniques |
  |-----|--------|-----------|------------|
  | 独孤九剑 (a_sword) | sword | 刚 | 总诀式 / 破剑式(ignores DR) / 破气式(line) / 绝招·无招胜有招 |
  | 降龙十八掌 (a_palm) | palm | 阳 | 亢龙有悔(kb1) / 飞龙在天 / 见龙在田 / 绝招·潜龙勿用(kb2) |
  | 杨家枪法 (a_polearm) | polearm | 刚 | 回马枪 / 梨花枪 / 锁喉枪(kb1) / 绝招·枪出如龙 |
  | 小李飞刀 (a_dart) | dart | 阴 | 例不虚发 / 连环飞刀 / 满天刀雨 / 绝招·一刀飞仙 |
- **5 internal A arts** (one per sect, same attribute as the line): 易筋经·圆满 / 纯阳无极功·圆满 / 混天功·圆满 / 峨眉九阳功·圆满 / 唐门心法·圆满.
- Grade tables: `GRADE_STEP` 丁入门/丙精进/乙大成/甲圆满, `PRACTICE_TO_MASTER` 丁4/丙6/乙8/甲10, `TECHNIQUE_COUNT` 丁1/丙2/乙3/甲4, `TECHNIQUE_DAMAGE` 丁18/丙22/乙26/甲30.
- The **9-row A pool** (`a_pool()`) is the 神功 card grant pool. The year ladder tops at 乙 — 甲 comes only from the 神功 card (or `debug_grant_art`).

External A attributes deliberately never equal their school's feeding sect lines (e.g. sword lines are 柔/阴 → a_sword 刚), so a completed 3-year ladder sits at exactly 1.0 and the climb toward 1.3 stays a real pursuit.

### 修习 lookup table

`TraitEffects.practice_gain(wisdom, roll)` maps one `SaveManager.rng.randf()` draw through 悟性-tier cumulative thresholds:

| 悟性 | +1 | +2 | +3 | expected |
|---|---|---|---|---|
| ≤15 | 60% | 30% | 10% | 1.50 |
| 16–25 | 35% | 45% | 20% | 1.85 |
| 26–35 | 20% | 50% | 30% | 2.10 |
| ≥36 | 10% | 45% | 45% | 2.35 |

练功 adds +1 practice per action; 破 (sha_po_lang) multiplies gongfa practice amounts ×1.5 (`round(amount × 1.5)`).

## Encounter Battles

`GameManager.start_encounter()` (a new entry point, distinct from `start_battle()` which is gated to TUTORIAL) sets `battle_return_state = "CULTIVATION"` and routes CULTIVATION → BATTLE. The battlefield detects encounter mode (`battle_return_state == "CULTIVATION"`), builds the player from `SaveManager.profile` via `BattleSetup.build_character`, spawns a deterministic sparring partner (`EncounterData.sparring_partner()` — 60 HP, 4 mastered D 阳 arts → fhd 1.3), and does **not** start the tutorial overlay. `request_retry()` / `request_continue()` route LOST/WON back to `battle_return_state` (with `clear_battle()` so a second encounter rebuilds fresh refs).

**Round-1 kick-off sequencing** (the wiring fix): `start_encounter()` emits `battle_started` *before* the async scene swap, while the roster is still empty. `CombatManager._on_battle_started()` therefore delegates to the guarded `_begin_if_ready()` — phase `IDLE` + live player + ≥1 enemy — and silently skips the empty pre-swap signal instead of tripping `empty_round_stalls`. The new battlefield's `_ready()` (ENCOUNTER branch) then queues `_wire_hud.call_deferred(...)` followed by `CombatManager.begin_battle.call_deferred()` (FIFO, same frame flush), so the HUD is wired **before** `round_started`/`turn_started` fire. `begin_battle()` is public, idempotent, and safe to call sync or deferred (after a `reset_battle()` + `clear_battle()` teardown it self-guards to a no-op). The tutorial path is unchanged: its units exist before `start_battle()`, so the skip never fires there.

## Trait Effects (first implementations)

Pure static math lives in `scripts/data/trait_effects.gd`; engine hooks live in `CombatManager` / `player.gd` / `battlefield.gd`:

| Trait | Effect |
|-------|--------|
| 杀 (sha_po_lang) | Heal `round(actual HP loss × 0.20)`, capped at `round(max HP × 0.15)` per round (per-owner counter reset at round start) |
| 破 (sha_po_lang) | Gongfa practice experience ×1.5 (`round(amount × 1.5)`) on every `_add_practice` / practice card |
| 狼 (sha_po_lang) | Attack side ×`(1 + 0.08 × living enemies)`; defense side extra DR `0.05 × living enemies` |
| 铁布衫 (iron_shirt) | First lethal damage per battle → stay at 1 HP, clear negative statuses (per-battle flag, mirror of 先天罡气) |
| 身轻如燕 (swallow_lightness) | Player single-tile move may slide **through** an enemy-occupied tile to the free tile beyond (costs 2 movement) |
| 左右互搏 (ambidextrous) | Equipment cap 3 external arts → **12-slot** skill bar (two rows × 6 buttons) |

## HUD

- **Grid overlay** (`GridLines`): 1 px semi-transparent cell-boundary lines across the 15×11 board plus a border ring; exposed as `Battlefield.grid_lines_visible`.
- **Action hint line** (`ActionHintLabel`, new this round): a bottom-center label (hidden by default) that shows `按 J 出招 / 点击目标` after a technique is selected and a specific Chinese reason on every rejection — 射程不够 / 冷却中 N 回合 / 须在半血以下 / 本回合无法用招 / 教程尚未解锁 / 该招式不存在. The player emits a `action_hint` signal; the HUD forwards it to the label and clears it on deselect / success / battle exit (`clear_battle_refs()`).
- **Range/target highlight** (`RangeHighlight`, new this round): a `Node2D` overlay between the grid lines and the characters. It polls `GameManager.get_player()` each frame, recomputes only when the selected skill / player tile / living-enemy count changes, and draws reachable tiles (translucent blue, alpha ≤ 0.28 so grid lines stay visible) plus valid enemy targets (translucent red). Reachability mirrors `player.can_skill_hit()` exactly; the target test *is* `can_skill_hit()`.
- **Skill bar**: up to **12** `SkillButton` nodes. Default = 2 arts / 8 slots (one row); with 左右互搏 = 3 arts / 12 slots (**two rows × 6**). Buttons beyond `skills.size()` are created but hidden, so `SkillButton9..12` surface reads are stable in every mode. Each button shows the technique name, hotkey, a `发挥 ×N.N` label, and a round-based cooldown overlay with a remaining-rounds number plus a state tag (`LOCKED` / `HP`). `state_text` is one of `"ready"` / `"cooldown"` / `"phase_locked"` / `"hp_gated"` / **`"waiting"`** — the new fifth state renders on every visible button while the battle is live but it is not the player's turn. `SkillButtonN.state_luma` exposes the bg luminance (`Color.get_luminance()`; waiting bg luma 0.26596, ≥ 0.10 below ready 0.3874). The two-phase unlock gate is `tutorial_battle`-scoped; the HP gate is data-driven from `SkillData.hp_gate_below_ratio`. `HUD.skill8_right_edge` / `HUD.skill12_right_edge` expose the right edges (≤ 960).
- **Health bars** (`HealthBar`): a **64 px** wide bar with the **name label above**, fill green→yellow→red by HP fraction, edge-clamped via `get_final_transform()`.
- **Round indicator** (top-center): `回合 N`, `行动: <name> · 移动 <m> · 行动 ✓/结束`, `顺序: <Chinese names>`; never overlaps `PauseButton`.
- **Energy label**: `内力: 180` (display only).
- All rendered UI text is Chinese; identity strings stay canonical English.

### Health-bar display aliases

| Canonical name | Display name |
|----------------|--------------|
| Yang Guo | 杨过 |
| East Heretic | 黄药师 |
| West Poison | 欧阳锋 |
| South Emperor | 段智兴 |
| North Beggar | 洪七公 |
| Central Divine | 王重阳 |
| Sparring Partner | 陪练弟子 |

## Project Structure

```
├── project.godot                 # Engine config, autoload singletons, input map, display/stretch, theme
├── playtest/                     # Headless playtest contract, one file per scenario
│   ├── _common.yaml              #   shared scene / actions / surface + scenario_order
│   └── <scenario>.yaml           #   26 of them, basename == the scenario's `name:`
├── run_tests.sh                  # CLI gate: compile + headless playtest + unit tests
├── resources.md                  # Asset/tool reference notes
├── design/                       # Authoritative design archive (00..99)
├── assets/
│   ├── characters/ terrain/ backdrop/ audio/ fonts/ themes/ seed_manifest.json
├── scenes/
│   ├── main.tscn battlefield.tscn player.tscn enemy.tscn
│   ├── ui/ (hud, health_bar, skill_button, tutorial_overlay)
│   └── segments/ (transition / creation / sect_select / cultivation / map / ending)
├── scripts/
│   ├── battlefield.gd grid_lines.gd
│   ├── autoload/ (game_manager, scene_manager, save_manager, grid_manager,
│   │              combat_manager, tutorial_manager, theme_manager, audio_manager)
│   ├── characters/ (player.gd, enemy.gd)
│   ├── ai/ (ai_base + 5 Grandmaster controllers + ai_sparring)
│   ├── data/ (character_data, skill_data, gongfa_data, player_profile, trait_data,
│   │          trait_effects, tutorial_fillers, encounter_data,
│   │          progression_gongfa_data, card_data, event_data, map_data, battle_setup)
│   ├── segments/ (transition, creation, sect_select, cultivation, map, ending)
│   └── ui/ (hud, health_bar, skill_button, round_indicator, pause_button,
│             tutorial_step, range_highlight)
└── tests/                        # 16 test_*.gd + unit_test_runner.gd (unwired this round)
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager` (six-segment FSM), `SaveManager` (PlayerProfile + seeded RNG + 3-slot JSON IO), `GridManager`, `CombatManager` (turn engine + `reset_battle()` / DEBUG hooks), `TutorialManager`, `AudioManager`, `ThemeManager`, `SceneManager` (state-driven scene router; kept last).

### Input actions (`project.godot` `[input]`)

`move_up/down/left/right`, `skill_1`..`skill_8` (digits 1–8), `skill_9`..`skill_12` (keys 9 / 0 / minus / equal), `attack_confirm` (J — renamed from `basic_attack`; the *input* action only), `end_turn` (Space), `pause_game` (Escape), `tutorial_next` (Enter), plus the six harness-only DEBUG actions `debug_fast_forward` / `debug_win_tutorial` / `debug_lose_tutorial` / `debug_step_month` / `debug_grant_art` / `debug_enter_encounter`.

> **Naming caveat (important):** `basic_attack` exists as **two different strings**. The input action was renamed to `attack_confirm` (project.godot `[input]`, `player.gd` `ATTACK_ACTION` const + its two input sites, `tutorial_manager.gd` `_allowed_actions` lists, `playtest_spec.yaml`). The **engine action string** `"basic_attack"` — the AI decision dicts in `scripts/ai/*.gd` and the `CombatManager.execute_action(unit, "basic_attack", …)` resolution — is unchanged. Grep must show `basic_attack` only in the AI/combat resolution sites.

### `CombatManager` public API

| Member | Behaviour |
|--------|-----------|
| `current_round` / `phase` / `active_unit_name` / `turn_order` / `turn_log` / `last_turn_actor` / `empty_round_stalls` | Observable turn-engine state (the last is a loud guard counter — must stay 0) |
| `tutorial_battle` | Encounter/tutorial mode flag |
| `begin_battle()` | Guarded round-1 kick-off (phase IDLE + live player + ≥1 enemy); idempotent, callable sync or deferred |
| `debug_sha_heal_total` / `debug_iron_shirt_procs` / `debug_lang_attack_mult` | Trait diagnostic counters |
| `is_player_turn()` | True while the player's turn is active |
| `end_current_turn()` | End the active unit's turn |
| `begin_turn(unit)` | Turn-start lifecycle: cooldown → DoT/status → regen |
| `execute_move_path` / `execute_action` | Execute movement / `"basic_attack"` / `"skill"` |
| `apply_damage(target, amount, source, is_melee, ignore_dr)` | Two-stage pipeline + fatal guard (先天罡气 / 铁布衫) + 杀 lifesteal + counters |
| `apply_heal` / `apply_shield` / `apply_dot` / `apply_status` | Heal / shield / DoT / status |
| `get_fa_hui_du(gongfa, unit)` | Delegates to the `GongfaData` 甲乙丙丁 cascade |
| `reset_battle()` / `debug_wipe_enemies()` / `debug_kill_player()` | Battle teardown + harness-only WON/LOST drivers |

Signals: `round_started`, `turn_started`, `turn_ended`, `phase_changed`, `action_executed`, `damage_dealt`, `paused`, `unpaused`.

### `GridManager` public API

`is_in_bounds`, `is_walkable`, `is_occupied` / `reserve_tile` / `free_tile`, `find_path`, `get_move_range`, `get_units_in_range`, `get_tiles_in_aoe`, `get_units_in_aoe` (origin / shape / size / direction / team filter), `grid_to_world` / `world_to_grid`, `clamp_sprite_offset`, `clear_grid`.

### `GameManager` public API

`get_state()`, `start_battle()` (tutorial-gated), `start_encounter()` (CULTIVATION → BATTLE), `end_battle(won)`, `register_enemy`, `unregister_enemy`, `get_enemies_alive()`, `set_player`, `get_player`, plus the six-segment surface: `set_battle_return_state` / `get_battle_return_state`, `enter_segment(state)`, `request_continue` / `request_retry`, `restart_game()`, `clear_battle()`, and the `end_overlay_text` observable.

### `Player` surface (this round's additions)

`signal action_hint(text)` (forwarded to the HUD hint label), `_skill_reject_reason(index) -> String` (single source of truth for the six rejection reasons, gate order byte-identical to the former `_skill_selectable()`), public `can_skill_hit(skill, enemy)` (authoritative hit test the highlight mirrors). `const ATTACK_ACTION: StringName = &"attack_confirm"` replaces the two hard-coded input-action strings.

### `SaveManager` / `SceneManager` surface

`SaveManager` exposes `seed`, `last_error`, `slot`, `has_save`, the six deck counts `eco_left/eq_left/growth_left/pow_left/trait_left/art_left`, and the roundtrip observables `snapshot_profile_json` / `snapshot_rng_state` / `snapshot_decks_string` + `loaded_profile_json` / `loaded_rng_state` / `loaded_decks_string`. `SceneManager` exposes `current_scene`, `pending_swap`, `last_error`.

### Playtest surface contract (`playtest/_common.yaml`)

The contract is split one file per scenario under `playtest/`: `_common.yaml` holds `scene` / `actions` / `surface` and a `scenario_order`, and each `playtest/<name>.yaml` holds one scenario (its basename must equal its `name:`). It used to be a single 1478-line `playtest_spec.yaml`, which made every one-scenario repair a rewrite of all 26 — and that is how assertions quietly went missing. An unlisted scenario file still runs, appended, so adding a scenario is just dropping in a file. Editing the whole contract in one place is no longer possible, and that is the point.

Observable nodes/variables include `CombatManager` (turn engine + trait diagnostics), per-unit `health`/`grid_pos`/`turns_taken`/`acted`/`skill_cooldowns`/`shield`/`status_names`/`traits`, `SkillButton1..12` (`text`, `fahui_text`, `disabled`, `hp_gated`, `state_text`, `cooldown_remaining`, `state_luma`), `ActionHintLabel` (`visible`, `text`), `RangeHighlight` (`visible`, `tile_count`, `target_count`), `RoundIndicator`, `EnergyLabel`, `HUD` (`visible`, `size`, `skill8_right_edge`, `skill12_right_edge`, `round_pause_overlap`), `HealthBar`, `Battlefield`, the six segment screens (`TransitionScreen`, `CreationScreen`, `SectSelectScreen`, `CultivationScreen` — incl. `gongfa_ids`/`gongfa_grades`/`gongfa_names` — `MapScreen`, `EndingScreen`), and the `SceneManager` / `SaveManager` autoloads.

## Technical Notes

- **Godot version**: targets 4.4; `project.godot` `config/features` records `4.7` — pre-existing, compiles/runs under the current toolchain.
- **Stable initiative sort**: decorate-sort-undecorate with a registration-index tie-break.
- **Freed-object safety**: `is_instance_valid()` before every `as` cast / typed assignment; scene swaps await the outgoing scene's `tree_exited`.
- **Tween safety**: `_await_tween_safe()` caps every action tween at `TWEEN_TIMEOUT_SEC` (0.25 s).
- **Deterministic AI**: zero RNG — pure priority lists.
- **Seeded RNG**: one `RandomNumberGenerator` owned by `SaveManager`, seeded from `mix_seed(system_entropy)` (splitmix64 finalizer); all card draws / deck shuffles / 修习 rolls / shen_gong picks go through it in operation order. No stray `randi()` / `randomize()`.
- **Rounding**: GDScript `round()` rounds half away from zero; `45 * 1.3` = 58.5 → 59. Percentages never take the fhd multiplier.
- **Static AStar graph**: only the border ring is disabled once; occupancy re-checked at move time.
- **Highlight layering**: `RangeHighlight` sits between `GridLines` and `Characters` in `battlefield.tscn`; translucent fills (alpha ≤ 0.28) keep grid lines readable, and health bars (CanvasLayer 10) always float on top.

## Testing

```bash
./run_tests.sh
```

Runs a compile check (which triggers the Godot import pass), then a headless playtest against the `playtest/` contract, then the Godot unit tests under `tests/`. The playtest contract carries **26 scenarios**: the ten battle behaviour scenarios (round-one snapshot + initiative order, enemy-acts-only-after-player-ends-turn, each-unit-acts-once-per-round, cooldown-by-round, DoT-at-victim-turn-start, the 1.3× damage multiplier, two-phase unlock + HP gate, 先天罡气 fatal guard, terminal victory within 8–12 rounds with player HP 15%–40%, `ui_geometry_readability` + `skill_button_visual_states`), the segment/scene scenarios (`spine_to_ending`, `tutorial_win_routes_to_transition`, `tutorial_loss_restarts_tutorial`, `creation_budget_clamp_and_traits`, `lone_bane_sect_grants_external_only`, `cultivation_month_cycle_and_deck_bookkeeping`, `cultivation_year_end_stay`, `save_load_roundtrip`, `sect_switch_same_school_connects`, `cultivation_changes_combat`, `trait_combat_effects_and_twelve_slots`), and the three scenarios added this round (`skill_hint_and_range_highlight`, `skill_rejection_reason_texts`, `skill_bar_waiting_state`).

A passing run requires a clean compile, a playtest that executes frames with no `input_dead` scenarios, zero runtime errors (including no `Trying to cast a freed object`), and every assertion green.

> **Verification status: FAILED (gates have run) — do not claim shipped.** `5_compile` passes (62 scripts, 0 errors, 0 warnings) and `5_test` reports "no Python sources, not applicable" (the GDScript suite is explicitly unwired this round — non-goal, correctly not read as a pass). The playtest hard gate passes (no crash, scenes load, no `input_dead`), but **8/26 scenarios fail assertions**:
>
> - **This round's new deliverables — green:** `skill_hint_and_range_highlight` **13/13**, `skill_bar_waiting_state` **7/7**, `skill_rejection_reason_texts` **3/3**, and `trait_combat_effects_and_twelve_slots` **22/22**. The W5 sect pick is confirmed: `cultivation_changes_combat` is **30/30 GREEN** (`sect_id == "wudang"` passes, and the `发挥 ×0.85` damage pins are green).
> - **5_vision — `passed: true`.** Both encounter battles are classified `battle` (skill bar + health bars visible) and `skill_bar_waiting_state` answers Q3 = YES. Residual caveat: waiting-state visual distinctness is still shaky — Q3 (skill-button appearance changes over time) had **7 bad answers across 19 answered battle scenarios** (including `round_one`, `central_divine`, `ui_geometry`, `tutorial_win`, `tutorial_loss`, `cultivation_changes_combat`), so success criterion #5 ("Q3 green in battle scenarios") is only partially met.
> - **Blockers still red (genuine core gameplay):**
>   - `terminal_victory_8_12_rounds_hp_15_40` 4/6 — `current_state != "WON"`, HP out of range → **the game cannot be won** (declared legacy, still unreachable).
>   - `each_unit_acts_once_per_round_initiative_order` 6/12 — all five enemies `turns_taken != 1`, wrong `turn_log` (declared legacy).
>   - `dot_resolves_at_victim_turn_start` 2/8 — round/phase/active_unit/health pins wrong (declared legacy).
>   - `two_phase_skill_unlock_and_hp_gate` 18/20 — `SkillButton8.disabled`/`hp_gated` wrong → a protected tutorial scenario is not green (violates success criterion #8).
>   - `ui_geometry_readability` 23/24 — `HUD.round_pause_overlap == false` fails (readability #6).
>   - `cultivation_month_cycle_and_deck_bookkeeping` 15/17 and `save_load_roundtrip` 9/13 — `has_save` / `last_error` / `month == 3` wrong.
>   - `sect_switch_same_school_connects` 6/8 — `sect_id != "emei"`, `gongfa_ids` missing.
> - **Spec-contract note:** the earlier "`Array == String` operator" defects are **already resolved** — the current failing asserts already use the `.has()` / numeric form, so do not delete any timeline.
> - **Data provenance:** per-scenario counts come from the `5_review` verdict (which read `playtest_summary.md` / `vision_report.json`); the authoritative per-assertion source is `playtest_report.json` on disk, which this step cannot access — the PM must cite it before creating fix tasks.

`final/verify_report.json` reports `all_goals_met: false` and `ready_for_deploy: false`. Fix the genuine blockers above (turn-engine / HP-gate / DoT regressions, `round_pause_overlap`, and the save/cultivation/sect regressions), then re-run the full gate and confirm every gate green (compile + 26 playtest scenarios + vision battle classification + 0 runtime errors + `empty_round_stalls == 0`) before flipping the verdict:

```bash
./run_tests.sh
```

Re-run instructions: after any change, re-run and confirm: (a) `playtest_report.json` shows no `Trying to cast a freed object` errors, (b) the terminal scenario reports `WON` / round in `[8,12]` / HP in `[75,200]`, (c) the six protected tutorial behaviour scenarios stay green (including `two_phase_skill_unlock_and_hp_gate`) with byte-identical damage numbers and `发挥 ×1.3`, (d) `spine_to_ending` reaches `ENDING`, (e) `cultivation_changes_combat` stays **30/30 GREEN** — `sect_id == "wudang"` and `fahui_text == "发挥 ×0.85"` / damage pins, (f) `save_load_roundtrip` snapshot/loaded equality is green, (g) `skill_hint_and_range_highlight` / `skill_rejection_reason_texts` / `skill_bar_waiting_state` are green, and (h) `ui_geometry_readability` (`round_pause_overlap == true`) + `skill_button_visual_states` are green.
