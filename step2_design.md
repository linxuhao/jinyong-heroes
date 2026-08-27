# Technical Architecture Design - Character Creation Clarity Pass (UX-06/07/08)

**Round id:** `jinyong-clarity` · **Family:** presentation-only information round (same class as `jinyong-hud`) · **Stage 2 of the roadmap (交互: 玩家看得懂).**
**Baseline:** 50 playtest scenarios (all green at last measured gate), 73 compiled scripts, 17-file GDScript unit suite, `spine_to_ending` 32/32.

Scope: three information-missing findings on the character-creation screen (UX-06 / UX-07 / UX-08) plus removal of the fossil `final/verify_report.json`. **Zero game-rule or numeric-value changes; zero content invention; zero edits to frozen layout constants.**

---

## 0. The three findings and the one-line answer to each

| id | finding (design/40_ux_backlog.md, OPEN) | design answer |
|---|---|---|
| UX-06 | ATTRS page: 内力/身法/悟性/福缘 rows show only name+value; no effect explanation -> cannot decide where to spend points | The existing `AttrDescLabel` slot **stops following focus and lists ALL FIVE attribute effects** (name-prefixed, strings verbatim from `_ATTR_DESCS`), always visible during ATTRS |
| UX-07 | ATTRS page shows the formula 「气血 = 根骨 × 5」 but not the current HP -> player must do mental math | New additive `HpValueLabel` directly below the effects list, `text = "当前气血 %d"`, value = `attrs["bone"] * 5` (`design/40_progression.md §7` formula for player-created characters) |
| UX-08 | CONFIRM page shows only 剩余点数 + two buttons; no final attribute values -> cannot review the build before committing | New additive `ConfirmSummaryLabel` as the FIRST child of `ConfirmBox`, one `名 值` line per attribute, above 确认踏上江湖 |
| (housekeeping) | `final/verify_report.json` is a jinyong-events-era fossil that `repo_apply` (`final/*` ignore) can never refresh, yet presents itself as a delivery verdict | **Replace** with a pointer/tombstone note (gate results live in pipeline step products); decision recorded in `design/90_decisions.md` + `design/99_changelog.md`; README's citation re-pointed |

Everything below exists to make those four answers land **without moving a single frozen constant** and with every new displayed fact pinned by a playtest assertion.

---

## 1. Key design decisions (with rejected alternatives)

### D1 - UX-06: the desc slot becomes the all-five effects list (decision)

`AttrDescLabel.text` changes from "the focused attribute's description" (`_attr_desc(ATTR_KEYS[attr_index])`) to "all five effects, name-prefixed" (`attr_effects_text()`). `attr_index` still drives the row focus highlight (modulate) and the +/- target - only the desc channel's content semantics change.

**Why at-rest all-five, not focus-to-see:** the finding was recorded from the at-rest page (its text even quotes seeing the bone formula, i.e. the desc slot with default focus). A fix that keeps four rows bare until the player focuses each one leaves the at-rest page unchanged and the finding would be re-reported by the next frame review. The jinyong-hud precedent (UX-03) fixed "buttons show only name + 发挥度" by displaying effect text at rest, not by hiding it behind hover.

**Why not per-row effect text (rejected on frozen-geometry grounds, keep this record):**
- An extra Label inside each `AttrRow` (left or right of the value cluster) shifts `_row_ink_union(i)`'s x-center by ~W/2 of the new label's width; `attr_cluster_center_ok` pins the ink center to ±6px of viewport center 480 - any per-row label wider than ~12px reddens it.
- Interleaving 5 effect lines between the rows inside `AttrBox` grows the box past the `creation_box_fits` budget (5×44px rows + 48px desc + 44px nav + separation 10 already total 372px of the 480px `MouseBox`; five extra ~17px lines + 5 gaps ≈ +135px -> bottom ≈ 614px > 584px ceiling).
- Extending each row label's text (`内力 10(效果...)`) breaks the pinned rhythm "数值右对齐贴住本行的 -/+ 簇" (the value would no longer hug the cluster).
- These rejections are recorded in `design/30_presentation.md` so a future round knows it was a decision, not an oversight.

**Height budget (theme `default_font_size = 12`, NotoSansSC, line ≈ 17px):** the joined effects text ≈ 980px unwrapped -> wraps to **2 lines (~34px) inside the 560px-wide slot, i.e. under the 48px `custom_minimum_size`, so the label does not even grow** (worst case 3 lines = 51px, +3px). `AttrBox` total ≈ 220 (rows) + 48 (desc) + 17 (HP line) + 44 (nav) + 70 (7 gaps × 10) = 399px -> content bottom ≈ y 511 vs the `creation_box_fits` ceiling y 584: **~73px slack**.

### D2 - UX-07: a separate always-visible `HpValueLabel`, not a formula edit

`_ATTR_DESCS` is documented as "verbatim, never paraphrased" - the formula string stays byte-identical inside the effects list ("根骨:气血 = 根骨 × 5 · ..."). The **current value is a different kind of content** (dynamic, derived) and gets its own additive node + its own observable + its own assert:

