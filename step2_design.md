# 六段骨架 — Technical Architecture Design (step 2)

**Run scope:** six-segment skeleton — tutorial win → transition → character creation → sect
selection → cultivation (36 months) → map → ending, on top of the existing tutorial battle
that must stay green (11 protected playtest scenarios).

---

## 1. Overview

The game currently ships exactly one playable moment: the tutorial battle (Huashan, Yang Guo vs
the Five Greats), embedded in `scenes/main.tscn`, with `GameManager` as a four-state FSM
(`TUTORIAL → BATTLE → WON | LOST`). This run builds the rest of the line from that win to the
ending, per `design/40_progression.md` (decided-but-unbuilt) and the Step-1 SOTA report:

1. **Persistent shell + SceneManager** — `main.tscn` becomes a shell (Camera + CanvasLayers +
   `SceneHost`); a new autoload routes one active segment scene under `SceneHost`. The
   battlefield becomes a routed scene, not the game.
2. **Six-segment state machine** — extend the existing string FSM; `end_battle()` becomes a
   router, never a terminal overlay.
3. **`PlayerProfile` + SaveManager** — attrs, traits, learned gongfa, silver, cultivation
   year/month, map node, tutorial-done flag; 3-slot JSON saves at `user://save_<slot>.json`;
   seeded `RandomNumberGenerator` + per-deck draw state persisted so a reloaded save replays
   the identical card sequence.
4. **Global Chinese font theme** — committed `Theme` resource with Noto Sans SC wired via
   `ProjectSettings gui/theme/custom`, plus a runtime `ThemeDB.fallback_font` bootstrap
   autoload as the CI-safe fallback; compact health bar (≤ 20 px total height) as the final
   piece of `design/30_presentation.md`'s bar requirements.
5. **Thin-but-walkable segments 2–6** — text transition, 30-point creation UI, 5-sect select,
   cultivation month loop (monthly 3-category card draw + 4-choice action + year-end
   stay/switch), node-graph map, tiered ending.
6. **Playtest spine** — one scenario drives the whole line tutorial-win → ending inside the
   3000-frame cap, using unbound DEBUG input actions (SOTA edge case 2).

**Hard constraints honored (from SOTA + prior-run knowledge):**
- The 11 existing scenarios in `playtest_spec.yaml` are **untouched** and must stay green.
  That pins the tutorial battle's observable values: `GameManager.current_state == "WON"` at
  frame 2999 (terminal scenario), `fahui_text == "OVERDRIVE x1.3"`, `name_text == "Yang Guo"`,
  skill buttons without `…`, `RoundIndicator.active_text` ending in `"Act ✓"`, `bar_width <= 64`.
- Freed-object crash hardening: autoloads never hold long-lived direct references to per-scene
  nodes; every access is `is_instance_valid()`/`get_node_or_null()`; scene swaps defer
  `add_child` until the outgoing scene is freed (SOTA edge case 1).
- Seeded RNG determinism: one RNG instance, one seed persisted in the save, all draws in
  operation order; zero `randi()`/`randomize()` in gameplay code (SOTA edge case 3, 4;
  `design/40_progression.md` §3.5).
- Save integrity: validate on load, fall back to a fresh profile with an error surface; saves
  only from stable states; atomic write with backup/validate/rollback (SOTA edge case 9;
  irreversible-op rollback requirement).
- `debug_fast_forward` must consume the *same* RNG draws as manual play — it reuses the
  month-advance code path with fixed auto-choices (SOTA edge case 2).

---

## 2. Design-consistency notes (required by `design/README.md`)

**No rules in the design archive are changed by this run.** Every number below that is not in
the archive is a *new decision filling an Open question in `design/90_decisions.md`* (the table
there delegates: "属性成长查表 — 谁来定: 架构", "事件/大地图/结局 — 用户 + 架构"). They are
listed in §12 so `5_design` can fold them into the archive after final verification. Where the
archive and the protected playtest conflict, the playtest wins for the tutorial battle only —
documented in the two notes below.

### 2.1 UI text language (explicit note for implementers)
- **Segments 2–6 ship Chinese UI text** per `design/30_presentation.md` ("界面文字一律中文",
  English abbreviations explicitly rejected). The global theme + Noto Sans SC make this
  renderable; all new screens are laid out for CJK widths at font size 12.
- **The tutorial battle keeps its existing English strings this run** (skill names, "Yang Guo",
  "OVERDRIVE x1.3", overlay text). Reason: 11 protected playtest scenarios assert those exact
  values, and retranslating the tutorial is out of this run's scope. This is a run-scope note,
  **not** a design change; a future run may retranslate the tutorial together with its
  playtest assertions.
- All code identifiers, node names, signal names, comments, and this document are English.

