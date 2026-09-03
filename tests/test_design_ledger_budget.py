"""Design-ledger budget pin (R4 Card N+2 / design C7.6).

The design/ directory is re-read wholesale by the PM and architect every turn, so
its byte size is a real per-turn cost. This pin bounds that cost.

Stdlib-only pytest (pathlib). No shell, no subprocess, no network — the same shape
as tests/test_readme_is_a_manual.py (constant verbatim heading list + "heading in
text" archive-completeness check + observed-value failure messages).

Pin A (test_design_total_budget)
    Sum of file sizes over the TOP-LEVEL design/*.md (NON-RECURSIVE glob — matching
    the brief's `du -cb design/*.md` shell semantics, which never descends into
    design/archive/), EXCLUDING design/99_changelog.md, must be <= BUDGET_TOTAL_MAX.

    Honest arithmetic (the recorded design deviation, step2_design §6.2): the brief's
    literal `du -cb design/*.md <= 180 KB` is arithmetically UNSATISFIABLE under this
    round's own constraints — 99_changelog.md alone is 162,824 B and is append-only /
    never-rewritten, while 20_content.md (62,442 B), 30_presentation.md and
    40_progression.md are fenced by this same round ("content untouched, header only").
    Post-shrink floor excluding the changelog is ~= 319,091 B. So Pin A is rebased to
    340,000 B over top-level design/*.md MINUS 99_changelog.md. archive/ is excluded
    BOTH because the non-recursive glob skips it AND because it IS the moved history
    that Pin D guards — shrinking Pin A by emptying archive/ would be self-defeating.
    Widening the exclusions is forbidden; the glob may only grow tighter.

Pin B / Pin C: the two files this card actually shrinks (90_decisions, 40_ux_backlog).

Pin D: archive completeness — every heading moved OUT of the two source files must
    exist verbatim in its archive file. Constants are generated from what was moved.
"""

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DESIGN = REPO_ROOT / "design"
ARCHIVE = DESIGN / "archive"

BUDGET_TOTAL_MAX = 340_000  # Pin A: top-level design/*.md, non-recursive
DECISIONS_MAX = 25_600      # Pin B: design/90_decisions.md
UX_BACKLOG_MAX = 20_480     # Pin C: design/40_ux_backlog.md

# Pin A excludes this: append-only history (162,824 B), never rewritten.
EXCLUDE_FROM_TOTAL = {"99_changelog.md"}

# DESIGN_PINNED — the 10 headings moved verbatim out of design/90_decisions.md
# into design/archive/decisions_2026-08.md (Card N+2 / C7.1). Byte-identical to the
# source headings at move time (CJK punctuation, backticks, em-dashes included).
DESIGN_PINNED = [
    "## Out of scope",
    "## Open questions",
    "## jinyong-roster — 角色面板七裁定 (2026-08-30)",
    "## jinyong-equipment-battle — 角色面板只读保证被有意推翻(2026-08-31;取代 2026-08-30 jinyong-roster 裁定 (e))",
    "## 门派设施:定义、不变量与复用上限(2026-08-29,`jinyong-facility` 轮)",
    "## 武虾立绘落地:四个虾种裁定 + 画风换向(2026-08-31,项目所有者裁定)",
    "## 点击锚不再挂在 *_ClickTarget 上(2026-08-29,record_clicktarget_anchor_decision)",
    "## P0 根因:menu.tscn 的 SegmentHost 全屏 STOP(2026-08-28,interaction-defects)",
    "## 解析错误拉倒整轮验证(record_parse_lesson_and_reconcile, 2026-08-29)",
    "## R3c — WIN 裁决(C5,2026-09-02,项目所有者裁定,goal-loop iteration 3)",
]

# UX_PINNED — headings moved out of, or added as containers in, design/40_ux_backlog.md
# and now living in design/archive/ux_backlog_closed.md (Card N+2 / C7.2).
#   - "## 队列 — CLOSED 项"  : ADDED container for the 18 moved CLOSED rows (new heading)
#   - "## 记录"              : MOVED verbatim container from the source file
#   - the three "###" heads  : MOVED verbatim (blind-judge manual frame-read prose)
UX_PINNED = [
    "## 队列 — CLOSED 项",
    "## 记录",
    "### 战斗屏:好",
    "### 创建角色屏:两页都差,而这是新玩家看到的第一屏",
    "### 一条与语言有关的观察",
]


def _decisions_text() -> str:
    return (DESIGN / "90_decisions.md").read_text(encoding="utf-8")


def _ux_backlog_text() -> str:
    return (DESIGN / "40_ux_backlog.md").read_text(encoding="utf-8")


def _top_level_design_md_size() -> int:
    total = 0
    for path in sorted(DESIGN.glob("*.md")):
        if path.name in EXCLUDE_FROM_TOTAL:
            continue
        total += path.stat().st_size
    return total


def test_design_total_budget() -> None:
    """Pin A: top-level design/*.md (minus 99_changelog.md) <= 340,000 B."""
    total = _top_level_design_md_size()
    assert total <= BUDGET_TOTAL_MAX, (
        "design/*.md (excluding 99_changelog.md and the design/archive/ subtree) is "
        f"a per-turn read cost and must stay <= {BUDGET_TOTAL_MAX} B; found {total} B. "
        "Move superseded/landed or CLOSED content verbatim into design/archive/ — do "
        "not paraphrase or tighten it."
    )


def test_decisions_size() -> None:
    """Pin B: design/90_decisions.md <= 25,600 B (one-line-per-decision table)."""
    n = (DESIGN / "90_decisions.md").stat().st_size
    assert n <= DECISIONS_MAX, (
        f"design/90_decisions.md must stay a one-line-per-decision table <= {DECISIONS_MAX} B; "
        f"found {n} B. Move superseded/landed derivations verbatim to design/archive/decisions_2026-08.md."
    )


def test_ux_backlog_size() -> None:
    """Pin C: design/40_ux_backlog.md <= 20,480 B (OPEN items only)."""
    n = (DESIGN / "40_ux_backlog.md").stat().st_size
    assert n <= UX_BACKLOG_MAX, (
        f"design/40_ux_backlog.md must keep only OPEN items <= {UX_BACKLOG_MAX} B; "
        f"found {n} B. Move CLOSED items verbatim to design/archive/ux_backlog_closed.md."
    )


def test_moved_headings_archived() -> None:
    """Pin D: every moved heading exists verbatim in its archive file."""
    decisions_archive = (ARCHIVE / "decisions_2026-08.md").read_text(encoding="utf-8")
    ux_archive = (ARCHIVE / "ux_backlog_closed.md").read_text(encoding="utf-8")

    for heading in DESIGN_PINNED:
        assert heading in decisions_archive, (
            "design/archive/decisions_2026-08.md is missing a moved heading verbatim: "
            f"{heading!r}"
        )
    for heading in UX_PINNED:
        assert heading in ux_archive, (
            "design/archive/ux_backlog_closed.md is missing a moved heading verbatim: "
            f"{heading!r}"
        )


def test_moved_headings_absent_from_sources() -> None:
    """Pin D pair: the moved decision headings no longer appear in the slim sources."""
    decisions = _decisions_text()
    for heading in DESIGN_PINNED:
        assert heading not in decisions, (
            f"design/90_decisions.md still carries a superseded heading verbatim: {heading!r}. "
            "It should live only in design/archive/decisions_2026-08.md."
        )
