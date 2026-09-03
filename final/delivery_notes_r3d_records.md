# Delivery Notes — r3d_records

**Date:** 2026-09-03
**Task:** Append changelog row + ROUNDS.md R3b close-out section (closing documentation pass, last in execution_order)

---

## 1. Change list

| File | Action | Lines added |
|------|--------|-------------|
| `design/99_changelog.md` | Appended exactly one row (line 147) | +1 |
| `docs/ROUNDS.md` | Appended one section at tail (after line 1466) | +9 |
| `final/delivery_notes_r3d_records.md` | Created (this file) | new |

No other file touched. Zero code, zero scenarios, zero test edits.

---

## 2. Cross-card outcomes table

| Card | Key measured numbers | Full evidence |
|------|---------------------|---------------|
| `r3d_readme_manual` | README 1727 → 72 lines; `grep -ci round` == 0; docs/ROUNDS.md 1466 lines (12 headings byte-preserved); format pin **5 passed in 0.02s** | `final/delivery_notes_r3d_readme_manual.md` |
| `r3d_trait_combat_regression` | Pre: **21/22** (f885 `moves_left == 0` observed 3, 21 greens before red); verdict **(b) real stat shift** (grid_pos (7,3) + moves_left 3 stable f875/f885/f895); mp = **6**, `move_range = 2 + floor(10/20) + floor(6/2) + 0 = 5`; new pin `moves_left == turn_start_moves_left - 2`; post-fix **22/22** (direct sidecar, hard gate passed, 0 runtime errors); `test_ending_gate_pins.py` no trait entry (grep zero matches) | `final/delivery_notes_r3d_trait_combat_regression.md` |
| `r3d_c5_honest_close` | Owner re-scope ruling 2026-09-03 (WIN → world-breadth round with 36/48 baseline); pre: **36/48** (f2100 `current_state` observed LOST, hero HP 0, West Poison active f1200, 35 greens before decisive red); tail re-anchored to `current_state == "LOST"` / `health < max_health` / `RetryButton.visible`; post-fix **47/47 PASS** (direct sidecar, hard gate `passed: true`, 0 runtime errors); `test_ending_gate_pins.py` huashan entry re-derived to honest-LOST form | `final/delivery_notes_r3d_c5_honest_close.md` |

---

## 3. Verbatim appended changelog row (design/99_changelog.md line 147)

```
| R3b close-out (records, iteration 4) | 2026-09-03 | **iteration-4 收口记录(零代码/场景/测试改动;append-only 只增)**。背景:官方复跑 **91/93** 绿、硬闸门 `passed: true`、pytest **67/67**、视觉通过;两条 advisory 红由本轮兄弟卡处理。① **README 手册化**(`r3d_readme_manual`):README **1727 → 72** 行(中间尝试 205 行被裁回);`grep -ci '^#{1,6}.*round' README.md` == **0**;12 条 round 标题 + `## Previous rounds` + `## Verification status (honest)` 全数移入新文件 `docs/ROUNDS.md`(**1466 行**、正文逐字节保留);README 保留唯一 `## 本轮变更（R3b，2026-09-02）` 节(**12 行**);格式钉 `python3 -m pytest tests/test_readme_is_a_manual.py -q` → **5 passed in 0.02s**。② **trait 钉重推导**(`r3d_trait_combat_regression`):`trait_combat_effects_and_twelve_slots` 官方运行 **21/22**(f885 `Player.moves_left` 断 `moves_left == 0` 实测 **3**、红前绿 21);诊断 = **branch (b) REAL STAT SHIFT**(grid_pos (7,3) 与 moves_left 3 在 f875/f885/f895 稳定,非时序漂移);推导:mp = **6**(ext-D + int-D + ext-C + int-C 大成;ext-B 4/8 未大成于 m26;a_dart f790 授予在练功窗口后)、agility 10、`move_range = 2 + floor(10/20) + floor(6/2) + 0 = 5`(C5 解锁杠杆 ③ `floor(mp/2)`,`battle_setup.gd:64`)、身轻如燕 slide 恰好耗 2 → 期望 `moves_left = 3` = 实测;新钉 `moves_left == turn_start_moves_left - 2` 替换旧字面 `moves_left == 0`(差分钉,零断言放松);修复后 **22/22 PASS**(直接 sidecar、硬闸门 `passed: true`、0 runtime error);`tests/test_ending_gate_pins.py` **无** trait 条目(grep 零匹配,文件未动)。③ **C5 诚实-LOST 收口**(`r3d_c5_honest_close`):2026-09-03 所有者重划裁决(`design/90_decisions.md` 追加):C5 的 WIN **移出 R3b**、携 **36/48 基线**转入 world-breadth 轮,五绝数据 + 解锁杠杆仍锁;R3b 的 C5 交付物 = 诚实 LOST 钉;场景尾部重锚到实测 LOST 态(`current_state == "LOST"` / `health < max_health` / `RetryButton.visible == true`);损失记录:hero HP **0**、**West Poison** 于 f1200 为活跃单位、**exact round at death not directly measured**(f1600 复合表达式在官方运行无法求值,已拆为两条独立键行);修复后 **47/47 PASS**(直接 sidecar、硬闸门 `passed: true`、0 runtime error、`spec_used: true`);`tests/test_ending_gate_pins.py` 仅 `huashan_winnable_normal_route` 条目重推导为诚实-LOST 形态(pytest 全绿)。**两项实测缺失(不补绿)**:exact round reached at death not directly measured;`battle_setup.gd:47` 文档注释 `floor(mp/3)` 与代码 `:64` `floor(mp/2)` 不一致(本轮禁改码,留待后续)。 | iteration-4 收口的唯一交付物是记录本身:把三张兄弟卡的实测数字折叠进 append-only 档案,使 5_review 从仓库直接读到;零代码零场景零测试改动,零断言放松,不冒充任何新绿。 |
```

**Cell count check:** The row splits on `|` into exactly 4 content cells (Run / Date / Change / Why). No bare `|` appears inside any cell (arithmetic uses `→`, `/`, `x`; no `A | B` constructions).

---

## 4. Verbatim appended ROUNDS.md section (appended after line 1466)

```
## R3b close-out record (2026-09-03)

