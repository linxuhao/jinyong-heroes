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


def test_no_autosave_in_roster_panel() -> None:
    """(a) roster_panel.gd must not call autosave/save_game/save_profile.

    Ruling (b): equipment follows the cultivation save/load model — change
    the profile, never persist. Adding an autosave call would silently
    violate this ruling; the guard makes it mechanical.
    """
    text = ROSTER_GD.read_text(encoding="utf-8")
    for forbidden in ("autosave(", "save_game(", "save_profile("):
        assert forbidden not in text, (
            f"roster_panel.gd contains forbidden call {forbidden!r} — "
            f"equipment must not trigger autosave (ruling b)." + _ESCAPE
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
