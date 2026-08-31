# 技术架构设计 — jinyong-equipment-battle (Step 2, Architect)

**Round thesis:** equipment leaves the data-only dead end. Three slots on `PlayerProfile`, a touch-only equip/unequip surface on the roster panel, one tier formula (no per-item literals), and equipped gear flowing into `BattleSetup.derive_stats` so a better sword measurably changes a real encounter — pinned by differential playtest contracts measured through the real grant → equip → encounter code path.

**Inputs honored:** Step 1 SOTA report (all file/line claims re-verified by direct reads this step: `scripts/data/player_profile.gd`, `scripts/data/battle_setup.gd`, `scripts/ui/roster_panel.gd`, `scripts/data/card_data.gd:36–48`, `playtest/_common.yaml:1005–1103`, `playtest/roster_panel_item_nail.yaml`, `playtest/cultivation_changes_combat.yaml`, `playtest/map_battle_node_huashan.yaml`, `design/40_progression.md §7–§9`, `design/90_decisions.md:477–503`, `design/40_ux_backlog.md` UX-13/14). Reviewer suggestions adopted: (1) surface-whitelist + superset-fixture obligations made explicit deliverables (§6.4); (2) magnitude anchors for the formula are derived here, not deferred (§3.3); (3) the self-run-per-scenario protocol is listed as a hard downstream dependency (§6.5).

---

## 1. Overview — what this architecture adds, and what it deliberately does not

Additive round. No existing interaction, ruling, pin, or scenario is redesigned. The four increments:

1. **Save model** — `PlayerProfile.equipped` (3 String-valued slots), JSON-lossless, defensively coerced, validated by `equip`/`unequip` helpers.
2. **One formula, one place** — new `scripts/data/equipment_data.gd`: id → slot, id → tier, tier → bonus. Five constants keyed on *category*, never per-item.
3. **Two consumers** — `BattleSetup.derive_stats` adds the bonuses (legacy-empty = byte-identical output, unit-pinned); `RosterPanel` grows a per-row button pool (装上/卸下) that writes `profile.equipped` only — free action, no autosave.
4. **Contract** — append-only surface observables, two new playtest scenarios (panel leg + real-encounter diff leg), smoke-test two-place sync, i18n keys, design-doc updates including the ruling that supersedes the read-only guarantee.

Explicit non-goals (from the brief, restated as architecture boundaries):
- UX-14 战前选装 untouched: `build_character`'s auto-pick-top-2-by-grade rule is byte-identical after this round.
- No autosave for equipment; no month/phase/count side effects; no new currency/event-pool/portrait/art work; no new keyboard actions (`project.godot` `[input]` unchanged).
- Tutorial (编排数值) path untouched — equipment only flows through the encounter path (`battlefield.gd:651` → `BattleSetup.build_character`).

## 2. Architecture diagram (text)

```
                         ┌──────────────────────────── (new) scripts/data/equipment_data.gd
                         │  SLOTS / SLOT_PREFIXES / 5 constants
                         │  slot_of(id) tier_of(id) bonuses_for(id) sum_bonuses(equipped)
                         └───────┬──────────────────────────────┬──────────────────┐
                                 │ preload                       │ preload          │ (read-only)
       scripts/data/player_profile.gd                 scripts/data/battle_setup.gd    │
       var equipped {weapon,armor,boots}              derive_stats(): + bonuses       │
       equip()/unequip_slot()/equipped_id()           build_character(): cd.gear_*    │
       to_dict()/from_dict() (defensive)              (stale header :14–15 corrected) │
              │                    │                            │                       │
              │ to_dict/from_dict  │ writes ONLY equipped       │ CharacterData (4 new   │
              ▼                    ▼                            ▼ int fields, default 0)
   scripts/autoload/save_manager.gd   scripts/ui/roster_panel.gd   scripts/characters/player.gd
   (serialize_failed guard already     + scenes/ui/roster_panel.tscn   new mirror vars
    catches non-String keys;           装上/卸下 button pool            gear_attack_bonus /
    round-trip pinned by new unit      focus_mode=0, no autosave       gear_health_bonus /
    test)                              header comment rewritten        gear_initiative_bonus /
                                                                       gear_move_bonus
                                                                       (surface: Player block)
```

Data flow of the round's core proof (playtest scenario B, §6.3):
merchant event (real `EventLogic.apply_option_effects`) → `inventory.append("eq_sword_3")` → roster click 装上 → `profile.equip("weapon","eq_sword_3")` → next `start_encounter()` → `battlefield.gd:651 BattleSetup.build_character(SaveManager.profile)` → `derive_stats` adds `EquipmentData.sum_bonuses` → `CharacterData.gear_*` → player unit mirrors → `Player.gear_attack_bonus` observable changes in a live battle. Unequip reverses it. No path writes profile fields directly.

## 3. Design decisions

### 3.1 D1 — `PlayerProfile.equipped`: plain Dictionary, String keys only

```gdscript
const EquipmentData = preload("res://scripts/data/equipment_data.gd")

var equipped: Dictionary = {"weapon": "", "armor": "", "boots": ""}   # slot -> inventory id or ""
```

