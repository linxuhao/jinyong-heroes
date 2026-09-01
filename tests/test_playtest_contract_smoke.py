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

It uses the Python standard library plus one sanctioned third-party import
(yaml, for the timeline 'at' type gate) — no requests, no subprocess, no
network, no Godot process — so it runs in milliseconds offline and can never
hit the gate's per-test time wall.
"""

from pathlib import Path
import json
import re
import yaml

REPO_ROOT: Path = Path(__file__).resolve().parents[1]
COMMON: Path = REPO_ROOT / "playtest" / "_common.yaml"
PLAYTEST_DIR: Path = REPO_ROOT / "playtest"

ROUND_SCENARIOS: list[str] = [
    "battle_focus_arrow_keys",
    "click_move_to_tile",
    "click_move_undo_right",
    "click_move_undo_feet",
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
    "map_hint_single",
    "map_battle_node_huashan",
    "input_click_differential",
    "undo_button_retreat",
    "click_portrait_body_targets_enemy",
    "health_bar_above_portrait",
    "trait_hover_preview",
    "portrait_grid_alignment",
    "language_zh_default",
    "camera_transform_follows_unit",
    "facility_use_reusable",
    "clicks_only_storyline",
    "map_facility_buttons_click",
    "clicks_only_gongfa_empty_exit",
    "gongfa_pick_empty_keyboard_return",
    "roster_panel_item_nail",
    "roster_panel_cultivation_open_close",
    "roster_equip_free_action",
    "equipment_in_battle_diff",
    "event_pool_new_event_resolved",
    "theme_focus_marker_cultivation",
    "softlock_empty_practice_month_advances",
    "facility_use_cap_exhausted_zero_delta",
    "map_node_event_revisit_no_resettle",
    "event_option_refused_no_charge",
    "occlusion_no_button_over_text",
    "action_yield_differential",
    "fortune_reroll_budget",
    "huashan_readiness_warning",
    "huashan_winnable_normal_route",
]

# The 12 observables the jinyong-map-events round appends to the MapScreen
# surface block (in playtest/_common.yaml), in the same order they are appended.
MAP_NODE_EVENT_SURFACE_VARS: tuple[str, ...] = (
    "phase", "event_id", "event_focus", "entry_declared_gap_types",
    "silver", "attr_bone", "attr_inner", "attr_agility", "attr_wisdom",
    "attr_fortune", "last_effect_types", "events_resolved_count",
)

# The 4 observables the jinyong-facility round appends to the MapScreen surface
# block (in playtest/_common.yaml), in the same order they are appended.
FACILITY_SURFACE_VARS: tuple[str, ...] = (
    "facility_id", "facility_use_count", "last_facility_effect_types",
    "facility_result_text",
)

# The 2 actions the jinyong-facility round appends to the actions list.
FACILITY_ACTIONS: tuple[str, ...] = ("use_facility", "debug_grant_silver")

# The 1 observable the jinyong-theme focus-marker round appends to the
# CultivationScreen surface block (in playtest/_common.yaml), in the same order
# it is appended. This is the runtime proof the script-driven focus marker (not
# the old 2-3% modulate trick) is applied — see the focus_marker_active var in
# scripts/segments/cultivation.gd.
FOCUS_MARKER_SURFACE_VARS: tuple[str, ...] = ("focus_marker_active",)


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
    # Verify new scenario file exists and every Camera. assert carries a
    # comparison operator (the rewritten CAMERA-LEVEL gate — full-portrait
    # visibility is the camera's property, not a sprite's, so the old per-unit
    # portrait_visible scan is replaced by the Camera. block).
    pv = PLAYTEST_DIR / "portrait_visibility.yaml"
    assert pv.is_file(), "portrait_visibility.yaml missing"
    pv_text = pv.read_text(encoding="utf-8")
    for line in pv_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("Camera."):
            assert any(op in stripped for op in ["==", "!=", "<", ">", "and", "or"]), (
                f"portrait_visibility.yaml Camera assert missing comparison "
                f"operator: {stripped}"
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


def _bad_timeline_at_values(text: str, name: str) -> list[str]:
    """Type gate: every timeline entry's 'at' must be an integer frame number.

    Parse-based (replaces the line-regex/comment-strip walker): comments
    vanish at parse, a '#' inside a quoted scalar is handled by the parser,
    and a file that fails to parse is REPORTED instead of silently
    unverifiable. Two rules, walked recursively over the whole document:
      A. every mapping that carries an 'at' key must carry an int
         (bool excluded) - also covers bare top-level entry lists and
         click/other frame entries;
      B. every element of any 'timeline' list must be a mapping with 'at'.
    """
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        return [f"{name}.yaml: unparseable YAML - timeline 'at' values "
                f"cannot be verified; parser said: {exc}"]
    bad: list[str] = []

    def _at_check(node: dict, path: str) -> None:
        v = node["at"]
        if isinstance(v, bool) or not isinstance(v, int):
            bad.append(f"{name}.yaml: 'at' value {v!r} at {path} must be an "
                       f"integer frame number (got {type(v).__name__})")

    def _walk(node: object, path: str) -> None:
        if isinstance(node, dict):
            if "at" in node:
                _at_check(node, path)
            entries = node.get("timeline")
            if isinstance(entries, list):
                for i, entry in enumerate(entries):
                    epath = f"{path}.timeline[{i}]"
                    if not isinstance(entry, dict):
                        bad.append(f"{name}.yaml: timeline entry {i} at "
                                   f"{epath} is not a mapping")
                    elif "at" not in entry:
                        bad.append(f"{name}.yaml: timeline entry {i} at "
                                   f"{epath} has no 'at'")
            for k, child in node.items():
                _walk(child, f"{path}.{k}")
        elif isinstance(node, list):
            for i, child in enumerate(node):
                _walk(child, f"{path}[{i}]")

    _walk(doc, "$")
    return bad


def test_timeline_at_values_are_integers() -> None:
    """Every timeline ``at:`` in every ROUND_SCENARIOS file is a single integer.

    Kept as the real-tree sweep: loops ROUND_SCENARIOS and feeds each file's
    text to ``_bad_timeline_at_values``, which now parses the YAML and
    type-checks recursively (every mapping carrying an ``at`` holds an int,
    bools excluded; every ``timeline`` element is a mapping with ``at``; an
    unparseable file is reported). A range (``3..15``), a list (``20/25/30``),
    a quoted string (``'3'``), a float (``3.0``), an empty value and a bool
    all fail.
    """
    bad: list[str] = []
    for name in ROUND_SCENARIOS:
        text = (PLAYTEST_DIR / (name + ".yaml")).read_text(encoding="utf-8")
        bad.extend(_bad_timeline_at_values(text, name))
    assert not bad, "malformed timeline `at` values:\n" + "\n".join(bad)


def test_timeline_at_real_non_integer_still_red() -> None:
    """Regression: a real non-integer ``at:`` value still fails the gate.

    The parse-based type gate (replaces the old line-regex/comment-strip
    walker) must not let an actual malformed timeline entry (``- at: abc``)
    slip through. Line numbers are gone in the parse view, so the failure
    message carries the filename plus the offending value's repr instead.
    """
    bad = _bad_timeline_at_values("- at: abc\n", "probe")
    assert len(bad) == 1
    assert "probe.yaml" in bad[0]
    assert "'abc'" in bad[0]  # captured value is echoed in the failure message


def test_timeline_at_type_rejections() -> None:
    """Regression: the parse gate rejects non-int 'at' values by TYPE.

    A str, a float, a str-range, an empty (None) value and a bool each yield
    exactly one failure (bools are excluded because ``isinstance(True, int)``
    is True). Legal ints (0, 30) pass.
    """
    cases = [
        ("- at: '3'\n", "'3'"),
        ("- at: 3.0\n", "3.0"),
        ("- at: 3..15\n", "'3..15'"),
        ("- at:\n", "None"),
        ("- at: true\n", "True"),
    ]
    for probe, expected_repr in cases:
        bad = _bad_timeline_at_values(probe, "probe")
        assert len(bad) == 1, (
            f"expected exactly 1 failure for {probe!r}, got {len(bad)}: {bad}"
        )
        assert "probe.yaml" in bad[0]
        # For `3..15` assert the repr WITH quotes: the bare `3..15` substring
        # could appear in a path and false-positive via a bare `in`.
        assert expected_repr in bad[0], f"expected {expected_repr!r} in {bad[0]!r}"
    # Legal ints pass (type gate: `at: 0` is legal, no positivity check).
    assert _bad_timeline_at_values("- at: 0\n", "probe") == []
    assert _bad_timeline_at_values("- at: 30\n", "probe") == []


def test_timeline_entry_without_at_is_reported() -> None:
    """Regression: a timeline element missing the 'at' key is reported (rule B)."""
    probe = "timeline:\n  - actions: [move_right]\n"
    bad = _bad_timeline_at_values(probe, "probe")
    assert len(bad) == 1
    assert "probe.yaml" in bad[0]
    assert "has no 'at'" in bad[0]


def test_unparseable_yaml_is_reported() -> None:
    """Regression: an unparseable doc reds (previously a silent skip)."""
    probe = "timeline: [ {at: 3"
    bad = _bad_timeline_at_values(probe, "probe")
    assert len(bad) == 1
    assert "probe.yaml" in bad[0]
    assert "unparseable" in bad[0]


def test_timeline_at_comment_backtick_at_is_ignored() -> None:
    """Regression: a backtick-wrapped `` `at:` `` inside a ``#`` comment is inert.

    Pins the exact bug fixed 2026-08-30: clicks_only_storyline.yaml:99 is a
    ``#`` comment whose prose contains `` `at:` ``; before comment-stripping the
    ``\\b`` boundary fired on a ``#``/backtick-adjacent ``a``, the regex captured
    the closing backtick, and ``isdigit()`` failed — a false red on a legal
    scenario comment. With the strip, line 1 contributes no entry and the real
    ``- at: 3`` on line 2 still passes.
    """
    assert _bad_timeline_at_values("#   ... and every `at:`\n- at: 3\n", "probe") == []


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
      3. (rewritten 2026-08-28) portrait_visibility.yaml is now the CAMERA-LEVEL
         visibility gate: the old per-unit `f"{unit}.portrait_covered_frac:"
         assert-line requirement is DELETED (full-portrait visibility is the
         camera's property, not a sprite's; the gate now asserts Camera.*
         observables the CameraFollower publishes). The per-unit surface
         whitelist of the four portrait probe vars (portrait_covered_frac /
         portrait_sprite_pos / portrait_tex_size / portrait_bar_pos) STAYS —
         append-only.
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


def test_facility_use_reusable_surface_contract() -> None:
    """Static contract pin for the jinyong-facility round.

    Pins ``facility_use_reusable`` against ``playtest/_common.yaml`` and
    ``ROUND_SCENARIOS`` (two-place sync): the 4 new observables
    (facility_id / facility_use_count / last_facility_effect_types /
    facility_result_text) are whitelisted on the MapScreen surface block, the 2
    new actions (use_facility / debug_grant_silver) are in the actions list, the scenario
    is in scenario_order AND in ROUND_SCENARIOS, the file exists with ``name:``
    equal to its basename, every timeline ``at:`` is a single integer, every
    4-space dotted assert line carries a comparison operator or the differential
    token changed/unchanged (the no-bare-scalar-silent-false rule), and the file
    carries at least one ``: changed`` line.

    HARD ANTI-DELETION PIN (the permanent negative assertion corridor): the
    scenario file text must contain BOTH a ``phase != "FACILITY"`` line AND a
    ``facility_use_count == 0`` line. These two lines are the arrival half of
    the scenario — the standing proof that "arrival never enters a facility;
    only an explicit choice does" (event = fires on arrival, facility = entered
    by choice). They are the ONLY guard against a future round silently wiring
    the facility into the arrival dispatch. Without this pin the permanent
    negative assertion is itself silently deletable — the same failure shape as
    the honesty pin in test_map_node_event_surface_contract (which requires the
    shaolin gap line to reference both battle and facility).
    """
    name = "facility_use_reusable"
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "MapScreen" in blocks, "surface has no MapScreen block"
    map_items = blocks["MapScreen"]
    assert map_items, "MapScreen surface block parsed empty (vacuous pass guard)"

    # The 4 new observables are whitelisted on the MapScreen surface block.
    for var in FACILITY_SURFACE_VARS:
        assert var in map_items, f"MapScreen.{var} not whitelisted on the surface"

    # The 2 new actions are in the actions list.
    actions = _items_under(text, "actions")
    for action in FACILITY_ACTIONS:
        assert action in actions, f"action {action} not in _common.yaml actions"

    # Two-place sync: the scenario is in scenario_order AND in ROUND_SCENARIOS.
    order = _items_under(text, "scenario_order")
    assert name in order, f"{name} not in _common.yaml scenario_order (two-place sync)"
    assert name in ROUND_SCENARIOS, (
        f"{name} not in ROUND_SCENARIOS (two-place sync)"
    )

    # Scenario file static checks (same shape as test_map_node_event_surface_contract).
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
    assert has_diff_line, (
        f"{name}.yaml missing a line ending `: changed` (relative-numeric rule)"
    )

    # HARD ANTI-DELETION PIN — the permanent negative assertion corridor.
    # See the docstring: these two lines are the definitional property of the
    # content type (arrival never enters a facility) made permanent.
    _escape = (
        " (verbatim anti-deletion gate). This gate exists ONLY so this "
        "differential/definitional nail cannot be silently deleted. If you are "
        "RENAMING or REWRITING the assertion, update THIS PIN in the same "
        "change to match the equivalent new assertion — do not keep a dead "
        "old-text line in the scenario just to turn it green, and do not "
        "bypass a legitimate rename. "
        "This is a FORM gate: it requires two literal assertion lines "
        "(phase != \"FACILITY\" and facility_use_count == 0) to appear "
        "verbatim in the scenario file — they are the machine-readable "
        "evidence of the definitional property 'arrival never enters a "
        "facility'. A red here is CORRECT when the observables or their "
        "expression legitimately change; the fix is to update this pin "
        "together with the equivalent new assertion in the same change — "
        "not to rename around it and not to keep a dead old-text line just "
        "to stay green."
    )
    assert re.search(
        r'phase\s*!=\s*"FACILITY"', ftext
    ), f"{name}.yaml must contain a `phase != \"FACILITY\"` line" + _escape
    assert re.search(
        r"facility_use_count\s*==\s*0", ftext
    ), f"{name}.yaml must contain a `facility_use_count == 0` line" + _escape

    # The differential nail for "using a facility must produce a VISIBLE
    # result" — the scenario must keep a `facility_result_text != ""` line at
    # each use frame (at: 600 / at: 790). While the FACILITY result rendering is
    # absent this var stays "" so those value-inequality asserts are RED — the
    # pre-fix measurement for the never-rendered-result defect. (A `changed`
    # differential cannot express that red: the harness's differential baseline
    # is the frame-0 snapshot, where the MapScreen is not yet loaded and reads
    # null, so `changed` is trivially green from null -> "".)
    assert re.search(
        r"facility_result_text\s*:\s*facility_result_text\s*!=\s*\"\"", ftext
    ), (
        f"{name}.yaml must contain a `facility_result_text != \"\"` line "
        "(the visible-result differential nail)" + _escape
    )


def test_focus_marker_surface_contract() -> None:
    """Static contract pin for the jinyong-theme focus-marker nail.

    Pins ``theme_focus_marker_cultivation`` against ``playtest/_common.yaml``
    and ``ROUND_SCENARIOS`` (two-place sync): the new CultivationScreen
    observable (focus_marker_active) is whitelisted on the surface, the scenario
    name appears in scenario_order AND in ROUND_SCENARIOS, the file exists with
    ``name:`` equal to its basename, every timeline ``at:`` is a single integer,
    and the file carries the mandatory differential ``: changed`` line
    (focused_option_text) — the no-bare-scalar-silent-false rule. The focus
    marker is a DIFFERENTIAL on a real published surface (focus_marker_active),
    so this pin never asserts a style/color literal.
    """
    name = "theme_focus_marker_cultivation"
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "CultivationScreen" in blocks, "surface has no CultivationScreen block"
    cult_items = blocks["CultivationScreen"]
    assert cult_items, "CultivationScreen surface block parsed empty (vacuous pass guard)"
    for var in FOCUS_MARKER_SURFACE_VARS:
        assert var in cult_items, (
            f"CultivationScreen.{var} not whitelisted on the surface"
        )

    # Two-place sync: the scenario is in scenario_order AND in ROUND_SCENARIOS.
    order = _items_under(text, "scenario_order")
    assert name in order, (
        f"{name} not in _common.yaml scenario_order (two-place sync)"
    )
    assert name in ROUND_SCENARIOS, (
        f"{name} not in ROUND_SCENARIOS (two-place sync)"
    )

    # Scenario file static checks (same shape as test_facility_use_reusable_surface_contract).
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
    assert has_diff_line, (
        f"{name}.yaml missing a line ending `: changed` "
        f"(mandatory differential on focused_option_text)"
    )


def test_softlock_nail_contract() -> None:
    """Static anti-weakening pins for the jinyong-loop soft-lock nail.

    The soft-lock nail (``softlock_empty_practice_month_advances``) is this
    round's core deliverable: it must reach the empty-GONGFA state through
    REAL player input (``debug_seed_save`` seed + ``ui_accept`` drive) and
    assert the month advances differentially. Three hard pins:

      1. the file MUST carry the differential line
         ``month == month_before_accept + 1`` (the month-advance proof);
      2. the timeline MUST NOT USE ``debug_fast_forward`` in any action — the
         existing 78 greens are green precisely because they bypass this path
         via the debug twin, so a nail that reaches the state by fast-forward
         would prove nothing;
      3. each re-pointed soft-lock-era nail (``gongfa_pick_empty_keyboard_return``
         and ``clicks_only_gongfa_empty_exit``) must still carry its preserved
         empty-state assert ``mastered_count == gongfa_count`` — the re-point
         changed only the exit-frame asserts, never the empty-state proof.
    """
    name = "softlock_empty_practice_month_advances"
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    assert "month == month_before_accept + 1" in ftext, (
        f"{name}.yaml missing the differential month-advance line "
        "`month == month_before_accept + 1`"
    )
    # The ban is scoped to the TIMELINE's actions, not the file's prose: the
    # file legitimately QUOTES the token in its header comments and description
    # scalar (the in-file documentation of why the action is banned). The
    # protective property is that no timeline step ever executes the debug
    # twin, so we parse the timeline and check every action (list form and any
    # single-action ``press`` scalar) for the token. yaml.safe_load is already
    # imported; if parsing fails the assert fails loudly rather than passing.
    parsed = yaml.safe_load(ftext)
    timeline = parsed.get("timeline", []) if isinstance(parsed, dict) else []
    for entry in timeline:
        if not isinstance(entry, dict):
            continue
        for key in ("actions", "press"):
            acts = entry.get(key)
            if isinstance(acts, str):
                acts = [acts]
            if isinstance(acts, list):
                for act in acts:
                    if isinstance(act, str) and "debug_fast_forward" in act:
                        assert False, (
                            f"{name}.yaml uses debug_fast_forward in a timeline "
                            "action — the soft-lock nail must be reached through "
                            "real player input, never the debug twin"
                        )
    for repointed in ("gongfa_pick_empty_keyboard_return", "clicks_only_gongfa_empty_exit"):
        rtext = (PLAYTEST_DIR / (repointed + ".yaml")).read_text(encoding="utf-8")
        assert "mastered_count == gongfa_count" in rtext, (
            f"{repointed}.yaml lost its preserved empty-state assert "
            "`mastered_count == gongfa_count` during the re-point"
        )


def test_facility_use_cap_nail_contract() -> None:
    """Static anti-weakening pins for the jinyong-loop facility-cap nail.

    The nail (``facility_use_cap_exhausted_zero_delta``) pins the per-month
    facility cap (RULE GATE: 2 uses per profile month). The exhausted press
    must be proven by DIFFERENTIAL comparisons against the success-only
    snapshot surfaces (never by tuned literals like ``== 8``). Hard pins:

      1. the scenario is in BOTH registries — ``scenario_order`` in
         ``playtest/_common.yaml`` AND ``ROUND_SCENARIOS`` here (two-place
         sync, both tails, same relative order);
      2. the file exists with ``name:`` == its basename;
      3. every timeline ``at:`` is a single integer;
      4. the file MUST carry the two zero-delta lines
         ``silver == last_use_silver`` and ``attr_bone == last_use_attr_value``
         (the exhausted press changed nothing on either value), plus the
         on-screen exhausted-receipt line ``facility_result_text != ""``;
      5. the protected gate (a) file ``facility_use_reusable.yaml`` still
         carries its pinned ``phase != "FACILITY"`` and
         ``facility_use_count == 0`` arrival-half lines — the cap fix must
         never weaken them.
    """
    name = "facility_use_cap_exhausted_zero_delta"
    order_text = COMMON.read_text(encoding="utf-8")
    order_names = _items_under(order_text, "scenario_order")
    assert name in order_names, f"{name} missing from scenario_order"
    assert name in ROUND_SCENARIOS, f"{name} missing from ROUND_SCENARIOS"
    assert [n for n in order_names if n in ROUND_SCENARIOS] == ROUND_SCENARIOS, (
        f"{name}: scenario_order and ROUND_SCENARIOS disagree on presence or "
        "relative order"
    )
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    for lineno, line in enumerate(
        ftext.splitlines(), start=1
    ):
        match = re.search(r"\bat\s*:\s*([^,}\s]+)", line)
        if match and not match.group(1).isdigit():
            assert False, (
                f"{name}.yaml line {lineno}: non-integer timeline "
                f"'at' value {match.group(1)!r}"
            )
    for mandatory in (
        "silver == last_use_silver",
        "attr_bone == last_use_attr_value",
        'facility_result_text != ""',
    ):
        assert mandatory in ftext, (
            f"{name}.yaml missing the mandatory differential/receipt line "
            f"`{mandatory}`"
        )
    # The protected arrival-half pins of gate (a) must survive the cap fix
    # byte-untouched (anti-weakening, per the verbatim-protected trio rule).
    gate_text = (PLAYTEST_DIR / "facility_use_reusable.yaml").read_text(
        encoding="utf-8"
    )
    assert 'phase != "FACILITY"' in gate_text, (
        "facility_use_reusable.yaml lost its pinned `phase != \"FACILITY\"` line"
    )
    assert "facility_use_count == 0" in gate_text, (
        "facility_use_reusable.yaml lost its pinned "
        "`facility_use_count == 0` line"
    )


def test_map_node_event_revisit_no_resettle_nail_contract() -> None:
    """Static anti-weakening pins for the jinyong-loop revisit nail.

    The nail (``map_node_event_revisit_no_resettle``) pins the settled-split
    rule: a node event may RE-APPEAR on revisit (gates (b) pin re-fire, and the
    fix must NOT remove re-appearance), but its economy/attr effects must NOT
    re-settle. Hard pins:

    1. the scenario name is present in ``scenario_order`` AND
       ``ROUND_SCENARIOS`` at the same relative order (two-place sync);
    2. the file exists with ``name:`` == its basename;
    3. every timeline ``at:`` is a single integer;
    4. the file MUST carry the zero-delta line
       ``attr_wisdom == last_apply_attr_value`` (the suppressed re-resolve
       changed nothing on wisdom), the empty-effect line
       ``last_effect_types.is_empty()``, and the on-screen receipt line
       ``map_status_text != \"\"``;
    5. the file MUST keep a re-fire leg asserting ``phase == \"EVENT\"`` — the
       fix cannot be "landed" by also suppressing re-appearance;
    6. the two gate-(b) protected files keep their pinned ladder lines
       byte-untouched (anti-weakening, per the verbatim-protected trio rule).
    """
    name = "map_node_event_revisit_no_resettle"
    order_text = COMMON.read_text(encoding="utf-8")
    order_names = _items_under(order_text, "scenario_order")
    assert name in order_names, f"{name} missing from scenario_order"
    assert name in ROUND_SCENARIOS, f"{name} missing from ROUND_SCENARIOS"
    assert [n for n in order_names if n in ROUND_SCENARIOS] == ROUND_SCENARIOS, (
        f"{name}: scenario_order and ROUND_SCENARIOS disagree on presence or "
        "relative order"
    )
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    for lineno, line in enumerate(
        ftext.splitlines(), start=1
    ):
        match = re.search(r"\bat\s*:\s*([^,}\s]+)", line)
        if match and not match.group(1).isdigit():
            assert False, (
                f"{name}.yaml line {lineno}: non-integer timeline "
                f"'at' value {match.group(1)!r}"
            )
    for mandatory in (
        "attr_wisdom == last_apply_attr_value",
        "last_effect_types.is_empty()",
        'map_status_text != ""',
        'phase == "EVENT"',
    ):
        assert mandatory in ftext, (
            f"{name}.yaml missing the mandatory differential/receipt line "
            f"`{mandatory}`"
        )
    # The two gate-(b) protected files' pinned ladder lines survive byte-untouched.
    shaolin = (PLAYTEST_DIR / "map_node_event_shaolin.yaml").read_text(
        encoding="utf-8"
    )
    huashan = (PLAYTEST_DIR / "map_battle_node_huashan.yaml").read_text(
        encoding="utf-8"
    )
    assert "events_resolved_count == 3" in shaolin, (
        "map_node_event_shaolin.yaml lost its pinned "
        "`events_resolved_count == 3` ladder line"
    )
    assert "events_resolved_count == 3" in huashan, (
        "map_battle_node_huashan.yaml lost its pinned "
        "`events_resolved_count == 3` Leg-F ladder line"
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


# ── The full-screen host that must never eat a click ────────────────────────
#
# `SegmentHost` is a full-rect Control that stays in the tree for the whole
# session, so a missing `mouse_filter` on it swallows every mouse click that
# does not land on a Button — the board included.
#
# This has now happened twice. `playtest/_common.yaml`'s own header records the
# first time ("那次就是 main.tscn 的 SegmentHost 漏写 mouse_filter"). main.tscn
# was fixed; menu.tscn, the sibling with the same structure, was not — and
# menu.tscn is `run/main_scene`, the scene players actually boot. The play-test
# contract boots main.tscn, so all 57 scenarios exercised the FIXED scene while
# the shipped game ran the broken one, and the suite stayed green for as long as
# the defect existed.
#
# Measured 2026-08-27 by driving a real X11 window with xdotool (the play-test
# harness injects with Input.parse_input_event and never reaches the GUI phase
# where this is decided): a real click on an empty tile left the player at (7,5)
# with raw=3 handled=0, i.e. the press reached the player node and never reached
# handle_world_click. With `mouse_filter = 2` restored: (7,4), raw=3 handled=1.
_FULL_RECT_HOSTS = ("SegmentHost",)


def _scene_files() -> list[Path]:
    return sorted((REPO_ROOT / "scenes").rglob("*.tscn"))


def test_every_full_rect_host_is_click_through():
    offenders = []
    for scene in _scene_files():
        text = scene.read_text(encoding="utf-8")
        for host in _FULL_RECT_HOSTS:
            marker = '[node name="%s" ' % host
            idx = text.find(marker)
            while idx != -1:
                # the node's own property block ends at the next [node / [sub_
                end = text.find("\n[", idx + 1)
                block = text[idx:end if end != -1 else len(text)]
                if "mouse_filter = 2" not in block:
                    offenders.append("%s: %s" % (scene.name, host))
                idx = text.find(marker, idx + 1)
    assert not offenders, (
        "a full-rect host without mouse_filter = 2 swallows every board click: "
        + ", ".join(offenders))


def test_the_contract_boot_scene_is_recorded_against_the_games_own():
    """The contract boots main.tscn; the game boots run/main_scene. When those
    differ, every scenario grades a scene no player ever starts — which is
    exactly how the SegmentHost defect above survived a green suite. This does
    not force them equal (the 57 scenarios carry absolute frame numbers tied to
    main.tscn); it forces the difference to stay VISIBLE."""
    project = (REPO_ROOT / "project.godot").read_text(encoding="utf-8")
    main_scene = ""
    for line in project.splitlines():
        if line.startswith("run/main_scene="):
            main_scene = line.split("=", 1)[1].strip().strip('"')
            break
    assert main_scene, "project.godot declares no run/main_scene"

    common = (REPO_ROOT / "playtest" / "_common.yaml").read_text(encoding="utf-8")
    boot = ""
    for line in common.splitlines():
        if line.startswith("scene:"):
            boot = line.split(":", 1)[1].strip()
            break
    assert boot, "the contract declares no boot scene"

    if boot != main_scene:
        assert "run/main_scene" in common, (
            "the contract boots %s while the game boots %s, and _common.yaml "
            "does not say so. A scenario suite that never starts the scene the "
            "player starts cannot see a defect that lives in it — that is how "
            "menu.tscn's SegmentHost swallowed every click through 57 green "
            "scenarios. Document the gap in the header, and say which "
            "properties of the boot scene are therefore UNTESTED."
            % (boot, main_scene))


# ---------------------------------------------------------------------------
# fix_static_guards (2026-08-28): two more static guards in the family of
# test_every_full_rect_host_is_click_through.
# ---------------------------------------------------------------------------

# Two-place sync for the four camera/visibility-round scenarios: the tail
# "trait_hover_preview, portrait_grid_alignment, language_zh_default,
# camera_transform_follows_unit" sits at ROUND_SCENARIOS and in _common.yaml's
# scenario_order — mirrored in BOTH places (test_round_scenarios_present_on_disk_and_in_order
# checks that pairing). The entries are already present in both places — this
# comment documents the sync point; do NOT add a duplicate.

# Block -> script mapping for the whitelist-existence guard. The card's
# "Enemy" is NOT a surface block name; it means scripts/characters/enemy.gd,
# the shared script behind all five enemy-unit blocks (differently-named
# instances). Sparring_Partner is intentionally outside the curated map.
BLOCK_SCRIPT_MAP: dict = {
    "Player": "scripts/characters/player.gd",
    "East_Heretic": "scripts/characters/enemy.gd",
    "West_Poison": "scripts/characters/enemy.gd",
    "South_Emperor": "scripts/characters/enemy.gd",
    "North_Beggar": "scripts/characters/enemy.gd",
    "Central_Divine": "scripts/characters/enemy.gd",
    "HUD": "scripts/ui/hud.gd",
    "HealthBar": "scripts/ui/health_bar.gd",
    "TileMarkers": "scripts/ui/tile_markers.gd",
    "CreationScreen": "scripts/segments/creation.gd",
    "MapScreen": "scripts/segments/map.gd",
    "SettingsManager": "scripts/autoload/settings_manager.gd",
}

# Godot built-in Control/CanvasItem properties whitelisted on the surface but
# NOT `var`-declared by the script (inherited, not script members). If a mapped
# block starts whitelisting another inherited property, add it here WITH a
# comment — never delete the check for a var that should be a script member.
BUILTIN_CONTROL_PROPS: set = {
    "visible", "size", "global_position", "text",
    "mouse_filter", "focus_mode", "disabled", "rect_position",
}

# Anchored to a code line so a `# var x` comment cannot false-positive: its
# first token after [ \t]* is `#`, not a var-prefix. `@?[a-z_]*` covers
# `@onready` / `@export` / a bare `var`.
_VAR_DECL_RE = r"^[ \t]*@?[a-z_]*\s*var\s+"


def test_settings_language_zh_default() -> None:
    """Pin the language-zh default structurally (2026-08-28 regression).

    The regression this guards: a RENDER-mode harness run produced
    SettingsManager.language=en, and 10 scenarios asserting the Chinese source
    strings byte-for-byte went red. Two structural facts must hold forever:

    (a) _detect_language() contains `if not OS.has_feature("web"):` immediately
        followed by `return "zh"` — headless/RENDER/editor runs are always zh
        ("am I a real player" is asked by the web feature, not by headlessness).
    (b) _load() applies a persisted language value ONLY inside an
        `if OS.has_feature("template"):` block — the editor/harness run must
        never be steered by a settings.cfg another scenario wrote, while a
        real exported player (template=true) still gets their choice back.

    Coupling note: the SettingsManager surface block whitelists `language`
    (a real var in settings_manager.gd), so this test and
    test_whitelisted_observables_exist_in_scripts both read the same script —
    keep them consistent if the persisted-key layout changes.
    """
    src = (REPO_ROOT / "scripts" / "autoload" / "settings_manager.gd").read_text(
        encoding="utf-8")

    det = re.search(r"func _detect_language\(\)[^:]*:.*?(?=\nfunc \w+|\Z)",
                    src, re.DOTALL)
    assert det is not None, "settings_manager.gd has no _detect_language()"
    det_body = det.group(0)
    assert re.search(
        r'if not OS\.has_feature\("web"\):\s*\n\s*return "zh"', det_body
    ), ("_detect_language() lost its `if not OS.has_feature(\"web\"):` -> "
        "`return \"zh\"` guard: headless/RENDER runs would fall through to "
        "locale detection and the Chinese-source assertions would go red.")

    load = re.search(r"func _load\(\)[^:]*:.*?(?=\nfunc \w+|\Z)", src, re.DOTALL)
    assert load is not None, "settings_manager.gd has no _load()"
    load_body = load.group(0)

    tmpl = re.search(r'^([ \t]*)if OS\.has_feature\("template"\):',
                     load_body, re.MULTILINE)
    assert tmpl is not None, ("_load() no longer gates the persisted-language "
                              "read behind `if OS.has_feature(\"template\"):`")
    indent = tmpl.group(1)

    lang_writes = re.findall(r"^([ \t]*)language\s*=", load_body, re.MULTILINE)
    assert lang_writes, "_load() writes `language` nowhere — the persisted " \
        "value would be silently dropped"
    deeper = [w for w in lang_writes if len(w) > len(indent)]
    assert len(deeper) == len(lang_writes), (
        "the ONLY place _load() may write `language` is inside the "
        "`if OS.has_feature(\"template\"):` block; found a write at indent "
        "%r while the block sits at %r" % (lang_writes, indent))

    assert 'cfg.get_value("general", "language"' in load_body, (
        "_load() no longer reads the persisted language value from "
        "general/language — a desktop player's choice would not survive a "
        "restart")


def test_whitelisted_observables_exist_in_scripts() -> None:
    """Every observable whitelisted under a mapped surface block must be a
    real `var` declaration in the block's mapped script.

    The negative case this exists to catch: a whitelisted var missing from its
    script — the debug_click_target_fires regression, where the scenario read
    `Invalid named index 'debug_click_target_fires'` because the counter was
    never declared (and so never written — a never-written observable reads
    exactly like a false reading). Blocks NOT in BLOCK_SCRIPT_MAP are skipped:
    they are node/button blocks whose whitelist entries are Godot built-ins
    (visible / text / size / ...). If a mapped block exposes a var via
    get()/set() or inheritance rather than a declaration, narrow the mapping
    or extend BUILTIN_CONTROL_PROPS with a comment — never delete the check
    for a var that should be a script member.
    """
    blocks = _surface_blocks(COMMON.read_text(encoding="utf-8"))
    # Guard against a silent no-op: if the parser ever collapses these blocks
    # to empty lists, the inner loop below would vacuously pass forever.
    for must_exist in ("Player", "HUD", "MapScreen"):
        assert blocks.get(must_exist), (
            "surface block %r parsed as empty — _surface_blocks() regexes no "
            "longer match playtest/_common.yaml" % must_exist)
    missing = []
    for block, rel in BLOCK_SCRIPT_MAP.items():
        script = (REPO_ROOT / rel).read_text(encoding="utf-8")
        for name in blocks.get(block, []):
            if name in BUILTIN_CONTROL_PROPS:
                continue  # Control-inherited built-in, not a script member
            if not re.search(_VAR_DECL_RE + re.escape(name) + r"\b",
                             script, re.MULTILINE):
                missing.append("%s.%s (expected in %s)" % (block, name, rel))
    assert not missing, (
        "whitelisted surface observables with no `var` declaration in their "
        "mapped script (they would read as a parse error or a stale initial "
        "value in Expression asserts): " + "; ".join(missing))


# ---------------------------------------------------------------------------
# Touch-reach round pins (2026-08-29): clicks-only keyboard-free + surface
# existence.
# ---------------------------------------------------------------------------

# The verified seeding/debug prefix token set from facility_use_reusable.yaml
# (read the ACTUAL file, never a design list): ui_accept, move_right,
# debug_win_tutorial, debug_fast_forward, debug_grant_silver.
_FACILITY_COMPANION_ALLOWED_ACTIONS: frozenset = frozenset({
    "ui_accept", "move_right", "debug_win_tutorial",
    "debug_fast_forward", "debug_grant_silver",
})


def _extract_action_tokens(text: str) -> list[tuple[int, str]]:
    """Extract (line_number, token) pairs for every action item in a scenario.

    Parses the YAML text using stdlib regex only (no PyYAML). An action item
    is a line matching `^  - (\\S+)$` that follows a `^  actions:$` line
    (within the same timeline entry, before the next `^  [a-z_]+:$` key or
    `^- ` timeline entry).
    """
    lines = text.splitlines()
    results: list[tuple[int, str]] = []
    in_actions = False
    for lineno, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if stripped == "actions:":
            in_actions = True
            continue
        if in_actions:
            m = re.match(r"^  - (\S+)$", raw)
            if m:
                results.append((lineno, m.group(1)))
            elif stripped == "" :
                continue
            else:
                # Any other key or timeline entry ends the actions block
                in_actions = False
    return results


def _extract_click_tokens(text: str) -> list[tuple[int, str]]:
    """Extract (line_number, token) pairs for every click item in a scenario."""
    lines = text.splitlines()
    results: list[tuple[int, str]] = []
    in_clicks = False
    for lineno, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if stripped == "clicks:":
            in_clicks = True
            continue
        if in_clicks:
            m = re.match(r"^  - (\S+)", raw)
            if m:
                results.append((lineno, m.group(1)))
            elif stripped == "":
                continue
            else:
                in_clicks = False
    return results


def test_clicks_only_storyline_is_keyboard_free() -> None:
    """The clicks-only spine and its facility companion must not smuggle in
    keyboard actions.

    This is a self-explaining pin: if you are legitimately changing a
    documented seed or adding a non-keyboard action, update THIS pin's
    allowance in the same change — do not delete the pin to go green, and
    never smuggle a keyboard action where a click is required.

    Rules:
      clicks_only_storyline.yaml:
        - Every actions: token must be `debug_win_tutorial` (the ONE
          documented battle-outcome seed).
      map_facility_buttons_click.yaml:
        - actions: tokens restricted to the verified seeding/debug prefix
          set {ui_accept, move_right, debug_win_tutorial, debug_fast_forward,
          debug_grant_silver}.
        - NO actions: entry after the first FacilityEnterButton click line.
      Both files:
        - >= 5 clicks: entries.
        - No clicks token may end in `_ClickTarget`.
    """
    # ── clicks_only_storyline.yaml ─────────────────────────────────────────
    spine_path = PLAYTEST_DIR / "clicks_only_storyline.yaml"
    assert spine_path.is_file(), "clicks_only_storyline.yaml missing"
    spine_text = spine_path.read_text(encoding="utf-8")
    spine_actions = _extract_action_tokens(spine_text)
    bad_actions = [
        (ln, tok) for ln, tok in spine_actions if tok != "debug_win_tutorial"
    ]
    assert not bad_actions, (
        "clicks_only_storyline.yaml contains non-allowed actions: %s. "
        "The ONLY allowed action is `debug_win_tutorial` (the documented "
        "battle-outcome seed). If you are legitimately changing a documented "
        "seed, update this pin's allowance in the same change — do not "
        "delete the pin to go green, and never smuggle a keyboard action "
        "where a click is required." % (bad_actions,)
    )
    spine_clicks = _extract_click_tokens(spine_text)
    assert len(spine_clicks) >= 5, (
        "clicks_only_storyline.yaml has %d clicks entries; >= 5 required "
        "(a clicks-only scenario with fewer than 5 clicks cannot traverse "
        "the six-segment spine)" % len(spine_clicks)
    )
    for ln, tok in spine_clicks:
        assert not tok.endswith("_ClickTarget"), (
            "clicks_only_storyline.yaml line %d: click token %r ends in "
            "_ClickTarget. Anchors must target the control/unit body itself "
            "(2026-08-29 90_decisions.md ruling)." % (ln, tok)
        )

    # ── map_facility_buttons_click.yaml ────────────────────────────────────
    fac_path = PLAYTEST_DIR / "map_facility_buttons_click.yaml"
    assert fac_path.is_file(), "map_facility_buttons_click.yaml missing"
    fac_text = fac_path.read_text(encoding="utf-8")
    fac_actions = _extract_action_tokens(fac_text)
    bad_fac = [
        (ln, tok) for ln, tok in fac_actions
        if tok not in _FACILITY_COMPANION_ALLOWED_ACTIONS
    ]
    assert not bad_fac, (
        "map_facility_buttons_click.yaml contains disallowed actions: %s. "
        "Allowed tokens are %s. If you are legitimately adding a new "
        "documented debug action, update this pin's allowlist in the same "
        "change — do not delete the pin to go green." % (
            bad_fac, sorted(_FACILITY_COMPANION_ALLOWED_ACTIONS))
    )
    fac_clicks = _extract_click_tokens(fac_text)
    assert len(fac_clicks) >= 5, (
        "map_facility_buttons_click.yaml has %d clicks entries; >= 5 "
        "required" % len(fac_clicks)
    )
    for ln, tok in fac_clicks:
        assert not tok.endswith("_ClickTarget"), (
            "map_facility_buttons_click.yaml line %d: click token %r ends "
            "in _ClickTarget (2026-08-29 ruling)." % (ln, tok)
        )

    # Facility leg: NO actions after the first FacilityEnterButton click.
    first_enter_ln: int = -1
    for ln, tok in fac_clicks:
        if tok == "FacilityEnterButton":
            first_enter_ln = ln
            break
    assert first_enter_ln > 0, (
        "map_facility_buttons_click.yaml has no FacilityEnterButton click "
        "(the facility leg must click it)"
    )
    post_facility_actions = [
        (ln, tok) for ln, tok in fac_actions if ln > first_enter_ln
    ]
    assert not post_facility_actions, (
        "map_facility_buttons_click.yaml has actions after the first "
        "FacilityEnterButton click (line %d): %s. The facility leg must "
        "contain NO actions — all interaction is clicks only. If you are "
        "legitimately restructuring, update this pin in the same change." % (
            first_enter_ln, post_facility_actions)
    )


def test_clicks_only_gongfa_empty_exit_is_keyboard_free() -> None:
    """The GONGFA_PICK empty-exit nail must be clicks-only and click-real.

    Self-explaining pin mirroring test_clicks_only_storyline_is_keyboard_free:
    this scenario proves the touch-only exit out of the empty GONGFA_PICK
    dead-end, so it must not smuggle in a KEYBOARD action (a keyboard return
    would prove nothing about the finger path) and must land >= 3 real clicks
    (card, 练功, 返回行动). Every click anchors the control body, never a
    *_ClickTarget.

    The ONE allowed action is `debug_seed_save` — the documented no-sect save
    seed (the same sanctioned non-keyboard role `debug_win_tutorial` plays in
    clicks_only_storyline: it seeds a fresh no-sect CULTIVATION save so a direct
    cultivation boot is not required and decks are initialized). Any other
    action, especially a keyboard one, reds.
    """
    path = PLAYTEST_DIR / "clicks_only_gongfa_empty_exit.yaml"
    assert path.is_file(), "clicks_only_gongfa_empty_exit.yaml missing"
    text = path.read_text(encoding="utf-8")
    actions = _extract_action_tokens(text)
    bad_actions = [
        (ln, tok) for ln, tok in actions if tok != "debug_seed_save"
    ]
    assert not bad_actions, (
        "clicks_only_gongfa_empty_exit.yaml contains keyboard/action tokens: %s. "
        "The ONLY allowed action is `debug_seed_save` (the no-sect save seed). "
        "This scenario must otherwise be clicks-only — it proves the finger-only "
        "exit out of the empty GONGFA_PICK dead-end. If you are legitimately "
        "changing the documented seed, update this pin's allowance in the same "
        "change — do not delete the pin to go green." % (bad_actions,)
    )
    clicks = _extract_click_tokens(text)
    assert len(clicks) >= 3, (
        "clicks_only_gongfa_empty_exit.yaml has %d clicks entries; >= 3 required "
        "(card, 练功, 返回行动)." % len(clicks)
    )
    for ln, tok in clicks:
        assert not tok.endswith("_ClickTarget"), (
            "clicks_only_gongfa_empty_exit.yaml line %d: click token %r ends in "
            "_ClickTarget. Anchors must target the control/unit body itself "
            "(2026-08-29 90_decisions.md ruling)." % (ln, tok)
        )


def test_touch_reach_surface_contract() -> None:
    """The 12 new touch-reach surface blocks + 5 pressed_connected vars +
    GameManager.end_overlay_pressed_connected exist in _common.yaml.

    This is a whitelist-existence gate: it exists so newly published
    observables cannot be silently deleted. If you are renaming or
    refactoring these observables, the correct fix is to update this pin
    and the equivalent assertions in the same change — do not keep dead old
    names to go green, and do not route around the rename.
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)

    _escape = (
        " (whitelist-existence gate). This gate exists so newly published "
        "observables cannot be silently deleted. If you are RENAMING or "
        "REFACTORING these observables, the correct fix is to update THIS "
        "PIN and the equivalent assertions in the same change — do not keep "
        "dead old names to go green, and do not route around the rename."
    )

    # The 12 new blocks (each with visible, size, mouse_filter, text).
    new_blocks: list[tuple[str, list[str]]] = [
        ("ContinueButton", ["visible", "size", "mouse_filter", "text",
                            "disabled", "focus_mode"]),
        ("RetryButton", ["visible", "size", "mouse_filter", "text",
                         "disabled", "focus_mode"]),
        ("NextButton", ["visible", "size", "mouse_filter", "text"]),
        ("SectButton0", ["visible", "size", "mouse_filter", "text"]),
        ("CultOptionButton0", ["visible", "size", "mouse_filter", "text"]),
        ("CultOptionButton2", ["visible", "size", "mouse_filter", "text"]),
        ("TravelButton0", ["visible", "size", "mouse_filter", "text"]),
        ("EventOptionButton0", ["visible", "size", "mouse_filter", "text"]),
        ("RestartButton", ["visible", "size", "mouse_filter", "text"]),
        ("FacilityEnterButton", ["visible", "size", "mouse_filter", "text"]),
        ("FacilityUseButton", ["visible", "size", "mouse_filter", "text"]),
        ("FacilityLeaveButton", ["visible", "size", "mouse_filter", "text"]),
    ]
    for block_name, required_vars in new_blocks:
        assert block_name in blocks, (
            "surface missing %s block" % block_name
        ) + _escape
        for var in required_vars:
            assert var in blocks[block_name], (
                "surface %s block missing %s" % (block_name, var)
            ) + _escape

    # The 5 pressed_connected additions to existing screen blocks.
    for screen in ("TransitionScreen", "SectSelectScreen",
                   "CultivationScreen", "MapScreen", "EndingScreen"):
        assert screen in blocks, (
            "surface missing %s block" % screen
        ) + _escape
        assert "pressed_connected" in blocks[screen], (
            "surface %s block missing pressed_connected" % screen
        ) + _escape

    # GameManager.end_overlay_pressed_connected
    assert "GameManager" in blocks, "surface missing GameManager block" + _escape
    assert "end_overlay_pressed_connected" in blocks["GameManager"], (
        "surface GameManager block missing end_overlay_pressed_connected"
    ) + _escape


