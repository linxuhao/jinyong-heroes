"""Static smoke test for the playtest contract — the 5_test pytest gate's real test.

This module gives the pytest gate at least one genuine, deterministic, pass/fail
signal (flipping ``no_tests_collected`` to false) WITHOUT invoking Godot: it
statically verifies the integrity of the playtest contract in
``playtest/_common.yaml`` against the scenario files on disk.

Scope (deliberately narrow):
  * scenario_order <-> scenario-file completeness
  * the six scenarios of this round present on disk AND listed in order
  * the success-criterion-1 click-targeting surface contract (Player's
    debug_click_events / debug_last_click_grid observables, the Central_Divine
    block, and the actual node named in click_targeting_fixed.yaml's ``clicks:``
    list — parsed from the file, never hardcoded, because the dependency may
    land either branch)

It uses ONLY the Python standard library (pathlib, re) — no PyYAML, no
requests, no subprocess, no network, no Godot process — so it runs in
milliseconds offline and can never hit the gate's per-test time wall.
"""

from pathlib import Path
import re

REPO_ROOT: Path = Path(__file__).resolve().parents[1]
COMMON: Path = REPO_ROOT / "playtest" / "_common.yaml"
PLAYTEST_DIR: Path = REPO_ROOT / "playtest"

ROUND_SCENARIOS: list[str] = [
    "click_targeting_fixed",
    "creation_traits_back_next_buttons",
    "creation_back_to_menu_walk",
    "skill_description_visible",
    "movement_range_highlight",
    "battle_end_turn_attack_buttons",
]


def _items_under(text: str, header: str) -> list[str]:
    """Collect the dash items under the first ``header:`` line.

    Finds the FIRST line whose stripped content EXACTLY equals ``header:``
    (exact match, never substring — the free text in a ``description:`` block
    can contain e.g. "clicks: key)," and must not be mistaken for the key).
    Records that line's leading-whitespace length as the header indent. Then
    collects every following line matching ``^\\s*-\\s+(\\S.*)$`` whose
    indentation is >= the header's indentation (the item's name is the text
    after ``- ``), stopping at the first line indented LESS than the header
    (list end), at the first line at >= header indentation that is not a dash
    item, or at EOF. Blank lines are skipped (never a dash item, never a list
    terminator on their own).
    """
    header_marker = header + ":"
    start: int = -1
    header_indent: int = 0
    lines = text.splitlines()
    for idx, raw in enumerate(lines):
        if raw.strip() == header_marker:
            start = idx + 1
            header_indent = len(raw) - len(raw.lstrip())
            break
    if start < 0:
        return []
    items: list[str] = []
    for raw in lines[start:]:
        if not raw.strip():
            continue
        indent = len(raw) - len(raw.lstrip())
        if indent < header_indent:
            break
        match = re.match(r"^\s*-\s+(\S.*)$", raw)
        if match is None:
            break
        items.append(match.group(1).strip())
    return items


def _surface_blocks(text: str) -> dict[str, list[str]]:
    """Parse the ``surface:`` section of ``playtest/_common.yaml``.

    Key = a line matching ``^  (\\S+):$`` (EXACTLY two spaces of indent —
    verified: there is no 4-space indentation anywhere in the surface section,
    so a 4-space item regex would match nothing and collapse every block to an
    empty list). Items = following lines matching ``^  - (\\S+)`` (ALSO exactly
    two spaces, e.g. ``  - health``, ``  - debug_click_events``). Blank lines
    are skipped. Parsing stops at the first non-blank line matching NEITHER
    pattern (verified: the 0-space ``scenario_order:`` at the end of the
    section). Returns ``{key: [items]}`` in document order.
    """
    lines = text.splitlines()
    start: int = -1
    for idx, raw in enumerate(lines):
        if raw.strip() == "surface:":
            start = idx + 1
            break
    if start < 0:
        return {}
    blocks: dict[str, list[str]] = {}
    current_key = None
    for raw in lines[start:]:
        if not raw.strip():
            continue
        key_match = re.match(r"^  (\S+):$", raw)
        item_match = re.match(r"^  - (\S+)", raw)
        if key_match is not None:
            current_key = key_match.group(1)
            blocks[current_key] = []
        elif item_match is not None:
            if current_key is not None:
                blocks[current_key].append(item_match.group(1))
        else:
            break
    return blocks


def test_common_yaml_exists_with_both_sections() -> None:
    text = COMMON.read_text(encoding="utf-8")
    assert text.strip(), "playtest/_common.yaml is empty"
    assert re.search(r"^surface:", text, re.MULTILINE), "missing top-level surface: marker"
    assert re.search(
        r"^scenario_order:", text, re.MULTILINE
    ), "missing top-level scenario_order: marker"


def test_scenario_order_names_have_files() -> None:
    text = COMMON.read_text(encoding="utf-8")
    names = _items_under(text, "scenario_order")
    assert names, "scenario_order: section lists no scenarios"
    missing = [
        name for name in names if not (PLAYTEST_DIR / (name + ".yaml")).is_file()
    ]
    assert not missing, "scenario_order lists files that do not exist: %s" % (missing,)


def test_round_scenarios_present_on_disk_and_in_order() -> None:
    text = COMMON.read_text(encoding="utf-8")
    names = _items_under(text, "scenario_order")
    absent = [name for name in ROUND_SCENARIOS if name not in names]
    assert not absent, "round scenarios missing from scenario_order: %s" % (absent,)
    no_file = [
        name
        for name in ROUND_SCENARIOS
        if not (PLAYTEST_DIR / (name + ".yaml")).is_file()
    ]
    assert not no_file, "round scenario files missing on disk: %s" % (no_file,)
    indices = [names.index(name) for name in ROUND_SCENARIOS]
    assert indices == sorted(indices), (
        "round scenarios must appear in scenario_order in ROUND_SCENARIOS order"
    )


def test_click_targeting_surface_contract() -> None:
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "Player" in blocks, "surface has no Player block"
    assert (
        "debug_click_events" in blocks["Player"]
    ), "Player.debug_click_events not whitelisted on the surface"
    assert (
        "debug_last_click_grid" in blocks["Player"]
    ), "Player.debug_last_click_grid not whitelisted on the surface"
    assert "Central_Divine" in blocks, "Central_Divine not whitelisted on the surface"
    click_text = (PLAYTEST_DIR / "click_targeting_fixed.yaml").read_text(
        encoding="utf-8"
    )
    clicks_items = _items_under(click_text, "clicks")
    assert clicks_items, "click_targeting_fixed.yaml has no clicks: items"
    target = clicks_items[0]
    # The target must BELONG to an observable unit — either the unit block
    # itself, or that unit's click hit-surface, which enemy.gd:_ready() renames
    # to "<EnemyNodeName>_ClickTarget" (unique-name requirement of the harness'
    # recursive bare-name search). The hit-surface is a bare Control with no
    # variables of its own, so it is deliberately NOT a surface block — asserting
    # membership directly would force a meaningless observable into the contract.
    owner = target[: -len("_ClickTarget")] if target.endswith("_ClickTarget") else target
    assert owner in blocks, (
        "clicks: target %r belongs to no whitelisted surface block "
        "(looked for %r)" % (target, owner)
    )
