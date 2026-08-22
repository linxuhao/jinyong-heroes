# Technical Architecture Design — Turn-Based Combat Overhaul (Tutorial Battle)

**Project:** Huashan Sword Tournament (Godot 4 / GDScript; engine gate runs 4.4; `config/features=4.7` is pre-existing)
**Goal (this run):** convert the RTWP combat system into turn-based combat per `design/10_systems.md` §5, reconfigure Yang Guo and the Five Greats to match `design/20_content.md` exactly, introduce the 功法 (internal/external art) data structure with a 发挥度 multiplier, add an English round/actor HUD, rework input bindings, and rewrite `playtest_spec.yaml` including a deterministic 8–12-round terminal victory scenario.

**Inputs:** Step-1 SOTA report (`step1_sota.md`) + full code/scene inspection performed in this step. All facts below are verified against the current repo.

---

## 1. Overview

The current game is real-time-with-pause: `CombatManager` owns a FIFO `action_queue` + `Engine.time_scale` pause, DoTs tick per-frame in `_process`, enemies decide every `AI_TICK_INTERVAL=0.5s` via `_ai_accumulator`, cooldowns decay by `delta` seconds, and the player moves freely with WASD. This run replaces all of that with a **strictly sequential turn engine**: each round snapshots a stable initiative order, each surviving unit gets exactly one turn (move ≤ move_range + one action), cooldowns / DoTs / statuses tick by round at the unit's own turn start, and enemy AI is invoked exactly once per enemy turn returning a single move+action decision.

The existing execution primitives are **kept and driven by the new engine**: `_execute_move` / `_execute_basic_attack` / `_execute_skill` internals (occupancy management, AoE via `GridManager`, knockback, DoT application, cooldown start, SFX hooks), `_damage_flash`, `apply_damage/heal/knockback`, `_await_tween_safe`. What is **deleted**: `action_queue`, `is_unit_busy`, `_processing_action`, `_drain_action_queue`, `Engine.time_scale` pausing, `_process` DoT ticking, `AI_TICK_INTERVAL` / `_ai_accumulator` / `reset_ai_timer`, and the seconds-typed cooldown / DoT-duration fields.

### 1.1 Success criteria → verification mapping

| Brief criterion | Mechanism | Proof |
|---|---|---|
| Each unit acts exactly once per round, initiative order | Round snapshot + per-unit `turns_taken` + `turn_log` | Playtest S3 |
| Turn = move + one action, any order; Space ends turn | Per-unit `moves_left` / `moved` / `acted` budgets; `end_turn` action | Playtest S2/S3 |
| Cooldowns tick by round, not seconds | `skill_cooldowns: Array[int]`, decrement at own turn start | Playtest S4 |
| DoT resolves at victim's turn start, duration in rounds | Per-unit DoT table ticked in `begin_turn` | Playtest S5 |
| 发挥度 ×1.3 actually applies to damage | Attack-side `round(base × 1.3)` in the damage pipeline | Playtest S6 (45 → 58) |
| Yang Guo + Five Greats match `design/20_content.md` | Data factory rewritten from the record; no derived formulas | Implementer review + terminal scenario |
| HUD shows 发挥度 + round/actor/initiative order | `SkillButton*.fahui_text`, `RoundIndicator.*` | Playtest S6/S7 |
| Space = end turn, Escape = pause, 1–8 techniques, two-phase unlock | `project.godot [input]`, player input gates, skill-bar unlock state | Playtest S7 + manual |
| Terminal: win in 8–12 rounds, player HP 15–40% | Deterministic AI + scripted keys | Playtest S9 |

---

## 2. Architecture Diagram (text)

```
Autoloads (order unchanged in project.godot):
  GameManager    — TUTORIAL → BATTLE → WON/LOST; enemies_alive; battle_started signal
  GridManager    — grid math, occupancy, AStar, move range, AoE tile queries (+origin/cross-size extensions)
  CombatManager  — TURN ENGINE + resolution pipeline (rewritten; no action queue, no timers)
  TutorialManager— step overlay + input gating (texts rewritten in English)
  AudioManager   — unchanged

Scene tree (scenes/main.tscn — unchanged shape):
  Main
  ├─ Camera @ (480,352)
  ├─ Battlefield (battlefield.gd — content factory rewritten)
  │  ├─ SummitBackdrop / Grid (TileMap) / Characters
  │  │  ├─ Player (player.gd — turn budgets, 1–8 input, Space end turn)
  │  │  └─ East_Heretic / West_Poison / South_Emperor / North_Beggar / Central_Divine
  │  │     (enemy.gd — turn state; ai_controller decides once per turn)
  ├─ HUDLayer (CanvasLayer 10)
  │  └─ HUD (Control)
  │     ├─ HealthBarContainer
  │     ├─ RoundIndicator (NEW: round, active actor, initiative order)
  │     ├─ EnergyLabel (NEW: "Qi: 180")
  │     ├─ SkillBar → SkillButton1..8 (NEW layout: name + 发挥度 + cooldown overlay)
  │     └─ PauseButton
  └─ TutorialLayer (CanvasLayer 100) → TutorialOverlay
```

**Data flow — turn engine:** `GameManager.start_battle()` emits `battle_started` → `CombatManager._on_battle_started()` → `current_round = 1` → `_begin_round()` (snapshot stable initiative order) → `_next_turn()` → `unit.begin_turn()` (cooldowns → DoT/status ticks → regen) → player turn waits for input (event-driven) / enemy turn runs `ai_controller.evaluate()` once and executes move-path then action → `end_current_turn()` → next unit, else `_end_round()` (round += 1). After every action the loop checks `GameManager.get_state()` and aborts on WON/LOST.

**Data flow — resolution:** `execute_skill(unit, target, params)` → attack side: `round(base_damage × buff_multiplier × fa_hui_du)` → defense side per target: `round(output × (1 − DR))` → shield absorb → HP → fatal-guard check (先天罡气) → death handling → counterattack/reflect triggers (弹指神通 / 蛤蟆反震) → `_damage_flash` tween awaited via `_await_tween_safe`.

**Data flow — HUD:** `hud.gd _process()` polls `CombatManager` (`current_round`, `phase`, `active_unit_name`, `turn_order`) and the player's cooldowns each frame and refreshes `RoundIndicator` / skill-button overlays / unlock states; skill buttons keep the `cooldowns_updated` signal path for cooldown overlays.

---

## 3. Turn Engine Specification (normative)

### 3.1 Round loop pseudocode (single source of truth for implementers)

