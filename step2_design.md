# 技术架构设计 — jinyong-huashan (Step 2, Architect)

> Project: make the Huashan summit finale on the big map an **actually playable battle** —
> profile-derived hero, real turn loop, return to MAP — and prove it with a rewritten
> `playtest/map_battle_node_huashan.yaml` that gates "can fight", not "loaded".
> Date: 2026-08-31. All repo facts below were re-verified by direct read today; the brief's
> cited line numbers are used as-is (Step 1 E1 noted the one stale-doc line is at
> `design/20_content.md:463`, confirmed by read).

## 1. 概述 (Overview)

The defect, precisely: `scripts/segments/map.gd::_maybe_start_entry_battle()` (237-242) reads
`MapData.active_battle_id("huashan") == "huashan_duel"` and calls `GameManager.start_map_battle()`
(game_manager.gd:183-189), which sets `battle_return_state = STATE_MAP`. But `battlefield.gd`
routes to the profile-build path (`_setup_encounter_battle`, :627-677) **only** when
`battle_return_state == "CULTIVATION"` (:69-71). A MAP battle therefore falls through into the
tutorial path: hard-coded Yang Guo (HP 1000), tutorial overlay replay, `tutorial_battle = true`,
and a battle that never begins (`phase == "IDLE"`, `current_round == 0`, `turn_order == []`).

The root cause is one variable carrying two meanings: `battle_return_state` decides BOTH
*who builds the player character* (profile vs tutorial Yang Guo) AND *where WON/LOST routes*.
This design **decouples** them:

- **Build source** = a new `GameManager.map_battle_id` signal (non-empty ⇒ profile build via
  `BattleSetup.build_character(SaveManager.profile)`, opponent roster resolved from the battle id).
- **Return target** = `battle_return_state` alone (already works: `request_continue`/
  `request_retry` route any named segment state — MAP included — and `clear_battle()` on routing;
  verified at game_manager.gd:244-266. **No new return code.**).

The battle itself reuses the proven encounter tail as a **sibling** (`_setup_map_battle`), never
rewriting the pinned `_setup_encounter_battle` (pinned green by `equipment_in_battle_diff` 47/47).
The tutorial path is not touched by one byte: `start_battle()` stays hard-gated on TUTORIAL, the
tutorial branch (:73-98), `_instantiate_enemies()`'s positions/ai_map (:785-800), and the overlay
wiring are untouched.

Scope guard rails honored: no new combat system, no new skills, no new art, no number/formula
changes; cultivation encounter path semantics unchanged; playtest contracts append-only except the
one sanctioned rewrite of `map_battle_node_huashan.yaml`.

## 2. Ground-truth anchors (verified 2026-08-31, used as-is)