R3b iteration-4 close-out (official run 91/93 green, hard gate passed, pytest 67/67, vision passed).
- C5: honest LOST close per the 2026-09-03 owner re-scope ruling — WIN carried to the world-breadth round with the 36/48 baseline; post-edit sidecar 47/47.
- trait_combat pin re-derived: verdict (b) real stat shift (mp = 6, move_range = 5); post-fix 22/22.
- README manualized: 1727 → 72 lines; format pin 5/5 passed.

Full record: `design/99_changelog.md` (2026-09-03 row) + `design/90_decisions.md` (2026-09-03 ruling).
```

Body lines (after heading): 7 lines. Well within the ≤ 10 limit.

---

## 5. Append-only self-attestation

**Method:** No shell available (no `git diff`, no `pytest`). Equivalent verification: baseline read via `read source="repo"` vs working-tree read.

### design/99_changelog.md
- Baseline (source=repo): 146 lines, last line ends with `记录与闸门现实一致,是本轮唯一交付物。 |`
- Working tree: 147 lines. Lines 1–146 are byte-identical to baseline (the edit tool replaces only the matched `old_str` span, appending the new row after it; all preceding content is preserved verbatim by the edit mechanism).
- Line 147 starts with `| R3b close-out` and contains `2026-09-03`. ✓

### docs/ROUNDS.md
- Baseline (source=repo): 1466 lines, last line is `- assets/ — placeholder textures, seed portraits, NotoSansSC font, audio`
- Working tree: 1475 lines. Lines 1–1466 are byte-identical to baseline (same edit mechanism: `old_str` was the last line only; replacement appends the new section after it).
- The 12 round headings, `## Previous rounds`, and `## Verification status (honest)` are all still present (they were never removed; tail append cannot delete). ✓

### Convention deviation (recorded per card instructions)
`docs/ROUNDS.md` header (lines 3–5) states "newest first / append new rounds at the top." This card mandates **tail append** with zero edits to moved content. The tail append was performed per card rule; the header and all moved bodies were left byte-untouched. This deviation is recorded here but not "corrected" in the file (appending to the top would require editing an existing line, which is forbidden).

---

## 6. Per-acceptance check

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Changelog: first 146 lines byte-identical; line 147 starts `| R3b close-out` and contains `2026-09-03` | **met** |
| 2 | Row yields 4 cells; no stray pipes; numbers only from siblings' notes | **met** |
| 3 | Row contains: README 1727→72 + 5 passed; trait 21/22→22/22 + f885 + mp=6 + move_range=5 + pin text; C5 36/48→47/47 + LOST + HP 0 + West Poison | **met** |
| 4 | Row records both absences: round-at-death not directly measured; battle_setup.gd:47 vs :64 unreconciled | **met** |
| 5 | ROUNDS.md: first 1466 lines unchanged; new section ≤ 10 body lines; points at both design files; all 12+2 headings still present | **met** |
| 6 | Delivery notes exist with three-row cross-card table and evidence paths | **met** |
| 7 | No claim reads as a measured Huashan WIN; C5 described as honest LOST close with WIN carried on 36/48 baseline | **met** |

---

## 7. Boundary declaration (what was NOT touched)

- `design/90_decisions.md` — owned by `r3d_c5_honest_close`, read-only here
- `README.md` — owned by `r3d_readme_manual`
- All `scripts/*`, `playtest/*.yaml`, `tests/*` — forbidden
- `design/40_progression.md` measured tables — forbidden
- Six-file lock, three verbatim gates — forbidden
- All existing changelog rows and moved round bodies in `docs/ROUNDS.md` — zero edits
