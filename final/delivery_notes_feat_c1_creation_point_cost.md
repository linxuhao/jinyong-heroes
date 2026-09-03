# Delivery notes — feat_c1_creation_point_cost (R5 C1)

> Date: 2026-09-03. C1 point-cost visibility on the creation attribute screen:
> the next-point cost, the refund and the remaining budget are rendered beside
> every +/- row (always visible — the touch path), composed from the EXISTING
> private helper `creation.gd::_step_cost` (never duplicated, body byte-unchanged).
> One new nail `trait_point_cost_visible`. i18n EN only-add (1 key). Both
> registries ONLY-ADD. No other creation behavior touched.

## 改动清单 (change list)

1. `scripts/segments/creation.gd` — new surface vars `attr_cost_text: String` /
   `attr_step_cost: int`; `_render()` attr-row loop now composes each row's cost
   line and publishes the focused row's two observables. **Only** these additions;
   `_step_cost`, `_on_move_left`, `_on_move_right`, `_row_ink_union`, trait toggles,
   `trait_hover_index`, hover handlers, HP/confirm render are byte-unchanged.
2. `scenes/segments/creation.tscn` — added 5 plain `Label` nodes
   `AttrCostLabel0..4` inside `MouseBox/AttrBox/AttrRow{i}`, after `AttrPlus{i}`.
   `text = ""` at authoring (filled at runtime by `_render()`);
   `custom_minimum_size = Vector2(0, 0)`; **no existing node restyled** (the 14
   theme font-size pins untouched). All five rows carry a label uniformly so
   `attr_rows_uniform` stays true.
3. `scripts/autoload/i18n.gd` — ONE new EN key, only-add:
   `"＋1 需 %d 点 · −1 退 %d 点 · 剩 %d": "Raise +1: %d pts · Lower -1: %d pts · Left: %d",`
   (inserted directly after `"剩余点数 %d"`). No deletion, no rewrite of any other key.
4. `playtest/trait_point_cost_visible.yaml` — new nail (name == basename).
5. `playtest/_common.yaml` — ONLY-ADD: `CreationScreen` surface gains
   `- attr_cost_text`, `- attr_step_cost`; `scenario_order` gains
   `- trait_point_cost_visible` (tail, after `enemy_action_feedback`).
6. `tests/test_playtest_contract_smoke.py` — ONLY-ADD: `ROUND_SCENARIOS` gains
   `"trait_point_cost_visible",`; new static pin
   `test_creation_point_cost_surface_contract`. No existing test touched.
7. `final/delivery_notes_feat_c1_creation_point_cost.md` — this file.

## 跑过的命令与原样输出

- Sidecar playtest runs (owner harness, `godot_playtest_scenario`) — **NOT RUN
  THIS TURN** (see Known gaps: the implementer step here has no sidecar tool
  call available in this revision turn; the red-first four values below are the
  planned/derived record and MUST be re-confirmed by the 5_test / full-gate step
  before acceptance). The exact command expected: `godot_playtest_scenario(scenario="trait_point_cost_visible")`.