| Anchor | Fact |
|---|---|
| `scripts/data/map_data.gd:48-49` | huashan row: event `declared`/`""`, **battle `active`/`huashan_duel`**, facility `declared`/`""` |
| `scripts/data/map_data.gd:175-186` | `active_battle_id()` validates presence only — "when a battle table lands, this is where it gets consulted" (the comment anticipates this round) |
| `scripts/segments/map.gd:236-242` | `_maybe_start_entry_battle()` fires on travel arrival only; writes `entry_battle_id`; calls `GameManager.start_map_battle()` |
| `scripts/segments/map.gd:99-109` | `_ready()` re-derives `current_node_id` from `SaveManager.profile.map_node`; **never** dispatches entry content → no battle re-trigger loop on return |
| `scripts/segments/map.gd:52, 260` | `events_resolved_count` is a MapScreen session var, incremented in `_resolve_node_event()` — reset when MapScreen is rebuilt (the E10 persistence problem) |
| `scripts/autoload/game_manager.gd:142-148` | `start_battle()` hard-gated on TUTORIAL (frozen) |
| `scripts/autoload/game_manager.gd:156-162` | `start_encounter()` hard-gated on CULTIVATION, sets return = CULTIVATION |
| `scripts/autoload/game_manager.gd:183-189` | `start_map_battle()` hard-gated on MAP, sets return = MAP |
| `scripts/autoload/game_manager.gd:215-233` | return-state get/set; `clear_battle()` drops per-battle refs (the lifecycle owner) |
| `scripts/autoload/game_manager.gd:244-266` | `request_continue`/`request_retry` route WON/LOST to any segment state + `clear_battle()` |
| `scripts/autoload/game_manager.gd:608-611` | `debug_win_tutorial` → `CombatManager.debug_wipe_enemies()`; `debug_lose_tutorial` → `debug_kill_player()` — both route through the real pipeline in ANY battle with registered units |
| `scripts/battlefield.gd:64-71` | the only build-source branch today: `battle_return_state == "CULTIVATION"` → `_setup_encounter_battle()` |
| `scripts/battlefield.gd:73-98` | tutorial fallthrough: Yang Guo + five greats, overlay wiring, `tutorial_battle = true` (frozen) |
| `scripts/battlefield.gd:411+` | `_create_all_skill_data()` / `_create_all_character_data()` — pure factories; the five greats' CharacterData carry `ai_class` resolved through an ai_map of preloads |
| `scripts/battlefield.gd:627-677` | `_setup_encounter_battle()`: profile-null guard → `tutorial_battle = false` → `release_stale_units()` → `BattleSetup.build_character(SaveManager.profile)` (:651) → `_instantiate_sparring_partner()` → **synchronous** `_wire_hud` with deferred fallback (:666-668) → `begin_battle.call_deferred()` (:677) |
| `scripts/battlefield.gd:686-725` | sparring-partner instantiation pattern: setup → guarded field wires → `reserve_tile` → surface name BEFORE `add_child` → `register_enemy` |
| `scripts/battlefield.gd:733-768` | `_instantiate_player(data)`: start (7,5) for ALL paths, guarded wires, `set_player` (first-call-wins) |
| `scripts/battlefield.gd:778-830` | tutorial `_instantiate_enemies`: positions dict + ai_map preloads + `enemy.setup(data, ai_controller)` (frozen; the map path must NOT read it) |
| `scripts/data/battle_setup.gd:36-114` | `derive_stats`: `max_health = bone*5 (+gear health)`, `energy = inner*2`, `move_range = 2+floor(agility/20)`, `initiative = agility`; `build_character` → `character_name = "ProgressionHero"`, skills from equipped external arts, `team = 0` |
| `scripts/autoload/combat_manager.gd:104, 249-260, 324-328` | `phase ∈ {IDLE, PLAYER_TURN, ENEMY_TURN, ROUND_END}`; `begin_battle()` = guarded `_begin_if_ready()` (phase IDLE + live player + ≥1 enemy ⇒ `current_round = 1`); `reset_battle()` zeroes everything |
| `scripts/autoload/combat_manager.gd` (turn_order) | `turn_order` holds **name strings** (pinned by `round_one_snapshot_and_turn_order.yaml`: `turn_order[1] == "East Heretic"`), initiative-desc stable snapshot |
| `scripts/ui/hud.gd:751-759` | `EndTurnButton.disabled = not (CombatManager.is_player_turn() and not paused)` — enabled **iff** it is the player's turn |
| `scripts/ai/ai_*.gd` (all five read) | zero-RNG, pure functions of state. Round-1 behavior: East Heretic = Tidal Melody only (global **18×1.3=23**, then returns — no move/attack in round 1); Central Divine = Primal Unity "always when ready" (global **30×1.3=39**); South Emperor = heal falls through (allies full) then approaches (0 dmg from far); North Beggar & West Poison = all damage gated at dist ≤ 3 with alignment (0 dmg from far perimeter) |
| `SaveManager` | `signal loaded(slot)` exists (:30); `new_profile()` (:100) has no signal yet |
| `SceneManager.current_scene` | scene-key strings: `"battlefield"`, `"map"`, … (:26) |
| `playtest/_common.yaml` | whitelisted already: CombatManager `current_round/turn_order/phase/active_unit_name/tutorial_battle`; Player `max_health/health/grid_pos/moves_left/energy`; `EndTurnButton.disabled`; MapScreen `events_resolved_count/current_node_id/phase/ended/focus_id`; actions include `end_turn`, `debug_win_tutorial`, `debug_lose_tutorial` |
| `playtest/click_move_to_tile.yaml` | proven click syntax: `clicks: ["Player +64,0"]` (offset anchored on the live node centre); equality asserts ≥25 frames after the click |
| `tests/test_map_node_event.gd:101-108` | unit pins: huashan is the only live battle slot, binds `huashan_duel`, carries no event (must stay green) |

## 3. 架构图 (Architecture & data flow)

```
 MAP segment (map.gd)                     GameManager (autoload)                BATTLEFIELD scene
 ─────────────────────                    ───────────────────────               ─────────────────────────
 _travel() ─────────────────────────────▶ enter BATTLE (unchanged)
   └─ _maybe_start_entry_battle()         start_map_battle(bid):
       bid = MapData.active_battle_id(      battle_return_state = MAP   ──┐  return target (routing only)
             "huashan")  ── "huashan_duel"  map_battle_id      = bid   ──┼▶ build source (NEW, decoupled)
       guard: MapBattleData.roster_ids     current_state = BATTLE        │
       (bid) non-empty (fail-safe)         battle_started.emit()         │
                                                                         ▼
                                           battlefield._ready():
                                             if battle_return_state == "CULTIVATION":   (byte-identical branch)
                                                 _setup_encounter_battle(); return
                                             if get_map_battle_id() != "":              (NEW branch, sits NEXT TO it)
                                                 _setup_map_battle(bid); return         (never falls into tutorial)
                                             … tutorial fallthrough untouched …

 _setup_map_battle(bid)  — mirrors the pinned encounter tail, same ordering:
   1. guards (profile null / unknown roster ⇒ push_warning + abort)
   2. CombatManager.tutorial_battle = false        (no tutorial intro overlay — TutorialManager never starts)
   3. GameManager.release_stale_units()
   4. player = _instantiate_player(BattleSetup.build_character(SaveManager.profile))   ← PROFILE BUILD
   5. enemies = _instantiate_map_enemies(bid, _create_all_character_data(_create_all_skill_data()))
        roster/positions from MapBattleData (OWN tables — never the tutorial dicts)
   6. _wire_hud(player, enemies) synchronous, deferred fallback          (FIFO flush before the kick)
   7. CombatManager.begin_battle.call_deferred()                          (round 1 starts — the ONLY kick)

 WON / LOST ──▶ request_continue / request_retry ──▶ battle_return_state ("MAP") ──▶ clear_battle()
              (clears map_battle_id too — no leak into later boots)      └──▶ MAP segment rebuilt:
                                                                          current_node_id = profile.map_node
                                                                          events_resolved_count = GameManager mirror
```

