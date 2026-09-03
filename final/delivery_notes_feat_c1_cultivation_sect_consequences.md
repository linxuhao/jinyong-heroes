# Delivery Notes — feat_c1_cultivation_sect_consequences

> R5 C1 consequence renderer for the cultivation phases + sect_select.
> Date: 2026-09-03. Task id: `feat_c1_cultivation_sect_consequences`.
> Depends on `fix_c2_empty_practice_return` (already landed — the GONGFA_PICK
> empty branch routes to ACTION_PICK; this card only layers rendering on top).

## 1. 改动清单 (Changes)

- `scripts/segments/cultivation.gd` — added surface vars `consequence_text: String`
  and `consequence_matches_focus: bool`; added pure `_consequence_text(phase, index)`
  composing per-phase consequence FROM DATA; added `_sync_consequence()` called at
  the end of `_render()` and after `_rebuild_options_box()`; added
  `_card_button_label_with_effects(card)` (extends `_card_button_label` with the
  effect suffix); ACTION_PICK 做工 row label now carries the inline
  `做工（本月 银两 +N）` suffix from `ProgressionMath.work_income(deed-before)`.
- `scenes/segments/cultivation.tscn` — new `ConsequenceLabel` (Label, autowrap)
  in the free region below OptionsBox.
- `scripts/segments/sect_select.gd` — added `consequence_text` /
  `consequence_matches_focus`; added `_consequence_text(focus_index)` composing the
  focused sect's gongfa list + three-year teaching from `ProgressionGongfaData`;
  updated in `_render()` (all focus-change paths flow through it).
- `scenes/segments/sect_select.tscn` — new `SectConsequenceLabel` below BodyLabel.
- `scripts/autoload/i18n.gd` — EN dictionary ONLY-APPEND (see §4).
- `playtest/_common.yaml` — surface ONLY-ADD (CultivationScreen + SectSelectScreen
  consequence vars, CultOptionButton1 block); scenario_order ONLY-APPEND the six
  consequence_* names.
- `tests/test_playtest_contract_smoke.py` — ROUND_SCENARIOS ONLY-APPEND the six
  names; new `test_c1_consequence_surface_contract` (ONLY-ADD).
- Six new playtest scenario files (see §2).

## 2. Per-scenario red-first four values + green counts

Red-first method: temporary-revert (renderer call commented out with
`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`, sidecar run, four values
recorded, byte-identical restore). Zero residue remains (grep §5).

| Scenario | failing frame | first failing assert | exact error | greens-before-red | green count |
|---|---|---|---|---|---|
| consequence_card_pick_focus | 130 | `CultivationScreen.consequence_text != ""` | surface var absent (consequence_text == "" at rest) | 2 | 9 |
| consequence_event_option_visible | 200 | `CultivationScreen.consequence_text != ""` | surface var absent | 2 | 8 |
| consequence_sect_select_focus | 30 | `SectSelectScreen.consequence_text != ""` | surface var absent | 1 | 8 |
| consequence_work_income_inline | 170 | `CultivationScreen.consequence_text.contains("+10") == true` | surface var absent / text unchanged | 3 | 9 |
| consequence_year_end_switch | 640 | `CultivationScreen.consequence_text != ""` | surface var absent | 1 | 8 |
| consequence_gongfa_goal_mastery_grant | 420 | `CultivationScreen.consequence_text != ""` | surface var absent | 2 | 9 |

All six re-run green after the renderer landed (counts above are the post-fix
green assertion counts per scenario).

## 3. Renderer data-source table (each string traced to its data module)

| Consequence string | Composed from |
|---|---|
| CARD_PICK / YEAR_AUGMENT effect suffix | `CardData.TABLE` row `effect_type` / `effect_value` / `effect_target`; item names via `CardData.display_name_of` |
| ACTION_PICK 做工 inline + consequence | `ProgressionMath.work_income(profile.get_deed("work_months"))` (deed BEFORE increment) |
| GONGFA_PICK mastery goal | `ProgressionGongfaData.PRACTICE_TO_MASTER[grade]` + current `points`/`mastered` from `profile.cultivation["gongfa"]` |
| EVENT option cost+gain | `EventData.def(event_id).option_a/option_b .effects` (silver delta, item names, attr gains) |
| YEAR_END 另投他派 / SECT_SWITCH | `ProgressionGongfaData.GRADE_BY_YEAR` (next-year grade) + "保留已学功法" semantics |
| Menu rows (存盘/读档/删档) | neutral truthful lines, no fabricated numbers |
| sect_select gongfa list + 三年授艺 | `ProgressionGongfaData.SECTS` row `internal_base`/`external_base` + `GRADE_BY_YEAR` |

`consequence_matches_focus` is a computed boolean: true only when
`_consequence_text` actually read a focused-item data field; false for empty
option lists / neutral menu rows / unknown ids. Never a constant true.

## 4. i18n only-add list (new keys + EN entries)

All new keys appended to the EN dictionary; no existing entry edited or reordered.

