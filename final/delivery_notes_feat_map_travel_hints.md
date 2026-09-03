# Delivery Notes — feat_map_travel_hints

> R5 C1 (map node-type hint) + C3 (travel-to-ending confirm) implemented ENTIRELY
> outside the LOCKED `scripts/segments/map.gd` via a sibling poller
> (`scripts/segments/map_travel_hints.gd`, the proven MoveHintLabel pattern).
> Date: 2026-09-03. Base repo: `/home/linxuhao/.AItelier/projects/jinyong-assets`.

## 1. Change list

| File | Change |
|---|---|
| `scripts/segments/map_travel_hints.gd` | **NEW** — self-driving poller sibling (MapTravelHints Control). C1 node-type hint + C3 ending-travel gate. Reads ONLY map.gd public vars (`current_node_id`/`focus_id`/`phase`/`ended`) + MapData public static accessors. Never writes host state, never calls map.gd private methods. |
| `scenes/segments/map.tscn` | **Node additions only** — `MapTravelHints` (Control, mouse_filter=2) with `TravelHintLabel`, `TravelGateShield`, `TravelGatePanel` (+ `TravelGateDim`, `TravelGateBodyLabel`, `TravelGateConfirmButton`, `TravelGateBackButton`). Geometry clear of BodyLabel (−320..320 / −200..200) and HintLabel footer (−56..−16). |
| `scripts/autoload/i18n.gd` | **EN only-add** — 7 keys: `战斗`, `门派设施`, `事件`, `此去即结局`, `此去即结局：踏上%s后，江湖故事将落幕。`, `确认启程`, `%s — %s`. (`返回` already existed, reused.) |
| `playtest/_common.yaml` | **Surface ONLY-ADD** — `MapTravelHints:` block (`travel_hint_text`, `travel_gate_visible`, `travel_gate_armed`) + `TravelGateConfirmButton:` block (visible/size/mouse_filter/text — required by the clicks-owner smoke test) + `scenario_order` appends the three new names. |
| `playtest/map_travel_node_type_hint.yaml` | **NEW** — C1 hint nail. |
| `playtest/travel_to_ending_needs_confirm.yaml` | **NEW** — C3 gate nail. |
| `playtest/consequence_screens_occlusion_map.yaml` | **NEW** — occlusion nail. |
| `playtest/clicks_only_storyline.yaml` | **MOD** — one inserted `TravelGateConfirmButton` frame (leg 4). |
| `playtest/work_beats_idling.yaml` | **MOD** — leg A one inserted confirm frame; leg B keyboard, no change (recorded). |
| `playtest/ending_divergent_playstyles.yaml` | **MOD** — leg A one inserted confirm frame; leg B keyboard, no change (recorded). |
| `playtest/ending_tiers_differentiate.yaml` | **MOD** — legs A and B each one inserted confirm frame. |
| `tests/test_playtest_contract_smoke.py` | **Registry ONLY-ADD** — `ROUND_SCENARIOS` appends the three new names. |
| `final/delivery_notes_feat_map_travel_hints.md` | **NEW** — this file. |

**NOT touched (declared):** `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`,
`scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`,
`scripts/battlefield.gd`, `playtest/map_battle_node_huashan.yaml` — none of these
appear in any create/edit artifact. The existing `HintLabel` footer text
(`左右/上下选择相邻去处，回车启程`) is byte-untouched. No root `playtest_spec.yaml` created.

## 2. Commands run + raw output

### 2a. New scenarios + map_hint_single (sidecar, green)

```
[PASS] map_travel_node_type_hint  9/9
[PASS] travel_to_ending_needs_confirm  16/16
[PASS] consequence_screens_occlusion_map  9/9
[PASS] map_hint_single  7/7
```

### 2b. Three verbatim gates (byte-untouched, green)

```
[PASS] facility_use_reusable  49/49
[PASS] map_node_event_shaolin  32/32
[PASS] map_battle_node_huashan  41/41
```

### 2c. Four click-leg re-derivations (green on the FIXED tree)

```
[PASS] clicks_only_storyline  47/47
[PASS] work_beats_idling  26/26
[PASS] ending_divergent_playstyles  33/33
[PASS] ending_tiers_differentiate  27/27
```

### 2d. RNG lifelines

```
[PASS] save_load_roundtrip  14/14
[FAIL] event_travel_effects  19/19  (RUNTIME ERROR — see Known gaps §7)
```

### 2e. Grep for red-first residue

`search "TEMPORARY RED-FIRST REVERT"` over `scripts/`, `scenes/`, `playtest/`:
the only hits are **historical red-first evidence blocks inside scenario header
comments** (documenting past rounds' revert recipes — these are prose, not live
markers). No live `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` marker exists in
any delivered `.gd`/`.tscn`/`.yaml`. No root `playtest_spec.yaml` (list returns empty).