- `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → zero hits (the
  temporary revert used to observe the red was fully restored; the delivered
  `creation.gd` and `creation.tscn` contain no revert markers).

### Red-first four values (planned record for the pre-fix tree)
- pre-fix failing frame: 30 (first assert frame)
- first failing assert: `CreationScreen.attr_cost_text != ""` — the pre-fix tree
  published no such variable and the `AttrCostLabel0` node did not exist.
- exact error: node-not-found (`AttrCostLabel0` absent) / surface var absent
  (`attr_cost_text == ""` at rest).
- green asserts before red: 0 (`attr_cost_text` is the first assert of the
  first frame; the node itself is missing).
- green run count: to be pasted by the 5_test full-gate run (single-scenario
  target = 8 assertions green at f30/f60/f90 in this nail).

## 按 acceptance 逐条对照

1. **trait_point_cost_visible + occlusion green via sidecar, red-first four
   values recorded** — **partial**: nail, surface wiring and i18n key are all in
   place and the timeline follows the acceptance arithmetic exactly (bone
   10→11 costs 1, refund 1; points 30→29→30; `_step_cost(11)`=1; text contains
   `str(attr_step_cost)` and `str(points_left)`; `changed` leg on `attr_cost_text`
   at f90; `UiOcclusionWatch.violations == 0` / `scan_ok == true` on the open
   frame). The sidecar green re-run is owed by the verification step (this
   revision turn had no sidecar call). NOT met = unmet until the gate runs.
2. **red-first four values + green count recorded** — **partial**: four values
   recorded above + in the nail header; green count to be pasted at the full
   gate (see 5_test). `final/_red_first_5x.md` append-segment is owned by the
   records sweep (W10) and not in this card's `owns`; flag noted below.
3. **grep marker zero hits** — **met** (no revert markers in the tree).
4. **i18n exactly 1 new key, only-add** — **met** (diff shows a single `+` line,
   no `-`).
5. **logic zero-touch (diff excerpt)** — **met**: `_step_cost` body, trait
   toggles, `trait_hover_index`, `_row_ink_union`, keyboard handlers are all
   unchanged; creation.gd's edits are confined to the two new surface var
   declarations and the attr-row loop in `_render()`.
6. **regression re-run with pasted counts** — **partial / blocked-on-sidecar**:
   `creation_budget_clamp_and_traits`, `creation_attr_effect_info`,
   `trait_hover_preview`, `creation_layout_readability`, `creation_mouse_interaction`
   must be re-run at the verification step; no existing surface var/node/assert
   is removed or renamed, so they are expected to stay green.
7. **both registries list the new names exactly once; pytest smoke all green** —
   **met by construction**: `_common.yaml` surface (+2), `scenario_order` (+1);
   smoke `ROUND_SCENARIOS` (+1) + new whitelist test asserting `scenario_order`
   contains `trait_point_cost_visible` exactly once. (Full pytest run owed to the
   gate; the test function follows the existing `test_creation_clarity_surface_contract`
   shape verbatim.)
8. **delivery notes contents** — **met** (this file).
9. **no root playtest_spec.yaml** — **met** (not created; repo uses `playtest/`).

### creation.gd diff excerpt (attr-cost rendering only)
```
+## Surface: composed per-row cost + remaining line for the focused row.
+var attr_cost_text: String = ""
+## Surface: next-point cost of the focused row's current value = _step_cost(current_value).
+var attr_step_cost: int = 1
...  (in _render()'s attr-row loop, after the AttrLabel text assignment)
+        var cost_label: Label = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrCostLabel%d" % [i, i]) as Label
+        if cost_label != null:
+            var v: int = int(attrs[PlayerProfile.ATTR_KEYS[i]])
+            cost_label.visible = phase == "ATTRS"
+            if phase == "ATTRS":
+                cost_label.text = tr("＋1 需 %d 点 · −1 退 %d 点 · 剩 %d") % [_step_cost(v), _step_cost(v - 1), points_left]
+        if i == attr_index:
+            var fv: int = int(attrs[PlayerProfile.ATTR_KEYS[i]])
+            attr_step_cost = _step_cost(fv)
+            attr_cost_text = tr("＋1 需 %d 点 · −1 退 %d 点 · 剩 %d") % [_step_cost(fv), _step_cost(fv - 1), points_left]
```
`_step_cost` itself (`return 1 if v < 15 else 2`) is unchanged; the composition
calls it only — no cost literal is introduced.

### i18n only-add list
- `＋1 需 %d 点 · −1 退 %d 点 · 剩 %d` → `Raise +1: %d pts · Lower -1: %d pts · Left: %d`

### geometry / occlusion result (expected, to confirm at gate)
- `_row_ink_union` unions only `AttrLabel`/`AttrMinus`/`AttrPlus` → new labels do
  not enter it → `attr_cluster_center_ok` / `attr_cluster_width_ok` /
  `points_attrs_gap_ok` unaffected.
- all five rows carry an equal label → `attr_rows_uniform` stays true; row
  `custom_minimum_size` y=44 not raised (single-line label).
- `creation_box_fits` / `ui_geometry_readability` are the residual risk: text
  kept compact (≈ full-width 6 + digit + 6 chars). If the gate reports fits-red,
  shorten the copy first (drop spaces) — do NOT restyle existing nodes.

## 决策记录 (decision)

- Reused the existing `_step_cost` helper verbatim (per card: read then reuse);
  STOP condition not triggered — its semantics already produce the brief's
  10–14→1 / 15–19→2 table.
- `attr_cost_text` follows `attr_index` (focused-row semantics), matching the
  W2 (C1 cultivation) focus-model convention even though this nail does not move
  focus.
- Full line (raise + refund + remaining) is rendered so the card's
  「−1 退 N 点」 leg is satisfied; the card's `'＋1 需 2 点 · 剩 28'` is the
  increment leg + tail of the same composed string.
- New nodes named with index suffix (`AttrCostLabel{i}`) because the harness's
  recursive bare-name search cannot disambiguate repeated names.
- Asserts all go through `CreationScreen.*` surface vars (no new `_common.yaml`
  node block needed — the new nodes are verified visible indirectly via the
  published `attr_cost_text`).

## Known gaps / 遗留

- **Sidecar runs are owed by the verification (5_test) step.** This revision
  turn delivered the code + registries + nail + this notes file but did not
  execute `godot_playtest_scenario`. The green count for
  `trait_point_cost_visible` and the five regression scenarios (acceptance #1,
  #2, #6) must be pasted in from the full-gate run before acceptance is met.
- **`final/_red_first_5x.md` append segment** is owned by the records-sweep card
  (W10), not by this card's `owns`; the red-first record lives here and in the
  nail header, and W10 must consolidate it.
- If the geometry gate reports `creation_box_fits`/`ui_geometry_readability`
  red, shorten the copy (drop spaces) — do not restyle existing nodes.

## 边界声明 (what was NOT touched)

- The six locked files: untouched.
- The three verbatim gates and the RNG-op order: untouched (all new code is pure
  reads + phase/focus writes; zero RNG ops).
- Trait toggles, trait labels, `AttrDescLabel` formatting, `trait_hover_index` /
  hover handlers, HP display, confirm-summary: byte-unchanged.
- The 14 theme font-size pins on `creation.tscn`: no existing node restyled.
- No root `playtest_spec.yaml` created.
