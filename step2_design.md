# 技术架构设计 — jinyong-roster (人物栏 · 功法栏 · 物品栏)

**Step 2 (Architect) · 2026-08-30 · Single lever:** one tappable, read-only roster panel
(character / gongfa / items) openable from CULTIVATION and MAP, proven by a clicks-only
correspondence nail whose first-red is measured, plus the two recorded debts (README counts,
facility-pin failure message) and the two record-only backlog rows (UX-13 / UX-14).

**Inputs honored:** Project Brief + verbatim spec, `step1_sota.md` (reuse-only conclusion),
`design/` (30_presentation 指针可达性 (f)/(g) single-surface rules, 31_touch_coverage survey,
40_progression §7–§9, 40_ux_backlog format, 90_decisions ruling format, 99_changelog
append-only archive). Everything below reuses in-repo machinery; **zero new dependencies**.

---

## 1. 概述

The player's data already exists (`PlayerProfile`: attrs / traits / gongfa / silver /
inventory / cultivation) and one path is dead: 12 equipment cards append ids into
`profile.inventory` (`scripts/data/event_logic.gd` item effects, `scripts/data/card_data.gd:36-48`)
and **nothing ever renders them**. This round adds a single new *display-only* surface:

- **Entry** — a visible, tappable `RosterOpenButton` in both stable segments
  (`CULTIVATION`, `MAP`; `design/40_progression.md §8`), delivered as one self-contained
  instanced scene so hosts change by **one node + one input-gate line** each.
- **Panel** — three sections, all read from `SaveManager.profile` at open time:
  (a) 人物: five attributes, silver, innate traits, current year/month, sect;
  (b) 功法: each learned art with grade / practice / 大成 marker;
  (c) 物品: `profile.inventory` resolved via the frozen `CardData.display_name_of(id)`,
  unknown ids degrade lazily to the raw id (never crash, never `push_error`).
- **Close** — a pinned `RosterCloseButton` **and** a tap-outside dim layer (both exist;
  the button is what the scenario clicks).
- **Single-surface conformance** — the panel has **zero internal selectable options**
  (pure display rows + two controls), publishes `cursor_markers_visible == false`, and
  while open owns all input (host `_unhandled_input` gated by one boolean; the dim layer's
  STOP filter covers every host control). No `▶` is ever printed anywhere.
- **Read-only hard guarantee** — open/close never call `SaveManager.autosave()`, never
  write any profile field, never consume a month/action, never touch `spine_to_ending.yaml`
  timing (the panel is not a phase; the spine never opens it).

Nail discipline: the scenario drives the **real grant path**
(`map.gd::_resolve_node_event → EventLogic.apply_option_effects`, merchant `option_a` →
silver −20 + item `eq_sword_3` 青锋剑 — deterministic, already unit-pinned in
`tests/test_map_node_event.gd:274-292`), then `click:` opens the panel and asserts
`青锋剑` inside `RosterBodyLabel.text`. Text-name pins are the sanctioned exception to the
no-absolute-numbers rule (`30_presentation.md` relative-numeric discipline); every other
assert is structural (`==` on session counters/phases) or differential (`changed`).

## 2. 架构图(文字)

```
                            SaveManager.profile  (READ-ONLY for this round)
                              attrs / traits / gongfa / silver / inventory / cultivation
                                      │ read at open()/refresh()
                                      ▼
 scenes/segments/cultivation.tscn ─┐
 scenes/segments/map.tscn ─────────┤  each instances ONE node:
                                   │      RosterPanel  (scenes/ui/roster_panel.tscn)
                                   ▼
 scenes/ui/roster_panel.tscn  =  RosterPanel (Control, full-rect, mouse_filter=2 ALWAYS)
                                   ├─ RosterOpenButton  (「角色」, focus_mode=0, visible iff !is_open)
                                   └─ RosterOverlay     (visible iff is_open)
                                        ├─ RosterDim    (ColorRect, STOP; click-outside → close)
                                        └─ RosterBox    (Panel, STOP; absorbs inside clicks)
                                             ├─ RosterBodyLabel   (composed 人物/功法/物品 text)
                                             └─ RosterCloseButton (「关闭」, focus_mode=0)

 name resolvers (use, never modify):
   CardData.display_name_of(id)              -> "" on unknown  (FROZEN, card_data.gd:82-84)
   ProgressionGongfaData.display_name_of(id) -> "" on unknown  (progression_gongfa_data.gd:216-220)
   ProgressionGongfaData.PRACTICE_TO_MASTER  -> {"D":4,"C":6,"B":8,"A":10}  (:22)
   ProgressionGongfaData.SECTS               -> id + display_name (少林/武当/丐帮/峨眉/唐门, :48-74)
   TraitData.get_def(id).display_name        -> null-guarded     (trait_data.gd:48-52)

 grant path under the nail (real code, no field writes):
   click TravelButton0 → map EVENT(merchant) → click EventOptionButton0
     → map.gd::_resolve_node_event → EventLogic.apply_option_effects
     → profile.inventory += "eq_sword_3" (青锋剑) → click RosterOpenButton → assert 青锋剑

 host input ownership (the ONLY host code change, one guard each):
   cultivation.gd / map.gd::_unhandled_input:  if roster panel is_open: return
   (keyboard branches byte-identical whenever the panel is closed)
```

