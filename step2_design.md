# Technical Architecture Design - Battle HUD Information Presentation (jinyong-hud)

Round scope: close **UX-03 / UX-04 / UX-05** on the battle HUD. Presentation-only:
no combat rule changes, no value changes, no art assets, no geometry-constant edits
to `health_bar.*`. Roadmap position: stage 2 (interaction) - "the player can read it,
click it, and know what to press next".

Everything below reuses the in-repo patterns surfaced by `step1_sota.md`:
the skill-button state machine (`state_palette` / `state_luma_value` /
`_apply_state`), the HUD per-frame derivation (`_refresh_skill_button_states`),
the append-only playtest contract (`playtest/_common.yaml` + one-file-per-scenario
+ `ROUND_SCENARIOS` two-place sync), and the probe-notes / backlog-closure doc
discipline. No new frameworks, no new dependencies.

---

## 1. Overview / Architecture Diagram

```
DATA LAYER (read-only sources; NO value changes)
  scripts/data/skill_data.gd        + @export var cost: int = 0   (schema only)
  scripts/battlefield.gd            existing _skill() descriptions (Chinese, authoritative)
  scripts/characters/player.gd      energy (display only, 180)
  CombatManager.tutorial_battle / current_round   (existing phase-lock predicate)
  design/20_content.md              unlock condition: round 4 opens 黯然销魂掌

DERIVATION LAYER (scripts/ui/hud.gd - _refresh_skill_button_states, every frame)
  phase_locked > cooldown > hp_gated > no_energy(NEW) > ready   -> waiting override (unchanged)
  + lock_reason_text  ("" unless the SAME phase-lock predicate fires)
  + no_energy         (cost > 0 AND player.energy < cost - never true with current data)

RENDER LAYER (scripts/ui/skill_button.gd + scenes/ui/skill_button.tscn)
  state_palette() += "no_energy" entry (luma 0.6629, pairwise >= 0.10 from all 5 states)
  + CostLabel   (NEW node, top band)  <- cost_text
  + InfoLabel   (NEW node, bottom-right) <- lock_reason_text OR effect summary
  + effect_text observable (= skill.description; also the tooltip)

HEALTH BAR (scripts/ui/health_bar.gd + scenes/ui/health_bar.tscn - FROZEN GEOMETRY)
  + HpLabel (NEW Label, child of Bar, full-rect anchors, mouse_filter 2)
  + hp_text / hp_value / hp_max observables, written in update_health()
  NO existing constant touched (68x24 widget, Bar 64x12 @(2,12), EMPTY_CAP_PX,
  expand margins, STRIP_BOTTOM all byte-identical)

CONTRACT LAYER (playtest + smoke + unit)
  playtest/_common.yaml          surface += 4 vars x SkillButton1..12, +3 vars HealthBar
  playtest/<3 new scenario>.yaml one per UX item (name == basename, int at:, operator asserts)
  tests/test_playtest_contract_smoke.py  ROUND_SCENARIOS += 3, +1 additive test function
  tests/test_skill_button_info.gd (NEW)  palette separation + label formatters (headless)
  tests/test_health_bar_text.gd  (NEW)  hp_text format + pinned geometry unchanged

DOC / EVIDENCE LAYER
  design/40_ux_backlog.md        UX-03/04/05 -> CLOSED(jinyong-hud) + evidence paths
  design/20_content.md           new section: inner-force cost content gap (recorded, not invented)
  design/30_presentation.md      new label rows (append)
  design/99_changelog.md         jinyong-hud row
  final/hud_info_probe_notes.md  (NEW) pre-fix probe evidence
  final/delivery_notes.md        names the missing-cost gap
```

Data flow is strictly one-way: data -> HUD derivation -> button/bar render ->
playtest observables. Nothing in this round writes game state.

---

## 2. Component List

### 2.1 `scripts/data/skill_data.gd` - additive cost field (schema only)

