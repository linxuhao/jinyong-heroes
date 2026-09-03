"""README format guard (stdlib-only pytest).

The README is a *manual*, not a round log: hard cap 200 lines (target <= 180),
no markdown heading may name a "round", and exactly one ``本轮变更`` section
carries this round's summary. The round-by-round archive lives in
``docs/ROUNDS.md`` (append-only, one ``## `` heading per round). This pin is the
contract: it re-checks the cap, the no-round-heading rule, the presence of the
本轮变更 section, the 12 verbatim round headings in the archive, and that every
key-interface NAME is still named in the manual.
"""

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

README = REPO_ROOT / "README.md"
ROUNDS = REPO_ROOT / "docs" / "ROUNDS.md"

# The 12 round headings that MUST appear verbatim in docs/ROUNDS.md (the
# archive contract), embedded as constants — never guessed at read time.
ROUND_HEADINGS = [
    "## Latest round: R3b Numbers That Bind — the claimed numbers now hold on real saves (2026-09-02)",
    "## Previous round: R3 Meaningful Numbers — choices must shape the ending (2026-09-01)",
    "## Round: jinyong-loop R2 — the monthly loop cannot stop, redemption cannot be infinite (previous round, 2026-09-01)",
    "## Round: jinyong-theme — the UI finally looks designed (previous round, 2026-09-01)",
    "## Round: jinyong-huashan — the Mount Hua summit duel is a real, fightable battle (previous round)",
    "## Round: jinyong-shrimpcopy2 — every person in the 36 journey events is now a shrimp (previous round)",
    "## Round: jinyong-event-pool-36 — a full 36-month journey never repeats an event (previous round)",
    "## Round: jinyong-equipment-battle — gear you drew can now be equipped, and it fights (previous round)",
    "## Round: wuxia-shrimp-portraits — every character is now a shrimp (武虾, 2026-08-31)",
    "## Round: jinyong-roster — the roster panel: what you own, finally visible (taps only) (previous round)",
    "## Round: touch-single-surface — buttons are the option list, every state has a tappable exit (previous round)",
    "## Round: touch-reach — the whole storyline is playable with taps only (previous round)",
]

# 11 known key interfaces the manual must keep naming; >= 10 of these present.
INTERFACES = [
    "GameManager",
    "CombatManager",
    "SaveManager",
    "EventLogic",
    "BattleSetup",
    "ProgressionMath",
    "UiOcclusionWatch",
    "ThemeManager",
    "MapBattleData",
    "Coord",
    "GridManager",
]

_HEADING_RE = re.compile(r"^#{1,6}\s")


def _readme_text() -> str:
    return README.read_text(encoding="utf-8")


def _rounds_text() -> str:
    return ROUNDS.read_text(encoding="utf-8")


def test_readme_line_count() -> None:
    lines = _readme_text().splitlines()
    assert len(lines) <= 200, (
        f"README.md is a manual and must stay <= 200 lines; found {len(lines)}. "
        "Move round sections to docs/ROUNDS.md, do not grow the manual."
    )


def test_no_round_headings() -> None:
    offenders = [
        ln
        for ln in _readme_text().splitlines()
        if _HEADING_RE.match(ln) and "round" in ln.lower()
    ]
    assert not offenders, (
        "README.md (the manual) must carry no heading naming a round; found: "
        f"{offenders}"
    )


def test_round_change_heading_exists() -> None:
    assert "## 本轮变更（R4，2026-09-03）" in _readme_text(), (
        "README.md must carry exactly the 本轮变更（R4，2026-09-03） section."
    )


def test_rounds_doc_contains_12_headings() -> None:
    rounds = _rounds_text()
    for heading in ROUND_HEADINGS:
        assert heading in rounds, (
            f"docs/ROUNDS.md (the round archive) is missing heading verbatim: {heading!r}"
        )
    # The moved summary + status sections belong to the archive too.
    assert "## Previous rounds" in rounds
    assert "## Verification status (honest)" in rounds


def test_readme_names_interfaces() -> None:
    # >= 10 of the 11 known interface NAMES must remain in the manual.
    text = _readme_text()
    present = [name for name in INTERFACES if name in text]
    assert len(present) >= 10, (
        f"README.md must name >= 10 key interfaces; found {len(present)}: {present}"
    )