- **Plain `Dictionary`, NOT `Dictionary[String, String]`.** Godot 4 `JSON.parse_string` returns an untyped Dictionary; typed dictionaries are not JSON-round-trip compatible (godot#97137). This is the same constraint the file header already documents; the new field obeys it by construction.
- `to_dict()`: add `"equipped": _equipped_snapshot()` where `_equipped_snapshot()` builds a fresh `{"weapon": v, "armor": v, "boots": v}` plain Dictionary each call (deep-copy semantics consistent with the other container fields — caller mutation must not corrupt the live profile).
- `from_dict()` coercion (hostile-data rules of the house, extended):
  1. `src.get("equipped")` — if not a Dictionary → keep defaults (three empty slots). **Legacy saves with no `equipped` key fall through here: equivalent to three empty slots, no crash, nothing wiped.**
  2. For each of the three known slot keys only: value accepted iff it is a non-empty String; anything else (number/bool/null) → `""`.
  3. **Invariant repair on load:** a candidate id that is not in the (already-coerced) `inventory` is dropped to `""`. Order matters: coerce `inventory` before `equipped`, or run a post-pass after both. Consequence: `equipped ⊆ inventory` is a restored invariant, not just an entry-time rule; lossless round-trip is unaffected because `equip()` can only ever produce ids that are in inventory.
  4. Unknown keys inside the saved `equipped` dict are naturally dropped (we only read the three known keys).
- Helpers on `PlayerProfile` (the profile owns its own invariant — same style as `add_gongfa` returning bool):

```gdscript
func equipped_id(slot: String) -> String            # defensive .get(slot, ""); "" when unknown slot
func equip(slot: String, id: String) -> bool        # see validation matrix below
func unequip_slot(slot: String) -> bool             # invalid slot -> false; else set "" (idempotent true)
```

  `equip` validation matrix (all failures are silent `false`, never push_error):
  | case | result |
  |---|---|
  | slot not in `EquipmentData.SLOTS` | `false`, no write |
  | `id == ""` | `false` (use `unequip_slot` to clear) |
  | `id` not in `inventory` | `false` (the brief's precondition: 装上的前提是该 id 真在 inventory 里) |
  | `EquipmentData.slot_of(id) != slot` | `false` (an armor id can never enter the weapon slot) |
  | same id already equipped in that slot | `true`, no state change (idempotent — duplicate inventory rows render multiple buttons that all behave correctly) |
  | different id in that slot | `true`, overwrite = **swap semantics** (one click swaps swords; the displaced sword stays in inventory and its row's button flips back to 装上) |

### 3.2 D2 — New module `scripts/data/equipment_data.gd` (the formula's single home)

House naming mirrors `card_data.gd` / `event_data.gd` / `facility_data.gd` / `skill_data.gd`. Pure static layer, no autoload, no scene dependency (so `PlayerProfile` and `BattleSetup` can both preload it without direction problems). The 12 card rows in `card_data.gd` are untouched (frozen `display_name_of` and rows stay as-is; their `effect_value: 0` columns remain — the effect now comes from here, not the table).

```gdscript
class_name EquipmentData extends RefCounted

const SLOTS: Array[String] = ["weapon", "armor", "boots"]
const SLOT_PREFIXES := {"weapon": "eq_sword_", "armor": "eq_armor_", "boots": "eq_boots_"}

# ---- the one formula (design/40_progression.md §9, derivation below) --------
const ATTACK_PER_TIER := 2          # 兵刃 → 普攻
const HEALTH_PER_TIER := 5          # 护甲 → 气血
const INITIATIVE_PER_TIER := 2      # 鞋履 → 先攻
const MOVE_BONUS_TIER_THRESHOLD := 3
const MOVE_BONUS := 1

static func slot_of(id: String) -> String      # "" when not an equipment id
static func tier_of(id: String) -> int         # 1..4, else 0 (defensive, never push_error)
static func bonuses_for(id: String) -> Dictionary   # {"attack","health","initiative","move"} ints; zeros for ""/unknown
static func sum_bonuses(equipped: Dictionary) -> Dictionary  # defensive .get(slot, "") per known slot
```

- `slot_of`: `id.begins_with(SLOT_PREFIXES[slot])` scan over the 3 prefixes. A 3-entry prefix table keyed on *category* is not a per-item literal — categories are the design axis the brief allows; adding a 4th tier needs zero code here.
- `tier_of`: suffix after the last `"_"` (`id.substr(id.rfind("_") + 1)`), `int()`-coerced (`int("") == 0`, `int("x") == 0` — malformed ids degrade to 0 = no bonus), accepted only in `1..4`, else 0.
- `bonuses_for(id)`:
  ```
  t = tier_of(id); s = slot_of(id)
  attack    = ATTACK_PER_TIER     * t   if s == "weapon" else 0
  health    = HEALTH_PER_TIER     * t   if s == "armor"  else 0
  initiative= INITIATIVE_PER_TIER * t   if s == "boots"  else 0
  move      = MOVE_BONUS                if s == "boots" and t >= MOVE_BONUS_TIER_THRESHOLD else 0
  ```
- `sum_bonuses(equipped)`: sums `bonuses_for(equipped.get(slot, ""))` over `SLOTS`; treats a non-String value as `""`. This is the single call site `derive_stats` uses.

**Shape rationale (from Step 1, adopted):** additive linear in tier (3 constants) beats multiplicative (couples to future base-stat drift every phase-5 re-tune) and is the opposite of the forbidden 12-row table. Tier-1 items give a nonzero bonus (`step × tier`, not `base + step×(t−1)`) — any drawn equipment is worth equipping, and every tier step is the same delta so "better sword → better stat" is monotone by construction.

### 3.3 D3 — The formula's derivation and magnitude anchors (design, not just code)

Base formulas (`battle_setup.gd:31–42`, unchanged): 气血 = 根骨×5, 普攻 = 10+根骨, 先攻 = 身法, 移动力 = 2 + floor(身法/20). Attribute reality (`design/40_progression.md §2.1, §7.1`): creation starts attrs at 10 (cap 20), 修习 adds +1~3 per session, three years of cultivation lands main attrs at **30~40**, so the encounter-true mid-game anchor is attrs ≈ 20–30.

Anchoring the per-tier step in **attribute equivalents** (the currency the rest of the design already speaks):

| slot | stat fed | step | attribute-equivalent per tier | t1 → t4 bonus | % of mid-game base (attrs 25) | % at fresh (10) | % at late (40) |
|---|---|---|---|---|---|---|---|
| 兵刃 weapon | 普攻 = 10+根骨 | `2×t` | +2 根骨 | +2 → +8 | 6% → 23% (base 35) | 10% → 40% (base 20) | 4% → 16% (base 50) |
| 护甲 armor | 气血 = 根骨×5 | `5×t` | **+1 根骨 exactly** (5 HP) | +5 → +20 | 4% → 16% (base 125) | 10% → 40% (base 50) | 2.5% → 10% (base 200) |
| 鞋履 boots | 先攻 = 身法 | `2×t` | +2 身法 | +2 → +8 | 8% → 32% (base 25) | 20% → 80%* (base 10) | 5% → 20% (base 40) |
| 鞋履 boots | 移动力 | `+1 if t≥3` | +1 tile (踏云履/凌波靴 only) | 0/0/1/1 | — | — | — |

\* the fresh-char ceiling: a fresh 10-attr character holding top-tier gear gets +40% (attack/health) — this is the accepted coarse-tuning headroom. Top-tier ids are the tail of the 12-card equipment deck spread over 36 monthly draws, so top gear realistically arrives mid-run; and every tier is monotone, so a month-1 铁剑 (+2 attack) is already visible. **Phase 5 re-tunes by editing the three `*_PER_TIER` ints — no assertion anywhere pins these numbers** (all gates are `changed`/relation diffs; unit tests pin formula *relations* + the empty-slot legacy equality, see §7.1).

Derivation logic recorded for the design doc:
1. **Direction** is fixed by the brief: weapon→普攻, armor→气血, boots→先攻 (+movement at high tier). One stat per slot keeps attribution unambiguous (a `changed` on one derived stat names its slot).
2. **Armor step = 5 HP** is chosen so `HEALTH_PER_TIER ÷ 气血-multiplier` is exactly 1 根骨-equivalent per tier — the cleanest possible statement of "one tier ≈ one attribute point".
3. **Weapon/boots step = 2** per tier: two attribute-equivalents — a sword/boots slot is worth visibly more than the armor slot per tier, because 普攻/先攻 also gate tempo (fewer hits to kill; earlier action), which the coarse pass prices at ×2.
4. **Movement kicker is a step function, gated at tier ≥ 3**: 移动力 is the scarcest combat resource (2–4 across the whole run), so a whole extra tile is a *qualitative* jump — it belongs to 踏云履/凌波靴 only, and one threshold (`t >= 3`) keeps it formula-derived. `MOVE_BONUS_TIER_THRESHOLD`/`MOVE_BONUS` are constants, so phase 5 can move the gate without touching logic.

### 3.4 D4 — `BattleSetup`: read `equipped`, keep everything else byte-identical

```gdscript
static func derive_stats(profile) -> Dictionary:
    var bone: int = _attr(profile, "bone")
    var inner: int = _attr(profile, "inner")
    var agility: int = _attr(profile, "agility")
    var gear: Dictionary = EquipmentData.sum_bonuses(profile.get("equipped") if profile.get("equipped") != null else {})
    return {
        "max_health": bone * 5 + int(gear.get("health", 0)),
        "energy": inner * 2,
        "move_range": 2 + int(floor(float(agility) / 20.0)) + int(gear.get("move", 0)),
        "initiative": agility + int(gear.get("initiative", 0)),
        "attack_damage": 10 + bone + int(gear.get("attack", 0)),
        "attack_range": _attack_range_for(profile),
    }
```

- `profile.get("equipped")` (Object.get) instead of `profile.equipped` — null-safe against any duck-typed/legacy profile object in tests; missing → `{}` → all bonuses 0 → **output bit-identical to today's formula**. This empty-equip equality is unit-pinned (§7.1) and is also the reversibility baseline.
- `build_character` shape unchanged (same grade-slice logic, UX-14 untouched) but sets four new `CharacterData` fields from the same `sum_bonuses` result:

```gdscript
var gear: Dictionary = EquipmentData.sum_bonuses(profile.get("equipped") if profile.get("equipped") != null else {})
cd.gear_attack_bonus = int(gear.get("attack", 0))
cd.gear_health_bonus = int(gear.get("health", 0))
cd.gear_initiative_bonus = int(gear.get("initiative", 0))
cd.gear_move_bonus = int(gear.get("move", 0))
```

- `scripts/data/character_data.gd`: four additive `int` fields, default `0` (`gear_attack_bonus/gear_health_bonus/gear_initiative_bonus/gear_move_bonus`). Not serialized anywhere (CharacterData is a runtime Resource) → zero save-format impact. Tutorial-path CharacterData instances keep 0 → tutorial 编排数值 untouched.
- **Stale header fix (mandatory while the file is touched):** `battle_setup.gd:14–15` still says "GameManager.enter_battle is a stub — there is no live caller yet". Rewrite to state the real live caller (`scripts/battlefield.gd:651 BattleSetup.build_character(SaveManager.profile)` at encounter entry) and that gear now participates via `derive_stats`. Never silently delete prose that is wrong — replace it with the current fact.
- Snapshot semantics preserved (Step 1 edge case 11): `build_character` runs once at encounter entry; gear changes take effect at the **next** encounter. No mid-battle mutation path is added.

### 3.5 D5 — `RosterPanel`: from read-only to free-action writable (ruling recorded, not silently overwritten)

- **Header comment rewrite (ruling (e) of 2026-08-30 is superseded — see §8):** the paragraph at `roster_panel.gd:1–15` claiming "writes nothing … never touch a profile field" is replaced by the new fact: the panel now writes exactly one profile surface — `SaveManager.profile.equip(...)` / `unequip_slot(...)` from its item-row buttons; it still never calls `SaveManager.autosave()`/`save_game`, never consumes a month/action, never changes any phase or counter, and never writes any other profile field. The old guarantee's scope and its supersession are recorded in `design/90_decisions.md` (§8), never deleted.
- **Button pool (house pattern:** `CultOptionButton{i}` / `TravelButton{i}` / roster's own `pressed_connected` observables):
  - Eager pool `EquipButton0..EquipButton11` built in `_ready()` as children of the panel (`MAX_EQUIP_BUTTONS = 12` = the 12 distinct equipment cards), each `focus_mode = 0` (FOCUS_NONE — the `battle_focus_arrow_keys.yaml` defect class: a button holding built-in focus swallows `ui_up/ui_down` before `_unhandled_input`), `pressed` connected, hidden when its row doesn't exist.
  - `refresh()` recomputes the row map: for each index `i` of `p.inventory` where `EquipmentData.slot_of(id) != ""`, assign the next pool button `k`; button text = `tr("卸下")` if `p.equipped_id(slot) == id` else `tr("装上")` — **the button label is the equip state; no separate "已装备" text marker is added** (fewer strings, and it avoids a form-assertion trap on label text). Rows for non-equipment ids render text-only, exactly as today.
  - Row → id map kept in a member (e.g. `_equip_row_ids: Array[String]`); `_on_equip_pressed(k)` does the toggle: if `equipped_id(slot) == id` → `unequip_slot(slot)` else `equip(slot, id)`; then `refresh()`. **This handler is the only new profile write in the codebase.** No autosave. No month/phase/counter touched. Swap-on-equip means a player never needs unequip-first.
  - Pool cap honesty: inventory can hold duplicate ids (node events re-fire by policy, `design/20_content.md` §8.3 item 5), so row count can exceed 12 in principle. Rows beyond the cap keep today's text-only rendering (buttons capped at 12) — recorded as a known bound; every distinct id remains reachable (state is keyed by id, and any one row of an id can toggle it).
  - Geometry: buttons sit in the 物品 area of the existing fixed `RosterBox`, one per text line, right-aligned inside the box; must not overlap `RosterCloseButton`, the dim layer's hit region semantics, or any existing hit zone — `click:` true hit-testing is the proof, per the established rule.
- **New observables** (plain vars on `roster_panel.gd`, recomputed in `refresh()` from the live profile — same pattern as `item_count`):
  - `equipped_weapon: String`, `equipped_armor: String`, `equipped_boots: String` — mirrors of the three slots (via defensive `p.equipped_id(slot)`).
  - `equip_button_count: int` — pool rows currently bound.
  - `equip_pressed_connected: int` — count of pool buttons whose `pressed` is connected (house convention; proves wiring, catches a silently-disconnected rebuild).
- **Single-surface conformance preserved:** buttons only, `focus_mode = 0`, no "▶" list, so `cursor_markers_visible` stays computed-from-body and `false`; existing assertions (`roster_panel_cultivation_open_close.yaml`, `roster_panel_item_nail.yaml`) are not edited and must stay green unchanged.
- **Pure string builder invariant extended, not loosened:** `_compose_items` output for non-equipment inventories is byte-identical to today; `tests/test_roster_panel.gd` additions cover the equipment-row rendering (name resolution still via frozen `CardData.display_name_of`, degrade-lazily to raw id).

### 3.6 D6 — Save/load: nothing to migrate, everything to pin

- No schema migration, no file rewrite, no destructive step anywhere in this design (no backup/restore machinery needed — the only "migration" is `from_dict` defaulting, which is already the house pattern). `save_manager.gd` is **not modified**: `serialize_failed` guard (`:201–209`) already fails a save whose dict JSON.stringify can't serialize, and the String-key rule makes `equipped` safe by construction. `save_load_roundtrip` must stay green and its scenario gains nothing structural — the new field's round-trip is pinned at unit level (§7.1).
- Ruling (b) honored: equipment follows the cultivation save/load model — change the profile, never persist. **No autosave is added anywhere in this round.** A static guard test makes "someone adds an autosave call later" visible (§7.2).

### 3.7 D7 — i18n

New UI copy, minimal by design: `tr("装上")` and `tr("卸下")` (the brief's own verbs; deliberately **not** `装备`, which collides with the equipment-deck noun "Equipment" already implied by `CardData` copy — a verb/noun EN collision is exactly the kind of rebase annoyance the EN dictionary doesn't need). Keys appended to `scripts/autoload/i18n.gd`'s EN dictionary (`EN["装上"] = "Equip"`, `EN["卸下"] = "Unequip"`); implementer greps the dict first and reuses if an equivalent key already exists. `tests/test_i18n_coverage.py` stays green (it scans `tr()` call sites and `.text =` assignments — the pool buttons must set text via `tr(...)`, never a raw literal).

### 3.8 D8 — What is intentionally NOT built

No bonus-preview numbers in the panel (the visible effect lives in battle, which is the round's thesis; panel bonus text would invite literal-value assertions), no slot summary line, no equipment durability/repair, no enemy equipment, no new actions in `project.godot`, no new scenes, no changes to `scripts/camera_follower.gd`, `scripts/coord.gd`, `card_data.gd` rows, `event_logic.gd`, `display_name_of`, or any frozen camera/coordinate layer.

## 4. Component list & interfaces (repo-root-relative paths)

| # | File | Change | Interface surface |
|---|---|---|---|
| C1 | `scripts/data/equipment_data.gd` | **NEW** (~70 lines) | `SLOTS`, `SLOT_PREFIXES`, 5 formula constants, `slot_of(id) -> String`, `tier_of(id) -> int`, `bonuses_for(id) -> Dictionary`, `sum_bonuses(equipped) -> Dictionary`. Header comment carries the derivation pointer to `design/40_progression.md` §9. |
| C2 | `scripts/data/player_profile.gd` | extend | `equipped` field; `equipped_id/equip/unequip_slot`; `to_dict` + `_equipped_snapshot`; `from_dict` coercion (inventory-first, invariant repair). All existing behavior byte-identical for equipment-free saves. |
| C3 | `scripts/data/battle_setup.gd` | extend + header fix | `derive_stats` adds gear bonuses; `build_character` sets `cd.gear_*`; header :14–15 rewritten to the live-caller fact. `_sort_by_grade_rank` / grade-slice / `attack_range` logic untouched. |
| C4 | `scripts/data/character_data.gd` | extend (+4 fields) | `gear_attack_bonus/gear_health_bonus/gear_initiative_bonus/gear_move_bonus: int = 0`. |
| C5 | `scripts/characters/player.gd` | extend (mirror vars) | 4 mirror vars set where `CharacterData` stats are applied at spawn; exposed to the `Player` surface block. Enemies untouched (always 0 / not exposed). |
| C6 | `scripts/ui/roster_panel.gd` | extend + header rewrite | button pool + `equipped_weapon/armor/boots`, `equip_button_count`, `equip_pressed_connected`; `_on_equip_pressed(k)` free-action write; header comment rewritten per §3.5/§8. |
| C7 | `scenes/ui/roster_panel.tscn` | extend | pool buttons declared in the scene (or built in `_ready()` — implementer's choice; scene-declared preferred so `click:` hit-testing sees static nodes) inside `RosterBox`, `focus_mode = 0`. |
| C8 | `scripts/autoload/i18n.gd` | extend | `装上` / `卸下` EN entries. |
| C9 | `playtest/_common.yaml` | **append-only** | `RosterPanel` block += `equipped_weapon, equipped_armor, equipped_boots, equip_button_count, equip_pressed_connected`; new `EquipButton0:` / `EquipButton1:` blocks (`visible/size/mouse_filter/text/focus_mode`); `scenario_order` += `roster_equip_free_action`, `equipment_in_battle_diff` (tail, in that order). **No actions list change** (equip is click-only; no new input actions). |
| C10 | `playtest/roster_equip_free_action.yaml` | **NEW** | §6.2. |
| C11 | `playtest/equipment_in_battle_diff.yaml` | **NEW** | §6.3. |
| C12 | `tests/test_playtest_contract_smoke.py` | extend | `ROUND_SCENARIOS` += the two names (order-matched, two-place sync); new static contract test `test_equipment_surface_contract` (pattern of `test_facility_use_reusable_surface_contract`): the 5 RosterPanel observables whitelisted, the 4 `Player` gear observables whitelisted, both scenario names in `scenario_order` AND `ROUND_SCENARIOS`, each file carries ≥1 differential `: changed` line, no `*_ClickTarget` in clicks. |
| C13 | `tests/test_equipment_data.gd`, `tests/test_player_profile_equipment.gd`, `tests/test_battle_setup_equipment.gd` (or extensions of the existing files) | **NEW** | §7.1. |
| C14 | `tests/test_roster_panel.gd` | extend | string-builder + pool + free-action behaviors (§7.1). |
| C15 | `tests/test_roster_equipment_guards.py` | **NEW** (static pytest, `test_facility_copy_location.py` spirit) | (a) `roster_panel.gd` contains no `autosave(` / `save_game(` / `save_profile(` call; (b) `_common.yaml` `RosterPanel` block contains the 5 new observables (redundant with C12 but keeps the append-only promise checkable from the pytest side); (c) every `EquipButton` occurrence in `roster_panel.tscn` carries `focus_mode = 0`. Failure messages carry the escape clause: "if you are renaming/moving this guarantee, update this guard in the same change — do not delete it to go green." |
| C16 | `design/*` (5_design step, not implementation) | — | §8 list. |

## 5. Playtest contract (Architect-owned: observable surface + scenario skeletons)

### 5.1 Assertions discipline for this round

- Game-level only; no engine-level gates (`offset/position/size/z-order/mouse_filter` asserted only where an existing block already whitelists them for clickability, e.g. `EquipButton0.mouse_filter` is legitimate because the harness's own click is the subject).
- Differential (`changed`) or relational expressions; **no absolute tuned values** (`== 55`-style). Sanctioned literals in this round: id correspondence (`equipped_weapon == "eq_sword_3"`) and the zero-baseline relation (`gear_*_bonus == 0` = "no gear", the same shape as `facility_id == ""`).
- Clicks anchor on the real control (`EquipButton0`), never `*_ClickTarget`; `click:` is the true-hit-test proof that the equip button is actually pressable (occluded / IGNORE / zero-size would push_error).
- Gate assertions never pin the formula's constants (`ATTACK_PER_TIER` etc. appear in exactly one place: `equipment_data.gd` + the design doc).

### 5.2 Scenario A — `roster_equip_free_action.yaml` (free action + panel-level reversibility)

Direct `map.tscn` boot (the `roster_panel_item_nail.yaml` precedent), **clicks-only**. Skeleton (frames indicative, implementer re-baselines by measurement):

```
f30  assert  MapScreen.visible / phase == "TRAVEL" / current_node_id == "wuming_valley"
             RosterOpenButton.visible
f40  click   TravelButton0                         (→ luoyang, merchant auto-fires)
f50  assert  phase == "EVENT" / event_id == "merchant"
f60  click   EventOptionButton0                    (real grant path: eq_sword_3 → inventory)
f70  assert  phase == "TRAVEL" / events_resolved_count == 1
f80  click   RosterOpenButton
f90  assert  RosterPanel.is_open / equipped_weapon == ""  (baseline)
             equip_button_count >= 1 / equip_pressed_connected >= 1
             RosterPanel.cursor_markers_visible == false / MapScreen.cursor_markers_visible == false
f100 click   EquipButton0                          (装上)
f110 assert  equipped_weapon == "eq_sword_3" / equipped_armor == "" / equipped_boots == ""
             phase == "TRAVEL" / events_resolved_count == 1 / ended == false   ← free action
f120 click   EquipButton0                          (same node now reads 卸下)
f130 assert  equipped_weapon == ""                 ← panel-level reversibility, one round trip
f140 click   RosterCloseButton
f150 assert  is_open == false / phase == "TRAVEL" / events_resolved_count == 1 / ended == false
```

This scenario pins ruling (c) for the *write* path: the panel now writes `profile.equipped` and the month/phase/count invariants still hold byte-for-byte. (The cultivation-phase month/phase pins already live in the untouched `roster_panel_cultivation_open_close.yaml`.)

### 5.3 Scenario B — `equipment_in_battle_diff.yaml` (real grant → real equip → real encounter → changed → reverse)

Full boot through the proven `map_battle_node_huashan.yaml` route (start_map_battle is hard-gated to `current_state == MAP`; direct map boot leaves TUTORIAL — the huashan scenario measured this), **keyboard `ui_accept` for travel/event resolution (proven path), clicks for the roster leg (the touch path under test)**. Three encounter legs:

```
Leg 0  boot + travel (huashan route frames) — merchant resolves on the luoyang pass
       (option A grants eq_sword_3 regardless of silver; roster_panel_item_nail measured this)
Leg 1  encounter UNEQUIPPED (travel to huashan, ui_accept):
       assert  GameManager.current_state == "BATTLE" / CombatManager.tutorial_battle == false
               Player.gear_attack_bonus == 0 / Player.gear_health_bonus == 0
               Player.gear_initiative_bonus == 0 / Player.gear_move_bonus == 0
               Player.max_health: max_health > 0        (registers the observation for `changed`)
       debug_win_tutorial → WON → return to MAP (battle_return_state; huashan scenario left this
       leg untested — implementer MEASURES the return node and lays out the re-travel steps,
       "measured, not guessed", per the huashan header's own discipline)
Leg 2  equip through the panel (click RosterOpenButton → EquipButton{k} → RosterCloseButton):
       assert  equipped_weapon == "eq_sword_3", events_resolved_count unchanged across the
       open/equip/close (free action), then re-travel to huashan:
       assert  BATTLE / Player.gear_attack_bonus: changed      (0 → 2×3 = +6, direction-true)
               Player.gear_attack_bonus: gear_attack_bonus > 0
               Player.max_health: changed                      (armor slot empty; health bonus 0 —
                                                                the changed max_health is NOT expected
                                                                here; the expected diff carrier is
                                                                attack/initiative — see note)
       debug_win_tutorial → return to MAP
Leg 3  unequip through the panel (click EquipButton{k} again), re-travel:
       assert  Player.gear_attack_bonus == 0 / Player.gear_health_bonus == 0
               Player.gear_attack_bonus: changed               (equipped value → 0: reversed)
```

**Note on which stat carries the diff:** scenario B grants exactly one sword and equips it into the weapon slot → the guaranteed diffs are `attack_damage` (+2×3) via `gear_attack_bonus` and, through the mirror, the derived `Player` stats the surface already publishes (`max_health` carries the armor slot only). To make the **max_health** differential airtight without a second grant, Leg 2 additionally equips the armor granted if the deterministic seed produced one; if the measured inventory holds no armor, the health-slot diff stays on the unit level (§7.1: `derive_stats` diff with an armor equipped) and the scenario pins attack/initiative — the brief requires "气血/普攻/先攻之一" changed, and `changed` must be *true by the game*, not arranged. The implementer records which slots the measured boot inventory actually holds and writes the assertions against the measured rows (scenario header note, `map_battle_node_huashan.yaml` precedent of measuring focus steps instead of guessing them).

Frame budget ≈ 1000–1200 (< 2999 cap); asserts ≈ 30–40.

### 5.4 Surface whitelist appends (append-only, two-place sync)

- `RosterPanel` block: `equipped_weapon`, `equipped_armor`, `equipped_boots`, `equip_button_count`, `equip_pressed_connected`.
- New blocks `EquipButton0:`, `EquipButton1:` — `visible / size / mouse_filter / text / focus_mode`.
- `Player` block: `gear_attack_bonus`, `gear_health_bonus`, `gear_initiative_bonus`, `gear_move_bonus`.
- `scenario_order` tail: `roster_equip_free_action`, `equipment_in_battle_diff` — mirrored into `ROUND_SCENARIOS` (order-matched; `test_round_scenarios_present_on_disk_and_in_order` enforces the pairing). **The superset fixture (`tests/fixtures/playtest_assert_superset.json`) covers only the two authorized pre-edit scenarios and is NOT extended** — we do not edit `spine_to_ending.yaml` / `map_node_event_shaolin.yaml` at all this round; the reviewer's "superset fixture" obligation resolves to the ROUND_SCENARIOS two-place sync + the new static contract test (C12).

### 5.5 Hard downstream dependency (reviewer suggestion #3)

Per the implementer protocol, **every new/changed playtest scenario must be self-run via `godot_playtest_scenario` before delivery, with the observed values pasted into the delivery notes** — this is a hard condition, not advice. Additionally each new pin needs its **red-first four values measured, never predicted** (fail frame / first failing assertion / exact error string / green-before-red), using the sanctioned temporary-revert + direct-sidecar method (`roster_panel_item_nail.yaml` header and the 2026-08-30 `record_measured_red_first_and_reconcile` record are the templates). Suggested revert points: comment out the `_on_equip_pressed` body (scenario A goes red at its first `equipped_weapon` diff) and the `sum_bonuses` call in `derive_stats` (scenario B goes red at the first `gear_attack_bonus: changed`). The Step 1 lesson stands: predictions are wrong (predicted 8, measured 9) — measure.

## 6. Test plan

### 6.1 GDScript unit suite (extends the existing runner pattern)

- `test_equipment_data.gd`: `slot_of` for all 12 ids + `""`/`eq_axe_1`/`eq_sword` → ""; `tier_of` 1..4 → 1..4, `eq_sword_9`/`eq_sword_0`/`eq_sword_x`/`""` → 0; `bonuses_for` direction matrix (weapon feeds attack only; armor health only; boots initiative only; move only t≥3); monotonicity in tier; `sum_bonuses({})` == all zeros; `sum_bonuses` with hostile values (int instead of String) → treated as empty.
- `test_player_profile_equipment.gd`: default profile → three empty slots; `to_dict → JSON.stringify → JSON.parse_string → from_dict` preserves equipped exactly (String keys, no data loss); hostile `from_dict` (equipped = 42 / "x" / [..], values non-String, unknown slot keys) → defaults or dropped; equip validation matrix (§3.1); equip→unequip→`to_dict` equality with the pre-equip snapshot; equipped-id-not-in-inventory repaired to "" on load.
- `test_battle_setup_equipment.gd` (or extension): **legacy equality** — `derive_stats` on an empty-equipped profile equals the pre-round formula output for several attr tuples (this is the unit-level form of "old save falls back to current behavior without crashing"); equipped sword/armor/boots each move exactly their own stat and nothing else; reversibility (equip → stats differ → unequip → equal to legacy output again); `build_character` mirrors `cd.gear_*`; tutorial-shape CharacterData (not built via build_character) unaffected.
- `test_roster_panel.gd` extensions: non-equipment inventory renders byte-identical body text; equipment rows render names via `CardData.display_name_of`; after `equip`, `equipped_weapon` observable + button label state flip; `_on_equip_pressed` toggles and never mutates anything but `equipped`; pool cap behavior; `cursor_markers_visible` still false with buttons present.

### 6.2 Static pytest guards

- `tests/test_roster_equipment_guards.py` (C15) — no-autosave scan, surface appends, `focus_mode = 0` on pool buttons.
- Existing guards stay green untouched: `test_playtest_contract_smoke.py` (with the C12 additions), `test_facility_copy_location.py`, `test_i18n_coverage.py`, `test_shrimp_roster.py`.

### 6.3 Regression gates (acceptance mapping)

| Gate | Why it must stay green | Watchpoint specific to this round |
|---|---|---|
| `spine_to_ending` (42/42) | six-segment spine untouched; roster never opens in it | none expected |
| `roster_panel_cultivation_open_close` (16/16), `roster_panel_item_nail` (36/36) | open/close/grant-display behavior unchanged; free-action pins now extend to the write path | panel body grows no `▶`; buttons don't shift the close button's hit region |
| `save_load_roundtrip` (14/14) | equipped round-trips; no new save-time failures | `serialize_failed` guard stays silent (String keys) |
| `cultivation_changes_combat` (30/30) | `derive_stats` legacy-empty equality | empty-equipped output bit-identical |
| `map_battle_node_huashan`, `facility_use_reusable`, `clicks_only_storyline`, … | untouched surfaces | `Player` block appends are additive |
| compile gate (89/89 → +4 new/extended .gd files) | zero compile errors | — |
| full playtest hard gate `passed: true`, 0 runtime errors | — | scenario B's new timeline is the main new crash risk (measured frame layout) |

## 7. Technology choices

No new dependencies (Godot 4.4 stdlib + house patterns only, per Step 1). GDScript for all game code; Python stdlib for static pytest guards; YAML scenario files under the existing harness contract. `linter_manifest.json` re-emitted unchanged: `.gd` deliberately excluded (host-controlled `gdscript_check` gate), `.py` → `ruff`, `.md/.yaml/.yml/.json/.tscn` → `basic`.

## 8. Design-doc changes this round commits to (5_design executes; implementation must not self-declare)

1. **`design/90_decisions.md` — new ruling (2026-08-31, jinyong-equipment-battle)** superseding **2026-08-30 jinyong-roster ruling (e) 只读硬保证** (`design/90_decisions.md:494–496`). The ruling must state: why (e) was right *then* (that round's whole job was proving the panel produced zero side effects — open/close/refresh wrote nothing, and the read-only guarantee was the sharpest possible form of that proof), what changed *now* (equipment needs a write path, and the panel is the touch surface the brief designates for it), the precise new scope (the ONLY profile write is `equipped` via the item-row buttons; still no autosave, still free-action, still no month/phase/count change), and it must scope-correct the two neighboring 2026-08-30 claims that carried the old fact: (a) "面板是纯展示 overlay" and (f) "无装备语义" are true of everything *except* the item-row equip buttons. Nothing from the old ruling is deleted — supersession by explicit new record.
2. **`design/40_progression.md` §8** — the save-content table gains the `equipped` row (兵刃/护甲/鞋履 → inventory id or empty string; String keys, JSON-lossless). The table is the authority on what a save holds; unrecorded = undocumented.
3. **`design/40_progression.md` §9** — the tier→effect formula **with its derivation** (the §3.3 table: directions, steps, attribute-equivalent anchors, movement threshold, phase-5 re-tune note) moves from code into the archive; §9 also records explicitly that 战前选装 (UX-14) is **not** delivered this round and the auto-pick-top-2 rule is untouched — the promised player choice remains OPEN.
4. **`design/30_presentation.md`** — roster panel section: interactive equipment rows (装上/卸下 pool, focus_mode 0, free action, single-surface conformance, pool cap note).
5. **`design/40_ux_backlog.md`** — UX-13 → CLOSED(jinyong-equipment-battle) **with gate evidence** (scenario names + counts from the round's `playtest_summary.md`), written by the 5_design evidence step per rule 2 — never by the implementation self-declaring. UX-14 stays OPEN, untouched.
6. **`design/99_changelog.md`** — one appended row (2026-08-31, jinyong-equipment-battle), append-only.

## 9. Extensibility (deliberate, minimal)

- **Phase 5 re-tuning surface = 3 ints + 1 threshold + 1 bonus** in `equipment_data.gd`; nothing else references the magnitudes.
- **New equipment categories** (e.g. 护腕) = one `SLOT_PREFIXES` entry + one profile slot key + one `*_PER_TIER` constant; the panel pool, observables, and scenario patterns already generalize (`equipped_<slot>` naming).
- **Companions with gear** (out of scope, §6 of `40_progression.md`) can reuse `sum_bonuses` per-unit when that lands; nothing here hard-codes "player only" except the `Player` surface mirror.

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Inventory row index of 青锋剑 unknown at design time (fast-forward boot may draw deck cards; re-fired events can duplicate rows) | Scenario B's header records the measured row/button index after one observed run (`map_battle_node_huashan` measured-steps precedent); assertions target observables (`equipped_weapon == "eq_sword_3"`), so a wrong row click fails loudly, not silently |
| Post-battle return node after `debug_win_tutorial` unmeasured (huashan scenario deliberately skipped the return leg) | Implementer measures the return node first, then lays out Leg-2/3 travel steps; no assertion guesses a node id |
| `changed` semantics assumed observation-history-based (evidence: `MapScreen.silver: changed` passes with no prior silver assert in `roster_panel_item_nail`) | Scenario B pairs every `changed` with an explicit relational assert (`== 0` / `> 0`) so the pin holds under either semantics |
| Panel geometry overflow with many item rows | Buttons bounded by `MAX_EQUIP_BUTTONS = 12`, per-line placement inside the existing box; overflow rows keep text-only rendering (recorded bound) |
| `tr("装上")` key collision with an existing EN entry | Implementer greps `i18n.gd` first; reuse only if the EN translation fits a button verb |
| New observables unused by any scenario drift from the scripts | Whitelist-existence guard (block→script var mapping) catches renames; C12 keeps the two-place sync |
| Empty-equipped legacy save regression | Unit-pinned legacy equality + `cultivation_changes_combat` untouched-green |

## 11. Suggested task decomposition (for the PM)

- **T1 data layer:** C1 + C2 + their unit tests (green before anything consumes the field).
- **T2 battle layer:** C3 + C4 + C5 + unit tests (legacy-equality first, then diffs).
- **T3 panel:** C6 + C7 + C8 + `test_roster_panel` extensions.
- **T4 contract:** C9 + C10 + C11 + C12 + C15; self-run both scenarios, paste observed values + measured red-first four values into delivery notes.
- **T5 regression:** full gate suite + pytest set; zero red, `passed: true`.
- **T6 archive:** §8's design-doc set (separate 5_design step; UX-13 closure needs T5's gate evidence).

## 12. Acceptance-criteria coverage map

| Acceptance criterion | Carried by |
|---|---|
| Equip/unequip via touch only; month/phase/counts unchanged; close panel fully | Scenario A (§5.2) + untouched `roster_panel_cultivation_open_close` |
| Better sword measurably changes a real encounter; reversible; real code path (event grant → click equip) | Scenario B (§5.3): real `EventLogic` grant, real click, real `battlefield.gd:651` encounter, `changed` diffs, unequip return |
| Formula from tier, no 12 literals, derivation in design | C1 (one module, 5 constants) + §3.3 → `40_progression.md` §9 |
| Save-table record of `equipped`; JSON round-trip green | §8 item 2 + unit round-trip test + `save_load_roundtrip` |
| Ruling supersession recorded, never silent | §8 item 1 + C6 header rewrite |
| UX-13 closed with gate evidence; UX-14 OPEN | §8 items 3/5 |
| All existing pins green; i18n/contract/facility tests green; compile 0 errors | §6.3 table |
| Red-first values measured, not predicted | §5.5 |

## 13. Rollback

Nothing irreversible exists in this design: no save migration, no data rewrite, no file deletion, no rename of any frozen resource. A full revert of the round = dropping the new files and the additive edits; every pin added this round is additive to `_common.yaml`/`ROUND_SCENARIOS` and removable without touching any pre-existing assertion line.