- **Responsibility**: carry a per-skill inner-force cost so the button can render it.
- **Interface**: ONE new line, `@export var cost: int = 0` (0 = "no cost defined").
- **Hard constraint honored**: `design/10_systems.md §1` states the pool "stores but
  does not spend" and NO technique defines a cost. Therefore the default 0 is the
  only value shipped; `battlefield.gd` `_skill()` call sites are **NOT** modified
  (no invented numbers). The gap is recorded in `design/20_content.md` §5 (2.10)
  and named in the delivery notes.
- `progression_gongfa_data.gd` techniques keep cost 0 (default) - same rule.

### 2.2 `scripts/ui/hud.gd` - derivation extension (UX-03/04 state + reason)

All changes live inside the existing per-frame `_refresh_skill_button_states(player)`
(the single derivation site). The existing priority chain, `disabled` semantics and
the `waiting` override stay byte-identical for current data.

- **no_energy derivation** (inserted after `hp_gated`, before `ready`):
  `cost = int(btn._skill_data.cost)` (0 when skill data missing);
  `no_energy = cost > 0 and "energy" in player and int(player.energy) < cost`.
  With current data (all costs 0, energy 180) this is always false -> every existing
  `state_text` / `state_tag_text` / `state_luma` assert fires unchanged.
  `disabled` becomes `phase_locked or on_cooldown or hp_gated or no_energy`
  (presentation machinery; the engine's own use-gate is untouched - player.gd never
  checks energy this round, and we do not add a check).
- **lock_reason derivation** (UX-04), from the SAME predicate that phase-locks:
  `phase_locked = CombatManager.tutorial_battle and i >= 4 and CombatManager.current_round < 4`
  -> when true: `btn.lock_reason_text = "第 4 轮解锁"` (unlock condition source:
  `design/20_content.md §1` - round 4 opens 黯然销魂掌); when false: `""`.
  Never a hardcoded always-on string: encounter battles and rounds >= 4 render "".
- **Per-frame observable writes** (guarded with `if "var" in btn`, same as hp_gated):
  `btn.cost_text` is written once in `skill_button.setup()` (static per battle) -
  the HUD does NOT rewrite it. `lock_reason_text` IS rewritten every frame (it flips
  at round 4 without a re-setup).

### 2.3 `scripts/ui/skill_button.gd` - render + observables

- **New state palette entry** (constraint 3: visually distinct from 锁定):
  `"no_energy"`: bg `Color(0.72, 0.62, 0.92)` (light purple), border
  `Color(0.45, 0.35, 0.75)` width 2, tag `"内力不足"`.
  bg luma (raw BT.709, `Color.get_luminance()`) = **0.6629**. Pairwise distances:
  vs phase_locked 0.5306 -> 0.1323; vs ready 0.3874 -> 0.2755; vs hp_gated 0.2020
  -> 0.4609; vs waiting 0.1558 -> 0.5071; vs cooldown 0.0814 -> 0.5815.
  **All >= 0.10** - the documented luma-spread contract holds for all six states.
  (0.6629 is the only viable band: every luma below 0.6306 collides with an
  existing state's +/-0.10 window; the computation is pinned in the unit test.)
  Goes through the EXISTING `state_palette()` / `state_luma_value()` /
  `_apply_state()` machinery - no fork.
- **New observables** (all declared here, values written by setup()/HUD as noted):
  - `cost_text: String` - rendered cost line. Written in `setup()` from
    `skill.cost` via the new static formatter (below). Chinese-only.
  - `effect_text: String` - the skill's full Chinese description
    (`skill.description`); "" for placeholder/empty skills. Written in `setup()`.
    Also surfaced as `tooltip_text` (hover = read the effect without selecting).
  - `effect_summary_text: String` - short on-face summary derived ONLY from
    existing SkillData numbers by the new static `effect_summary()` (below).
  - `lock_reason_text: String` - "" or the unlock condition; written every frame
    by the HUD (2.2). Rendered by InfoLabel (2.4) only while phase-locked.
- **New pure static functions** (unit-testable headless, no scene):
  - `cost_label_text(cost: int) -> String`: `0 -> "无消耗"`, `n > 0 -> "内力 " + str(n)`.
  - `effect_summary(skill) -> String`: reads `damage / heal_amount / aoe_shape /
    aoe_size / jump_tiles / dot_damage` and renders a <= 6-CJK-char line, e.g.
    `"单体 45"`, `"十字 34"`, `"跳3 · 20"`, `"回复 35"`. Numbers come verbatim
    from SkillData (presentation of existing values, never new values).
    Empty skill -> `""` (graceful undefined case).
  - `hp_label_text(...)` lives in health_bar.gd (2.6), not here.
- **Render wiring**: `_apply_state()` unchanged except it already renders any
  palette state generically (no_energy needs zero _apply_state edits - the tag,
  stylebox and luma all flow from `state_palette`). The two new labels are driven
  from `setup()` (cost/effect) and a small `_refresh_info_label()` called at the
  end of `_apply_state()` (info line = `lock_reason_text` when non-empty, else
  `effect_summary_text`), so the info line flips in the same frame the lock flips.

### 2.4 `scenes/ui/skill_button.tscn` - two additive labels

Button stays 104x48; HotkeyLabel / StateTag / CooldownLabel / CooldownOverlay /
SelectedMarker / FahuiLabel **node names, paths and the Button's own text pipeline
are unchanged**. Only FahuiLabel's *rect* is narrowed (nothing pins it: the pinned
geometry is the Button size and `skill8_right_edge`; the no-ellipsis asserts read
the `text` vars, not label rects). Probe-first fallback below.