def test_equipment_surface_contract() -> None:
    """Static contract pin for the jinyong-equipment-battle round.

    Pins ``roster_equip_free_action`` and ``equipment_in_battle_diff`` against
    ``playtest/_common.yaml`` and ``ROUND_SCENARIOS`` (two-place sync):

    - The 5 RosterPanel equipment observables (equipped_weapon /
      equipped_armor / equipped_boots / equip_button_count /
      equip_pressed_connected) are whitelisted on the surface.
    - The 4 Player gear observables (gear_attack_bonus / gear_health_bonus /
      gear_initiative_bonus / gear_move_bonus) are whitelisted.
    - Both scenario names appear in scenario_order AND in ROUND_SCENARIOS.
    - Each scenario file carries at least one differential ``: changed`` line.
    - No ``*_ClickTarget`` appears in any clicks list in the two files.
    """
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)

    # The 5 RosterPanel equipment observables are whitelisted.
    assert "RosterPanel" in blocks, "surface has no RosterPanel block"
    roster_items = blocks["RosterPanel"]
    assert roster_items, "RosterPanel surface block parsed empty (vacuous pass guard)"
    roster_equipment_vars = (
        "equipped_weapon", "equipped_armor", "equipped_boots",
        "equip_button_count", "equip_pressed_connected",
    )
    for var in roster_equipment_vars:
        assert var in roster_items, (
            f"RosterPanel.{var} not whitelisted on the surface"
        )

    # The 4 Player gear observables are whitelisted.
    assert "Player" in blocks, "surface has no Player block"
    player_items = blocks["Player"]
    assert player_items, "Player surface block parsed empty (vacuous pass guard)"
    player_gear_vars = (
        "gear_attack_bonus", "gear_health_bonus",
        "gear_initiative_bonus", "gear_move_bonus",
    )
    for var in player_gear_vars:
        assert var in player_items, (
            f"Player.{var} not whitelisted on the surface"
        )

    # Two-place sync: both scenario names in scenario_order AND ROUND_SCENARIOS.
    order = _items_under(text, "scenario_order")
    for name in ("roster_equip_free_action", "equipment_in_battle_diff"):
        assert name in order, (
            f"{name} not in _common.yaml scenario_order (two-place sync)"
        )
        assert name in ROUND_SCENARIOS, (
            f"{name} not in ROUND_SCENARIOS (two-place sync)"
        )

    # Per-file static checks.
    for name in ("roster_equip_free_action", "equipment_in_battle_diff"):
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
        assert has_diff_line, (
            f"{name}.yaml missing a line ending `: changed` "
            f"(differential rule)"
        )

        # No *_ClickTarget in clicks.
        for item in _items_under(ftext, "clicks"):
            target = item.split()[0]
            assert not target.endswith("_ClickTarget"), (
                f"{name}.yaml uses forbidden *_ClickTarget: {target}"
            )


