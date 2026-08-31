"""Static guards for the jinyong-equipment-battle round.

Three invariants, each with the escape clause: "if you are renaming/moving
this guarantee, update this guard in the same change — do not delete it to
go green."

(a) roster_panel.gd contains no autosave/save_game/save_profile call —
    equipment follows the cultivation save/load model (change profile,
    do not persist). Ruling (b) is a ruling, not a vulnerability.

(b) _common.yaml RosterPanel block contains the 5 new equipment observables
    (equipped_weapon / equipped_armor / equipped_boots / equip_button_count /
    equip_pressed_connected). Append-only surface whitelist.

(c) Every EquipButton occurrence in scenes/ui/roster_panel.tscn carries
    focus_mode = 0. Buttons holding Godot built-in focus swallow ui_up/ui_down
    before _unhandled_input (defect class pinned by battle_focus_arrow_keys.yaml).
"""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ROSTER_GD = REPO_ROOT / "scripts" / "ui" / "roster_panel.gd"
COMMON_YAML = REPO_ROOT / "playtest" / "_common.yaml"
ROSTER_TSCN = REPO_ROOT / "scenes" / "ui" / "roster_panel.tscn"

_ESCAPE = (
    " If you are renaming or moving this guarantee, update this guard in "
    "the same change — do not delete it to go green."
)

# The 5 new observables the jinyong-equipment-battle round appends to the
# RosterPanel surface block.
EQUIPMENT_ROSTER_OBSERVABLES: tuple[str, ...] = (
    "equipped_weapon",
    "equipped_armor",
    "equipped_boots",
    "equip_button_count",
    "equip_pressed_connected",
)


def _strip_gdscript_comments(text: str) -> str:
    """Remove whole-line GDScript comments from source text.

    A line is stripped if its first non-whitespace character is '#'
    (covers both single-# comments and ## doc-comments).  Inline /
    trailing comments on code lines are preserved — the guard is
    intentionally conservative (red rather than miss).

    Mirrors the repo precedent for comment-tolerant token scanning
    (tests/test_playtest_contract_smoke.py::_bad_timeline_at_values).
    """
    lines = text.split("\n")
    kept = [ln for ln in lines if not ln.lstrip().startswith("#")]
    return "\n".join(kept)


def test_no_autosave_in_roster_panel() -> None:
    """(a) roster_panel.gd must not call autosave/save_game/save_profile.

    Ruling (b): equipment follows the cultivation save/load model — change
    the profile, never persist. Adding an autosave call would silently
    violate this ruling; the guard makes it mechanical.

    Comment lines are stripped before scanning so the doc-comment at
    roster_panel.gd:8 (which legitimately names the method to document
    the invariant) does not false-positive the guard.
    """
    text = _strip_gdscript_comments(ROSTER_GD.read_text(encoding="utf-8"))
    for forbidden in ("autosave(", "save_game(", "save_profile("):
        assert forbidden not in text, (
            f"roster_panel.gd contains forbidden call {forbidden!r} — "
            f"equipment must not trigger autosave (ruling b)." + _ESCAPE
        )


def test_no_autosave_guard_strips_comment_lines() -> None:
    """Regression: comment lines naming the forbidden method are stripped,
    so the guard passes on the real roster_panel.gd and on synthetic
    comment-only text.

    Acceptance criterion 1: the real file's stripped text must NOT contain
    "autosave(" (line 8 doc-comment is the sole occurrence and is stripped).
    Acceptance criterion 2: synthetic "## the panel never calls
    SaveManager.autosave() here.\n" strips to empty; "## x.autosave()\nvar y = 1\n"
    strips to "var y = 1".
    """
    # Real file: the only occurrence of "autosave(" is in a ## doc-comment.
    raw = ROSTER_GD.read_text(encoding="utf-8")
    assert "autosave(" in raw, (
        "Sanity check failed: expected 'autosave(' to appear in "
        "roster_panel.gd raw text (inside the doc-comment at line 8). "
        "If the comment was removed or reworded, this test's premise "
        "is outdated — update the test."
    )
    stripped = _strip_gdscript_comments(raw)
    assert "autosave(" not in stripped, (
        "After stripping comment lines, 'autosave(' should be absent from "
        "roster_panel.gd. If present, a REAL (non-comment) call exists "
        "and the main guard (a) should catch it."
    )

    # Synthetic: a comment-only line strips to empty.
    synthetic_comment_only = "## the panel never calls SaveManager.autosave() here.\n"
    result = _strip_gdscript_comments(synthetic_comment_only)
    assert "autosave(" not in result, (
        "Comment line naming autosave() must be stripped entirely."
    )

    # Synthetic: comment line removed, code line preserved verbatim.
    synthetic_mixed = "## x.autosave()\nvar y = 1\n"
    result_mixed = _strip_gdscript_comments(synthetic_mixed)
    assert result_mixed == "var y = 1", (
        f"Expected 'var y = 1' after stripping, got {result_mixed!r}. "
        "Comment lines must be removed; code lines preserved verbatim."
    )


