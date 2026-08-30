# 技术架构设计 — 人物栏 · 功法 · 物品 (round id: `jinyong-roster`, 2026-08-30)

**Input:** Project Brief + verbatim spec conversation, Step 1 SOTA report (review verdict: passed, no blocking issues), direct reads of the repo performed this step (every file:line below was read, not assumed).

**One-line shape:** one read-only `RosterPanel` Control (settings-panel pattern) instantiated into the two STABLE_STATES host scenes, opened/closed by a new `toggle_roster` key (C) owned entirely by the panel; one new static resolver `CardData.display_name_of(id)` beside the existing `def(id)`; one new playtest scenario pinning the item-name correspondence through a REAL event grant; three Python guard/tail fixes; two recorded debts; four design-doc updates. Zero new data fields, zero new systems, zero new values.

---

## 1. Overview

The player can never see what they already own: `PlayerProfile` carries `attrs` (根骨/内力/身法/悟性/福缘), `silver`, `traits`, `gongfa: Array[Dictionary]` (`{id, grade, practice, mastered}`), `inventory: Array[String]`, and `cultivation: {year, month, sect_id}` — but no UI reads any of it except the cultivation footer one-liner (`scripts/segments/cultivation.gd:790`). The 12 equipment cards are a dead road: written into `profile.inventory` by `scripts/data/event_logic.gd:45-48` and `scripts/segments/cultivation.gd` (card `"item"` effect) and read by nothing.

This round adds a **read-only character page** with three sections (人物 / 功法 / 物品), reachable in `CULTIVATION` and `MAP` (the two `STABLE_STATES`), open/close costing no turn, no action, and no state change. It also pays three recorded tails from the `jinyong-touch`/`jinyong-facility` rounds (README Q6 count, walkthrough pointer, `_bad_timeline_at_values` parser), converts the `facility_copy_location` gate from literal-allowlist to symbol exclusion, and records two verified debts.