| Node | rect (x1,y1)-(x2,y2) | font | align | notes |
|---|---|---|---|---|
| `CostLabel` (NEW) | (26,2)-(62,14) | 9 | center | top band, between HotkeyLabel (ends 24) and StateTag text (~starts 72); `clip_text=false`, `text_overrun_behavior=0`, `mouse_filter=2` |
| `InfoLabel` (NEW) | (56,34)-(102,46) | 8 | right | bottom-right; shows lock reason while locked, else effect summary |
| `FahuiLabel` (rect narrowed only) | (0,34)-(56,46) | 10 (unchanged) | center | text "发挥 ×1.3" ≈ 50px fits the 56px half |

- Discipline: **never** re-widen either new label into HotkeyLabel / StateTag /
  CooldownLabel rects; if a frame probe (see 6) shows ink overlap, shorten the
  summary (effect_summary cap) or drop InfoLabel font to 8 - never an ellipsis
  (no-ellipsis rule, `design/30_presentation.md`).
- `fahui_text` format and the `SkillButtonN.fahui_text` surface var are
  byte-identical ("发挥 ×N.N").

### 2.5 `scripts/ui/hud.gd` - energy already visible (no work)

`EnergyLabel` already renders "内力: 180" in the top strip - the "how much inner
force is left" half of UX-03 is satisfied by the existing label; the round only
adds the per-button cost. No change.

### 2.6 `scripts/ui/health_bar.gd` + `scenes/ui/health_bar.tscn` - HP numbers (UX-05)

**Frozen geometry honored**: 68x24 widget, Bar 64x12 @(2,12), NameLabel 9px,
`EMPTY_CAP_PX`, expand margins, `STRIP_BOTTOM`, hover offset - all untouched.
`tests/test_health_bar.gd`'s pinned values (`size==(68,24)`, `bar_width==64`,
`bar_height==12`, `empty_area_px==168`...) are never edited; new assertions are
ADDITIVE (new test file 2.9, plus optionally appended cases - pinned lines
byte-identical).

- **New node**: `HpLabel` (Label) as a **child of `Bar`** (EmptyCap precedent),
  anchors full-rect `(0,0)-(64,12)`, centered, font 9, `clip_text=false`,
  `text_overrun_behavior=0`, `mouse_filter=2`, drawn as Bar's LAST child so it
  paints above the fill and the EmptyCap. "500/500" at font 9 ≈ 40px < 64px.
  Text color light with dark outline (same recipe as NameLabel) so it reads on
  both green fill and dark track.
- **New observables** on health_bar.gd:
  - `hp_text: String` - `str(current) + "/" + str(max_hp)`; initialized in
    `setup()` (max/max) so the headless null-char path reads it, rewritten in
    `update_health()` (the health_changed signal path - stays live on damage).
  - `hp_value: int`, `hp_max: int` - numeric mirrors for max_health-relative
    playtest asserts.
