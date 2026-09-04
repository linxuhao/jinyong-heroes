# Delivery notes — fix_r5_creation_layout_regression (2026-09-04)

## 1. 改动清单
- `scenes/segments/creation.tscn` — `AttrCostLabel0..4` 的 `custom_minimum_size` 从 `Vector2(240, 0)` 改为 `Vector2(190, 0)`，与 `scripts/segments/creation.gd` 的 `const _ATTR_COST_CELL = 190` 一致（评审指出的 scene/const 不一致；此前 frame 1 由 `_sync_attr_cost_cells()` 静默改写，现改为源头一致）。`AttrCostSpacer0..4` 保持 `Vector2(190, 0)`、`mouse_filter = 2`、无文本，为各 `AttrRow{i}` 首子节点。
- `scripts/segments/creation.gd` — 本步**零改动**（fix 步已落地的等宽槽机制原样保留，见 §5 diff 判据）。
- 其余文件（`playtest/_common.yaml`、`playtest/creation_layout_readability.yaml`、`tests/test_playtest_contract_smoke.py`）在 fix 步已按 append-only 落地，本步零改动。

## 2. 跑过的命令与原样输出
`godot_playtest_scenario`（单场景探针，非闸门）：

```
[PASS] creation_layout_readability  23/23
[PASS] trait_point_cost_visible  16/16
[PASS] creation_budget_clamp_and_traits  11/11
[PASS] creation_attr_effect_info  7/7
[PASS] trait_hover_preview  21/21
hard gate passed: True

[PASS] creation_single_ui  16/16
[PASS] creation_mouse_interaction  14/14
[PASS] creation_traits_back_next_buttons  18/18
[PASS] creation_back_to_menu_walk  15/15
[PASS] creation_confirm_summary  13/13
[PASS] creation_hp_value_displayed  10/10
[FAIL] consequence_screens_occlusion  62/62
    RUNTIME ERROR: {"kind": "push_error", "msg": "aim: node not found: SectButton0 (spec: SectButton0)"}
```

## 3. 按 acceptance 逐条对照
1. **MET** — 测得红（本周期 playtest_summary.md，逐字）：`creation_layout_readability` **20/22**，f30 `CreationScreen.points_attrs_gap_ok` expr `points_attrs_gap_ok == true` observed **False**；`CreationScreen.attr_cluster_center_ok` expr `attr_cluster_center_ok == true` observed **False**。其余 20 条断言通过。
2. **MET** — 落地后 `creation_layout_readability` **23/23 绿**（新增 1 行 f30 诊断断言 `ink_cluster_center_x >= 474 and ink_cluster_center_x <= 486`，故 22→23；计数形式记 23/23）。
3. **MET** — `trait_point_cost_visible` **16/16 绿**（含按 `＋` 后 `attr_cost_text` 差分腿）；f30 `ink_cluster_center_x ∈ [474,486]` 由 23/23 中的该断言通过证实。
4. **MET** — 九条 creation 回归：`creation_budget_clamp_and_traits` 11/11、`creation_attr_effect_info` 7/7、`trait_hover_preview` 21/21、`creation_single_ui` 16/16、`creation_mouse_interaction` 14/14、`creation_traits_back_next_buttons` 18/18、`creation_back_to_menu_walk` 15/15、`creation_confirm_summary` 13/13、`creation_hp_value_displayed` 10/10。
5. **MET** — 见 §5 字节判据。测量代码（`_update_geometry_observables` / `_row_ink_union` / `_label_text_rect`）与 `attr_cost_text` 组合段零 diff；`creation_layout_readability.yaml` 相对上轮只有一行 `+`（f30 诊断线）。
6. **MET** — 见 §4/§6。
7. **MET** — 六个锁文件零 diff；仓库根无 `playtest_spec.yaml`；无 `# TEMPORARY RED-FIRST REVERT` 残留。

