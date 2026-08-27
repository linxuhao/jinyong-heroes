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
import json
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
    "event_travel_effects",
    "skill_button_effect_info",
    "locked_slot_unlock_reason",
    "health_bar_numbers",
    "creation_attr_effect_info",
    "creation_hp_value_displayed",
    "creation_confirm_summary",
    "qi_cost_blocks_cast_no_energy",
    "map_node_event_shaolin",
    "map_node_event_mainline_east",
    "map_node_event_mainline_return",
]

# The 12 observables the jinyong-map-events round appends to the MapScreen
# surface block (in playtest/_common.yaml), in the same order they are appended.
MAP_NODE_EVENT_SURFACE_VARS: tuple[str, ...] = (
    "phase", "event_id", "event_focus", "entry_declared_gap_types",
    "silver", "attr_bone", "attr_inner", "attr_agility", "attr_wisdom",
    "attr_fortune", "last_effect_types", "events_resolved_count",
)


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


def test_timeline_at_values_are_integers() -> None:
    """Every timeline ``at:`` in every ROUND_SCENARIOS file is a single integer.

    Harness rule (playtest_summary.md, 2026-08-25): frames are single integers —
    a range (``- {at: 3..15, ...}``) or a list (``- at: 20/25/30``) is NOT valid
    spec syntax; the loader rejects such an entry and the whole run HARD-fails.
    A timeline entry takes exactly two shapes: the inline dict
    (``- {at: 3, actions: [ui_accept]}``) or the multiline dict (``- at: 3``).
    ``\\bat\\s*:`` is word-boundary-guarded, so ``at`` inside identifiers
    (``grid_pos``, ``format``) or prose never matches; the captured value class
    ``[^,}\\s]*`` stops at ``,`` / ``}`` / whitespace, so an inline dict captures
    only the number. Every captured value must pass ``isdigit()`` — a range
    (``3..15``), a list (``20/25/30``), a quoted string (``'3'``), a float
    (``3.0``) or an empty value all fail, catching malformed timeline entries at
    static-check time instead of at runtime.
    """
    bad: list[str] = []
    for name in ROUND_SCENARIOS:
        text = (PLAYTEST_DIR / (name + ".yaml")).read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), start=1):
            m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
            if m is None:
                continue  # line carries no timeline `at:` key
            val = m.group(1)
            if not val.isdigit():
                bad.append(
                    f"{name}.yaml line {lineno}: non-integer timeline 'at' "
                    f"value {val!r}"
                )
    assert not bad, "malformed timeline `at` values:\n" + "\n".join(bad)


