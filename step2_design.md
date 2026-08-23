# 技术架构设计 — 养成真的有意义 (Real Fa-Hui-Du, Fillable Ladders)

Project: 养成真的有意义 — 发挥度真算、阶梯真的填得起来
Repo: Godot 4.4, GDScript, single-player wuxia cultivation + turn-based tactics.
All file paths in this document are relative to the repo root (write paths, no `project/` prefix).

## 1. Overview

The SOTA report established the real state of the codebase (the fa-hui-du cascade is already implemented; the "stub returns 1.3" premise is stale). This round's actual work:

1. **Remove the `staged_values` bypass entirely** and make the tutorial's protected 1.3 values emerge from the real cascade via **real mastered filler arts** (the brief forbids the 特判 short-circuit; protected playtest values must stay byte-identical).
2. **Complete the progression ladder with 甲级 (A) rows**: A-grade arts for the four external ladders (sword / palm / polearm / dart) and the five sects' internal ladder, real technique names replacing the 一式/二式/三式 stubs, `PRACTICE_TO_MASTER["A"]`, and a legal in-game way to obtain an A art (the 神功 card, design/40_progression §3.6).
3. **Decide the 修习 lookup table** (the open Architect decision in design/90_decisions.md) and implement it through the single seeded RNG.
4. **Encounter battles**: a real CULTIVATION → BATTLE → WON → CULTIVATION path so cultivation changes combat *visibly* (the round's thesis).
5. **Trait hooks**: 杀 / 破 / 狼 / 铁布衫 / 身轻如燕 / 左右互搏 get real engine effects (first trait implementations ever).
6. **Save roundtrip observability** and **sect-switch observability** so the two new playtest scenarios can assert full equality / continuity.
7. **Two new playtest scenarios** (`cultivation_changes_combat`, `sect_switch_same_school_connects`) + extended `save_load_roundtrip` + trait scenarios, with new additive DEBUG actions and surface vars — existing 20 scenarios and all protected asserts stay byte-identical.

**Non-goals this round:** the other seven traits (无师自通 / 骨骼清奇 / 过目不忘 / 旧伤 / 心魔 / 孤煞 / 筋骨迟钝 / 江湖阅历 / 福缘深厚 — hooks stay data-only; 孤煞's existing lone_bane implementation is untouched), the 轻功 ladder (explicitly out of scope), companions, map content, and the three 遗留 failing scenarios (dot_resolves_at_victim_turn_start 2/8, each_unit_acts_once 6/12, terminal_victory 4/6 — do not touch).

## 2. Design-consistency notes and 设计变更 (design changes)

Per `design/README.md`, every conflict with the design archive is declared here; `5_design` will apply these to the archive after final verification passes.

1. **设计变更 — ladder set (40_progression §3.7).** The archive says 首批填满阶梯的门类 = 剑、拳掌、轻功. The implemented data (ProgressionGongfaData.SECTS) already provides 拳掌/剑/长兵/暗器 lines — matching all five sect start arts (罗汉拳/太极剑/峨眉剑法/打狗棒法/满天花雨) — and the SOTA report declares 轻功 out of scope. **Change: the filled ladders are 剑 / 拳掌 / 长兵 / 暗器 (external) + 内功 (internal, 5 sect lines); 轻功 is not filled this round.**
2. **Design decision recorded — 修习 lookup table (90_decisions "谁来定:架构").** Final table in §4.1. This closes the open question.
3. **Design decision recorded — 破 semantics.** 破军 ("功法修习经验 +50%") applies to **gongfa practice experience** (练功 +1 and every `practice`-type card/event amount through `_add_practice`), NOT to attribute 修习 gains. Amounts are `round(amount × 1.5)` (half-away-from-zero): 1→2, 2→3, 4→6, 6→9. No extra RNG.
4. **Design decision recorded — A-grade content rows** (§4.2–§4.3): the 4 external A arts + 5 internal A arts, their attributes, and technique rows. External A attributes are deliberately chosen **not to equal any feeding sect line's attribute** so a completed 3-year ladder lands exactly at 1.0 (design §3.3 "1.0 起步") and the climb toward 1.3 stays a real pursuit; internal A arts keep their sect line's attribute so a full internal line can reach 1.3 (internal is 自成一类, 家家都教 — the generous lane).
5. **Design decision recorded — 神功 card effect** (40_progression §3.6): grants one **random unowned A art** from the 9-row A pool (4 external + 5 internal), one `SaveManager.rng` draw in operation order. A player whose ladder doesn't match gets a 0.6~0.7 artifact — exactly the design's "用不好的神兵".
6. **Design decision recorded — tutorial 编排数值 implementation.** 20_content.md says tutorial units' prerequisites are "视为已满" (treated as complete). That is now *implemented*: each tutorial unit's CharacterData is populated with real mastered filler arts (B/C/D same-school + same-attribute) by a shared pure helper, and the `staged_values` marker is deleted from CharacterData / gongfa_data / README / tests. Numbers are unchanged (`round(v × 1.3)` everywhere, exactly as before).
7. **Design decision recorded — encounter defeat routing.** For encounter battles (battle_return_state = a segment state), LOST routes back to the return state (no death penalty designed yet) instead of hardcoded TUTORIAL. Tutorial LOST behavior unchanged.
8. **Design decision recorded — 12-slot skill bar layout** (40_progression §9 + §2.2 左右互搏): default stays 2 arts / 8 slots; with 左右互搏, up to 3 arts / 12 slots. Layout = **two rows of 6 buttons** (each button keeps the audited 104 px width; row 2 holds buttons 7–12). Hotkeys skill_9..skill_12 are added as input actions (keys 9 / 0 / minus / equal); 1–8 unchanged.
9. **Note (no change needed):** 40_progression §9's "技能栏 8 格…不再上调" is the *default*; the trait modifies it. This is the design's own §2.2 rule, not a conflict.

## 3. Architecture diagram (text)

```
                        ┌────────────────────────── CULTIVATION (cultivation.gd) ──────────────────────────┐
                        │  month loop: YEAR_AUGMENT / CARD_PICK → _apply_card → ACTION_PICK → _after_action │
  SaveManager.rng ──────┤    shen_gong card → ProgressionGongfaData.a_pool() → random unowned A art        │
  (single stream)       │    cultivate → TraitEffects.practice_gain(wisdom, rng.randf())  [修习查表]        │
                        │    practice  → _add_practice(round(amt × 1.5 if 杀破狼))          [破]            │
                        │    DEBUG: debug_step_month / debug_grant_art / debug_enter_encounter             │
                        └───────────────┬───────────────────────────────┬──────────────────────────────────┘
                                        │ debug_enter_encounter         │ WON→CULTIVATION (request_continue)
                                        ▼                               ▲
                       GameManager.start_encounter(): CULTIVATION → BATTLE; battle_return_state="CULTIVATION"
                                        │                               │
                                        ▼                               │
                 battlefield.gd _ready: mode = return_state=="CULTIVATION" ? ENCOUNTER : TUTORIAL
                                        │
        ┌───────────────────────────────┴──────────────────────────────────┐
        │ ENCOUNTER mode:                                                  │
        │   player  = BattleSetup.build_character(SaveManager.profile)     │
        │             → CharacterData { stats via design §7 formulas,      │
        │               arts mirrored (mastered flags), equip ≤2/≤3 arts,  │
        │               traits copied }                                    │
        │   enemy   = EncounterData.sparring_partner() (fixed CharacterData)│
        │   TutorialManager never starts (is_input_allowed = not is_active)│
        │ TUTORIAL mode (unchanged numbers):                                │
        │   content factory builds 6 units, then TutorialFillers.fill(cd)   │
        │   replaces the staged_values loop: real mastered B/C/D fillers +  │
        │   mastered=true on every art ⇒ cascade computes 1.3 for every art │
        └───────────────────────────────┬──────────────────────────────────┘
                                        ▼
                  CombatManager — turn engine + resolution pipeline
     get_fa_hui_du(gongfa, unit_cd) → GongfaData.get_fa_hui_du (pure cascade, no staged branch)
     apply_damage: attack output (base × fhd × 狼 mult → round) → defense (× (1−DR−狼DR) → round)
                   → shield → HP → fatal guard (先天罡气 / 铁布衫) → 杀 lifesteal → counters
                                        │
                                        ▼
                  HUD (hud.gd): buttons per equipped skills (8 or 12, two rows),
                  fahui_text from cascade; states data-driven (tutorial flag, hp_gate from SkillData)
```

## 4. Architect-decided numbers (authoritative for implementers)

### 4.1 修习 lookup table (final; closes 90_decisions)

One `SaveManager.rng.randf()` draw per 修习, mapped to +1/+2/+3 by 悟性 tier (cumulative thresholds). `roll = rng.randf()`; tier table:

| 悟性 tier | +1 | +2 | +3 | expected |
|---|---|---|---|---|
| ≤ 15 | 60% | 30% | 10% | 1.50 |
| 16–25 | 35% | 45% | 20% | 1.85 |
| 26–35 | 20% | 50% | 30% | 2.10 |
| ≥ 36 | 10% | 45% | 45% | 2.35 |

Pure helper (unit-testable, no autoload deps): `TraitEffects.practice_gain(wisdom: int, roll: float) -> int`. The caller draws the roll from `SaveManager.rng` — exactly one rng op per 修习, same op count as the old `randi_range(1,3)`, so determinism discipline is preserved (existing tests assert gain ∈ 1..3 and same-seed equality — still true).

### 4.2 Grade tables extended (ProgressionGongfaData)

- `GRADE_SUFFIX["A"] = "a"`, `GRADE_STEP["A"] = "圆满"` (display: `易筋经·圆满`).
- `PRACTICE_TO_MASTER["A"] = 10` (continuing D4/C6/B8/+2).
- `TECHNIQUE_COUNT["A"] = 4`; `TECHNIQUE_DAMAGE["A"] = 30` (continuing 18/22/26/+4) — per-technique overrides below.

### 4.3 A-grade art rows (new content; real names replace 一式/二式/三式)

**External A arts — one per school; attribute never matches that school's feeding sect lines:**

| art id (school) | name (attr) | technique | shape | dmg | rng | cd | notes |
|---|---|---|---|---|---|---|---|
| `a_sword` | 独孤九剑 (刚) | 总诀式 | single | 30 | 1 | 1 | |
| | | 破剑式 | single | 28 | 1 | 2 | `ignore_damage_reduction = true` |
| | | 破气式 | line self | 26 | 3 | 3 | |
| | | 绝招·无招胜有招 | square r2 self | 55 | — | 5 | `is_finisher = true` |
| `a_palm` | 降龙十八掌 (阳) | 亢龙有悔 | single | 30 | 1 | 1 | knockback 1 |
| | | 飞龙在天 | line self | 28 | 3 | 2 | |
| | | 见龙在田 | cross1 self | 26 | — | 3 | |
| | | 绝招·潜龙勿用 | square r2 self | 55 | — | 5 | `is_finisher`, knockback 2 |
| `a_polearm` | 杨家枪法 (刚) | 回马枪 | single | 30 | 1 | 1 | |
| | | 梨花枪 | line self | 28 | 3 | 2 | |
| | | 锁喉枪 | single | 26 | 1 | 3 | knockback 1 |
| | | 绝招·枪出如龙 | square r2 self | 55 | — | 5 | `is_finisher` |
| `a_dart` | 小李飞刀 (阴) | 例不虚发 | single | 30 | 3 | 1 | ranged (dart) |
| | | 连环飞刀 | line target | 28 | 2 | 2 | |
| | | 满天刀雨 | square r1 target | 26 | 3 | 3 | |
| | | 绝招·一刀飞仙 | square r2 target | 55 | 3 | 5 | `is_finisher` |

Feeding line attributes: sword lines are 柔(武当)/阴(峨眉) → sword A = 刚 ✓ no clash; palm line 刚(少林) → palm A = 阳 ✓; polearm line 阳(丐帮) → polearm A = 刚 ✓; dart line 柔(唐门) → dart A = 阴 ✓.

**Internal A arts — one per sect line, same attribute as the line; data-only (energy 0, passive "", stats {}) like all progression internal arts:**

| id | name (attr) |
|---|---|
| `shaolin_yijin_a` | 易筋经·圆满 (刚) |
| `wudang_chunyang_a` | 纯阳无极功·圆满 (柔) |
| `gaibang_huntian_a` | 混天功·圆满 (阳) |
| `emei_jiuyang_a` | 峨眉九阳功·圆满 (阴) |
| `tangmen_xinfa_a` | 唐门心法·圆满 (柔) |

**A pool (神功 grant pool, 9 ids):** the 4 external A ids + the 5 internal A ids. `ProgressionGongfaData.a_pool() -> Array[String]`, `a_art_for_school(school)`, `a_art_for_sect(sect_id)`. `art_by_id` / `art_id` / `display_name_of` extended to grade A.

### 4.4 Trait effect formulas (percentages never take the fhd multiplier)

Pure static math lives in `TraitEffects` (new file) so unit tests don't need a scene tree:

- **杀 (sha)**: when the owner deals damage, heal `round(actual_hp_loss × 0.20)`; cap per round `round(owner.max_health × 0.15)`; per-round heal budget keyed by owner instance id, reset at round start (mirrors `_finger_dart_used`). Lifesteal fires after the target's HP deduction and before death handling; target death doesn't cancel it. No heal on self-damage.
- **破 (pojun)**: `round(practice_amount × 1.5)` on every `_add_practice` call and every practice-typed card/event effect (see §2.3).
- **狼 (lang)**: attack side — output = `round(base × fhd × other_buffs × (1 + 0.08 × N))` where N = living enemies of the owner at resolve time; defense side — extra DR `0.05 × N` added inside `_damage_reduction` (stacks additively with 铁骨/神雕之力; still bypassed by `ignore_damage_reduction`).
- **铁布衫 (iron_shirt)**: first lethal damage per battle → owner stays at 1 HP, negative statuses cleared, flag `_iron_shirt_used[instance_id]` set (mirror `_innate_qi_used`; separate dictionary; reset in `reset_battle`).
- **身轻如燕 (swallow_lightness)**: when the player's single-tile move targets an enemy-occupied tile AND the tile beyond is walkable and free AND `moves_left >= 2`: consume 2 movement, slide through to the far tile (never landing on the enemy tile). GridManager occupancy updated only for the departure and landing tiles; the enemy's tile occupancy is untouched.
- **左右互搏 (ambidextrous)**: equipment cap 3 external arts (12 slots) instead of 2 (8 slots). Layout two rows × 6 (§2.8).

## 5. Component list & interfaces

### C1 — `scripts/data/progression_gongfa_data.gd` (MODIFIED, pure data)
Grade table extensions (§4.2) + A-grade rows (§4.3). New static API (all return fresh Resources, null on unknown):
- `a_pool() -> Array[String]`
- `a_art_for_school(school: String) -> Resource`
- `a_art_for_sect(sect_id: String) -> Resource`
- `art_by_id(id)` / `art_id(...)` / `display_name_of(id)` extended to A.
External A techniques are real SkillData rows with the table's shapes/damages; internal A arts are data-only. Keep the existing "no class_name typing" rule (GongfaData/SkillData are preloaded constants).

### C2 — `scripts/data/trait_effects.gd` (NEW, pure static)
`practice_gain(wisdom: int, roll: float) -> int` · `lang_attack_mult(living_enemies: int) -> float` · `lang_dr(living_enemies: int) -> float` · `sha_heal_amount(loss: int, max_hp: int, healed_this_round: int) -> int` · `pojun_practice(amount: int) -> int`. No autoload references; all float math via `round()` (half-away-from-zero).

### C3 — `scripts/data/tutorial_fillers.gd` (NEW, pure static)
`fill(unit_cd) -> void`: for every art on the unit (internal+external), for every lower-grade same-school slot with no mastered art present, append a fresh filler GongfaData (grade/school/attribute cloned from the art, empty techniques, `mastered = true`); then set `mastered = true` on every art the unit already carries. Pure data → unit-testable; battlefield and tests share the same code path. This replaces the staged bypass: after `fill`, `get_fa_hui_du` computes 1.3 for every tutorial art (cascade complete + ≥3 same-attribute mastered arts per attribute group — each unit's fillers share its arts' attributes).

### C4 — `scripts/data/character_data.gd` (MODIFIED)
- **DELETE** `staged_values` (the forbidden 特判).
- **ADD** `@export var traits: Array[String] = []` (battle-side trait carrier).

### C5 — `scripts/data/gongfa_data.gd` (MODIFIED)
Remove the `unit.staged_values → return fa_hui_du` branch from `get_fa_hui_du`; the `unit == null` fallback stays. Doc comment updated (no more 编排数值 mention).

### C6 — `scripts/data/battle_setup.gd` (MODIFIED)
- Drop the `staged_values` assignment and its comment.
- `build_character(profile)`: `cd.traits = profile.traits.duplicate()`; external arts sorted by grade rank (A first, via `GongfaData.GRADE_RANK`), equip the first **2** arts (no ambidextrous) or first **3** (ambidextrous); `skills` = concatenated techniques of equipped arts only; mastered flags mirrored from profile as today.

### C7 — `scripts/data/encounter_data.gd` (NEW, pure data)
`sparring_partner() -> Resource` — fixed CharacterData: `character_name "Sparring Partner"`, `display_name "陪练弟子"`, hp 60, attack 12, move 2, initiative 3, melee, start tile (7,4) (adjacent to the player's (7,5)), team 1, `ai_class "AIControllerSparring"` (new tiny AI or reuse a melee one — implementer picks an existing melee AI class; must not require tutorial content). Arts: one mastered D internal art (attribute `阳`) + one mastered D external art (same attribute, no techniques needed) + two mastered D filler arts of the same attribute → its basic-attack fhd is exactly `1.0 + 0.1×3 = 1.3` regardless of engine defaults (deterministic; PM computes cooked numbers from these inputs). `sparring_partner_tile() -> Vector2i`.

### C8 — `scripts/battlefield.gd` (MODIFIED)
- Tutorial mode: after building the six units, call `TutorialFillers.fill(cd)` for each; delete the `staged_values = true` loop. Set `CombatManager.tutorial_battle = true`. Wire `traits` onto player/enemy nodes (same guarded `in` pattern as initiative/energy).
- Encounter mode (when `GameManager.get_battle_return_state() == "CULTIVATION"`): build player via `BattleSetup.build_character(SaveManager.profile)`; instantiate via the existing `_instantiate_player`-style flow; spawn `EncounterData.sparring_partner()` at its tile; **do not call `TutorialManager.start`**; `CombatManager.reset_battle()` and `GameManager.start_battle`-equivalent transition are driven by `GameManager.start_encounter()` (see C9). All AI/hazard/status wiring stays shared.

### C9 — `scripts/autoload/game_manager.gd` (MODIFIED)
- `start_encounter() -> void`: if `current_state == "CULTIVATION"`: set `battle_return_state = "CULTIVATION"`, `current_state = "BATTLE"`, emit `battle_started` + `state_changed("BATTLE")` (SceneManager already routes on this state).
- `request_retry()`: destination = `battle_return_state` when it is a segment state, else TUTORIAL (mirrors `request_continue`).
- DEBUG actions (unbound, harness-only, in `_process`): `debug_enter_encounter` → `start_encounter()` (no-op outside CULTIVATION). (`debug_win_tutorial`/`debug_lose_tutorial` reuse the existing pipeline hooks — verified they work for any active battle.)

### C10 — `scripts/segments/cultivation.gd` (MODIFIED)
- `_apply_card`: implement `"shen_gong"` — `pool = ProgressionGongfaData.a_pool()` minus owned ids; if non-empty: `pick = pool[SaveManager.rng.randi_range(0, pool.size()-1)]`; `SaveManager.profile.add_gongfa(pick, "A")`. (`"tech_unlock"` and `""` remain pass.) Note: this adds one rng op when the card is drawn — test_cultivation's fast-forward test (seed 4242, asserts `gongfa_count == 6`) must be updated to tolerate a granted A art (recompute expected count from the profile).
- `_apply_action` cultivate: `var roll = SaveManager.rng.randf(); var gain = TraitEffects.practice_gain(profile.get_attr("wisdom"), roll)`.
- `_add_practice(amount)`: if `profile.has_trait("sha_po_lang")`: `amount = TraitEffects.pojun_practice(amount)`; mastery threshold unchanged (`PRACTICE_TO_MASTER`, now incl. A=10).
- New DEBUG actions: `debug_step_month` → advance exactly one month through the same phase machine with fixed auto-choices (card 0; 练功 first unmastered else 修习 根骨; year-end stay), stopping after the month completes (re-usable N times; no-op outside CULTIVATION). `debug_grant_art` → grant the A art of `main_external_id`'s school (fallback: the sect's internal A) via `add_gongfa(id, "A")`.
- New surface vars (additive, synced in `_sync_surface`): `gongfa_ids: Array[String]`, `gongfa_grades: Array[String]`, `gongfa_names: Array[String]` (grant order).

### C11 — `scripts/autoload/combat_manager.gd` (MODIFIED)
- `tutorial_battle: bool = false` (set by battlefield tutorial mode; reset in `reset_battle`).
- `_traits_of(unit) -> Array[String]` (node.traits or character_data.traits; both may be absent → []).
- 狼: attack-side mult applied where attack output is computed (after fhd, before the attack-side `round`); defense-side term inside `_damage_reduction` (`+ 0.05 × enemies_alive` when owner has sha_po_lang).
- 杀: in `apply_damage` after HP deduction / fatal-guard resolution: if source alive and has sha_po_lang and source != target: `heal = TraitEffects.sha_heal_amount(actual_loss, source.max_health, _sha_round_healed[src_id])`; `apply_heal(source, heal)`; accumulate counter. Counter reset in `_begin_round` (with `_finger_dart_used`) and `reset_battle`.
- 铁布衫: in the fatal-guard section: `is_lethal and traits.has("iron_shirt") and not _iron_shirt_used.get(id, false)` → hp 1, clear negative statuses, set flag (mirror innate_qi, separate dict, reset in `reset_battle`).
- New surface: `debug_sha_heal_total: int`, `debug_iron_shirt_procs: int`, `debug_lang_attack_mult: float` (last applied 狼 attack mult; 1.0 default).
- Do NOT touch the three 遗留 failing scenarios' logic.

### C12 — `scripts/characters/player.gd` (MODIFIED)
- 身轻如燕 slide-through in `_try_move` (§4.4) — requires `moves_left >= 2`; uses `GridManager.is_occupied(target)` + `GridManager.is_walkable(beyond)`; occupancy ops via `GridManager.move_unit(self, from, beyond)`.
- Hotkey handling extended: skill_9..skill_12 select indices 8..11 (bounds-safe); the two-phase palm unlock gate in `_skill_selectable`/HUD stays tutorial-only.

### C13 — `scripts/autoload/tutorial_manager.gd` (MODIFIED)
`is_input_allowed(action)` returns **true when `not is_active`** (encounter battles never start the tutorial; the gating list only applies while a tutorial is actually running). Existing tutorial behavior unchanged (all 7 steps still gate as before).

### C14 — `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` (MODIFIED)
- SkillBar becomes a VBoxContainer with row HBoxes: `N <= 8` → one row (geometry identical to today: buttons 1–8 in a row, `skill8_right_edge` unchanged); `N > 8` → two rows × 6 (buttons 1–6 top, 7–12 bottom; each button 104 px → `skill8_right_edge = 6×104 = 624 ≤ 960` stays green; `skill12_right_edge = 624` too).
- `_populate_skill_buttons`: buttons per equipped skills (already loops `skills.size()`; no cap changes needed for 8-mode).
- `_refresh_skill_button_states`: phase lock condition becomes `CombatManager.tutorial_battle and i >= 4 and CombatManager.current_round < 4`; hp_gate becomes data-driven from `btn._skill_data.hp_gate_below_ratio` (tutorial button 8 keeps identical behavior — verified `seventeen_melancholy_forms` carries `hp_gate_below_ratio = 0.5`).
- New surface: `HUD: skill12_right_edge: float` (0.0 when absent).

### C15 — `scripts/autoload/save_manager.gd` (MODIFIED)
Roundtrip observability (additive surface; save schema unchanged — profile already persists traits/gongfa/mastered, `SAVE_VERSION` stays 1):
- `snapshot_profile_json: String`, `snapshot_rng_state: int`, `snapshot_decks_string: String` — captured from `_build_save_dict()` at every successful `save_slot`.
- `loaded_profile_json: String`, `loaded_rng_state: int`, `loaded_decks_string: String` — captured from the parsed file dict at every successful `load_slot`.
- `decks_string` format: `"cat1:a,b,c;cat2:x,y"` (DECK_CATEGORIES order, ids joined by ",").

### C16 — `project.godot` (MODIFIED)
`[input]` additions (all unbound/empty event lists except skill_9..12): `debug_step_month`, `debug_grant_art`, `debug_enter_encounter`, `skill_9` (key 9), `skill_10` (key 0), `skill_11` (key minus), `skill_12` (key equal).

### C17 — tests (extend + new; run_tests.sh / unit_test_runner registration)
- `tests/test_progression_gongfa_data.gd` (extend): A tables (suffix/step/practice/count/damage), 9 A ids resolve, 4 techniques per external A with exactly one `is_finisher`, finisher name prefix 绝招, external-A attribute ∉ feeding sect-line attributes, internal A attributes == sect line attributes.
- `tests/test_gongfa_cascade.gd` (rewrite criterion 1): delete staged short-circuit tests; add: `TutorialFillers.fill` yields 1.3 for every art of a tutorial-shaped unit (use the same art shapes as battlefield's factory); A-art ladder progression 缺2→0.7 / 缺1→0.85 / 齐→1.0 / same-attr 3→1.3; `CharacterData` has no `staged_values` property.
- `tests/test_battle_setup.gd` (extend): traits propagation; equip cap 2 vs 3 (ambidextrous) with grade-sorted order (A art always equipped); no `staged_values` references.
- `tests/test_trait_effects.gd` (NEW, pure): 修习 table tiers/expected values, pojun rounding, lang mult/dr, sha cap.
- `tests/test_cultivation.gd` (extend): shen_gong card grants exactly one unowned A id (seeded); debug_grant_art targets main school; debug_step_month advances exactly one month; 破 ×1.5 practice; cultivate determinism via the lookup table; fix `_test_fast_forward` expected gongfa_count for possible A grants.
- `tests/test_encounter.gd` (NEW, SceneTree-driven like test_cultivation): `start_encounter` transition CULTIVATION→BATTLE; `request_retry` routes to CULTIVATION for encounter context; EncounterData.sparring_partner shape (stats, arts, fhd inputs).
- `tests/test_save_manager.gd` (extend): snapshot/loaded vars equal across save→mutate→load.
- `tests/test_trait_data.gd`: unchanged (hook ids stay data-only); add assertion that the 13 ids/names/costs are untouched.

### C18 — `playtest_spec.yaml` (extended additively — see §7)
Existing 20 scenarios byte-identical. Four new skeletons + surface/action additions.

## 6. Rollback & migration safety (irreversible-operation discipline)

1. **Save format: additive only.** `PlayerProfile.to_dict`/`from_dict` already persist `traits`, `gongfa[{id,grade,practice,mastered}]`, seed, `rng.state`, six decks. No schema keys change; `SAVE_VERSION` stays 1. Old saves load cleanly (from_dict is defensive); new saves are a superset. **No destructive migration exists, therefore no delete-then-verify step is permitted anywhere.**
2. **SaveManager IO already implements backup → execute → validate → delete** (.tmp write → re-validate → .bak copy → rename → re-validate → drop backup). The new snapshot/loaded observables read the same dicts — they add verification, not new risk.
3. **staged_values removal is code-only** (no user data). Rollback path: git revert of C3/C4/C5/C7; protected playtest asserts (`fahui_du_multiplies_damage`, `dot_resolves_at_victim_turn_start`, `terminal_victory`, geometry) are the acceptance gate — if any turns red, the filler tables (not the asserts) must be fixed.
4. **Deck/RNG order:** the shen_gong effect adds one rng draw when the card resolves. Existing scenario/test asserts target counts/categories only (audited: test_cultivation explicitly never asserts exact card ids) — the only count-affecting assert is `_test_fast_forward`'s `gongfa_count == 6`, updated per §C17. The new draw joins the same `SaveManager.rng` operation-order stream (never global `randi()`).
5. **Protected-content invariants** (re-checked in t_plan, never weakened): 8 buttons all `发挥 ×1.3`; `Central_Divine.health == 71`; `Player.health == 152/168`; `skill8_right_edge <= 960`; all no-ellipsis asserts.

## 7. Playtest contract (scene / actions / surface + scenario skeletons)

`scene: "res://scenes/main.tscn"` (unchanged). **Actions (additive):** `debug_step_month`, `debug_grant_art`, `debug_enter_encounter`, `skill_9`, `skill_10`, `skill_11`, `skill_12` — all must exist in project.godot `[input]`. **Surface (additive only):**

```yaml
CultivationScreen: [..., gongfa_ids, gongfa_grades, gongfa_names]
SaveManager: [..., snapshot_profile_json, snapshot_rng_state, snapshot_decks_string,
              loaded_profile_json, loaded_rng_state, loaded_decks_string]
CombatManager: [..., tutorial_battle, debug_sha_heal_total, debug_iron_shirt_procs, debug_lang_attack_mult]
Player: [..., traits]
HUD: [..., skill12_right_edge]
SkillButton9..SkillButton12: [visible, text, fahui_text, disabled, hp_gated, state_text, cooldown_remaining, overlay_visible, state_tag_text, cooldown_label_text]
Sparring_Partner: [health, max_health, grid_pos, turns_taken, acted, skill_cooldowns, shield, status_names]
```

**Scenario skeletons (PM fills assert thresholds; every scenario presses at least one action; frame cap 3000, last assert ≤ 2999):**

1. `sect_switch_same_school_connects` — creation → 武当 → cultivation year 1: `debug_step_month` ×12 → YEAR_END → move_down (换门派) → ui_accept → SECT_SWITCH → move_down ×3 (峨眉) → ui_accept → assert at ~frame 700: `CultivationScreen.year == 2`, `sect_id == "emei"`, `gongfa_ids` contains `emei_emeijian_c` (剑法到了丙级 — the continuity the brief demands), `gongfa_grades` shows the new C row.
2. `cultivation_changes_combat` — creation → 武当 → `debug_step_month` ×12 (year 2 m1) → `debug_grant_art` (sword A 独孤九剑) → `debug_enter_encounter` → BATTLE: press `skill_1` (总诀式) → assert `Sparring_Partner.health == 39` (30 × 0.7 = 21; 60−21) and `SkillButton1.fahui_text == "发挥 ×0.7"` → `debug_win_tutorial` → ui_accept (WON → CULTIVATION) → `debug_step_month` ×15 (master C in year 2; B granted + mastered in year 3, stop ≤ month 3) → `debug_enter_encounter` → BATTLE: `skill_1` → assert `Sparring_Partner.health == 30` (30 × 1.0) and `fahui_text == "发挥 ×1.0"` → `debug_win_tutorial`. One scenario, two battles, damage 21 vs 30 — 发挥度真算, byte-auditable.
3. `save_load_roundtrip` (EXTEND the existing scenario — keep current asserts, add at the end): after the load, assert `SaveManager.loaded_profile_json == SaveManager.snapshot_profile_json`, `loaded_rng_state == snapshot_rng_state`, `loaded_decks_string == snapshot_decks_string`.
4. `trait_combat_effects_and_twelve_slots` — creation: traits 杀破狼 + 铁布衫 + 身轻如燕 + 左右互搏 (indices 8, 4, 5, 0) → 唐门 → `debug_step_month` ×12 → `debug_step_month` ×12 → `debug_grant_art` (dart A 小李飞刀; 4 external arts → 10 techniques) → `debug_enter_encounter` → assert: `SkillButton9.visible == true`, `SkillButton10.visible == true`, `SkillButton9.global_position.y > SkillButton1.global_position.y` (second row), `HUD.skill8_right_edge <= 960`, `HUD.skill12_right_edge <= 960`, `Player.traits` contains `sha_po_lang`; press `move_up` at the occupied (7,4) tile → assert `Player.grid_pos == Vector2i(7,3)` and moves_left −2 (身轻如燕); press `skill_1` → assert enemy HP loss × (1 + 0.08×1) and `debug_sha_heal_total == 4`-style value (PM computes: 18 × 1.0 × 1.08 = 19.44 → 19; 杀 heal round(19×0.2) = 4; cap round(50×0.15) = 8); press `debug_lose_tutorial` → assert `Player.health == 1` (铁布衫) and `debug_iron_shirt_procs == 1` and state != LOST; `debug_win_tutorial`.

**PM threshold note:** all damage examples in §7 assume the §4.3/§7 inputs and `round()` half-away-from-zero; PM re-derives each number from the audited code during task planning (the derivation rules above are authoritative, the example digits are the expected values to verify).

## 8. Tech stack (per SOTA — nothing reinvented)

Godot 4.4 + GDScript; programmatic Resource data layer (no .tres content files); `RandomNumberGenerator` per-instance seed/state via `SaveManager.rng` (splitmix64-mixed, persisted); `round()` half-away-from-zero; stable insertion-sort initiative; `AStarGrid2D` paths (GridManager); JSON text saves with the existing 5-step atomic write; additive playtest surface contract; `gdscript_check` compile gate per implementation step (`.gd` stays out of linter_manifest per addon guidance).

## 9. Extensibility

- Trait hooks remain data (`TraitData.hooks`): the six implemented effects key off trait ids; the remaining hooks (`dual_main_internal`, `no_finishers`, `hp30_chaos`, …) plug into the same lookup points (`_traits_of`, skill-selectable gate, turn start) in later rounds.
- EncounterData is a table: more enemies/encounters are rows, not new code paths; the battlefield mode switch keys off `battle_return_state`, so further battle kinds (map encounters) reuse the same seam.
- The A pool / ladders are rows: adding 轻功 or more schools means new rows in ProgressionGongfaData only.
- Save roundtrip observables are generic string snapshots — future schema bumps can assert equality through them before adding fields.

## 10. Output files checklist

`step2_design.md` (this file) + `linter_manifest.json` (unchanged: `""`, `.json`, `.yaml`, `.md`, `.tscn`, `.tres` → `basic`; no `.gd` entry — handled by the gdscript_check gate).