Session-counter persistence (E10): `GameManager.map_events_resolved_count` is a session mirror;
MapScreen writes through on each resolve and seeds from it in `_ready()`; it is reset to 0 when a
run begins (`SaveManager.new_profile()`) or a save is loaded (`SaveManager.loaded`).

## 4. Design decisions (with rejected alternatives)

### D1 — Build-source/return-target decoupling: the battle id IS the build-source signal
`GameManager` gains `map_battle_id: String = ""` (+ getter/setter), set **only** by
`start_map_battle(battle_id)`, cleared **only** in `clear_battle()` (the lifecycle owner — it
already runs on every WON/LOST segment routing). `battlefield._ready()` branches on
`map_battle_id != ""`. A non-empty id ⇒ profile build; empty ⇒ tutorial fallthrough untouched.

- **Rejected: branch on `battle_return_state == "MAP"`** — that is exactly the defect's coupling,
  re-created one level down; any future caller that sets return=MAP for another build source
  would silently mis-route.
- **Rejected: separate boolean `battle_build_source`** — strictly less informative than the id
  (the roster still needs the id) and adds a second field to keep in sync. The id carries both
  meanings in one write point.
- **Lifecycle safety**: the only exits from a map battle are the WON/LOST overlays →
  `request_continue`/`request_retry` → `clear_battle()` ⇒ id cleared before the next battlefield
  can ever load, so a tutorial boot can never observe a stale id. Pinned by a unit test (§8).

### D2 — Opponent roster: `huashan_duel` → the five greats, from the existing tutorial factory
New pure data module `scripts/data/map_battle_data.gd` (`class_name MapBattleData`, mirroring the
`MapData`/`EventData`/`FacilityData` data-layer pattern):

```gdscript
const ROSTERS: Dictionary = {
    "huashan_duel": ["East Heretic", "West Poison", "South Emperor", "North Beggar", "Central Divine"],
}
## Map-battle layout — OWNED HERE, never read from the tutorial's positions dict.
## Every tile: walkable interior (col 1..13, row 1..9), Chebyshev distance 6 from the
## player's spawn (7,5), and NOT on the player's row 5 / column 7 (line-caster deny).
const POSITIONS: Dictionary = {
    "huashan_duel": {
        "East Heretic":   Vector2i(1, 1),
        "West Poison":    Vector2i(1, 4),
        "South Emperor":  Vector2i(1, 9),
        "North Beggar":   Vector2i(13, 9),
        "Central Divine": Vector2i(13, 1),
    },
}
static func roster_ids(battle_id: String) -> Array[String]   # [] when unknown (fail-safe)
static func position_for(battle_id: String, name_key: String) -> Vector2i
```

Enemy CharacterData comes from the existing `_create_all_character_data(_create_all_skill_data())`
factory (Step 1 E5); AI controllers resolve from each unit's `data.ai_class` through the new
helper's OWN ai_map of preloads (five entries, mirroring the tutorial pattern — the tutorial's
`ai_map` is not read). `character_name` keeps the factory's spelling with spaces ("East Heretic",
what `turn_order` contains); the **node** name is underscored ("East_Heretic", what the playtest
surface keys resolve) — same convention as the tutorial; the implementer confirms the tutorial's
exact naming line and mirrors it.

- **Rejected: `assets/characters/roster.json`** as the combat source — it is art/species metadata,
  not combat data.
- **Rejected: reusing the tutorial `_instantiate_enemies()`** — it reads the frozen tutorial
  positions/ai_map dicts (E4 forbids); the map path gets its own helper (§5).

### D3 — Round-1 survivability of the gate's differential leg (honest analysis, not a predicted value)
The gate must drive ONE real player action, so the profile hero must survive the greats' round-1
turns (hero initiative ≈ 10-20 ⇒ acts **last**). From the AI reads (all zero-RNG pure functions):

- Guaranteed, position-independent globals in round 1: East Heretic Tidal Melody **23**
  (branch returns — he does not move or attack again in round 1) + Central Divine Primal Unity
  **39** ⇒ **floor 62** with the five-great roster.
- South Emperor / North Beggar / West Poison deal **0** in round 1 from the far perimeter above
  (their damage branches all gate at dist ≤ 3 with alignment; heal falls through on full allies).
- Hero HP = bone×5 + gear. The route's fast-forwarded profile bone is not a number this round
  predicts — the gate run measures it.