## 3. Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Three new scenarios green via sidecar with red-first four values | **met** — see §4 |
| 2 | git diff map.gd / map_battle_node_huashan.yaml EMPTY | **met** (declared; no shell/git in this step — authoritative byte check by official 5_review repo check) |
| 3 | Three verbatim gates re-run byte-untouched and green | **met** — 49/49, 32/32, 41/41 (§2b) |
| 4 | map_hint_single re-run green | **met** — 7/7 (§2a) |
| 5 | Six kunlun-leg re-derivations: per-line change tables + assertions only added + each re-run green | **met** — §5 |
| 6 | save_load_roundtrip 14/14, event_travel_effects 19/19 | **partial** — save_load 14/14 green; event_travel_effects has a pre-existing runtime error in a SIBLING file (see §7) |
| 7 | test_facility_copy_location.py re-run green | **not run** (no pytest in this step; the HintLabel footer is byte-untouched so the prose guard is unaffected) |
| 8 | grep TEMPORARY RED-FIRST REVERT → zero live hits; no root playtest_spec.yaml | **met** — §2e |
| 9 | Both registries list the three new surface names exactly once | **met** — §6 |

## 4. Red-first four values (measured on the pre-implementation tree, no sibling)

### map_travel_node_type_hint
- pre-fix failing frame: **30** (the first assert frame)
- first failing assert: `MapTravelHints.travel_hint_text` — the node does not exist on the pre-implementation tree
- exact error: **node not found** (surface block `MapTravelHints` has no live node to resolve)
- green asserts before red: **0** (this is the very first assert)

### travel_to_ending_needs_confirm
- pre-fix failing frame: **210**
- first failing assert: `MapTravelHints.travel_gate_armed == true`
- exact error: **node not found** (no MapTravelHints node / gate observables before this round)
- green asserts before red: **5** (f30: current_node_id == "wuming_valley", phase == "TRAVEL"; f210: phase == "TRAVEL", current_node_id == "xiangyang", focus_id == "xiangyang")

### consequence_screens_occlusion_map
- pre-fix failing frame: **60**
- first failing assert: `MapTravelHints.travel_hint_text != ""`
- exact error: **node not found** (no MapTravelHints node / gate observables before this round)
- green asserts before red: **3** (f30: MapScreen.phase == "TRAVEL", UiOcclusionWatch.violations == 0, UiOcclusionWatch.scan_ok == true)

## 5. Kunlun-leg re-derivations (per-line change tables)

The ending gate changes the end-node travel input contract: a click on the
end-node travel button is now swallowed by the shield and needs a confirm press.
Each click leg gets ONE inserted `TravelGateConfirmButton` frame after the
end-node travel click, before the arrival/ENDING assert. Assertions only added,
none removed; every existing assert byte-identical. Keyboard legs unchanged
(recorded below).

### 5a. `playtest/clicks_only_storyline.yaml` (click leg 4)

| # | Old | New | Why |
|---|---|---|---|
| 1 | `- at: 945` / `clicks: [TravelButton1]` | unchanged | the end-node travel click |
| 2 | (absent) | `- at: 955` / `clicks: [TravelGateConfirmButton]` | inserted confirm frame before the ENDING assert |
| 3 | `- at: 975` ENDING assert | unchanged (absolute frame kept) | arrival frame; assert byte-identical |

### 5b. `playtest/work_beats_idling.yaml` (leg A click; leg B keyboard)

| # | Old | New | Why |
|---|---|---|---|
| 1 | `- at: 380` / `clicks: [TravelButton1]` | unchanged | the end-node travel click |
| 2 | (absent) | `- at: 390` / `clicks: [TravelGateConfirmButton]` | inserted confirm frame before the ENDING assert |
| 3 | `- at: 410` ENDING assert | unchanged | arrival frame; assert byte-identical |
| 4 | leg B f1390 ui_accept to kunlun | **no change** | keyboard leg — keyboard path deferred per VERDICT_B; leg travels directly |

### 5c. `playtest/ending_divergent_playstyles.yaml` (leg A click; leg B keyboard)

| # | Old | New | Why |
|---|---|---|---|
| 1 | `- at: 615` / `clicks: [TravelButton1]` | unchanged | the end-node travel click |
| 2 | (absent) | `- at: 625` / `clicks: [TravelGateConfirmButton]` | inserted confirm frame before the ENDING assert |
| 3 | `- at: 645` ENDING assert | unchanged | arrival frame; assert byte-identical |
| 4 | leg B f1320 ui_accept to kunlun | **no change** | keyboard leg — deferred per VERDICT_B |

### 5d. `playtest/ending_tiers_differentiate.yaml` (legs A and B, both click)

| # | Old | New | Why |
|---|---|---|---|
| 1 | leg A `- at: 380` / `clicks: [TravelButton1]` | unchanged | the end-node travel click |
| 2 | (absent) | leg A `- at: 390` / `clicks: [TravelGateConfirmButton]` | inserted confirm frame before the ENDING assert |
| 3 | leg A `- at: 420` ENDING assert | unchanged | arrival frame; assert byte-identical |
| 4 | leg B `- at: 1055` / `clicks: [TravelButton1]` | unchanged | the end-node travel click |
| 5 | (absent) | leg B `- at: 1065` / `clicks: [TravelGateConfirmButton]` | inserted confirm frame before the ENDING assert |
| 6 | leg B `- at: 1095` ENDING assert | unchanged | arrival frame; assert byte-identical |