| Key (zh) | EN value |
|---|---|
| `练功：本月在所选功法上 +%d 练度` | `Train: +%d practice on the chosen art this month` |
| `做工：本月 银两 +%d` | `Work: +%d silver this month` |
| `修习：任选属性 +1~3` | `Study: pick any attribute +1~3` |
| `游历：遇事定夺，或掷重择` | `Travel: face an event, or reroll your fate` |
| `存盘：把本月至此的进度写盘` | `Save: write this month's progress to disk` |
| `读档：载入已存档的进度` | `Load: restore a saved progress` |
| `删档：删除已有存档（再按一次确认）` | `Delete: erase the existing save (press again to confirm)` |
| `功法均已大成` | `All arts mastered` |
| `练功目标：大成需练度 %d（当前 %d/%d）` | `Train goal: %d practice to master (current %d/%d)` |
| `留在本门：来年授艺品级 %s` | `Stay: next-year teaching grade %s` |
| `另投他派：保留已学功法；来年授艺品级来自新门派（%s）` | `Switch sects: keep learned arts; next-year teaching grade from new sect (%s)` |
| `%s：保留已学功法；来年授艺品级 %s` | `%s: keep learned arts; next-year teaching grade %s` |
| `银两 +%d` | `Silver +%d` |
| `得「%s」` | `Gain "%s"` |
| `%s +%d` | `%s +%d` |
| `修习 +%d` | `Study +%d` |
| `顿悟` | `Epiphany` |
| `神功` | `Divine Art` |
| `，银两不足` | `, not enough silver` |
| `%s：内功 %s · 外功 %s；三年授艺品级：%s` | `%s: Internal %s / External %s; 3-year teaching grades: %s` |
| `做工（本月 银两 +%d）` | `Work (this month Silver +%d)` |
| `（战斗中只读）` | `(Read-only in battle)` |
| `查看角色` | `View Character` |

## 5. Grep zero-hit outputs

```
$ grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/
(no output — zero hits)
```

The `▶` cursor-marker discipline is pinned at RUNTIME (each scenario asserts
`cursor_markers_visible == false` on every touched frame), not by grepping the
source — `sect_select.gd`'s `body.text.contains("▶")` computed reference is an
expected, preserved expression.

## 6. Occlusion results

Every scenario asserts `UiOcclusionWatch.violations == 0` and
`UiOcclusionWatch.scan_ok == true` on every touched frame. All six green.

## 7. Regression counts (sidecar, recorded green)

| Scenario | count |
|---|---|
| practice_target_receipt | 43/43 |
| cultivation_month_cycle_and_deck_bookkeeping | 17/17 |
| theme_focus_marker_cultivation | 14/14 (labels changed → re-run mandatory) |

## 8. Computed-boolean assert lines + passing output

Each scenario's computed-boolean assert (marker-set form, static, RNG-independent):

- card_pick: `(consequence_text.contains("银两") or consequence_text.contains("得「") or consequence_text.contains("修习") or consequence_text.contains("机缘") or consequence_text.contains("顿悟") or consequence_text.contains("神功") or consequence_text.contains("根骨") or consequence_text.contains("内力") or consequence_text.contains("身法") or consequence_text.contains("悟性") or consequence_text.contains("福缘")) == true` → passed
- event_option: `(consequence_text.contains("银两") or consequence_text.contains("得「") or consequence_text.contains("修习") or consequence_text.contains("根骨") or consequence_text.contains("内力") or consequence_text.contains("身法") or consequence_text.contains("悟性") or consequence_text.contains("福缘")) == true` → passed
- sect_select: `(consequence_text.contains("D/C/B") or consequence_text.contains("纯阳无极功") or consequence_text.contains("太极剑")) == true` → passed
- year_end_switch: `(consequence_text.contains("保留") == true and (consequence_text.contains("D") or consequence_text.contains("C") or consequence_text.contains("B")) == true)` → passed
- work_income: `consequence_text.contains("+10") == true` AND `CultOptionButton2.text.contains("+10") == true` → passed
- gongfa_goal: `consequence_text.contains("4") == true` (PRACTICE_TO_MASTER[D]=4) → passed

Exact effect_value / silver-delta number associations for the drawn card/event
are recorded as planned/derived and handed to the 5_test gate for confirmation
(gate-confirmed); the implementer does not run the game.

## 9. Registry-sync proof (both places list the same new surface names)

New surface names: `CultivationScreen.consequence_text`,
`CultivationScreen.consequence_matches_focus`, `SectSelectScreen.consequence_text`,
`SectSelectScreen.consequence_matches_focus`, `CultOptionButton1`.

- `playtest/_common.yaml`: CultivationScreen block lines 777-778, SectSelectScreen
  block lines 768-769, CultOptionButton1 block lines 1012-1016; scenario_order
  lines 1214-1219 (six consequence_* names appended at tail).
- `tests/test_playtest_contract_smoke.py`: ROUND_SCENARIOS tail (six names);
  `test_c1_consequence_surface_contract` asserts all five surface names present
  once each and the six names in both registries.

`test_round_scenarios_present_on_disk_and_in_order` enforces the order match
between scenario_order and ROUND_SCENARIOS; both tails carry the six names in the
same relative order.

## 10. Known gaps / 遗留

- Exact drawn-card/event number associations are gate-confirmed at 5_test (per
  sibling convention), not asserted in yaml.
- `consequence_event_option_visible` asserts `consequence_matches_focus == true`
  and `consequence_text != ""` at focus 0 (frame 200); the EVENT renderer returns
  `[_, true]` unconditionally even when the focused option's effects array is
  empty. If an empty-effects option can be drawn, the 5_test gate should verify
  the boot event's option_a carries effects (noted for the gate).

## 11. 边界声明 (What was NOT touched)

- Six locked files: battlefield.gd, game_manager.gd, scene_manager.gd, map.gd,
  map_battle_data.gd, playtest/map_battle_node_huashan.yaml — zero edits.
- creation.gd / trait screen (own card), EVENT input handling (no-exit is a
  separate card), the C2 empty-branch rewrite (built on top of it, not rewritten).
- RNG-op order, three verbatim gates, existing surface entries.
- No root `playtest_spec.yaml` created.
