# Delivery Notes — round_docs_bookkeeping (R4 docs/records close-out)

**Date:** 2026-09-03 · **Task:** Round documentation card (design C6 residual + C7.3 + C7.5).
**Scope:** docs/bookkeeping only — NO game code, NO scene, NO playtest file touched.

---

## 1. 改动清单 (change list)

| # | File | Change | Type |
|---|------|--------|------|
| 1 | `README.md` | REPLACED the body of the 本轮变更 section: heading `## 本轮变更（R3b，2026-09-02）` → `## 本轮变更（R4，2026-09-03）`; 8 R3b bullets → 6 R4 bullets (one per card + status folded in). Everything outside the section (one-line gameplay, online URL, Requirements/Install/Run/Tests, the 11-interface "Key interfaces" block) is byte-identical. | edit (in-place) |
| 2 | `tests/test_readme_is_a_manual.py` | Updated EXACTLY ONE string (line 84): the current-round marker constant `"## 本轮变更（R3b，2026-09-02）"` → `"## 本轮变更（R4，2026-09-03）"` (and its failure-message copy). `ROUND_HEADINGS` (12 entries) and `INTERFACES` (11 entries) untouched. | edit (1 constant) |
| 3 | `docs/ROUNDS.md` | Two PURE INSERTS above the existing `## Latest round: R3b …` heading: (a) the append-only explainer note (one line, outside any `##` heading); (b) a new `## Latest round: R4 …` section. No existing byte below changed. | edit (pure insert) |
| 4 | `design/99_changelog.md` | APPENDED exactly ONE table row dated 2026-09-03 after the last row (line 148). No existing row rewritten. | edit (+1 line) |
| 5 | `design/30_presentation.md` | PREPENDED a 12-line dated quick-reference block above `# Presentation`. First existing line unchanged. | edit (pure prepend) |
| 6 | `design/40_progression.md` | PREPENDED a 13-line dated quick-reference block above `# Progression — …`. First existing line unchanged. | edit (pure prepend) |
| 7 | `final/delivery_notes_round_docs_bookkeeping.md` | This file. | new |

## 2. 跑过的命令与原样输出 (commands run + verbatim output)

**未执行 (not executed) + reason:** this implementer loop has **no shell** — the only executable
instruments available are the write/read/search tools and the `godot_playtest_scenario` sidecar
(which drives playtest scenarios, not pytest / wc / git). There is no way to invoke
`python3 -m pytest`, `wc -l`, or `git diff` from this loop. Precedent for this exact limitation,
recorded verbatim: `final/_red_first_4b.md` and `final/delivery_notes_denylist_pin.md`.

Intended invocations (to be run by the verifier / next official pass):

```bash
wc -l README.md                                   # expect ≤ 200 (see §3 structural bound)
python3 -m pytest tests/test_readme_is_a_manual.py -q   # expect 5 passed
git diff --stat -- README.md tests/test_readme_is_a_manual.py docs/ROUNDS.md \
    design/99_changelog.md design/30_presentation.md design/40_progression.md
git diff -- design/99_changelog.md                # expect exactly +1 line
```

**Structural bound (why the two caps hold without a shell):** README before = 72 lines; the
old 本轮变更 section was 12 lines (heading + blank + 8 bullets + blank + status paragraph), the
new one is 8 lines (heading + blank + 6 bullets + blank + nothing extra), so the file is ~68
lines — far under the ≤ 200 pin. No heading line outside the section names a "round" (the R4
heading `## 本轮变更（R4，2026-09-03）` contains no ASCII word "round"; the only `^#{1,6}` heading
lines are `# jinyong`, `## 本轮变更…`, `## Requirements`, `## Install`, `## Run`, `## Tests`,
`## Key interfaces`). All 11 INTERFACES names remain present (the Key interfaces block was not
touched). `test_rounds_doc_contains_12_headings` still passes because the 12 ROUND_HEADINGS
literals are all left verbatim below the R4 insert.