**Decision rule (pre-authorized, data-only):** run the gate with the five-great roster. If the
measured hero dies before the first `phase == "PLAYER_TURN"` frame (i.e. measured
`Player.max_health <= 62` on this route), the roster row drops **Central Divine** (his Primal
Unity is the 39 unconditional global) ⇒ floor becomes 23, survivable at bone 10 (HP 50). That is
a one-line `ROSTERS` change plus the matching unit-pin count update, recorded in the delivery
notes and `90_decisions.md`. Balance/roster-composition for difficulty is explicitly NEXT round's
matter (the brief: 数值量级是下一轮); this rule exists only so the gate can prove "can fight" this
round without touching any number.

### D4 — The widened entry is a SIBLING, not a rewrite of the pinned function
`_setup_map_battle(battle_id)` mirrors `_setup_encounter_battle()`'s tail (guards →
`tutorial_battle = false` → stale-ref cleanup → profile build → enemies → sync HUD wire with
deferred fallback → `begin_battle.call_deferred()`). The CULTIVATION branch (:69-71) and the
function itself stay **byte-identical** (`equipment_in_battle_diff` 47/47 must not see a diff).

- **Rejected: parameterizing `_setup_encounter_battle(roster)`** — touches the function pinned by
  an official gate; a sibling that shares the tail achieves the same "widened entry" with zero
  risk to the pinned path. Some ~25 lines of duplication is the deliberate price of the freeze.

**Kick-off ordering (load-bearing, per Step 1 E6/review):** register player → register enemies →
wire HUD **synchronously** (HUD.setup creates SkillButtons + bars before the deferred flush) →
`begin_battle.call_deferred()`. `begin_battle()` self-guards (phase IDLE + live player + ≥1
enemy), so a stray scene load can never trip the empty-round stall guard. Reproducing any other
order is exactly how the observed frozen state (`phase == "IDLE"`, round 0) is reborn.

### D5 — `events_resolved_count` persistence home: GameManager session mirror (E10)
`MapScreen` is `queue_free()`d by `SceneManager._do_swap` and rebuilt on return, so the session
counter dies with it. Persistence design (smallest safe surface):

- `GameManager.map_events_resolved_count: int = 0` (session-scoped, NOT saved).
- `map.gd::_ready()`: `events_resolved_count = GameManager.map_events_resolved_count` (seed).
- `map.gd::_resolve_node_event()`: after `events_resolved_count += 1`,
  `GameManager.map_events_resolved_count = events_resolved_count` (write-through).
- Resets at run boundaries: `GameManager` connects `SaveManager.loaded` (exists) and a NEW
  `SaveManager.profile_created` (2 additive lines: signal declaration + one emit in
  `new_profile()`) and zeroes the mirror on both. Connection is made via
  `_connect_save_signals.call_deferred()` from `GameManager._ready()` so autoload ordering can
  never bite (by the first deferred flush all autoloads are in the tree).

Semantics check against every existing pin (grep-verified 2026-08-31): all `events_resolved_count`
ladder pins (`map_node_event_shaolin` 1→2→3, `spine_to_ending` ==2, `clicks_only_storyline`
1→2→3, `map_node_event_mainline_*` 1→2, `roster_*` 0/1) live inside scenarios where MapScreen is
created once and never rebuilt — the mirror seeds 0 on their single boot and write-through keeps
the ladders identical. `save_load_roundtrip` asserts **no** `events_resolved_count` value; load
resetting the mirror to 0 is invisible to it.

- **Rejected: persisting the counter in the profile/save** — touches the save pipeline and changes
  "session count" semantics; unnecessary.
- **Rejected: snapshot-only at `start_map_battle()`** — leaks a stale mirror into a second run in
  the same process; needs the same reset hooks anyway, so the full mirror is strictly better.

### D6 — Start-position reuse
`_instantiate_player()` hard-codes (7,5) for every path (tutorial + encounter today). The map
battle reuses it unchanged — the grid is the same 15×11 board, (7,5) is legal and unoccupied by
the §D2 layout. No change to the shared function.

### D7 — Tutorial byte-freeze mechanics
No edit inside: `start_battle()`, the tutorial fallthrough (:73-98), `_instantiate_enemies()`
(+ its positions/ai_map), `_wire_tutorial_overlay`, `TutorialManager.start`, tutorial skill
phase-lock. The new branch sits **next to** :69-71. Tutorial skill phase-lock is keyed on
`tutorial_battle` (false here), so the profile hero has all equipped-arts skills from round 1 —
that is the shared engine behaving on different input, not a tutorial change.

### D8 — Gate rewrite discipline (the one sanctioned yaml change)
`playtest/map_battle_node_huashan.yaml` is rewritten **in place, same `name:`** (scenario_order /
the 78-scenario registry and `ROUND_SCENARIOS` two-place sync stay untouched). Every existing
assertion line is retained verbatim (f400 MAP; f520 TRAVEL+shaolin; f540 focus; f580
BATTLE/battlefield/pending_swap) — the machine superset guard (`tests/test_playtest_contract_smoke.py`)
holds with **no exception record**. Only additions + description/header prose. Red-first evidence
for every new nail is measured via the sidecar, never predicted (§7.3).

