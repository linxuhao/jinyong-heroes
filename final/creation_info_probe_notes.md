# Creation Info Probe Notes — pre-fix A-class absence baseline (UX-06/07/08)

**Task:** creation_info_probe (jinyong-clarity round, 2026-08-27). Probe-only — no code changes.
This probe is a structural read (code + scene + surface), not a runtime run: the pipeline t_impl has no shell, so no gate was run here — per hud_info_probe_notes.md §1/§4 the A-class red is provable by reading the repo. Every value below is a read fact, not a measured frame.

These notes record the **pre-fix A-class absence baseline** for UX-06/07/08 on the character-creation screen (`scenes/segments/creation.tscn` + `scripts/segments/creation.gd`), mirroring the `final/hud_info_probe_notes.md §1` discipline. The fix code (landed by the sibling `creation_info_labels` / `creation_clarity_scenarios` tasks) is **not** present on disk at write time; this file exists so the later delivery notes can prove the three information groups were absent before, present after, and are each pinned by a playtest assertion.

Explicit honesty note: **no gate was run in this task.** No `compile_report.json` / `playtest_report.json` / `playtest_summary.md` / `vision_report.json` / `test_report.json` was produced here. This is a structural read only — the A-class absence facts are decidable by reading the repo (hud_info_probe_notes.md §1 precedent). Live rendering / playtest verdicts are the job of the later `5_compile` gate, not of this probe.

---

## 1. `MouseBox/AttrBox/HpValueLabel` node absent

**Fact:** A `HpValueLabel` node does not exist under `MouseBox/AttrBox`.

**Evidence path:** `scenes/segments/creation.tscn` — full-file search for `HpValueLabel` returns **0 matches**. The `AttrBox` (`VBoxContainer`, node at L57) child list is exactly: `AttrRow0`..`AttrRow4` (L60–143), `AttrDescLabel` (L145–151), `AttrNavRow` (L153–161). There is no HP line label anywhere in the scene tree.

> UX-07 relevance: the ATTRS page shows only the formula string 「气血 = 根骨 × 5」 (inside `AttrDescLabel`, via `_ATTR_DESCS["bone"]`) with no current-HP value next to it. The player must do the mental math — exactly the information gap UX-07 records.

---

## 2. `MouseBox/ConfirmBox/ConfirmSummaryLabel` node absent

**Fact:** A `ConfirmSummaryLabel` node does not exist under `MouseBox/ConfirmBox`.

**Evidence path:** `scenes/segments/creation.tscn` — full-file search for `ConfirmSummaryLabel` returns **0 matches**. The `ConfirmBox` (`VBoxContainer`, node at L237) child list is exactly: `ConfirmButton` (L241–245) and `BackButton` (L247–251). There is no summary/checklist label showing the final attribute values.

> UX-08 relevance: the CONFIRM page carries only `ConfirmButton` (「确认踏上江湖」) and `BackButton` (「返回」) — no per-attribute final-value list to review the build before committing. Exactly the information gap UX-08 records.

---

## 3. `hp_value` / `hp_text` / `confirm_summary_text` observables absent

**Fact:** None of the three observables exists on `creation.gd` or on the `CreationScreen:` surface block of `playtest/_common.yaml`.

**Evidence path (path-qualified, per hud_info_probe_notes §1):**

- `scripts/segments/creation.gd` — full-file search for `hp_value`, `hp_text`, `confirm_summary_text` returns **0 matches**. The file's only surfaced vars are: `phase` (L25), `points_left` (L28), `attr_index` (L31), `attrs` (L34), `trait_index` (L36), `trait_ids` (L39), `confirmed` (L42), `pressed_connected` (L49), `cursor_markers_visible` (L56), and the Round-2/3 geometry observables (L64–82). No HP or confirm-summary derivation exists.
- `playtest/_common.yaml` — the `CreationScreen:` block (L588–610) whitelists `phase`, `points_left`, `attr_index`, `attrs`, `trait_ids`, `confirmed`, `cursor_markers_visible`, `pressed_connected`, and the geometry observables through `desc_alignment_ok` (L610). None of `hp_value` / `hp_text` / `confirm_summary_text` is present in that block.

**Path-qualification note:** `hp_text` and `hp_value` DO exist on disk — but only on the **`HealthBar`** block of `playtest/_common.yaml` (L561–562) and on `scripts/ui/health_bar.gd`. That is the **battle-HUD screen** (UX-05), not the creation screen. The evidence above is scoped to `creation.gd` + the `CreationScreen:` surface block; a naive whole-file search would false-positive on the HUD block.

> UX-06/07/08 relevance: because none of these observables exists on the creation surface, no playtest assertion could possibly pin the new displayed information (current HP, per-attribute effects, confirm summary) — an A-class absence by structure, provable by reading the repo.

---

## 4. `AttrDescLabel` shows only the focused attribute's desc at rest (UX-06 baseline)