def test_event_content_surface_contract() -> None:
    """Static contract pin for the jinyong-events round (4 -> 16 event pool).

    Three files are pinned, stdlib-only, so every assertion is decidable by
    reading the repo (no Godot run needed):

      1. playtest/_common.yaml — the six battle-unit surface blocks each carry
         the four new portrait probe vars (portrait_covered_frac /
         portrait_sprite_pos / portrait_tex_size / portrait_bar_pos), and the
         CultivationScreen block carries events_seen_count (the no-repeat bag
         observable the event_travel_effects scenario ladders on).
      2. playtest/event_travel_effects.yaml — exists, its `name:` equals its
         basename, every timeline `at:` is a single integer (the same regex as
         test_timeline_at_values_are_integers), and every Node.var assert line
         (exactly 4 leading spaces + a dotted key) carries a comparison
         operator — the repo's no-bare-scalar-silent-false rule.
      3. playtest/portrait_visibility.yaml — contains a
         `f"{unit}.portrait_covered_frac:"` assert line for each of the six
         units (the partial-occlusion A/B gate lines).
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    for unit in ["Player", "East_Heretic", "West_Poison", "South_Emperor",
                 "North_Beggar", "Central_Divine"]:
        assert unit in blocks, f"surface missing {unit} block"
        for var in ("portrait_covered_frac", "portrait_sprite_pos",
                    "portrait_tex_size", "portrait_bar_pos"):
            assert var in blocks[unit], (
                f"{unit}.{var} not whitelisted on the surface"
            )
    cultivation_items = blocks.get("CultivationScreen", [])
    assert "events_seen_count" in cultivation_items, (
        "CultivationScreen.events_seen_count not whitelisted on the surface"
    )

    # event_travel_effects.yaml: exists, name == basename, integer at values,
    # comparison operator on every 4-space dotted assert line.
    ev = PLAYTEST_DIR / "event_travel_effects.yaml"
    assert ev.is_file(), "event_travel_effects.yaml missing"
    ev_text = ev.read_text(encoding="utf-8")
    assert re.search(
        r"^name:\s*event_travel_effects\s*$", ev_text, re.MULTILINE
    ), "event_travel_effects.yaml name: does not equal its basename"
    for lineno, line in enumerate(ev_text.splitlines(), start=1):
        m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
        if m is not None:
            assert m.group(1).isdigit(), (
                f"event_travel_effects.yaml line {lineno}: non-integer "
                f"timeline 'at' value {m.group(1)!r}"
            )
        if re.match(r"^    [A-Za-z_]\w*\.[A-Za-z_]\w*:", line):
            assert any(
                op in line for op in ["==", "!=", "<", ">", "and", "or"]
            ), (
                f"event_travel_effects.yaml line {lineno} assert missing "
                f"comparison operator: {line.strip()}"
            )

    # portrait_visibility.yaml: each unit has a covered_frac assert line.
    pv_text = (PLAYTEST_DIR / "portrait_visibility.yaml").read_text(
        encoding="utf-8"
    )
    for unit in ["Player", "East_Heretic", "West_Poison", "South_Emperor",
                 "North_Beggar", "Central_Divine"]:
        assert any(
            line.strip().startswith(f"{unit}.portrait_covered_frac:")
            for line in pv_text.splitlines()
        ), f"portrait_visibility.yaml missing {unit}.portrait_covered_frac assert"


def test_hud_info_surface_contract() -> None:
    """Static contract pin for the jinyong-hud round (UX-03/04/05 info layer).

    Pins the four new observable vars on every SkillButton block, the three new
    HealthBar vars, the three new scenario files existing with ``name:`` equal to
    their basename, single-integer timeline ``at:`` values, and a comparison
    operator on every 4-space dotted assert line (the repo's
    no-bare-scalar-silent-false rule).
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    for i in range(1, 13):
        key = f"SkillButton{i}"
        assert key in blocks, f"surface missing {key} block"
        for var in ("cost_text", "effect_text", "effect_summary_text",
                    "lock_reason_text"):
            assert var in blocks[key], (
                f"{key}.{var} not whitelisted on the surface"
            )
    health_items = blocks.get("HealthBar", [])
    for var in ("hp_text", "hp_value", "hp_max"):
        assert var in health_items, (
            f"HealthBar.{var} not whitelisted on the surface"
        )

    for name in ("skill_button_effect_info", "locked_slot_unlock_reason",
                 "health_bar_numbers"):
        path = PLAYTEST_DIR / (name + ".yaml")
        assert path.is_file(), f"{name}.yaml missing"
        ftext = path.read_text(encoding="utf-8")
        assert re.search(
            rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
        ), f"{name}.yaml name: does not equal its basename"
        for lineno, line in enumerate(ftext.splitlines(), start=1):
            m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
            if m is not None:
                assert m.group(1).isdigit(), (
                    f"{name}.yaml line {lineno}: non-integer timeline "
                    f"'at' value {m.group(1)!r}"
                )
            if re.match(r"^    [A-Za-z_]\w*\.[A-Za-z_]\w*:", line):
                assert any(
                    op in line for op in ["==", "!=", "<", ">", "and", "or"]
                ), (
                    f"{name}.yaml line {lineno} assert missing "
                    f"comparison operator: {line.strip()}"
                )


