# 技术架构设计 — Map Node Events (jinyong-map-events round)

## 1. Overview

Make the 6-node jianghu map actually trigger content on entry. This round implements exactly
one content type end-to-end — **event** — by reusing the existing `scripts/data/event_data.gd`
pool (16 rows) and the existing event resolution logic from `scripts/segments/cultivation.gd`,
extracted into a shared pure-static module. Battle and sect-facility types get **declaration
slots only**, recorded as honest gaps. Shaolin — the dead-end branch off Luoyang — gets the one
fully interactive node-entry event this round, via a **deterministic binding to an existing
pool row** (zero new prose).

Non-negotiables inherited from the brief and SOTA:

1. **`spine_to_ending` stays green with its UNMODIFIABLE timeline.** That scenario walks
   无名谷→洛阳→武当→襄阳→昆仑 with exactly 4 `(move_right, ui_accept)` pairs at
   f420–f490 and asserts `ENDING` at f520. Any *blocking interactive* event on a MAINLINE node
   consumes presses the budget does not have (verified by hand-simulation below). Therefore
   the interactive node event lives on **Shaolin (off-spine)**; mainline nodes *declare* event
   slots that stay inert this round and are recorded as gaps.
2. **Docs first.** The `design/` archive edits are the first implementation tasks, before any
   code (§2).
3. **No new event text.** The Shaolin binding points at an existing `EventData.TABLE` row.
4. **Append-only playtest contract.** New scenario file + surface/action whitelist appends +
   smoke-test contract pin; zero edits to any of the 54 existing scenario yamls (last-known
   count from the knowledge base, not an on-disk gate product — no gate counts may be
   fabricated).
5. **One lever.** No numeric tuning, no combat rule change, no month-loop change, no new art.

## 2. Design changes (declared for the `design/` archive — the docs-first round)

This round is explicitly data-first per the brief, so the archive edits are scheduled BEFORE
code (§9 task ordering). They are declared here; the `5_design` step reconciles them after
final acceptance.

| File | Change | Rationale |
|---|---|---|
| `design/40_progression.md` | §5 (第 6 段 · 大地图): after the existing node-movement paragraph, add the **per-node entry-content declaration table** — every node declares `event` / `battle` / `facility` slots; only Shaolin's event slot is `active` this round; battle/facility and mainline event slots are `declared` (declaration-only, unimplemented); the spine-protection reason for inert mainline slots is stated verbatim (f420–f520 fixed budget, unmodifiable yaml). | The map paragraph currently says "节点上触发战斗、事件或门派设施" — the second half is unimplemented. The declaration schema makes it data-first. |
| `design/20_content.md` | New dated section **§8 大地图节点进入内容 (2026-08-28, jinyong-map-events 轮)**: the 6-node entry-content table (mirroring `map_data.gd`), the Shaolin binding (`night_rain`, from the existing pool, with the "closest-scene, zero-new-prose" rationale), and the gap notes in the §5 style (see §8.5 below). | The single authoritative content record; gap notes follow the existing §5 discipline ("不许假装实现，也不许悄悄不提"). |
| `design/90_decisions.md` | Dated decision note (appended after the existing 2026-08-27 note, same style): **event resolution logic relocation** — `_draw_event` / `_apply_event_option`'s effect loop / `_add_practice` are extracted from `cultivation.gd` into a shared pure-static module `scripts/data/event_logic.gd`; cultivation delegates byte-identically (same RNG op order, same effect application). Rationale: the map segment must reuse the resolution path rather than fork a parallel system; the only way to share instance-coupled code without regressing cultivation's pinned tests is to move the *pure* core once, with the doc note written first. | Required by the brief: "如果解算逻辑需要挪位置或共享，先改设计档案说明理由，再动代码". |
| `design/99_changelog.md` | Append one round row (append-only; no existing row edited). | Round archive discipline. |

### 2.1 Gap notes to record in `20_content.md` §8 (§5 style — declared-but-unimplemented)

1. **battle** slots: declared on the relevant nodes, unimplemented this round (no battle
   encounter wiring on map entry; `battle_id` stays `""`).
2. **facility** (门派设施) slots: declared, unimplemented (no sect-facility content type).
3. **mainline event slots** (无名谷/洛阳/武当/襄阳/昆仑): declared, deferred — an interactive
   event there would consume input budget the unmodifiable `spine_to_ending` timeline does not
   have. NOT "postponed silently": the spine-protection reason is written in the gap note.