## 5. Component list & interfaces (file-by-file change manifest)

### 5.1 `scripts/data/map_battle_data.gd` (NEW)
Pure static data layer, zero autoload dependency. Contents per §D2. Interface:
`roster_ids(battle_id) -> Array[String]` (empty when unknown), `position_for(battle_id, name_key)
-> Vector2i`. Mirrors `MapData`'s fail-safe philosophy: an unknown binding reads as inert, never
crashes.

### 5.2 `scripts/autoload/game_manager.gd` (4 additive edits)
1. `var map_battle_id: String = ""` + `set_map_battle_id()`/`get_map_battle_id()` (beside the
   return-state pair at :215-221).
2. `func start_map_battle(battle_id: String = "") -> void:` — body unchanged except
   `map_battle_id = battle_id` (default param keeps the signature backward-compatible).
3. `clear_battle()`: add `map_battle_id = ""` (lifecycle owner; runs on every WON/LOST segment
   routing).
4. `var map_events_resolved_count: int = 0` + deferred connection to `SaveManager.loaded` and the
   new `SaveManager.profile_created`, both resetting it to 0.

### 5.3 `scripts/autoload/save_manager.gd` (2 additive lines)
`signal profile_created` declared beside `loaded`; emitted at the end of `new_profile()`.

### 5.4 `scripts/segments/map.gd` (3 small edits)
1. `_maybe_start_entry_battle()`: after `bid != ""`, guard
   `MapBattleData.roster_ids(bid).is_empty()` → `push_warning` + return (unresolvable binding is
   inert, mirroring `active_event_id`'s fail-safe; the map stays playable on a data typo); then
   `GameManager.start_map_battle(bid)`.
2. `_ready()`: seed `events_resolved_count` from the mirror.
3. `_resolve_node_event()`: write-through to the mirror.

### 5.5 `scripts/battlefield.gd` (1 new branch + 2 new functions)
1. After the CULTIVATION branch (:69-71), the map branch:
   `var bid := GameManager.get_map_battle_id(); if bid != "": _setup_map_battle(bid); return`
   — the tutorial fallthrough after it is untouched.
2. `_setup_map_battle(battle_id: String) -> void` — the sibling per §D4, with the profile-null
   and unknown-roster guards (push_warning + abort, mirroring :630-632; never a hard crash).
3. `_instantiate_map_enemies(battle_id: String, all_data: Dictionary) -> Array[Node]` — per-enemy
   flow copied from the tutorial's pattern (enemy.tscn → `setup(data, ai)` → guarded field wires
   → `reserve_tile` → surface name before `add_child` → `register_enemy`), but positions from
   `MapBattleData.position_for` and AI scripts from its own ai_map preloads. Own ai_map const
   (`ai_east_heretic.gd` … `ai_central_divine.gd` — the same five preloads, independently owned).