def test_creation_clarity_surface_contract() -> None:
    """Static contract pin for the jinyong-clarity round (UX-06/07/08 info layer).

    Pins the three new CreationScreen observables (hp_value / hp_text /
    confirm_summary_text), the two new node blocks (HpValueLabel /
    ConfirmSummaryLabel with visible + text), the BackButton node block that the
    confirm_summary scenario clicks, the still-whitelisted AttrDescLabel guard,
    and for each of the three new scenario files: exists on disk, name: equals
    its basename, every timeline at: is a single integer, and every 4-space
    dotted assert line carries a comparison operator OR the differential token
    changed/unchanged (the repo's no-bare-scalar-silent-false rule).
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    creation_items = blocks.get("CreationScreen", [])
    for var in ("hp_value", "hp_text", "confirm_summary_text"):
        assert var in creation_items, (
            f"CreationScreen.{var} not whitelisted on the surface"
        )
    assert "AttrDescLabel" in blocks, "surface missing AttrDescLabel block (guard)"
    for key in ("HpValueLabel", "ConfirmSummaryLabel"):
        assert key in blocks, f"surface missing {key} block"
        for prop in ("visible", "text"):
            assert prop in blocks[key], (
                f"{key}.{prop} not whitelisted on the surface"
            )
    assert "BackButton" in blocks, "surface missing BackButton block"

    for name in ("creation_attr_effect_info", "creation_hp_value_displayed",
                 "creation_confirm_summary"):
        path = PLAYTEST_DIR / (name + ".yaml")
        assert path.is_file(), f"{name}.yaml missing"
        ftext = path.read_text(encoding="utf-8")
        assert re.search(
            rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
        ), f"{name}.yaml name: does not equal its basename"
        for lineno, line in enumerate(ftext.splitlines(), start=1):
            m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
            if m is not None:
                assert m.group(1).isdigit(), (
                    f"{name}.yaml line {lineno}: non-integer timeline "
                    f"'at' value {m.group(1)!r}"
                )
            if re.match(r"^    [A-Za-z_]\w*\.[A-Za-z_]\w*:", line):
                has_op = any(
                    op in line for op in ["==", "!=", "<", ">", "and", "or"]
                )
                has_diff = "changed" in line or "unchanged" in line
                assert has_op or has_diff, (
                    f"{name}.yaml line {lineno} assert missing "
                    f"comparison operator: {line.strip()}"
                )


def test_readability_geometry_surface_contract() -> None:
    """Static contract pin for the feedback-round-5 geometry asserts.

    The four on-frame readability defects (HP number width, nameplate pairwise
    overlap, hint-vs-nameplate overlap, settings title rows) all had GREEN
    headless asserts that only check node state, not rendered geometry. This
    round's fix tasks expose four geometry observables (HealthBar.hp_text_width_ok,
    HUD.hint_nameplate_overlap, HUD.nameplate_pairwise_overlap,
    SettingsPanel.title_rows_overlap) that the playtest now asserts on. This
    test pins the wiring side: the four vars are whitelisted on the surface and
    the four new assert lines in the two touched scenarios each carry a
    comparison operator (no-bare-scalar-silent-false rule). No new scenario
    files, so ROUND_SCENARIOS is intentionally untouched.
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)

    # HealthBar.hp_text_width_ok
    health_items = blocks.get("HealthBar", [])
    assert "hp_text_width_ok" in health_items, (
        "HealthBar.hp_text_width_ok not whitelisted on the surface"
    )

    # HUD.hint_nameplate_overlap / HUD.nameplate_pairwise_overlap
    hud_items = blocks.get("HUD", [])
    for var in ("hint_nameplate_overlap", "nameplate_pairwise_overlap"):
        assert var in hud_items, "HUD.%s not whitelisted on the surface" % (var,)

    # SettingsPanel.title_rows_overlap — exactly one SettingsPanel block holds
    # the whitelist, so its presence pins the "no second block" guard.
    settings_items = blocks.get("SettingsPanel", [])
    assert settings_items, "surface has no SettingsPanel block"
    assert "title_rows_overlap" in settings_items, (
        "SettingsPanel.title_rows_overlap not whitelisted on the surface"
    )

    # Every newly added geometry assert line carries a comparison operator.
    expected_lines = {
        "HealthBar.hp_text_width_ok:": "ui_geometry_readability.yaml",
        "HUD.nameplate_pairwise_overlap:": "ui_geometry_readability.yaml",
        "HUD.hint_nameplate_overlap:": "ui_geometry_readability.yaml",
        "SettingsPanel.title_rows_overlap:": "settings_panel.yaml",
    }
    for prefix, scenario in expected_lines.items():
        ftext = (PLAYTEST_DIR / scenario).read_text(encoding="utf-8")
        matched = [
            line
            for line in ftext.splitlines()
            if line.strip().startswith(prefix)
        ]
        assert matched, f"{scenario} missing {prefix} assert line"
        for line in matched:
            assert any(
                op in line for op in ["==", "!=", "<", ">", "and", "or"]
            ), f"{scenario} assert missing comparison operator: {line.strip()}"


