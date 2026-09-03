"""Personal-name denylist pin for the display layer (R4 shrimp-nickname rename).

Guarantee: no personal name may appear in any display-layer string. The six
owner-locked personal names (杨过/黄药师/欧阳锋/段智兴/洪七公/王重阳) are
replaced on screen by shrimp nicknames (独臂大虾/东邪虾/西毒虾/南帝虾/北丐虾/
中神通虾) in the rename wave; this pin is the red-first guard that proves the
pre-rename tree still leaks them, and the green-after guard that proves the
rename removed them from every scanned display surface.

Denylist is token-level full names only — never single CJK characters (a single
char like 王 appears inside legitimate 王重阳 and other words) and never English
identifiers. 'East Heretic', 'Yang Guo', 'ProgressionHero', 'Sparring Partner'
are INTERNAL KEYS (character_name / node names / turn_order tokens) and are out
of scope by definition (owner ruling) — they are asserted byte-identical by the
three verbatim gates and must never be touched. Walk-on role nouns (侠客 /
陪练弟子) are not personal names; the rename wave coins their shrimp nicknames
and they never enter this list.

SCANNED (each with its reason):

- scripts/**/*.gd — STRING LITERALS ONLY. '#' comments are stripped before
  scanning via a per-line in-literal-state walk (see _extract_literals). Reason:
  scripts/ai/ai_{east_heretic,west_poison,south_emperor,north_beggar,
  central_divine}.gd line-1 '##' headers name canonical characters by design
  (e.g. "## AIControllerEastHeretic — 东邪黄药师 AI") and never render; the
  comment-stripping mechanism keeps them out WITHOUT editing those files. The
  walk is comment-aware: a quoted span inside a comment (e.g.
  scripts/ui/round_indicator.gd:22 '## "行动: 杨过 · 移动 4 ···· · 行动 ✓"')
  is dropped because the '#' comment start precedes the quote; a '#' inside a
  literal (e.g. scripts/autoload/i18n.gd:471 '"Cultivation gained (use #%d):
  %s"') does NOT truncate the literal, so the literal is scanned. Escaped
  double-quotes (\" ) inside a literal do not toggle state (e.g. i18n.gd:123
  'Press \"Continue\" or Enter...'). GDScript string literals do not span lines
  in this repo's scanned files, so per-line extraction is faithful.
  Single-quoted CJK literals were verified absent at pin-writing time
  (2026-09-03) by grep over scripts/**; a future `display_name = '...'` would
  be a false negative — the 'scope may widen' rule below is the mechanism that
  closes that gap.

- scenes/**/*.tscn — full text. Reason: scenes carry no personal names today
  (verified zero hits at pin-writing time); scanning keeps the invariant so a
  future scene edit cannot silently reintroduce a name.

- design/20_content.md — full text EXCEPT lines wrapped between the HTML
  comment markers '<!-- nickname-ruling-record -->' and
  '<!-- nickname-ruling-record-end -->'. Reason: this file is the roster/copy
  record that feeds the display layer, so it must be scanned; but the rename
  wave wraps its dated ruling record (which must quote the old names to be
  meaningful) in exactly those markers, and the carve-out keeps that record
  from tripping the pin. The carve-out supports MULTIPLE start/end marker
  pairs (each pair's span is skipped), so the rename wave can keep verbatim
  historical/derivation lines without rewriting records. If a start marker is
  found with no matching end marker before EOF, the test FAILS LOUDLY (raises)
  rather than silently skipping to end-of-file — a silent to-EOF skip would be
  a false-negative path. The markers do not exist yet; the carve-out is a no-op
  today (whole file scanned → red today).

EXCLUDED (each with its reason):

- tests/ — test fixtures legitimately quote names (e.g.
  tests/test_skill_button_states.gd input literals, red-first records).
- assets/ — off-screen inventory (assets/seed_manifest.json carries
  杨过(独臂神雕侠) as an asset-manifest note), per the brief.
- docs/ROUNDS.md and design/99_changelog.md — append-only round history
  quoting pre-rename names forever.
- design/90_decisions.md — records the owner ruling itself; it must quote the
  old names to be meaningful.
- design/00_roadmap.md, design/40_ux_backlog.md — task/queue records citing
  the ruling.
- design/30_presentation.md, design/40_progression.md — measurement/round
  logs.
- design/00_overview.md and design/10_systems.md — design NARRATIVE prose
  containing the names (13+ lines and :18/:129 respectively); never rendered on
  screen. These two are named explicitly so a later scope-widening does not
  silently trip the pin against files nobody may edit.
- remaining design/*.md — design narrative/ledger, never rendered.

Scope rule: this scope may WIDEN later; narrowing is forbidden. Adding a future
personal name = one list entry.
"""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

PERSONAL_NAMES = ["杨过", "黄药师", "欧阳锋", "段智兴", "洪七公", "王重阳"]

_START_MARKER = "<!-- nickname-ruling-record -->"
_END_MARKER = "<!-- nickname-ruling-record-end -->"


def _extract_literals(line: str) -> list:
    """Return the text of every double-quoted span NOT inside a comment.

    Per-line in-literal-state walk: toggle on each unescaped double-quote; a
    '#' starts a comment only when NOT inside a literal; once a comment start
    is seen, stop scanning the line. Escaped chars (\\x) inside a literal are
    skipped without toggling state and their escaped char is kept in the span.
    """
    spans = []
    in_literal = False
    buf = []
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if in_literal:
            if ch == "\\":
                if i + 1 < n:
                    buf.append(line[i + 1])
                i += 2
                continue
            if ch == '"':
                spans.append("".join(buf))
                buf = []
                in_literal = False
                i += 1
                continue
            buf.append(ch)
            i += 1
        else:
            if ch == "#":
                break  # comment start — stop scanning this line
            if ch == '"':
                in_literal = True
                i += 1
                continue
            i += 1
    return spans


def _scanned_lines():
    """Yield (relpath_str, 1_based_line_no, line_text) for every scannable line.

    For .gd files the yielded text is each double-quoted literal span (not the
    whole line), so a token inside a comment never trips the pin. For .tscn and
    design/20_content.md the yielded text is the whole line.
    """
    # scripts/**/*.gd — string literals only (comment-aware).
    for path in sorted((REPO_ROOT / "scripts").rglob("*.gd")):
        rel = path.relative_to(REPO_ROOT).as_posix()
        for ln, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for span in _extract_literals(line):
                yield (rel, ln, span)
    # scenes/**/*.tscn — full text.
    for path in sorted((REPO_ROOT / "scenes").rglob("*.tscn")):
        rel = path.relative_to(REPO_ROOT).as_posix()
        for ln, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            yield (rel, ln, line)
    # design/20_content.md — full text except marker blocks.
    path = REPO_ROOT / "design" / "20_content.md"
    rel = "design/20_content.md"
    in_marker = False
    for ln, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        has_start = _START_MARKER in line
        has_end = _END_MARKER in line
        if has_start:
            in_marker = True
        if has_end:
            in_marker = False
        if has_start or has_end:
            continue  # marker lines themselves are never scanned
        if not in_marker:
            yield (rel, ln, line)
    if in_marker:
        raise AssertionError(
            "design/20_content.md: unclosed %s marker "
            "(no matching %s before EOF)" % (_START_MARKER, _END_MARKER)
        )


def test_no_personal_names_in_display_layer() -> None:
    hits = [
        (rel, ln, tok)
        for (rel, ln, line) in _scanned_lines()
        for tok in PERSONAL_NAMES
        if tok in line
    ]
    assert not hits, "personal names in display layer: %r" % (hits,)