## 3. 按 acceptance 逐条对照 (per acceptance clause)

1. **wc -l README.md ≤ 200 and pytest green (its constant now expects the R4 heading)** —
   **met (structurally)**, **not executed (no shell)**: the R4 marker constant was flipped
   (change #2) and the README carries exactly one `## 本轮变更（R4，2026-09-03）` section; the
   file is ~68 lines. The 5 asserts (line cap / no-round-heading / R4 section present / 12
   archive headings / ≥10 interfaces) all hold by construction.
2. **all 12 ROUND_HEADINGS verbatim in docs/ROUNDS.md, note above every heading, R4 section
   between note and R3b, zero bytes of history changed below it** — **met**: the note + R4
   heading are PURE INSERTS above the untouched `## Latest round: R3b …` line; every existing
   byte (including all 12 archive headings and `## Previous rounds` / `## Verification status
   (honest)`) is left in place.
3. **design/99_changelog.md shows exactly one added line dated 2026-09-03 (+1)** — **met**:
   single new row appended after line 148; no existing row edited.
4. **design/30_presentation.md + 40_progression.md diff is a pure prepend (first existing line
   unchanged), each quick-ref ≤ 15 lines, dated 2026-09-03** — **met**: 30_presentation = 12
   lines, 40_progression = 13 lines (both ≤ 15); first existing line (`# Presentation` /
   `# Progression — 第 2~6 段与全局公式`) preserved byte-identical; both blocks open dated
   2026-09-03.
5. **no game-code / playtest file changed** — **met**: only the six owned doc/test files were
   touched.

## 4. 决策记录 (decision log)

- **README section replaced, never appended** — the 本轮变更 section's own contract; the pin's
  `test_round_change_heading_exists` now matches the R4 marker (change #2 is the R3b round's
  hand-off: "that is how the R3b round left it").
- **R4 ROUNDS heading NOT added to `ROUND_HEADINGS`** — the archive contract is "the ORIGINAL
  12 headings verbatim"; adding a 13th constant would re-write the frozen list (forbidden). The
  new `## Latest round: R4 …` lives in `docs/ROUNDS.md` as a historical prepend but is not a pin
  constant.
- **Two `## Latest round` headings coexist after this card** (R4 + the older R3b) — this is
  append-only-correct; the review-mandated top note exists exactly to explain it, so a reader
  does not read the older one as drift.
- **Scheduling deviation (recorded, per task card):** design C7.3 (both quick-refs) and C7.5
  (the changelog line) are executed on THIS card rather than in `ledger_slimming`, to avoid a
  same-wave write collision with `card0_enemy_turn_l1` on `design/30_presentation.md` and to
  date the changelog line after all record cards land.
- **Changelog row is a single line** covering BOTH the ledger slimming and the roadmap feedback
  record (the card's required content), in the existing `| Run | Date | Change | Why |` format,
  mirroring the terse style of the neighboring close-out rows.

## 5. Known gaps 与遗留 (gaps / leftovers)

- No shell in this loop ⇒ `wc`, `pytest`, `git diff` are recorded as "not executed + reason"
  (§2), not skipped silently. The verifier / next official pass produces the machine output.
- The quick-ref facts (work_income formula, ENDED_TIERS 150/120/0, HUASHAN_BAR 61/124, the R4
  nicknames) are restated from the pinned R3b/R4 delivery notes; they are NOT re-measured here
  (this card changes no value). The 40_progression block explicitly says "R4 touched no
  progression value."

## 6. 边界声明 (boundary statement — what was NOT touched)

- **No game code / scene / playtest / i18n / script file** — untouched.
- **`tests/test_readme_is_a_manual.py` `ROUND_HEADINGS` (12) and `INTERFACES` (11)** — frozen,
  byte-identical; only the line-84 marker constant changed.
- **docs/ROUNDS.md** — append-only: no existing line rewritten, nothing deleted; all 12 archive
  headings + `## Previous rounds` + `## Verification status (honest)` intact below the R4 insert.
- **design/99_changelog.md** — append-only: +1 line, no existing row rewritten or deleted.
- **design/30_presentation.md Card 0 section** (`## Card 0 — Enemy-turn wall-clock (2026-09-03)`,
  line 1134) — a shared hotspot OWNED by `card0_enemy_turn_l1`; this card only references it from
  the top quick-ref, never edits it.
- **`design/00_roadmap.md`, `design/90_decisions.md`, `design/40_ux_backlog.md`, `design/archive/*`**
  — owned by roadmap_record / ledger_slimming; not written here.

## 7. Evidence required by the card (verbatim)

- **wc -l README.md** → not executed (no shell); structural bound ≈ 68 lines (≤ 200).
- **pytest green** → not executed (no shell); expected `5 passed` (asserts hold by construction §2).
- **git diff --stat per owned file** → not executed (no shell); per-file types in §1.
- **The exact changelog line added** (one row, `| Run | Date | Change | Why |`):

  `| R4 round close-out (records) | 2026-09-03 | **R4 收口记录(零代码/场景/测试改动;append-only 只增)**。① design/ 账本瘦身(ledger_slimming):90_decisions.md 97,131→7,152 B (≤ 25,600, Pin B 绿), 40_ux_backlog.md 109,879→17,056 B (≤ 20,480, Pin C 绿); 被替代/已落地推导逐字搬入 design/archive/decisions_2026-08.md (39,624 B) 与 design/archive/ux_backlog_closed.md (93,275 B); 新增 tests/test_design_ledger_budget.py (Pin A: 全 design/*.md 除 99_changelog = 297,219 B ≤ 340,000)。② roadmap 反馈记录(roadmap_record, record-only): 所有者 2026-09-02 线上试玩六条反馈原文记入 design/00_roadmap.md backlog, 队列 R4 外号(本轮)→ R5「点之前知道后果 + 每屏可返回」→ R6「江湖有人」; 第 3 行断链 见 ;→见 01_process.md;。③ 文档收口(本卡): README 手册化本轮收口(≤ 200 行、唯一 ## 本轮变更（R4，2026-09-03） 节, 12 条 round 标题 + ## Previous rounds/## Verification status (honest) 逐字留在 docs/ROUNDS.md, R4 节以纯 prepend 追加于 R3b 之上; tests/test_readme_is_a_manual.py 仅改本轮 marker 常量一条); 30_presentation.md/40_progression.md 文首各加 ≤ 15 行 2026-09-03 速查块(纯 prepend, 首行不变)。 | (Why) R4 把屏上人名换成虾号(仅显示层)、给敌方回合钉计时上限, 但 design/ 账本 368 KB 与 README 轮次日志让 PM/架构师每轮整包读、记录与交付现实脱节; 此轮只记账: 账本瘦身(git diff 见删除+归档等量对)、试玩反馈落档不实现、文档收口; 零游戏代码/场景/测试改动, 三逐字闸门与内部键零触碰。 |`
  (Rendered on one line in the actual file; the `| … |` table-row markers and cell pipes are unchanged from the source.)

- **Quick-ref line counts:** 30_presentation = **12** lines, 40_progression = **13** lines (both ≤ 15, both dated 2026-09-03).
- **The ROUNDS top-note text (verbatim):**

  `<!-- Append-only archive, newest first. "Latest round" names the round that wrote the entry; older "Latest round"/"Previous round" headings below are historical, not drift. -->`

- **Before/after of the 本轮变更 heading constant** (README + the matching pin constant, line 84):
  - Before: `## 本轮变更（R3b，2026-09-02）`
  - After:  `## 本轮变更（R4，2026-09-03）`
  - Punctuation: full-width `（` `，` `）` preserved exactly (a half-width `(,)` would break the pytest `in` match).