def test_no_autosave_guard_still_catches_real_calls() -> None:
    """Regression: a genuine non-comment 'autosave(' line in the file body
    is NOT stripped and would red the guard.

    Acceptance criterion 3: "var cb := func(): SaveManager.autosave()\n"
    retains "autosave(" after stripping (the guard would fail correctly).
    """
    real_call_text = "var cb := func(): SaveManager.autosave()\n"
    stripped = _strip_gdscript_comments(real_call_text)
    assert "autosave(" in stripped, (
        "A real (non-comment) line containing 'autosave(' must survive "
        "comment stripping — the guard must still be able to catch it."
    )

    # Also verify the full token set: save_game( and save_profile( on a
    # real code line are not stripped.
    for token in ("save_game(", "save_profile("):
        # Realistic call line: "    SaveManager.save_game()\n"
        call_line = f"    SaveManager.{token[:-1]}()\n"
        stripped_call = _strip_gdscript_comments(call_line)
        assert token in stripped_call, (
            f"Token {token!r} on a real code line must survive stripping."
        )


def test_common_yaml_roster_panel_equipment_observables() -> None:
    """(b) _common.yaml RosterPanel block contains the 5 new observables.

    The surface whitelist is append-only: these 5 observables were added by
    the jinyong-equipment-battle round and must remain whitelisted for the
    two new scenarios to reference them.
    """
    text = COMMON_YAML.read_text(encoding="utf-8")
    # Parse the RosterPanel block: find "  RosterPanel:" and collect items
    # until the next block (a line matching "^  \S" that is not an item).
    lines = text.splitlines()
    in_block = False
    items: list[str] = []
    for raw in lines:
        if raw.strip() == "RosterPanel:":
            in_block = True
            continue
        if in_block:
            m = re.match(r"^  - (\S+)", raw)
            if m:
                items.append(m.group(1))
            elif raw.strip() == "" :
                continue
            elif re.match(r"^  \S", raw):
                # Next block header — stop.
                break
            else:
                # Something unexpected — stop.
                break

    assert items, (
        "RosterPanel surface block parsed empty (vacuous pass guard)."
        + _ESCAPE
    )
    for var in EQUIPMENT_ROSTER_OBSERVABLES:
        assert var in items, (
            f"RosterPanel.{var} not whitelisted on the surface block in "
            f"_common.yaml." + _ESCAPE
        )


def test_tscn_equip_buttons_focus_mode_zero() -> None:
    """(c) Every EquipButton in roster_panel.tscn carries focus_mode = 0.

    A Button holding Godot built-in focus swallows ui_up/ui_down before
    _unhandled_input (the defect class pinned by battle_focus_arrow_keys.yaml).
    The single-surface rule (ruling d) requires focus_mode = 0 on all new
    controls.
    """
    text = ROSTER_TSCN.read_text(encoding="utf-8")
    # Find every [node name="EquipButton..." block and check it contains
    # focus_mode = 0 before the next [node] or EOF.
    blocks = re.split(r"(?=\[node )", text)
    equip_blocks = [b for b in blocks if re.search(r'\[node name="EquipButton\d+"', b)]
    assert equip_blocks, (
        "No EquipButton nodes found in roster_panel.tscn — the scene-declared "
        "pool is missing." + _ESCAPE
    )
    for block in equip_blocks:
        node_match = re.search(r'\[node name="(EquipButton\d+)"', block)
        if node_match is None:
            continue
        name = node_match.group(1)
        assert "focus_mode = 0" in block, (
            f"{name} in roster_panel.tscn does not carry focus_mode = 0 — "
            f"buttons must not hold built-in focus (ruling d, "
            f"battle_focus_arrow_keys defect class)." + _ESCAPE
        )
