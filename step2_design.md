# 技术架构设计 — 门派设施 (Sect Facility Nodes)

**Project:** Sect Facility Nodes — implement the third jianghu map-node content type (`facility`), alongside `event` and `battle`.
**Round:** jinyong-facility · **Architect date:** 2026-08-29
**Input:** Step 1 SOTA report (passed review), Project Brief/Spec, design/ archive (20_content §8, 40_progression §5, 00_roadmap, 90_decisions). All file/symbol references below are direct-read verified against the current repo tree.

---

## 概述 (Overview)

Facility is the third entry-content type on the jianghu map node. The **definitional distinction** from the event slot — event is passive content that auto-fires on arrival; facility is something the player **actively chooses to use and can use repeatedly** — is the round's reason for being, and the architecture is built around making that distinction mechanically real and permanently observable, not just documented.

The design adds **no new economy**: facility effects route through the existing `EventLogic.apply_option_effects` / `PlayerProfile` mutators (silver / attr / practice / none — the closed effect domain from `event_data.gd` L10). A facility is a cost-gated (silver) opt-in action, reusable as long as the player can pay — naturally reusable, differentially assertable every use, and bounded by an existing resource rather than inventing a new one.

**Two nodes flip** from `declared` to `active`: **少林 (shaolin)** and **武当 (wudang)** — both are already sects, both already carry an active arrival event (`night_rain` / `quanzhen_scripture`), so the event+facility coexistence case is the norm, not an edge case, and is designed head-on. The remaining five nodes keep their facility slots honestly `declared`.

**Scope of irreversible / state-moving edits** (rollback plan in §10):
1. `scripts/data/map_data.gd` NODES table — flip 2 facility slots (data row edits; the const table is the source of truth, no migration needed — `declared_gap_types()` re-derives automatically).
2. `tests/fixtures/playtest_assert_superset.json` — re-baseline the shaolin frozen-scenario gap assert (documented exception, same precedent as the `events_resolved_count 1→2` re-baseline).
3. `playtest/map_node_event_shaolin.yaml` — re-derive the gap assertion lines (facility drops from the gap list; battle stays). Superset fixture guards "只许加,不许减" — the re-baseline exception is baked into the fixture FIRST, so the smoke test stays green through the edit.

---

## 架构图 (Architecture — components and data flow)

```
                    ┌─────────────────────────────┐
                    │  scripts/data/facility_data.gd  │  NEW — FacilityData.TABLE
                    │  (class_name FacilityData)       │  id / node / title / text /
                    │  def(id) · all() · _build()      │  action_label / effects[]
                    └──────────────┬──────────────────┘
                                   │ validated by
                    ┌──────────────▼──────────────────┐
                    │  scripts/data/map_data.gd         │  EDIT — NODES: flip 2 slots;
                    │  active_facility_id(id) -> Str    │  NEW accessor (symmetric with
                    │  declared_gap_types(id) (unchanged│  active_event_id / active_battle_id)
                    │  — auto re-derives)               │
                    └──────────────┬──────────────────┘
                                   │ resolved on travel, NOT on arrival
                    ┌──────────────▼──────────────────┐
                    │  scripts/segments/map.gd  (MapScreen)│  EDIT — new FACILITY phase
                    │  _travel() → _maybe_start_entry_   │  in the phase model. NEVER wired
                    │    event() → _maybe_start_entry_   │  into the arrival dispatch.
                    │    battle()  (UNCHANGED arrival)    │  Entered by explicit key only.
                    │                                      │
                    │  TRAVEL: use_facility key → enter   │  NEW surface observables:
                    │  FACILITY: ui_accept → _use_facility │  facility_id / facility_use_count
                    │            move_down/left → leave   │  last_facility_effect_types
                    └──────────────┬──────────────────┘
                                   │ effects via the SAME path as events
                    ┌──────────────▼──────────────────┐
                    │  scripts/data/event_logic.gd      │  UNCHANGED — EventLogic.apply_
                    │  (EventLogic, pure-static)        │  option_effects(profile, opt)
                    └──────────────┬──────────────────┘
                                   │ mutates
                    ┌──────────────▼──────────────────┐
                    │  scripts/data/player_profile.gd   │  UNCHANGED — add_attr / silver /
                    │  (PlayerProfile, RefCounted)       │  add_gongfa / ATTR_FLOOR
                    └─────────────────────────────────┘

  Observability surface (playtest/_common.yaml MapScreen block — append-only):
    facility_id · facility_use_count · last_facility_effect_types   ← NEW (3 vars)
    phase (now carries "FACILITY") · entry_declared_gap_types (auto) ← existing, extended

  Keyboard:
    project.godot [input]:  use_facility (F)  ← NEW player-facing action
                            debug_grant_silver     ← NEW debug-injection action
```

---

## 组件列表 (Component list)