def test_qi_cost_surface_contract() -> None:
    """Static contract pin for the jinyong-spend-qi round.

    Pins the qi-cost surface contract against ``playtest/_common.yaml`` and the
    new ``qi_cost_blocks_cast_no_energy.yaml`` scenario: ``Player.energy_max`` is
    whitelisted on the surface (cap-relative qi asserts), ``debug_spend_player_qi``
    is in the actions list (the shared spend-path injection), the scenario file
    exists with ``name:`` equal to its basename, every timeline ``at:`` is a single
    integer, and every 4-space dotted assert line carries a comparison operator or
    the differential token changed/unchanged (the repo's
    no-bare-scalar-silent-false rule). The exact cost values are deliberately NOT
    pinned here — they live in the GDScript unit pin
    (``tests/test_qi_costs_match_design.gd``) so a future cost retuning reddens one
    greppable file, not the regression net.
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    player_items = blocks.get("Player", [])
    assert "energy_max" in player_items, (
        "Player.energy_max not whitelisted on the surface"
    )
    actions = _items_under(text, "actions")
    assert "debug_spend_player_qi" in actions, (
        "debug_spend_player_qi not in _common.yaml actions list"
    )

    name = "qi_cost_blocks_cast_no_energy"
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    for lineno, line in enumerate(ftext.splitlines(), start=1):
        m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
        if m is not None:
            assert m.group(1).isdigit(), (
                f"{name}.yaml line {lineno}: non-integer timeline "
                f"'at' value {m.group(1)!r}"
            )
        if re.match(r"^    [A-Za-z_]\w*\.[A-Za-z_]\w*:", line):
            has_op = any(
                op in line for op in ["==", "!=", "<", ">", "and", "or"]
            )
            has_diff = "changed" in line or "unchanged" in line
            assert has_op or has_diff, (
                f"{name}.yaml line {lineno} assert missing "
                f"comparison operator: {line.strip()}"
            )


def test_map_node_event_surface_contract() -> None:
    """Static contract pin for the jinyong-map-events round.

    Pins the MapScreen node-entry event contract against ``playtest/_common.yaml``
    and the new ``map_node_event_shaolin.yaml`` scenario: the 12 new observables
    (phase / event_id / event_focus / entry_declared_gap_types / silver / attr_*×5 /
    last_effect_types / events_resolved_count) are whitelisted on the surface,
    ``map_node_event_shaolin`` is in scenario_order (two-place sync), the scenario
    file exists with ``name:`` equal to its basename, every timeline ``at:`` is a
    single integer, every 4-space dotted assert line carries a comparison operator
    or the differential token changed/unchanged (the repo's
    no-bare-scalar-silent-false rule), and the declared-but-unimplemented battle /
    facility gaps are assertable via an entry_declared_gap_types line containing
    both "battle" and "facility".
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "MapScreen" in blocks, "surface has no MapScreen block"
    map_items = blocks["MapScreen"]
    assert map_items, "MapScreen surface block parsed empty (vacuous pass guard)"

    # Append-only guard: the five pre-existing MapScreen vars are still there.
    for var in ("current_node_id", "focus_id", "ended", "visible", "size"):
        assert var in map_items, f"MapScreen.{var} no longer whitelisted on the surface"

    # The 12 new observables are whitelisted on the surface.
    for var in MAP_NODE_EVENT_SURFACE_VARS:
        assert var in map_items, f"MapScreen.{var} not whitelisted on the surface"

    # Two-place sync: the new scenario is listed in scenario_order.
    assert "map_node_event_shaolin" in _items_under(
        text, "scenario_order"
    ), "map_node_event_shaolin not in _common.yaml scenario_order"

    # Scenario file static checks (same shape as test_qi_cost_surface_contract).
    name = "map_node_event_shaolin"
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    for lineno, line in enumerate(ftext.splitlines(), start=1):
        m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
        if m is not None:
            assert m.group(1).isdigit(), (
                f"{name}.yaml line {lineno}: non-integer timeline "
                f"'at' value {m.group(1)!r}"
            )
        if re.match(r"^    [A-Za-z_]\w*\.[A-Za-z_]\w*:", line):
            has_op = any(
                op in line for op in ["==", "!=", "<", ">", "and", "or"]
            )
            has_diff = "changed" in line or "unchanged" in line
            assert has_op or has_diff, (
                f"{name}.yaml line {lineno} assert missing "
                f"comparison operator: {line.strip()}"
            )

    # Honesty pin: the declared-unimplemented gaps are assertable via a line
    # carrying both "battle" and "facility" on MapScreen.entry_declared_gap_types.
    gap_lines = [
        line
        for line in ftext.splitlines()
        if line.strip().startswith("MapScreen.entry_declared_gap_types:")
    ]
    assert gap_lines, (
        f"{name}.yaml missing MapScreen.entry_declared_gap_types assert line"
    )
    assert all(
        "battle" in line and "facility" in line for line in gap_lines
    ), f"{name}.yaml entry_declared_gap_types line must reference both battle and facility gaps"

    # Single-operation-hint negative control (5_vision_human round #1). The
    # bottom travel hint (HintLabel) must be hidden while the node event modal is
    # up and restored when it closes, so the map never shows two contradictory
    # operation prompts at once. Three static half-pins: (1) HintLabel whitelisted
    # on the surface with visible+text; (2) the scenario file asserts BOTH states
    # (== false while EVENT, == true after TRAVEL) so a forgotten restore line is
    # caught by the smoke gate alone; (3) the source-level toggle exists in map.gd.
    hint_items = blocks.get("HintLabel", [])
    assert "visible" in hint_items and "text" in hint_items, (
        "HintLabel surface block must whitelist visible and text"
    )
    hint_visible_lines = [
        line
        for line in ftext.splitlines()
        if line.strip().startswith("HintLabel.visible:")
    ]
    assert any("== false" in line for line in hint_visible_lines), (
        f"{name}.yaml missing HintLabel.visible == false (hidden while EVENT)"
    )
    assert any("== true" in line for line in hint_visible_lines), (
        f"{name}.yaml missing HintLabel.visible == true (restored on TRAVEL)"
    )
    src = (REPO_ROOT / "scripts" / "segments" / "map.gd").read_text(encoding="utf-8")
    assert "HintLabel" in src and "visible = phase" in src.replace("\t", " "), (
        "map.gd must toggle HintLabel.visible from the phase (missing or renamed)"
    )


