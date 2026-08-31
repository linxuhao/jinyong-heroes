"""Shrimp-prose guard for the 36 journey events (jinyong-shrimpcopy2).

Scope: scripts/data/event_data.gd ONLY. The test mirrors are byte-pinned to
it by the GDScript suite, EN values are English, and every other file belongs
to the record-only human-prose sweep — not to this guard.

Denylists are token-level CJK substrings built from the PRE-edit corpus —
never character-level bans (手 appears inside legitimate 出手/身手 idioms).

Intent note: broad presence tokens (有人/无人/人声/人手) are pre-edit corpus
tokens scoped to event_data.gd. If a FUTURE row introduces one of them as a
"legitimate" description, this guard trips ON PURPOSE: every written person
must be re-attributed to a shrimp. Fix the prose, never 'fix' the guard.
"""
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "scripts" / "data" / "event_data.gd"

HUMAN_TOKENS = [
    # person-role nouns (pre-edit corpus inventory)
    "劫匪", "行商", "老丐", "掌柜", "郎中", "村民", "少年", "醉汉", "客商",
    "老僧", "老道", "药翁", "书贾", "失主", "刀主", "向导", "说书人", "剑客",
    "弟子", "艄公", "镖头", "头目", "巫师", "老铁匠",
    # person-presence / human-body phrases
    "之人", "有人", "无人", "人声", "人手", "招人", "寻人",
    "手提", "伸手", "手舞足蹈", "搭手", "揉着腰", "揉眼", "拍着胸脯",
]
UNDERWATER_TOKENS = [
    "游过去", "潜入", "水流", "海底", "水底", "下潜", "潜游",
    "洄游", "洋流", "珊瑚", "海藻", "鳃",
    # 泅水而过 (flood_ferry) is a land-world river-crossing feat — deliberately NOT banned.
]
SPECIES_TOKENS = [
    "皮皮虾", "螳螂虾", "龙虾", "小龙虾", "樱花虾", "罗氏沼虾", "玻璃虾",
    "枪虾", "濑尿虾", "对虾", "基围虾", "青虾", "明虾",
]
PROTECTED = [
    '"title": "崖上采药"',  # playtest #78 f200 pin
    '"重金购芝"',           # playtest #78 f210 pin
    '"泅水而过"',           # kept land-world river-crossing feat
    '"破财消灾"',           # _test_fresh_instances :383 (unchanged)
]


def _rows():
    """Return [(row_id, row_source)] by splitting the source on '"id": "'.
    Index 0 is the file preamble and is skipped."""
    text = SRC.read_text(encoding="utf-8")
    rows = []
    for part in text.split('"id": "')[1:]:
        row_id = part.split('"', 1)[0]
        rows.append((row_id, part))
    return rows


def test_no_human_tokens():
    hits = [(rid, tok) for rid, src in _rows() for tok in HUMAN_TOKENS if tok in src]
    assert not hits, "human-person tokens remain in event prose: %r" % (hits,)


def test_no_underwater_tokens():
    hits = [(rid, tok) for rid, src in _rows() for tok in UNDERWATER_TOKENS if tok in src]
    assert not hits, "underwater-rewrite tokens entered event prose: %r" % (hits,)


def test_no_species_tokens():
    hits = [(rid, tok) for rid, src in _rows() for tok in SPECIES_TOKENS if tok in src]
    assert not hits, "species names entered passerby prose: %r" % (hits,)


def test_protected_literals_present():
    text = SRC.read_text(encoding="utf-8")
    missing = [lit for lit in PROTECTED if lit not in text]
    assert not missing, "protected literals missing from event prose: %r" % (missing,)
