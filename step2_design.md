# Technical Architecture Design — Main Story Node Events (jinyong-nodes round 2)

## 1. Overview

This round wires content events into the five main story nodes (无名谷 / 洛阳 / 武当 /
襄阳 / 昆仑) of the existing Godot 4 turn-based cultivation game, keeps the ending
reachable, unifies the map-page bottom hint with the panel text, and closes the
persistent-text audit in the delivery notes. The mechanism already exists — the
previous `jinyong-map-events` round built the declaration table (`map_data.gd`),
the EVENT phase (`map.gd`), the shared pure effect core (`event_logic.gd`), and the
playtest observables. **This round is a data edit (4 dictionary literals), one
`.tscn` string, two authorized yaml re-budgets, two appended scenarios, and the
docs-first archive that must precede them.** Zero new mechanics, zero new prose,
zero new art.

**Constraint status (as amended by the round owner):** the "no existing yaml may be
modified" exception covers exactly **two** files — `playtest/spine_to_ending.yaml`
and `playtest/map_node_event_shaolin.yaml` — under identical conditions: write the
rationale in `design/` first (task C0, which BLOCKS C3/C4), assertions only added
or strengthened (never removed or relaxed), and the change is the frame/input
budget, not what each scenario proves. The other **53** existing scenario yamls
stay untouched. Grep-verified blast radius: only these two files contain
`current_state == "MAP"` / walk the map, so **no third scenario can redden via a
live mainline event**.

MVP coverage:
- Five main nodes carry content → 4 live deterministic bindings + 昆仑 argued
  non-trigger (§2.1, §4.1).
- Ending still reachable → routing-first order + exact re-budgeted spine
  timeline (§4.3), all existing ENDING asserts survive.
- Hint unification → one `.tscn` string, byte-identical to the panel string
  (§4.2), assertable with the existing whitelist.
- Persistent-text audit → recorded in `final/delivery_notes.md` (§4.8).
- Only `spine_to_ending.yaml` + `map_node_event_shaolin.yaml` edited; new
  scenarios appended only; numeric asserts relative everywhere.

## 2. Key design decisions

### D1 — Binding table: 4 deterministic live bindings, 昆仑 stays `declared`

| Node id | Node | event slot | verbatim pool row | option A effects (from `event_data.gd`) | Why |
|---|---|---|---|---|---|
| `luoyang` | 洛阳 | `active` / `merchant` | 行商路过 | silver −20 + item `eq_sword_3` | The imperial trade hub; a cart of blades passing through the city is the natural pool fit. Decisive technical reason: **option A has no `attr` effect**, so it cannot muddy the shaolin scenario's `attr_bone: changed` / `last_effect_types` pins. |
| `wudang` | 武当 | `active` / `quanzhen_scripture` | 全真抄经 | attr `wisdom` +2 | A Taoist mountain sect; the 老道 at 全真宫 row is the strongest pool fit. The spine's `tier >= 1 and tier <= 3` range assert absorbs the +2 wisdom. |
| `xiangyang` | 襄阳 | `active` / `dragon_scrap` | 降龙残谱 | practice +4 | The 神雕侠侣 climax city; the palm-scrapped manual on a book stall. Practice-only = **zero stat coupling** on the spine walk. |
| `wuming_valley` | 无名谷 | `active` / `tomb_bed` | 古墓寒玉 | attr `inner` +2 | A hidden valley concealing an ancient tomb — strongest pool fit. It is reachable only by return travel (`ADJACENCY["luoyang"]` contains `wuming_valley`), so `active` is honest: it fires on **return** travel, never at boot. |
| `kunlun` | 昆仑 | **stays `declared` / `""`** | — | — | Terminal node: `_travel()` routes an end node to ENDING (and sets `ended = true`) **before** `_maybe_start_entry_event()` — any 昆仑 binding is structurally dead. The ending IS the terminal's content. |