- **New pure static**: `static func hp_label_text(current: int, max_hp: int) -> String`
  (unit-tested headless; format pinned: "cur/max", no spaces).
- `update_health()` additionally writes `HpLabel.text` (guarded by
  `get_node_or_null`, same defensive-resolution pattern) and re-asserts
  `mouse_filter=2`. Nothing else in update_health / setup / follow_character
  changes.

### 2.7 Playtest contract (architect-owned surface + skeletons; PM fills thresholds)

**Surface append (append-only, `playtest/_common.yaml`):**
- `SkillButton1` .. `SkillButton12` blocks each append: `cost_text`, `effect_text`,
  `effect_summary_text`, `lock_reason_text` (48 new surface vars total).
- `HealthBar` block appends: `hp_text`, `hp_value`, `hp_max`.
- `actions:` unchanged (new scenarios use only declared actions).
- `scenario_order` appends, in order: `skill_button_effect_info`,
  `locked_slot_unlock_reason`, `health_bar_numbers` (same order as
  `ROUND_SCENARIOS` - the order test requires sorted indices).

**Scenario skeletons** (name == basename, single-integer `at:`, every assert
carries a comparison operator; frame numbers are calibrated by probe - the
7x `ui_accept` boot prefix mirrors `skill_button_visual_states.yaml`):

1. `playtest/skill_button_effect_info.yaml` (UX-03) - boot to battle (7x
   `ui_accept`), then at a player-turn frame:
   - `SkillButton1.effect_text: effect_text != ""` (non-empty effect description)
   - `SkillButton1.cost_text: cost_text == "无消耗"` (cost surfaced; the only
     honest value with current data - all costs undefined => 0)
   - `SkillButton1.effect_summary_text: effect_summary_text != ""`
   - `SkillButton1.fahui_text: fahui_text == "发挥 ×1.3"` (regression pin: the
     narrowed FahuiLabel still renders the same text)
   - negative control: `SkillButton5.effect_text: effect_text != ""` (locked
     slots still show their effect info)
2. `playtest/locked_slot_unlock_reason.yaml` (UX-04) - same boot, at a round<4
   player-turn frame:
   - `SkillButton5.lock_reason_text: lock_reason_text != ""` (reason visible)
   - `SkillButton6/7/8.lock_reason_text: ... != ""` (all four locked slots)
   - `SkillButton1.lock_reason_text: lock_reason_text == ""` (unlocked slot
     shows no reason - derived, not hardcoded)
   - then `end_turn` xN (or `debug_fast_forward`) to reach round >= 4 and assert
     `SkillButton5.lock_reason_text == ""` and `SkillButton5.state_text != "phase_locked"`
     (the reason disappears exactly when the lock does).
3. `playtest/health_bar_numbers.yaml` (UX-05) - boot, at full HP:
   - `HealthBar.hp_text: hp_text != ""` and `hp_text == str(hp_max) + "/" + str(hp_max)`
     (full-HP text, expressed against max_health - no absolute HP literal)
   - `HealthBar.hp_max: hp_max > 0`; `HealthBar.hp_value: hp_value == hp_max`
   - then `debug_damage_player` (injects ~40% HP through apply_damage - the
     documented injection interface) and assert:
     `HealthBar.hp_value: hp_value < hp_max * 0.5 and hp_value > 0` and
     `HealthBar.hp_text: hp_text == str(hp_value) + "/" + str(hp_max)`
     (the number tracks the live value, still max_health-relative).

All health asserts are expressed against `hp_max` / ratios - **zero absolute HP
literals** (roadmap rule + brief constraint 6). No new DEBUG action is needed.

### 2.8 `tests/test_playtest_contract_smoke.py` - additive contract pin

- `ROUND_SCENARIOS` appends the three new names (end, same order as
  `scenario_order`; existing entries untouched).
- ONE new function `test_hud_info_surface_contract` (stdlib-only, follows the
  existing regex helpers): pins the four new vars on every SkillButton block,
  the three HealthBar vars, the three new scenario files existing with
  `name:` == basename, single-integer `at:` values, and a comparison operator
  on every assert line.

### 2.9 Unit tests (headless, `run() -> bool` SceneTree contract)

