"""Static smoke test for the playtest contract — the 5_test pytest gate's real test.

This module gives the pytest gate at least one genuine, deterministic, pass/fail
signal (flipping ``no_tests_collected`` to false) WITHOUT invoking Godot: it
statically verifies the integrity of the playtest contract in
``playtest/_common.yaml`` against the scenario files on disk.

Scope (deliberately narrow):
  * scenario_order <-> scenario-file completeness
  * the five scenarios of this round present on disk AND listed in order
  * the success-criterion-1 click-targeting surface contract (Player's
    debug_click_events / debug_last_click_grid observables, the Central_Divine
    block, and the actual node named in click_targeting_fixed.yaml's ``clicks:``
    list — parsed from the file, never hardcoded, because the dependency may
    land either branch)
  * the click-move round's surface contract (Player.turn_start_grid /
    turn_start_moves_left / undo_available, MoveRangeHighlight.start_tile /
    undo_available, and CreationScreen.cursor_markers_visible whitelisted on
    the surface; every clicks: target in the five round scenario files belongs
    to a whitelisted surface block — offset specs parsed by first whitespace
    token, trailing ``_ClickTarget`` stripped)

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
    "battle_focus_arrow_keys",
    "click_move_to_tile",
    "click_move_undo_right",
    "click_move_commit_lock",
    "creation_single_ui",
    "creation_layout_readability",
    "portrait_visibility",
    "move_target_affordance",
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


def test_click_move_surface_contract() -> None:
    """Surface whitelist + clicks-owner contract for the click-move round.

    The five round scenarios assert observables the previous rounds never
    whitelisted (Player.turn_start_grid / turn_start_moves_left /
    undo_available, MoveRangeHighlight.start_tile / undo_available,
    CreationScreen.cursor_markers_visible) and click OFFSET targets (the
    ``"<Node> +dx,dy [right]"`` spec) that the old single-target owner check
    did not parse. This test pins both sides of the contract:
      1. every new observable is whitelisted on the surface;
      2. every clicks: target in the five new scenario files belongs to a
         whitelisted surface block — the FIRST whitespace token of the spec
         string (offsets like "Player +64,0" keep only "Player"), with a
         trailing "_ClickTarget" stripped (the hit-surface Control itself is
         deliberately not a surface block, exactly like click_targeting_fixed).
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    player_items = blocks.get("Player", [])
    for var in ("turn_start_grid", "turn_start_moves_left", "undo_available"):
        assert var in player_items, "Player.%s not whitelisted on the surface" % (var,)
    highlight_items = blocks.get("MoveRangeHighlight", [])
    for var in ("start_tile", "undo_available"):
        assert var in highlight_items, (
            "MoveRangeHighlight.%s not whitelisted on the surface" % (var,)
        )
    creation_items = blocks.get("CreationScreen", [])
    assert "cursor_markers_visible" in creation_items, (
        "CreationScreen.cursor_markers_visible not whitelisted on the surface"
    )
    for name in ROUND_SCENARIOS:
        click_text = (PLAYTEST_DIR / (name + ".yaml")).read_text(encoding="utf-8")
        for item in _items_under(click_text, "clicks"):
            target = item.split()[0]
            owner = (
                target[: -len("_ClickTarget")]
                if target.endswith("_ClickTarget")
                else target
            )
            assert owner in blocks, (
                "clicks: target %r in %s belongs to no whitelisted surface block "
                "(looked for %r)" % (item, name, owner)
            )


def test_affordance_surface_contract() -> None:
    """Surface contract for the jinyong-affordance round: portrait_visibility vars."""
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    for unit in ["Player", "East_Heretic", "West_Poison", "South_Emperor",
                 "North_Beggar", "Central_Divine"]:
        assert unit in blocks, f"surface missing {unit} block"
        assert "portrait_visible" in blocks[unit], (
            f"{unit}.portrait_visible not whitelisted on surface"
        )
        assert "portrait_fail_layer" in blocks[unit], (
            f"{unit}.portrait_fail_layer not whitelisted on surface"
        )
    # Verify new scenario file exists and has comparison operators
    pv = PLAYTEST_DIR / "portrait_visibility.yaml"
    assert pv.is_file(), "portrait_visibility.yaml missing"
    pv_text = pv.read_text(encoding="utf-8")
    for line in pv_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("Player.portrait_visible:") or \
           stripped.startswith("Central_Divine.portrait_visible:") or \
           stripped.startswith("East_Heretic.portrait_visible:") or \
           stripped.startswith("West_Poison.portrait_visible:") or \
           stripped.startswith("South_Emperor.portrait_visible:") or \
           stripped.startswith("North_Beggar.portrait_visible:"):
            assert any(op in stripped for op in ["==", "!=", "<", ">", "and", "or"]), (
                f"portrait_visibility.yaml assert missing comparison operator: {stripped}"
            )
    # MoveHintLabel surface contract (UX-02)
    assert "MoveHintLabel" in blocks, "surface missing MoveHintLabel block"
    for var_name in ["state", "text", "visible", "tile", "center",
                     "in_viewport", "bar_overlap"]:
        assert var_name in blocks["MoveHintLabel"], (
            f"MoveHintLabel.{var_name} not whitelisted on surface"
        )
    # Verify new scenario file exists and every MoveHintLabel.assert carries a
    # comparison operator (the repo's "no bare-scalar silent-false" rule).
    ma = PLAYTEST_DIR / "move_target_affordance.yaml"
    assert ma.is_file(), "move_target_affordance.yaml missing"
    for line in ma.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("MoveHintLabel."):
            assert any(op in stripped for op in ["==", "!=", "<", ">", "and", "or"]), (
                f"move_target_affordance.yaml assert missing comparison operator: {stripped}"
            )