### 2.2 Architecture-decided numbers (new decisions, for `5_design`)
| Topic | Decision (this design) |
|---|---|
| 修习 gain distribution | `+1..+3` uniform: `rng.randi_range(1, 3)`, chosen attr + gain (no curve, per §3 "查表,不用曲线" — the table is uniform) |
| Practice-to-mastery | 丁 `4`, 丙 `6`, 乙 `8` months of 练功 (a mastered gongfa counts as a full 前置 for its school's cascade; it can no longer be practiced) |
| 做工 income | `+10` silver per month |
| 丙/乙 gongfa names | `<丁级名>·精进` (丙), `<丁级名>·大成` (乙), e.g. 易筋经·入门/精进/大成; external attrs: 罗汉拳 刚, 太极剑 柔, 打狗棒法 阳, 峨眉剑法 阴, 满天花雨 柔 |
| Progression 普攻 | `attack_damage = 10 + 根骨`, range = 1 (melee main external school) / 2 (ranged school, per §2.2) |
| Progression technique stubs | Each external gongfa grants `grade` generic techniques (丁1/丙2/乙3): single-target, range 1, cooldown 1, damage 丁18/丙22/乙26 |
| Card pools | economy 12, equipment 12, growth 12 (monthly); power 6, trait 6, artifact 6 (yearly) — content tables in §8.5 |
| Events (first batch) | 4 events, 2 options each, §8.6 |
| Map | 6 nodes, adjacency in §8.7; mainline 无名谷→洛阳→武当→襄阳→昆仑 |
| Ending tiers | 3 tiers by total attrs: ≥90 宗师 / 60–89 名宿 / <60 归隐, §8.8 |
| Fast-forward auto-choices | card = first card; action = 练功 on the first unmastered gongfa (else 修习 根骨); year-end = stay. Runs through the identical `_apply_month()` code path |
| Tutorial-loss handling | `LOST` → keypress → reload tutorial battle from scratch (TUTORIAL state, tutorial active) |
| Creation points | leftover points allowed (design says "spend 30", not "exactly 30"; SOTA assumption 2) |

---

## 3. Architecture diagram (text)

```
┌─ res://scenes/main.tscn — persistent shell (root "Main", Node2D) ─────────────┐
│ Camera (480,352) · SceneHost (Node2D) · HUDLayer(layer 10, HUD)              │
│ TutorialLayer(layer 100, TutorialOverlay) · EndGameOverlay (runtime, layer 50)│
└───────────────────────────────────────────────────────────────────────────────┘
      ▲ SceneManager instantiates / queue_free()s exactly one active scene here
      │  (preloaded PackedScenes — no cold file loads on swap)
SceneHost children (one at a time):
  battlefield.tscn ("Battlefield")  ·  transition.tscn ("TransitionScreen")
  creation.tscn ("CreationScreen")  ·  sect_select.tscn ("SectSelectScreen")
  cultivation.tscn ("CultivationScreen")  ·  map.tscn ("MapScreen")  ·  ending.tscn ("EndingScreen")

Autoloads (project.godot order):
  GameManager     — six-segment FSM; battle context; WON/LOST continue/retry input
  SceneManager    — state→scene router; listens to GameManager.state_changed
  SaveManager     — PlayerProfile + RNG + decks + 3-slot JSON IO (atomic writes)
  CombatManager   — turn engine (existing); + reset_battle()/debug hooks
  TutorialManager — unchanged (7-step tutorial, drives GameManager.start_battle())
  GridManager     — grid occupancy (existing); + clear_grid()
  AudioManager    — unchanged
  ThemeManager    — runtime font fallback (ThemeDB.fallback_font) if the .tres theme fails

Pure data layer (no scene-tree deps; instantiated by SaveManager/scenes):
  scripts/data/player_profile.gd          — the persisted character (RefCounted)
  scripts/data/trait_data.gd              — 13 trait/flaw defs + hook ids
  scripts/data/progression_gongfa_data.gd — 5 sects × (internal + external) × 丁丙乙
  scripts/data/card_data.gd               — monthly + yearly card pools
  scripts/data/event_data.gd              — 游历 event pool
  scripts/data/map_data.gd                — 6 nodes + adjacency + ending tiers
  scripts/data/battle_setup.gd            — §7 formula derivation → CharacterData
  scripts/data/gongfa_data.gd             — REAL 发挥度 cascade (replaces the 1.3 stub)
```

**Primary data flow (spine):**
```
TUTORIAL (battlefield) ──tutorial done──▶ BATTLE ──end_battle(true)──▶ WON (overlay + hint)
  ──ui_accept──▶ TRANSITION (2 text pages) ──ui_accept──▶ CHARACTER_CREATION
  ──confirm──▶ SECT_SELECTION ──pick sect──▶ CULTIVATION (36 monthly cycles, autosave)
  ──month 36──▶ MAP ──reach end node──▶ ENDING (tiered text) ──key──▶ restart (fresh TUTORIAL)
```

---

## 4. State machine (GameManager, extended in place)

States (string constants; `current_state` + `state_changed` signal stay the playtest surface):
`TUTORIAL, BATTLE, WON, LOST` (existing, protected) + `TRANSITION, CHARACTER_CREATION,
SECT_SELECTION, CULTIVATION, MAP, ENDING`.

| From | To | Trigger |
|---|---|---|
| TUTORIAL | BATTLE | `TutorialManager` finishes (`start_battle()`) — unchanged |
| BATTLE | WON | `end_battle(true)` when `battle_return_state == "TUTORIAL"` — **unchanged observable** |
| BATTLE | LOST | `end_battle(false)` when `battle_return_state == "TUTORIAL"` |
| WON | TRANSITION | `ui_accept`/`tutorial_next` while WON (new input hook in GameManager) |
| LOST | TUTORIAL | `ui_accept`/`tutorial_next` while LOST → `SceneManager.reload_battle()` + tutorial restart |
| TRANSITION | CHARACTER_CREATION | transition scene's last page (its own continue press) |
| CHARACTER_CREATION | SECT_SELECTION | creation confirm |
| SECT_SELECTION | CULTIVATION | sect picked |
| CULTIVATION | MAP | month 36 completed |
| MAP | ENDING | end node reached |
| ENDING | TUTORIAL | restart keypress → `restart_game()` (fresh profile + reload battlefield) |

Battle context: `battle_return_state: String` — set to `"TUTORIAL"` when the tutorial battle
starts, and to `"CULTIVATION"` by the future encounter-battle hook (`enter_battle(encounter_id)`
is a stub this round; `end_battle` already routes `WON/LOST → battle_return_state`). This keeps
`WON/LOST` reachable (protected scenarios) while making them transitions, not terminals.

New GameManager API:
- `set_battle_return_state(s: String)`, `get_battle_return_state()`
- `enter_segment(state: String)` — validated single transition helper used by segment scenes
- `request_continue()` / `request_retry()` — called from `_unhandled_input` on WON/LOST
- `restart_game()` — clears battle refs, resets SaveManager, reloads tutorial battle
- `clear_battle()` — nulls `_player`, clears `enemies_alive`, frees the end overlay
- `_show_end_game_overlay()` gains a hint line ("Press Enter to continue" / retry wording) —
  no existing assert reads overlay text, so this is safe.

---

## 5. Component list & interfaces

### C1. SceneManager (NEW, `scripts/autoload/scene_manager.gd`)
**Responsibility:** state→scene routing under the persistent shell; safe swap lifecycle.

**Interface:**
```
var current_scene: String            # surface: "battlefield"|"transition"|"creation"|"sect_select"|"cultivation"|"map"|"ending"|"none"
var pending_swap: bool               # surface: true while a deferred swap is in flight
var last_error: String               # surface

const SCENE_MAP := { ... }           # state String -> preloaded PackedScene
func _ready():                       # grabs SceneHost from Main, preloads, instantiates battlefield synchronously (initial TUTORIAL state)
func _on_state_changed(state: String) -> void
func reload_battle() -> void         # for LOST retry / restart_game
func swap_to(scene_key: String) -> void
```
**Swap protocol (freed-object safe, SOTA edge case 1):**
1. `pending_swap = true`; HUD visibility = `(next == "battlefield")`.
2. If a scene is hosted: `hud.clear_battle_refs()` (C5), `CombatManager.reset_battle()`,
   `GridManager.clear_grid()`, `GameManager.clear_battle()`, then `current.queue_free()`.
3. `await current.tree_exited` (guarded: if the node was never in the tree, skip the await);
   the incoming scene is **preloaded**, so `instantiate()` + `add_child` after the await.
4. `pending_swap = false; current_scene = scene_key`.
Initial startup: battlefield is instantiated **synchronously in `_ready`** (it is preloaded;
no cold load), so the protected scenarios' frame-3 `ui_accept` presses hit a live battlefield
exactly as today. `battlefield.gd`'s existing recursive `HUDLayer`/`TutorialLayer` lookups
(`_find_hud_recursively`, `_find_tutorial_layer_recursively`) already tolerate the extra
`SceneHost` nesting level — no changes needed there.

### C2. SaveManager (NEW, `scripts/autoload/save_manager.gd`)
**Responsibility:** owns `PlayerProfile`, the seeded RNG, deck state, and slot IO.

**Interface (surface-relevant subset):**
```
var seed: int                 # surface (uint64 as int)
var last_error: String        # surface ("" = healthy; set on any IO/schema failure)
var slot: int                 # surface (1..3, last used)
var has_save: bool            # surface (true after a successful save this session)
var eco_left / eq_left / growth_left / pow_left / trait_left / art_left: int   # surface, deck remaining counts

func new_profile(attrs: Dictionary, traits: Array[String]) -> void   # creation confirm; generates seed
func load_slot(s: int) -> bool
func save_slot(s: int) -> bool        # guarded: only when state is stable (CULTIVATION/MAP) and not pending_swap
func delete_slot(s: int) -> bool
func autosave() -> void               # slot 1, from month advance + map move
func draw_cards(monthly: bool) -> Array[Dictionary]   # 3 cards, one per category; removes all 3; reshuffles empty decks (rng-driven shuffle)
func apply_seed(seed_value: int) -> void             # hash once (splitmix64 finalizer), rng.seed = hash
```
**PlayerProfile** (`scripts/data/player_profile.gd`, RefCounted, `class_name PlayerProfile`):
```
attrs: Dictionary   # {"bone","inner","agility","wisdom","fortune"} -> int (>=10, no ceiling)
traits: Array[String]
gongfa: Array[Dictionary]   # {"id","grade","practice","mastered"} — ids from progression_gongfa_data
silver: int
inventory: Array[String]; companions: Array[String]   # empty this round; schema reserved
cultivation: Dictionary    # {"year":1..3,"month":1..12,"sect_id"}
map_node: String
flags: Dictionary          # {"tutorial_done": bool, "events_seen": Array[String]}
main_external_id: String
```
Methods: `add_gongfa(id)`, `master_gongfa_of(id)`, `to_dict()` / static `from_dict(d)`.

### C3. ThemeManager (NEW, `scripts/autoload/theme_manager.gd`, ~20 lines)
`_ready()`: if `ThemeDB.fallback_font == null`, `load("res://assets/fonts/NotoSansSC-Regular.otf")`
→ assign `ThemeDB.fallback_font`. Primary mechanism is the committed theme
(`assets/themes/global_theme.tres`, `default_font` = ext_resource by **res:// path**, not uid —
SOTA edge case 5) wired via `[gui] theme/custom="res://assets/themes/global_theme.tres"`.
`default_font_size = 12`. No per-node font overrides anywhere. Labels must never ellipsize
(`text_overrun_behavior` stays non-ellipsis; keep strings short enough to fit — the 104 px
button math from the archive holds at size 12).

### C4. GameManager (MODIFIED, `scripts/autoload/game_manager.gd`) — see §4.

### C5. HUD + battle-exit cleanup (MODIFIED `scripts/ui/hud.gd`, `scripts/ui/health_bar.gd`, `scenes/ui/health_bar.tscn`)
- `hud.gd` gains `clear_battle_refs()`: nulls player/enemy refs (health-bar `follow_character`
  already guards with `is_instance_valid`, so no crash window even if a frame straddles the swap).
- `CombatManager.reset_battle()` (MODIFIED `scripts/autoload/combat_manager.gd`): clears turn
  order/log, cooldowns, statuses, phase → `TUTORIAL`-clean; `debug_wipe_enemies()` and
  `debug_kill_player()` apply lethal damage **through the normal damage/death pipeline**
  (they exercise the real WON/LOST path — used by the unbound DEBUG actions).
- `GridManager.clear_grid()` (MODIFIED): frees tile occupancy only (grid setup itself persists).
- Health bar compact pass (design/30_presentation.md final shape): widget **68×20**, `Bar` 64×8
  at y=11, `NameLabel` 64×9 above it (font 10); keep the existing `expand_margin_all(3)` track
  (already implemented — do not regress to content_margin); offset so the widget floats above
  the sprite without covering it (`screen_pos + (-34, -28)`). Expose `total_height: float` on
  the surface; keep `bar_width <= 64`, `name_text`, `fill_color`, `follow_delta` untouched.

### C6. Segment scenes (NEW — all keyboard-drivable, no mouse required)
All segment roots are `Control` FULL_RECT named exactly as the surface key. Input via
`_unhandled_input` on `ui_accept`, `tutorial_next`, and the four `move_*` actions.

| Scene / script | Root name | Focus model | Surface vars |
|---|---|---|---|
| `scenes/segments/transition.tscn` + `scripts/segments/transition.gd` | TransitionScreen | 2 pages; ui_accept advances; last page → `GameManager.enter_segment("CHARACTER_CREATION")` | `lines_shown, done` |
| `scenes/segments/creation.tscn` + `scripts/segments/creation.gd` | CreationScreen | phase `attrs` (5 rows: index = attr; left/right −1/+1 with tiered pricing and clamps) → phase `traits` (13 cells: up/down; ui_accept toggles) → phase `confirm` (ui_accept) | `phase, points_left, attr_index, attrs, trait_ids, confirmed` |
| `scenes/segments/sect_select.tscn` + `scripts/segments/sect_select.gd` | SectSelectScreen | 5 rows (up/down), ui_accept picks | `focus_index, selected_sect_id` |
| `scenes/segments/cultivation.tscn` + `scripts/segments/cultivation.gd` | CultivationScreen | month phases §6 | `year, month, sect_id, phase, silver, attr_bone…attr_fortune, gongfa_count, mastered_count, drawn_card_categories, event_id, fast_forward_used` |
| `scenes/segments/map.tscn` + `scripts/segments/map.gd` | MapScreen | focus = current node; `move_*` selects among **adjacent** nodes (adjacency-validated, not just distance — SOTA edge case 13); ui_accept moves | `current_node_id, focus_id, ended` |
| `scenes/segments/ending.tscn` + `scripts/segments/ending.gd` | EndingScreen | ui_accept → `GameManager.restart_game()` | `tier, done` |

### C7. Data layer (NEW/MODIFIED — pure, table-driven)
- **`scripts/data/gongfa_data.gd` (MODIFIED, the §3.7 hard requirement).** Add
  `mastered: bool = false` to `GongfaData`; add `staged_values: bool = false` to
  `CharacterData` (tutorial units set it `true` — the explicit 编排数值 marker the archive
  demands; do NOT "fix" tutorial values). Real `get_fa_hui_du(unit)`:
  ```
  if unit.staged_values: return fa_hui_du            # tutorial: 编排值 1.3, labeled, never recomputed
  missing = count of lower grades in unit's arts (same school) that are not mastered
            (A needs B+C+D, B needs C+D, C needs D, D needs none)
  base = [1.0, 0.85, 0.7, 0.6][clamp(missing, 0, 3)]
  if base < 1.0: return base
  same_attr = min(count of mastered arts (internal+external) with attribute == self.attribute, 3)
  return 1.0 + 0.1 * same_attr                # 1.0 / 1.1 / 1.2 / 1.3
  ```
- **`scripts/data/battle_setup.gd` (NEW, static).** `derive_stats(profile) -> Dictionary`
  (`气血 = 根骨×5`, `内力值 = 内力×2`, `移动力 = 2 + floor(身法/20)`, `先攻 = 身法`,
  普攻 = `10 + 根骨`, range per main external school melee/ranged); `build_character(profile) ->
  CharacterData` (staged_values=false, mastered flags from profile, techniques from
  progression gongfa data). Used by the future encounter-battle hook; present + unit-testable
  this round even though no second battle is reachable in normal play.
- **`scripts/data/trait_data.gd` (NEW).** 13 `TraitDef` rows: id / 中文名 / cost (positive:
  cost, flaw: negative refund) / hooks (Array[String] effect identifiers, stable extension
  points). Implemented this round: **孤煞** only (sect teaching skips the internal art — real
  gameplay impact in C6 sect select). All other hooks (左右互搏 `skill_bar_3_arts`, 无师自通
  `bypass_prereq_learn`, 骨骼清奇 `dual_main_internal`, 过目不忘 `self_learn_watched`, 铁布衫
  `fatal_guard_once`, 身轻如燕 `pass_through_enemies`, 江湖阅历 `map_inquire`, 福缘深厚
  `yearly_event_reroll`, 杀破狼 `solo_only`, 旧伤 `no_finishers`, 心魔 `hp30_chaos`,
  筋骨迟钝 `no_lightfoot_school`) are **data-only stubs** this round.
- **`scripts/data/progression_gongfa_data.gd` (NEW).** 5 sects × (internal + external) ×
  丁/丙/乙 = 30 entries. 丁 names from `design/40_progression.md` §2.4 verbatim; 丙/乙 by the
  `·精进/·大成` convention (§2.2); grade→technique-count (丁1/丙2/乙3) generic stubs.
- **`scripts/data/card_data.gd` (NEW).** §8.5 tables; ids are stable strings.
- **`scripts/data/event_data.gd` / `map_data.gd` (NEW).** §8.6 / §8.7.

---

## 6. Cultivation month loop + DEBUG fast-forward (normative)

`cultivation.gd` phases per month (surface `phase`):
```
CARD_PICK   → 3 cards drawn (economy/equipment/growth, one each; all 3 removed from decks)
              focus 0..2 (move_left/right), ui_accept applies the picked card
              (trait cards: owned ids are filtered out BEFORE drawing, never offered again)
YEAR_AUGMENT (months 1, 13, 25 only, before CARD_PICK) → 3 cards (power/trait/artifact), same pattern
ACTION_PICK → 4 cells 练功/修习/做工/游历 (move_up/down + ui_accept)
  练功   → GONGFA_PICK sub-phase (first unmastered gongfa autofocused; +1 practice;
           reaching 丁4/丙6/乙8 → mastered=true, grants its techniques) 
  修习   → ATTR_PICK sub-phase (5 attrs; + rng.randi_range(1,3), no ceiling)
  做工   → silver += 10
  游历   → event pool draw (rng, no repeat until exhausted) → EVENT overlay (2 options,
           1 consequence each; battle-trigger options reserved as `battle_id: null` stubs)
YEAR_END   → after months 12 and 24: 留下/换门派 (stay → next year same sect;
            switch → pick new sect). Either way, at year start the CURRENT sect grants its
            internal + external gongfa at grade = new year (2→丙, 3→乙); 孤煞 suppresses the
            internal grant. Then autosave(slot 1).
After month 36's action → GameManager.enter_segment("MAP"); autosave.
```
Month advances **after** the action resolves. `_apply_month(card_choice, action_choice)` is the
single code path; **`debug_fast_forward`** (unbound input action consumed in `_process`) loops
the remaining months synchronously through `_apply_month` with fixed auto-choices (first card;
练功 on first unmastered gongfa, else 修习 根骨; stay at year-end) — same RNG draws, same
determinism (SOTA edge case 2). Sets `fast_forward_used = true`. No awaits inside the loop, so
it completes within a handful of frames (spine frame budget).

---

## 7. RNG & save design

**RNG (SOTA edge case 3):** seed generated at `new_profile()` from system time
(`Time.get_ticks_usec()` — system entropy, not gameplay RNG), hashed once (splitmix64
finalizer, because `RandomNumberGenerator` has no avalanche effect for similar seeds), then
`rng.seed = hash`. All gameplay draws go through `SaveManager.rng` in operation order. Deck
shuffles are `rng`-driven (Fisher-Yates with `rng.randi_range`). No other RNG anywhere.

**Save schema (`user://save_<slot>.json`, plain JSON, `version` field — SOTA edge case 9):**
```json
{ "version": 1,
  "seed": 1234567890123456789, "rng_state": 987654321,
  "profile": { "attrs": {"bone":15,"inner":12,"agility":11,"wisdom":10,"fortune":12},
               "traits": ["iron_shirt"], "silver": 0, "inventory": [], "companions": [],
               "gongfa": [{"id":"shaolin_yijin_d","grade":"D","practice":2,"mastered":false}],
               "main_external_id": "shaolin_luohan_d" },
  "segment": "CULTIVATION",
  "cultivation": {"year":1,"month":3,"sect_id":"shaolin"},
  "map_node": "wuming_valley",
  "flags": {"tutorial_done": true, "events_seen": []},
  "decks": { "economy": {"remaining":[], "drawn":[]}, "equipment": {...}, "growth": {...},
             "power": {...}, "trait": {...}, "artifact": {...} } }
```
Determinism is belt-and-suspenders: `seed` + `rng_state` (restore both: `rng.seed = seed` then
`rng.state = rng_state`) **and** explicit per-deck `remaining`/`drawn` lists. A reloaded save
replays the identical card sequence even if RNG internals change.

**Load validation:** missing/truncated/hand-edited files → `JSON.parse_string` null-check,
`version == 1`, type checks, clamps (attrs ≥ 10; silver ≥ 0; month 1..12; year 1..3; segment ∈
known set; deck lists are String arrays). Any failure → `last_error` set, fresh profile, no
crash. Saving is refused while `SceneManager.pending_swap` or outside stable states.

**Atomic save + rollback (irreversible-op requirement — overwriting an existing save):**
1. Write `save_<slot>.json.tmp` (pretty-printed `JSON.stringify`). Flush + close.
2. **Validate the tmp** by reading + schema-checking it (never trust the write).
3. If `save_<slot>.json` exists: copy it to `save_<slot>.json.bak` (**backup before touch**).
4. Remove the old file; rename tmp → real; re-validate the real file by reading it.
5. Only after step-4 validation passes, delete the `.bak`; on any failure, restore the
   `.bak` over the real file and set `last_error`. (Backup → execute → verify → delete old
   data — in that order, never "delete first, write second".)

**Delete must confirm:** slot delete in the cultivation UI is a two-step cell
(arm → confirm on a second ui_accept in the same phase).

---

## 8. Content tables (thin but real; Chinese UI text for segments 2–6)

### 8.5 Card pools (ids → effects; effects apply immediately)
- **economy (12):** `eco_20`×4 +20银, `eco_50`×3 +50银, `eco_100`×2 +100银, `eco_trade_1..3`
  +40/+60/+80银 (names: 一袋碎银/半锭纹银/一锭元宝/行商分成).
- **equipment (12):** items recorded in `inventory` (data-only this round, no stat effects):
  `eq_sword_1..4` 铁剑/精铁剑/青锋剑/长剑, `eq_armor_1..4` 布衣/皮甲/锁子甲/软猬甲,
  `eq_boots_1..4` 草鞋/快靴/踏云履/凌波靴.
- **growth (12):** `gr_attr_bone/inner/agility/wisdom/fortune` (+1 to that attr, ×5),
  `gr_practice_2` ×2 (practice +2 to first unmastered gongfa), `gr_trait_pool` (draw from the
  not-yet-owned trait pool — excludes owned at draw time), `gr_silver_30`.
- **power (6, yearly):** `pw_practice_4`×2, `pw_attr_3`×2 (+3 chosen attrs — auto: bone),
  `pw_tech_unlock`×2 (grants the current external gongfa's next technique early — data hook).
- **trait (6, yearly):** trait cards from the not-yet-owned pool (drawn from a pool of the 8
  positive trait ids; owned excluded).
- **artifact (6, yearly):** `art_ding_speed`×3 (practice +6 to first unmastered gongfa),
  `art_shen_gong`×2 (grants one 甲-grade external gongfa of the sect's school — cascade keeps
  it 失常 0.6~0.7, per §3.6: no extra balance rule), `art_silver_500`.

### 8.6 Events (first batch; 游历 draws one, no repeat until pool exhausted)
| id | text (Chinese, 2–3 lines) | option A / consequence | option B / consequence |
|---|---|---|---|
| bandits | 山道遇劫匪 | 破财消灾: silver −10 (min 0) | 出手退敌: 根骨 +1 |
| merchant | 行商路过 | 买下长剑: silver −20 → inventory +青锋剑 | 婉拒: nothing |
| ruins | 古墓残碑 | 入内参悟: 悟性 +1 | 谨慎绕行: 福缘 +1 |
| beggar | 老丐乞食 | 施舍: silver −5 → 福缘 +1 | 切磋武学: practice +2 (first unmastered gongfa) |

### 8.7 Map (6 nodes; adjacency-checked moves)
```
wuming_valley 无名谷 ── luoyang 洛阳 ── wudang 武当 ── xiangyang 襄阳 ── kunlun 昆仑(终点)
                          └── shaolin 少林
```
Mainline = 无名谷→洛阳→武当→襄阳→昆仑 (4 moves). Current node persisted in the save.
End node reached → tier computed → ENDING.

### 8.8 Ending tiers
`total = bone+inner+agility+wisdom+fortune`: **≥ 90** tier 3 一代宗师 · **60–89** tier 2
武林名宿 · **< 60** tier 1 隐于市井 — each with distinct 3–5 line Chinese text (drafted by
the implementer from these titles; the tier id is the asserted value).

---

## 9. Playtest contract (`playtest_spec.yaml`)

**Preserved verbatim:** all 11 existing scenarios and every existing `surface` line.
**Additive changes only:**

1. `actions:` add `debug_fast_forward`, `debug_win_tutorial`, `debug_lose_tutorial` —
   defined in `project.godot [input]` with **empty event lists** (SOTA edge case 12: no
   physical keys, never visible in UI, triggerable via `Input.action_press`).
2. `surface:` add:
   ```
   SceneManager:      [current_scene, pending_swap, last_error]
   SaveManager:       [seed, last_error, slot, has_save, eco_left, eq_left, growth_left, pow_left, trait_left, art_left]
   TransitionScreen:  [lines_shown, done]
   CreationScreen:    [phase, points_left, attr_index, attrs, trait_ids, confirmed]
   SectSelectScreen:  [focus_index, selected_sect_id]
   CultivationScreen: [year, month, sect_id, phase, silver, attr_bone, attr_inner, attr_agility, attr_wisdom, attr_fortune, gongfa_count, mastered_count, drawn_card_categories, event_id, fast_forward_used]
   MapScreen:         [current_node_id, focus_id, ended]
   EndingScreen:      [tier, done]
   HealthBar:         (existing line) + total_height
   ```
3. Scenario skeletons (assert thresholds → PM):
   - **`spine_to_ending`** (the 终局 spine, SOTA edge case 2 — primary deliverable):
     7×ui_accept (tutorial) → `debug_win_tutorial` → assert `WON` → ui_accept →
     `TRANSITION` → 2×ui_accept → `CHARACTER_CREATION` → 5×move_right (+根骨 10→15) →
     confirm → `SECT_SELECTION` → ui_accept → `CULTIVATION` (assert year=1, month=1,
     gongfa_count=2) → `debug_fast_forward` → assert `MAP` → 4× map moves to 昆仑 →
     assert `ENDING` + `EndingScreen.tier` ∈ {1,2,3}. Final assert ≤ frame 2900.
   - **`tutorial_win_routes_to_transition`**: same first half; asserts
     `SceneManager.current_scene == "transition"` after the WON continue, `pending_swap == false`.
   - **`tutorial_loss_restarts_tutorial`**: `debug_lose_tutorial` → assert `LOST` → ui_accept →
     assert `TUTORIAL`, `SceneManager.current_scene == "battlefield"`,
     `TutorialManager`-visible state (Player re-instantiated; no freed-object crash).
   - **`creation_budget_clamp_and_traits`**: buy 根骨 10→20 (15 pts), 内力 10→15 (+5),
     assert `points_left == 10`; attempt +根骨 → still 20; toggle 旧伤 (−8) → 18; toggle
     左右互搏 (−10) → 8; toggle off → 18; confirm with leftover allowed → `SECT_SELECTION`.
   - **`lone_bane_sect_grants_external_only`**: creation: toggle 孤煞, confirm; pick 峨眉 →
     `CultivationScreen.gongfa_count == 1`, `sect_id == "emei"` (internal suppressed).
   - **`cultivation_month_cycle_and_deck_bookkeeping`**: month 1: `phase == "CARD_PICK"`,
     `drawn_card_categories` has 3 distinct entries; pick card 0 → action 练功 (2×ui_accept)
     → practice +1, `month == 2`, three `*_left` counts each −1, `has_save == true`,
     `last_error == ""`.
   - **`cultivation_year_end_stay`**: 12 manual months (each: 2×ui_accept = card 0 +
     练功 gongfa 0) → at year-end: stay → `year == 2`, `month == 1`,
     `gongfa_count == 4` (丙 grants land).
   - **`save_load_roundtrip`**: 2 manual months → navigate focus to Save cell (move_down×N)
     → ui_accept → `has_save`, `last_error == ""`; 1 more month → navigate to Load cell →
     ui_accept → `year`/`month`/`attr_bone` equal the saved snapshot.
   Every skeleton contains at least one keypress (contract rule); PM fills threshold
   expressions in the `assert:` blocks.

---

## 10. File-level change list (paths relative to repo root `./`)

**NEW**
- `scripts/autoload/scene_manager.gd`, `scripts/autoload/save_manager.gd`, `scripts/autoload/theme_manager.gd`
- `scripts/data/player_profile.gd`, `scripts/data/trait_data.gd`, `scripts/data/progression_gongfa_data.gd`, `scripts/data/card_data.gd`, `scripts/data/event_data.gd`, `scripts/data/map_data.gd`, `scripts/data/battle_setup.gd`
- `scripts/segments/transition.gd`, `creation.gd`, `sect_select.gd`, `cultivation.gd`, `map.gd`, `ending.gd`
- `scenes/segments/transition.tscn`, `creation.tscn`, `sect_select.tscn`, `cultivation.tscn`, `map.tscn`, `ending.tscn`
- `assets/themes/global_theme.tres`
- `tests/test_battle_setup.gd`, `tests/test_save_manager.gd` (pure-logic unit tests run via `run_tests.sh` extension; last run collected zero tests — knowledge.md pitfall)

**MODIFIED**
- `project.godot` — autoloads (SceneManager, SaveManager, ThemeManager), `[gui] theme/custom`,
  3 unbound debug input actions
- `scenes/main.tscn` — battlefield removed from static tree → `SceneHost` added (shell refactor)
- `scripts/autoload/game_manager.gd` — FSM extension, battle context, WON/LOST input, clear_battle
- `scripts/autoload/combat_manager.gd` — `reset_battle()`, `debug_wipe_enemies()`, `debug_kill_player()`
- `scripts/autoload/grid_manager.gd` — `clear_grid()`
- `scripts/ui/hud.gd` — `clear_battle_refs()`, visibility toggling
- `scripts/ui/health_bar.gd` + `scenes/ui/health_bar.tscn` — compact 68×20 layout, `total_height`
- `scripts/data/gongfa_data.gd` — `mastered` field + real cascade `get_fa_hui_du`
- `scripts/data/character_data.gd` — `staged_values` flag (编排数值 marker)
- `playtest_spec.yaml` — additive surface/actions/scenarios (§9; protected lines untouched)
- `README.md` — new flow, controls, debug actions, save locations

**NOT modified:** all AI scripts, `player.gd`/`enemy.gd` combat logic, tutorial content,
the 11 protected scenarios, all existing asset files.

**Assets:** no new art/audio this run (design/40_progression.md §0: no art/audio/animation
polish; thin segments use themed built-in controls + the existing `summit.png` backdrop for
the transition page). Fallback to Godot primitives only if a background fails to load.

---

## 11. Tech stack & linter

Godot **4.4**, GDScript, text-based `.tscn` scenes (agent-writable), autoload singletons,
`FileAccess` + JSON for saves, `RandomNumberGenerator` for seeded draws, `Theme`/`ThemeDB` for
the global font. No third-party addons; no new dependencies (SOTA: FSM/statechart addons and
save plugins rejected; the in-place string FSM is the playtest surface).

`linter_manifest.json`: GDScript is deliberately absent (checked by the `gdscript_check` gate);
`""`, `.json`, `.yaml`, `.md`, `.tscn`, `.tres` → `basic`.

---

## 12. Extensibility (reserved, not built)

- **Trait hooks** — `TraitDef.hooks` ids are stable extension points; only 孤煞 executes this
  round; future runs wire the rest where the systems exist.
- **Encounter battles** — `GameManager.battle_return_state` + `battle_setup.build_character()`
  + `CombatManager.reset_battle()` are the complete seam for re-entering the battlefield from
  events/map; event rows reserve `battle_id`.
- **Companions** — `profile.companions` schema slot reserved; battle engine already multi-unit.
- **Augments/decks** — pools are data tables; new cards are rows, not code.
- **More gongfa content** — `progression_gongfa_data.gd` is a table; the 发挥度 cascade and
  generic-technique stubs are grade-driven, so new 剑/拳掌/轻功 ladder rows plug in.

## 13. Risks & mitigations
| Risk | Mitigation |
|---|---|
| Shell refactor breaks protected scenarios (battlefield now instantiated) | Instantiate synchronously in SceneManager._ready from a preloaded scene; node name stays "Battlefield"; battlefield.gd's recursive HUD/overlay lookups already handle the SceneHost nesting |
| Frame-cap overshoot in spine | Both DEBUG actions are synchronous, no awaits; spine final assert ≤ 2900; terminal scenario (2600-frame battle) remains separate |
| Freed-object crashes on swap | Await tree_exited + deferred add; `clear_battle_refs()` + `is_instance_valid` guards; the loss-retry scenario exercises the teardown path |
| RNG non-determinism | Single RNG instance; seed+rng_state+decks persisted; fast-forward reuses `_apply_month`; no stray `randi()` |
| `.tres` theme/uid rot in CI | Theme references font by res:// path; ThemeManager runtime fallback via ThemeDB |
| Save corruption | Versioned schema + load validation + atomic write with .bak rollback; error surface var, never a crash |
| New surface names not yet instantiated at assert time | Segment vars are only asserted in scenarios after the segment exists; PM keeps that invariant when filling thresholds |