**Hard constraints honored by construction (verified this step):**
- `PlayerProfile` is treated strictly as a read source. The panel writes nothing; `SaveManager` surface untouched (`save_load_roundtrip` 14/14 stays green by construction).
- No numeric tuning: no attribute/damage/price value changes anywhere.
- Playtest contract append-only: `surface` whitelist additions only; no frozen yaml edited; `spine_to_ending.yaml` byte-untouched (the panel key `C` never appears in any frozen action stream — verified against `playtest/_common.yaml` action list and `spine_to_ending`'s keyboard path).
- Click anchors: this round adds **zero** `clicks:` entries (keyboard-only scenario), so the 2026-08-29 `*_ClickTarget` ruling is not even exercised.
- Absolute-number rule: the new scenario's numeric asserts are `changed` / relational only; the only literals are **text correspondence pins** (`青锋剑`, `无`, hint copy) — which is the entire point of the nail.

---

## 2. 设计变更 (declared design-doc changes — for `5_design`)

This round legitimately **changes the design archive**; the changes are additive presentation + record corrections, no rule/system/value changes:

1. **ADD** — `design/30_presentation.md` gains a roster-panel section: panel content (three sections), entry (states, key, visible hint), zero-turn-cost guarantees, observables, lazy-fallback rule, empty-section `无` placeholder.
2. **ADD** — `design/40_ux_backlog.md` gains two OPEN record-only debts (UX-13 no `equipped` field / no equipment system; UX-14 §9 loadout promise vs `battle_setup.gd` auto-equip). Record only, per the brief.
3. **ADD** — `design/90_decisions.md` gains the round's rulings (§11 below) — including the tail-(c) resolution and the facility-copy-location gate conclusion.
4. **ADD** — `design/99_changelog.md` gains one `jinyong-roster` row (2026-08-30).
5. **CORRECT** — `README.md`'s stale Q6 claim ("two bad Q6 frames are parked as next-round review candidates") is corrected to the measured `bad_answers: 0` (71/71 good). This is a record correction, not a design change.
6. **POINT** — `final/delivery_notes_touch_reach_walkthrough.md` gains ONE pointer line at the top naming `final/delivery_notes_touch_reach_red_first.md` as the authoritative measured record (f265/8). The walkthrough's predicted f180/5 table is NOT rewritten (the prediction↔measurement gap is itself the record).
7. **NO CHANGE** to `design/10_systems.md`, `design/20_content.md`, `design/40_progression.md` — the panel displays existing data; no rule moves layers. The §9-vs-`battle_setup.gd` divergence stays a recorded debt (UX-14), not a design edit.

---

## 3. Architecture (component map and data flow)

```
                    ┌──────────────────────────── SaveManager.profile (READ-ONLY) ───────────────────────────┐
                    │  attrs · silver · traits · gongfa[{id,grade,practice,mastered}] · inventory · cultivation │
                    └───────┬───────────────────────┬───────────────────────┬─────────────────────────────────┘
                            │                       │                       │
              ProgressionGongfaData      TraitData.get_def       CardData.display_name_of(id)  ← C2 NEW static
              .display_name_of/.GRADE_STEP/.sect_def   (existing)      └─ wraps existing CardData.def(id), "" on unknown
                            │                       │                       │
                            ▼                       ▼                       ▼
   ┌────────────────────────────────── RosterPanel (C1, NEW) ──────────────────────────────────────┐
   │  scripts/ui/roster_panel.gd + scenes/ui/roster_panel.tscn                                     │
   │  _unhandled_input: toggle_roster opens/closes; while open EVERY key is set_input_as_handled   │
   │  _render(): composes person_text / gongfa_text / items_text → RosterLabel.text (tr() only)    │
   │  surface: visible · roster_open · person_text · gongfa_text · items_text ·                    │
   │           inventory_count · gongfa_count                                                      │
   └───────┬───────────────────────────────────────────────────────────────────────────────────────┘
           │ instantiated as LAST child of
   ┌───────┴──────────────┐   ┌──────────────────────┐
   │ cultivation.tscn (C3)│   │ map.tscn (C3)        │   each host scene also gains a RosterHint label
   │ + guard in .gd       │   │ + guard in .gd       │   "C 人物" (C5 i18n key; HintLabel byte-untouched)
   └───────┬──────────────┘   └──────────┬───────────┘
           │  GameManager.current_state == "CULTIVATION"/"MAP" gate (panel-side, primary)
           ▼
   project.godot [input]: toggle_roster = physical C (C4, NEW action)

   Playtest (C6/C7): playtest/roster_panel_shows_granted_item.yaml
     direct-boot map.tscn → travel 无名谷→洛阳 → REAL merchant option A grants eq_sword_3
     via EventLogic.apply_option_effects (the same path the game uses — no fake field write)
     → press toggle_roster → assert items_text contains 青锋剑 → close → segment state unchanged.
   Guards (C8/C9): tests/test_playtest_contract_smoke.py (registry + pins + parser hole),
     tests/test_facility_copy_location.py (symbol exclusion).
```

---

## 4. Component list

### C1 — `scripts/ui/roster_panel.gd` + `scenes/ui/roster_panel.tscn` (NEW)

- **Responsibility:** the entire toggle lifecycle, the read-only composition, and the publish surface. Clones the `settings_panel.gd` pattern (`scripts/ui/settings_panel.gd` read in full this step): `extends Control`, `_unhandled_input` gated on `GameManager.current_state`, `get_viewport().set_input_as_handled()` on every consumed key, `tr()`-composed `_render()`, no state emission, no HUD touch.
- **Scene tree:** root `Control` named `RosterPanel`, full-rect anchors, `visible = false`, **`mouse_filter = 2` (IGNORE) in the .tscn**, script attached. Children: `RosterBox` (Panel, centered ~560×560, opaque-ish panel style reusing `assets/themes/global_theme.tres` defaults — zero new art) and `RosterLabel` (Label inside the box, `autowrap_mode = 3`, `mouse_filter = 2`).
- **Mouse filter contract (risk-mitigating, required):** the .tscn default is `mouse_filter = 2` so the closed panel is click-through (the repo's static full-rect click-through guard and `clicks_only_storyline` 47/47 stay untouched). `_open_panel()` sets root `mouse_filter = MOUSE_FILTER_STOP` (modal: a stray click cannot travel/resolve through the open panel); `_close_panel()` restores `MOUSE_FILTER_IGNORE`. This mirrors the health-bar round's explicit-filter discipline.
- **Toggle logic (the whole keyboard contract lives here):**

  ```gdscript
  func _unhandled_input(event: InputEvent) -> void:
      if GameManager.current_state != "CULTIVATION" and GameManager.current_state != "MAP":
          return
      if event.is_action_pressed("toggle_roster"):
          get_viewport().set_input_as_handled()
          if visible:
              _close_panel()
          elif not _open_refused():
              _open_panel()
          return
      if visible:
          get_viewport().set_input_as_handled()   # swallow EVERYTHING else while open
  ```

  `_open_refused()` (C3 host contract, see below): on `MAP`, refuse when the host's `phase != "TRAVEL"` or host `ended == true` (never fight the EVENT/FACILITY modal key grammar — `map.gd:106-148` branches EVENT/FACILITY first and returns; the panel must never be open inside them). On `CULTIVATION`, never refuse (all cultivation phases are plain flow; the panel is read-only and closing restores the same phase).
- **`_open_panel()` / `_close_panel()`:** flip `visible`, set surface `roster_open`, flip root mouse_filter, call `_render()` on open. `_close_panel()` is unconditional and changes nothing else.
- **`_render()` (only entry points: `_open_panel()` and first `_ready()`):**
  - Reads **only** `SaveManager.profile` + the three data accessors (C2 and existing ones). Never writes to the profile, flags, or save. Never `push_error`s.
  - Person section (`person_text`): header reuses the existing i18n key `第 %d 年 · 第 %d 月    门派: %s\n` with the sect name via `ProgressionGongfaData.sect_def(sect_id).display_name` (empty sect → `tr("未定")`, the exact `_sect_display()` shape at `cultivation.gd:886-890`); one attrs+silver line reusing the existing key `银两 %d    根骨 %d 内力 %d 身法 %d 悟性 %d 福缘 %d\n`; a traits line `先天特质：%s\n` where each trait id resolves via `TraitData.get_def(id).display_name` and an unknown id degrades to the raw id (lazy fallback; `get_def` null-check, no crash). Empty traits → `无`.
  - Gongfa section (`gongfa_text`): header reuses `武功 %d 门 · 大成 %d\n` (counts from `profile.gongfa`). One row per entry, in profile order: `%s（%s · 练度 %d · %s）\n` with name = `ProgressionGongfaData.display_name_of(id)` (unknown id → render the raw id + stored grade/practice verbatim — never a blank row), grade = `row.grade` letter + `ProgressionGongfaData.GRADE_STEP[grade]` when the key exists (missing/empty grade → render the letter or omit gracefully), mastered → `已大成` / `未大成`. Empty section → single `无` line (placeholder, never blank — the SOTA edge case, pinned by the scenario).
  - Items section (`items_text`): header `【物品】%d 件\n` (count = `profile.inventory.size()`), then one line per id: `CardData.display_name_of(id)` + `"\n"`; resolver `""` (unknown id) → render the raw id verbatim (lazy fallback, no skip-that-silently, no crash). Empty → `无`.
  - Footer: `按 C 关闭`.
  - Sets `RosterLabel.text` to the full composition and the three section vars separately (the items pin targets `items_text` so `contains("青锋剑")` is precise).
- **`_process()` must NOT exist** in this script — zero per-frame cost; the spine's frame budget is untouched (`spine_to_endpoing` timing invariant).
- **Interface (published observables — exact names, they are the PM/impl contract):**
  `visible` (built-in), `roster_open: bool`, `person_text: String`, `gongfa_text: String`, `items_text: String`, `inventory_count: int`, `gongfa_count: int`. `RosterLabel` publishes `visible`, `text` (built-ins, same shape as every existing Label block).

### C2 — Inventory resolver: `CardData.display_name_of(id) -> String` (EDIT `scripts/data/card_data.gd`)

- **Responsibility:** the mandated id→display_name accessor, written beside the existing precedent.
  ```gdscript
  ## Display name for an inventory id; "" when unknown (caller degrades to the
  ## raw id — mirrors ProgressionGongfaData.display_name_of's "" contract).
  static func display_name_of(id: String) -> String:
      var d := def(id)
      return "" if d == null else d.display_name
  ```
- Note: `def(id)` also synthesizes trait-card defs; that is harmless here (an inventory id is an item id in practice; any id with a def renders its name, anything else renders raw). **No other card_data.gd change** — TABLE rows and `def(id)` are byte-untouched.
- Unit-pinned in C12 (known id `eq_sword_3` → `青锋剑`; unknown id → `""`).

### C3 — Host wiring: `scenes/segments/cultivation.tscn`, `scenes/segments/map.tscn`, `scripts/segments/cultivation.gd`, `scripts/segments/map.gd` (EDIT)

- **Scene edits (both hosts):** append as the **last** nodes (unhandled input is delivered in reverse tree order, so the panel sees keys before the segment root — same ordering the settings/menu panels rely on):
  1. `[node name="RosterPanel" parent="." instance=ExtResource("<roster_panel.tscn>")]` (last node);
  2. a new `RosterHint` Label (bottom band, right side of the existing `HintLabel` row — `map.tscn` HintLabel is a 400 px centered rect at offsets −200..+200 / −56..−16, so `RosterHint` anchors bottom-right with a clear margin; exact offsets are implementer's, constraint: **must not overlap `HintLabel`, `BodyLabel`, or any Button**, and `mouse_filter = 2`), `text = "C 人物"` (CJK tscn literal → needs its EN key, C5).
- **Script edits (both hosts) — the ONLY change is a defensive early-return, inserted without touching any existing handler line:**
  - `map.gd::_unhandled_input`: immediately after `if ended: return` (line ~107-108), insert `var _rp := get_node_or_null("RosterPanel") as Control` + `if _rp != null and _rp.visible: return`.
  - `cultivation.gd::_unhandled_input`: immediately after the `GameManager.current_state != "CULTIVATION"` early-return (line ~136-137), insert the same two lines.
  - **Justification + constraint:** the panel consumes input first (tree order), so this guard is belt-and-braces — but it is what makes "open panel blocks the segment keyboard" true even if node order ever changes, and it is machine-assertable. The brief forbids touching the just-landed facility files: the guard is a pure early-return placed **before** all branches; the EVENT/FACILITY/`use_facility`/`_travel`/`_cycle_focus` bodies stay byte-identical. Record this scoping in `90_decisions.md` ruling (c).
- **RosterHint visibility:** always visible in both hosts (it is the visible key hint the acceptance criterion demands). It is static chrome; no per-frame logic.

### C4 — Input action: `project.godot` (EDIT)

- Add to `[input]`:
  ```
  toggle_roster={
  "deadzone": 0.5,
  "events": [Object(InputEventKey,...,"physical_keycode":67,...)]
  }
  ```
  Physical **C (67)** — audited collision-free this step: the existing physical keys are W/A/S/D + arrows (move_*), 1–8/9–0/−/= (skill_1..12), J (attack_confirm), Escape (pause_game), Space (end_turn), Enter (tutorial_next), F (use_facility); harness debug actions have empty event lists. `ui_accept` is untouched.
- **No `actions:` list change is possible without the contract** — `toggle_roster` is appended to `playtest/_common.yaml`'s `actions:` list in C7 (append-only; the loader refuses unknown keys).

### C5 — i18n: `scripts/autoload/i18n.gd` (EDIT)

- Every new CJK string enters the EN dictionary in the same change (`tests/test_i18n_coverage.py` mechanically reddens otherwise: it scans `.tscn` `text =` CJK literals, `tr("<zh>")` call sites, and `.text = "<zh>"` assignments).
- **Grep first, then add only what is missing.** Already-present keys the panel reuses: `第 %d 年 · 第 %d 月    门派: %s\n`, `银两 %d    根骨 %d 内力 %d 身法 %d 悟性 %d 福缘 %d\n`, `武功 %d 门 · 大成 %d\n`, `根骨`/`内力`/`身法`/`悟性`/`福缘`, `未定`. Expected new keys (verify each against the current dict before adding):
  - `【物品】%d 件\n` → `[Items] %d held\n`
  - `先天特质：%s\n` → `Innate traits: %s\n`
  - `%s（%s · 练度 %d · %s）\n` → `%s (%s · practice %d · %s)\n` (gongfa row template)
  - `已大成` → `Mastered`; `未大成` → `In training`
  - `无` → `None` (placeholder; grep — may exist)
  - `按 C 关闭` → `C to close`
  - `C 人物` → `C Character` (the `RosterHint` tscn literal)
  - GRADE_STEP values `入门` / `精进` / `大成` / `圆满` if the panel renders them through `tr()` — add any missing EN values (`Entry` / `Proficient` / `Accomplished` / `Perfected`). Item/gongfa **names** are data constants and render raw (same as every existing name surface — not an i18n gap).
- RosterHint's tscn literal and all `tr()` call sites must pass `test_i18n_coverage.py` — run it before hand-off.

### C6 — Playtest scenario: `playtest/roster_panel_shows_granted_item.yaml` (NEW, 72nd)

The correspondence nail. Direct-boot (per-scene `scene:` override), keyboard-only, zero clicks. **The item is granted through the REAL event path** — `merchant` option A (洛阳) applies `silver + item eq_sword_3` via `EventLogic.apply_option_effects`, the same code the game uses; the scenario never writes a field. (`merchant` is deliberately the granting event: its option A has **no attr effect**, so it cannot perturb any `attr_*` differential pin, exactly the property §8.2b of `20_content.md` exploited for the shaolin timeline.)

```yaml
# One play-test scenario. The correspondence nail: a REAL event grant (merchant
# option A -> eq_sword_3) must be VISIBLE on the roster panel by its Chinese
# name. Asserting "the panel is non-empty" would stay green even if inventory
# were still a dead road; this asserts the exact granted item's name.
name: roster_panel_shows_granted_item
description: >-
  Direct-boot map.tscn, travel 无名谷→洛阳, resolve merchant option A (silver +
  item eq_sword_3 through the real EventLogic path), press toggle_roster (C) to
  open the panel, and pin the correspondence: items_text contains 青锋剑.
  Then close with the same key and pin that the segment is exactly where it
  was — same phase, same node, same counters (open/close consumes no turn).
  A fresh direct boot has no gongfa, so gongfa_text must render the 无
  placeholder (the empty-section edge case), and person_text must still carry
  the five attribute labels.
scene: res://scenes/segments/map.tscn
timeline:
- at: 30
  actions: []
  assert:
    MapScreen.phase: phase == "TRAVEL"
    MapScreen.event_id: event_id == ""
    RosterPanel.roster_open: roster_open == false
    RosterPanel.visible: visible == false
    RosterHint.visible: visible == true
- at: 40
  actions: [move_right]
- at: 50
  actions: [ui_accept]
- at: 60
  actions: []
  assert:
    MapScreen.phase: phase == "EVENT"
    MapScreen.event_id: event_id == "merchant"
    MapScreen.current_node_id: current_node_id == "luoyang"
- at: 70
  actions: [ui_accept]
- at: 80
  actions: []
  assert:
    MapScreen.phase: phase == "TRAVEL"
    MapScreen.event_id: event_id == ""
    MapScreen.events_resolved_count: events_resolved_count == 1
    MapScreen.silver: changed
- at: 90
  actions: [toggle_roster]
- at: 100
  actions: []
  assert:
    RosterPanel.roster_open: roster_open == true
    RosterPanel.visible: visible == true
    RosterPanel.items_text: 'items_text.contains("青锋剑") == true'
    RosterPanel.inventory_count: inventory_count >= 1
    RosterPanel.gongfa_text: 'gongfa_text.contains("无") == true'
    RosterPanel.person_text: 'person_text.contains("根骨") == true'
    RosterHint.text: 'text.contains("C") == true'
- at: 110
  actions: [toggle_roster]
- at: 120
  actions: []
  assert:
    RosterPanel.roster_open: roster_open == false
    RosterPanel.visible: visible == false
    MapScreen.phase: phase == "TRAVEL"
    MapScreen.event_id: event_id == ""
    MapScreen.current_node_id: current_node_id == "luoyang"
    MapScreen.events_resolved_count: events_resolved_count == 1
```

- Compliance notes: last assert ≤ 2999 ✓; every dotted assert line carries a comparison operator ✓; at least one `: changed` line (`MapScreen.silver`) ✓ (the smoke test's per-scenario differential requirement); numeric asserts are `changed`/relational, the only literals are text pins ✓; zero clicks → no anchor rulings involved ✓.
- **Fresh-boot assumption (stated, not assumed):** direct-boot map.tscn yields a fresh profile (no gongfa, empty inventory) — the same shape `facility_use_reusable` relies on when it asserts `facility_use_count == 0` at boot. If authoring-time measurement ever contradicts it, drop only the `无` pin (keep the correspondence nail) and record why in the delivery note.
- **RED-FIRST PROTOCOL (binding, mirrors the touch-reach round's measured recipe):**
  1. Land C1–C4 + C7 (panel exists, scenario + registry exist). Baseline green run of the scenario.
  2. Apply the TEMPORARY RED-FIRST REVERT: comment out the `RosterPanel` instance node in `scenes/segments/map.tscn` only, marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`.
  3. Run `godot_playtest_scenario(scenario="roster_panel_shows_granted_item")` (the external sidecar `aitelier/tools/godot_playtest/impl.py`). Capture the four measured values: failing frame / first failing assert (expected shape: the first `RosterPanel.*` key, error `node not found: RosterPanel`)/ exact error string / green asserts before red.
  4. Restore `map.tscn` byte-identically (verify by read-back), re-run green.
  5. Record the measured values in `final/delivery_notes_roster_panel.md` (with the verbatim repro recipe) and in the scenario header. **Values are measured, never predicted** — the design deliberately does not pre-write the numbers.
- **Visible walkthrough (acceptance criterion):** the same delivery note carries the screen-by-screen narration — open page in map → person section (five attributes, silver, traits, year/month/sect) → 功法 section (无 on a fresh boot; the row template itself is unit-pinned in C12) → 物品 section showing the drawn 青锋剑 → close with C → travel continues. Honest boundary: gate numbers belong to the downstream `5_compile` run and are not pre-written here.

### C7 — Contract registry: `playtest/_common.yaml` + `tests/test_playtest_contract_smoke.py` (EDIT, append-only)

- **`_common.yaml`:**
  - `actions:` — append `- toggle_roster` after `- debug_grant_silver` (append-only; nothing removed).
  - `surface:` — append two NEW blocks after the `Next:` block (append-only; no existing line touched):
    ```yaml
      RosterPanel:
      - visible
      - roster_open
      - person_text
      - gongfa_text
      - items_text
      - inventory_count
      - gongfa_count
      RosterLabel:
      - visible
      - text
      RosterHint:
      - visible
      - text
    ```
  - `scenario_order:` — append `- roster_panel_shows_granted_item` at the tail (after `map_facility_buttons_click`).
- **`tests/test_playtest_contract_smoke.py`:**
  1. `ROUND_SCENARIOS` (line 36–70): append `"roster_panel_shows_granted_item"` at the tail (two-place sync is machine-checked; also add the scenario to the round-registration structure that carries the per-scenario `expected_diff` entry used by the `: changed` check at ~line 915-921).
  2. NEW `test_roster_panel_surface_contract()` — mirrors the facility pin shape: the seven RosterPanel vars + RosterLabel/RosterHint blocks are whitelisted; `toggle_roster` is in the actions list; the scenario is in `scenario_order` AND `ROUND_SCENARIOS`; the file exists with `name:` equal to its basename; the file text contains a `toggle_roster` timeline entry (the panel must be opened by the real key action, not a handler call); **correspondence anti-deletion pin:** the file text must contain a line matching `items_text.contains("青锋剑")`, and the assert's FAILURE TEXT (not docstring-only, per the 2026-08-29 form-gate ruling) carries the escape clause: *"this is a form gate — if you legally renamed the observable or re-expressed the pin, update THIS pin together with the equivalent assert in the same change; never bypass a rename by weakening this pin, and never keep a dead old scenario line to stay green."*
  3. **Facility pin failure-text upgrade (brief item, exact):** in `test_facility_use_reusable_surface_contract()` (line 925+), the two verbatim requirements (`phase != "FACILITY"` and `facility_use_count == 0` present in the file text) get failure messages that carry the form-gate explanation: these are form gates; a future legal rename/rewrite of the observables must update this pin together with the equivalent assertions in the same change — red is right in that case; the fix is never to bypass the rename. Docstring stays as supporting prose; the escape clause must live in the assert messages.

### C8 — `_bad_timeline_at_values` → parse-based type gate: `tests/test_playtest_contract_smoke.py` (EDIT)

- **The property is structural, so the checker must parse, not regex.** The gate asserts "every timeline entry's `at` is an integer". Timeline entries are YAML structures, not text shapes; a line-level rule asserts a text shape. (Feedback round 1 replaced the previously designed line-level "shadowed-`at:`" rule; its rejection is recorded below so nobody re-derives it.)
- **Why ANY line-level rule is rejected:** a rule keyed on "`#` appears before `at:` on the line" cannot distinguish these two inputs — they are character-level identical to a line regex:

  | line | after `#`-strip | the rule says |
  |---|---|---|
  | `- {label: "a#b", at: 3}` (real hole: `#` inside quotes) | `- {label: "a` | red ✔ correct |
  | `  actions: [move_right]   # travel at: full speed` (legal trailing comment) | `  actions: [move_right]` | **red ✘ false red** |

  It swaps a silent miss for a false red on legal prose — a form gate that stays green only while nobody happens to write such a comment. Measured on today's tree: **2** lines in `playtest/*.yaml` carry an inline `#`; the rule would false-red **0** of them today — that is "hasn't collided yet", not "can distinguish". The 2026-08-29 form-gate rule (`design/30_presentation.md`: a gate a legal edit can red must self-explain or assert by property) forbids exactly this shape.
- **Measured feasibility (reviewer-verified 2026-08-30; adopted as given — do NOT re-verify):** pyyaml **6.0.3** is present in the container the gate runs in; all **72** `playtest/*.yaml` parse independently with `yaml.safe_load` (**0** failures, no `_common.yaml` merge needed); **1617** timeline entries, every `at` an int — the parse-based gate is green today. (The earlier line-grep counted 1620 `at:`-bearing lines vs 1617 real entries: line-level counting over-matches, which is precisely why the gate must walk the structure.)
- **Verified current shape (read this step):** `_bad_timeline_at_values(text: str, name: str) -> list[str]` at `tests/test_playtest_contract_smoke.py:407` — pure helper (no file I/O, no globals), docstring :408–430, body comment-strips each line (`line.split("#", 1)[0]`) then applies `\bat\s*:\s*([^,}\s]*)` + `isdigit()`. Sole caller: `test_timeline_at_values_are_integers` (:456–460) loops `ROUND_SCENARIOS`, `bad.extend(_bad_timeline_at_values(text, name))`, `assert not bad`. Two existing regressions: `test_timeline_at_real_non_integer_still_red` (probe `"- at: abc\n"` → len 1, message contains `probe.yaml line 1` and `'abc'`) and `test_timeline_at_comment_backtick_at_is_ignored` (probe `"#   ... and every `at:`\n- at: 3\n"` → `[]`; pins the exact historical false-red bug `clicks_only_storyline.yaml:99`, cf. `final/delivery_notes_fix_at_gate_strip_comments.md`). Six OTHER smoke checks re-implement the same line-regex+`isdigit()` walk per scenario (:537/:586/:638/:746/:806/:900/:982) — **out of scope this round**: the verdict targets the shared helper; migrating six more sites is a possible follow-up, not a requirement (their per-scenario line diagnostics stay untouched, so no diagnostic capability regresses).
- **New implementation — helper body + docstring replaced; signature, position, and the caller loop untouched:**

  ```python
  import yaml  # pyyaml 6.0.3 — present in the gate container (measured 2026-08-30)

  def _bad_timeline_at_values(text: str, name: str) -> list[str]:
      """Type gate: every timeline entry's 'at' must be an integer frame number.

      Parse-based (replaces the line-regex/comment-strip walker): comments
      vanish at parse, a '#' inside a quoted scalar is handled by the parser,
      and a file that fails to parse is REPORTED instead of silently
      unverifiable. Two rules, walked recursively over the whole document:
        A. every mapping that carries an 'at' key must carry an int
           (bool excluded) — also covers bare top-level entry lists and
           click/other frame entries;
        B. every element of any 'timeline' list must be a mapping with 'at'.
      """
      try:
          doc = yaml.safe_load(text)
      except yaml.YAMLError as exc:
          return [f"{name}.yaml: unparseable YAML — timeline 'at' values "
                  f"cannot be verified; parser said: {exc}"]
      bad: list[str] = []

      def _at_check(node: dict, path: str) -> None:
          v = node["at"]
          if isinstance(v, bool) or not isinstance(v, int):
              bad.append(f"{name}.yaml: 'at' value {v!r} at {path} must be an "
                         f"integer frame number (got {type(v).__name__})")

      def _walk(node: object, path: str) -> None:
          if isinstance(node, dict):
              if "at" in node:
                  _at_check(node, path)
              entries = node.get("timeline")
              if isinstance(entries, list):
                  for i, entry in enumerate(entries):
                      epath = f"{path}.timeline[{i}]"
                      if not isinstance(entry, dict):
                          bad.append(f"{name}.yaml: timeline entry {i} at "
                                     f"{epath} is not a mapping")
                      elif "at" not in entry:
                          bad.append(f"{name}.yaml: timeline entry {i} at "
                                     f"{epath} has no 'at'")
              for k, child in node.items():
                  _walk(child, f"{path}.{k}")
          elif isinstance(node, list):
              for i, child in enumerate(node):
                  _walk(child, f"{path}[{i}]")

      _walk(doc, "$")
      return bad
  ```

  Implementation notes the implementer must honor:
  - `yaml.safe_load` ONLY (never the unsafe `yaml.load`); per-file parse, no `_common.yaml` merge — matching the measured protocol. Add `import yaml` to the module import block (currently `Path`/`json`/`re` only).
  - **Bool exclusion is mandatory:** pyyaml loads `at: true` as Python `True`, and `isinstance(True, int)` is True — without the `not isinstance(v, bool)` guard the gate would accept a boolean frame number.
  - **This is a TYPE gate: `at: 0` is legal.** Positivity / upper-bound claims live in their own checks; do not add them here.
  - Failure strings must keep the two fragments the regressions pin: the file name (`{name}.yaml`) and the offending value's `repr` (`'abc'`). Line numbers are gone (the parse view has no lines) — the sibling per-scenario walkers keep theirs.
  - If the module header carries a stdlib-only remark, amend that one comment line: the single sanctioned third-party import is `yaml` (recorded in 90_decisions ruling (d)).
- **The two existing regressions are PRESERVED with their exact probe texts, re-expressed to the parse message shape (the sanctioned re-expression):**
  1. `test_timeline_at_real_non_integer_still_red` — probe `"- at: abc\n"` unchanged; assertions become `len(bad) == 1`, `"probe.yaml" in bad[0]`, `"'abc'" in bad[0]`. The `line 1` fragment is dropped (no line numbers in the parse view); the probe now lands via rule A on the bare top-level entry list.
  2. `test_timeline_at_comment_backtick_at_is_ignored` — probe and the `== []` assertion unchanged byte-for-byte; under the parser it is trivially true (comments vanish at parse) and is kept as the recorded history of the strip-comments bug.
- **New regressions (no loosening — pinned):**
  3. `test_timeline_at_type_rejections` — `at: '3'` (str), `at: 3.0` (float), `at: 3..15` (str), bare `at:` (None), `at: true` (bool) each yield exactly one failure; `at: 0` and `at: 30` each yield `[]`. (The old docstring already promised the first four fail — the parse gate keeps that promise by TYPE, more accurately than `isdigit()`, which also false-reds legal YAML ints like `at: +30` and mis-reads multi-line scalars.)
  4. `test_timeline_entry_without_at_is_reported` — a `timeline:` element without an `at` key reds (rule B: "every entry's `at` is an integer" fails when there is no `at`).
  5. `test_unparseable_yaml_is_reported` — a truncated doc (e.g. `timeline: [ {at: 3`) reds with the filename and a fragment of the parser's message — the previously silent skip becomes a red.
  6. Real-tree sweep unchanged: `test_timeline_at_values_are_integers` keeps looping `ROUND_SCENARIOS` and must stay green (72 files / 1617 entries per the measurement above).
- **Explicitly REJECTED (record in 90_decisions (d)):** (i) "aligning" the parser to the `f265/8 → 97.6%` prose in `final/delivery_notes_touch_reach_red_first.md` — that file is delivery-note prose, not the playtest contract; `_bad_timeline_at_values` never reads it and must not (the brief's tail-(c) literal wording rests on a false premise). (ii) the line-level shadow rule — see the table above. The brief's other exit (declare not-worth-fixing, keep status quo) is not taken: the parse path is measured feasible and green today.

### C9 — `tests/test_facility_copy_location.py`: literal allowlist → symbol exclusion (EDIT)

- **Verified current shape (read in full):** `ALLOWED` (lines 121–164) contains the 7 node display_names (≤3 CJK, below `PROSE_MIN_CJK = 4` — they can never hit), the 3 `ENDING_TIERS` tier titles, and the 3 multi-line tier texts. Ending copy is roadmap-scope content: any wording edit next round reddens the gate for an unrelated reason, and the "fix" would be hand-editing test string constants — the exact silent-sync failure shape the 2026-08-29 form-gate ruling names.
- **Fix — exclude by symbol, keep the guard (deletion is the fallback, not the choice):**
  1. Scanner gains two skip mechanisms in `_cjk_literals()`:
     - **field-symbol skip:** a line whose comment-stripped text matches `"display_name"\s*:` contributes no literals (this is exactly the `NODES[*].display_name` shape in `map_data.gd`; any future display_name field is covered by the same symbol).
     - **block-symbol skip:** a line matching `ENDING_TIERS\s*:?=` opens the block; all literals inside are skipped until the block closes (first subsequent line whose lstripped content starts with `]` or `}`).
  2. `ALLOWED` shrinks: **delete** the 7 node names, the 3 tier titles, the 3 tier texts (13 data-side entries); **keep** the 9-ish `map.gd` chrome/template entries (tr format strings + facility chrome) with a comment that they are UI templates and that a future round may symbolize them via tr() call-site detection.
  3. Re-derive the extraction-sanity floor with a fresh measurement (the data-side literals no longer count); pin the measured floor with a comment citing the number, never below 3.
  4. `test_no_prose_duplicated_from_data_modules` stays byte-identical in behavior (its cross-check reads the data modules, which the skips do not touch).
- Rationale for fixing rather than deleting: the guard's property ("no NEW inline prose position in the map files") still has value and now matches its stated intent; the conclusion is recorded in `90_decisions.md` ruling (f) either way, so the brief's "两种结论都接受,不接受的是沉默" is satisfied by an explicit adopted-fix record.

### C10 — Tail corrections (EDIT, record hygiene)

1. **README Q6 (tail a):** `README.md` ~lines 372-373 say "two bad Q6 frames are parked as next-round review candidates and do not flip the gate". The measured record (2026-08-30 correction row in `design/40_ux_backlog.md`, from the on-disk `vision_report.json`) is Q6 **good_answers 71 / bad_answers 0**, both named frames answered YES. Rewrite that clause to the measured 0/71 with a pointer to `vision_report.json` + the backlog correction row; keep the rest of the bullet byte-identical. Grep `parked as next-round` / `bad Q6` across `README.md` and `final/*.md` — `final/verify_report.json` is a `superseded_pointer_note` tombstone with no Q6 text (verified), so README is expected to be the only live site; correct any other live repetition found. Do NOT edit the historical backlog rows (the correction row already exists there).
2. **Walkthrough pointer (tail b):** insert ONE bold pointer line directly under the title of `final/delivery_notes_touch_reach_walkthrough.md`:
   > **权威首红值在 `final/delivery_notes_touch_reach_red_first.md`(实测):f265 / 首断 `ContinueButton.visible` / 确切错误 `aim: node not found: ContinueButton` / 红前绿 8。下表的 f180/5 是当时的结构预测,原样保留——预测与实测的差本身是记录,不得当实测引用。**
   Do not rewrite the table values (brief-explicit).

### C11 — Design docs (EDIT)

- `design/30_presentation.md` — new section 「人物栏 · 功法 · 物品(roster panel)」: the three sections' content sources, entry (`STABLE_STATES` CULTIVATION/MAP, key C, `RosterHint`), the zero-turn-cost guarantees (panel-owned toggle, swallow-while-open, defensive host guard, no `_process`), the lazy-fallback rules (unknown item/gongfa/trait id → raw id; empty section → `无`), observables list, and the doc pointer that UX-13/14 carry the equipment absence.
- `design/40_ux_backlog.md` — two new OPEN record-only rows in the queue table + one dated 记录 row:
  - **UX-13** | OPEN — 本轮只记录(.record-only) | 装备/物品 | `PlayerProfile` 没有 `equipped` 字段,装备系统不存在:12 张装备卡(`eq_sword_1..4`/`eq_armor_1..4`/`eq_boots_1..4`,见 `card_data.gd` TABLE)只是 `inventory` 里的字符串;本轮人物栏把它们显示为中文名,但「装备」这个动作不存在 | 玩家看得到铁剑/软猬甲,却永远穿不上也卸不下;装备位、属性加成、战前换装全部缺失。
  - **UX-14** | OPEN — 本轮只记录 | 战前准备 | `design/40_progression.md` §9 承诺「已学功法不限数量,战前选装」,而 `scripts/data/battle_setup.gd:91-96` 按品级自动装前 2 门外部功法(有左右互搏则 3 门):设计承诺的玩家选择不存在 | 玩家不能自己决定带哪几门功法上阵;自动选择可能与玩家的养成方向相悖。
  - 记录 row: 2026-08-30 `jinyong-roster`(记录;不改任何既有 OPEN/CLOSED 状态;两条为 brief 点名的已查实欠账,实现各需自己的一轮,按规矩 2 关闭)。
- `design/90_decisions.md` — the round's rulings (§11 below, verbatim substance).
- `design/99_changelog.md` — one append-only row:
  `| jinyong-roster | 2026-08-30 | 新增只读角色页(人物/功法/物品三段,`toggle_roster` 键 C,养成与大地图可达,开合不耗回合不写存档);新增 `CardData.display_name_of` 惰性解析器;新场景 `roster_panel_shows_granted_item` 钉「事件给予的青锋剑出现在面板」;`facility_copy_location` 闸门改按符号排除(ENDING_TIERS 块与 NODES[*].display_name),删 7 个永不命中的节点名;`_bad_timeline_at_values` 改为 YAML 解析式类型闸门(timeline 条目 `at` 必须为整数;'3'/3.0/空值/布尔均红;解析失败即红,不再静默跳过);README Q6 勘误为实测 0;walkthrough 顶部加权威首红指针;UX-13/14 两条欠账入册。 | 玩家三年养成、抽卡、触发事件之后,第一次能看见自己是谁、会什么、有什么;装备死路(inventory 只写不读)由面板首次接通为可见——「data-only this round」的欠账本轮还掉显示的那一半。 |`

### C12 — Unit test: `tests/test_roster_panel.gd` (NEW) + registry (EDIT `tests/unit_test_runner.gd`)

- Registered in `tests/unit_test_runner.gd`'s `TESTS` const (line 22, alphabetical insert). Pins, all data-level and engine-free:
  1. Resolver: `CardData.display_name_of("eq_sword_3") == "青锋剑"`; `display_name_of("no_such_id") == ""`.
  2. Gongfa row rendering: a synthetic profile row `{id: "shaolin_yijin_d", grade: "D", practice: 2, mastered: false}` composes a line containing the art name, the D/入门 step, practice 2, `未大成`; `mastered: true` → `已大成`.
  3. Lazy fallbacks: unknown gongfa id renders the raw id + stored grade/practice (never blank, never crash); unknown item id renders the raw id; unknown trait id renders the raw id; empty inventory/gongfa/traits render `无`.
  4. Read-only: run the composition against a profile, snapshot `to_dict()`, re-run, assert the snapshot is byte-equal (the panel never mutates the profile).
- **`90_decisions.md` 2026-08-29 rule:** after adding any `tests/*.gd`, run a standalone parse check before hand-off (a parse error reds the project-wide check and blinds the whole playtest gate — the recorded lesson).

---

## 5. Interface specifications (the PM/implementer contract)

1. **Keyboard contract:** `toggle_roster` (physical C) is consumed ONLY by `RosterPanel._unhandled_input`. While the panel is closed, the key reaches nothing else (no segment branch references it). While open, every unhandled key is consumed by the panel and the host `_unhandled_input` returns at its guard — no month advances, no travel, no facility use, no event resolution. Open/close never calls `SaveManager` and never writes any profile field.
2. **Phase contract (MAP):** open refused unless `phase == "TRAVEL" and not ended`. Panel cannot be open inside EVENT/FACILITY (it can only be opened from TRAVEL, and while open nothing can change the phase).
3. **Surface contract (whitelist, exact names):** as listed in C7. `test_whitelisted_observables_exist_in_scripts` requires each whitelisted var to exist on the named node's script — `RosterPanel.gd` must declare `roster_open/person_text/gongfa_text/items_text/inventory_count/gongfa_count` verbatim; `visible`/`text` are built-ins (precedent: every Label block).
4. **Resolver contract:** `CardData.display_name_of(id) -> String`, `""` on unknown — same lazy shape as `ProgressionGongfaData.display_name_of`. Caller (panel) degrades to the raw id. No `push_error` on any lookup path.
5. **i18n contract:** every new CJK literal (tscn `text =`, `tr()` argument, `.text =` assignment) has an EN dictionary entry in the same change; `test_i18n_coverage.py` green.
6. **Ordering constraint:** land C1–C3 (scripts publish vars) BEFORE C7's whitelist rows land in the delivered tree, or `test_whitelisted_observables_exist_in_scripts` A-class reds (documented, expected-when-out-of-order — the red_first note's warning). The task order in §8 encodes this.

---

## 6. Technical stack (unchanged)

- Godot 4.4 / GDScript; Control + Label + Panel from `assets/themes/global_theme.tres`; no new assets, no plugins, no addons, no package manager.
- Python stdlib pytest for the three guard edits (no PyYAML, no subprocess — the smoke test's own constraint).
- Linter manifest unchanged: `.py` → `ruff`; `.yaml`/`.md`/`.json` → `basic`; `.gd` deliberately absent (host-controlled `gdscript_check`); scenes have no linter entry.

---

## 7. Invariants & risk register

| Risk | Mitigation designed in |
|---|---|
| Unhandled-input tree-order assumption (panel before segment) | Panel is the LAST child of both host scenes; PLUS the defensive early-return guard in both segment scripts (C3); PLUS scenario f120 asserts the segment state is exactly restored |
| Open panel lets a click travel/resolve through the map | Root mouse_filter flips IGNORE (tscn default, closed) ↔ STOP (open); swallow-while-open covers keys |
| Full-rect static click-through guard / `clicks_only_storyline` | tscn carries `mouse_filter = 2`; the STOP state exists only at runtime while open — a closed panel is byte-level click-through |
| Verbatim text pins break (`HintLabel` pinned by `map_node_event_mainline_return` f30; `map_hint_single` one-hint invariant) | The key hint is a NEW `RosterHint` node; `HintLabel.text` and map.gd's hint logic are byte-untouched |
| EN-locale gate renders English → CJK verbatim pins red | Existing verbatim zh text pins (HintLabel) are green in the official gate (zh fallback), so the hint pin is the same class; if the vision/locale layer ever changes, the failure message on the hint pin points at the i18n key (form-gate escape clause pattern) |
| i18n checker red on new literals | C5's grep-first list + same-change EN entries; run `test_i18n_coverage.py` before hand-off |
| Whitelist published before scripts (A-class red) | Task order in §8; the smoke test's existence check is the enforcement |
| New `tests/*.gd` parse error blinds the gate | C12 note: standalone parse check before hand-off (recorded 2026-08-29 rule) |
| Frozen scenarios / camera layer / facility files | Explicit DO-NOT-TOUCH list: `spine_to_ending.yaml` and every existing yaml byte-untouched; `scripts/camera_follower.gd`, `scripts/coord.gd`, both camera/coord yamls untouched; `map_data.gd`, `facility_data.gd`, `event_data.gd` untouched; in `map.gd`/`cultivation.gd` ONLY the two guard lines are inserted |
| Scenario flakiness from stray `user://` state | Fresh direct-boot profile is the same assumption `facility_use_reusable` already makes; documented fallback: drop only the `无` pin, never the correspondence nail |

---

## 8. Task decomposition proposal (ordered; PM may split further)

1. **T2 resolver + unit** — C2 (`card_data.gd::display_name_of`) + C12 (`tests/test_roster_panel.gd` + registry). Small, independent, green-by-itself.
2. **T3 panel + hosts** — C1 (`roster_panel.gd`/`.tscn`), C3 (two tscn instantiations + RosterHint + two guard insertions), C4 (`project.godot`), C5 (i18n keys). Panel runs, key works in both segments.
3. **T1 contract** — C6 (scenario yaml) + C7 (`_common.yaml` appends + smoke-test registry/pins). After T3 so the whitelist never outruns the scripts.
4. **T4 red-first measured + green** — C6's protocol; write `final/delivery_notes_roster_panel.md` (measured red values + repro recipe + restore proof + visible walkthrough).
5. **T5 static guards** — C8 (parser hole + regression) and C9 (symbol exclusion). Pure Python; no runtime effect.
6. **T6 tails** — C10 (README Q6 correction; walkthrough pointer line).
7. **T7 docs** — C11 (four design docs).
8. **T8 final sweep** — run `test_i18n_coverage.py`, `test_playtest_contract_smoke.py`, `test_facility_copy_location.py`; standalone parse check; confirm `spine_to_ending.yaml` byte-identity; grep the `TEMPORARY RED-FIRST REVERT` marker count is 0.

Binding order constraints: T2 ≤ T3 (panel uses the resolver); T3 < T1 (whitelist after scripts); T1 < T4 (scenario must exist to be measured); everything < T8.

---

## 9. Extensibility (deliberate, not speculative)

- The section composition is three independent builders (`_person_text()` / `_gongfa_text()` / `_items_text()`) over one read-only profile snapshot — a future companion section (schema already reserved) is one more builder, not a new panel.
- `CardData.display_name_of` is the general item-name accessor; the future equipment round (UX-13) reuses it for loadout UI unchanged.
- `RosterPanel`'s open-refusal rule is a single predicate; if a third stable segment ever appears, it is one condition.
- No abstraction is added for hypothetical panel frameworks — the settings-panel clone is the ceiling of investment this round.

---

## 10. Rejected alternatives (for the record)

- **New GameManager state `ROSTER`:** breaks `STABLE_STATES`/save-guard logic and the six-segment machine for a display feature — rejected (SOTA concurs).
- **Autoload CanvasLayer overlay:** works, but hosts the panel outside both host scenes, weakening the state-gate locality and the scene-level observability; the per-scene instance matches the settings/menu precedent — rejected.
- **Reusing/ extending `HintLabel` or the map body text for the key hint:** both are pinned verbatim or invariant-pinned (`map_hint_single`); rejected in favor of a new `RosterHint`.
- **Deleting `test_facility_copy_location.py`:** allowed by the brief as a fallback, but the symbol-exclusion fix is small and keeps the guard's property; deletion recorded only as the fallback if the block parser proves brittle during implementation (record either way in `90_decisions.md`).
- **A second playtest scenario for the gongfa rows:** no existing deterministic grant path reaches a fresh profile's gongfa array outside the full spine (boot-flow scenario = frame-budget rewrite of frozen territory); the row template is unit-pinned (C12) instead, and the empty-section placeholder is pinned in the main scenario — rejected as a scenario, delivered as a unit pin.
- **Aligning `_bad_timeline_at_values` to the `f265/8 →` delivery-note prose:** rejected (C8) — the parser reads the playtest contract, not prose notes.
- **A line-level "shadowed-`at:`" rule in `_bad_timeline_at_values` (stripped line yields no `at:` match + raw line matches ⇒ red):** rejected (feedback round 1) — "`#` inside quotes" (the real hole it aimed at) and "a legal trailing comment containing `at:`" are character-level identical to a line regex, so the rule swaps a silent miss for a false red on prose: a form gate by the 2026-08-29 rule. Superseded by C8's parse-based type gate.

---

## 11. Decisions requiring `design/90_decisions.md` entries (with rationale)

- **(a) Toggle key = physical C, action `toggle_roster`.** Collision audit against `project.godot [input]` (all used physical keys enumerated); C is mnemonic (人物/Character); harness debug actions have empty event lists so no scenario can mis-fire it.
- **(b) MAP open only from TRAVEL (refuse EVENT/FACILITY/ended); CULTIVATION any phase.** The map's modal phases own their key grammar (`map.gd:109-133`); a panel open inside them would either fight the grammar or force per-phase swallow tables. Cultivation phases are plain flow and the panel is read-only.
- **(c) Panel owns the toggle; hosts get a 2-line defensive early-return; zero save writes.** Scoping note: the guard inserts before all branches in `map.gd`/`cultivation.gd`; facility/EVENT handler bodies stay byte-identical (the "don't touch just-landed facility files" constraint is honored in spirit and letter — no facility logic line changes).
- **(d) Tail-(c) resolution: the gate goes parse-based; BOTH the `f265/8 →` prose alignment AND the line-level shadow detection are rejected.** The gate's property is structural — "every timeline entry's `at` is an integer" — so `_bad_timeline_at_values(text, name)` (signature, position, caller loop and both regression probes preserved; failure-message shape re-expressed) now `yaml.safe_load`s each file and type-checks recursively: every mapping carrying an `at` must carry an int (bools excluded), every `timeline` element must be a mapping with an `at`; `'3'` / `3.0` / `3..15` / null stay red; an entry without `at` reds; an unparseable file reds with filename + parser message (previously a silent skip). Feasibility measured and adopted as given: pyyaml 6.0.3 in the gate container, 72/72 `playtest/*.yaml` parse clean, 1617 entries all-int → green today; this one `import yaml` supersedes the module's stdlib-only habit. Rejected (i): aligning the parser to the `f265/8 → 97.6%` prose in `final/delivery_notes_touch_reach_red_first.md` — delivery-note prose is not the playtest contract and the helper never reads it. Rejected (ii): the line-level "shadowed-`at:`" rule — `- {label: "a#b", at: 3}` (real hole: `#` inside quotes) and `actions: [move_right]   # travel at: full speed` (legal trailing comment) are character-level identical to a line regex, so the rule trades a silent miss for a false red on prose; measured: 2 inline-`#` lines in `playtest/*.yaml`, 0 false reds today — fragility, not correctness, and the 2026-08-29 form-gate rule forbids it. The brief's other exit (not-worth-fixing + keep status quo) not taken: the parse path is measured feasible. The six per-scenario line-regex walkers elsewhere in the smoke test (:537/:586/:638/:746/:806/:900/:982) are out of scope this round.
- **(e) Key hint lives in a new `RosterHint` node in both host scenes.** `HintLabel.text` is pinned verbatim (`map_node_event_mainline_return` f30) and `map_hint_single` pins the one-hint invariant; the hint must not ride either.
- **(f) `facility_copy_location` gate: symbol exclusion ADOPTED (not deleted).** The guard keeps asserting its property (no new inline prose positions) without pinning roadmap-scope content forms; the 7 node names are dropped (sub-threshold dead weight). If implementation proves the block parser brittle, the documented fallback is guard deletion with this same ruling noting §433 as an unguarded documentation rule.

---

## 12. Acceptance-criteria mapping

| Brief criterion | Where |
|---|---|
| Open in cultivation or map; see five attrs, silver, traits, learned gongfa (grade+practice+mastery), items in Chinese; close back with unchanged state | C1 + C3 + C4; pinned by C6 f100/f120 |
| New playtest scenario green, pinning the correspondence (known item granted by event → appears in panel); pre-green red value recorded in the report | C6 (scenario + measured red-first protocol) + C10's delivery note `final/delivery_notes_roster_panel.md` |
| Resolver with lazy fallback following `def(id)` precedent | C2 + C12 pins |
| `facility_copy_location` symbol exclusion (or deletion, recorded) | C9 + ruling (f) |
| Three jinyong-touch tails (Q6 measured 0; walkthrough pointer; parser alignment) | C8 + C10 (with the C8 caveat: the tail's literal instruction rests on a false premise; the verified defect is fixed and the rejection recorded) |
| Two debts recorded in `design/40_ux_backlog.md` | C11 (UX-13/UX-14, record-only) |
| Docs: 30_presentation content+entry; 40_ux_backlog debts; 99_changelog row; 90_decisions rulings | C11 |
| `spine_to_ending` untouched and green; no frozen yaml edited; surface whitelist append-only | C7 (additions only) + §7 invariants |
| i18n coverage + contract smoke green; compile 0 errors; unit suite green | C5/C7/C8/C9/C12 + T8 sweep |
| Visible walkthrough: open page → see learned gongfa and the drawn 青锋剑 → close and continue | C6 delivery-note walkthrough section |