**Fact:** At rest (phase == `"ATTRS"`, default `attr_index == 0`), `AttrDescLabel` renders **only the focused attribute's description** — `_attr_desc("bone")` = 「气血 = 根骨 × 5」 — not all five attributes' effects.

**Evidence path:** `scripts/segments/creation.gd` `_render()` L604–608:

```gdscript
var attr_desc_label: Label = get_node_or_null("MouseBox/AttrBox/AttrDescLabel") as Label
if attr_desc_label != null:
	attr_desc_label.visible = phase == "ATTRS"
	if phase == "ATTRS":
		attr_desc_label.text = _attr_desc(PlayerProfile.ATTR_KEYS[attr_index])
```

`attr_index` defaults to `0` (L31), `PlayerProfile.ATTR_KEYS[0]` is `"bone"`, and `_ATTR_DESCS["bone"]` (L17) = 「气血 = 根骨 × 5」. So the at-rest desc slot shows the single bone formula. The other four rows (内力 / 身法 / 悟性 / 福缘) show only `name value` — their effect meanings (`_ATTR_DESCS["inner"|"agility"|"wisdom"|"fortune"]`) never appear at rest and only surface one-at-a-time as `attr_index` cycles. That is the UX-06 finding.

**Render-state vs author-state:** in `creation.tscn` L145–151, `AttrDescLabel` is authored with `visible = false` (L148). "At rest" above means the **render state** (phase == `"ATTRS"` ⇒ `_render()` sets `visible = true`), not the author-time default. This matches the playtest surface, which reads the live `AttrDescLabel` node.

---

## 5. `points_attrs_gap_ok` CONFIRM cluster resolves to `ConfirmButton.get_global_rect()` (pre-fix)

**Fact:** In the `points_attrs_gap_ok` computation, the CONFIRM-phase first-row ink cluster is resolved as `MouseBox/ConfirmBox/ConfirmButton.get_global_rect()` — this is the measured quantity the later `creation_info_labels` task re-points at a new `ConfirmSummaryLabel` rect.

**Evidence path:** `scripts/segments/creation.gd` `_update_geometry_observables()` L208–211:

```gdscript
"CONFIRM":
	var gap_confirm: Button = get_node_or_null("MouseBox/ConfirmBox/ConfirmButton") as Button
	if gap_confirm != null:
		cluster = gap_confirm.get_global_rect()
```

The PointsLabel text bottom → first-row cluster top gap ∈ [4, 24]px fact (with x-centers within 4px) is computed at L214–217. Because `ConfirmBox` today has no first child other than `ConfirmButton` (see §2), the button rect is the first-row ink cluster. Once a `ConfirmSummaryLabel` is inserted as `ConfirmBox`'s first child, the gap arm must re-point this cluster at the summary label's rect to keep the same observable + same yaml assert lines green (the jinyong-layout-r2 measured-quantity-change precedent) — but **that change is not present here; this is the pre-fix value.**

---

## Verbatim source contracts (quoted from `creation.gd` — do not paraphrase)

The five `_ATTR_DESCS` entries, exactly as authored (L16–22), including `÷`, `×`, and full-width parentheses:

| key | `_attr_label` (L639–651) | `_ATTR_DESCS` (L16–22) |
|---|---|---|
| `bone` | 根骨 | 气血 = 根骨 × 5 |
| `inner` | 内力 | 内力值 = 内力 × 2 |
| `agility` | 身法 | 移动力 = 2 + 身法 ÷ 20(向下取整);先攻 = 身法 |
| `wisdom` | 悟性 | 决定学功法的速度(修习查表) |
| `fortune` | 福缘 | 影响事件与奇遇(游历事件可重掷) |

These are the existing, in-repo source strings for UX-06's effect text. The fix must **reuse/extend** them verbatim — never invent new wording (no-invention hard rule). No attribute is missing an effect definition here, so no content gap is expected to be recorded in `design/20_content.md`.

---

## Honest limits

- **No gate was run in this task.** This is a structural read (code + scene + surface), not a runtime boot; the pipeline t_impl has no shell, so no Godot frame was executed and no measured value is claimed. Every number above is a read fact from the repo at write time.
- **Structural read ≠ rendered ink.** The A-class absence facts are decidable by reading (nodes/observables simply do not exist), but the **post-fix** live rendering, the `points_attrs_gap_ok` re-pointed gap, and the playtest verdicts are the job of the later `5_compile` gate (its `playtest_report.json` / `playtest_summary.md` per-scenario counts), not of this probe.
- **This file records absence only — no fix suggestion, no new copy, no numeric judgment.** Its only purpose is the honest pre-fix baseline that the sibling tasks' delivery notes consume. The pre-existing `final/creation_probe_notes.md` (the Round-2/3 leaf-ink probe) is a different, unrelated artifact and was not modified.
