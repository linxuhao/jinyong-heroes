# Delivery notes — fix_c5_design_ledger_r5

> Date: 2026-09-04. Task: `fix_c5_design_ledger_r5` (C5 ledger completion, records-only).
> No code / scenario / test / registry changes. design/archive/*, the four existing R5 decision rows,
> the existing 2026-09-04 backlog record row, UX-14 status, and the three verbatim gates byte-untouched.
> No root `playtest_spec.yaml` created.

## 1. 改动清单 (files touched)

| File | Change |
|---|---|
| `design/99_changelog.md` | APPEND-ONLY: one fix-round row after the existing R5 row (line 150). No existing row edited/reordered. |
| `design/00_roadmap.md` | Current-position block (:18) updated to R5-done + next = 外号; queue prose line (:331) advanced. Numbered queue list (:251-278) NOT rewritten. |

| `design/40_ux_backlog.md` | UX-41 status cell OPEN → CLOSED(R5 fix round) with post-fix counts; one NEW dated record line appended to `## 记录`; **review fix**: CLOSED rows UX-36/37/38/39/41 moved out of the OPEN-only queue table (full text archived verbatim) to satisfy Pin C. Existing 2026-09-04 record row byte-untouched. UX-14 stays OPEN. |
| `design/archive/ux_backlog_closed.md` | **Review fix (reviewer-sanctioned route)**: the five CLOSED rows UX-36 / UX-37 / UX-38 / UX-39 / UX-41 appended **verbatim** to the archive's CLOSED-queue table, with a dated move note. This archive edit deviates from the card's "design/archive/* byte-untouched" boundary and was done on the explicit instruction of the t_impl_review verdict (primary sanctioned trim route); documented here and in the boundary section. |
| `design/90_decisions.md` | APPEND-ONLY: one new 2026-09-04 F4 ruling row after the four existing R5 rows. |
| `final/delivery_notes_fix_c5_design_ledger_r5.md` | This file. |

## 2. Before/after state of the four design files

### 2.1 `design/99_changelog.md`
- **Before:** 150 lines. Header `| Run | Date | Change | Why |` (line 7). Line 149 = R4 close-out (2026-09-03); line 150 = R5 main-round row (2026-09-04). Trailing newline present.
- **After:** 151 lines. One fix-round row appended after line 150. R4 (:149) and R5 (:150) rows byte-identical.
- **Appended row (quoted in full):**
  `| R5 fix-round (records reconcile) | 2026-09-04 | **R5 主轮之后的修复轮收口记录(零代码/场景/测试改动;append-only 只增;六文件锁 + 三逐字闸门 + RNG 生命线零触碰;主轮记录见上行 R5 行,本行只概括 fix 轮)**。① **F1 一行修复**(`fix_f1_event_option_effects_read`):`cultivation.gd:1108` 对 `EventData.EventOption`(RefCounted)的两参 `get("effects", [])` → 读类型化 `opt.effects` 属性,真实档 EVENT 后果渲染崩溃关闭;post-fix sidecar 复跑 `save_load_roundtrip` **14/14**、`consequence_event_option_visible` **9/9**、`event_phase_no_exit_reaffirmed` **8/8**、`event_travel_effects` **19/19**(来源 `final/delivery_notes_fix_f1_event_option_effects_read.md` sidecar 复跑)。② **F4 初始拜师单按恢复**(`fix_f4_sect_join_single_press`):初始拜师在**每条输入路径**(点击与键盘 `ui_accept` 一致,无 per-input-path 分支)恢复单按,三条逐字闸门回字节一致绿——`facility_use_reusable` **49/49**、`map_node_event_shaolin` **32/32**、`map_battle_node_huashan` **41/41**;重推导的 sect-select 钉 `sect_join_needs_confirm` **8/8**(硬闸门 passed: True)、`consequence_sect_select_focus` **10/10**、`map_facility_buttons_click` **38/38**、`action_yield_differential` **44/44**、`practice_target_receipt` **43/43**、`clicks_only_storyline` **47/47**(来源 `final/delivery_notes_fix_f4_sect_join_single_press.md` sidecar 复跑)。③ **stale pytest 常量修复**(`fix_stale_pin_constants`):README marker 字符串 + `consequence_work_income_inline` 差分 `: changed` 行;sidecar `consequence_work_income_inline` **10/10**(来源 `final/delivery_notes_fix_stale_pin_constants.md` sidecar)。④ **残余 geometry/baseline/split-bound 修复**:`back_button_year_end_zero_delta` **9/10 → 10/10**(f690 银两基线 `silver_before_accept` → `year_end_entry_silver`,性质「返回不改银两」不变;来源 `final/delivery_notes_fix_r5_year_end_silver_baseline.md` sidecar)、`creation_layout_readability` **23/23**(新增 f30 诊断断言,来源 `final/delivery_notes_fix_r5_creation_layout_regression.md` sidecar)、`enemy_turn_wall_clock` **14/14**(bounds 字节不变,来源 `final/delivery_notes_fix_r5_enemy_turn_split_bound.md` sidecar)。 | 修复轮把 R5 两按拜师打破的三条逐字闸门恢复为字节一致绿(单按是闸门为游戏钉的契约,不是为某条输入路径),并关闭 F1 的 EVENT 后果渲染崩溃;stale pytest 常量与残余 geometry/baseline/split-bound 一并收口;主轮记录 = 上行 R5 行,本行只记 fix 轮。 |`
- Run value contains `fix-round` (precedent = `R3b fix-round (records reconcile)` at :144). `navigation-and-consequence` appears once as a row-start Run value (the original :150 row).

### 2.2 `design/00_roadmap.md`
- **Before:** 338 lines. `:18` current-position block = `**当前位置(2026-08-30 校准):…**` (predates R5). `:331` queue prose = `R4 外号(本轮)→ R5「点之前知道后果 + 每屏可返回」(1/2/3/4 的入口)→ R6「江湖有人」(4 的功法量、5、6)。`
- **After:** 338 lines (both edits in-place, no line-count change). Numbered queue (:251-278) untouched — item 1 already `✅ R5 …` with `队列自第 2 项(外号)继续`.
- **`:18` block now reads (quoted):**
  `**当前位置(2026-09-04 校准):R5 navigation-and-consequence 已落地并经修复轮收口——C1 后果由数据渲染(遮挡网 `consequence_screens_occlusion` 62/62)、C2 软锁返回零差分(三钉 16/16·19/19·16/16)、C3 五相位可返回 + 确认、C4 战斗/结局只读角色面板(两钉 27/27)、战斗反馈钉绿;F1/F4 修复后三条逐字闸门回字节一致绿(49/49·32/32·41/41)。** 下一项 = **外号**(编号队列第 2 项,见下;R6「江湖有人」随后)。第 2 阶段(交互)与第 3 阶段(内容)是**并行**的,不是顺序推进——上面那张表没说清这一点,记在这里。`
  - Contains R5-done marker + one-line gate evidence; next = 外号 (consistent with the numbered queue's `队列自第 2 项(外号)继续`); does NOT say "当前 = R6"; keeps the two-phase-parallel sentence.
- **`:331` line now reads (quoted):**
  `R5「点之前知道后果 + 每屏可返回」(1/2/3/4 的入口)已落地(2026-09-04,见编号队列第 1 项)→ 下一项 **外号**(R4 遗留,编号队列第 2 项)→ R6「江湖有人」(4 的功法量、5、6)。`
  - No longer presents `R4 外号(本轮)` as the current position; the 本轮 marker is advanced to R5-done, next = 外号. Section header (:320) and the six verbatim feedback items (:324-329) byte-untouched.

### 2.3 `design/40_ux_backlog.md`
- **Before:** 58 lines. UX-41 row = line 48 (status `**OPEN** — 2026-09-04 官方闸门红入档…`). `## 记录` at :51; existing 2026-09-04 record row at :56. UX-14 at :28 (OPEN).
- **After (review fix applied):** the OPEN-only queue table keeps one short CLOSED pointer row per closed id; the five full CLOSED rows (UX-36 / UX-37 / UX-38 / UX-39 / UX-41) moved **verbatim** into `design/archive/ux_backlog_closed.md` (with a dated move note). UX-41 keeps a condensed but complete row in the current file: `**CLOSED(R5 fix round)**` status cell + the three post-fix counts (`save_load_roundtrip` **14/14**, `consequence_event_option_visible` **9/9**, `event_phase_no_exit_reaffirmed` **8/8**, plus `event_travel_effects` **19/19**), each labeled with its source. One NEW record line appended after the existing 2026-09-04 row (condensed in the review fix — the full detail lives in the changelog fix-round row). UX-14 unchanged (OPEN).
- **UX-41 status cell now reads (quoted):**
  `**CLOSED(R5 fix round)** — 2026-09-04 官方闸门红入档(sweep REV2 实测;归 owning C1 卡修,修复落树后 EVENT 后果面须并入遮挡网);**post-fix 实测已落**(来源 `final/delivery_notes_fix_f1_event_option_effects_read.md` sidecar 复跑):`save_load_roundtrip` **14/14**、`consequence_event_option_visible` **9/9**、`event_phase_no_exit_reaffirmed` **8/8**、`event_travel_effects` **19/19**`
- **Appended record line (quoted in full):**
  `- 2026-09-04 `R5 fix round`(post-fix 记录,5_design;证据 = 各 fix 卡交付说明 sidecar 复跑):**UX-41 → CLOSED(R5 fix round)**——F1 修复(`cultivation.gd:1108` 两参 `get` → 读类型化 `opt.effects`)落地后 post-fix sidecar 复跑 `save_load_roundtrip` **14/14**、`consequence_event_option_visible` **9/9**、`event_phase_no_exit_reaffirmed` **8/8**、`event_travel_effects` **19/19**(来源 `final/delivery_notes_fix_f1_event_option_effects_read.md` sidecar 复跑)。**F4 实际落地的裁决**:初始拜师在**每条输入路径**(点击与键盘 `ui_accept` 一致,无 per-input-path 分支)恢复**单按**——三条逐字闸门回字节一致绿(`facility_use_reusable` **49/49**、`map_node_event_shaolin` **32/32**、`map_battle_node_huashan` **41/41**),重推导的 sect-select 钉 `sect_join_needs_confirm` **8/8**(硬闸门 passed: True)、`consequence_sect_select_focus` **10/10**、`map_facility_buttons_click` **38/38**、`action_yield_differential` **44/44**、`practice_target_receipt` **43/43**、`clicks_only_storyline` **47/47**(来源 `final/delivery_notes_fix_f4_sect_join_single_press.md` sidecar 复跑);拜师屏的后果预览(C1)与返回路径(C3)保留。**残余 fix 收口**:`back_button_year_end_zero_delta` **10/10**(f690 银两基线重指向,来源 `final/delivery_notes_fix_r5_year_end_silver_baseline.md` sidecar)、`creation_layout_readability` **23/23**(来源 `final/delivery_notes_fix_r5_creation_layout_regression.md` sidecar)、`enemy_turn_wall_clock` **14/14**(来源 `final/delivery_notes_fix_r5_enemy_turn_split_bound.md` sidecar)、`consequence_work_income_inline` **10/10**(来源 `final/delivery_notes_fix_stale_pin_constants.md` sidecar)。UX-14 保持 **OPEN**(战前配装仍不存在)。`
- The existing 2026-09-04 record row (line 56) is byte-untouched. UX-14 status unchanged (OPEN).

### 2.4 `design/90_decisions.md`
- **Before:** 46 lines. Header `| 日期 | 范围 | 现行规则 | 证据指针 |` (line 7). Four R5 rows at :39-42. Trailing HTML comment at :44-45.
- **After:** 47 lines. One new F4 ruling row appended after the four R5 rows (before the trailing HTML comment). The four R5 rows byte-untouched. design/archive/* untouched.
- **Appended row (quoted in full):**
  `| 2026-09-04 | 拜师单按(R5 fix round) | 初始拜门在**每条输入路径**都是**单按**(点击与键盘 `ui_accept` 一致——无 per-input-path 分支;playtest-harness-injects-input 一类解法禁止),因为三条逐字闸门(`facility_use_reusable` 49/49、`map_node_event_shaolin` 32/32、`map_battle_node_huashan` 41/41,字节一致)为**游戏**钉住单按拜师,不是为某一条输入路径;让单按安全的是**点之前知道后果**(C1:拜师屏后果区在焦点/悬停时渲染加入给什么/花什么)与**返回路径**(C3:未提交时可见返回按钮、零状态差分);**年末改投保留两按确认**(无闸门钉它,且它是带代价的真实改投)。证据指针:三闸门计数 + 重推导的 sect-select 钉 `sect_join_needs_confirm` 8/8(硬闸门 passed: True)+ `final/delivery_notes_fix_f4_sect_join_single_press.md` | `playtest/facility_use_reusable` 49/49、`map_node_event_shaolin` 32/32、`map_battle_node_huashan` 41/41(字节一致,来源 `final/delivery_notes_fix_f4_sect_join_single_press.md` sidecar 复跑);`playtest/sect_join_needs_confirm` 8/8;`final/delivery_notes_fix_f4_sect_join_single_press.md` |`
- Covers all five required elements: single-press on every input path; three verbatim gates pin it for the game; C1 preview + C3 back make it safe; year-end switch keeps its two-press confirm; evidence pointers (49/49, 32/32, 41/41, re-derived sect-select nail, fix_f4 delivery note path).

## 3. UX-41 close citation (source-labeled counts)

UX-41 (opened for F1, the EVENT-option consequence crash) is CLOSED by the F1 fix. Post-fix counts cited in the status cell and the appended record line, each labeled with its source:
- `save_load_roundtrip` **14/14**, `consequence_event_option_visible` **9/9**, `event_phase_no_exit_reaffirmed` **8/8**, `event_travel_effects` **19/19** — source: `final/delivery_notes_fix_f1_event_option_effects_read.md` sidecar re-runs (lines 54-57: `[PASS] consequence_event_option_visible 9/9`, `[PASS] event_phase_no_exit_reaffirmed 8/8`, `[PASS] save_load_roundtrip 14/14`, `[PASS] event_travel_effects 19/19`).

## 4. F4 ruling row (90_decisions.md) — full text

Quoted in §2.4 above. All five required content elements present.

## 5. Budget test (review fix — honest state, measured)

**Before the review fix the budget pin was RED and the first delivery note's §5 misstated it.** Measured facts (per the t_impl_review verdict, which measured the delivered tree):

- `tests/test_design_ledger_budget.py` Pin C caps `design/40_ux_backlog.md` at **20,480 B** (UX_BACKLOG_MAX, test file line 41). The file was **22,819 B — over by 2,339 B** (Pin A ≈ 318,431 ≤ 340,000 passed; Pin B `90_decisions.md` 12,578 ≤ 25,600 passed; **Pin C failed**). The earlier "17,056 B, well under cap" claim in this note cited the stale R4-slimming figure and was wrong — the t_impl appends (UX-41 status-cell expansion + ~2.2 KB record line) pushed the file over.
- **Trim action taken (reviewer-sanctioned route):** per the file's own rule ("本文件只保留 OPEN 项") the five CLOSED rows UX-36 / UX-37 / UX-38 / UX-39 / UX-41 were moved **verbatim** into `design/archive/ux_backlog_closed.md` (review fix note appended there); the OPEN file keeps short pointer rows, and the UX-41 row keeps its CLOSED status + post-fix counts + sources in condensed form. The appended fix-round record line was also condensed (it duplicated the changelog fix-round row). Estimated removal ≈ 6 KB from the OPEN file (five full rows) — comfortably under the 20,480 B cap.
- **Pytest output: UNAVAILABLE in-harness.** This implementer has no shell tool, so `python3 -m pytest tests/test_design_ledger_budget.py -q` could not be literally executed, and no green output is fabricated. The pin is satisfiable by construction after the trim (archive files are not counted by the top-level Pin A; the OPEN backlog file's remaining content is well under Pin C), but **the test must be run at 5_compile**; if it still fails, the sanctioned fix is to trim prose in the non-changelog file further (never the changelog).
- Prior §5's claim of a green budget is **retracted** by this section; the real before/after is recorded here and above in §2.3.

## 6. 决策记录 (decisions made)

- **Next roadmap item = 外号, not R6.** The authoritative numbered queue (:251-278) already states `队列自第 2 项(外号)继续`; the current-position block and queue prose were reconciled to that, never writing "当前 = R6".
- **The R5 changelog row already existed** (:150); this card appended ONE fix-round row after it, not another R5 row.
- **UX-41 close cites sidecar counts** (fix_f1 delivery note), labeled as such — the official post-fix re-run is not yet on disk, so the close cites the freshest sidecar values per the stop-condition fallback.

## 7. Known gaps / 遗留

- The budget test output is not locally runnable (no shell); it must be run at 5_compile. All cited numbers are sidecar values from the fix cards' delivery notes (labeled), not official post-fix re-run numbers — the official re-run is pending.

## 8. 边界声明 (what was NOT touched)

- No code / scenario / test / registry file changed.
- `design/archive/*` — see §1: the ONE sanctioned deviation is the verbatim move of the five CLOSED backlog rows into `design/archive/ux_backlog_closed.md` (reviewer-instructed); nothing else in archive touched.
- The four existing R5 decision rows (90_decisions :39-42) byte-untouched.
- The existing 2026-09-04 backlog record row (40_ux_backlog :56) byte-untouched.
- UX-14 status unchanged (OPEN).
- The three verbatim gate files byte-untouched.
- No root `playtest_spec.yaml` created.
- The numbered roadmap queue list (:251-278) not rewritten.

## 9. Review fix (t_impl_review verdict, 2026-09-04)

The review verdict found one verified failure: the budget pin Pin C was RED on the delivered tree (`design/40_ux_backlog.md` 22,819 B > 20,480 B cap, over by 2,339 B) while this note's §5 asserted the file was "well under cap" using the stale 17,056 B R4-slimming figure. Fixes applied in this revision:

1. **Trim executed** (research_notes §6 / plan §6 mandated route): CLOSED rows UX-36 / UX-37 / UX-38 / UX-39 / UX-41 moved **verbatim** out of the OPEN-only queue table into `design/archive/ux_backlog_closed.md` (reviewer-sanctioned primary route; a dated move note was appended there — the sole archive edit, see §1/§8); the OPEN file keeps short pointer rows; UX-41 keeps its CLOSED status, the three post-fix counts, and their source label in condensed form; the appended fix-round record line was condensed (full detail remains in the `design/99_changelog.md` fix-round row).
2. **Delivery note corrected**: §5 now records the real measured before-state (22,819 B, Pin C failing, Pin A/Pin B passing) instead of the stale figure; the pytest green output is recorded as **unavailable in-harness** (no shell), with the test to be run at 5_compile — no fabricated output, no false green claim.
3. Everything the review listed as correct was NOT redone: the F4 ruling row, UX-41 close counts, roadmap :18/:331 edits, the single fix-round changelog row, and all source labels stand as delivered in t_impl.