### Component 1 — FacilityData module  [NEW]
- **File:** `scripts/data/facility_data.gd`
- **Responsibility:** The single sanctioned text source for all facility prose (the §433 rule — no inline anecdotes in `map_data.gd` / `map.gd`). Mirrors `EventData.TABLE` + `def(id)` / `all()` builder pattern byte-for-byte.
- **Schema:**
  - `class FacilityOption extends RefCounted` — NOT needed; a facility has one action, not a binary choice (that is the event shape; a facility with option_a/option_b would be "a second event"). Instead, the facility carries a flat `effects` array.
  - `class FacilityDef extends RefCounted`:
    - `id: String` — e.g. `"shaolin_wooden_men"`
    - `node: String` — the node id this facility binds to (`"shaolin"` / `"wudang"`)
    - `title: String` — Chinese, e.g. `"木人巷"`
    - `text: String` — 2-line Chinese body
    - `action_label: String` — the use prompt, e.g. `"入巷练骨"`
    - `effects: Array[Dictionary]` — same shape as `EventData.EventOption.effects`: each `{"type": "silver"|"attr"|"practice"|"none", "value": int, "target": String}`. The silver cost is carried as a `silver` effect with a negative value (exactly like `night_rain` option A: `[{"type":"silver","value":-6},{"type":"attr","value":1,"target":"bone"}]`).
  - `const TABLE: Array` — 2 rows (shaolin, wudang). Concrete copy (placeholder magnitudes, NOT tuned):
    - **shaolin_wooden_men** (少林·木人巷): `[{"type":"silver","value":-8},{"type":"attr","value":2,"target":"bone"}]` — pay 8 silver, gain 2 根骨 (the body-hardening facility; distinct from night_rain's bone gain).
    - **wudang_meditation** (武当·紫霄静修): `[{"type":"silver","value":-8},{"type":"attr","value":2,"target":"inner"}]` — pay 8 silver, gain 2 内力 (the qi-cultivation facility).
  - `static func def(id) -> FacilityDef` — fresh instance; null if unknown.
  - `static func all() -> Array[FacilityDef]` — table order.
  - `static func _build(row) -> FacilityDef` / `_build` helpers — mirror EventData.
  - `static func for_node(node_id) -> FacilityDef` — convenience: the facility bound to a node (scans TABLE for `row.node == node_id`); null if none. This is the single resolution point `active_facility_id()` in MapData delegates to.
  - `static func silver_cost(def) -> int` — the absolute silver price, derived from the `silver` effects (sum of negative values, absolute). This is what the cost-gate in map.gd checks against `profile.silver`.

### Component 2 — MapData edits  [EDIT existing]
- **File:** `scripts/data/map_data.gd`
- **Changes:**
  1. **NODES table** — flip the `facility` slot on `shaolin` and `wudang` from `{"status": "declared", "facility_id": ""}` to `{"status": "active", "facility_id": "shaolin_wooden_men"}` / `{"status": "active", "facility_id": "wudang_meditation"}`. All other nodes' facility slots stay `declared / ""`.
  2. **NEW accessor** `active_facility_id(id) -> String` — symmetric with `active_event_id` / `active_battle_id`: returns the `facility_id` iff the slot `status == "active"` AND `FacilityData.def(facility_id) != null`; `""` otherwise (typo-safe inert, fail-safe, never crashes). This is the single resolution point — `declared_gap_types()` needs NO change (it already reads whatever `status` each slot carries; flipping 2 slots to `active` makes it auto-drop `facility` from shaolin/wudang gap lists).
  3. Add `const FacilityData = preload("res://scripts/data/facility_data.gd")` at the top (one-way edge: facility_data.gd is pure data and does not reference map_data.gd, mirroring the EventData preload).
- **No second computation:** `declared_gap_types(id)` is unchanged — it reports whatever is still `declared`. After the flip: shaolin → `[battle]`, wudang → `[battle]`, wuming_valley/luoyang/xiangyang → `[battle, facility]`, kunlun → `[event, battle, facility]`, huashan → `[event, facility]`. The honesty observable MOVES — that is its job.

### Component 3 — MapScreen FACILITY phase  [EDIT existing]
- **File:** `scripts/segments/map.gd`
- **Changes:**
  1. **NEW surface vars** (mirrors the event observable set):
     - `var facility_id: String = ""` — the active facility id while in FACILITY phase ("" otherwise).
     - `var facility_use_count: int = 0` — session count of facility uses (ladder 0→1→2…; persists across visits because MapScreen stays loaded).
     - `var last_facility_effect_types: Array[String] = []` — effect "type"s of the last facility use, in order (mirrors `last_effect_types`).
  2. **Phase model:** `phase` gains a `"FACILITY"` value. The phase string is already a surface var; no new var, just a new value.
  3. **Input — `_unhandled_input`** (keyboard-driven, no new click target, no `*_ClickTarget`, no mouse_filter work):
     - In **TRAVEL**: if `Input.is_action_pressed("use_facility")` AND `MapData.active_facility_id(current_node_id) != ""` → enter FACILITY phase (`_enter_facility()`). This is the opt-in — the player actively chooses to use the facility. `ui_accept` still travels (unchanged); the facility entry is a separate key, so travel and facility-enter never conflict.
     - In **FACILITY**: `ui_accept` → `_use_facility()` (pay cost, apply effects, stay in FACILITY so it can be used again); `move_down` or `move_left` → leave (`_leave_facility()` → back to TRAVEL). This mirrors the EVENT phase's `move_up/left` ↔ `move_down/right` + `ui_accept` grammar.
  4. **`_enter_facility()`**: set `facility_id = MapData.active_facility_id(current_node_id)`, `phase = "FACILITY"`, `_sync_surface()`, `_render()`. Does NOT auto-use — the player still must press `ui_accept` to actually use it.
  5. **`_use_facility()`**: 
     - `var def = FacilityData.def(facility_id)`; if null, return.
     - **Cost-gate:** `var cost = FacilityData.silver_cost(def)`; if `SaveManager.profile.silver < cost` → refuse (do NOT apply effects; render a "银两不足" refusal; `facility_use_count` does not increment). This is the natural reuse limiter (existing silver resource), not a new economy. **Reuse is bounded only by silver this round** (i.e. effectively unbounded above the cost — silver→attr has no cap here); a per-visit / per-period / pure-silver-limit cap is a **PENDING phase-5 numerical decision** (recorded for `design/90_decisions.md` in the Docs table), NOT settled balance — a later round must not read the silver gate as the final word on the reuse ceiling.
     - If affordable: build a transient `EventData.EventOption` with `opt.effects = def.effects.duplicate(true)`, call `EventLogic.apply_option_effects(SaveManager.profile, opt)` (the SAME pure-static path events use). Record `last_facility_effect_types` from `def.effects`. Increment `facility_use_count`. `SaveManager.autosave()`. `_sync_surface()`, `_render()`. **Stays in FACILITY** — the player can use it again immediately or leave.
  6. **`_leave_facility()`**: `facility_id = ""`, `phase = "TRAVEL"`, `_sync_surface()`, `_render()`.
  7. **`_sync_surface()`**: append `facility_id` and `facility_use_count` and `last_facility_effect_types` mirroring (the profile mirrors `silver`/`attr_*` are already synced — the facility's silver/attr effects land through the same profile, so the existing mirrors pick them up with no extra code).
  8. **`_apply_hint_visibility()`**: change `hint.visible = phase != "EVENT"` → `hint.visible = phase == "TRAVEL"`. The travel hint shows ONLY in TRAVEL; it is hidden in both EVENT and FACILITY (the FACILITY panel renders its own prompt in BodyLabel). The smoke test pin (`"visible = phase" in src`) stays green — `hint.visible = phase == "TRAVEL"` still contains the substring `"visible = phase"`.
  9. **`_render()`** — add a FACILITY branch (before the TRAVEL fallback):
     - If `phase == "FACILITY"`: render `tr("【%s】\n\n%s\n\n%s\n\n%s") % [tr(def.title), tr(def.text), <cost/effect summary>, tr("回车使用 · 上下离开")]`. The cost/effect summary is composed from `def.effects` (e.g. `"银两 −8 · 根骨 +2"`). If the last use was refused (silver < cost), append `tr("银两不足")`.
     - In the TRAVEL branch: if `MapData.active_facility_id(current_node_id) != ""`, append a facility-hint line to the BodyLabel text: `tr("\n\n门派设施：%s（F 使用）") % tr(FacilityData.def(...).title)` — so the player can SEE the facility exists at this node and knows which key enters it.
  10. **CRITICAL — arrival dispatch is UNCHANGED:** `_travel()` calls `_maybe_start_entry_event()` then (if not EVENT) `_maybe_start_entry_battle()`. The facility is NEVER added to this chain. A facility is entered ONLY by the explicit `use_facility` key in TRAVEL phase. This is the definitional property: arrival never enters a facility; only an explicit choice does.

### Component 4 — Input actions  [EDIT project.godot]
- **File:** `project.godot` `[input]` section
- **NEW player-facing action:** `use_facility` — bound to physical key `F` (lower + upper). Mnemonic: "Facility". This is the ONLY new player-facing key.
- **NEW debug action:** `debug_grant_silver` — bound to an unused physical key (implementer's choice; debug-only, not player-facing). Injects silver into the profile for the facility scenario's cost precondition (the `_fast_forward` cultivation path always picks practice/cultivate, never "work" — verified: `cultivation.gd::_fast_forward` L506-516 — so the player arrives at the map with 0 silver). `debug_grant_silver` is handled in `map.gd::_process` (same dispatch shape as `cultivation.gd::_process` debug actions), but it **MUTATES silver through the normal pipeline — NEVER a bare field assignment**. Concretely: it builds a transient `EventData.EventOption` carrying a single `{"type":"silver","value":<fixed amount>}` effect and calls `EventLogic.apply_option_effects(SaveManager.profile, opt)` — the SAME pure-static path the facility's own `_use_facility()` silver cost (Component 3) and every event/card silver effect take (the `apply_option_effects` silver branch = `profile.silver = maxi(profile.silver + value, 0)`, verbatim with `cultivation.gd:268-269`; `PlayerProfile` exposes no dedicated silver mutator, so this IS the existing silver-mutation path). **Rationale** (roadmap "测试怎么写" rule 2 — 注入一律走正常管线,不直接改字段): a bare `SaveManager.profile.silver += N` would validate a mutation path the player can never reach AND bypass the clamp-to-≥0 floor; routing through `apply_option_effects` tests the exact code the player exercises, floor included. The amount is a single literal; it is NOT tuned — it just needs to be ≥ 2 × facility cost so the scenario can use the facility twice.
- Both actions MUST be added to `playtest/_common.yaml` `actions:` list (append-only).

### Component 5 — i18n strings  [EDIT existing]
- **File:** `scripts/autoload/i18n.gd` EN dictionary
- **NEW strings** (Chinese-as-key; every one gets an EN entry so `tests/test_i18n_coverage.py` stays green):
  - Facility titles: `"木人巷"` → `"Wooden Men Alley"`, `"紫霄静修"` → `"Purple Cloud Meditation"`
  - Facility body text (2 lines each) — verbatim from `facility_data.gd` TABLE
  - Facility action labels: `"入巷练骨"` → `"Enter the Alley to Tempermord"`, `"静室修内"` → `"Meditate for Inner Qi"`
  - Facility prompt: `"回车使用 · 上下离开"` → `"Enter to use · Up/Down to leave"`
  - Refusal: `"银两不足"` → `"Not enough silver"`
  - Travel facility hint: `"\n\n门派设施：%s（F 使用）"` → `"\n\nSect facility: %s (F to use)"`
  - Cost/effect summary fragments: `"银两 −%d"` → `"Silver −%d"`, `"根骨 +%d"` → `"Bone +%d"`, `"内力 +%d"` → `"Qi +%d"` (composed at runtime — wrapped in `tr()`)
- **Constraint:** `tests/test_i18n_coverage.py` checks scene `text=`, `tr()` call sites, and `.text =` direct assigns. All new strings are either in the EN dict (keys) or composed via `tr()` at runtime. The coverage test stays green.

### Component 6 — Playtest scenario (58th)  [NEW]
- **File:** `playtest/facility_use_reusable.yaml`
- **Basename == `name:`** = `facility_use_reusable`.
- **Two-place sync:** added to `_common.yaml scenario_order` tail (after `camera_transform_follows_unit`, becoming the 58th) AND to `tests/test_playtest_contract_smoke.py ROUND_SCENARIOS` tail (same order).
- **Surface whitelist** (append to `MapScreen` block in `_common.yaml`, in the SAME edit as the scenario — never land a scenario with unpublished observables, even transiently):
  - `facility_id`, `facility_use_count`, `last_facility_effect_types`
  - `use_facility` and `debug_grant_silver` added to `actions:` list (same edit)
- **Scenario skeleton** (the implementer/PM fills exact `at:` frames and thresholds; the Architect defines the structure and the assertions' shapes):
  - Boot: full boot (main.tscn → 7× ui_accept → debug_win_tutorial → creation → cultivation → debug_fast_forward → MAP), mirroring `map_node_event_shaolin.yaml`'s boot prefix (the facility needs the same MAP-state setup). Route to shaolin (wuming_valley → luoyang → shaolin, resolving intermediate events).
  - **Arrival half (the permanent negative assertion — definitional property):**
    - At the shaolin arrival frame: assert `MapScreen.phase == "EVENT"` (the arrival event fired) **PLUS** `MapScreen.phase != "FACILITY"` **PLUS** `MapScreen.facility_id == ""` **PLUS** `MapScreen.facility_use_count == 0` — merely arriving has used the facility zero times.
    - Resolve the arrival event (ui_accept) → TRAVEL. Re-assert `MapScreen.facility_use_count == 0` and `MapScreen.facility_id == ""` — resolving an event cannot smuggle a facility use in.
  - **Choice half (the positive assertion — active, reusable, observable):**
    - No travel between these frames. `debug_grant_silver` (fund the profile — verified: 0 silver after fast-forward). Then `use_facility` → assert `MapScreen.phase == "FACILITY"`, `MapScreen.facility_id == "shaolin_wooden_men"`, `MapScreen.facility_use_count == 0` (entered but not yet used).
    - `ui_accept` → use. Assert `MapScreen.facility_use_count == 1`, `MapScreen.silver: changed`, `MapScreen.attr_bone: changed`, `MapScreen.last_facility_effect_types == ["silver", "attr"]` (all differential/relative — no absolute game-value literals).
    - `move_down` → leave. Assert `MapScreen.phase == "TRAVEL"`, `MapScreen.facility_id == ""`, `MapScreen.facility_use_count == 1` (count persists).
    - Travel away and back (shaolin → luoyang → shaolin, resolving intermediate events). Arrive again.
    - `use_facility` → `MapScreen.phase == "FACILITY"`, `MapScreen.facility_use_count == 1` (still 1).
    - `ui_accept` → use again. Assert `MapScreen.facility_use_count == 2`, `MapScreen.attr_bone: changed` again.
  - **`description:`** must state that the arrival half (negative assertion) is the DEFINITIONAL PROPERTY of the content type (event = fires on arrival; facility = entered by choice), not redundancy — deleting it deletes what this round established.
- **Assert grammar** (verified in-repo, no harness change needed): `!=` appears in `each_unit_acts_once_per_round_initiative_order.yaml` and `event_travel_effects.yaml`; compound `and` appears in `qi_cost_blocks_cast_no_energy.yaml`. The negative assertion `phase != "FACILITY"` and compound `phase == "EVENT" and phase != "FACILITY"` use the same grammar.

### Component 7 — Anti-deletion guard  [HARD REQUIREMENT — elevated from SOTA "recommended"]
- **File:** `tests/test_playtest_contract_smoke.py`
- **Pin:** a static text guard requiring `playtest/facility_use_reusable.yaml` to contain BOTH a `phase != "FACILITY"` line AND a `facility_use_count == 0` line — exactly the shape of the existing honesty pin that requires `map_node_event_shaolin`'s gap line to reference both `"battle"` and `"facility"` (`test_map_node_event_surface_contract` L762-772).
- **Why HARD, not "recommended":** the permanent negative assertion (Component 6's arrival half) is the ONLY guard against a future round wiring the facility into the arrival dispatch — the project's recurring failure shape where the property that defines a thing has no observation point, and the recurring failure shape ONE LEVEL UP where the observation point itself is silently deletable. Without this pin, the permanent assert is itself silently deletable. The Step 1 review explicitly recommended elevating it; this design makes it a hard requirement.
- Also pin (same test): the facility scenario's `name:` equals its basename, every timeline `at:` is a single integer, every 4-space dotted assert line carries a comparison operator or the `changed`/`unchanged` differential token (same shape as all other round-scenario static checks).

### Component 8 — Re-baseline the shaolin scenario gap asserts  [EDIT existing — authorized]
- **Files:** `playtest/map_node_event_shaolin.yaml`, `tests/fixtures/playtest_assert_superset.json`
- **What moves:** shaolin's `facility` slot flips to `active`, so `entry_declared_gap_types` at shaolin drops `facility` → `[battle]`. The two existing gap-assert lines in `map_node_event_shaolin.yaml` (f460, f560) currently read `entry_declared_gap_types.has("battle") and entry_declared_gap_types.has("facility")`. They must be re-derived to `entry_declared_gap_types.has("battle") and not entry_declared_gap_types.has("facility")` (facility is no longer a gap; battle still is).
- **Superset fixture:** the frozen baseline in `playtest_assert_superset.json` currently bakes the pre-edit expression `entry_declared_gap_types.has("battle") and entry_declared_gap_types.has("facility")` for shaolin (L52). The fixture must be updated FIRST (bake the post-edit expression), mirroring the `events_resolved_count == 1 → == 2` sanctioned-exception precedent (L3-9). This keeps `test_edited_scenarios_assert_superset` green through the edit.
- **Red-then-green discipline:** the measured red value from BEFORE the flip (facility still `declared`) must be recorded in the delivery report: the new facility scenario's first facility assert reads the empty/absent state — e.g. `MapScreen.phase == "FACILITY"` reads `"TRAVEL"`, or `MapScreen.facility_id == "shaolin_wooden_men"` reads `""`, or `facility_use_count` is undefined (surface not yet whitelisted). The measured value from that red run is recorded; a green-only nail does not count.
- **One-time vs standing:** the red-then-green evidence (item 12 in SOTA) is ONE-TIME-ONLY — it vanishes the moment the scenario turns green and protects nothing afterwards. The standing negative assertion (Component 6's arrival half + Component 7's anti-deletion pin) is what carries the definitional property forward. The design states these together so a later reader does not mistake the red signature for a lasting guard.
- **Spine stays green:** `spine_to_ending.yaml` walks 武当 (a facility node) at f480. The facility never auto-fires and never consumes input on arrival, so the spine is invisible to it. The spine's 武当 block handles the arrival event and walks on. No edit to `spine_to_ending.yaml` needed.

### Component 9 — §433 copy-location guard  [NEW — recommended, scoped to prose]
- **File:** `tests/test_facility_copy_location.py` (stdlib-only pytest, the `test_i18n_coverage.py` shape — no PyYAML, no Godot)
- **What:** scans `scripts/data/map_data.gd` and `scripts/segments/map.gd` for **prose-length CJK string literals** (regex for `"..."` containing ≥ 4 CJK chars) and fails if any NEW one appears that is not in a sanctioned allowlist. Goes red only on newly-inlined copy; green on day one.
- **Sanctioned day-one allowlist (enumerated explicitly, per Step 1 review suggestion):**
  - The travel hint: `"左右/上下选择相邻去处，回车启程"`
  - The map header: `"【江湖行路】\n\n"`
  - The here/reachable markers: `"▶ %s（此处）\n"`, `"  %s（可前往）\n"`
  - The current-node footer: `"\n当前：%s"`
  - The event-panel template: `"【%s】\n\n%s\n\n%s\n%s\n\n上下选择，回车定夺"`
  - Node `display_name` values: `"无名谷"`, `"洛阳"`, `"武当"`, `"襄阳"`, `"昆仑"`, `"少林"`, `"华山"` (these are data, not prose, but they are CJK literals in `map_data.gd`)
  - The facility travel-hint template (NEW this round, sanctioned): `"\n\n门派设施：%s（F 使用）"`
- **Why scoped to prose, not "zero CJK":** a stricter "zero CJK in map_data.gd" variant needs the same allowlist, so the extra strictness buys nothing. Prose-length (≥4 CJK) catches newly-inlined anecdotes while letting short identifiers/markers through.
- **Accepted alternative (if judged over-defence):** skip the guard AND record in `design/99_changelog.md` / `design/90_decisions.md` that §433 remains an unguarded documentation-only rule. Either conclusion is acceptable; an unexamined silence is not.

---

## 技术栈 (Technical stack)

- **Godot 4.4 + GDScript** — the project runtime; no new engine, no new libraries, no art, no numerical tuning.
- **`scripts/data/facility_data.gd`** — new dedicated data module (EventData.TABLE mirror) = the single home for all facility copy.
- **`scripts/data/map_data.gd`** — 2-slot flip + `active_facility_id()` accessor (symmetric with `active_event_id` / `active_battle_id`).
- **`scripts/segments/map.gd`** — `FACILITY` phase, opt-in/keyboard-driven, **never** in the arrival dispatch; observables through `_sync_surface()` (existing convention, not recomputed).
- **`scripts/data/event_logic.gd`** — UNCHANGED. Facility effects route through `EventLogic.apply_option_effects` (the same pure-static path events use) by constructing a transient `EventData.EventOption` with the facility's `effects` array. Zero new economy.
- **`scripts/data/player_profile.gd`** — UNCHANGED. The facility touches `silver` / `add_attr` through the same mutators.
- **`scripts/autoload/i18n.gd`** — EN dictionary gains all new facility strings.
- **`project.godot [input]`** — `use_facility` (F) + `debug_grant_silver` (debug).
- **Playtest:** one new scenario (58th) + re-baseline of shaolin gap asserts + anti-deletion pin + (optional) §433 copy-location guard.
- **Unit tests:** extend `tests/test_map_data.gd` / `tests/test_map_node_event.gd`, new `tests/test_facility_data.gd` (registered in `tests/unit_test_runner.gd` TESTS — append-only).

---

## 接口规范 (Interface specifications)

### FacilityData ↔ MapData
```
# map_data.gd
const FacilityData = preload("res://scripts/data/facility_data.gd")

static func active_facility_id(id: String) -> String:
    # Returns facility_id iff slot.status == "active" AND FacilityData.def(facility_id) != null
    # else "" (typo-safe inert — a dangling facility id reads as inert, never crashes)
```

### MapData ↔ MapScreen
```
# map.gd reads (TRAVEL phase, deciding whether to show the facility hint / allow entry):
var fid: String = MapData.active_facility_id(current_node_id)   # "" or the id
# map.gd reads (FACILITY phase, resolving the def):
var def = FacilityData.def(facility_id)                          # FacilityDef or null
var cost: int = FacilityData.silver_cost(def)                    # the silver gate
```

### MapScreen ↔ EventLogic (effect application — the SAME path as events)
```
# _use_facility():
var opt = EventData.EventOption.new()
opt.effects = def.effects.duplicate(true)   # the facility's silver-cost + gain effects
EventLogic.apply_option_effects(SaveManager.profile, opt)   # SAME pure-static path
```

### MapScreen surface observables (playtest contract)
```
MapScreen (append to _common.yaml surface block, in this order):
  - facility_id            # "" in TRAVEL/EVENT; the id in FACILITY
  - facility_use_count     # session ladder 0 -> 1 -> 2 ...
  - last_facility_effect_types  # ["silver", "attr"] etc — mirrors last_effect_types
# phase already whitelisted; now carries "FACILITY" as a value
# entry_declared_gap_types already whitelisted; auto-reflects the 2-slot flip
# silver / attr_bone / attr_inner already whitelisted; facility effects land through them
```

### Keyboard contract
```
project.godot [input]:
  use_facility = KEY_F (physical, lower+upper)    # NEW player-facing
  debug_grant_silver = <unused key>                # NEW debug-only

map.gd _unhandled_input:
  TRAVEL:    use_facility + active_facility_id != "" -> _enter_facility()
  FACILITY:  ui_accept -> _use_facility()  |  move_down/move_left -> _leave_facility()
  (EVENT and all other phases: unchanged)
```

---

## 测试计划 (Test plan)

### GDScript unit suite (register in `tests/unit_test_runner.gd` TESTS — append-only)
1. **`tests/test_facility_data.gd`** [NEW] — FacilityData schema pins:
   - `TABLE` has exactly 2 rows; each `def(id)` resolves; `for_node("shaolin")` / `for_node("wudang")` return the right def; `for_node("luoyang")` returns null (no facility there).
   - Each def's `effects` use only the closed domain {silver, attr, practice, none}; the silver cost (`silver_cost(def)`) is > 0 and matches the silver effect magnitude (cost-gate consistency).
   - Each effect lands through `EventLogic.apply_option_effects` on a local `PlayerProfile` (silver deducts with clamp; attr gains land floor-aware) — the parity test shape from `test_map_node_event.gd::_test_event_logic_parity`.
2. **`tests/test_map_data.gd`** [EDIT] — extend `_test_entry_content`:
   - `active_facility_count == 2` (was 0); `active_facility_id("shaolin") == "shaolin_wooden_men"`, `active_facility_id("wudang") == "wudang_meditation"`, `active_facility_id("luoyang") == ""` (declared stays inert).
   - **Per-node gap pins — the load-bearing evidence; the count alone is NOT sufficient.** The existing test (`test_map_data.gd` ~L152-156) pins `declared_gap_types` only for `luoyang` / `wuming_valley` / `shaolin`; **`wudang` has NO per-node pin today.** An implementer who flips shaolin+luoyang (not shaolin+wudang) would still see `active_facility_count == 2` go green while wudang stays unimplemented — the recurring "honest observable degrades into a count" failure shape. Closed by moving the observable PER-NODE:
     - **ADD** `declared_gap_types("wudang") == ["battle"]` — NEW pin, same shape as the existing three; wudang flipped ⇒ `facility` drops from its gap list.
     - **RE-DERIVE** the existing `declared_gap_types("shaolin")` line to `["battle"]` (facility dropped).
     - **KEEP** `declared_gap_types("luoyang") == ["battle", "facility"]` and `declared_gap_types("wuming_valley") == ["battle", "facility"]` UNCHANGED — the "not-flipped-still-honest" controls proving the flip did not fake the remaining nodes to look better.
   - The active-slot total is now 8 (5 events + 1 battle + 2 facilities), counted separately by type. The count is retained as a cross-check but is NO LONGER the sole evidence — the per-node gap pins are. (A wudang playtest scenario is optional, not required; the unit pin is the hard guard.)
3. **`tests/test_map_node_event.gd`** [EDIT] — extend with a facility phase test (`_test_map_facility_phase`):
   - Instantiate MapScreen, set up at shaolin, travel there (arrival event fires → resolve → TRAVEL).
   - **Negative:** after arrival, `phase != "FACILITY"`, `facility_id == ""`, `facility_use_count == 0`.
   - Fund the profile (local, `profile.silver = cost + 1`). Call `_enter_facility()` (or simulate the key) → `phase == "FACILITY"`, `facility_id` set, `facility_use_count == 0`.
   - Call `_use_facility()` → `facility_use_count == 1`, `last_facility_effect_types == ["silver","attr"]`, silver decreased, attr increased (all derived from the def, no absolute literals).
   - Call `_use_facility()` again → `facility_use_count == 2` (reusable).
   - Call `_leave_facility()` → `phase == "TRAVEL"`, `facility_id == ""`, `facility_use_count == 2` (count persists).
   - Cost-gate: set `profile.silver = cost - 1`, call `_use_facility()` → refused, `facility_use_count` unchanged, effects not applied.

### Playtest contract
- **New scenario:** `playtest/facility_use_reusable.yaml` (Component 6) — 58th, two-place sync, both halves of the definitional property.
- **Re-baseline:** `playtest/map_node_event_shaolin.yaml` gap asserts (Component 8) + superset fixture.
- **Smoke test pins:** `tests/test_playtest_contract_smoke.py` — new scenario presence/order/whitelist, the authorized shaolin re-derivation, the anti-deletion pin (Component 7).
- **All existing scenarios stay green:** the facility never auto-fires, never consumes arrival input, never touches the camera/coordinate layer. `spine_to_ending` (42/42), `save_load_roundtrip` (14/14), `event_travel_effects` (19/19), `map_battle_node_huashan` — all untouched.

### Compile + i18n + contract smoke
- `gdscript_check` gate: 0 errors (new `facility_data.gd` + edited `map_data.gd` / `map.gd` + new test files).
- `tests/test_i18n_coverage.py`: green (all new strings in EN dict).
- `tests/test_playtest_contract_smoke.py`: green (the edits are the authorized re-baseline + new scenario pin + anti-deletion pin).

---

## 文档同步 (Docs updates — docs-first, in sync)

| File | Change |
|---|---|
| `design/20_content.md` §8.1 | Six-node table: shaolin + wudang facility slots `declared → active` with their `facility_id`s. |
| `design/20_content.md` §8.3 | Gap note 2 ("facility: declared, unimplemented") → updated: facility is now implemented at shaolin/wudang; the remaining 5 nodes stay declared. |
| `design/20_content.md` | NEW §10 or append to §8: the facility definition (event = fires on arrival; facility = entered by choice, reusable, cost-gated by silver, effects via EventLogic), the 2 facility data rows, the arrival-never-enters-facility invariant. |
| `design/00_roadmap.md` | Completeness table entry 2: `facility ❌ 仅声明` → `facility ✅ (少林/武当)`. Entry 4: `❌ 立绘几何四条缺口` → `✅` (the four gaps — portrait-height, nameplate-on-leg, trait-click-to-show, no-mobile-retreat — all landed in prior rounds; this is the stale/outdated entry the brief calls out). |
| `design/99_changelog.md` | One row (2026-08-29): facility implemented at shaolin/wudang; the definitional property + permanent negative assertion; the re-baseline; the red-then-green record. |
| `design/90_decisions.md` | NEW rulings: (a) event/facility precedence — arrival never enters a facility, only an explicit key does, pinned by a permanent negative assertion; (b) the re-baseline exception for the shaolin gap assert; (c) the §433 guard conclusion (adopted guard or recorded unguarded); (d) the red-then-green record is one-time, the standing negative assertion carries the property forward; (e) **facility reuse upper limit is a PENDING numerical decision (phase 5)** — this round gates reuse on the existing silver resource ("pay each use") so it introduces NO new resource/economy; the open question (once-per-visit? once-per-period? pure-silver-limit?) is recorded as undecided so a later round does not read the silver gate as settled balance. |

`design/20_content.md` §8.1 table and §8.3 gap notes are the SAME fact source — they must be consistent (the brief's "两份文档是同一事实源,必须一致").

---

## 回滚与不可逆操作 (Rollback / irreversibility)

The design involves no destructive migrations. The "irreversible" edits are frozen-scenario re-baselines, handled by the backup-first protocol:

1. **`tests/fixtures/playtest_assert_superset.json` re-baseline:** snapshot the current fixture → bake the post-edit shaolin gap expression → verify `test_edited_scenarios_assert_superset` still passes against the edited `map_node_event_shaolin.yaml` → only then commit. If the new expression is wrong, restore the snapshot (the old expression is still in git). The fixture is the frozen baseline; updating it FIRST means the smoke test never sees a mismatch.
2. **`map_node_event_shaolin.yaml` gap assert re-derivation:** the superset fixture guards "只许加,不许减" — the re-baseline exception is baked into the fixture BEFORE the yaml is edited, so the machine proof holds through the edit. The re-derivation only TIGHTENS (facility drops from the gap list — an honesty observable that MOVES when a gap is filled, which is its job).
3. **`map_data.gd` NODES flip:** a data-row edit to a const table. No migration — `declared_gap_types()` re-derives automatically. Rollback = revert the 2 rows (git). The unit tests (`test_map_data.gd`) pin the exact post-edit counts.
4. **No file deletions, no batch rewrites.** Every edit is additive (append-only contract: surface whitelist grows, scenario_order grows, TESTS registry grows, EN dict grows) or a surgical re-derivation of a single existing assert line.

---

## 扩展性考虑 (Extensibility)

- **Adding a 3rd facility** (e.g. a kunlun facility after the ending-routing guarantee is lifted): add a row to `FacilityData.TABLE`, flip the node's facility slot in `map_data.gd` NODES, and `declared_gap_types()` auto-drops `facility` for that node. No code change in `map.gd` (the FACILITY phase is generic — it reads `active_facility_id(current_node_id)` and resolves via `FacilityData.def`). The cost-gate, effect application, and surface sync are all data-driven.
- **Facility with multiple options:** the current design deliberately has NO option_a/option_b (that is the event shape; a facility with a binary choice would be "a second event"). If a future facility genuinely needs a choice, it belongs in a design decision first, not in a data row. The `FacilityDef.effects` array can carry multiple gain effects (e.g. silver −8 + bone +2 + agility +1) without schema change.
- **Non-silver cost gates:** the cost-gate is currently silver-only. If a future facility needs a qi or practice ceiling as the limiter, the gate check in `_use_facility()` is the single place to extend. The effect domain stays the closed {silver, attr, practice, none} set.
- **The permanent negative assertion is the load-bearing extensibility guard:** it ensures that no future round can wire the facility into the arrival dispatch without going red. That is what keeps "facility = entered by choice" true as the codebase grows — not the data schema, not a comment, an observation point.

---

## 设计自检 (Pre-submission checklist)

- [x] Covers all MVP goals: facility defined + distinguished from event; ≥2 nodes active; declared_gap_types honest; reusable + observable; no new economy; data-table copy; new playtest scenario with red-then-green; roadmap entries 2+4 updated; changelog + decisions.
- [x] Component responsibilities single and clear: FacilityData (data), MapData (resolution), MapScreen (phase), EventLogic (unchanged effect path). No unnecessary coupling — the facility touches EventLogic/PlayerProfile through the same interface events use.
- [x] Prioritizes SOTA-recommended tools: EventData.TABLE pattern, EventLogic pure-static path, map.gd phase model, active_*_id accessor, append-only playtest contract, anti-deletion pin. Nothing reinvented.
- [x] Interfaces clear enough for PM to decompose: each component has a named file, named functions, named surface vars, and named keyboard actions.
- [x] No over-design: no new economy, no new abstract layer, no option_a/option_b for facilities, no new click target, no camera/coordinate changes.
- [x] `linter_manifest.json` produced, matching the file types in this project (`.gd` excluded — handled by the gdscript_check gate per addon guidance).