```
_on_battle_started():            # GameManager.battle_started signal
    current_round = 1
    _begin_round()

_begin_round():
    alive_units = player + GameManager.enemies_alive (health > 0)
    effective_init(u) = u.initiative - (20 if status "init_minus_20" active on u else 0)
    turn_order = stable_sort(alive_units, key=effective_init DESC,
                             tie-break = registration index ASC)   # earlier-registered first
    turn_order_names = [u.character_data.character_name ...]
    round_started.emit(current_round)
    _next_turn()

_next_turn():
    if GameManager.get_state() in ["WON","LOST"]: return
    while turn_order not empty and head not alive: pop head      # killed earlier this round
    if turn_order empty: _end_round(); return
    unit = pop head
    active_unit_name = unit.character_data.character_name
    phase = "PLAYER_TURN" if unit == GameManager.get_player() else "ENEMY_TURN"
    turn_started.emit(unit)
    unit.begin_turn()                          # §3.3 lifecycle
    if unit is player:
        await player_end_turn                  # event-driven: player presses end_turn (Space)
    else:
        decision = unit.ai_controller.evaluate(unit)      # §6.2, called ONCE
        if not decision.empty:
            await execute_move_path(unit, decision.move_path)   # each step tween-awaited
            if decision.action != "wait": await execute_action(...)  # validated at execution
        unit.acted = true
        end_current_turn()

end_current_turn():
    unit.turns_taken += 1
    turn_log.append(unit.character_data.character_name)
    unit.clear_this_turn_restrictions()        # "next turn" statuses expire at turn end
    turn_ended.emit(unit)
    _next_turn()

_end_round():
    current_round += 1
    _begin_round()
```

- **Pause (Escape):** boolean gate only (no `Engine.time_scale`). While paused, player input is ignored and the enemy loop halts at unit boundaries (`while is_paused: await frame`). The player's turn is event-driven, so nothing advances while paused anyway. 100 ms debounce kept.
- **Death mid-round:** a unit killed earlier in the round never acts (alive check at pop). Death during an action (counter/reflect killing the player, DoT at turn start killing a unit, lethal kill of the last enemy) is observed via `GameManager.get_state()` after every action; the loop aborts immediately. `GameManager.unregister_enemy` already auto-wins on an empty list.
- **Initiative debuff timing:** 碧海潮生's −20 applies to the *next* round snapshots. A status is "active for this round's snapshot" when `rounds_remaining ≥ 1` at round start; durations decrement at the victim's own turn start (§3.3), so a 2-round debuff applied mid-round N affects the snapshots of rounds N+1 and N+2. (Player 88 → 68: order becomes East Heretic, Central Divine, South Emperor, North Beggar, West Poison, Yang Guo.)

### 3.2 Turn structure (both sides)

- A turn = move (up to `move_range` tiles, decremented per tile) + exactly one action (basic attack / technique / wait). Move and action order is free for the player; **enemies conventionally execute move-path first, then the action** (deterministic).
- **Player movement** stays tile-by-tile WASD/arrow: each valid step consumes 1 from `moves_left`; blocked at 0. Moving after acting is allowed.
- **Wait** = ending the turn without an action (Space). There is no separate wait button.
- `moved` / `acted` flags live on each unit; `end_turn` (Space) is accepted at any point of the player's turn, with or without remaining budget.
- **Jump techniques** (徘徊空谷, 飞龙在天): displacement of up to 3 tiles along the A* path toward the nearest enemy, landing tile walkable + unoccupied; the jump consumes the action but NOT `moves_left`. Invalid landing (no reachable/unoccupied tile within 3) → skill not consumed (no cooldown, no `acted`).

### 3.3 Unit turn-start lifecycle (`begin_turn`, per design 10_systems §5.2)

Exact order (assertable):
1. **Cooldown decrement** — each `skill_cooldowns[i] > 0` → `-1`.
2. **DoT / status ticks** — each active poison DoT ticks damage (`apply_damage`), then `rounds -= 1`; status durations decrement (shield, init debuff, zone lifetimes, 蛤蟆蹲 charge); "next turn" restriction statuses (拖泥带水 / 玉箫点穴 / 点穴) apply their restriction for this turn.
3. **Constant regen** — 神雕之力 +12, 一阳续命 +10 (no 发挥度; passives are not techniques).
4. **Unit acts.**

DoT tick value = `round(base_tick × fa_hui_du)` computed **at application time** and stored in the unit's DoT table (发挥度 does not change mid-battle). Poison 8 → 10/tick, 6 → 8/tick. Multiple DoTs stack as separate entries; death removes a unit's DoTs with it.

### 3.4 Status table (per unit, `statuses`)

Each entry: `{id, kind: "negative"|"positive", rounds: int, params: Dictionary}`. Exposed for the surface as `status_names: Array[String]`.

| id | kind | semantics |
|---|---|---|
| `poison` | negative | `params.tick` damage at victim's turn start; `rounds` decrements; removed at 0 |
| `init_minus_20` | negative | 2 rounds; −20 effective initiative in round-start snapshots while `rounds ≥ 1` (碧海潮生) |
| `move_minus_next_turn` | negative | next turn: `moves_left = max(0, move_range − 2)`; cleared at turn end (拖泥带水) |
| `no_techniques_next_turn` | negative | next turn: technique use blocked (basic attack + move still allowed); cleared at turn end (玉箫点穴) |
| `no_move_next_turn` | negative | next turn: movement blocked (action still allowed); cleared at turn end (点穴) |
| `shield` | positive | `params.amount` absorbed before HP; `rounds` (3) decrements at owner's turn start (罡气护体) |
| `toad_charge` | positive | 蛤蟆蹲: next round's first technique ×1.5; consumed on use or at that turn's end |

- **先天罡气** (fatal guard): clears ALL `kind == "negative"` statuses; shield (positive) survives.
- **先天一炁**: removes all positive statuses (shield, toad_charge) from every unit hostile to the caster (player only, in this battle).
- **桃花迷阵** is NOT a unit status: it is a hazard-zone table in `CombatManager` — `{tile: Vector2i, rounds: int, owner: Node}`. Zone lifetimes decrement at the caster's turn start, removed at 0. Entering a zone tile during movement applies −2 to that unit's *current-turn* remaining `moves_left` (clamped ≥ 0), no persistence; zones affect all units except the caster.

---

## 4. Resolution Pipeline Specification (normative)

### 4.1 发挥度 (fa hui du)

- `GongfaData.get_fa_hui_du(unit) -> float` returns **1.3** for every unit in the tutorial — an interface-only stub; the prerequisite (甲乙丙丁 cascade) calculation is NOT implemented this run (brief).
- Applies to technique **damage / heal / shield** values and **DoT per-tick damage only**. Never to cooldown, range, knockback tiles, durations, or jump distance.
- **Does NOT apply** to: basic attacks (普攻 is a derived stat, not a 功法-produced technique), 弹指神通 counterattacks, 蛤蟆反震 reflects (passives are not techniques). Documented interpretation, see §7.2.
- Display labels (English): value < 1.0 → `ERRATIC`, 1.0–1.2 → `NORMAL`, 1.3 → `OVERDRIVE`. All tutorial buttons show `OVERDRIVE x1.3`.

