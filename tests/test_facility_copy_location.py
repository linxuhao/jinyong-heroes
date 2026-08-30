"""Static guard for the §433 copy-location rule.

design/20_content.md §433 (and the P2 facility design, Component 9) states that
facility/event prose lives ONLY in its data module (scripts/data/event_data.gd /
scripts/data/facility_data.gd), NEVER inline in scripts/data/map_data.gd or
scripts/segments/map.gd. That rule has exactly the same silent-failure shape as
the i18n one this file's sibling test guards: a violation renders Chinese
perfectly happily, so no runtime or import check can see it. The only signal
would be a reader noticing an anecdote sitting in the wrong file — invisible.

This guard makes the rule mechanical. It scans the two map files for
double-quoted GDScript string literals that are NOT inside a comment, counts the
CJK ideographs in the raw slice, and reddens on any prose-length literal (>= 4
CJK ideographs in the "一".."鿿" range — the same range
test_i18n_coverage._has_cjk uses) that is not in the ALLOWED allowlist below.
It is GREEN on day one: every literal that is legitimately in the two files
today is named in ALLOWED, so it catches only NEWLY inlined copy.

Why prose-length (>= 4 CJK) rather than "zero CJK"? A stricter "no CJK at all in
map_data.gd" variant needs exactly the same allowlist (the display_names and the
short tr() templates are CJK), so the extra strictness buys nothing — every real
violation is prose-length anyway. The < 4 CJK literals (此处 / 可前往 / 当前, the
display_names at <= 3) are allowlisted defensively so a future threshold
tightening does not move them; they are data identifiers and short chrome, not
narrative.

facility_data.gd is the sanctioned data module and is deliberately NOT scanned
by the first test; the second test cross-checks it the other way (no data-module
prose may be duplicated into the map files).

Deliberately stdlib-only and Godot-free, like the other static guards under
tests/, so it runs in the ordinary pytest pass with no Godot binary.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Only the two map files may NOT carry inlined prose. Both are read-only here.
FILES: tuple[Path, ...] = (
    ROOT / "scripts" / "data" / "map_data.gd",
    ROOT / "scripts" / "segments" / "map.gd",
)

# The sanctioned data modules. Read-only: their prose is the cross-check source.
DATA_MODULES: tuple[Path, ...] = (
    ROOT / "scripts" / "data" / "event_data.gd",
    ROOT / "scripts" / "data" / "facility_data.gd",
)

# A literal is "prose" once it carries this many CJK ideographs. The count
# interval is "一"(U+4E00) .. "鿿"(U+9FFF) — the same one test_i18n_coverage uses,
# so full-width punctuation (【】（）, ·, ▶) is never counted. That is why, e.g.,
# "▶ %s（此处）\n" counts as only 2 CJK.
PROSE_MIN_CJK = 4

# A double-quoted GDScript literal. Group 1 is the RAW slice between the quotes:
# a `\n` in GDScript source is two characters (backslash + n), and is matched by
# the \\. branch; the character class excludes \n so a match never spans source
# lines (GDScript has no triple-quoted / continuation strings).
_LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def _strip_comments(line: str) -> str:
    """Return ``line`` with any trailing ``#`` comment removed, honoring quotes.

    A per-character state machine: inside a double-quoted string, backslash
    escapes the next char and a ``#`` is literal; outside a string, the first
    ``#`` truncates the line. A naive ``line.split('#')[0]`` would silently drop
    a whole line whenever a legit literal happens to contain ``#`` — the guard
    would then miss it. GDScript has no triple-quoted strings, so per-line
    processing is safe.
    """
    out: list[str] = []
    in_str = False
    escaped = False
    for c in line:
        if in_str:
            out.append(c)
            if escaped:
                escaped = False
            elif c == "\\":
                escaped = True
            elif c == '"':
                in_str = False
        else:
            if c == "#":
                break
            if c == '"':
                in_str = True
            out.append(c)
    return "".join(out)


def _cjk_count(s: str) -> int:
    """Number of CJK ideographs in the "一".."鿿" interval."""
    return sum(1 for c in s if "一" <= c <= "鿿")


def _cjk_literals(path: Path) -> list[tuple[int, str, int]]:
    """All non-comment literals in ``path`` with >= 1 CJK ideograph.

    Two symbol-based skips (jinyong-roster 2026-08-30) remove roadmap-scope
    content forms so the guard asserts "no NEW inline prose position" without
    pinning their wording:
      * field-symbol: a line whose comment-stripped text contains
        ``"display_name":`` contributes no literals (covers NODES[*].display_name
        in map_data.gd; any future display_name field is covered by the same
        symbol, so a wording edit to a node name never reddens this gate).
      * block-symbol: a line matching ``ENDING_TIERS ... =`` opens a block
        whose literals are skipped until the first subsequent line whose
        lstripped content starts with ``]`` or ``}`` (the ENDING_TIERS tier
        titles/texts are roadmap-scope content — same stability rationale).

    Returns ``(1-based line number, raw slice, cjk count)`` triples.
    """
    out: list[tuple[int, str, int]] = []
    text = path.read_text(encoding="utf-8")
    in_ending_block = False
    for lineno, raw in enumerate(text.splitlines(), start=1):
        stripped = raw.lstrip()
        # block-symbol: inside the ENDING_TIERS block — skip until closing ]/}
        if in_ending_block:
            if stripped.startswith("]") or stripped.startswith("}"):
                in_ending_block = False
            else:
                continue
        # block-symbol: entering the ENDING_TIERS block
        if re.search(r"ENDING_TIERS\b.*=", _strip_comments(raw)):
            in_ending_block = True
            continue
        # field-symbol: display_name field lines contribute no literals
        if re.search(r'"display_name"\s*:', _strip_comments(raw)):
            continue
        for m in _LITERAL.finditer(_strip_comments(raw)):
            lit = m.group(1)
            c = _cjk_count(lit)
            if c >= 1:
                out.append((lineno, lit, c))
    return out


# Every prose-length CJK literal that is legitimately in the two map files today,
# written as Python RAW strings because each entry must equal the raw source
# slice: GDScript's ``\n`` is backslash+n (two chars), and a normal Python
# string would turn that into a real newline that never matches.
ALLOWED: frozenset[str] = frozenset({
    # --- scripts/segments/map.gd: the tr() render templates (map chrome, not
    #     narrative — the single-hint invariant, the travel-board labels).
    #     UI templates, not data rows: the 7 node display_names and the
    #     ENDING_TIERS tier titles/texts are NOT allowlisted here — roadmap-
    #     scope content, excluded by SYMBOL in _cjk_literals (2026-08-30) so a
    #     wording edit to a node name or ending line never reddens this gate. ---
    r"【%s】\n\n%s\n\n%s\n%s\n\n上下选择，回车定夺",
    r"【江湖行路】\n\n",
    r"▶ %s（此处）\n",
    r"  %s（可前往）\n",
    r"\n当前：%s",
    # --- sanctioned facility chrome (jinyong-facility 2026-08-29): the facility
    #     travel-hint template and the FACILITY-phase panel prompt / refusal.
    #     These are short directive/template strings (<= 12 CJK) that the §433
    #     data-module rule does not cover — the panel chrome is UI, not anecdote.
    #     Allowed so the guard stays green whichever order the sibling tasks
    #     land in; a narrative sentence is NOT allowed and would stay red. ---
    r"\n\n门派设施：%s（F 使用）",
    r"回车使用 · 上下离开",
    r"银两不足",
    # The FACILITY result-line template (facility_result_render, 2026-08-29). UI
    # chrome, not narrative: it is a format string composed from the def's own
    # effects plus the session use count. It exists in no data module, so
    # test_no_prose_duplicated_from_data_modules stays green alongside it.
    r"修炼有得（第 %d 次）：%s",
})


def test_no_inline_prose_in_map_files() -> None:
    """No prose-length CJK literal outside ALLOWED may sit in the map files."""
    bad: list[str] = []
    total = 0
    for p in FILES:
        for lineno, lit, cjk in _cjk_literals(p):
            total += 1
            if cjk >= PROSE_MIN_CJK and lit not in ALLOWED:
                bad.append("%s:%d: %s" % (p.relative_to(ROOT), lineno, lit))
    # Extraction sanity — without this a broken extractor makes the assert below
    # trivially green by finding nothing (the test_i18n_coverage._en_keys()
    # `len(keys) > 100` guard pattern). After symbol-exclusion (display_name
    # fields + ENDING_TIERS block skipped in map_data.gd), the two map files
    # yield 9 >= 1-CJK literals — all in map.gd chrome — measured 2026-08-30.
    # Never set this floor below 3: a broken extractor must never look plausible.
    assert total >= 9, "extraction found only %d literals" % total
    assert not bad, (
        "prose-length CJK literal in a map file outside the allowlist "
        "(§433: prose lives only in its data module):\n  " + "\n  ".join(bad)
    )


def test_no_prose_duplicated_from_data_modules() -> None:
    """No data-module literal may be copied verbatim into a map file.

    This is the §433 violation shape that ALLOWED cannot see: an implementer
    copies an event/facility sentence into map.gd AND adds it to ALLOWED, and
    the first test stays green. Comparing the raw slices of the two data modules
    against the map files closes that hole — it stays red even if the sentence
    was allowlisted. Today the two trees share no literal, so it is green on day
    one.
    """
    data_literals: set[str] = set()
    for p in DATA_MODULES:
        for _lineno, lit, cjk in _cjk_literals(p):
            if cjk >= 1:
                data_literals.add(lit)
    map_literals: set[str] = set()
    for p in FILES:
        for _lineno, lit, cjk in _cjk_literals(p):
            if cjk >= 1:
                map_literals.add(lit)
    dup = sorted(data_literals & map_literals)
    assert not dup, (
        "a data module's prose is inlined in a map file "
        "(§433: prose lives only in its data module):\n  " + "\n  ".join(dup)
    )
