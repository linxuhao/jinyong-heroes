"""Static guard for the rewritten huashan map-battle gate (jinyong-huashan round).

The playtest contract `playtest/map_battle_node_huashan.yaml` is the one
sanctioned rewrite of an existing scenario this round — its whole purpose is to
prove the Huashan duel is FIGHTABLE, not merely LOADED. That proof rests on a
handful of load-bearing assertion literals that distinguish "the battle really
starts with the profile hero" from "a tutorial battle scene loaded":

  * `current_round >= 1`            — the round actually started (was 0)
  * `turn_order.size() == 6`        — the five greats + the profile hero
                                      (was empty []); this is the deliberate
                                      loud-failure pin: it may only change to 5
                                      under the MEASURED §D3 fallback (drop
                                      Central Divine) in lockstep with the
                                      sibling count pins — no other weakening
                                      is permitted
  * `tutorial_battle == false`      — profile build, not the tutorial path
  * `max_health != 1000`            — HP derived from the profile, not the
                                      tutorial Yang Guo's 1000
  * `events_resolved_count == 2`    — the pre-battle ladder anchor that must
                                      survive the duel on the WIN leg

This file is a pure text door in the same style as tests/test_facility_copy_location.py
and the facility anti-deletion pin: it scans the rewritten yaml and reddens if
any of those literals silently disappears (e.g. `>= 1` softened to `> 0`,
`size() == 6` retyped, a == dropped in favor of a bare scalar). Deliberately
stdlib-only and Godot-free so it runs in the ordinary pytest pass.

`turn_order.size() == 6` is an intentional anti-weakening nail: the ONLY legal
change is 6 -> 5 under the measured §D3 fallback, applied together with the
equivalent count pins in tests/test_map_battle_data.gd and
tests/test_map_battle_entry.gd (owned by the sibling data/battlefield tasks)
and with this file's literal updated in the same commit.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SCENARIO = ROOT / "playtest" / "map_battle_node_huashan.yaml"

# The load-bearing literals the rewritten gate must still contain. Each proves
# a distinct facet of "can fight" (see the module docstring); removing or
# weakening any of them would silently regress the gate back to "loaded".
LOAD_BEARING_LITERALS: tuple[str, ...] = (
    "current_round >= 1",
    "turn_order.size() == 6",
    "tutorial_battle == false",
    "max_health != 1000",
    "events_resolved_count == 2",
)


def _scenario_text() -> str:
    return SCENARIO.read_text(encoding="utf-8")


def test_scenario_exists() -> None:
    """The scenario file must exist and still carry the same scenario name."""
    assert SCENARIO.exists(), "playtest/map_battle_node_huashan.yaml is missing"
    text = _scenario_text()
    assert "name: map_battle_node_huashan" in text, (
        "scenario must keep its name: map_battle_node_huashan (same "
        "scenario_order slot — the 78-scenario registry is unchanged)"
    )


def test_load_bearing_literals_present() -> None:
    """Every load-bearing 'can fight' literal must still appear verbatim."""
    text = _scenario_text()
    missing = [lit for lit in LOAD_BEARING_LITERALS if lit not in text]
    assert not missing, (
        "the rewritten huashan gate lost a load-bearing 'can fight' literal — "
        "this is the anti-accidental-weakening door, do NOT remove or relax it:\n  "
        + "\n  ".join(missing)
        + "\n\nThe only sanctioned change is turn_order.size() == 6 -> 5 under "
        "the MEASURED §D3 fallback, in lockstep with the sibling count pins."
    )