### 4.2 Two-stage damage pipeline (design 10_systems §4.3)

```
Attack side:  output = round(base_damage × buff_multipliers × fa_hui_du)     # e.g. 45 × 1.3 = 58.5 → 58
Defense side: actual = round(output × (1 − DR_total))                        # e.g. 58 × 0.85 = 49.3 → 49
```

- `buff_multipliers` = attack-side buffs only (蛤蟆蹲 ×1.5 — composed multiplicatively with 发挥度 before the single round).
- `DR_total` = product of defense-side reduction tags on the target: 丐帮铁骨 (all −15%), 神雕之力 (melee −20%). A technique flagged `ignore_damage_reduction` (一阳指) skips ALL DR tags.
- **Melee definition:** Chebyshev distance(attacker, target) ≤ 1 at resolution time. 神雕之力's −20% and 蛤蟆反震's trigger use this definition.
- Counter/reflect damage (弹指神通 10, 蛤蟆反震 12) is untyped direct damage: no 发挥度, no DR, no shield interaction beyond normal HP subtraction; triggers **after** the triggering damage fully resolves, only if the trigger source is still alive (East Heretic must survive the hit to counter; West Poison must survive to reflect). Counter limited to once per round (flag reset at round start).
- **Order inside `apply_damage`:** lethal check → 先天罡气 fatal guard (if target is Central Divine and trait unused: HP = 1, clear negative statuses, mark used — applies to DoT ticks too) → otherwise death handling. 一阳续命 below-40% one-time +60 triggers only when the damaging instance leaves the unit alive (HP > 0 after the hit) and HP% < 40% for the first time.
- Heal/shield: `round(base × fa_hui_du)` then apply. 先天调息 35 → 46; 罡气护体 50 → 65.
- All arithmetic uses GDScript **double** floats then `round()`; the design's canonical example 45 × 1.3 = 58.5 → 58 holds under double arithmetic (58.4999…) and must pass in playtest S6.

### 4.3 Expected ×1.3 cook values (implementer reference; compute via `round(v * 1.3)`, assert at least the bold ones)

| base | out | base | out | base | out |
|---|---|---|---|---|---|
| 8 | 10 | 20 | 26 | 35 | 46 |
| 6 | 8 | 22 | 29 | 36 | 47 |
| 12 | 16 | 24 | 31 | 38 | 49 |
| 14 | 18 | 25 | 33 | 40 | 52 |
| 18 | 23 | 26 | 34 | 45 | **58** |
| 30 | 39 | 32 | 42 | 48 | 62 |
| 34 | 44 | 70 | 91 | 50 | 65 |