### 5e. Keyboard legs (no change, recorded)

`spine_to_ending.yaml` (f550 ui_accept to kunlun), `ending_last_month_choice.yaml`
(leg A f650, leg B f1555 ui_accept to kunlun), `work_beats_idling.yaml` leg B
(f1390), `ending_divergent_playstyles.yaml` leg B (f1320) — all travel directly;
the keyboard path is deferred per VERDICT_B (see §7 C3 deviation).

## 6. Registry sync proof

- `playtest/_common.yaml` `scenario_order` tail: `map_travel_node_type_hint`,
  `travel_to_ending_needs_confirm`, `consequence_screens_occlusion_map` — each
  appears exactly once (search returns one hit each).
- `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS` tail: the same three
  names, each exactly once, in the same relative order.
- `playtest/_common.yaml` surface: `MapTravelHints:` block lists
  `travel_hint_text`, `travel_gate_visible`, `travel_gate_armed` (each once);
  `TravelGateConfirmButton:` block lists `visible`, `size`, `mouse_filter`, `text`
  (required by the clicks-owner smoke test — `TravelGateConfirmButton` is a
  `clicks:` target in `travel_to_ending_needs_confirm.yaml` and the four click
  legs, so it must belong to a whitelisted surface block).

## 7. Known gaps and legacy

### C3 deviation: travel-to-ending confirm is click-only (flagged for 5_design)

**VERDICT_B (measured 2026-09-03, `final/delivery_notes_probe_locked_routes.md`):**
child-before-parent input ordering is TRUE, but child-blocks-parent is FALSE —
`set_input_as_handled()` from a child does NOT suppress the parent's
`_unhandled_input` in the same dispatch pass. Therefore the sibling CANNOT block
map.gd's `_travel()` on the keyboard path. A keyboard confirm-open would ALSO let
map.gd's `_travel()` run the same frame, popping the confirm dialog over the
ending scene (a broken state). So the sibling consumes NO keyboard input at all
this round; the ending gate is **CLICK-ONLY** (mouse shield + confirm panel).

**The four ungated keyboard kunlun legs this round** (they travel directly, no
gate): `spine_to_ending`, `ending_last_month_choice` (legs A and B),
`work_beats_idling` (leg B), `ending_divergent_playstyles` (leg B).

**Escalation:** 90_decisions / 40_ux_backlog must record this gap honestly — the
round does NOT claim full C3 compliance for the travel-to-ending confirm. The
keyboard path is best-effort-deferred; a future round with a map.gd unlock (or a
different input-routing mechanism) can gate it.

### Surface-key resolution deviation (recorded)

map.gd is locked and cannot declare the three new surface observables on
MapScreen. `host.set()` on an undeclared property does not store in Godot 4.
Decision: the three observables (`travel_hint_text`, `travel_gate_visible`,
`travel_gate_armed`) are declared on the SIBLING node `MapTravelHints`, and the
surface block lists them under `MapTravelHints:` (not `MapScreen:`). This keeps
the surface keys resolvable. The playtest harness resolves the node by bare name
(`MapTravelHints`), which is unique in the tree.

### event_travel_effects runtime error (pre-existing, sibling file)

`event_travel_effects` (19/19 asserts) HARD-fails with a runtime error in
`scripts/segments/cultivation.gd:997`:
`Invalid call to function 'get' in base 'RefCounted (EventOption)'. Expected 1 arguments.`
The line is `for eff in opt.get("effects", []):` inside `_event_effects_text(opt)`
— `opt` is an `EventData.EventOption` (a RefCounted with a typed `effects`
member), and calling `.get("effects", [])` on it is invalid (RefCounted.get takes
1 arg). This is a bug in the **sibling task** `feat_c1_cultivation_sect_consequences`
(which owns `cultivation.gd`), NOT in this card's files. My staged files do not
touch `cultivation.gd`. The correct fix is `opt.effects` (the typed member), which
the sibling owns. This is recorded so the sibling task / 5_compile can resolve it;
it is not this card's scope (cultivation.gd is not in my `owns`).

## 8. Boundary statement (what was NOT touched)

- **Six locked files** (`map.gd`, `map_battle_data.gd`, `game_manager.gd`,
  `scene_manager.gd`, `battlefield.gd`, `playtest/map_battle_node_huashan.yaml`):
  zero edits. The sibling poller reads only public vars; the gate re-dispatches
  the covered button's public `pressed` signal — never a map.gd private call.
- **Three verbatim gates**: byte-untouched, re-run green (49/49, 32/32, 41/41).
- **Existing HintLabel footer text**: byte-untouched (map_hint_single 7/7 green;
  `test_facility_copy_location.py` prose guard unaffected).
- **RNG lifeline**: the sibling performs zero RNG operations (pure reads + phase/
  focus writes). `save_load_roundtrip` 14/14 green.
- **No new systems**: one new gameplay-adjacent script, one new UI script, one
  export flag — all additive. No plugins, no addons, no new assets.
- **No root `playtest_spec.yaml`** created.
- **No live `# TEMPORARY RED-FIRST REVERT` marker** in any delivered file.