- Node: `HpValueLabel`, new Label in `AttrBox`, placed **directly after `AttrDescLabel`** (below the effects list - the value reads as the resolution of the formula just above it), phase-gated to ATTRS.
- `CreationScreen.hp_value: int` = `hp_from_bone(int(attrs["bone"]))` = `attrs["bone"] * 5` (the §7 formula operand 5 IS the contract, same as the HUD round's `max_health`-relative discipline: **zero absolute HP literals in any assert**).
- `CreationScreen.hp_text: String` = `"当前气血 %d" % hp_value` - the exact rendered format, assertable as `hp_text == "当前气血 " + str(hp_value)`.
- Recomputed in `_render()` (every `attrs` mutation path ends in `_render` - verified: `_cycle_attr_or_trait`, `_on_move_left/right`, `_on_accept`, `_on_trait_toggle_pressed`, `debug_click_creation_widget` all route there).

### D3 - UX-08: `ConfirmSummaryLabel` above the buttons + one honest observable re-point

`ConfirmBox` is a `VBoxContainer` (separation 12) holding only `ConfirmButton` (240×44) + `BackButton` (160×44) = 100px of the 480px `MouseBox`. The summary becomes its **first child** (read before you commit), one line per attribute, explicit `\n` (no autowrap needed - longest line ≈ 60px):

```
根骨 12
内力 10
身法 14
悟性 10
福缘 10
确认踏上江湖
返回
```

Height ≈ 5 × 17 + 12 + 44 + 12 + 44 = 197px -> content bottom ≈ y 309, **~275px slack** against the `creation_box_fits` ceiling. `phase_skeleton_same` still holds (`ConfirmBox` remains `MouseBox`'s first visible child, top = 112), `nav_cluster_center_ok` still holds (both buttons still shrink-centered, union 240px).

**The one necessary observable change (declared, not silent):** `_update_geometry_observables()`'s `points_attrs_gap_ok` CONFIRM branch currently resolves the phase's first-row ink cluster as **`ConfirmButton`'s rect**. With the summary above the button, ConfirmButton moves down ~127px and that arm would read `gap ≈ 133 > 24` - silently flipping a measured-green fact (the pre-fix probe recorded it true at f150). The fix re-points the CONFIRM cluster to **`ConfirmSummaryLabel.get_global_rect()`**:

- Same observable name, **same yaml assert lines** - `creation_layout_readability.yaml` f30 and f90 lines `CreationScreen.points_attrs_gap_ok: points_attrs_gap_ok == true` stay byte-identical, and that file's f150 CONFIRM block (which does not assert the gap) is untouched. This is the exact precedent of the jinyong-layout-r2 Round-3 rework ("measured quantities changed... same var name, same yaml assert lines"), logged in `design/30_presentation.md` + `design/99_changelog.md`.
- Honesty argument (put in the code comment): the summary label's rect top == its first ink line's top (the label height equals its text block height in the VBox), and rect center-x == ink center-x because `horizontal_alignment = 1` centers every line - both conjuncts the gap check reads (top y, center x) are true ink facts, same class as the button-rect arms the code comment already documents.
- New measured value: PointsLabel text bottom ≈ y 102.5 -> summary top y 112 -> **gap ≈ 9.5 ∈ [4, 24]** ✓. The new `creation_confirm_summary` scenario asserts `points_attrs_gap_ok == true` AT the CONFIRM frame, pinning the re-point.
- Fallback: if `ConfirmSummaryLabel` is missing, fall back to the old `ConfirmButton` rect lookup (both `get_node_or_null`; zero-size cluster keeps the previous value - the existing sentinel convention).

### D4 - `final/verify_report.json`: replace with a tombstone pointer note (decision)

Chosen over deletion because: (a) the path is cited by `README.md` ("Verification status"), `design/30_presentation.md`'s Q5 note, and append-only changelog rows that can never be edited - a tombstone keeps those references resolving to the truth instead of dangling; (b) it converts the lie into an explicit statement ("this file does not represent current delivery") for every future reader; (c) the decision is what actually guards the future, and it goes in `design/90_decisions.md`.

The replacement carries **no verdict fields at all** (no `all_goals_met`, no `ready_for_deploy`, no `verified_subtasks` - those are themselves verdicts) - only `status`, a `note` naming the pipeline step products (`5_compile`: `compile_report.json` / `playtest_report.json` / `playtest_summary.md`; `5_vision`: `vision_report.json`; `5_test`: `test_report.json`) as the only authoritative gate evidence, and `represents_current_delivery: false`.

**Safety order (irreversible-content replacement -> backup/verify pattern):** (1) write the decision rows into `design/90_decisions.md` and `design/99_changelog.md` FIRST; (2) replace the file; (3) verify the new file parses as JSON and contains none of the old verdict fields; (4) the pre-replacement content remains recoverable via git history (the changelog row says so explicitly). Rollback = `git revert`. See §8.

`README.md`'s "Verification status (honest)" section (which today claims "final/verify_report.json records this round's verdict") is re-pointed to the pipeline gate products in the same task (it is rewritten by the final verifier step each round anyway, but the re-point is on the task list so the fossil citation cannot survive).

### D5 - Three NEW scenario files, zero edits to existing yamls

One scenario per UX item (mirrors jinyong-hud's 3-scenario shape, keeps blast radius one-file-per-scenario, and gives the backlog-closure task per-scenario counts to cite). The seven existing creation/menu scenario yamls (`creation_single_ui`, `creation_layout_readability`, `creation_mouse_interaction`, `creation_traits_back_next_buttons`, `creation_budget_clamp_and_traits`, `creation_back_to_menu_walk`, `menu_to_creation_to_tutorial_order`) are **byte-untouched** - their pins already cover everything this round must not break.

---

## 2. Architecture / data flow (text diagram)

```
player input (mouse clicks / move_* / ui_accept)
        |
        v
creation.gd state: phase, attrs, points_left, attr_index   (UNCHANGED rules)
        |
        v  _render()  (every mutation path ends here)
   +---------------- NEW: pure composition layer ----------------+
   | hp_value  = hp_from_bone(attrs["bone"])        (= bone * 5, §7) |
   | hp_text   = "当前气血 %d" % hp_value                           |
   | confirm_summary_text = confirm_summary_text_from(attrs)       |
   | attr_effects_text()  (all five, name-prefixed, verbatim)      |
   +----------------------------------------------------------------+
        |                    |                       |
        v                    v                       v
AttrDescLabel.text   HpValueLabel.text      ConfirmSummaryLabel.text
(all-five effects)   (ATTRS only)            (CONFIRM only)
        |                    |                       |
        +----- surface vars (CreationScreen.hp_value / hp_text / ----+
              confirm_summary_text) + node blocks (HpValueLabel,
              ConfirmSummaryLabel: visible/text)
                        |
                        v  _process() -> _update_geometry_observables()
        points_attrs_gap_ok CONFIRM cluster re-pointed to
        ConfirmSummaryLabel rect (same name, same yaml lines)
                        |
                        v
playtest/<3 new scenarios>.yaml  --Expression--> live-node asserts
        |                    |
        v                    v
tests/test_playtest_contract_smoke.py   tests/test_creation_info_texts.gd
(static two-place sync pin)             (headless unit pin, -s runner)
```

Single source of truth: the label text and the surface var are written from the same composed string in `_render()`; the unit test calls the same pure functions; the scenarios assert both the node text (display proof) and the vars (relative numeric proof).

---

## 3. Component list (all paths relative to repo root)

### C1 · `scenes/segments/creation.tscn` - two additive Label nodes, nothing else

**No existing node, offset, `custom_minimum_size`, separation, size flag or text is edited.** Add:

```ini
[node name="HpValueLabel" type="Label" parent="MouseBox/AttrBox"]
horizontal_alignment = 1
mouse_filter = 2
visible = false
text = ""
clip_text = false
text_overrun_behavior = 0

[node name="ConfirmSummaryLabel" type="Label" parent="MouseBox/ConfirmBox"]
horizontal_alignment = 1
mouse_filter = 2
visible = false
text = ""
clip_text = false
text_overrun_behavior = 0
```

- `HpValueLabel` is authored **between `AttrDescLabel` and `AttrNavRow`** (tscn node order == VBox order); `ConfirmSummaryLabel` is authored **before `ConfirmButton`** (first child of `ConfirmBox`).
- No `custom_minimum_size` (natural one-line / five-line heights); no autowrap on the summary (explicit `\n`); the effects label keeps its existing `autowrap_mode = 3`.
- `mouse_filter = 2` (IGNORE) - explicit-declaration discipline (AttrDescLabel precedent); `clip_text = false` + `text_overrun_behavior = 0` - the no-ellipsis discipline from jinyong-hud.
- Both paths are new and pinned by nothing; sibling-addition precedent (TopStrip, HpLabel, CostLabel/InfoLabel).

### C2 · `scripts/segments/creation.gd` - additive vars + pure funcs + two render hooks + one measurement re-point

Untouched: `START_POINTS`, `ATTR_MIN/MAX`, `_ATTR_DESCS` (byte-identical), `_step_cost`, all input handlers, `SaveManager.new_profile` call, all existing observables' semantics. New (all with `## Surface:` doc comments):

```gdscript
## Surface: current HP of the build under construction, derived exactly as
## design/40_progression.md §7 defines it for player-created characters
## (气血 = 根骨 × 5). Display-only - no rule or stored value changes (UX-07).
var hp_value: int = 50

## Surface: the HpValueLabel text ("当前气血 N"); kept equal to the label so
## asserts can pin the exact rendered format (UX-07).
var hp_text: String = ""

## Surface: the ConfirmSummaryLabel text - one "名 值" line per attribute,
## the final-value checklist the confirm page was missing (UX-08).
var confirm_summary_text: String = ""


## Pure derivation: HP from 根骨 (design/40_progression.md §7). Reads no
## nodes, so tests can call it on a bare instance. The multiplier 5 IS the
## documented formula - the only number this round is allowed to show.
func hp_from_bone(bone: int) -> int:
	return bone * 5


## Pure composition: all five attribute effects, name-prefixed, segments
## VERBATIM from _ATTR_DESCS (design/10_systems.md §1 + §7 formulas).
## Nothing is invented; _attr_desc("") never throws.
func attr_effects_text() -> String:
	var parts: Array[String] = []
	for key in PlayerProfile.ATTR_KEYS:
		parts.append("%s:%s" % [_attr_label(key), _attr_desc(key)])
	return " · ".join(parts)


## Pure composition: the confirm-page summary, one line per attribute in
## PlayerProfile.ATTR_KEYS order, same "名 值" shape as the ATTRS row labels.
func confirm_summary_text_from(values: Dictionary) -> String:
	var lines: Array[String] = []
	for key in PlayerProfile.ATTR_KEYS:
		lines.append("%s %2d" % [_attr_label(key), int(values.get(key, 0))])
	return "\n".join(lines)
```

Render hooks in `_render()`:

```gdscript
# Derivations (cheap; every attrs mutation ends in _render):
hp_value = hp_from_bone(int(attrs["bone"]))
hp_text = "当前气血 %d" % hp_value
confirm_summary_text = confirm_summary_text_from(attrs)
# UX-06: the desc slot lists ALL FIVE effects (was: the focused attr's desc).
# attr_index still drives the focus highlight (modulate) and the +/- target.
var attr_desc_label: Label = get_node_or_null("MouseBox/AttrBox/AttrDescLabel") as Label
if attr_desc_label != null:
	attr_desc_label.visible = phase == "ATTRS"
	if phase == "ATTRS":
		attr_desc_label.text = attr_effects_text()
# UX-07: current HP next to the formula list.
var hp_label: Label = get_node_or_null("MouseBox/AttrBox/HpValueLabel") as Label
if hp_label != null:
	hp_label.visible = phase == "ATTRS"
	if phase == "ATTRS":
		hp_label.text = hp_text
# UX-08: the confirm-page checklist above the two buttons.
var confirm_summary_label: Label = get_node_or_null("MouseBox/ConfirmBox/ConfirmSummaryLabel") as Label
if confirm_summary_label != null:
	confirm_summary_label.visible = phase == "CONFIRM"
	if phase == "CONFIRM":
		confirm_summary_label.text = confirm_summary_text
```

And in `_update_geometry_observables()`, the `match phase:` `"CONFIRM":` arm of the `points_attrs_gap_ok` cluster (currently resolves `MouseBox/ConfirmBox/ConfirmButton`): first try `MouseBox/ConfirmBox/ConfirmSummaryLabel`; if non-null, `cluster = summary.get_global_rect()`; else keep the existing `ConfirmButton` fallback. Code comment must state: same observable, same yaml lines, measured-quantity change per the jinyong-layout-r2 precedent; rect top == first ink line top and rect center == ink center (centered lines) so both conjuncts (top y, center x) remain ink facts.

`PlayerProfile` is a `class_name` (`scripts/data/player_profile.gd`), so the pure functions resolve off-tree - the unit test needs no SceneTree.

### C3 · `playtest/_common.yaml` - append-only surface + scenario_order

- `CreationScreen` block appends: `hp_value`, `hp_text`, `confirm_summary_text` (after `desc_alignment_ok`).
- Two new node blocks (next to `AttrDescLabel`/`TraitDescLabel`/`PointsLabel`):
  `HpValueLabel: [visible, text]`, `ConfirmSummaryLabel: [visible, text]`.
- `scenario_order` appends, in this exact order: `creation_attr_effect_info`, `creation_hp_value_displayed`, `creation_confirm_summary` (50 -> 53 scenarios).

### C4 · `playtest/creation_attr_effect_info.yaml` (UX-06) - full skeleton

```yaml
name: creation_attr_effect_info
description: >-
  UX-06: at rest (f30, default focus) the ATTRS desc slot lists all five
  attribute effects - every name present, every effect keyword present, the
  bone formula verbatim. Focus cycling (move_down) proves the list does not
  follow focus away - the info is at-rest, not focus-transient.
scene: res://scenes/segments/creation.tscn
timeline:
- at: 30
  actions: []
  assert:
    CreationScreen.phase: phase == "ATTRS"
    AttrDescLabel.visible: visible == true
    AttrDescLabel.text: text.contains("根骨") == true
    AttrDescLabel.text: text.contains("内力") == true
    AttrDescLabel.text: text.contains("身法") == true
    AttrDescLabel.text: text.contains("悟性") == true
    AttrDescLabel.text: text.contains("福缘") == true
    AttrDescLabel.text: text.contains("气血 = 根骨 × 5") == true
    AttrDescLabel.text: text.contains("内力值") == true
    AttrDescLabel.text: text.contains("移动力") == true
    AttrDescLabel.text: text.contains("学功法") == true
    AttrDescLabel.text: text.contains("奇遇") == true
    CreationScreen.cursor_markers_visible: cursor_markers_visible == false
- at: 40
  actions:
  - move_down
- at: 70
  actions: []
  assert:
    CreationScreen.phase: phase == "ATTRS"
    CreationScreen.attr_index: attr_index == 1
    AttrDescLabel.text: text.contains("福缘") == true
    AttrDescLabel.text: text.contains("奇遇") == true
```

("气血 = 根骨 × 5" is the documented formula string from `_ATTR_DESCS` / `40_progression.md §7` - a text contract, not an invented number. The `move_down` leg also satisfies the "at least one input per scenario" rule.)

### C5 · `playtest/creation_hp_value_displayed.yaml` (UX-07) - full skeleton

```yaml
name: creation_hp_value_displayed
description: >-
  UX-07: the current HP is displayed next to the formula and tracks the live
  build - every numeric assert is RELATIVE to attrs (hp_value ==
  attrs["bone"] * 5), zero absolute HP literals. move_right raises the
  focused bone row (default focus = row 0) and the displayed value follows.
scene: res://scenes/segments/creation.tscn
timeline:
- at: 30
  actions: []
  assert:
    CreationScreen.phase: phase == "ATTRS"
    HpValueLabel.visible: visible == true
    HpValueLabel.text: 'text != ""'
    HpValueLabel.text: text.contains("气血") == true
    CreationScreen.hp_value: hp_value == attrs["bone"] * 5
    CreationScreen.hp_text: 'hp_text == "当前气血 " + str(hp_value)'
- at: 40
  actions:
  - move_right
- at: 45
  actions: []
  assert:
    CreationScreen.hp_value: changed
- at: 70
  actions: []
  assert:
    CreationScreen.hp_value: hp_value == attrs["bone"] * 5
    CreationScreen.hp_text: 'hp_text == "当前气血 " + str(hp_value)'
    HpValueLabel.text: 'text != ""'
- at: 80
  actions:
  - move_left
- at: 105
  actions: []
  assert:
    CreationScreen.hp_value: hp_value == attrs["bone"] * 5
```

`str()` in an assert expression is proven by `health_bar_numbers.yaml` (`hp_text == str(hp_max)`); dictionary indexing is proven by `creation_single_ui.yaml` (`attrs["bone"] == 11`). **Fallback if the harness Expression ever rejects `+` on strings:** replace `hp_text == "当前气血 " + str(hp_value)` with `hp_text.contains(str(hp_value)) == true` (still relative) - do NOT fall back to any absolute literal.

### C6 · `playtest/creation_confirm_summary.yaml` (UX-08) - full skeleton

```yaml
name: creation_confirm_summary
description: >-
  UX-08: walking ATTRS -> TRAITS -> CONFIRM (real clicks), the confirm page
  lists the final value of each attribute (one per-assert per attribute, each
  expressed RELATIVE to the live attrs dict). The CONFIRM-phase geometry pins
  (points_attrs_gap_ok with the re-pointed first-row cluster, skeleton, box
  fit, nav cluster) prove the summary entered the frozen layout without
  moving it. BackButton returns to TRAITS and the summary phase-hides.
scene: res://scenes/segments/creation.tscn
timeline:
- at: 30
  actions: []
  assert:
    CreationScreen.phase: phase == "ATTRS"
    ConfirmSummaryLabel.visible: visible == false
- at: 40
  actions: []
  clicks:
  - AttrNextButton
- at: 90
  actions: []
  assert:
    CreationScreen.phase: phase == "TRAITS"
- at: 100
  actions: []
  clicks:
  - TraitNextButton
- at: 150
  actions: []
  assert:
    CreationScreen.phase: phase == "CONFIRM"
    ConfirmSummaryLabel.visible: visible == true
    ConfirmSummaryLabel.text: 'text != ""'
    CreationScreen.confirm_summary_text: 'confirm_summary_text != ""'
    CreationScreen.confirm_summary_text: 'confirm_summary_text.contains("根骨 " + str(attrs["bone"])) == true'
    CreationScreen.confirm_summary_text: 'confirm_summary_text.contains("内力 " + str(attrs["inner"])) == true'
    CreationScreen.confirm_summary_text: 'confirm_summary_text.contains("身法 " + str(attrs["agility"])) == true'
    CreationScreen.confirm_summary_text: 'confirm_summary_text.contains("悟性 " + str(attrs["wisdom"])) == true'
    CreationScreen.confirm_summary_text: 'confirm_summary_text.contains("福缘 " + str(attrs["fortune"])) == true'
    CreationScreen.points_attrs_gap_ok: points_attrs_gap_ok == true
    CreationScreen.phase_skeleton_same: phase_skeleton_same == true
    CreationScreen.creation_box_fits: creation_box_fits == true
    CreationScreen.nav_cluster_center_ok: nav_cluster_center_ok == true
- at: 160
  actions: []
  clicks:
  - BackButton
- at: 180
  actions: []
  assert:
    CreationScreen.phase: phase == "TRAITS"
    ConfirmSummaryLabel.visible: visible == false
```

All `clicks:` targets (`AttrNextButton`, `TraitNextButton`, `BackButton`) already belong to whitelisted surface blocks (the smoke test enforces clicks-owner membership). Attr values 10..20 are always two digits, so `"%s %2d"` renders exactly `"名 NN"` and the `contains("名 " + str(attrs[key]))` form matches. Same string-concat fallback rule as C5 if ever needed.

### C7 · `tests/test_playtest_contract_smoke.py` - ROUND_SCENARIOS tail + one additive test

- `ROUND_SCENARIOS` appends, in the SAME order as the `scenario_order` tail: `creation_attr_effect_info`, `creation_hp_value_displayed`, `creation_confirm_summary` (the existing `test_round_scenarios_present_on_disk_and_in_order` enforces the two lists agree).
- New additive function `test_creation_clarity_surface_contract()` (mirrors `test_hud_info_surface_contract`): asserts `CreationScreen` block carries `hp_value` / `hp_text` / `confirm_summary_text`; `HpValueLabel` and `ConfirmSummaryLabel` blocks exist with `visible` + `text`; `AttrDescLabel` still whitelisted (guard); for each of the three new scenario files: exists on disk, `name:` == basename (regex `^name:\s*<name>\s*$`), every timeline `at:` value is a single integer (the same `\bat\s*:` regex), and every 4-space dotted assert line carries a comparison operator (`== != < > and or` - the no-bare-scalar-silent-false rule). Stdlib only; existing functions untouched.

### C8 · `tests/test_creation_info_texts.gd` + `tests/unit_test_runner.gd` registry

New headless unit test, contract `static func run() -> bool` + `_expect` helper (test_health_bar_text.gd pattern; scene instantiated, never added to a tree; `PlayerProfile` is a `class_name` so the pure functions work off-tree):

1. **Formula pin (relative):** `for b in range(10, 21): hp_from_bone(b) == b * 5` - the full creation clamp range; the operand 5 is the §7 contract.
2. **Effects composition pin:** `attr_effects_text()` contains all five names, `气血 = 根骨 × 5`, `内力值`, `移动力`, `学功法`, `奇遇`; contains no `▶` (cursor-marker guard).
3. **Summary composition pin:** for a sample attrs dict, `confirm_summary_text_from()` has exactly 5 lines and each `"名 值"` line present.
4. **Scene wiring pin:** instantiate `creation.tscn`; set `attrs["bone"] = 15`; call `_render()`; assert `HpValueLabel.text == "当前气血 75"`, `HpValueLabel.visible == true`, `AttrDescLabel.text == attr_effects_text()`; set `phase = "CONFIRM"`, `_render()`; assert `ConfirmSummaryLabel.visible == true` and its text contains `"根骨 15"`, `HpValueLabel.visible == false`; both new labels `mouse_filter == 2`, `clip_text == false`, `text_overrun_behavior == 0`, `horizontal_alignment == 1`.
5. **Frozen-geometry regression pin (any drift reddens THIS test):** `AttrRow0..4.custom_minimum_size == Vector2(0, 44)`; `AttrDescLabel.custom_minimum_size == Vector2(0, 48)`; `MouseBox` offsets `-280 / -240 / 280 / 240`; `AttrBox` separation 10, `ConfirmBox` separation 12; `ConfirmButton.custom_minimum_size == Vector2(240, 44)`; `BackButton.custom_minimum_size == Vector2(160, 44)`; `AttrLabel` pair `horizontal_alignment == 2 and size_flags_horizontal == 3`; `AttrNavRow.size_flags_horizontal == 4`.

Register `res://tests/test_creation_info_texts.gd` in `unit_test_runner.gd`'s `TESTS` array in alphabetical position (after `test_card_data.gd`; additions only, no removals) - suite 17 -> 18 files.

### C9 · Design-archive edits (docs FIRST, then code - the constraint-2 order)

1. `design/30_presentation.md`: (a) update the UI-layout 捏人屏 row: the ATTRS desc slot lists all five attribute effects (name-prefixed, sourced from `10_systems.md §1` / `40_progression.md §7`), the current-HP line (`HpValueLabel`, live `气血 = 根骨 × 5` value) sits below it, and the CONFIRM page carries `ConfirmSummaryLabel` (per-attr final values) above the two buttons; (b) append a dated 2026-08-27 amendment block recording D1's at-rest decision + the rejected per-row alternatives (with the ink-center / box-overflow reasons) and D3's `points_attrs_gap_ok` CONFIRM cluster re-point (same observable, same yaml lines, jinyong-layout-r2 precedent, with the ink-honesty argument).
2. `design/20_content.md`: append a "no content gap" note (mirroring §5's discipline): all five attribute effects have existing definitions (`_ATTR_DESCS`, verbatim from `10_systems.md §1` + `40_progression.md §7`); 悟性 / 福缘 have `-` in the battle-derived column, so their displayed effects are the cultivation meanings exactly as defined - **nothing invented, no gap to record**.
3. `design/40_ux_backlog.md`: append a 记录 row (2026-08-27 `jinyong-clarity`: fixes landed for UX-06/07/08 + the three scenario files; post-fix gate evidence pending; per rule 2 CLOSED is written only by the post-gate evidence task). The three rows stay OPEN at landing time.
4. `design/99_changelog.md`: append the `jinyong-clarity` round row (creation info layer, 50 -> 53 scenarios, verify_report tombstone, docs-first record).
5. `design/90_decisions.md`: append to the Out-of-scope table: maintaining a delivery verdict inside `final/verify_report.json` - rejected because `repo_apply` ignores `final/*` (never refreshed), the jinyong-events-era verdict kept presenting itself as current and misled the jinyong-hud backlog-closure re-check; replaced by a pointer note; the only authoritative gate evidence is the pipeline step products, never a repo file under `final/`.

### C10 · `final/verify_report.json` tombstone + README re-point + round evidence notes

1. Tombstone JSON (no verdict fields):
```json
{
  "status": "superseded_pointer_note",
  "note": "This file is NOT a delivery verdict and does not represent the current delivery state. Authoritative gate results are the PIPELINE STEP PRODUCTS (5_compile: compile_report.json / playtest_report.json / playtest_summary.md; 5_vision: vision_report.json; 5_test: test_report.json) - pipeline artifacts, not repo files. The pipeline's repo_apply ignores final/*, so nothing in this directory is ever refreshed by a run. The verdict text this file used to carry (last written by the jinyong-events round's t_impl card: vision gate IncompleteRead, 4/47 scenarios judged, terminal_victory 5/6) was removed on 2026-08-27 by the jinyong-clarity round; the decision is recorded in design/90_decisions.md (Out of scope) and design/99_changelog.md. The pre-replacement content is recoverable from git history.",
  "represents_current_delivery": false
}
```
2. `README.md` "Verification status (honest)": re-point the `final/verify_report.json` citation to the pipeline gate products (no "this round's verdict" claim from a repo file that the pipeline cannot refresh).
3. `final/creation_info_probe_notes.md` (probe task, BEFORE the code lands): one inline direct-boot probe recording the pre-fix A-class absence - `HpValueLabel` / `ConfirmSummaryLabel` nodes absent, `hp_value` / `hp_text` / `confirm_summary_text` observables absent, `AttrDescLabel.text` shows only the focused attr's desc at rest (the UX-06 baseline). Mirrors `final/hud_info_probe_notes.md §1`.
4. `final/delivery_notes.md` for this round (the closing record, jinyong-hud template): A/B classification of the three info groups, gate-product honesty (compile / playtest / unit / vision states as measured, not claimed), the no-gap content note, UX disposition, and the verify_report resolution decision.

---

## 4. Frozen-pin compatibility table (why every existing creation pin stays green)

| pinned observable (creator scenario) | why this round cannot redden it |
|---|---|
| `attr_rows_uniform` (f30) | the five `AttrRow` rects (44px, shared edges) are untouched; new labels are `AttrBox`-level siblings |
| `attr_label_alignment_ok` (f30) | checks only `AttrRow%d/AttrLabel` property pair (2 / 3) - untouched |
| `points_attrs_gap_ok` ATTRS arm (f28) | cluster = `_row_ink_union(0)` - row 0 ink unchanged |
| `points_attrs_gap_ok` TRAITS arm (f45) | cluster = `TraitToggle0` rect - untouched |
| `points_attrs_gap_ok` CONFIRM (re-pointed, new pin at f150 of the new scenario) | cluster = `ConfirmSummaryLabel` rect; gap ≈ 9.5 ∈ [4, 24]; fallback = old ConfirmButton lookup |
| `phase_skeleton_same` (f44/f58/f150) | `AttrBox` / `TraitBox` / `ConfirmBox` tops are all still `MouseBox` top (112) - only children were appended, no box moved |
| `creation_in_viewport` | `MouseBox` 560×480 offsets untouched |
| `creation_box_fits` | ATTRS bottom ≈ 511, CONFIRM bottom ≈ 309, both ≤ 584 (73px / 275px slack) |
| `attr_cluster_center_ok` / `attr_cluster_width_ok` (f30) | measured on row ink (label text ∪ minus ∪ plus) - rows untouched |
| `nav_cluster_center_ok` (all phases) | nav buttons keep shrink-center + fixed widths; vertical position is not measured |
| `trait_cluster_center_ok` (f90) | `TraitBox` untouched |
| `desc_center_ok` (f30) | `AttrDescLabel` stays centered-aligned; its wrapped multi-line text keeps an ink x-center equal to the label center (each wrapped line is centered); the helper's single-line width is inexact but the derived fact (x-center ±6, non-zero) remains true - the same known limitation the code comment already documents for the TRAITS desc; `desc_alignment_ok` (property pin) remains the load-bearing centering proof |
| `desc_alignment_ok` (all phases) | checks `AttrDescLabel` / `TraitDescLabel` `horizontal_alignment == 1` - unchanged properties |
| `cursor_markers_visible == false` | new texts are plain Chinese, no `▶`; the `_render()` scan covers the new labels automatically |
| `creation_traits_back_next_buttons` f30 `AttrDescLabel.text.contains("气血")` | the all-five list still contains bone's formula segment "气血 = 根骨 × 5" |
| `creation_single_ui` points/budget walk | no input-path or clamp logic touched |
| `menu_to_creation_to_tutorial_order` / `creation_back_to_menu_walk` / `spine_to_ending` | routing, `SaveManager.new_profile`, `GameManager.finish_creation` untouched; no new control can steal focus or input (`focus_mode` untouched on interactive nodes, new labels are `mouse_filter = 2`) |

Regression net: the seven existing creation/menu yamls byte-untouched + `spine_to_ending` + the full 50-scenario gate + the unit suite (18 files) + the smoke test.

---

## 5. Observable contract (the hard interface - implementers match names exactly)

| surface entry | type | meaning | written by |
|---|---|---|---|
| `CreationScreen.hp_value` | int | `attrs["bone"] * 5` (§7 formula) | `_render()` |
| `CreationScreen.hp_text` | String | `"当前气血 %d"` - the exact rendered format | `_render()` |
| `CreationScreen.confirm_summary_text` | String | five `名 值` lines joined with `\n` | `_render()` |
| `HpValueLabel` (node block) | visible, text | the HP line, ATTRS-gated | `_render()` |
| `ConfirmSummaryLabel` (node block) | visible, text | the confirm checklist, CONFIRM-gated | `_render()` |

UI strings (Chinese-only hard rule, verbatim contracts):
- Effects list: `_attr_label(key) + ":" + _attr_desc(key)` for the five keys, joined `" · "` -> `根骨:气血 = 根骨 × 5 · 内力:内力值 = 内力 × 2 · 身法:移动力 = 2 + 身法 ÷ 20(向下取整);先攻 = 身法 · 悟性:决定学功法的速度(修习查表) · 福缘:影响事件与奇遇(游历事件可重掷)` (every segment is an existing string).
- HP line: `当前气血 50` (format `"当前气血 %d"`).
- Summary lines: `根骨 12` (format `"%s %2d"`, same shape as the row labels).

Every new piece of displayed information has at least one assert: five name + five keyword asserts (UX-06), visibility + non-empty + relative-equality + change-tracking asserts (UX-07), one per-attribute relative assert + phase-gating asserts (UX-08). All numeric asserts are relative expressions (`hp_value == attrs["bone"] * 5`, `contains("根骨 " + str(attrs["bone"]))`); **zero absolute numeric literals in new asserts**.

---

## 6. Edge cases from the SOTA report - how this design handles each

- **"A desc label already exists"** - it is reused as the carrier (content semantics changed, D1) instead of adding a parallel node; the cycling-assert alternative was considered and rejected as leaving the at-rest page unchanged (D1 rationale).
- **"Effect-text source of truth"** - every segment is an existing string; 悟性/福缘 display their cultivation meanings as defined; `design/20_content.md` gets the explicit "no gap" note rather than silence.
- **"HP must be relative, never == 50"** - `hp_value == attrs["bone"] * 5` everywhere; the only literal is the formula operand 5, which IS the documented contract.
- **"Frozen geometry pinned by two scenarios"** - §4 table; the one unavoidable measurement change (CONFIRM gap cluster) is declared, precedented, and newly pinned.
- **"No silent constant edits"** - the tscn diff contains only two new node stanzas; the unit test re-pins every frozen constant so drift reddens a test.
- **"CONFIRM observables must come from the surface"** - `hp_value` / `hp_text` / `confirm_summary_text` are real vars appended to the `CreationScreen` block; node blocks added; contract test pins the two-place sync.
- **"Scenario-harness hard rules"** - name == basename, single-integer `at:` values, comparison operator on every dotted assert line, `ROUND_SCENARIOS` order == `scenario_order` tail order, direct `creation.tscn` boots, at least one input per scenario.
- **"cursor glyph"** - no `▶` anywhere; scan runs after every `_render`.
- **"Chinese-only UI text"** - all new strings are Chinese, quoted in §5.
- **"verify_report fossil"** - D4 + C10.
- **"Backlog closure discipline"** - OPEN at landing; only the post-gate evidence task flips to `CLOSED(jinyong-clarity)` citing `playtest_summary.md` per-scenario counts (`creation_attr_effect_info N/N` etc.) - the jinyong-hud CLOSED-before-evidence reversal is the standing lesson.
- **"Content-gap ledger honesty"** - the "no gap, sourced from §1" note (C9.2) instead of silence.

---

## 7. Design changes declared for `5_design` (surgical archive updates after acceptance)

1. `30_presentation.md` - 捏人屏 row update + the 2026-08-27 amendment block (D1 decision + rejected alternatives; D3 cluster re-point) - see C9.1.
2. `20_content.md` - "no content gap" note for attribute effect text - C9.2.
3. `40_ux_backlog.md` - the round's 记录 row now; CLOSED rows + evidence only from the post-gate task - C9.3.
4. `99_changelog.md` - one append-only round row - C9.4.
5. `90_decisions.md` - one Out-of-scope row (verdict-in-final/ rejected) - C9.5.
6. `final/verify_report.json` -> tombstone (C10.1) + README citation re-point (C10.2).

No conflicts with the archive's rules: the desc-slot change is a presentation record addition (the archive never pinned focused-vs-all content semantics); the cluster re-point follows the repo's own "same name, same yaml lines, logged measured-quantity change" convention.

---

## 8. Safety, baseline protection, rollback

- **Everything additive:** two new scene nodes, three script vars, three pure funcs, two render hooks, one measurement re-point with fallback, three new yaml files, surface/order/smoke/TESTS registry appends, doc row appends. No existing file's pinned lines are edited (the only in-file edit sites are `creation.gd`'s desc assignment, the CONFIRM gap arm, and `creation.tscn`'s node list).
- **The one content-replacement op (verify_report.json)** follows backup -> execute -> verify -> record: decision rows written first; replacement second; verification third (parses as JSON; no `all_goals_met` / `ready_for_deploy` / `verified_subtasks` fields; pointer text present); recoverability via git history stated in the changelog row. Rollback: `git revert` restores the fossil byte-for-byte if the decision is ever reversed.
- **Whole-round rollback:** every change lands as normal git commits in one round; `git revert` of the round's commits restores the exact 50-scenario / 73-script / 17-test baseline.
- **No rule/value drift guard:** `_ATTR_DESCS`, `START_POINTS`, `ATTR_MIN/MAX`, `_step_cost`, `new_profile`, battle/cultivation files untouched; the only new number anywhere is the ×5 display derivation, which is the documented §7 formula; the unit test pins it relatively across the whole 10..20 clamp range.

---

## 9. Verification plan (gate criteria) and PM decomposition hints

**Gate criteria (all must hold on the final tree):**
- `5_compile` sidecar: whole-repo compile 74 scripts (73 + the new unit test file) with 0 errors; playtest hard gate passed, **53/53 scenarios green** - including `spine_to_ending` 32/32, the seven existing creation/menu scenarios byte-unchanged and green, and the three new scenarios green (`creation_attr_effect_info`, `creation_hp_value_displayed`, `creation_confirm_summary`).
- GDScript unit suite via `run_tests.sh` / `-s` runner: **18 passed, 0 failed**.
- pytest smoke gate: all existing tests + `test_creation_clarity_surface_contract` green.
- Vision gate: may be blind (`endpoint_unreachable`) - same stance as jinyong-hud: the three findings are information-presence pins (text non-empty / value present) judged by playtest asserts; rendered-ink concerns are compensated by the existing measured observables, not by a vision verdict.
- Post-gate `backlog_closure` evidence task flips UX-06/07/08 to `CLOSED(jinyong-clarity)` citing `playtest_summary.md` per-scenario counts (backlog rule 2); delivery notes record the honest gate-product state and the verify_report resolution.

**Task decomposition order (dependencies):**
1. `creation_info_probe` - pre-fix A/B probe notes (C10.3) - BEFORE any code lands.
2. `docs_presentation_record` - 30_presentation + 20_content rows (C9.1, C9.2) - docs FIRST per constraint 2.
3. `creation_info_labels` - tscn + creation.gd + unit test + TESTS registry (C1, C2, C8).
4. `creation_clarity_scenarios` - three yamls + `_common.yaml` surface/order + smoke ROUND_SCENARIOS + new test function (C3-C7).
5. `verify_report_tombstone` - 90_decisions + 99_changelog rows, file replacement + verification, README re-point (C9.4, C9.5, C10.1, C10.2).
6. `backlog_record` - 40_ux_backlog 记录 row (C9.3) + delivery notes (C10.4).
7. (post-gate) `backlog_closure` evidence task - the only writer of CLOSED.

---

## 10. Linter / tooling selection

No new external tooling - the round is pure in-repo Godot/GDScript + the existing stdlib-only pytest smoke test (PyYAML stays out, per every prior round). `linter_manifest.json` therefore stays identical to the repo baseline: `.py` -> `ruff`, `.yaml` / `.json` / `.md` -> `basic`. GDScript (`.gd`) and scenes (`.tscn`) are deliberately NOT in the manifest - they are parsed per-file by the host-controlled `gdscript_check` / compile gates (the addon rule: a misspelled backend name must never silently disable a gate).