def test_occlusion_watch_surface_contract() -> None:
    """Static contract pin for the jinyong-loop R2 occlusion_watch_gate task.

    Pins the structural occlusion gate (D6): the UiOcclusionWatch surface
    block (violations / violations_text plus the crash-proofing scan-health
    observables scan_ok / scan_failed_frames) is whitelisted on the
    ``playtest/_common.yaml`` surface section, the scenario
    ``occlusion_no_button_over_text`` is in scenario_order AND in
    ROUND_SCENARIOS (two-place sync), the scenario file exists with
    ``name:`` equal to its basename, every timeline ``at:`` is a single
    integer, and the file carries at least one
    ``UiOcclusionWatch.violations: violations == 0`` property assert.

    COORDINATE-LITERAL FORBIDDEN ZONE: no 4-space dotted ASSERT line may
    contain ``offset_``. A legal layout re-tweak (e.g. moving the sect button
    column a few px further right) would otherwise falsely red a stale
    geometry pin; the gate asserts ONLY the published property
    ``violations == 0`` — zero coordinate-literal asserts anywhere. The ban is
    scoped to the dotted assert lines deliberately: the scenario's header
    comments legitimately document the red-first revert-recipe offsets, and a
    comment is not an assert.
    """
    name = "occlusion_no_button_over_text"
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "UiOcclusionWatch" in blocks, "surface has no UiOcclusionWatch block"
    watch_items = blocks["UiOcclusionWatch"]
    assert watch_items, "UiOcclusionWatch surface block parsed empty (vacuous pass guard)"
    for var in ("violations", "violations_text", "scan_ok", "scan_failed_frames"):
        assert var in watch_items, (
            f"UiOcclusionWatch.{var} not whitelisted on the surface"
        )

    # Two-place sync: scenario_order AND ROUND_SCENARIOS.
    order = _items_under(text, "scenario_order")
    assert name in order, f"{name} not in _common.yaml scenario_order (two-place sync)"
    assert name in ROUND_SCENARIOS, f"{name} not in ROUND_SCENARIOS (two-place sync)"

    # Scenario file static checks.
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    has_property = False
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
            assert has_op, (
                f"{name}.yaml line {lineno} assert missing comparison operator: "
                f"{line.strip()}"
            )
            # Coordinate-literal forbidden zone (R1 order): a layout re-tweak
            # must not falsely red this gate; only the published property is
            # asserted. Scoped to the 4-space dotted ASSERT lines only — the
            # scenario's documentation comments legitimately mention the
            # revert-recipe offsets, and a comment is not an assert.
            assert "offset_" not in line, (
                f"{name}.yaml line {lineno} carries a forbidden coordinate-literal "
                f"assert (offset_): {line.strip()}"
            )
            if "violations == 0" in line:
                has_property = True
    assert has_property, (
        f"{name}.yaml missing a `violations == 0` property assert"
    )

    # Evidence-record pin (reviewer feedback): the threshold-rationale + tutorial
    # other-6-pages measurement record cannot be silently dropped in a future
    # round. The gate's >=4px / >=0.5 thresholds are justified only by the
    # measured per-axis intersections and residual visibilities recorded there.
    delivery = (
        Path(__file__).resolve().parents[1]
        / "final"
        / "delivery_notes_loop_occlusion_watch.md"
    )
    assert delivery.is_file(), (
        "final/delivery_notes_loop_occlusion_watch.md missing — the occlusion "
        "gate's threshold-rationale evidence record must not be dropped"
    )