## 3. 组件列表

### 3.1 `scripts/ui/roster_panel.gd` + `scenes/ui/roster_panel.tscn` (NEW, self-contained)
- **职责:** entry button + overlay + three-section display + close affordances + observables.
  Reads `SaveManager.profile` only; **writes nothing, saves nothing, consumes nothing**.
- **Scene tree:** exactly as in §2. Root `RosterPanel`: full-rect anchors, `mouse_filter = 2`
  (IGNORE) **permanently** — the SegmentHost STOP-swallow defect class
  (`99_changelog.md` 2026-08-25 条) forbids a full-rect default-STOP host; children keep
  receiving clicks because parent-IGNORE does not block children (same documented semantics).
  `RosterDim` STOP is what blocks the host's own controls while open (panel = the single
  operation surface while open); `RosterBox` STOP so only *outside* clicks close.
- **Geometry:** `RosterOpenButton` top-right of the canvas, target rect ≈ `(830, 8)–(950, 48)`
  (above cultivation's OptionsBox column `x 610–950, y 80–620`; inside the 960×704 canvas in
  both hosts). Hittability needs no gate — `clicks:` is a true hit test, so occlusion /
  IGNORE / zero-size / off-screen delivery fails with `push_error` and turns the gate red.
  `RosterBox` centered ≈ 640×560; body label autowraps inside the box (vision-gate Q6 safe,
  global theme + NotoSansSC, no art assets).
- **Public API (class_name `RosterPanel extends Control`):**
  - `func open() -> void` / `func close() -> void` — flip `is_open`, sync `visible`, `refresh()`.
    No `SaveManager.autosave()`, no profile/flags writes, no month/action counters, no phase.
  - `var is_open: bool = false`
  - `func refresh() -> void` — recompute all observables + `body_text` from the live profile.
  - `func _compose_body(p: PlayerProfile) -> String` — **pure** string builder (unit-testable);
    same profile in → byte-identical string out.
  - Resolvers (private, all null-guarded, degrade lazily): `_name_of_item(id)`
    (`CardData.display_name_of`, `""` → raw id), `_name_of_gongfa(id)`
    (`ProgressionGongfaData.display_name_of`, `""` → raw id), `_name_of_trait(id)`
    (`TraitData.get_def(id)` null → raw id), `_sect_display(sect_id)` (`SECTS` scan,
    miss → raw id, `""` → 「无门无派」).
- **Published observables (recomputed in `refresh()`, `SaveManager.loaded` connected for
  re-sync — cultivation.gd:114-135 precedent):**
  `is_open`, `visible`, `body_text`, `cursor_markers_visible` (`"▶" in body_text`),
  `pressed_connected` (`{"RosterOpenButton": bool, "RosterCloseButton": bool}`, wired in
  `_ready` mirroring `map.gd::_wire_buttons`), `item_count`, `gongfa_count`.
- **Panel display rows (not options — shown normally per the brief):**
  - 人物: `根骨/内力/身法/悟性/福缘` values from `p.attrs`; `银两` = `p.silver`;
    `先天特质` = trait display names (empty list → 「（无）」); `第 %d 年 %d 月`;
    `门派` = sect display.
  - 功法: per `p.gongfa` entry `{id, grade, practice, mastered}` — name, grade letter,
    `练度 %d/%d` where the cap is `PRACTICE_TO_MASTER.get(grade, -1)` (grade `""` or unknown
    → practice shown without cap; hostile rows read via `.get()` with defaults, never crash),
    `大成` marker when `mastered == true`. Empty list → 「（无）」.
  - 物品: per `p.inventory` id → `_name_of_item`. Empty list → 「（无）」.