def test_map_node_event_mainline_surface_contract() -> None:
    """Static contract pin for the two new mainline map-node scenarios.

    Pins ``map_node_event_mainline_east`` and ``map_node_event_mainline_return``
    against ``playtest/_common.yaml`` and ``ROUND_SCENARIOS`` (two-place sync):
    each file exists with ``name:`` equal to its basename, every timeline ``at:``
    is a single integer, every 4-space dotted assert line carries a comparison
    operator or the differential token changed/unchanged (the repo's
    no-bare-scalar-silent-false rule), and each file carries at least one
    differential ``: changed`` assert line (east: attr_wisdom; return:
    attr_inner). Both names must appear in scenario_order AND in ROUND_SCENARIOS,
    east before return in both (test_round_scenarios_present_on_disk_and_in_order
    enforces the order match).
    """
    text = COMMON.read_text(encoding="utf-8")
    order = _items_under(text, "scenario_order")
    expected_diff = {
        "map_node_event_mainline_east": "MapScreen.attr_wisdom",
        "map_node_event_mainline_return": "MapScreen.attr_inner",
    }
    for name in ("map_node_event_mainline_east", "map_node_event_mainline_return"):
        # Two-place sync: present in scenario_order AND in ROUND_SCENARIOS.
        assert name in order, (
            f"{name} not in _common.yaml scenario_order (two-place sync)"
        )
        assert name in ROUND_SCENARIOS, (
            f"{name} not in ROUND_SCENARIOS (two-place sync)"
        )
        path = PLAYTEST_DIR / (name + ".yaml")
        assert path.is_file(), f"{name}.yaml missing"
        ftext = path.read_text(encoding="utf-8")
        assert re.search(
            rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
        ), f"{name}.yaml name: does not equal its basename"
        has_diff_line = False
        for lineno, line in enumerate(ftext.splitlines(), start=1):
            m = re.search(r"\bat\s*:\s*([^,}\s]*)", line)
            if m is not None:
                assert m.group(1).isdigit(), (
                    f"{name}.yaml line {lineno}: non-integer timeline "
                    f"'at' value {m.group(1)!r}"
                )
            if re.match(r"^    [A-Za-z_]\w*\.[A-Za-z_]\w*:", line):
                has_op = any(
                    op in line for op in ["==", "!=", "<", ">", "and", "or"]
                )
                has_diff = "changed" in line or "unchanged" in line
                assert has_op or has_diff, (
                    f"{name}.yaml line {lineno} assert missing "
                    f"comparison operator: {line.strip()}"
                )
                if line.rstrip().endswith(": changed"):
                    has_diff_line = True
        # Each scenario must carry its own differential `: changed` assert line
        # (the round's relative-numeric-assert rule).
        assert has_diff_line, (
            f"{name}.yaml missing a line ending `: changed` "
            f"(expected {expected_diff[name]})"
        )