def test_event_option_refused_nail_contract() -> None:
    """Static anti-weakening pins for the jinyong-loop all-or-nothing purchase nail.

    The nail (``event_option_refused_no_charge``) pins design D4: ``apply_option_effects``
    is validate-then-apply, so a purchase whose item is already owned (or whose silver
    cost cannot be paid) is REFUSED as a whole option — zero profile mutation and an
    on-screen receipt. The scenario grants the already-owned ``eq_sword_3`` through the
    whitelisted ``debug_grant_equip`` action and pins the ZERO DELTA on silver. Hard pins:

      1. the scenario name is present in ``scenario_order`` in ``playtest/_common.yaml``
         AND ``ROUND_SCENARIOS`` here at the same relative order (two-place sync);
      2. the file exists with ``name:`` == its basename;
      3. every timeline ``at:`` is a single integer;
      4. the file MUST carry the zero-delta line ``silver == event_open_silver`` (the
         whole refused option changed silver by nothing), a ``phase == \"TRAVEL\"`` line
         (refusal still resolves the encounter — no new soft-lock), an
         ``events_resolved_count`` ladder rung, the on-screen receipt line
         ``map_status_text != \"\"``, and the ``debug_grant_equip`` seeding line (the
         owned item enters through the REAL item pipeline, then the pick is refused);
      5. the surface whitelist contains ``event_open_silver`` and ``map_status_text``
         under the ``MapScreen`` block — the differential anchors must be whitelisted.
    """
    name = "event_option_refused_no_charge"
    order_text = COMMON.read_text(encoding="utf-8")
    order_names = _items_under(order_text, "scenario_order")
    assert name in order_names, f"{name} missing from scenario_order"
    assert name in ROUND_SCENARIOS, f"{name} missing from ROUND_SCENARIOS"
    assert [n for n in order_names if n in ROUND_SCENARIOS] == ROUND_SCENARIOS, (
        f"{name}: scenario_order and ROUND_SCENARIOS disagree on presence or "
        "relative order"
    )
    path = PLAYTEST_DIR / (name + ".yaml")
    assert path.is_file(), f"{name}.yaml missing"
    ftext = path.read_text(encoding="utf-8")
    assert re.search(
        rf"^name:\s*{name}\s*$", ftext, re.MULTILINE
    ), f"{name}.yaml name: does not equal its basename"
    for lineno, line in enumerate(ftext.splitlines(), start=1):
        match = re.search(r"\bat\s*:\s*([^,}\s]+)", line)
        if match and not match.group(1).isdigit():
            assert False, (
                f"{name}.yaml line {lineno}: non-integer timeline "
                f"'at' value {match.group(1)!r}"
            )
    for mandatory in (
        "silver == event_open_silver",
        'phase == "TRAVEL"',
        "events_resolved_count",
        'map_status_text != ""',
        "debug_grant_equip",
    ):
        assert mandatory in ftext, (
            f"{name}.yaml missing the mandatory differential/receipt/seeding line "
            f"`{mandatory}`"
        )
    # The differential anchors must be whitelisted on the MapScreen surface block —
    # the zero-delta proof cannot be asserted if harness cannot read either side.
    blocks = _surface_blocks(COMMON.read_text(encoding="utf-8"))
    assert "MapScreen" in blocks, "surface has no MapScreen block"
    map_items = blocks["MapScreen"]
    for var in ("event_open_silver", "map_status_text"):
        assert var in map_items, (
            f"MapScreen.{var} not whitelisted on the surface — the refusal nail's "
            "zero-delta anchor is unreadable"
        )