- **gongfa entry read rule:** every field via `entry.get("id","") / .get("grade","") /
  .get("practice",0) / .get("mastered",false)` — `from_dict` coerces but the panel never
  assumes (edge case 3 of step1_sota).

### 3.2 Host integration: `scenes/segments/cultivation.tscn`, `scenes/segments/map.tscn`
(+ `scripts/segments/cultivation.gd`, `scripts/segments/map.gd`)
- **职责:** instance `res://scenes/ui/roster_panel.tscn` as node **`RosterPanel`** (same name
  in both scenes → one surface block resolves under both boots). No new host copy, no new
  host button, no i18n entries in hosts (`tests/test_facility_copy_location.py` untouched).
- **Input gate (the only host script change):** first line of each `_unhandled_input`:
  `if _roster_open(): return` where `_roster_open()` is a null-safe
  `get_node_or_null("RosterPanel")` read of `is_open`. Keyboard branches stay byte-identical
  whenever the panel is closed; while open the host keyboard grammar (incl. map EVENT /
  FACILITY modals and cultivation's choice phases) is inert — the panel owns input. This is
  an input-*ownership* guard, not a new input action (see §7 ruling (b)/(d)).

### 3.3 i18n: `scripts/autoload/i18n.gd` (append entries only)
- New keys (Chinese-as-key, EN values) for every new player-facing string, e.g.:
  `「角色」→ "Character"`, `「关闭」→ "Close"`, section headers `人物/功法/物品`,
  `银两`, `先天特质`, `门派`, `无门无派`, `（无）`, `大成` (reuse the existing grade-step
  entry if present), `练度 %d/%d`, `第 %d 年 %d 月`, grade letter labels.
- Scene `text =` literals (`RosterOpenButton` / `RosterCloseButton`) are auto-translated
  whole strings but MUST have EN entries — `tests/test_i18n_coverage.py` scans scene `text=`,
  `tr()` call sites, and `.text =` assignments; all three channels stay green.
- Composed strings wrapped in `tr()` at composition sites in `roster_panel.gd`.
- **No new `.text =` Chinese literals in `map.gd`** — panel copy lives in
  `roster_panel.gd` / `i18n.gd` only.

### 3.4 Playtest contract additions (append-only)
- **`playtest/_common.yaml`** — append four NEW surface blocks (nothing existing changes):
  ```yaml
  RosterPanel:
  - visible
  - is_open
  - body_text
  - cursor_markers_visible
  - pressed_connected
  - item_count
  - gongfa_count
  RosterOpenButton:
  - visible
  - size
  - mouse_filter
  - text
  - focus_mode
  RosterCloseButton:
  - visible
  - size
  - mouse_filter
  - text
  - focus_mode
  RosterBodyLabel:
  - visible
  - text
  ```
  Append two names to `scenario_order` (tail, after `gongfa_pick_empty_keyboard_return`):
  `roster_panel_item_nail`, `roster_panel_cultivation_open_close`. No new actions.
- **`tests/test_playtest_contract_smoke.py`** — append the same two names to
  `ROUND_SCENARIOS` in the same order (two-place sync; `test_round_scenarios_present_on_disk_and_in_order`
  enforces order match). The smoke test's click-anchor whitelist check requires every
  `clicks:` target to be whitelisted — `TravelButton0` / `EventOptionButton0` already are;
  `RosterOpenButton` / `RosterCloseButton` are covered by the new blocks.
- **Facility anti-delete pin failure message (brief goal; additive only):** extend the
  shared `_escape` string (`tests/test_playtest_contract_smoke.py:1069-1076`) with an
  explicit form-gate sentence, e.g.:
  `" This is a FORM gate: it requires two literal assertion lines (phase != \"FACILITY\" and facility_use_count == 0) to appear verbatim in the scenario file — they are the machine-readable evidence of the definitional property 'arrival never enters a facility'. A red here is CORRECT when the observables or their expression legitimately change; the fix is to update this pin together with the equivalent new assertion in the same change — not to rename around it and not to keep a dead old-text line just to stay green."`
  All three asserts already inherit `_escape`; no regex/line is weakened, nothing frozen is
  touched (`_bad_timeline_at_values`, `test_facility_copy_location.py`, `card_data.gd`).

### 3.5 New playtest scenarios (2 files; both must be self-run)
**S1 — `playtest/roster_panel_item_nail.yaml`** (the round's nail)
`scene: res://scenes/segments/map.tscn` (direct boot; autoloads verified to load —
`_common.yaml` header). Skeleton (frame numbers are the implementer's to re-baseline against
the actual run; structure and assertions are the contract):
```yaml
name: roster_panel_item_nail
description: >-
  Correspondence nail: a REAL event path (map.gd::_resolve_node_event ->
  EventLogic.apply_option_effects, merchant option_a) grants eq_sword_3 (青锋剑),
  then clicks open the roster panel and assert the item's Chinese name appears;
  close restores the same state (phase / node / session counters unchanged).
  Ruling (b) pin: the panel also opens OVER the unresolved merchant modal —
  phase / event_id / events_resolved_count untouched while open — and after
  closing, the SAME EventOptionButton0 click resolves the event normally:
  the modal grammar resumes because the panel owned input while open.
# RED-FIRST EVIDENCE block pasted here from the measured run (§6).
timeline:
- at: 10   # boot
  assert:
    MapScreen.visible: visible == true
    MapScreen.phase: phase == "TRAVEL"
    MapScreen.current_node_id: current_node_id == "wuming_valley"
    RosterOpenButton.visible: visible == true
- at: 20   # travel wuming_valley -> luoyang (real path, clicks only)
  clicks: [TravelButton0]
- at: 30
  assert:
    MapScreen.phase: phase == "EVENT"
    MapScreen.event_id: event_id == "merchant"
    MapScreen.current_node_id: current_node_id == "luoyang"
    MapScreen.events_resolved_count: events_resolved_count == 0   # baseline for the mid-modal pin
- at: 35   # ruling (b) pin: OPEN the panel OVER the unresolved modal (true hit test)
  clicks: [RosterOpenButton]
- at: 40   # panel owns input; the modal underneath is untouched
  assert:
    RosterPanel.is_open: is_open == true
    MapScreen.phase: phase == "EVENT"
    MapScreen.event_id: event_id == "merchant"
    MapScreen.events_resolved_count: events_resolved_count == 0   # opening resolved/consumed nothing
    RosterBodyLabel.text: 'text.contains("人物") and text.contains("功法") and text.contains("物品")'   # three sections render even with an empty inventory
    RosterPanel.cursor_markers_visible: cursor_markers_visible == false
    MapScreen.cursor_markers_visible: cursor_markers_visible == false
    RosterCloseButton.visible: visible == true
- at: 45   # close back into the SAME unresolved modal
  clicks: [RosterCloseButton]
- at: 50   # modal intact — its grammar is about to be PROVEN by walking it, not asserted as prose
  assert:
    RosterPanel.is_open: is_open == false
    RosterPanel.visible: visible == false
    MapScreen.phase: phase == "EVENT"
    MapScreen.event_id: event_id == "merchant"
- at: 55   # the SAME option click resolves normally -> grammar resumed byte-identical
  clicks: [EventOptionButton0]
- at: 60
  assert:
    MapScreen.phase: phase == "TRAVEL"
    MapScreen.event_id: event_id == ""
    MapScreen.events_resolved_count: events_resolved_count == 1
    MapScreen.silver: changed          # grant landed (differential; no absolute silver)
- at: 65   # OPEN the panel again, now after the grant (true hit test proves tappable)
  clicks: [RosterOpenButton]
- at: 70
  assert:
    RosterPanel.is_open: is_open == true
    RosterBodyLabel.text: 'text.contains("青锋剑")'   # THE correspondence pin
    RosterPanel.cursor_markers_visible: cursor_markers_visible == false
    MapScreen.cursor_markers_visible: cursor_markers_visible == false
    MapScreen.phase: phase == "TRAVEL"
    RosterCloseButton.visible: visible == true
    RosterPanel.pressed_connected: pressed_connected.size() >= 2
- at: 75   # CLOSE
  clicks: [RosterCloseButton]
- at: 80
  assert:
    RosterPanel.is_open: is_open == false
    RosterPanel.visible: visible == false
    MapScreen.phase: phase == "TRAVEL"
    MapScreen.current_node_id: current_node_id == "luoyang"
    MapScreen.events_resolved_count: events_resolved_count == 1   # consumed nothing
    MapScreen.ended: ended == false
    RosterOpenButton.visible: visible == true
```
Notes: `events_resolved_count == 1` is a session-counter ladder pin (precedent
`map_node_event_shaolin.yaml` f460), not a balance literal. The name pin is the sanctioned
text-correspondence exception. The file carries a `: changed` line (silver) satisfying the
smoke test's relative-numeric rule; every dotted assert line carries an operator.

**S2 — `playtest/roster_panel_cultivation_open_close.yaml`** (entry reachability in
CULTIVATION + content presence + no-consumption + re-sync)
`scene: res://scenes/segments/cultivation.tscn`:
```yaml
name: roster_panel_cultivation_open_close
timeline:
- at: 20   # boot: fresh profile, month 1 (structural start state)
  assert:
    CultivationScreen.visible: visible == true
    CultivationScreen.phase: phase == "CARD_PICK"
    RosterOpenButton.visible: visible == true
- at: 30
  clicks: [RosterOpenButton]
- at: 40
  assert:
    RosterPanel.is_open: is_open == true
    RosterBodyLabel.text: 'text.contains("人物") and text.contains("功法") and text.contains("物品")'
    RosterPanel.gongfa_count: gongfa_count > 0      # relational; year-1 month-1 start grant
    RosterPanel.cursor_markers_visible: cursor_markers_visible == false
    CultivationScreen.cursor_markers_visible: cursor_markers_visible == false
- at: 50
  clicks: [RosterCloseButton]
- at: 60
  assert:
    RosterPanel.is_open: is_open == false
    CultivationScreen.phase: phase == "CARD_PICK"   # consumed no month/action
    CultivationScreen.month: month == 1             # structural ladder at fresh boot
- at: 70   # one real month advance via the DEBUG path (mirror
  actions: [debug_step_month]                      # cultivation_month_cycle_and_deck_bookkeeping's token)
- at: 80
  assert:
    CultivationScreen.month: changed               # deterministic differential, no literal
- at: 90   # reopen: panel re-syncs after state changed underneath
  clicks: [RosterOpenButton]
- at: 100
  assert:
    RosterPanel.is_open: is_open == true
- at: 110
  clicks: [RosterCloseButton]
- at: 120
  assert:
    RosterPanel.is_open: is_open == false
```
Implementer verifies the exact debug token against
`playtest/cultivation_month_cycle_and_deck_bookkeeping.yaml` (`debug_step_month` /
`debug_fast_forward`) and mirrors its real usage; if neither advances a month standalone,
fall back to one real month played by clicks (card + a non-travel action) keeping the
`changed` line on `CultivationScreen.month` or `CultivationScreen.silver`. Month `== 1` at
boot is a structural start-state pin (same class as the boot asserts existing scenarios
already carry), not a balance literal.

### 3.6 GDScript unit test: `tests/test_roster_panel.gd` (NEW)
Registered in the unit-suite registry exactly like `tests/test_facility_data.gd`. Pins:
1. item resolution: crafted profile with `eq_sword_3` → `_compose_body()` contains `青锋剑`;
2. unknown id degrade: inventory `["definitely_not_an_id"]` → body contains the raw id,
   no `push_error`, no crash;
3. honest empty states: default profile → three sections render with 「（无）」 rows;
4. gongfa row: `{id, grade:"C", practice:3, mastered:false}` → name + `练度 3/6` (cap from
   `PRACTICE_TO_MASTER`); `mastered:true` → 大成 marker; `grade:""` → no cap shown, no crash;
5. purity: same profile twice → identical string;
6. read-only: `profile.to_dict()` before `open()`+`close()` == after (bit-identical);
7. `cursor_markers_visible == false` for every composed body.

### 3.7 Design-doc updates (for `5_design` to land)
| File | Change |
|---|---|
| `design/30_presentation.md` | New subsection 「## 角色面板(roster panel, 2026-08-30)」 after 指针可达性: content (three sections + degradation), entry (`RosterOpenButton` in CULTIVATION/MAP), close affordances, single-surface conformance (zero internal selectables, `cursor_markers_visible == false`, dim-layer STOP = sole surface while open), read-only guarantee. |
| `design/31_touch_coverage.md` | One new row: roster overlay open state has ≥1 visible wired control (`RosterCloseButton`), touch-only exit **Y**; entry button covered in every cultivation/map phase. |
| `design/40_ux_backlog.md` | Two new OPEN record-only rows (§8 below) + one dated 记录 line. |
| `design/90_decisions.md` | New section with the seven rulings of §7. |
| `design/99_changelog.md` | **Verify, do not extend, row :126** (`touch_single_surface(修红实测收口)`) — it already holds the measured four values verbatim (f140 / `CultOptionButton0.visible: visible == true` / `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)` / red-before-green 9); record the verification conclusion in the delivery report; **no third correction row** (append-only archive: corrections are new rows and this correction already exists — step1 §14(b), reviewer-confirmed). Append ONE new row for this round's own design change. |
| `README.md` | Replace every stale 「71 scenarios」/「71 headless playtest scenarios」 (at least :402/:501/:507; sweep all occurrences incl. :554) with the **measured** final count from this round's official gate run (predicted 75 = 73 + 2; paste the measured value from `playtest_summary.md`). This is plain prose — **not** under the append-only archive rule — so a direct edit is sanctioned; state that distinction in the delivery notes. |

## 4. 接口规范(契约面)

- **Node names are load-bearing:** `RosterPanel`, `RosterOpenButton`, `RosterCloseButton`,
  `RosterBodyLabel` must exist verbatim in both host scenes (assert expressions resolve
  against live nodes; the smoke test requires click anchors whitelisted).
- **Surface contract:** new observables listed in §3.4 only; no existing block edited,
  no threshold relaxed, no frozen scenario touched. `test_edited_scenarios_assert_superset`
  guards *edits*; this round only *adds* files.
- **Click anchors:** `RosterOpenButton` / `RosterCloseButton` are Button bodies
  (`focus_mode = 0`) — never `*_ClickTarget` (2026-08-29 ruling). The tap-outside dim layer
  is never a click anchor in scenarios.
- **Assertion grammar:** every dotted assert line carries a comparison operator or
  `changed`/`unchanged`; numbers are structural counters/phases or differentials; the ONLY
  game-content literals are the text pins (青锋剑, section headers, 「（无）」).
- **Gate assertions stay game-level:** no `offset/position/size/z-order/mouse_filter` gates;
  `mouse_filter` may remain in the whitelist (legacy shape) but no assert depends on it —
  hittability is proven by the click itself.

## 5. 数据流

1. Grant: `map.gd::_resolve_node_event` (real path) → `EventLogic.apply_option_effects`
   → `profile.inventory.append("eq_sword_3")` (dedup append, `event_logic.gd:45-48`).
2. Open: `RosterOpenButton.pressed → RosterPanel.open()` → `refresh()` reads
   `SaveManager.profile` → `_compose_body()` → `RosterBodyLabel.text`; observables recomputed.
3. Close: `RosterCloseButton.pressed` / dim-layer click → `close()`; profile untouched.
4. Load: `SaveManager.loaded → refresh()` (stale-after-load impossible).
5. While open nothing can mutate the profile: host keyboard gated, host controls covered by
   the dim STOP layer, and no timer/phase machine writes profile outside input handlers.

## 6. 红先于绿:实测协议(MEASURED, never predicted)

Method = the twice-proven TEMPORARY RED-FIRST REVERT + direct sidecar call
(`record_measured_red_first_and_reconcile`; `touch_single_surface(修红实测收口)`):
1. In `scripts/ui/roster_panel.gd`, comment out the open handler body so `open()` is a
   no-op (panel never opens; button still exists and clicks still deliver), each block
   marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`.
2. Run the sidecar directly, NOT through the gate:
   `godot_playtest_scenario(scenario="roster_panel_item_nail")`.
3. Record the four measured values — failing frame / first failing assertion (expected
   shape: `RosterPanel.is_open: is_open == true` at the post-open frame) / exact error
   string / green asserts before red — into the scenario header RED-FIRST EVIDENCE block
   and the delivery notes.
4. Restore byte-identical (zero revert markers left in `scripts/`), re-run both new
   scenarios green, then the full official gate.
Predictions are never quoted as observations; the brief's example (f140 / 9-green) is the
*previous* round's measurement, not this one's.

## 7. 设计裁定(going verbatim into `design/90_decisions.md`)

- **(a) Panel is a pure display overlay, not a phase.** No `match phase:` arm, no new state
  string, no save/write. The single-surface rule is satisfied *vacuously* (zero internal
  selectables) and *actively* (`cursor_markers_visible == false` published and asserted;
  no `▶` anywhere).
- **(b) Openable in ANY phase of CULTIVATION/MAP — including map EVENT/FACILITY modals and
  cultivation's choice phases — with host `_unhandled_input` gated by `is_open`; both
  ownership claims below are pinned by assertions, not carried by prose (review round 1:
  option (ii) chosen over (i), reason below).** Rationale: **convenience** — "who am I /
  what do I carry" is phase-independent information, and the moment a player most wants
  it is right before committing an event choice (spend the silver? take the sword?).
  Option (i) — hiding the entry button during map EVENT/FACILITY — was defensible: the
  modals have their own tappable exits (`EventOptionButton0/1`, `FacilityUseButton` /
  `FacilityLeaveButton`), so a modal-gated entry costs only a few deferred clicks, never
  a trap. (ii) is chosen because the convenience is real exactly at that moment, and
  because it keeps the panel phase-blind — the scene stays self-contained (one node +
  one input-gate line per host, no visibility-sync coupling to the host's phase
  machine). Its price is that the two ownership claims must be measured, and they are:
  S1's inserted segment (f35–f60) opens the panel over the unresolved `merchant` modal,
  asserts the modal untouched while open (`phase == "EVENT"`, `event_id == "merchant"`,
  `events_resolved_count == 0`), closes, then the SAME `EventOptionButton0` click
  resolves normally (`events_resolved_count == 1`, `silver: changed`) — "while open, the
  modal keys are inert; on close the grammar resumes byte-identical" is carried by that
  walked segment. `spine_to_ending` never opens the panel → its timing is untouched by
  construction.
- **(c) Close = close button AND tap-outside.** The button is pinned by a real click (the
  tap-outside layer alone cannot be hit-tested by the harness meaningfully); the dim layer's
  STOP filter is what makes the panel the sole operation surface while open (host option
  buttons unreachable underneath).
- **(d) No new keyboard action this round.** Open/close are click-only; no `project.godot`
  input-map change, no new action token, zero grammar-clash surface. Keyboard shortcuts are
  additive-later; visible tappable controls are the sole mechanism (brief: shortcut-less
  is acceptable, button-less is not).
- **(e) Read-only hard guarantee.** `open()/close()` never call `SaveManager.autosave()`
  (anti-example: `map.gd:256` `_resolve_node_event` autosaves — that is the event path, not
  the panel), never write profile/flags, never consume a month/action. `save_load_roundtrip`
  stays green; SaveManager surface unchanged.
- **(f) Degradation, never invention.** Item names via frozen `CardData.display_name_of`,
  gongfa via `ProgressionGongfaData.display_name_of`, traits via `TraitData.get_def()`,
  sect via `SECTS`; every resolver miss degrades to the raw id or an honest 「（无）」 row.
  No new data fields, no new systems, no equipment semantics — the panel only *shows* what
  `PlayerProfile` already stores.
- **(g) Self-contained instanced scene.** One `.tscn` carries entry + overlay so hosts gain
  one node and one input-gate line; button placement (top-right) is implementer-tunable
  within "inside canvas, never under an existing hit area" — the click hit test is the proof.

## 8. 记录级欠账:UX-13 / UX-14(OPEN, record-only → `design/40_ux_backlog.md`)

- **UX-13** | OPEN | 角色页/装备 | `PlayerProfile` has no `equipped` field and no equipment
  system exists; the 12 equipment cards (`scripts/data/card_data.gd:36-48`) live only as
  inventory strings (write points: `scripts/data/event_logic.gd` item effects, cultivation
  card item effects), now visible via the roster panel but not equippable or battle-relevant
  | 玩家看得见抽到的装备,却装不上——「看见」本轮还账,「装上」欠着
- **UX-14** | OPEN | 角色页/战前 | `design/40_progression.md §9` promises 战前选装 (已学功法
  不限数量,战前选装) while `scripts/data/battle_setup.gd:94-96` auto-equips the top-2
  external arts by grade (3 with 左右互搏) — the promised player choice does not exist
  | 设计承诺的选择不存在;auto-equip 是既成行为,差距记档待后续独立一轮

## 9. 边缘情况(covered by code rules above)

Unknown/missing ids (raw-id degrade); empty sections (「（无）」); hostile gongfa rows
(`.get()` defaults, grade `""`); duplicate inventory ids (display is per-row, name pin does
not depend on count); re-sync after in-scene load (`SaveManager.loaded`); input ownership
while open; `spine_to_ending` timing (panel not a phase, never opened by the spine);
`tests/test_touch_option_surface_gate.gd` traversal (panel adds no phase; the always-visible
`RosterOpenButton` is additive visible+wired control in every choice phase); vision gate Q6
(autowrap inside a fixed box, existing theme/font, nothing overflows 960×704).

## 10. 技术栈

Godot 4.4 GDScript + Controls only (Control/Button/Panel/ColorRect/Label, existing
`global_theme.tres` + NotoSansSC); existing data resolvers; existing playtest sidecar
(`aitelier/tools/godot_playtest`) + pytest guards; **no new packages, no plugins, no art
assets, no theme changes, no camera/coord touches, no input-map changes.**

## 11. 不可逆操作与回滚

None. All changes are additive files plus small guarded edits; the only history file
(`design/99_changelog.md`) receives one appended row and NO rewrites (row :126 verified, not
edited). README count is plain prose and git-reversible. No schema migration, no data
rewrite, no save-format change (`save_load_roundtrip` untouched and must stay green).

## 12. 给 PM 的分解建议(顺序即依赖)

1. **T1 组件:** `scripts/ui/roster_panel.gd` + `scenes/ui/roster_panel.tscn` + i18n entries +
   `tests/test_roster_panel.gd` (registry). Accept: unit suite green; compose pure; degrade rules.
2. **T2 接入:** instance into both `.tscn`; one-line input gate in both `_unhandled_input`;
   observables live. Accept: compile clean; both scenes show the button; no host copy added.
3. **T3 契约:** `_common.yaml` surface blocks + scenario_order; two scenario files;
   `ROUND_SCENARIOS` append; facility-pin `_escape` extension. Accept:
   `test_playtest_contract_smoke.py` green (incl. new two-place sync).
4. **T4 钉子实测:** self-run both scenarios via sidecar; TEMPORARY RED-FIRST REVERT on
   `roster_panel.gd` open handler; paste the four measured values into the scenario header
   + delivery notes; restore byte-identical. Accept: both scenarios green with observed
   values pasted; red-first values measured not predicted.
5. **T5 文档与欠账:** README counts (measured), `99_changelog.md` (verify :126 + one new row),
   `40_ux_backlog.md` (UX-13/14 + 记录行), `90_decisions.md` (§7 rulings),
   `30_presentation.md` + `31_touch_coverage.md`. Accept: all five pytest guards green.
6. **T6 终验:** official full gate — all playtest scenarios PASS (73 → 75), hard gate
   `passed: true`, 0 runtime errors, compile 0 errors (predicted +2 `.gd` files; paste
   measured), `spine_to_ending` byte-untouched and green, vision gate non-blind and passed;
   record counts against predictions.

## 13. 非目标(unchanged from the brief)

No equipment system / `equipped` field / pre-battle loadout (recorded UX-13/14 only);
no numerical or balance tuning (read-only display); no new data fields, systems, or save
writes; no art assets; no regression into parallel `▶` UI (all four segments'
`cursor_markers_visible` stay `false`); the three frozen artifacts
(`_bad_timeline_at_values`, `test_facility_copy_location.py`, `card_data.gd::display_name_of`)
and the camera/coord layers are used, never modified.

## 14. 自检

- Covers every brief goal: panel (three sections, degradation) ✓; tappable open AND close ✓;
  single-surface + `cursor_markers_visible == false` ✓; read-only/no-save/no-turn ✓;
  STABLE_STATES entry ✓; real-path nail with measured red-first ✓; README counts ✓;
  99_changelog verified-not-rewritten + this round's row ✓; facility-pin failure message ✓;
  UX-13/14 record-only ✓; design/ five-file update set ✓.
- Components single-responsibility; the only host coupling is one input-gate line.
- Researcher's recommendations adopted verbatim (reuse-only; rejected alternatives —
  PopupPanel/Window, CanvasLayer, grab_focus, external themes — stay rejected).
- Interfaces concrete enough for PM to split by §12; no over-design (no tabs, no
  configuration, no caching layer).
- `linter_manifest.json` mirrors the repo's existing manifest (`.gd` deliberately excluded —
  it is checked by the `gdscript_check` gate, not the manifest).