- `tests/test_skill_button_info.gd` (NEW): (a) `state_palette("no_energy")`
  luma 0.6629 is >= 0.10 from each of the five existing states' luma
  (pin the numbers: ready 0.3874, cooldown 0.0814, phase_locked 0.5306,
  hp_gated 0.2020, waiting 0.1558); (b) `cost_label_text(0) == "无消耗"`,
  `(25) == "内力 25"`; (c) `effect_summary` on a real tutorial SkillData
  (non-empty, <= 6 CJK chars, contains the skill's own damage number);
  (d) tag text `"内力不足"` present on the no_energy palette.
- `tests/test_health_bar_text.gd` (NEW): (a) `hp_label_text(500, 500) == "500/500"`,
  `(200, 500) == "200/500"`; (b) instantiate health_bar.tscn headless, call
  `setup("杨过", 500, null)` + `update_health(500, 500)` and assert `hp_text ==
  "500/500"`, `hp_value == 500`, `hp_max == 500`; (c) **regression pin**: the
  frozen geometry observables still read their authored values (`size == (68,24)`,
  `bar_width == 64.0`, `bar_height == 12.0`, `empty_cap_px == EMPTY_CAP_PX`) -
  proving the additive label changed no constant.
- Both wired into the GDScript unit-suite runner list (append-only, same as the
  jinyong-events round wired `test_event_data.gd`).

### 2.10 Docs / evidence

| File | Change |
|---|---|
| `design/40_ux_backlog.md` | UX-03 / UX-04 / UX-05 rows: OPEN -> `CLOSED(jinyong-hud)` with evidence paths (`playtest/skill_button_effect_info.yaml`, `playtest/locked_slot_unlock_reason.yaml`, `playtest/health_bar_numbers.yaml`, `final/hud_info_probe_notes.md`). Closure is explicit (backlog rule 2: action + evidence; no evidence -> no CLOSED). |
| `design/20_content.md` | NEW section 5 「内力消耗缺口」: no technique in the tutorial battle (or progression data) defines an inner-force cost; `10_systems.md §1` keeps "pool stores but does not spend"; `SkillData.cost` defaults 0; per-skill costs are a CONTENT GAP to be defined in the 养成 round - never invented in place. Lists the 8 player techniques + 12-slot bar as "cost undefined (0)". |
| `design/30_presentation.md` | Appended rows: skill-button info line (cost label + contextual info label, no-ellipsis discipline) and the HP number on the bar (child-of-Bar label, geometry constants untouched). |
| `design/99_changelog.md` | jinyong-hud round row (scope + rationale). |
| `final/hud_info_probe_notes.md` (NEW) | Pre-fix probe: current HUD shows no cost/effect/lock-reason/HP-number observables (A-class reds) + post-fix label-rect overlap probe for CostLabel/InfoLabel/FahuiLabel ink. |
| `final/delivery_notes.md` | Round notes; explicitly names the missing-cost content gap. |

---

## 3. Technology Stack

- **GDScript + stock Godot 4 Controls** (Label, Button stylebox overrides,
  ProgressBar child overlay) - exactly the in-repo toolkit; no new deps.
- **Playtest harness** as-is: `playtest/_common.yaml` + per-scenario YAML +
  `Expression`-evaluated asserts on the whitelisted surface.
- **pytest static smoke** (`tests/test_playtest_contract_smoke.py`) for the
  contract pins; **GDScript SceneTree unit tests** for the pure functions.
- No art assets, no audio, no `project.godot` changes (no new input actions or
  autoloads; all new scenarios reuse declared actions).

---

## 4. Edge Cases (from step1_sota.md -> how this design answers each)

- **Costs do not exist anywhere**: `SkillData.cost` defaults 0; the display
  renders "无消耗" (graceful undefined); the gap is recorded in
  `design/20_content.md §5` + delivery notes. No number is invented.
- **no_energy must be distinct from locked**: luma 0.6629 is the only band
  pairwise >= 0.10 from all five existing states (computed above, pinned in
  `test_skill_button_info.gd`); hue (light purple) differs from phase_locked's
  light gray; Chinese tag 内力不足 vs 锁定. The state machinery is real and
  unit-tested even though it cannot fire with current data.
- **Lock reason is tutorial-scoped**: derived from the same predicate, "" when
  not locked; the scenario asserts the empty case AND the round-4 flip.
- **Health geometry frozen**: sibling/child Label addition only; new test file
  pins the unchanged constants. `update_health()` writes the text; no constant
  touched in the three frozen files.
- **Health asserts relative to max_health**: `hp_text == str(hp_max)+"/"+str(hp_max)`,
  `hp_value < hp_max * 0.5` - no absolute HP literals anywhere.
- **Button label crowding (104x48, 4 live labels)**: two new labels placed in
  measured free bands; FahuiLabel rect is the only existing-child rect touched
  (unpinned); probe-first fallback shrinks the summary, never widens into
  pinned siblings, never uses ellipsis.
- **Two-place sync**: three new scenarios appended to BOTH `scenario_order` and
  `ROUND_SCENARIOS` in the same order; every assert line carries an operator;
  single-integer `at:` values only.
- **spine_to_ending + existing suites stay green**: with current data every new
  derivation evaluates to the empty/false branch (cost 0 -> no_energy false;
  lock_reason only on the already-locked slots 5-8 pre-round-4; waiting override
  unchanged), so existing `state_text` / `state_tag_text` / `state_luma` values
  are byte-identical on every existing frame. New observables are additive to
  the surface; existing assert lines are untouched.

---

## 5. Rollback / Safety (no irreversible operations)

- Every edit is additive (new vars, new nodes, new files, appended list entries,
  appended doc rows). No deletion, no rewrite of pinned constants, no data
  migration.
- The three frozen files (`scripts/ui/health_bar.gd`, `scenes/ui/health_bar.tscn`,
  `tests/test_health_bar.gd`) receive ONLY: one new child node, three new vars +
  one static + guarded writes in `update_health()`/`setup()` (health_bar.gd); one
  node block (health_bar.tscn); appended test cases (test file). Revert = remove
  those blocks; the pinned geometry lines are never edited, so rollback cannot
  drift the frozen contract. The new `tests/test_health_bar_text.gd` doubles as
  a constant-unchanged regression pin.
- Scenario registration follows the append-only rule; a bad scenario file is
  deleted without touching siblings.
- Probe-first gating (see 6) blocks label placement on measured ink overlap.

---

## 6. Task Decomposition (for PM)

1. **A1 - SkillData cost field** (2.1): one line; independent.
2. **A2 - skill_button.gd info layer** (2.3): no_energy palette + 4 observables +
   2 statics + `_refresh_info_label`; depends on A1.
3. **A3 - skill_button.tscn labels** (2.4): CostLabel + InfoLabel + FahuiLabel
   rect narrow; depends on A2. **Probe-gated**: run the label-rect ink probe
   before/after; shrink summary on overlap.
4. **A4 - hud.gd derivation** (2.2): no_energy + lock_reason_text in
   `_refresh_skill_button_states`; depends on A2/A3.
5. **B1 - health bar numbers** (2.6): HpLabel + observables + static; independent
   of A*; frozen-geometry discipline.
6. **C1 - contract wiring** (2.7 + 2.8): three scenario files, surface append,
   scenario_order + ROUND_SCENARIOS, smoke test function; depends on A4 + B1.
7. **C2 - unit tests** (2.9): two new test files + runner wiring; depends on A2/B1.
8. **D1 - docs + closure** (2.10): backlog CLOSED rows with evidence, content-gap
   section, presentation rows, changelog, probe notes, delivery notes; after C1/C2
   produce the gate evidence.
9. **D2 - full regression**: 47 -> 50 scenarios, spine_to_ending green, only
   `terminal_victory_8_12_rounds_hp_15_40` may stay red (sanctioned balance
   deferral).

**Acceptance (from the brief):** each UX item has a playtest assertion pinning
visible text/number (non-empty text / number appears, health relative to
max_health); `design/40_ux_backlog.md` shows all three as CLOSED(jinyong-hud)
with evidence paths; spine_to_ending fully green; existing playtest + unit
suites not red.
