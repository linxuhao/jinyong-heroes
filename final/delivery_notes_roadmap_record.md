# Delivery Notes — roadmap_record (R4, record-only)

Date: 2026-09-03 · Task: `roadmap_record` · Type: **record-only, zero game code**

Two text edits, both inside `design/00_roadmap.md`:
1. **EDIT 2** — fixed the broken line-3 link (`见 ;` → `见 01_process.md;`). One token inserted; all other bytes of the line unchanged.
2. **EDIT 1** — appended the owner's six 2026-09-02 playtest-feedback items verbatim + the R4→R5→R6 queue line into the backlog region (immediately after the UX-36 row, before `## 参考`). Append-only; no existing roadmap content reflowed or rewritten.

---

## 1. Per-item read-back proof (each line quoted with its line number, verbatim vs contract)

Read back from the working tree after the edit. File now totals 330 lines. Each line below is byte-identical to the contract string in the task card (full-width parentheses, 「」 quotes, em-dash `——`, semicolons preserved).

| # | line | read-back text |
|---|------|----------------|
| 1 | 316 | `1. 选项不给介绍:点按钮之前只看到名字,不知道效果(参照 Europa Universalis:每个按钮写明点了之后的后果)。` |
| 2 | 317 | `2. 没有可练功法时原本可返回重选,现在变成「度过本月」烧掉一个月 —— 裁决:应能返回,不该 skip。` |
| 3 | 318 | `3. 很多页面没有返回上一页(如修习,进去就不能反悔)。` |
| 4 | 319 | `4. 功法太少;装备/人物/功法栏看不到(入口不可达或无标识)。` |
| 5 | 320 | `5. 没有其他战斗、没有其他 NPC;养成期与大地图期都应有战斗。` |
| 6 | 321 | `6. 养成期一个月一次行动太少。` |

All six items are located inside the appended block under header `### Owner 试玩反馈(2026-09-02 线上试玩)—— 2026-09-03 记录,logged **NOT implemented**` (line 312), placed immediately after the UX-36 backlog row (line 310) and before the `## 参考` heading (line 325). Insertion anchor honored exactly — the block was NOT appended to file end (which would have fallen below `## 参考`).

## 2. Queue line (verbatim)

Appears at line 323, byte-identical to the contract string:

```
R4 外号(本轮)→ R5「点之前知道后果 + 每屏可返回」(1/2/3/4 的入口)→ R6「江湖有人」(4 的功法量、5、6)。
```

## 3. Broken link — full before/after of line 3

Located by content anchor (`> **循环与排序规则**` prefix), not by line number.

- **Before (line 3):** `> **循环与排序规则**(一轮怎么跑、两件事同等紧急时先做哪个)见 ;本档只定阶段顺序。`
- **After  (line 3):** `> **循环与排序规则**(一轮怎么跑、两件事同等紧急时先做哪个)见 01_process.md;本档只定阶段顺序。`

Exactly one token `01_process.md` was inserted between `见 ` and `;`. Every other byte of the line is unchanged. The line now contains `见 01_process.md;` per acceptance criterion (3). `design/01_process.md` exists in the tree.

## 4. Change-file inventory (derived from this implementer's own create/edit calls)

Files touched by this task — exactly two:
- `design/00_roadmap.md` (EDIT 1 + EDIT 2)
- `final/delivery_notes_roadmap_record.md` (this file, new)

No other file was created or edited by this card. The pre-existing blank line between the UX-36 row and `## 参考` is preserved (relocated to sit after the appended block), so the six items were never merged into the reference section.

## 5. Acceptance cross-check (against the card's `acceptance`)

| acceptance | status | note |
|---|---|---|
| (1) six item strings byte-verbatim in 00_roadmap.md, delivery note lists proof one line each | **met** | §1 table, lines 316–321 |
| (2) queue line appears verbatim | **met** | §2, line 323 |
| (3) line 3 contains `见 01_process.md;`, other bytes unchanged, full before/after shown | **met** | §3 |
| (4) git diff touches `design/00_roadmap.md` ONLY (+ delivery note) | **met (by inventory)** | §4; git diff itself not executed — see §6 |
| (5) zero game-code / playtest / backlog-status changes | **met** | only two text edits in one design doc; no `design/40_ux_backlog.md` CLOSED flip, no playtest scenario created |

**met** on all five criteria.

## 6. Honest git-diff declaration

git diff not executed — this implementer has no shell/git access. The authoritative diff is produced by `repo_apply` (`git add -A`) / the `5_review` step. The change-file inventory in §4 is derived from this card's own `create`/`edit` tool calls, which touched exactly `design/00_roadmap.md` and `final/delivery_notes_roadmap_record.md`.

## 7. Decision records

- **Annotation header wording:** the six items and queue line are contract-locked verbatim; the surrounding header/prose lines (312, 314) are my framing text required by the card ("Mark the block as owner feedback recorded 2026-09-03, logged NOT implemented: R5 covers 1/2/3 and 4's entry; R6 covers 4's gongfa volume plus 5 and 6"). Framing text is not itself verbatim-contracted; only the six numbered lines and the queue line are, and those are byte-identical.
- **Position within file:** inserted as its own `###` sub-section under the backlog area (after UX-36, before `## 参考`) rather than appended to the table rows, so the numbered list is not misparsed as markdown-table content. This satisfies "append to the backlog section" while respecting "APPEND only — never rewrite or reflow existing roadmap content."

## 8. Known gaps / leftover

None for this card. Items remain explicitly **NOT implemented** (record-only), deferred to R5 (items 1/2/3 + 4's entry points) and R6 (item 4's gongfa volume + items 5/6) per the owner's queue.

## 9. Boundary statement (what was NOT touched)

- No game code (`scripts/**`), no scene files (`scenes/**`).
- No playtest files (`playtest/**`) — no scenario created for these six items.
- No other design file: `design/99_changelog.md` (round_docs_bookkeeping's), `design/90_decisions.md` / `design/40_ux_backlog.md` (ledger_slimming's) untouched.
- No backlog item flipped to CLOSED.
- The three verbatim-protected gates untouched.
- Existing content of `design/00_roadmap.md` other than line 3 (link fix) and the appended block (EDIT 1) is byte-for-byte unchanged.