def test_topbar_layout_surface_contract() -> None:
    """Surface whitelist + clicks-owner contract for the layout round.

    The round's battle-top-strip and creation-layout observables
    (HUD.top_text_* / hint_hpbar_overlap / hpbar_strip_overlap,
    TopStrip.visible/size, HealthBar.name_backing_alpha,
    CreationScreen.attr_*/points_*/phase_*/creation_*) must be whitelisted on
    the surface, and the new creation_layout_readability scenario's clicks
    targets must parse non-vacuously AND belong to whitelisted surface blocks
    (same owner logic as test_click_move_surface_contract — first whitespace
    token, trailing _ClickTarget stripped). Pinning the click parsing inside
    this test closes the vacuum-coverage gap: an inline ``clicks: [X]`` list
    never matches ``_items_under``'s exact ``clicks:`` header match, so an
    unparseable scenario would silently skip the owner check.
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "TopStrip" in blocks, "surface has no TopStrip block"
    hud_items = blocks.get("HUD", [])
    for var in (
        "top_text_pairwise_overlap",
        "top_text_in_strip",
        "top_strip_alpha",
        "hint_hpbar_overlap",
        "hpbar_strip_overlap",
    ):
        assert var in hud_items, "HUD.%s not whitelisted on the surface" % (var,)
    creation_items = blocks.get("CreationScreen", [])
    for var in (
        "attr_rows_uniform",
        "attr_label_alignment_ok",
        "points_attrs_gap_ok",
        "phase_skeleton_same",
        "creation_in_viewport",
        "creation_box_fits",
    ):
        assert (
            var in creation_items
        ), "CreationScreen.%s not whitelisted on the surface" % (var,)
    health_items = blocks.get("HealthBar", [])
    assert "name_backing_alpha" in health_items, (
        "HealthBar.name_backing_alpha not whitelisted on the surface"
    )
    click_text = (PLAYTEST_DIR / "creation_layout_readability.yaml").read_text(
        encoding="utf-8"
    )
    clicks_items = _items_under(click_text, "clicks")
    assert clicks_items, "creation_layout_readability.yaml has no clicks: items"
    for item in clicks_items:
        target = item.split()[0]
        owner = (
            target[: -len("_ClickTarget")]
            if target.endswith("_ClickTarget")
            else target
        )
        assert owner in blocks, (
            "clicks: target %r in creation_layout_readability belongs to no "
            "whitelisted surface block (looked for %r)" % (item, owner)
        )


def test_creation_rework_and_bar_surface_contract() -> None:
    """Surface whitelist contract for the creation rework + health-bar round.

    The round's new observables (HealthBar.bar_height / empty_area_px /
    empty_cap_px and CreationScreen.attr_cluster_center_ok /
    attr_cluster_width_ok / nav_cluster_center_ok / trait_cluster_center_ok /
    desc_center_ok / desc_alignment_ok) must be whitelisted on the surface, or
    the playtest gate refuses to evaluate them.
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    health_items = blocks.get("HealthBar", [])
    for var in ("bar_height", "empty_area_px", "empty_cap_px"):
        assert var in health_items, "HealthBar.%s not whitelisted on the surface" % (var,)
    creation_items = blocks.get("CreationScreen", [])
    for var in ("attr_cluster_center_ok", "attr_cluster_width_ok",
                "nav_cluster_center_ok", "trait_cluster_center_ok",
                "desc_center_ok", "desc_alignment_ok"):
        assert var in creation_items, "CreationScreen.%s not whitelisted on the surface" % (var,)