def _normalize_assert(s: str) -> str:
    """Apply the superset matching rule's normalizer to an assert RHS.

    Strips leading/trailing whitespace, strips a YAML single-quote wrapper when
    it spans the whole RHS, and collapses any internal whitespace run to one
    space. All 42 baseline expressions in the fixture are stored WITHOUT the
    single-quote wrapper, so this must run against the FILE RHS to strip the
    same wrapper the current (post-edit) yaml files carry.
    """
    s = s.strip()
    if len(s) >= 2 and s[0] == "'" and s[-1] == "'":
        s = s[1:-1]
    return re.sub(r"\s+", " ", s)


def test_edited_scenarios_assert_superset() -> None:
    """Machine proof of 只许加,不许减 for the two authorized-edited scenarios.

    Loads the frozen PRE-EDIT baseline fixture
    (tests/fixtures/playtest_assert_superset.json) and asserts every baseline
    assert line still appears (node-key + var + expression pair, >= once) in the
    CURRENT edited files ``playtest/spine_to_ending.yaml`` and
    ``playtest/map_node_event_shaolin.yaml``. The single sanctioned exception
    (shaolin events_resolved_count == 1 -> == 2) is baked into the fixture as
    the post-edit expression, so a dropped or renamed pre-edit assert reddens
    here — a whole-file rewrite that drops an assert is caught by pytest, not
    just code review.
    """
    fixture = REPO_ROOT / "tests" / "fixtures" / "playtest_assert_superset.json"
    assert fixture.is_file(), (
        "tests/fixtures/playtest_assert_superset.json missing"
    )
    data = json.loads(fixture.read_text(encoding="utf-8"))
    assert set(data["baselines"]) == {"spine_to_ending", "map_node_event_shaolin"}, (
        "superset fixture payload must cover exactly the two authorized scenarios"
    )
    for scenario, entries in data["baselines"].items():
        file_path = PLAYTEST_DIR / (scenario + ".yaml")
        assert file_path.is_file(), f"{scenario}.yaml missing"
        text = file_path.read_text(encoding="utf-8")
        for entry in entries:
            node = entry["node"]
            var = entry["var"]
            expression = entry["expression"]
            regex = re.compile(
                r"^\s*" + re.escape(node) + r"\." + re.escape(var) + r":\s*(.*)$",
                re.MULTILINE,
            )
            candidates = [
                _normalize_assert(m.group(1)) for m in regex.finditer(text)
            ]
            assert candidates, (
                f"{scenario}.yaml: no assert line for baseline {node}.{var}"
            )
            normalized = _normalize_assert(expression)
            assert any(c == normalized for c in candidates), (
                f"{scenario}.yaml: pre-edit baseline {node}.{var}: "
                f"{expression!r} no longer present in the current file"
            )