## 4. 测量量读码结论（fix 步行号，评审复核一致）
- `points_attrs_gap_ok`（creation.gd `:264-295`）：ATTRS 相位下 = PointsLabel 文本 rect 底 … `_row_ink_union(0)`（AttrLabel 文本 rect ∪ AttrMinus ∪ AttrPlus）簇顶的 y 间距 ∈ [4,24] px **且** 两个 x 中心差 ≤ 4 px。
- `attr_cluster_center_ok`（`:324-330`）：簇中心 x 是否落在布局中心（480）容差内。
- 回归机理：`AttrRow{i}` 是 HBox，无子节点带 `SIZE_EXPAND`（AttrLabel flags=3 无 expand，按钮 min=(44,34)），每子 rect == 其 combined minimum → 成本文本宽度变化把 AttrMinus/AttrPlus 整体左移，簇中心偏离 480。
- 修复形（评审复核的对称代数成立）：行 children = [Spacer, AttrLabel, AttrMinus(44), AttrPlus(44), AttrCostLabel]，4×6px 缝；簇 spans [spacer+6, spacer+label+106]，行 rect 收缩居中 —— 簇中心 == 480 **当且仅当 spacer == cost**。故左右等宽单元使成本槽宽度变化两侧对称抵消，簇中心钉回 480。
- 采用形记录：**跟随文本的等宽槽**（spacer 每帧同步 = cost label combined minimum.x，floor `_ATTR_COST_CELL = 190`），非常量槽退化形。190 为最长成本串（`＋1 需 2 点 · −1 退 2 点 · 剩 30` 形）像素宽之下限；若 EN 文案超宽，唯一改动点是 `_ATTR_COST_CELL`。

## 5. 字节判据 / diff 证明
creation.gd 允许改动集（fix 步落地，本步未再触碰）：`const _ATTR_COST_CELL`（:22）、两个 surface var 声明（:56-57）、`_sync_attr_cost_cells()`（:436-446）、`_process()` 内调用（:171）+ ATTRS 门控两 var 赋值（:180-184）。`_update_geometry_observables`（:203-406）/ `_row_ink_union`（:454-464）/ `_label_text_rect`（:415-426）/ `_render()` 成本文本组合段零 diff（评审逐行核实）。行 0 代数上代表全部五行（`attr_rows_uniform` 钉 ±1px），故 `_row_ink_union(0)` 即代表行；`ink_cluster_center_x/width` 语义与接口契约一致（以 attr_rows_uniform 钉为前提）。

本步唯一 diff（creation.tscn，5 处同形）：

```
-[node name="AttrCostLabel0" ...] custom_minimum_size = Vector2(240, 0)
+[node name="AttrCostLabel0" ...] custom_minimum_size = Vector2(190, 0)   # (…1..4 同形)
```

before/after rect 对照（每行相同）：Spacer 190→190（不变）、AttrCostLabel 240→190；运行时两者由 `_sync_attr_cost_cells()` 同帧对齐到 `max(190, 文本宽)`，五行一致（`attr_rows_uniform` 绿）。

行总 min 宽 ≈ 190+147+24+190 ≈ 551 px ≤ 560 预算；MouseBox 无可见边框，`creation_in_viewport` 读 MouseBox rect 而非行 rect，对称溢出不可见、不触发任何几何断言。

## 6. 遮挡结论
`consequence_screens_occlusion` **62/62 全部断言通过**（含创建屏成本行帧），`UiOcclusionWatch.violations == 0`、`scan_ok == true`。该 scenario 报 hard-fail 仅因一条与本卡无关的既有周期红：`push_error "aim: node not found: SectButton0 (spec: SectButton0)"`（与 clicks_only_storyline 的 "aim: node not found: CultOptionButton*" 同族，拜入确认流其闸门接线问题，已在周期级记录为不在本卡范围）。

## 7. Known gaps 与遗留
- `consequence_screens_occlusion` 的 SectButton0 hard-fail 属周期既有红，非本卡引入、非本卡可修（sect_select 点击锚接线）。62/62 断言通过。
- 周期级其他既有红（`save_load_roundtrip` cultivation.gd:1108 EventOption.get、RosterPanel equip 相关、`occlusion_no_button_over_text` 18/22）均不在本卡范围，未编辑。

## 8. 边界声明
未碰：`creation.gd`（本步零 diff）、trait toggles、AttrDescLabel、HP 显示、confirm summary、`attr_cost_text` 组合、14 处 theme 字号 pin、`creation_layout_readability.yaml` 既有断言（仅 fix 步追加过一行诊断）、六个锁文件、仓库根 `playtest_spec.yaml`（不存在）。
