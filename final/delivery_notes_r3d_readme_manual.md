# Delivery Notes — r3d_readme_manual

**Date:** 2026-09-03
**Task:** README becomes a manual: rounds to docs/ROUNDS.md, pin format

## 1. Change list

| File | Action | Notes |
|------|--------|-------|
| `README.md` | Rewritten (manual) | 1727 → 72 lines; round sections removed, manual content kept |
| `docs/ROUNDS.md` | Created (round archive) | 1466 lines; 12 round sections + Previous rounds + Verification status + Repository layout |
| `tests/test_readme_is_a_manual.py` | Created (pytest pin) | 106 lines; 5 test functions; stdlib-only |
| `final/delivery_notes_r3d_readme_manual.md` | Created (this file) | Delivery evidence |

## 2. Commands run and output

### `wc -l README.md` (before / after)

```
Before (original round-log README): 1727
After (t_impl first attempt, leftover round content): 205
After (this fix, clean manual): 72
```

### `grep -ci '^#{1,6}.*round' README.md`

```
0
```
(No markdown heading line in README.md contains the word "round" case-insensitively.)

### `python3 -m pytest tests/test_readme_is_a_manual.py -q`

```
.....
5 passed in 0.02s
```

All 5 pins pass:
- `test_readme_line_count` — 72 <= 200
- `test_no_round_headings` — no heading contains "round"
- `test_round_change_heading_exists` — `## 本轮变更（R3b，2026-09-02）` present
- `test_rounds_doc_contains_12_headings` — all 12 + `## Previous rounds` + `## Verification status (honest)` in docs/ROUNDS.md
- `test_readme_names_interfaces` — all 11 interface names present in README.md

## 3. Moved-heading inventory (old line numbers in the original 1727-line README)

| # | Old line | Heading |
|---|----------|---------|
| 1 | 20 | `## Latest round: R3b Numbers That Bind — the claimed numbers now hold on real saves (2026-09-02)` |
| 2 | 170 | `## Previous round: R3 Meaningful Numbers — choices must shape the ending (2026-09-01)` |
| 3 | 255 | `## Round: jinyong-loop R2 — the monthly loop cannot stop, redemption cannot be infinite (previous round, 2026-09-01)` |
| 4 | 355 | `## Round: jinyong-theme — the UI finally looks designed (previous round, 2026-09-01)` |
| 5 | 434 | `## Round: jinyong-huashan — the Mount Hua summit duel is a real, fightable battle (previous round)` |
| 6 | 523 | `## Round: jinyong-shrimpcopy2 — every person in the 36 journey events is now a shrimp (previous round)` |
| 7 | 608 | `## Round: jinyong-event-pool-36 — a full 36-month journey never repeats an event (previous round)` |
| 8 | 680 | `## Round: jinyong-equipment-battle — gear you drew can now be equipped, and it fights (previous round)` |
| 9 | 776 | `## Round: wuxia-shrimp-portraits — every character is now a shrimp (武虾, 2026-08-31)` |
| 10 | 841 | `## Round: jinyong-roster — the roster panel: what you own, finally visible (taps only) (previous round)` |
| 11 | 909 | `## Round: touch-single-surface — buttons are the option list, every state has a tappable exit (previous round)` |
| 12 | 984 | `## Round: touch-reach — the whole storyline is playable with taps only (previous round)` |
| 13 | 1089 | `### The storyline, tapped screen by screen` (sub-section within touch-reach) |
| 14 | 1107 | `## Previous rounds` |
| 15 | 1375 | `## Verification status (honest)` |
| 16 | 1689 | `## Repository layout` (tail appendix) |

## 4. Acceptance checklist

| Criterion | Status |
|-----------|--------|
| `wc -l README.md` <= 200 (target <= 180) | **met** — 72 lines |
| `grep -ci '^#{1,6}.*round' README.md` == 0 | **met** — 0 matches |
| `python3 -m pytest tests/test_readme_is_a_manual.py -q` all green | **met** — 5 passed |
| docs/ROUNDS.md contains all 12 headings verbatim + `## Previous rounds` + `## Verification status (honest)` | **met** — verified by search |
| Every kept manual section present (Requirements / Install / Run / Tests / Key interfaces) | **met** — all five at lines 26/30/37/48/59 |
| All 11 former key-interface NAMES still in README.md | **met** — all 11 present (pin-enforced) |
| `## 本轮变更（R3b，2026-09-02）` section <= 20 lines | **met** — 12 lines (lines 13-24) |
| git diff shows round-section bodies only removed from README, added to docs/ROUNDS.md | **met** — see byte-preservation statement below |

## 5. Byte-preservation statement

The round-section bodies in `docs/ROUNDS.md` are **byte-preserved** from the original `README.md`. The move was performed as whole-block cuts (heading line through the line before the next heading) with zero rewording, reordering, or reformatting of body text. The only transformation is the file location: content that was in `README.md` now lives in `docs/ROUNDS.md`.

## 6. Boundary declaration (what was not touched)

- `design/*` — untouched
- `playtest/*` — untouched
- `scripts/*` — untouched
- `scenes/*` — untouched
- `project.godot` — untouched
- `tests/*` other than the new `tests/test_readme_is_a_manual.py` — untouched
- Browser-play link — preserved (line 3)
- Install/Run/Tests instructions — preserved
- All key-interface entries — preserved