### 5.6 Tests (NEW files; existing suites untouched)
- `tests/test_map_battle_data.gd`: `roster_ids("huashan_duel")` = the five greats (or the measured
  fallback set — keep in sync with §D3's rule); unknown id → []; every position in-bounds,
  walkable, pairwise-distinct, ≠ player spawn (7,5); (generic property pins, so a reposition does
  not break them).
- `tests/test_map_battle_entry.gd` (template: `tests/test_encounter.gd`): seed a profile, set
  `current_state = MAP` + return state MAP + `map_battle_id = "huashan_duel"`, instantiate the
  battlefield, one deferred flush → assert player is the profile build (ProgressionHero,
  `tutorial_battle == false`, `current_round == 1`, `turn_order.size() == 6` and contains the
  five greats' names, HUD `pressed_connected["EndTurnButton"] == true`, enemies registered).
  Also: `clear_battle()` clears `map_battle_id` (no-leak pin); a null profile aborts without
  crashing (guard pin).
- `tests/test_map_battle_gate_pins.py` (stdlib pytest, pattern: `test_facility_copy_location.py`):
  the rewritten yaml must still contain the load-bearing assertion literals
  (`current_round >= 1`, `turn_order.size() == 6`, `tutorial_battle == false`,
  `max_health != 1000`, `events_resolved_count == 2` return pin) — an anti-accidental-weakening
  door, mirroring the facility guard's "防删钉".

### 5.7 Playtest contract appends (append-only)
`playtest/_common.yaml`: append exactly two entries to the `GameManager` surface block:
`map_battle_id`, `map_events_resolved_count`. Nothing else changes; no new scenario id; no new
debug action (`debug_win_tutorial`/`debug_lose_tutorial`/`end_turn`/clicks suffice).

## 6. 技术栈 (Technology choices — all in-repo, per SOTA)

- Godot 4.4 / GDScript; autoload singletons (`GameManager`, `CombatManager`, `SaveManager`,
  `SceneManager`) as today; signals for state broadcast.
- `CombatManager` turn engine adopted **as-is** (non-goal: no new combat system).
- `BattleSetup.build_character(SaveManager.profile)` — the only sanctioned player factory.
- External Godot turn-queue frameworks/plugins: rejected (would violate the no-new-system /
  no-new-assets constraints; the in-repo initiative-queue already implements the surveyed
  architecture).
- Measurement instrument: `run_tests.sh` → `godot-builder` sidecar (compile → headless playtest of
  all 78 scenarios → GDScript unit suite). All nail values measured, never predicted.

## 7. Playtest contract — the rewritten `map_battle_node_huashan.yaml`

### 7.1 Scenario skeleton (boot spine preserved; frames marked ⟨meas⟩ are measured, not predicted)

- **Leg A — boot (f3-f400, byte-identical):** 7× ui_accept creation → `debug_win_tutorial` f20 →
  transition/creation/sect accepts → `debug_fast_forward` f280 → f400 assert
  `GameManager.current_state == "MAP"` (KEPT verbatim).
- **Leg B — travel (f420-f545, assertions kept):** luoyang EVENT resolve (count 1) → shaolin
  EVENT resolve (count 2) → f520 `phase == "TRAVEL" and current_node_id == "shaolin"` (KEPT) →
  two move_right → f540 `focus_id == "huashan"` (KEPT) → NEW f545
  `events_resolved_count == 2` (the pre-battle ladder anchor).
- **Leg C — battle arrival (f550 ui_accept → f580, plus new asserts):**
  KEPT: `current_state == "BATTLE"`, `SceneManager.current_scene == "battlefield"`,
  `pending_swap == false`.
  NEW: `GameManager.map_battle_id == "huashan_duel"` (the binding, consumed end-to-end);
  `CombatManager.tutorial_battle == false`; `Player.max_health: max_health != 1000 and
  max_health > 0` (profile-derived, not the tutorial's 1000 — relational per Step 1 E7, no
  predicted literal); `CombatManager.current_round: current_round >= 1`;
  `CombatManager.turn_order: turn_order.size() == 6 and turn_order.has("ProgressionHero") and
  turn_order.has("East Heretic") and turn_order.has("West Poison") and turn_order.has("South
  Emperor") and turn_order.has("North Beggar") and turn_order.has("Central Divine")`;
  `CombatManager.phase: phase != "IDLE"`; `CombatManager.active_unit_name != ""`.
- **Leg D — the player's turn + one real action (frames ⟨meas⟩ — five greats act first, hero
  last):** assert `phase == "PLAYER_TURN"`, `active_unit_name == "ProgressionHero"`,
  `EndTurnButton.disabled == false` (HUD gate ⇒ player's turn is live); then
  `clicks: ["Player +64,0"]` (click_move_to_tile pattern) → ≥25 frames later:
  `Player.grid_pos: changed`, `Player.moves_left: changed` (**the one real action's differential**).
- **Leg E — win & return to MAP (frames ⟨meas⟩):** `end_turn` → `debug_win_tutorial` within the
  same round handoff (before any round-2 enemy turn can kill a low-HP hero; deterministic, so the
  measured window holds) → WON overlay → `ui_accept` → assert:
  `GameManager.current_state == "MAP"`, `SceneManager.current_scene == "map"`,
  `pending_swap == false`, `MapScreen.current_node_id == "huashan"`,
  `MapScreen.phase == "TRAVEL"`, `MapScreen.ended == false`,
  `MapScreen.events_resolved_count == 2` (intact across the duel),
  `GameManager.map_battle_id == ""` (cleared — no leak into later boots).
- **Leg F — lose & return (re-fire + retry routing, frames ⟨meas⟩):** travel shaolin → night_rain
  re-fires (recorded re-visit policy) → resolve → `events_resolved_count == 3` → travel back to
  huashan → battle #2 re-fires (`current_state == "BATTLE"`, `map_battle_id == "huashan_duel"`,
  `current_round >= 1`, `tutorial_battle == false`) → `debug_lose_tutorial` → LOST overlay →
  `ui_accept` → assert MAP return again: `current_state == "MAP"`,
  `SceneManager.current_scene == "map"`, `current_node_id == "huashan"`,
  `events_resolved_count == 3`, `ended == false`.

Frame budget: the current file ends at f580; legs D-F land well under the 2999 hard cap.
Total scenario count stays 78 (rewrite in place, same name).

### 7.2 Line-by-line assertion change table (to be transcribed verbatim into the delivery notes)

| # | Old line (current file) | Disposition | New line | Rationale (old proved "loaded"; new proves "can fight") |
|---|---|---|---|---|
| 1 | f400 `GameManager.current_state: current_state == "MAP"` | KEPT verbatim | — | boot spine unchanged |
| 2 | f520 `MapScreen.phase: phase == "TRAVEL"` | KEPT verbatim | — | travel leg unchanged |
| 3 | f520 `MapScreen.current_node_id: current_node_id == "shaolin"` | KEPT verbatim | — | travel leg unchanged |
| 4 | f540 `MapScreen.focus_id: focus_id == "huashan"` | KEPT verbatim | — | arrival targeting unchanged |
| 5 | f580 `GameManager.current_state: current_state == "BATTLE"` | KEPT verbatim | — | the swap really happens |
| 6 | f580 `SceneManager.current_scene: current_scene == "battlefield"` | KEPT verbatim | — | the right scene loaded |
| 7 | f580 `SceneManager.pending_swap: pending_swap == false` | KEPT verbatim | — | swap settled |
| 8 | — (absent) | ADDED | f580 `GameManager.map_battle_id == "huashan_duel"` | proves `huashan_duel` is actually CONSUMED (today it is written nowhere) |
| 9 | — | ADDED | f580 `CombatManager.tutorial_battle == false` | the observed defect asserted false-positive today (`true`) |
| 10 | — | ADDED | f580 `Player.max_health != 1000 and max_health > 0` | HP derived from the profile, not the tutorial Yang Guo's 1000; relational, no tuned literal |
| 11 | — | ADDED | f580 `CombatManager.current_round >= 1` | the round ACTUALLY started (observed: 0) |
| 12 | — | ADDED | f580 turn_order size/has set | non-empty roster with the five greats + profile hero (observed: `[]`) |
| 13 | — | ADDED | f580 `phase != "IDLE"` | engine left idle (observed: IDLE forever) |
| 14 | — | ADDED | f580 `active_unit_name != ""` | a current actor is visible |
| 15 | — | ADDED | ⟨meas⟩ `phase == "PLAYER_TURN"` + `active_unit_name == "ProgressionHero"` + `EndTurnButton.disabled == false` | the hero's turn arrives and the end-turn button is enabled (observed: disabled forever) |
| 16 | — | ADDED | ⟨meas⟩ `Player.grid_pos: changed` + `Player.moves_left: changed` after one click-move | the one real action's differential (movement works) |
| 17 | — | ADDED | ⟨meas⟩ MAP-return block after WIN | return target = MAP (not CULTIVATION, not tutorial), map state + counter intact, binding cleared |
| 18 | — | ADDED | ⟨meas⟩ re-fire + LOST-return block | both endings return to MAP; battle slots re-fire like events (policy) |
| 19 | header prose ("What is NOT asserted here: the return leg…") | REWRITTEN | new header | the old refusal-to-assert rationale is obsolete; the rewrite states what is now proven and why the old gate was insufficient (not weakened — extended) |

No existing assertion is dropped, relaxed, or re-based → the machine superset guard passes with
no exception record.

### 7.3 Red-first protocol (measured, sidecar-wired — E12)
1. Land the rewritten yaml FIRST with the code fix absent (temporary revert of the §5 code
   changes, kept out of the build), run
   `godot_playtest_scenario(scenario="map_battle_node_huashan")` **directly against the sidecar**.
2. Measure and record the four values into the delivery notes: failing frame / first failing
   assertion / exact error string / green asserts before red. Expected first red is one of
   f580 `map_battle_id` (field absent) or `tutorial_battle == false` (reads true) — whichever
   fires first is the MEASURED value, not this prediction.
3. Restore the code fix, re-run → green; then the full official gate (78/78) plus the unit suite.

## 8. Design-doc deliverables (executed by the 5_design step from gate artifacts)

1. `design/20_content.md`: fix the stale sentence at **:463** — `battle 槽六节点仍全 declared` is
   obsolete; record that 华山's battle slot is `active`/`huashan_duel` (mirroring
   `map_data.gd:49`) and is now a real, gated battle. Add a §11 (same fact-source discipline as
   §8/§10): the `huashan_duel` implementation — roster row, positions, entry path
   (`map.gd → start_map_battle(bid) → map_battle_id → _setup_map_battle`), the sibling-not-rewrite
   ruling, and the §D3 roster/survivability ruling with measured numbers. Update §8.3 item 1
   (battle slots) to "live on 华山, declared elsewhere".
2. `design/90_decisions.md`: one dated ruling (2026-08-31) recording: build-source/return-target
   decoupling via `map_battle_id` (rejected alternatives per §D1), sibling `_setup_map_battle`
   (rejected parameterization per §D4), counter persistence home (rejected profile-persistence per
   §D5), roster = five greats from the existing factory with the pre-authorized one-line fallback.
3. `design/99_changelog.md`: **exactly one appended line** for this round; no existing line or
   cell changes.
4. `design/00_roadmap.md`: completeness table row 2 (map node types) updated from THIS round's
   gate artifacts only (`battle ✅ 华山 — playtest gate map_battle_node_huashan n/n`, numbers from
   `playtest_summary.md`; nothing predicted).
5. `design/40_ux_backlog.md`: append the 11 measured findings from the brief, record-only
   (monthly loop no-feedback & near-static numbers; focus highlight below perception threshold;
   character-page transparency bleed; map is a vertical list with no geography; silent event
   resolution; monthly deck four identical runs; shrimp only on the battle screen; creation has
   no name/portrait; save/load/delete mixed into "本月行动"; empty practice screen; ending has no
   summary). Marked OPEN, unscheduled, explicitly out of this round's scope.

## 9. Verification & regression matrix (hard gate)

- Compile: zero errors (95/95 baseline + new files).
- Playtest: **78/78 scenarios PASS**, hard gate `passed: true`, zero runtime errors. Named
  non-regression pins to quote in the delivery notes: `spine_to_ending` (42/42),
  `clicks_only_storyline` (47/47), `equipment_in_battle_diff` (47/47 — the encounter path is
  byte-identical), `cultivation_changes_combat` (30/30), `save_load_roundtrip` (14/14),
  `event_travel_effects` (19/19), `facility_use_reusable` (49/49), `terminal_victory_
  8_12_rounds_hp_15_40` (6/6), `tutorial_win_routes_to_transition` (8/8),
  `tutorial_loss_restarts_tutorial` (5/5), `map_node_event_shaolin` (32/32), `round_one_snapshot_
  and_turn_order`, `battle_end_turn_attack_buttons`, `click_move_to_tile`.
- Unit suite: existing suite green + `tests/test_map_battle_data.gd` + `tests/test_map_battle_entry.gd`;
  `tests/test_map_node_event.gd` must stay green untouched (it already pins huashan as the only
  live battle slot).
- Visual gate: run per the round's standard blind/human-fallback rules; no new geometry or
  palette introduced (enemy portraits already exist for the five greats).

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Hero dies in round 1 before acting (floor 62 global with five greats) | §D3: far-perimeter positions; pre-authorized one-line roster fallback (drop Central Divine → floor 23); decision made from MEASURED gate evidence, recorded honestly |
| Frame timing for the player's turn (5 enemy turns first) | Deterministic engine (zero-RNG AI, seeded RNG outside battle) — measured once, holds forever; generous ⟨meas⟩ margins; `at:` values re-baselined exactly like prior rounds did |
| `map_battle_id` leaks into a tutorial boot | Cleared in `clear_battle()` (the only WON/LOST exit); unit pin asserts the clear; the branch reads the id, never the return state |
| `events_resolved_count` ladder regressions | Mirror is additive; grep-verified no existing pin spans a MapScreen rebuild; `save_load_roundtrip` asserts no counter value |
| Tutorial byte-freeze violation | No edit inside the tutorial branch/`_instantiate_enemies`/`start_battle`; sibling functions only; `equipment_in_battle_diff` + tutorial scenarios are the tripwires |
| `turn_order.size() == 6` breaks if the roster changes | Intentional loud failure (gate discipline); the §D3 fallback updates the same line knowingly |
| Synchronous HUD wire unreachable | Same deferred-fallback pattern as the encounter path (:666-668) |

## 11. 扩展性考虑 (Extensibility, deliberately bounded)

- The NEXT map battle slot (e.g. a shaolin battle) is **one `ROSTERS`/`POSITIONS` row** in
  `MapBattleData` + one `map_data.gd` slot flip — the entry path is battle-id-driven and needs
  zero new code. No speculative battle-type hierarchy, per-battle BGM/intro hooks, or reward
  tables this round.
- The id now flows end-to-end, so a future per-battle intro overlay or music has a natural home
  (keyed by `map_battle_id`) — recorded as a horizon, not built.
- Balance/roster tuning for difficulty is next round's lever and touches only `MapBattleData`.

## 12. PM decomposition hints (suggested subtask split)

1. **Data & decoupling**: `map_battle_data.gd` + GameManager (id field, start_map_battle(bid),
   clear_battle, counter mirror) + SaveManager signal + map.gd wiring + unit tests
   (`test_map_battle_data.gd`).
2. **Battlefield entry**: `_setup_map_battle` + `_instantiate_map_enemies` + branch +
   `test_map_battle_entry.gd`.
3. **Gate rewrite**: yaml rewrite per §7.1-7.2 + `_common.yaml` surface appends +
   `test_map_battle_gate_pins.py` + red-first measurement (sidecar) + delivery notes with the
   line-by-line table.
4. **Docs**: the five design-doc updates (from gate artifacts only; changelog = exactly one line).
   Subtasks 1-2 are code, 3 is contract, 4 is records; 1 and 2 can parallelize after 1 lands the
   GameManager field.

## 产出前自检 (self-check)

- Covers all MVP goals: profile build + `tutorial_battle == false` + no overlay replay (§D1/D4);
  real round start with visible actor, enabled end-turn, working move/skills (§7.1 legs C-D);
  WIN/LOST → MAP with map state and counter intact (§D5, legs E-F); `huashan_duel` consumed and
  roster-determining (§D2, assert #8); gate rewritten with line-by-line documentation (§7.2);
  design-doc updates specified (§8).
- Single-responsibility components, no new abstraction layers; everything reuses SOTA-recommended
  in-repo mechanisms (`BattleSetup`, `CombatManager`, request_continue/retry routing, debug
  actions, click-move pattern).
- Interfaces are concrete signatures/lines a PM can split and an implementer can write directly.
- No over-design: rejected alternatives recorded; extension points documented but not built.
- `linter_manifest.json` re-emitted: `.gd` deliberately excluded (the `gdscript_check` gate owns
  it per addon guidance); `.md/.yaml/.json/.tscn` → `basic`, `.py` → `ruff` — matches the files
  this design touches.