Result: **4 of 5 main nodes carry live content**; 昆仑 is an explicit, argued
non-trigger (the brief's sanctioned option "either no trigger, or trigger-then-
reach-ending" — we choose no trigger, the strictly safer variant). The existing
machine pin `active_event_id("kunlun") == ""` in `tests/test_map_node_event.gd`
stays green and stays.

**Rejected alternatives:**
- *Pool draw per node (`EventLogic.draw_unseen_id`)* — rejected: it reads/writes
  `profile.flags["events_seen"]`, entangling two channels that
  `design/20_content.md` §8.2 declares independent ("两条通道相互独立,互不读写
  `flags['events_seen']`"), and it would make both re-budgeted timelines
  RNG-dependent. All mainline bindings are literal `event_id` rows.
- *Bind 昆仑 and reorder `_travel()` so the event runs first* — rejected: breaks
  the terminal-node guarantee, breaks the existing `kunlun` inert pin, and adds a
  spine press for zero content gain (a dead binding dressed as a trigger is the
  dishonest-`active` failure mode).
- *Binding any row whose option A is `silver + attr` shaped at 洛阳* (e.g.
  `snake_bile`, `dali_market`) — rejected: 洛阳's resolution happens BEFORE
  少林's in the shaolin scenario; an attr effect there would either fake or mask
  the `attr_bone: changed` differential.

### D2 — The one authorized literal re-base: `events_resolved_count` 1 → 2 (shaolin yaml)

Once 洛阳 resolves an event on the outbound leg, the session counter is 2 by the
time 少林's `night_rain` resolves. The existing assert
`MapScreen.events_resolved_count: events_resolved_count == 1` must re-base to
`== 2`. This is defensible only because it stays an **exact equality** (never
`>=`) — the ladder is pinned tighter, not looser. To make the change purely
additive in spirit, a **NEW** assert block is inserted right after the 洛阳
outbound resolution pinning `events_resolved_count == 1`, so the pair
`{==1 at 洛阳, ==2 at 少林}` pins the **+1-per-resolution ladder** more strictly
than the original single `== 1`. The re-base is written into `design/` (task C0)
BEFORE the yaml moves, and is encoded as the single documented exception in the
machine superset pin (§4.6).

### D3 — Spine re-budget is arithmetic, not a gamble

With 洛阳 + 武当 + 襄阳 active and 昆仑 inert, the map leg costs **exactly one
extra `ui_accept` per event stop** (default `event_focus == 0` resolves option A
without any focus press) → 3 inserted presses, 0 on the 昆仑 leg. All existing
`move_right`/`ui_accept` travel pairs keep working because `_travel()` leaves
`focus_id == current_node_id` on arrival and `_cycle_focus(1)` then auto-picks
the `MAINLINE` successor. Exact new timeline in §4.3.

### D4 — Hint unification: byte-identical string, existing whitelist

`HintLabel.text` in `scenes/segments/map.tscn` is
`"左右选择 · 回车启程"` — a bottom-centred 400 px rect. The panel string in
`map.gd::_render()` is `"左右/上下选择相邻去处，回车启程"`. Fix: make the tscn
string **byte-identical to the panel string** (including the full-width `，`),
not a paraphrase. ~17 CJK glyphs ≈ 272 px < 400 px rect — width-safe, no geometry
change. `HintLabel: visible, text` is **already whitelisted** on the playtest
surface, so the "two places, one text" pin needs **no surface-whitelist change**.
Two stale text quotes must be updated in the same commit: the
`_apply_hint_visibility()` docstring in `map.gd` (L183–190) and the
`_apply_hint_visibility` comment block. No logic change — visibility toggling is
untouched (`phase != "EVENT"` is an allow-list-by-negation that already survives
any future phase).

### D5 — New scenarios direct-boot `map.tscn` (per-scenario `scene:` override)

Per `playtest/_common.yaml` L21–44, a scenario may boot
`res://scenes/segments/map.tscn` directly. This costs **zero frames of the two
re-budgeted timelines**, is immune to boot-flow shifts, and keeps the mainline
proof independent of the spine (whose shape must stay "the whole point",
per `_common.yaml`'s own advice). Two appended scenarios (§4.5). On direct boot,
`map.gd::_ready()` reads `SaveManager.profile.map_node` — empty/unknown falls
back to `start_node()` = `"wuming_valley"`, and the default profile lands there
either way, so the scenario starts at 无名谷 deterministically.

### D6 — Bag independence gets an explicit unit pin (reviewer suggestion #3)

`map.gd::_resolve_node_event()` already routes through
`EventLogic.apply_option_effects`, which never touches
`profile.flags["events_seen"]`. To keep future binders from regressing this, the
unit suite gains an explicit pin: resolve a mainline event (e.g. `merchant` at
`luoyang`) on a fresh profile and assert `flags.get("events_seen", [])` is
unchanged/empty. `apply_option_effects` performs **zero RNG calls** (the only RNG
in the module is `draw_unseen_id`, which node events never call), so the spine's
seeded RNG stream is untouched — that is why `event_travel_effects` (19/19) and
`save_load_roundtrip` (14/14) stay green by construction.

### D7 — Docs-first, machine-enforced "only add, never remove"

The ordering rule from the round owner — 先写理由,再动 yaml — is enforced as a
task dependency (C0 BLOCKS C3/C4) **and** as a machine pin: the smoke test gains
a superset check carrying the hard-coded **pre-edit** assertion lines of both
edited scenarios (with the single documented re-base substitution from D2),
asserting every pre-edit line still exists in the current file. This is the
machine proof of 只许加,不许减 — a whole-file rewrite that drops an assert
reddens pytest, not just a code review.

## 3. Architecture / data flow (text diagram)

```
scripts/data/map_data.gd  (NODES table — THE single lever)
    wuming_valley  event: declared -> active  / "tomb_bed"
    luoyang        event: declared -> active  / "merchant"
    wudang         event: declared -> active  / "quanzhen_scripture"
    xiangyang      event: declared -> active  / "dragon_scrap"
    kunlun         event: stays     declared  / ""        (terminal guarantee)
    shaolin        event: unchanged active   / "night_rain"
        |
        v  MapData.active_event_id(id)  (pure, typo-safe inert — unchanged API)
scripts/segments/map.gd  (UNCHANGED logic)
    _travel()  -> end-node routing FIRST (kunlun -> ENDING, ended = true)
              -> _maybe_start_entry_event()  (only on arrival by travel)
                   -> phase = "EVENT", event_id, event_focus = 0
    _unhandled_input() EVENT arm -> event_focus 0/1, ui_accept resolves
    _resolve_node_event() -> EventLogic.apply_option_effects (no RNG, no
                              flags["events_seen"]) -> phase = "TRAVEL"
        |
        v
scripts/data/event_logic.gd  (UNCHANGED, shared pure core)
scripts/data/event_data.gd   (UNCHANGED — the 16-row pool, only sanctioned text)
        |
        v
scenes/segments/map.tscn  HintLabel.text  -> unified panel string  (D4)
        |
        v
playtest/spine_to_ending.yaml          (authorized re-budget, §4.3)
playtest/map_node_event_shaolin.yaml   (authorized re-budget, §4.4)
playtest/map_node_event_mainline_east.yaml     (NEW, appended, §4.5)
playtest/map_node_event_mainline_return.yaml   (NEW, appended, §4.5)
playtest/_common.yaml                  (scenario_order append-only)
tests/test_playtest_contract_smoke.py  (two-place sync + superset pin)
tests/test_map_data.gd, tests/test_map_node_event.gd  (unit pins re-based —
                                              .gd files, not scenario yamls)
design/ + final/delivery_notes.md      (docs-first C0, BLOCKS the yaml edits)
```

## 4. Component list (all paths relative to repo root)

### C0 — `design/` docs-first archive (BLOCKS C3 and C4)

Write the rationale BEFORE any yaml moves. Exact targets:

1. `design/20_content.md` §8.1 — the six-node declaration table updated to the
   D1 binding table (row order = `NODES` order; the same-fact-source rule: §8.1
   and `design/40_progression.md` §5 must stay identical).
2. `design/20_content.md` §8.2 — add the binding rationale for the four nodes
   (content-fit + the attr-free-at-洛阳 technical reason), mirroring the §8.2
   style of the existing shaolin note. No new prose: every quoted title/text is
   verbatim from `event_data.gd`.
3. `design/20_content.md` §8.3 — clause 3 rewritten: the mainline event slots
   are **live for 4 of 5 nodes this round**; 昆仑 stays `declared` for the
   terminal-node guarantee (routing-first order), NOT for the old
   spine-budget reason. Record: (a) the two authorized yaml edits with
   before/after frame tables, (b) the D2 `events_resolved_count` re-base
   justification, (c) the D4 hint unification, (d) the repeat-visit re-fire
   now applying to 4 more nodes (re-visitable content sites; effects re-apply
   per arrival — the reason every new numeric assert is differential).
4. `design/40_progression.md` §5 (the L370–374 spine-protection paragraph) —
   rewritten: the protection now rests on the routing-first order + the
   re-budgeted timeline, not on mainline inertness.
5. `design/90_decisions.md` — round row: deterministic binding for all mainline
   nodes (no pool draw, bag independence); 昆仑 stays declared; the two-file
   yaml exception; the one literal re-base.
6. `design/99_changelog.md` — round row (55 -> 57 scenarios; one lever).
7. `final/delivery_notes.md` — round record including the persistent-text audit
   line (§4.8) and the honest gate-evidence stance (no PASS counts invented
   before the downstream gate runs).

### C1 — `scripts/data/map_data.gd` — the binding data edit (THE lever)

Edit exactly 4 dictionary literals in `NODES` (event slot
`{"status": "declared", "event_id": ""}` → `{"status": "active", "event_id":
"<id>"}` for wuming_valley/luoyang/wudang/xiangyang per D1; kunlun and shaolin
rows untouched). Rewrite the stale comment block at L13–17 ("mainline event
slots kept inert to protect the unmodifiable spine_to_ending timeline") to the
new rule: mainline events are live; the end node stays declared because
end-node routing runs before entry content. **No new code, no API change** —
`active_event_id()` / `declared_gap_types()` already implement the semantics.

### C2 — `scenes/segments/map.tscn` + `scripts/segments/map.gd` — hint unification

- `map.tscn` L49: `text = "左右选择 · 回车启程"` →
  `text = "左右/上下选择相邻去处，回车启程"` (byte-identical to `map.gd` L221).
- `map.gd` L183–190 (`_apply_hint_visibility` docstring) and the comment at the
  function head: update the quoted promise string to the unified text. No logic
  change; geometry untouched (400 px rect, centered, `mouse_filter = 2`).

### C3 — `playtest/spine_to_ending.yaml` — authorized re-budget (after C0)

**Everything at f400 and earlier is byte-unchanged** (boot, tutorial win,
transition, creation, sect, cultivation fast-forward, the MAP assert block at
f400). The map leg becomes:

| frame | action | effect |
|---|---|---|
| 420 | `move_right` | focus: 无名谷 → 洛阳 (MAINLINE successor) |
| 430 | `ui_accept` | arrive 洛阳; `merchant` EVENT opens (event_focus 0) |
| 440 | assert **NEW** | `MapScreen.phase: phase == "EVENT"`, `MapScreen.event_id: event_id == "merchant"`, `MapScreen.current_node_id: current_node_id == "luoyang"` |
| 450 | `ui_accept` | resolve option A (silver −20 + item; **no attr**) → TRAVEL |
| 460 | `move_right` | focus: 洛阳 → 武当 (MAINLINE successor) |
| 470 | `ui_accept` | arrive 武当; `quanzhen_scripture` EVENT opens |
| 480 | assert **NEW** | `phase == "EVENT"`, `event_id == "quanzhen_scripture"`, `current_node_id == "wudang"` |
| 490 | `ui_accept` | resolve option A (attr wisdom +2) → TRAVEL |
| 500 | `move_right` | focus: 武当 → 襄阳 |
| 510 | `ui_accept` | arrive 襄阳; `dragon_scrap` EVENT opens |
| 520 | assert **NEW** | `phase == "EVENT"`, `event_id == "dragon_scrap"`, `current_node_id == "xiangyang"`, `MapScreen.events_resolved_count: events_resolved_count == 2` |
| 530 | `ui_accept` | resolve option A (practice +4) → TRAVEL |
| 540 | `move_right` | focus: 襄阳 → 昆仑 |
| 550 | `ui_accept` | arrive 昆仑: end-node routing to ENDING runs **before** entry content — `ended = true`, no event fires |
| 580 | assert **EXISTING, moved f520→f580, lines verbatim** | `GameManager.current_state: current_state == "ENDING"`, `EndingScreen.tier: tier >= 1 and tier <= 3`, `EndingScreen.visible: true`, `EndingScreen.size: size.x > 0 and size.y > 0`, `Backdrop.visible: true`, `Backdrop.size: size.x > 0 and size.y > 0` |

The `description:` line is rewritten (its "4 moves to 昆仑" claim becomes false
otherwise): state that the map leg now resolves node events at 洛阳/武当/襄阳 on
the way and still reaches the tiered ending. Caps: last assert 580 ≤ 2900 (spine
cap) and ≤ 2999 (hard cap). The scenario remains the six-segment connectivity
proof; the three inserted blocks are the round's own claim ("every mainline stop
has content without blocking the ending"), kept thin per the pyramid rule.

**Silver-floor interaction (reviewer suggestion #2, resolved):** the spine's
silver at MAP is seed-dependent (cultivation cards may add economy silver;
silver starts at 0 in the default profile). `merchant` option A's −20 can only
clamp at 0 (`maxi(silver + value, 0)`); the spine asserts **no absolute silver
value anywhere**, and the item effect (`eq_sword_3` append-if-absent) cannot
stall a press. The floor is therefore provably inert for this timeline. The
+2 wisdom (武当) is absorbed by the `tier >= 1 and <= 3` range assert; the +4
practice (襄阳) masters a gongfa possibly, but the spine's map/ending leg asserts
no gongfa state. **No existing assert can redden from these effects.**

### C4 — `playtest/map_node_event_shaolin.yaml` — authorized re-budget (after C0)

Everything at f400 and earlier byte-unchanged. The leg becomes (the 洛阳 stops —
outbound AND return — each cost one inserted resolve press; the insertion lands
BEFORE each focus cycle, see edge case E1):

| frame | action | effect |
|---|---|---|
| 420 | `move_right` | focus: 无名谷 → 洛阳 |
| 430 | `ui_accept` | arrive 洛阳 (outbound); `merchant` EVENT opens |
| 440 | assert **NEW** | `phase == "EVENT"`, `event_id == "merchant"`, `current_node_id == "luoyang"`, `HintLabel.visible: visible == false` |
| 450 | `ui_accept` | resolve option A (silver+item, no attr) → TRAVEL |
| 460 | assert **NEW** | `phase == "TRAVEL"`, `event_id == ""`, `MapScreen.events_resolved_count: events_resolved_count == 1` (the NEW ladder pin from D2), `MapScreen.entry_declared_gap_types: 'entry_declared_gap_types.has("battle") and entry_declared_gap_types.has("facility")'` |
| 470 | `move_right` | focus: 洛阳 → 武当 (successor; NOT 少林 — the 3-edge hub) |
| 480 | `move_right` | focus: 武当 → 少林 (idx 2 of `[wuming_valley, wudang, shaolin]`) |
| 490 | `ui_accept` | arrive 少林; `night_rain` EVENT opens |
| 500 | assert **EXISTING, moved f470→f500** | `phase == "EVENT"`, `event_id == "night_rain"`, `current_node_id == "shaolin"`, `HintLabel.visible: visible == false` |
| 510 | `move_right` | event_focus → 1 |
| 520 | assert **EXISTING, moved f490→f520** | `MapScreen.event_focus: event_focus == 1`, `phase == "EVENT"` |
| 530 | `move_left` | event_focus → 0 |
| 540 | `ui_accept` | resolve `night_rain` option A (silver −6, attr bone +1) |
| 560 | assert **EXISTING, moved f530→f560, one literal re-based (D2)** | `phase == "TRAVEL"`, `event_id == ""`, `last_effect_types == ["silver", "attr"]`, `attr_bone: changed`, `events_resolved_count == 2` (was `== 1`), `entry_declared_gap_types.has("battle") and .has("facility")`, `HintLabel.visible: visible == true` |
| 590 | `move_right` | focus: 少林 → 洛阳 (`shaolin` not in MAINLINE → `nbrs[0]`) |
| 600 | `ui_accept` | arrive 洛阳 (return); `merchant` EVENT **re-fires** (repeat-visit policy) |
| 610 | assert **NEW** | `phase == "EVENT"`, `event_id == "merchant"`, `current_node_id == "luoyang"` |
| 620 | `ui_accept` | resolve option A again |
| 630 | assert **NEW** | `phase == "TRAVEL"`, `event_id == ""`, `events_resolved_count == 3` |
| 660 | assert **EXISTING, moved f600→f660** | `current_node_id == "luoyang"`, `phase == "TRAVEL"`, `event_id == ""` |

Why the existing neighbor asserts survive: 洛阳's option A is attr-free, so
`attr_bone: changed` keeps its exact differential meaning (the only bone change
on the leg is `night_rain`'s +1, exactly as before); `night_rain` is the last
resolution before f560, so `last_effect_types == ["silver", "attr"]` holds; the
return-leg re-fire at f600 is asserted AFTER f560, so it cannot disturb either
pin; the shaolin gap pin holds (shaolin's event slot is still the only active
slot there, battle/facility still declared — and 洛阳's own gaps, now
`[battle, facility]`, still contain both). The `description:` prose is
rewritten (it currently claims "the mainline nodes stay inert" — see edge case
E6). Caps: last assert 660 ≤ 2999. ✓

### C5 — Two NEW appended scenarios (skeletons; PM finalizes frames/thresholds within the given shapes)

**`playtest/map_node_event_mainline_east.yaml`** —
`scene: res://scenes/segments/map.tscn` (direct boot, D5). Walks the east
mainline and pins the 洛阳/武当/襄阳 bindings + the ladder:

| frame | action | effect |
|---|---|---|
| 30 | assert **NEW** | `phase == "TRAVEL"`, `event_id == ""`, `current_node_id == "wuming_valley"`, `focus_id == "wuming_valley"` |
| 40 | `move_right` | focus → 洛阳 |
| 50 | `ui_accept` | arrive 洛阳; `merchant` EVENT |
| 60 | assert | `phase == "EVENT"`, `event_id == "merchant"`, `current_node_id == "luoyang"` |
| 70 | `ui_accept` | resolve option A |
| 80 | assert | `phase == "TRAVEL"`, `event_id == ""`, `events_resolved_count == 1` |
| 90 | `move_right` | focus → 武当 |
| 100 | `ui_accept` | arrive 武当; `quanzhen_scripture` EVENT |
| 110 | assert | `phase == "EVENT"`, `event_id == "quanzhen_scripture"`, `current_node_id == "wudang"` |
| 120 | `ui_accept` | resolve option A (wisdom +2) |
| 130 | assert | `phase == "TRAVEL"`, `attr_wisdom: changed` (differential — the round's numeric-assert rule) |
| 140 | `move_right` | focus → 襄阳 |
| 150 | `ui_accept` | arrive 襄阳; `dragon_scrap` EVENT |
| 160 | assert | `phase == "EVENT"`, `event_id == "dragon_scrap"`, `current_node_id == "xiangyang"` |
| 170 | `ui_accept` | resolve option A (practice +4) |
| 180 | assert | `phase == "TRAVEL"`, `event_id == ""`, `events_resolved_count == 3` |
| 190 | `move_right` | focus: 襄阳 → 昆仑 |
| 200 | assert | `focus_id == "kunlun"`, `ended == false` (the terminal is one press away, unblocked — the ending itself stays proven by the spine) |

**`playtest/map_node_event_mainline_return.yaml`** —
`scene: res://scenes/segments/map.tscn`. Pins the 无名谷 return-binding, the
no-boot-fire property, and the hint unification:

| frame | action | effect |
|---|---|---|
| 30 | assert **NEW** | `phase == "TRAVEL"`, `event_id == ""`, `current_node_id == "wuming_valley"`, `HintLabel.visible: visible == true`, `HintLabel.text: text == "左右/上下选择相邻去处，回车启程"` — proves the active 无名谷 binding does NOT fire at boot AND the two hint sites are unified |
| 40 | `move_right` | focus → 洛阳 |
| 50 | `ui_accept` | arrive 洛阳; `merchant` EVENT |
| 60 | assert | `phase == "EVENT"`, `event_id == "merchant"`, `HintLabel.visible: visible == false` |
| 70 | `ui_accept` | resolve option A |
| 80 | assert | `phase == "TRAVEL"`, `event_id == ""`, `events_resolved_count == 1`, `HintLabel.visible: visible == true` |
| 90 | `move_right` | focus: 洛阳 → 武当 (successor) |
| 100 | `move_left` | focus: 武当 → 无名谷 (idx 0) |
| 110 | assert | `focus_id == "wuming_valley"` |
| 120 | `ui_accept` | arrive 无名谷 (RETURN travel); `tomb_bed` EVENT fires |
| 130 | assert | `phase == "EVENT"`, `event_id == "tomb_bed"`, `current_node_id == "wuming_valley"` |
| 140 | `ui_accept` | resolve option A (attr inner +2) |
| 150 | assert | `phase == "TRAVEL"`, `event_id == ""`, `events_resolved_count == 2`, `attr_inner: changed` |

Both files: `name:` == basename, single-integer `at:`, a comparison operator or
the `changed` token on every assert line (the smoke-test discipline), at least
one input action, zero absolute game-value literals (only the hint-string pin,
which is a text contract, not a number). Autosave refusals on direct boot
(outside a STABLE state) are documented-harmless — neither scenario asserts save
state.

### C6 — `playtest/_common.yaml` + `tests/test_playtest_contract_smoke.py`

- `_common.yaml`: `scenario_order` tail appends `map_node_event_mainline_east`,
  `map_node_event_mainline_return` (append-only; the surface whitelist needs NO
  change — every observable used, including `HintLabel.text`, is already
  listed).
- `tests/test_playtest_contract_smoke.py`: `ROUND_SCENARIOS` tail syncs the same
  two names (two-place sync rule); a new test pins each new scenario file
  (exists, name == basename, single-integer `at:`, operator discipline) and the
  superset pin (D7): hard-coded pre-edit assertion lines for both edited
  scenarios (with the single D2 substitution
  `events_resolved_count == 1` → `== 2` encoded as the documented exception),
  asserting every pre-edit line still exists in the current file — the machine
  proof of 只许加,不许减.

### C7 — Unit test updates (`.gd` files — allowed; they are not scenario yamls)

- `tests/test_map_data.gd`: `active_count == 1` → `== 5` (shaolin + the four
  mainline); the mainline-inert pins become binding pins
  (`active_event_id("luoyang") == "merchant"`, `("wudang") == "quanzhen_scripture"`,
  `("xiangyang") == "dragon_scrap"`, `("wuming_valley") == "tomb_bed"`,
  `("kunlun") == ""` — the terminal pin kept); `declared_gap_types("luoyang") ==
  ["battle", "facility"]` (was 3 slot types; same for `wuming_valley`).
- `tests/test_map_node_event.gd`: pin (b) "exactly one ACTIVE event slot" → 5;
  pin (c) "every mainline node stays inert" → re-argued, not just re-numbered
  (4 of 5 live; kunlun stays declared for the terminal guarantee — the comment
  must quote the routing-first order, replacing the old spine-protection
  rationale); pin (d) 洛阳's gap list is exactly 2 slot types; the live-leg test
  at L388–400 (无名谷→洛阳 stays in TRAVEL) → now asserts arrival enters EVENT
  with `event_id == "merchant"`, resolve returns to TRAVEL; the `kunlun`
  end-node pin (L405–406) stays green and stays.
- **NEW (D6):** explicit bag-independence pin — resolving a mainline event
  leaves `profile.flags["events_seen"]` untouched. Add to
  `tests/test_map_node_event.gd` (no new file, so `unit_test_runner.gd`'s TESTS
  registry is unchanged).

### C8 — `final/delivery_notes.md` — the audit record (required output this round)

The persistent-text investigation, scoped to the MAP segment's TRAVEL↔EVENT
switch (the segment this round's lever lives in; other segments' phase switches
are outside the single lever):

> 查过,只此一处 — audited `scenes/segments/map.tscn`: the MAP segment has
> exactly two persistent Label text nodes, `BodyLabel` (fully re-rendered on
> every phase by `map.gd::_render()`, including the EVENT branch) and
> `HintLabel` (visibility toggled by `_apply_hint_visibility()`, whose
> `phase != "EVENT"` allow-list-by-negation already yields for any future
> phase). No other persistent text exists in the segment; the only
> "phase-switch stale promise" site was HintLabel, already fixed in the previous
> round and re-pinned by the new scenarios this round.

The note also records: the 4-of-5 binding result with 昆仑's argued non-trigger,
the two authorized yaml re-budgets, the one literal re-base, the hint
unification, and the honest gate-evidence stance (measured PASS counts belong
to the downstream 5_compile/5_test gate products; none are invented here).

## 5. Observable contract (playtest surface — no whitelist change)

Every observable this design asserts is **already whitelisted** in
`playtest/_common.yaml`: `MapScreen: current_node_id, focus_id, ended, phase,
event_id, event_focus, entry_declared_gap_types, silver, attr_bone, attr_inner,
attr_agility, attr_wisdom, attr_fortune, last_effect_types,
events_resolved_count, visible, size` and `HintLabel: visible, text`. The
contract header's discipline applies to every new/edited assert line: a
comparison operator (`==`, `!=`, `and`, `or`, `>=`, `<=`) or the differential
token `changed` — never a bare scalar that the harness would silently
string-compare. Numeric assertions are relative/differential everywhere
(`changed`, ladder equalities, range asserts); the only absolute pin is the
hint **text** string, which is a UI-text contract, not a game value.

## 6. Edge cases (from step1_sota / review → how this design answers each)

- **E1 · The 3-edge hub trap (洛阳).** `ADJACENCY["luoyang"]` has three
  neighbors; a swallowed `move_right` during a live EVENT does not just mis-aim
  — it silently changes which node is focused. Answer: the resolve press is
  inserted BEFORE each focus cycle in both re-budgeted timelines (C3 f450→f460,
  C4 f450→f470), and the shaolin yaml keeps its **two** `move_right` presses
  (focus 武当 then 少林 — one press gives the MAINLINE successor 武当, never
  少林).
- **E2 · 昆仑 is structurally dead.** `_travel()` routes end nodes to ENDING
  before `_maybe_start_entry_event()`; a binding there would never fire. Answer:
  stays `declared`; the routing-first order is written up in C0 as the
  structural guarantee; the existing `kunlun` inert pin is kept (C7).
- **E3 · 无名谷 must not fire at boot.** It fires only on arrival by travel, so
  a boot/save-load at an active node never re-triggers
  (`save_load_roundtrip` stays green). Answer: pinned by the f30 assert in
  `map_node_event_mainline_return.yaml` (event_id == "" at boot) plus the
  return-travel firing at f120.
- **E4 · Silver floor.** `merchant` option A can clamp silver at 0. Answer: no
  scenario asserts absolute silver; see the C3 paragraph — provably inert.
- **E5 · RNG / bag independence.** `apply_option_effects` performs zero RNG
  calls and never touches `events_seen`. Answer: D6 unit pin; the seeded stream
  is byte-identical, so `event_travel_effects` (19/19) and
  `save_load_roundtrip` (14/14) stay green by construction.
- **E6 · Stale `description:` prose.** Both edited scenarios' docstrings claim
  things that become false (spine: "4 moves to 昆仑"; shaolin: "mainline nodes
  stay inert"). Answer: both rewritten in C3/C4, named in C0; the superset pin
  (D7) protects the ASSERT lines, and the design rationale names the prose edits
  alongside the frame edits.
- **E7 · Repeat-visit re-fire.** 洛阳 re-fires on the shaolin return leg — that
  is the documented policy, now pinned (C4 f600–f630) instead of silently
  costing a press.
- **E8 · Autosave refusals on direct boot.** Harmless refusals (documented at
  `test_map_node_event.gd` L19–22); no new scenario asserts save state.
- **E9 · Frame caps.** Spine last assert 580 ≤ 2900; shaolin last assert 660 ≤
  2999; both new scenarios end ≤ 200. All inside the harness caps.
- **E10 · MapScreen observables after the ending swap.** No MapScreen assert is
  placed after `GameManager.enter_segment("ENDING")` — the node is freed by the
  scene swap and the Expression would fail. The ending block keeps only its
  pre-existing GameManager/EndingScreen/Backdrop lines.

## 7. Safety / rollback

No irreversible operations. All edits are git-tracked text files; the design
explicitly rejects any destructive migration. Order of operations with
verification:

1. C0 (docs) lands first — the rationale exists before any yaml moves.
2. C1/C2 (data + one string) — compile gate parses; unit pins C7 re-based in the
   same change set so the suite is coherent.
3. C3/C4 (yaml re-budgets) — the superset pin (D7) verifies no assert was
   dropped; the playtest gate re-runs the two scenarios.
4. C5/C6 (appends) — append-only, no existing file's asserts touched.
5. Rollback path: `git checkout` of the two yamls + revert the four `map_data.gd`
   literals to `{"status": "declared", "event_id": ""}` + revert the one tscn
   string. The declaration-table design means rollback is data-only — no logic
   to unwind, and every scenario (including the two new ones) degrades to the
   pre-round behavior if the bindings are inert (typo-safe fail-safe is built
   into `active_event_id`).

## 8. Task decomposition (for PM)

| # | Task | Files | Depends on |
|---|---|---|---|
| T1 | Docs-first rationale (C0) — binding table, yaml re-budget rationale, the literal re-base justification, 昆仑 ruling, hint note | `design/20_content.md`, `design/40_progression.md`, `design/90_decisions.md`, `design/99_changelog.md` | — |
| T2 | Binding data edit + comment rewrite (C1) | `scripts/data/map_data.gd` | T1 |
| T3 | Hint unification (C2) | `scenes/segments/map.tscn`, `scripts/segments/map.gd` | T1 |
| T4 | Spine re-budget (C3) — exact frames per §4.3 | `playtest/spine_to_ending.yaml` | T1, T2 |
| T5 | Shaolin re-budget (C4) — exact frames per §4.4 + the one re-based literal | `playtest/map_node_event_shaolin.yaml` | T1, T2 |
| T6 | Two appended scenarios (C5) | `playtest/map_node_event_mainline_east.yaml`, `playtest/map_node_event_mainline_return.yaml` | T2, T3 |
| T7 | Contract sync + superset pin (C6) | `playtest/_common.yaml`, `tests/test_playtest_contract_smoke.py` | T4, T5, T6 |
| T8 | Unit pins re-based + bag-independence pin (C7) | `tests/test_map_data.gd`, `tests/test_map_node_event.gd` | T2 |
| T9 | Delivery notes with the audit line (C8) | `final/delivery_notes.md` | T1–T8 (written last, honestly reflecting gate evidence) |

## 9. Technology stack

- **Godot 4.4 built-ins only** (GDScript statics, pure data tables, `Control` /
  `Label`, `_unhandled_input` + `set_input_as_handled()`) — the repo's own
  pattern; zero new dependencies, zero new art (consistent with the open-and-play
  constraint and the no-reinvention rule).
- **The existing playtest harness** (aitelier `godot_playtest`,
  `playtest/_common.yaml` sibling scan, per-scenario `scene:` override,
  `assert:` Expression evaluation) — the only runtime test tooling needed.
- **PyYAML + pytest** (`tests/test_playtest_contract_smoke.py`) for the static
  contract pins, extended append-only with the superset pin (the machine proof
  of "only add, never remove").
- **Doc-first markdown archive** (`design/` + `final/delivery_notes.md`) as the
  rationale/audit tool.

Rejected: any new external event/framework; pool-draw bindings for mainline
nodes; reordering `_travel()` to force a 昆仑 trigger; any new authored event
text (must stay inside the 16-row pool — gaps are recorded, never invented);
editing any of the 53 frozen scenarios; `_common.yaml` edits beyond appending
scenario names (the surface needs no change).

## 10. Acceptance criteria mapping

| Success criterion | Where this design delivers it |
|---|---|
| `spine_to_ending.yaml` all green, still proves six segments connected + ending reachable | C3: existing asserts verbatim (moved frames only), 3 additive event blocks, ENDING block intact at f580; routing-first order keeps 昆仑 non-blocking |
| Each of the five main nodes triggers content without blocking progression; 昆仑 still reaches the ending | C1 binding table (4 live + kunlun argued non-trigger), C3/C4/C5 pins |
| Map bottom hint and panel hint unified | C2 (byte-identical string) + the `HintLabel.text` pin in `map_node_event_mainline_return.yaml` |
| Other 54 existing scenarios stay green; new scenarios appended only | Blast radius = the 2 authorized files (grep-verified); C5/C6 append-only; RNG/bag untouched (E5) |
| Delivery notes include the persistent-text investigation result | C8 — the 「查过,只此一处」 audit line |