4. **No Shaolin-exclusive authored event text this round**: the "reason to visit" is a
   deterministic binding to the existing `night_rain` pool row. A future *authored* exclusive
   row (e.g. a Shaolin-specific scene) is a content gap — it must be authored **inside
   `event_data.gd`'s TABLE only**, never inline in `map_data.gd` / `map.gd`, and must be
   recorded as a gap first.
5. **Node-event re-fire policy**: the Shaolin event fires on **every arrival by travel**; there
   is no once-per-profile flag this round. Extending `PlayerProfile.flags` sanitization for a
   new persisted key is out of scope; the policy (re-playable content site) is recorded rather
   than silently missing.
6. **江湖阅历 trait's 打听 action** (reveal adjacent node content, `40_progression.md` §2.2):
   declared in the archive, not implemented; out of scope this round — recorded so it is not
   read as forgotten.

### 2.2 Why the Shaolin binding row is `night_rain` (破庙夜雨)

Of the 16 pool rows, `night_rain` is the only one whose scene is **a monk in a temple** ("老僧
独坐，就着灯火补屋檐") — the closest existing fit for visiting 少林 (a monastery): you arrive,
help mend the leaky roof (silver −6, 根骨 +1) or practice sword under the eaves (practice +2).
Zero new prose. "Exclusive" is mechanism-exclusivity: **only Shaolin's node entry fires this
row deterministically**; the row itself stays in the shared pool (cultivation's 游历 bag may
still draw it — the two channels are independent, see §4.5). If the team later prefers a
different row, only the `event_id` value in `map_data.gd` changes; the mechanism is unaffected.

## 3. Architecture diagram (text)

```
scripts/data/map_data.gd  (EXTEND, additive)
  NODES rows gain "entry_content": {event|battle|facility: {status, id}}
  new statics: entry_content(id), active_event_id(id), declared_gap_types(id)
        |
        v
scripts/segments/map.gd  (EXTEND, additive EVENT phase)
  _travel(): end-node routing FIRST (unchanged) -> _maybe_start_entry_event()
  phase "TRAVEL" (existing behavior, byte-identical when no active slot)
  phase "EVENT" : move_* cycles _event_focus (0/1); ui_accept resolves
        |                                |
        | reuses (no fork)               v
        |                    scripts/data/event_logic.gd  (NEW, pure statics)
        |                      draw_unseen_id(profile, rng)     <- bag draw
        |                      apply_option_effects(profile, opt) <- 5 effect types
        |                      add_practice(profile, amount)   <- first-unmastered
        |                                ^
        | delegates byte-identically     |
        +---------------- scripts/segments/cultivation.gd  (EDIT, delegation only)
                           _draw_event / _apply_event_option / _add_practice
                           keep event_id / phase / _sync_surface management

scripts/data/event_data.gd  (UNTOUCHED — the mandated single text pool)
SaveManager.profile  (map_node, silver, add_attr, inventory, flags["events_seen"] — untouched schema)

Pins:
  playtest/map_node_event_shaolin.yaml  (NEW scenario, 54 -> 55, append-only)
  playtest/_common.yaml                 (MapScreen surface append + scenario_order tail append)
  tests/test_map_node_event.gd          (NEW unit pin, registered in unit_test_runner.gd TESTS)
  tests/test_playtest_contract_smoke.py (additive contract pin + ROUND_SCENARIOS tail sync)
```

## 4. Component list

### 4.1 `scripts/data/map_data.gd` — entry-content declarations (data-first)

Additive only; `node_def()` already deep-copies, so extra keys are invisible to existing
callers and `tests/test_map_data.gd` stays green.

Each NODES row gains `entry_content`. Statuses: `"active"` (implemented + live) or
`"declared"` (declaration slot only — unimplemented this round):

```gdscript
{"id": "wuming_valley", "display_name": "无名谷", "is_end": false,
    "entry_content": {
        "event":    {"status": "declared", "event_id": ""},
        "battle":   {"status": "declared", "battle_id": ""},
        "facility": {"status": "declared", "facility_id": ""},
    }},
# luoyang / wudang / xiangyang / kunlun: same "declared" shape (mainline, spine-protected)
{"id": "shaolin", "display_name": "少林", "is_end": false,
    "entry_content": {
        "event":    {"status": "active", "event_id": "night_rain"},
        "battle":   {"status": "declared", "battle_id": ""},
        "facility": {"status": "declared", "facility_id": ""},
    }},
```

New static accessors (pure data layer, deep-copied like `node_def`):

- `entry_content(id) -> Dictionary` — the node's `entry_content` ({} if unknown).
- `active_event_id(id) -> String` — the `event_id` iff `status == "active"` AND
  `EventData.def(event_id) != null`; else `""`. (A typo'd binding reads as inert — fail-safe,
  never a crash; the unit test pins the binding resolves.)
- `declared_gap_types(id) -> Array[String]` — types whose slot `status == "declared"`
  (e.g. `["event", "battle", "facility"]` on luoyang; `["battle", "facility"]` on shaolin).
  This is the **honesty observable**: the declared-but-unimplemented gap is assertable, not
  just documented.

### 4.2 `scripts/data/event_logic.gd` — NEW shared pure-static module

`class_name EventLogic`. No scene, no autoload, no signal — pure statics over
`(profile, rng)`; zero new RNG ops, zero new effect types. One resolution path for both
cultivation and the map segment.

- `static func draw_unseen_id(profile: PlayerProfile, rng: RandomNumberGenerator) -> String`
  — the no-repeat bag draw, byte-for-byte the current `cultivation._draw_event()` body:
  unseen ids from `EventData.all()`, pool reset when exhausted, exactly **one**
  `rng.randi_range(0, pool.size() - 1)` call. (RNG op order unchanged → the seeded stream is
  untouched → `event_travel_effects` and all cultivation draws stay deterministic.)
- `static func apply_option_effects(profile: PlayerProfile, opt: EventData.EventOption) -> void`
  — the 5-type effect loop from `cultivation._apply_event_option` (silver clamp ≥ 0,
  `add_attr`, inventory append-if-absent, `add_practice`), verbatim.
- `static func add_practice(profile: PlayerProfile, amount: int) -> void`
  — `cultivation._add_practice` verbatim, including the 杀破狼 `TraitEffects.pojun_practice`
  hook and first-unmastered targeting; `return` when no unmastered art exists.

**Naming-independence note (reviewer #4):** `EventLogic` holds no instance state and no
scene references; neither segment keeps a live instance of the other. Cultivation and map
each *call* statics — no coupling either direction beyond the shared module, so cultivation's
pinned cases (last-known: 48 effects-land cases in `tests/test_cultivation.gd`, plus
`event_travel_effects`) and `save_load_roundtrip` cannot regress through instance
interaction.

### 4.3 `scripts/segments/cultivation.gd` — delegation only (byte-identical behavior)

Three surgical edits, nothing else changes:

- `_draw_event() -> String`: body becomes `return EventLogic.draw_unseen_id(SaveManager.profile, SaveManager.rng)`.
- `_apply_event_option(opt_index)`: keeps `event_id` lookup, option pick, seen-mark,
  `event_id = ""`, `_sync_surface()` — only the `for eff in opt.effects: match ...` loop is
  replaced by `EventLogic.apply_option_effects(SaveManager.profile, opt)`.
- `_add_practice(amount)`: body becomes `EventLogic.add_practice(SaveManager.profile, amount)`.

Phase machine, `_sync_surface`, EVENT render, `_fast_forward`, `_debug_step_month` are
untouched. All existing cultivation unit tests and playtest scenarios must pass unchanged.

### 4.4 `scripts/segments/map.gd` — additive EVENT phase

New surface vars (see §5) + a two-phase input gate. **Inert by default**: a node whose event
slot is not `active` produces byte-identical behavior to today.

- `phase: String = "TRAVEL"` — existing focus/travel flow; `"EVENT"` while a node event is up.
- `_travel()` (order matters):
  1. existing adjacency checks + `current_node_id` assignment + `map_node` write + `autosave()`;
  2. **end-node routing first** (unchanged `is_end_node` → `ended = true` → ENDING);
  3. then `_maybe_start_entry_event()`: `var eid := MapData.active_event_id(current_node_id)`;
     if `eid != ""` → `phase = "EVENT"`, `event_id = eid`, `_event_focus = 0`, `_render()`.
     (Invariant recorded in design: a future node that is both end and active routes to ENDING
     first — node content never blocks the ending.)
- `_unhandled_input`: `if ended: return` (unchanged); then
  `if phase == "EVENT":` route `move_up/move_left` → `_event_focus = 0`,
  `move_down/move_right` → `_event_focus = 1` (cultivation's EVENT-phase convention),
  `ui_accept` → `_resolve_node_event()`; **all** consume `set_input_as_handled()` and return.
  Otherwise the existing travel/focus branches, unchanged.
- `_resolve_node_event()`:
  `var def := EventData.def(event_id)`; pick option by `_event_focus`;
  `last_effect_types` = the option's effect `type`s in order;
  `EventLogic.apply_option_effects(SaveManager.profile, opt)`;
  `events_resolved_count += 1`;
  `event_id = ""`, `phase = "TRAVEL"`, `SaveManager.autosave()`, `_sync_surface()`, `_render()`.
  **No read or write of `flags["events_seen"]`** — the node channel is a deterministic binding,
  independent of the cultivation bag (reviewer #5: entering Shaolin always shows its event,
  regardless of what 游历 already drew; no order-dependence, no flakiness).
- `_render()`: in EVENT phase, append the event block (title / text / both option labels with
  `▶` marker / `"\n\n上下选择，回车定夺"`) and **replace the travel hint line** in the same
  transition — the map must not keep promising "回车启程" while a modal event is up (the
  repo's "no stale promise" discipline). TRAVEL-phase render text is unchanged.
- `_ready()` is **untouched**: entry content fires only on arrival-by-travel, never on boot or
  load — a save→load roundtrip at Shaolin does not re-trigger an event, and `save_load_roundtrip`
  stays green.

### 4.5 Two independent event channels (stated explicitly)

- **Cultivation 游历 channel**: RNG bag draw, no-repeat via `flags["events_seen"]`, marks seen.
- **Map node channel**: deterministic `node → event_id` binding, reads/writes neither the bag
  nor the seed stream, fires on every arrival by travel.

They share one pool (`EventData`) and one effect-application path (`EventLogic`), nothing else.
Reusing the same row on both channels is accepted and recorded (§2.1 gap #4).

## 5. Observable contract (exact names — the playtest surface whitelist)

`playtest/_common.yaml` `surface: MapScreen:` block, **append-only** (existing five entries
untouched):

```
  MapScreen:
  - current_node_id        # existing
  - focus_id               # existing
  - ended                  # existing
  - visible                # existing
  - size                   # existing
  - phase                  # NEW: "TRAVEL" | "EVENT"
  - event_id               # NEW: "" when no node event is up
  - event_focus            # NEW: 0 | 1 (which option the ▶ marks)
  - entry_declared_gap_types  # NEW: Array[String] of declared-unimplemented slot types at the current node
  - silver                 # NEW: profile.silver mirror
  - attr_bone              # NEW: profile mirrors (differential asserts)
  - attr_inner
  - attr_agility
  - attr_wisdom
  - attr_fortune
  - last_effect_types      # NEW: Array[String] effect types of the last resolved option, in order
  - events_resolved_count  # NEW: session count of resolved node events (ladder 0 -> 1)
```

`_sync_surface()` on map.gd mirrors the profile fields (the cultivation pattern). These are
the hard contract for the implementer: node/variable/action names must match verbatim.

## 6. Playtest scenario skeleton (architect-owned; PM fills final thresholds)

New file `playtest/map_node_event_shaolin.yaml` (54 → 55, append-only; every existing yaml
untouched). `name:` equals the basename; every `at:` a single integer; every assert carries a
comparison operator; **numeric asserts are differential/relative — no absolute numeric
literals** (the exact `silver −6 / attr +1` math is pinned in the GDScript unit test where
before/after variables exist; the playtest pins appearance, selectability, and
application-by-differential).

**Frame budget (reviewer #1 — enumerated so it is never under-allocated):** the boot to MAP
reuses the spine's proven prefix; the Shaolin leg needs 3 more key-frames + assert frames:

| Frame | Action | Effect |
|---|---|---|
| 3–15 | `ui_accept` ×7 | menu → tutorial (spine prefix, proven) |
| 20 | `debug_win_tutorial` | tutorial WON |
| 50–90 | `ui_accept` ×3 | transition → creation |
| 120–190 | `move_right` ×5, `ui_accept`, `move_right`, `ui_accept` | creation → sect select → CULTIVATION |
| 280 | `debug_fast_forward` | 36 months → MAP |
| 400 | assert | `current_state == "MAP"` (spine prefix end) |
| 420 | `move_right` | focus → 洛阳 (mainline auto-select) |
| 430 | `ui_accept` | travel → 洛阳; **no event** (declared slot) |
| 440 | `move_right` | focus → 武当 (auto-select) |
| 450 | `move_right` | focus cycles → **少林** (3rd neighbor of 洛阳) |
| 460 | `ui_accept` | travel → 少林; EVENT phase opens |
| 470 | assert | `phase == "EVENT"`, `event_id == "night_rain"` (deterministic binding pin — this is a *binding*, not a drawn id), `current_node_id == "shaolin"` |
| 480 | `move_right` | `event_focus` 0 → 1 (option B selectable) |
| 490 | assert | `event_focus == 1`, `phase == "EVENT"` (focus moved, event still up — proves both options selectable) |
| 500 | `move_left` | `event_focus` back to 0 (option A selectable) |
| 510 | `ui_accept` | resolve option A: 帮工换宿 (silver −6, 根骨 +1) |
| 530 | assert | `phase == "TRAVEL"`, `event_id == ""`, `last_effect_types == ["silver", "attr"]`, `attr_bone: changed`, `events_resolved_count == 1`, `entry_declared_gap_types.has("battle") and entry_declared_gap_types.has("facility")` (the honesty pin: gaps declared, visible, assertable) |
| 560 | `move_right` | focus → 洛阳 (少林's only neighbor) |
| 570 | `ui_accept` | travel back → 洛阳; no event, no stall (declared slot inert) |
| 600 | assert | `current_node_id == "luoyang"`, `phase == "TRAVEL"`, `event_id == ""` |

Total ≤ ~f600, far under the 3000 cap / ≤ 2999 last assert. **Silver note for the PM:** after
`debug_fast_forward` the profile's silver is nonzero but not guaranteed ≥ 6, so the silver leg
should be asserted via `last_effect_types` (structural: the silver effect was applied) and the
guaranteed differential is `attr_bone: changed` (floor 10, +1 always lands). Do NOT assert
`silver: changed` unless a pre-check confirms silver ≥ 6 — the ≥ 0 clamp can make it a silent
no-op on the mainline-boot profile. A direct `res://scenes/segments/map.tscn` boot is NOT
usable for this scenario: the default profile has silver 0 and empty gongfa, so option A's
silver clamps and option B's practice no-ops — nothing observable.

**Two-place sync (hard):** `_common.yaml` `scenario_order` tail gains `- map_node_event_shaolin`
after `- qi_cost_blocks_cast_no_energy`; `tests/test_playtest_contract_smoke.py`
`ROUND_SCENARIOS` tail gains `"map_node_event_shaolin"` in the same position; a new
`test_map_node_event_surface_contract()` pins (a) the new MapScreen vars whitelisted, (b) the
scenario file exists with `name == basename`, (c) single-integer `at:` values, (d) comparison
operator (or `changed`/`unchanged`) on every 4-space dotted assert line — the same shape as
`test_qi_cost_surface_contract()`.

## 7. GDScript unit pin

`tests/test_map_node_event.gd` (NEW; static `run() -> bool` contract; registered by appending
to `TESTS` in `tests/unit_test_runner.gd`; expected compile count 75 → 77, last-known baseline
75/75 — label as expectation, not a measurement):

1. **MapData schema**: every node declares all three slots; statuses ∈ {active, declared};
   exactly one active event slot (shaolin); `active_event_id("shaolin")` resolves in
   `EventData.def`; `declared_gap_types` returns the right arrays; unknown node → {} / "" / [].
2. **EventLogic parity** (controlled profiles, relative asserts):
   `apply_option_effects` lands each of the 5 effect types exactly as the pool row states
   (silver == before + value with ≥ 0 clamp; attr == before + value; item appended once;
   practice adds to the first unmastered art; none → no change).
   `add_practice` with empty gongfa → no-op, no error.
   `draw_unseen_id` 15-of-16 exclusion → forced missing id; full bag → reset + non-empty draw
   (mirrors the existing cultivation criteria, now against the shared module).
3. **map.gd EVENT phase** (instantiate `scenes/segments/map.tscn` like `test_cultivation.gd`
   instantiates the cultivation scene): travel 洛阳→少林 opens EVENT with `event_id ==
   "night_rain"`; `_event_focus` cycles 0/1; resolve applies option effects to the profile
   (attr delta == pool value), returns `phase == "TRAVEL"`, `event_id == ""`,
   `events_resolved_count` 0 → 1; flags["events_seen"] untouched by the map channel; a
   mainline-node travel (wuming→luoyang) leaves phase TRAVEL and event_id "" (inert proof).

## 8. Edge cases (from step1_sota / review) → how this design answers each

| # | Edge case | Answer |
|---|---|---|
| 1 | spine budget: any blocking mainline event breaks f520 | Mainline event slots `declared` (inert). Hand-simulation: even the most favorable consumption (event eats exactly the next `(move_right, ui_accept)` pair) leaves the run at 武当 at f520 — 2 pairs short. Interactive node content lives only on Shaolin; 昆仑 routes to ENDING before/independently of entry content. |
| 2 | "exclusive" must not mean "invented" | First-choice path: deterministic binding to an existing row (`night_rain`). A new authored row is a LAST RESORT, gated on a `20_content.md` gap note recorded first and authored only inside `event_data.gd` — never inline. Not needed this round. |
| 3 | RNG-drawn ids unassertable | The node event is a deterministic binding, so `event_id == "night_rain"` is a legitimate pin (a data binding, not a draw). No new RNG ops exist on the map leg at all. |
| 4 | sharing must not regress cultivation | Pure statics only, no instance coupling either direction (§4.2 note); cultivation delegates with identical RNG op order and effect application; all existing cultivation pins must stay green unchanged. |
| 5 | bag/channel independence | The map channel never reads/writes `events_seen` (§4.5) — entering Shaolin always shows its event regardless of prior 游历 draws; no order-dependence. |
| 6 | inert regression-neutrality | A non-active node produces byte-identical `_travel` / focus / render; end-node routing unchanged and ordered first; `_ready` untouched. |
| 7 | declared-unimplemented honesty | `declared_gap_types` observable + 20_content.md §8 gap notes + the playtest honesty pin in the scenario (f530). No faking, no silence. |
| 8 | docs-first ordering | §2 schedules the four design-doc edits as tasks 1–2, before any code; compile-count figures are labeled last-known/expected, never fabricated. |
| 9 | save/load integrity | No new persisted keys; entry fires only on travel, never on boot/load; autosave after resolution; `save_load_roundtrip` untouched and must stay green. |

## 9. Safety, rollback, task decomposition (for PM)

No irreversible operations: all edits are additive (new keys in deep-copied data rows, new
statics, one new module, one new scenario, whitelist appends) or surgical delegation swaps in
`cultivation.gd`. The only behavior-affecting edit is `cultivation.gd`'s three delegations —
rollback = restore the three original bodies (verbatim in §4.3); everything else deletes
cleanly. No existing yaml, no gate product, no art asset is touched.

Suggested task order (docs-first is a hard constraint, not a preference):

1. `design/40_progression.md` §5 + `design/20_content.md` §8 (gap notes, binding, table) — **before code**.
2. `design/90_decisions.md` relocation note + `design/99_changelog.md` round row — **before code**.
3. `scripts/data/map_data.gd` entry_content + accessors (+ extend `tests/test_map_data.gd`? No — additive keys are invisible to it; pin in the new test file instead).
4. `scripts/data/event_logic.gd` (new) + `cultivation.gd` delegation swap.
5. `scripts/segments/map.gd` EVENT phase + `_sync_surface` observables.
6. `tests/test_map_node_event.gd` + `unit_test_runner.gd` TESTS append.
7. `playtest/_common.yaml` surface append + scenario_order tail append; `playtest/map_node_event_shaolin.yaml`.
8. `tests/test_playtest_contract_smoke.py` ROUND_SCENARIOS tail + new contract pin.
9. Regression pass: spine_to_ending, save_load_roundtrip, event_travel_effects, all cultivation scenarios green; new scenario green. No gate counts claimed before they land.

## 10. Technology stack

Godot 4.4 built-ins only (GDScript statics, Control/Label, `_unhandled_input`), reusing the
repo's existing modules per SOTA: `EventData` pool, `SaveManager.profile` effect API, the
playtest harness (`_common.yaml` sibling scan + `tests/test_playtest_contract_smoke.py`),
`unit_test_runner.gd` TESTS registry. Zero new third-party dependencies, zero new art/audio.