Defense side example (丐帮铁骨): 58 × 0.85 → 49 (design's canonical example). 神雕之力 melee: × 0.8, e.g. 26 → 21.

### 4.4 AoE origins (design 10_systems §5.5)

`SkillData.aoe_origin` ∈ {`self`, `target`, `landing`}. `GridManager.get_units_in_aoe(origin, shape, size, direction, hostile_to)` gains: explicit origin tile; cross **arm length = size** (十字 2 = 9 tiles); new shape `adjacent` (8-tile ring, for 十七式 / 徘徊空谷 "相邻全体"); `square` keeps Chebyshev-ball semantics (size = radius); team filter — damage AoEs return only units **hostile** to the caster (new `team: int` field, 0 = player, 1 = Five Greats), heal skills target friendly units (先天调息 targets self or ally).

---

## 5. Component List & Interfaces

### C1 — Data layer: `./scripts/data/gongfa_data.gd` (NEW), `character_data.gd`, `skill_data.gd`

**`GongfaData` (extends Resource, programmatic construction only):**
```gdscript
@export var gongfa_name: String          # English display name
@export var grade: String                # "A"|"B"|"C"|"D"  (甲乙丙丁)
@export var kind: String                 # "internal" | "external"
@export var school: String               # "sword"|"palm"|"finger"|"music"|"polearm"|"internal"
@export var attribute: String            # "yin"|"yang"|"hard"|"soft"
@export var energy_provided: int         # internal only (player 180)
@export var passive_id: String           # internal only: "shen_diao_power"|"finger_dart"|"toad_reflect"|
                                         #  "one_yang_renewal"|"beggar_iron_bone"|"innate_qi"
@export var stat_bonuses: Dictionary     # internal only; empty in tutorial (stats given directly)
@export var techniques: Array            # external only: Array[SkillData]
@export var fa_hui_du: float = 1.3
func get_fa_hui_du(_unit) -> float: return fa_hui_du   # prerequisite calc = interface-only stub
```

**`CharacterData` additions:** `initiative: int` (= 身法 value), `energy: int` (display only; player 180, enemies 0 — record lists no enemy 内力值), `internal_arts: Array`, `external_arts: Array`, `passive_id: String` (primary internal art), `team: int` (0 player / 1 enemy), existing `max_health`, `move_range`, `attack_damage`, `attack_range`, `skills`, `ai_class`, `character_name`, `color` kept.

**`SkillData` changes** (retype/rename where noted — no playtest surface references these fields, so the migration is low-risk):
```gdscript
@export var cooldown: int                 # ROUNDS (was float seconds)
@export var dot_rounds: int               # REPLACES dot_duration (float seconds)
@export var aoe_origin: String = "self"   # "self"|"target"|"landing"
@export var aoe_shape: String             # + "adjacent" added
@export var aoe_size: int                 # line=tiles, cross=arm length, square=radius
@export var shield_amount: int            # NEW (罡气护体)
@export var shield_rounds: int            # NEW
@export var jump_tiles: int               # NEW (徘徊空谷/飞龙在天 = 3)
@export var status_applied: String = ""   # NEW: "poison"|"move_minus_next_turn"|"no_techniques_next_turn"|
                                          #  "no_move_next_turn"|"init_minus_20"|"toad_charge"|"hazard_zone"
@export var ignore_damage_reduction: bool # NEW (一阳指)
@export var hp_gate_below_ratio: float    # NEW (十七式 = 0.5)
@export var target_friendly: bool         # NEW (先天调息)
@export var is_finisher: bool             # NEW (绝招 flag; display)
```
Unchanged: `skill_name`, `description`, `damage`, `range`, `knockback`, `dot_damage` (base per tick, pre-发挥度), `heal_amount` (base, pre-发挥度).

### C2 — Content factory: `./scripts/battlefield.gd`

`_create_all_skill_data()` / `_create_all_character_data()` rewritten to `design/20_content.md` **exactly** (no derived formulas; values are given directly). Registration order preserved: player first, then East Heretic, West Poison, South Emperor, North Beggar, Central Divine (this is the initiative tie-break order). Starting tiles unchanged. Technique list per unit (indices = hotkeys for the player; enemies keep AI-facing arrays):

| Unit | Techniques (index — name — key numbers) |
|---|---|
| Yang Guo | 0 重剑无锋 "Heavy Edge" 45 single KB1 cd1 · 1 大巧不工 "Grand Simplicity" line3 38 cd2 · 2 力斩千钧 "Thousand-Force Cleave" cross2 self 34 cd3 · 3 四海无量 "Boundless Seas" square2 self 70 cd6 finisher · 4 心惊肉跳 "Heart-Rending Strike" single 38 cd1 · 5 拖泥带水 "Dragging Mire" single 25 cd2 + move_minus_next_turn · 6 徘徊空谷 "Wandering Valley" jump3 + adjacent-at-landing 20 cd3 · 7 黯然销魂十七式 "Seventeen Melancholy Forms" adjacent self 70 KB2 cd8 hp_gate 0.5 finisher |
| East Heretic | 0 落英缤纷 "Falling Petals" range3 3×3@target 14 cd2 · 1 玉箫点穴 "Jade Flute Acupoint" single 20 cd3 + no_techniques_next_turn · 2 桃花迷阵 "Peach Blossom Maze" hazard_zone r2 self cd4 · 3 碧海潮生 "Tidal Melody" global 18 cd6 + init_minus_20 ×2r |
| West Poison | 0 灵蛇缠身 "Spirit Serpent" single 24 cd2 + poison 8×2r · 1 蛤蟆蹲 "Toad Squat" self-buff toad_charge cd3 · 2 毒砂掌 "Poison Sand Palm" cross1 self 18 cd3 + poison 6×2r · 3 蛤蟆功·倾巢 "Toad Swarm" line4 40 KB2 cd5 |
| South Emperor | 0 一阳指 "Solar Finger" range2 single 30 cd2 ignore_damage_reduction · 1 点穴 "Acupoint Lock" range2 single 12 cd3 + no_move_next_turn · 2 先天调息 "Primal Breath" heal35 self-or-ally cd4 target_friendly · 3 六脉齐发 "Six-Pulse Volley" range3 line3 34 cd6 |
| North Beggar | 0 亢龙有悔 "Proud Dragon Regret" single 36 KB2 cd2 · 1 飞龙在天 "Flying Dragon" jump3 + 3×3@landing 22 cd3 · 2 见龙在田 "Dragon in the Field" line3 30 KB1 cd4 · 3 潜龙勿用 "Hidden Dragon" square2 self 48 KB2 cd6 · 4 打狗·绊 "Dog-Beating Trip" range2 single 18 cd2 · 5 打狗·戳 "Dog-Beating Poke" range2 single 20 cd2 · 6 打狗·封 "Dog-Beating Seal" range2 single 22 cd2 |
| Central Divine | 0 全真剑 "Quanzhen Sword" single 32 cd1 · 1 七星聚会 "Seven Stars" cross2 self 26 cd3 · 2 罡气护体 "Qi Aegis" shield50 ×3r self cd5 · 3 先天一炁 "Primal Unity" global 30 cd7 + dispel hostile buffs |

Stats: Yang Guo 360 HP / qi 180 / move 4 / init 88 / basic 30@1 · East Heretic 95 / 4 / 85 / 22@3 · West Poison 115 / 3 / 70 / 26@1 · South Emperor 100 / 3 / 76 / 24@2 · North Beggar 120 / 3 / 74 / 28@1 · Central Divine 130 / 3 / 80 / 26@1. Passives wired via `passive_id` (§5.3). 发挥度 1.3 everywhere.

### C3 — CombatManager: turn engine + resolution pipeline (`./scripts/autoload/combat_manager.gd`)

Public state (assertable surface): `current_round: int`, `phase: String` (`"IDLE"|"PLAYER_TURN"|"ENEMY_TURN"|"ROUND_END"`), `active_unit_name: String`, `turn_order: Array[String]` (snapshot names), `turn_log: Array[String]` (names appended at each turn end), `last_turn_actor: String`, `is_paused: bool`, `hazard_zones: Dictionary`.

API:
```gdscript
func _on_battle_started()                     # connected to GameManager.battle_started
func begin_turn(unit) -> void                 # §3.3 lifecycle (called by the engine)
func end_current_turn() -> void               # player (Space) and the enemy loop both call this
func execute_move_path(unit, path) -> void    # tween-awaited steps, occupancy via GridManager
func execute_action(unit, action, target, params) -> void   # "basic_attack"|"skill"; awaits tweens
func apply_damage(target, amount, source = null, is_melee = false) -> void   # pipeline §4.2
func apply_heal(target, amount) -> void
func apply_shield(target, amount, rounds) -> void
func apply_dot(target, base_tick, rounds, fa_hui_du) -> void
func apply_status(target, status_id, params) -> void
func get_fa_hui_du(gongfa) -> float           # delegates to GongfaData stub
func is_player_turn() -> bool
func toggle_pause() / pause() / unpause()     # boolean gate; debounce kept; NO time_scale
```
Removed: `request_action`, `action_queue`, `is_unit_busy`, `_drain_action_queue`, `_tick_dots`, `_process`, `QUEUE_CAPACITY`, `TWEEN_TIMEOUT_SEC` stays (watchdog for `_await_tween_safe`). Passives resolution lives here as a `match passive_id` switch: `_on_turn_start(unit)` (regen), `_modify_damage_taken(target, source, amount, is_melee) -> int` (DR tags), `_on_attack_resolved(target, source, is_melee)` (counter/reflect), `_on_health_changed_below(unit, ratio)` (一阳续命), `_before_death(target) -> bool` (先天罡气 guard; returns false when death must proceed). Signals: `round_started(int)`, `turn_started(Node)`, `turn_ended(Node)`, `phase_changed(String)`, `action_executed(Node, String)`, `damage_dealt(Node, int, bool)`, `paused()`, `unpaused()`.

### C4 — GridManager extensions (`./scripts/autoload/grid_manager.gd`)

- `get_units_in_aoe(origin, shape, size, direction, hostile_to = null)` — origin parameterized; `cross` honors arm length = size; new `adjacent` shape (8-tile ring); team filter (omit `hostile_to` for current behavior).
- New `get_tiles_in_aoe(origin, shape, size, direction) -> Array[Vector2i]` (tile-set API; used by 桃花迷阵 zone placement and landing checks).
- Everything else (BFS `get_move_range`, AStar `find_path`, occupancy, `clamp_sprite_offset`) unchanged and reused.

### C5 — Player controller (`./scripts/characters/player.gd`)

New state: `moves_left: int`, `moved: bool`, `acted: bool`, `turns_taken: int`, `skill_cooldowns: Array[int]`, `shield: int`, `statuses: Array[Dictionary]`, `status_names: Array[String]`, `energy: int`, `initiative: int`, `team: int = 0`. `begin_turn()` / `clear_this_turn_restrictions()` implemented per §3.3 (engine calls them).

Input (`_unhandled_input`, all gated on: `GameManager.get_state() == "BATTLE"`, `TutorialManager.is_input_allowed(...)`, `CombatManager.is_player_turn()`, not paused, not `is_moving`):
- WASD/arrows → one tile per press, consume 1 `moves_left`; blocked at 0 or when `no_move_next_turn` active (status check at turn start already reduced the budget; belt-and-braces re-check).
- `skill_1..skill_8` → `select_skill(index)`; gated by two-phase unlock (§5.6) and cooldown; index 7 additionally gated by HP < 50% (check at selection AND execution; HUD button disabled when HP ≥ 50%).
- `basic_attack` (J) → execute selected skill at nearest valid target in range (existing `_pick_nearest_enemy_in_range` pattern, extended: self-origin AoEs require any hostile unit in the shape; line aims toward the nearest target; jump techniques land up to 3 tiles along the path to the nearest enemy), else basic attack on adjacent enemy. Success sets `acted = true`, starts cooldown, auto-deselects. No valid target → nothing happens (no cooldown, no `acted`).
- `end_turn` (Space) → `CombatManager.end_current_turn()` (accepted any time during the player's turn).
- `pause_game` (Escape) → `CombatManager.toggle_pause()` (gated on tutorial `pause` allowance).
- Left-click targeting kept for manual play (skill vs basic attack as today).
Cooldown ticking by `delta` in `_process` is **deleted**; cooldowns are ints decremented by `begin_turn()`. `cooldowns_updated` signal kept (emitted from `begin_turn` / after skill use) for HUD overlays.

### C6 — Enemy AI (`./scripts/ai/*.gd`)

Contract change: `AIControllerBase.evaluate(enemy) -> Dictionary` — called **once per enemy turn**; returns `{move_path: Array[Vector2i], action: String, target: Node, skill_index: int, params: Dictionary}` or `{}` (wait). Move path ≤ `move_range` tiles, computed with `GridManager.find_path` / `get_move_range`, each step validated walkable + unoccupied at execution. No `delta`, no busy-guards, no RNG — **every rule is a deterministic priority list over cooldown/range/HP facts** (required for the terminal scenario).

Per-enemy deterministic rules (implementer contract; exact conditions as listed):
- **Common:** evaluate techniques in the listed priority; if any ready technique's conditions hold → use it (move path first if needed to enter range, then action). Else if in basic-attack range → basic attack. Else move along the A* path toward the player up to `move_range` (stopping when in basic range, then attack). Else wait.
- **East Heretic:** 碧海潮生 (always when ready) > 落英缤纷 (player within 3) > 玉箫点穴 (within 3) > 桃花迷阵 (cooldown ready and player within 2) > basic 22@3 > move to keep distance 2–3 (retreat if adjacent).
- **West Poison:** 蛤蟆功·倾巢 (player in a cardinal line within 4) > 灵蛇缠身 (adjacent) > 毒砂掌 (adjacent) > basic 26@1 > 蛤蟆蹲 (ready and player beyond attack range but within move_range + 1: stand and charge) > move toward player.
- **South Emperor:** 先天调息 (self hp < max, else lowest-HP%-ally, ties → registration order; skip if all full) > 一阳指 (within 2) > 点穴 (within 2) > 六脉齐发 (player in a cardinal line within 3) > basic 24@2 > move toward player.
- **North Beggar:** 潜龙勿用 (player within 2) > 亢龙有悔 (adjacent) > 见龙在田 (cardinal line ≤ 3) > 飞龙在天 (within 3, valid landing) > 打狗·封/戳/绊 (within 2, highest damage first) > basic 28@1 > move toward player.
- **Central Divine:** 罡气护体 (ready and (hp < max or player within 2)) > 先天一炁 (ready) > 七星聚会 (player within 2) > 全真剑 (adjacent) > basic 26@1 > move toward player.

`fsm_state` is retained and set from the decision (`"APPROACH"|"ATTACK"|"SKILL"|"RETREAT"|"WAIT"`) for surface observability.

### C7 — HUD (`./scripts/ui/hud.gd`, `./scripts/ui/skill_button.gd`, `./scenes/ui/hud.tscn`, `./scenes/ui/skill_button.tscn`)

- **SkillBar:** 8 buttons created programmatically by `hud.gd` with explicit names `SkillButton1..SkillButton8` (remove the two pre-instanced buttons from `hud.tscn`; deterministic surface names). Button layout (skill_button.tscn restructure): hotkey label (top-left), name label, `FahuiLabel` ("OVERDRIVE x1.3"), `CooldownOverlay` (gray fill; fraction = remaining/total rounds). Width ~104 px each so 8 fit the 960 px viewport in one bottom-center row.
- **Button states:** disabled when (a) phase-locked (indices 4–7 during rounds 1–3, §5.6), (b) on cooldown, (c) index 7 and HP ≥ 50%. `skill_button.gd` observables: `skill_index: int`, `fahui_text: String`, `disabled` (built-in), `text` (built-in = technique name).
- **RoundIndicator** (new Control in `hud.tscn`, top-center): shows "Round N", "Active: <name>", "Order: <names>". Script vars for the surface: `current_round: int`, `active_actor: String`, `order_names: Array[String]`; refreshed each frame by `hud.gd _process()` from `CombatManager`.
- **EnergyLabel** (new Label): "Qi: 180" from `player.energy` (display only — no costs; design 10_systems §1).
- All new HUD strings are **English + digits only** (no CJK glyphs introduced this run). `health_bar.gd`, `pause_button.gd` unchanged.

### C8 — Input config, tutorial, state wiring (`./project.godot`, `tutorial_manager.gd`, `game_manager.gd`)

- `[input]` additions: `skill_3..skill_8` (physical keycodes 51..56 — digits 3..8), `end_turn` (Space, physical 32), `tutorial_next` (Enter, physical 4194309). Keep `move_*`, `basic_attack` (J), `pause_game` (Escape), `skill_1`, `skill_2`, built-in `ui_accept`. `project.godot` description updated to turn-based.
- **TutorialManager:** step texts rewritten in English for the new verbs (movement budget, J = attack, 1–8 techniques, Space = end turn, Escape = pause). 7 steps kept: WELCOME(0), MOVEMENT(1), BASIC_ATTACK(2), SKILLS(3), END_TURN(4), PAUSE(5), COMBAT_START(6). `_allowed_actions` mapping updated: after MOVEMENT `["move"]`; after BASIC_ATTACK `+ "basic_attack"`; after SKILLS `+ "skill_1".."skill_4"`; after END_TURN `+ "end_turn"`; after PAUSE `+ "pause"`. Advance on `ui_accept` OR `tutorial_next` (keeps the existing harness key and the design's Enter mapping). Skip still unlocks everything.
- **GameManager:** no logic change — `battle_started` already emitted; `CombatManager._ready()` connects to it. Win/loss stays auto-driven (`unregister_enemy` empty → win; `_handle_death` player → loss).

### C9 — Playtest contract (`./playtest_spec.yaml`) — full rewrite, §8.

### C10 — Docs (`./README.md`)

Update: turn-based description, controls table (WASD/arrows move with a 4-tile budget, 1–8 select technique, J execute, Space end turn, Enter advance tutorial, Escape pause), HUD description (round indicator, 发挥度 labels), no new assets.

---

## 6. Design Changes & Interpretations (declared, per design/README.md rules)

### 6.1 Design changes (content gaps the record left open — will be folded into the record by `5_design`)

1. **打狗棒法 three techniques pinned:** 绊 18 / 戳 20 / 封 22 damage, each range 2, single-target, cooldown **2 rounds**, no status effects. (Record: "各 18~22 伤害, 射程 2" — no per-skill values or cooldowns; a range is not assertable, so exact values are required.)
2. **发挥度 HUD labels rendered in English** — `ERRATIC` / `NORMAL` / `OVERDRIVE` + multiplier (brief's English-only constraint); the record's 失常/正常/超常 semantics are unchanged.
3. **Tutorial step texts rewritten** (English; new verbs) — the old texts describe the removed RTWP skills.

### 6.2 Interpretations (consistent readings of the record, no number changes)

1. 发挥度 does not apply to 普攻, 弹指神通 counter, or 蛤蟆反震 reflect — they are not 功法-produced techniques (record §4: "该功法产出的全部招式").
2. Initiative = the 身法 value (record §1: 先攻由身法决定; 20_content lists identical values).
3. Enemy 内力值 not listed in the record → energy field exists but only the player's 180 is displayed.
4. 桃花迷阵: −2 applies to the entering unit's current-turn remaining movement; the zone's "3 rounds" is its own lifetime, decremented at the caster's turn start.
5. Melee = Chebyshev distance ≤ 1 at resolution time (drives 神雕之力 and 蛤蟆反震).
6. 蛤蟆蹲 ×1.5 composes with 发挥度 on the attack side before the single `round()`.
7. Jump techniques displace up to 3 tiles along the A* path toward the nearest enemy; invalid landing → skill not consumed.
8. Status durations (shield 3, init −20 2, poison rounds) decrement at the owner's turn start; "next turn" restrictions apply at the victim's next turn start and clear at that turn's end.
9. DoT tick damage is captured (base × 发挥度, rounded) at application time.

---

## 7. File-Level Change Specification

| File | Change | Risk |
|---|---|---|
| `./scripts/data/gongfa_data.gd` | NEW Resource per C1 | Low |
| `./scripts/data/character_data.gd` | add initiative/energy/arts/passive/team fields | Low |
| `./scripts/data/skill_data.gd` | retype cooldown→int; + dot_rounds, aoe_origin, adjacent shape, shield, jump, status, gates | Low (no surface refs) |
| `./scripts/battlefield.gd` | content factory rewritten to design/20_content.md | Medium (numbers are the contract) |
| `./scripts/autoload/combat_manager.gd` | turn engine + pipeline (largest change; §3–§4) | High |
| `./scripts/autoload/grid_manager.gd` | AoE origin/size/shape/team extensions + tile API | Low-Medium |
| `./scripts/characters/player.gd` | turn budgets, 1–8 input, Space, gates | Medium |
| `./scripts/characters/enemy.gd` | remove AI timer; turn state; `begin_turn` | Medium |
| `./scripts/ai/ai_base.gd` + 5 subclasses | per-turn decision contract | Medium |
| `./scripts/ui/hud.gd`, `./scripts/ui/skill_button.gd` | 8 buttons, 发挥度 label, RoundIndicator, EnergyLabel | Low-Medium |
| `./scenes/ui/hud.tscn`, `./scenes/ui/skill_button.tscn` | button restructure, RoundIndicator/EnergyLabel nodes | Low |
| `./project.godot` | input actions, description | Low |
| `./scripts/autoload/tutorial_manager.gd` | English steps, allowed actions, tutorial_next | Low |
| `./scripts/autoload/game_manager.gd` | no change required (verify only) | — |
| `./playtest_spec.yaml` | full rewrite (§8) | — |
| `./README.md` | controls/turn-based docs | Low |

No new assets, no new scenes, no new autoloads, no asset regeneration (all existing sprites/audio reused; HUD text is engine-rendered).

---

## 8. Playtest Contract (scene / actions / surface + scenario skeletons)

Architect owns the observable surface + skeletons; **PM fills assert thresholds and final frames.**

```yaml
scene: "res://scenes/main.tscn"

actions:            # all must exist verbatim in project.godot [input]
  - move_up
  - move_down
  - move_left
  - move_right
  - skill_1
  - skill_2
  - skill_3
  - skill_4
  - skill_5
  - skill_6
  - skill_7
  - skill_8
  - basic_attack
  - end_turn
  - pause_game
  - ui_accept

surface:            # hard contract — node names + script variable names verbatim
  CombatManager: [current_round, phase, active_unit_name, turn_order, turn_log, last_turn_actor]
  GameManager: [current_state]
  Player: [health, max_health, grid_pos, moves_left, moved, acted, turns_taken,
           selected_skill_index, skill_cooldowns, shield, status_names, energy, sprite_top]
  East_Heretic:   [health, max_health, grid_pos, turns_taken, acted, skill_cooldowns, shield, status_names, sprite_top]
  West_Poison:    [health, max_health, grid_pos, turns_taken, acted, skill_cooldowns, shield, status_names]
  South_Emperor:  [health, max_health, grid_pos, turns_taken, acted, skill_cooldowns, shield, status_names]
  North_Beggar:   [health, max_health, grid_pos, turns_taken, acted, skill_cooldowns, shield, status_names]
  Central_Divine: [health, max_health, grid_pos, turns_taken, acted, skill_cooldowns, shield, status_names, sprite_top]
  HUD: [visible, size]
  RoundIndicator: [visible, current_round, active_actor, order_names]
  SkillBar: [visible, size, global_position]
  SkillButton1: [visible, text, fahui_text, disabled]
  SkillButton2: [visible, text, fahui_text, disabled]
  SkillButton3: [visible, text, fahui_text, disabled]
  SkillButton4: [visible, text, fahui_text, disabled]
  SkillButton5: [visible, text, fahui_text, disabled]
  SkillButton6: [visible, text, fahui_text, disabled]
  SkillButton7: [visible, text, fahui_text, disabled]
  SkillButton8: [visible, text, fahui_text, disabled]
  PauseButton: [visible, global_position]
  HealthBar: [visible, global_position, size, name_text]
  Battlefield: [board_aligned]
```

Notes for PM: array assertions (`turn_order[0]`, `status_names`, `skill_cooldowns`) depend on `Expression` array-index support — verify with the verifier; scalar fallbacks exist (`active_unit_name`, `last_turn_actor`, `current_round`, per-unit `turns_taken`). Round-based assertions read the exposed round/actor state, never wall-clock timestamps; the harness's key presses only drive the event loop forward.

### Scenario skeletons (each contains key presses; S9 reaches the terminal state)

**S1 `battle_starts_round_one_snapshot`** — 7× `ui_accept` (tutorial → BATTLE); assert `current_state == "BATTLE"`, `current_round == 1`, `active_unit_name == "Yang Guo"`, `turn_order` == [Yang Guo, East Heretic, Central Divine, South Emperor, North Beggar, West Poison], all enemy `turns_taken == 0`.

**S2 `enemy_acts_only_after_player_ends_turn`** — after S1: press `move_up` ×2, `basic_attack`; assert at the next frame active is still Yang Guo (no enemy `turns_taken`); press `end_turn`; assert after a few frames `East_Heretic.turns_taken == 1` and `active_unit_name` has advanced. *(brief: "enemy acts only after the player ends their turn")*

**S3 `each_unit_acts_once_per_round_initiative_order`** — end S1, then press `end_turn` ×6 with frame gaps (each press ends whoever is active); assert `current_round == 2`, all six units `turns_taken == 1`, `turn_log` sequence matches initiative order, and round 2's first actor is Yang Guo again. *(brief: "each unit acts exactly once per round in initiative order")*

**S4 `cooldowns_decrement_by_round`** — select `skill_1` (Heavy Edge, cd 1), execute via `basic_attack` (J), assert `Player.skill_cooldowns[0] == 1`; `end_turn` through the round; at the player's next turn start assert `== 0`. Repeat for `skill_2` (cd 2): assert 2 → (next own turn) 1 → 0. *(brief: "cooldowns decrement by round")*

**S5 `dot_resolves_at_victim_turn_start`** — scripted: `end_turn` ×N until West Poison is adjacent and uses 灵蛇缠身 (deterministic AI); assert `Player.status_names` contains poison and health is down by the direct hit only (no tick yet); `end_turn` once more; at the player's turn start assert health dropped by exactly **10** (round(8 × 1.3)), and again at the next player turn start (2-round DoT). *(brief: "DoT resolves at the victim's turn start")*

**S6 `fahui_du_1_3_applies_to_damage`** — after tutorial: move adjacent to East Heretic (no DR passive), select `skill_1`, J; assert `East_Heretic.health` dropped by exactly **58** (45 × 1.3 = 58.5 → 58, the design's canonical example), `SkillButton1.fahui_text == "OVERDRIVE x1.3"`, and all 8 buttons' `fahui_text` is `"OVERDRIVE x1.3"`. *(brief: "the 发挥度 multiplier (1.3 × base) actually applies to damage")*

**S7 `two_phase_skill_unlock_and_hp_gate`** — rounds 1–3: `SkillButton5..8.disabled == true` (palm arts locked) while `SkillButton1..4` enabled; on `current_round == 4`: buttons 5–8 enabled; while `Player.health >= 180` (50% of 360): `SkillButton8.disabled == true` (Seventeen Forms HP gate) — later, after HP drops below 180, assert it enables.

**S8 `central_divine_innate_qi_fatal_guard`** *(recommended extra)* — bring Central Divine low via scripted attacks, land a lethal blow; assert `Central_Divine.health == 1` (not dead), `status_names` emptied of negatives, and a second lethal blow kills him.

**S9 `terminal_victory_8_12_rounds_hp_15_40`** *(REQUIRED — reaches endgame)* — full scripted play: 7× `ui_accept`, then per-round key timeline implementing the design's lure-and-cluster strategy (move toward the cluster, basic attacks, 四海无量/力斩千钧 when clustered, `end_turn` each round; ~10 rounds of presses with frame gaps for tweens/AI turns). Final assert: `GameManager.current_state == "WON"`, `8 <= CombatManager.current_round <= 12`, `54 <= Player.health <= 144` (15%–40% of 360, sampled at the victory instant). *(brief terminal criterion)*

Tuning note for PM/tuner: the exact key timeline and AI thresholds must be iterated until S9 lands in-band. The **only legitimate tuning knob is AI behavior** (approach/spread/heal priority) — `design/20_content.md` numbers are authoritative; changing them requires a declared design change.

---

## 9. Technical Stack

| Concern | Choice | Rationale |
|---|---|---|
| Engine/language | Godot 4 / GDScript, existing project | Zero new dependencies; `.gd` parsed by the gate's `--check-only` |
| Turn engine | Rewritten `CombatManager` autoload (phase + round loop), event-driven player turn, await-serialized enemy turns | SOTA's "one active unit at a time, explicit phases" shape; executors already live there; no new autoload |
| Ordering | Stable initiative sort (身法 desc, registration-order tie-break), snapshot at round start | design 10_systems §5.1; Godot's `sort_custom` is unstable → implement a stable sort or decorate-sort-undecorate with registration index |
| Data | `Resource` classes built programmatically in `battlefield.gd` (+ new `GongfaData`) | Proven in-repo pattern; no `.tres` files |
| Animation serialization | `Tween` + `await tween.finished` via existing `_await_tween_safe` watchdog | Proven in-repo; dead-node tween never hangs the loop |
| AI | RefCounted controllers, `evaluate(enemy)` once per turn, priority-list rules, zero RNG | Deterministic terminal scenario requires zero RNG |
| HUD | Engine Controls; per-frame polling in `hud.gd _process` (matches existing bar-follow pattern) | No new UI framework |
| Verification | Existing harness (`run_tests.sh`) + rewritten `playtest_spec.yaml` | Brief requires the rewritten contract |

---

## 10. Migration & Rollback Plan (irreversible-op safety)

All changes are file edits (git-reversible). The RTWP machinery is removed, not data-migrated — the ordering constraint applies to the *deletion of the real-time path*:

1. **Baseline:** commit (or `cp` `.bak`) before starting; every medium/high-risk file is backed up. Backups never ship.
2. **Execute in dependency order** (§11 T1→T10), each task touching disjoint files where possible; run the compile gate + `run_tests.sh` after **every** task.
3. **Deletions gated:** the action queue / timer AI / seconds cooldowns are removed **in the same edit** that lands their replacement (turn loop, per-turn AI, int cooldowns) — never a standalone delete; the old playtest spec is replaced only when the new one is written and the game boots under it.
4. **Verify new state:** per-task gate green; after T9 the full scenario set (S1–S9) must pass; final manual check: F5 open-and-play (960×704, HUD visible, Space ends turn).
5. **Rollback:** `git checkout -- <file>` per task (disjoint files → component-local rollback, no cross-file undo ordering). No schema, no assets, nothing non-reversible.

---

## 11. Suggested Task Decomposition for PM (ordered; each ends with a gate)

1. **T1 — Data layer:** `gongfa_data.gd` (new), `character_data.gd`, `skill_data.gd` per C1. *Gate: `--check-only` green.*
2. **T2 — Content factory:** `battlefield.gd` data factories per C2/design numbers; unit registration order preserved. *Gate: compile + boot; Player.max_health == 360.*
3. **T3 — Turn engine + pipeline:** `combat_manager.gd` per §3–§4 (round loop, lifecycle, two-stage pipeline, statuses, passives, fatal guard, hazard zones); `game_manager.gd` wiring (connect `battle_started`). *Gate: compile + boot; round 1 snapshot correct with the old input mocked.*
4. **T4 — GridManager AoE:** origin/size/shape/team extensions + tile API. *Gate: compile.*
5. **T5 — Player controller:** budgets, 1–8, J, Space, gates per C5. *Gate: compile + S1/S2 keyable.*
6. **T6 — AI rework:** base + 5 subclasses per C6. *Gate: compile + S3/S5 keyable (deterministic enemy turns).*
7. **T7 — HUD:** skill buttons ×8 + 发挥度, RoundIndicator, EnergyLabel, scene edits. *Gate: compile + S6/S7 surface resolvable.*
8. **T8 — Input/tutorial:** `project.godot` actions, `tutorial_manager.gd` texts/gating. *Gate: compile + full tutorial key-through.*
9. **T9 — Playtest contract:** rewrite `playtest_spec.yaml` (S1–S9, PM thresholds), iterate the S9 key timeline until in-band. *Gate: full `run_tests.sh` green.*
10. **T10 — Docs:** `README.md`. *Gate: compile.*

---

## 12. Extensibility Considerations

- **New gongfa/content:** add `GongfaData` resources and technique tables in the factory; the engine reads data, not constants. The prerequisite calculation slot (`get_fa_hui_du`) is where the real 甲乙丙丁 cascade lands later.
- **New passives:** add a `passive_id` + a branch in the pipeline hook switches (`_on_turn_start`, `_modify_damage_taken`, `_on_attack_resolved`, `_before_death`) — no engine restructuring.
- **New statuses:** the per-unit status table + `begin_turn` ticker + hazard-zone table generalize to arbitrary round-based effects.
- **Future RTWP-like features are out:** the queue/timer path is deleted, not kept dormant — future pacing features should extend the turn phases, not resurrect timers.
- **Elemental counters (属性相克):** deliberately absent (design 90_decisions); the `attribute` field is data-only for the prerequisite system.

---

## 13. Non-Goals (explicit)

- No progression, school selection, world map (undesigned — design/90_decisions.md).
- No learning/cultivating 功法 and no real prerequisite calculation (interface stub only).
- No Chinese font / CJK UI text additions; existing CJK strings (end-game overlay) untouched; name truncation and `board_aligned`-class UI defects deferred.
- No elemental counter system.
- No new art/audio assets; no new scenes except HUD node edits; no new autoloads; no third-party addons (no GUT, no turn-system plugins).

---

## 14. Assumptions for Downstream Steps

1. The gate runs headless at the project's 960×704 base size; the harness is wall-clock driven, so round-based assertions must read `CombatManager` state, not timestamps. Enemy turns take ~1–2 s wall-clock (5 units × tween awaits); PM sizes frame gaps accordingly.
2. `Expression` assertions evaluate plain script variables on live nodes; arrays may or may not be indexable — PM verifies and uses scalar fallbacks (§8 note).
3. GDScript `round()` uses double arithmetic: the design's canonical 45 × 1.3 → 58.5 → **58** must hold (it does: 58.4999…). Implementers compute `round(v * 1.3)`; never `int(v * 1.3 + 0.5)` by hand.
4. `ui_accept` (Space/Enter) and `end_turn` (Space) coexist: `TutorialManager` consumes `ui_accept` only while `is_active`; the player's `end_turn` handler gates on `GameManager.get_state() == "BATTLE"` and its own turn.
5. Balance target (8–12 rounds, 15–40% HP) is reachable by tuning AI behavior only; if it proves unreachable, this is reported to the user as a design conflict, not silently fixed by changing content numbers.
6. Deterministic enemy registration/iteration order is East Heretic, West Poison, South Emperor, North Beggar, Central Divine (battlefield dictionary insertion order) — it is the initiative tie-break order and the heal-target tie-break order.

---

## 15. Design Decisions Log

- **D1 — Turn engine lives in `CombatManager`, no new autoload.** The executors and damage pipeline already live there; a sibling `TurnManager` would duplicate coupling. The phase/round state is plain observable variables (surface-assertable).
- **D2 — Stable initiative sort with registration-order tie-break.** `sort_custom` is unstable; 碧海潮生 can create ties mid-battle, so a decorate-sort-undecorate on (initiative desc, registration index asc) is mandatory for deterministic playtests.
- **D3 — Cooldowns are ints, decremented at the unit's own turn start** (design 5.2). "Cooldown 1" = usable every other own-turn.
- **D4 — Turn-start lifecycle order fixed:** cooldowns → DoT/status ticks → regen → act (design 5.2). Assertable via DoT timing in S5.
- **D5 — Two-stage rounding** per design 4.3: attack side `round(base × buffs × 发挥度)` → defense side `round(output × (1 − DR))`. 发挥度 never touches cooldown/range/KB/duration.
- **D6 — Melee = Chebyshev distance ≤ 1 at resolution.** Drives 神雕之力 (−20%) and 蛤蟆反震. Counter/reflect damage is untyped (no 发挥度, no DR).
- **D7 — Fatal guard (先天罡气) intercepts `apply_damage` before death handling, including DoT ticks; 一阳续命 below-40% triggers only if the unit survives the hit.**
- **D8 — AoE origins explicit (`self`/`target`/`landing`); cross arm length = size; `adjacent` = 8-tile ring; damage AoEs filter hostile units via a new `team` field.**
- **D9 — Jump techniques displace without consuming the move budget; invalid landing → not consumed.**
- **D10 — Player may act then move; enemies always move-path → action.** Space ends the turn regardless of remaining budget.
- **D11 — Pause = boolean gate, no `Engine.time_scale`** (turn-based flow is event-driven; freezing tweens buys nothing and risks the tween watchdog).
- **D12 — Zero RNG in AI** — priority lists over cooldown/range/HP facts; the terminal scenario is reproducible by construction.
- **D13 — 内力 180 stored and displayed, never consumed** (design 10_systems §1; no technique has a cost).
- **D14 — Skill bar always shows all 8 buttons; palm arts (5–8) disabled until round 4; Seventeen Forms additionally HP-gated** (checked at selection AND execution, mirrored on the button).
