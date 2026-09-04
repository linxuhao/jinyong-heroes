"""Static anti-weakening door for the six R3 differential nails (r3_gate_sync_evidence).

The R3 round's proof rests on six playtest scenarios whose load-bearing lines are
**choice-differentials** — never balance literals, never a `== 90`-style pin. Each
scenario proves a distinct "choices change the outcome" fact:

  * (`ending_divergent_playstyles` / `ending_last_month_choice` — retired
     2026-09-04, see playtest/RETIRED.md; no longer pinned here)
  * `fortune_reroll_budget`        — the fortune reroll spends its budget and the
                                     exhausted press is inert
  * `action_yield_differential`    — work is the only action with a > 0 silver
                                     grant (the other three are == 0)
  * `huashan_readiness_warning`    — the readiness verdict STRING differs after
                                     growth (never a power literal)
  * `huashan_winnable_normal_route`— a normal route fights the duel for real
                                     (health < max_health) and the measured end
                                     state is pinned honestly (LOST per the
                                     2026-09-03 owner re-scope ruling); the WIN
                                     is carried to the world-breadth round

Differential assertions can be silently deleted — and the deletion itself must go
red. This file is a pure text door in the same style as
`tests/test_map_battle_gate_pins.py` and `tests/test_facility_copy_location.py`:
it scans each scenario yaml and reddens if any load-bearing literal disappears
(e.g. `!=` softened to `==`, a `> 0` dropped, a `changed` differential retyped).
Deliberately stdlib-only and Godot-free so it runs in the ordinary pytest pass.

It also guards the registry completeness: `playtest/_common.yaml` must still carry
every new surface name, and at least one red-first evidence note must exist under
`final/` (the red-first discipline is itself load-bearing — a round that stops
recording its reds is a round that stopped proving anything).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PLAYTEST = ROOT / "playtest"
COMMON = PLAYTEST / "_common.yaml"
FINAL = ROOT / "final"

# The six new R3 scenario files, each with the load-bearing differential lines
# that must survive verbatim. Removing or weakening any of them silently regresses
# the corresponding nail back to "loaded but not proven".
SCENARIO_LOAD_BEARING_LINES: dict[str, tuple[str, ...]] = {
    # ending_divergent_playstyles / ending_last_month_choice were retired on
    # 2026-09-04 (route-type scenarios, owner ruling); their differentials are
    # carried by tests/test_action_yield_curves.gd + tests/test_ending_logic.gd
    # — see playtest/RETIRED.md.
    "fortune_reroll_budget": (
        # Budget decrement (leg 1) and exhausted inertness (leg 2).
        "rerolls_left == 0",
        "events_seen_count == 0",
    ),
    "action_yield_differential": (
        # Zero-delta pins (practice/cultivate/travel grant no silver) ...
        "last_action_silver == 0",
        # ... and the work line that proves the unique silver niche.
        "last_action_silver > 0",
    ),
    "huashan_readiness_warning": (
        # Verdict STRING differential (never a power literal).
        'readiness_text != "华山评估：战备不足"',
    ),
    "huashan_winnable_normal_route": (
        # Honest-LOST end state (2026-09-03 owner re-scope ruling): the fight
        # was real (health < max_health) and the measured end state is pinned
        # honestly (LOST + RetryButton overlay). The WIN is carried to the
        # world-breadth round with the 36/48 baseline.
        'current_state == "LOST"',
        "health < max_health",
        "RetryButton.visible",
    ),
}

# Every new surface must still be registered under the correct node in
# `playtest/_common.yaml` (append-only registry completeness).
COMMON_SURFACES: tuple[str, ...] = (
    "rerolls_left",
    "last_action_kind",
    "last_action_silver",
    "last_yield_text",
    "last_practice_target",
    "last_practice_amount",
    "score",
    "evaluation_text",
    "readiness_text",
)


def _scenario_text(name: str) -> str:
    return (PLAYTEST / f"{name}.yaml").read_text(encoding="utf-8")


def _common_text() -> str:
    return COMMON.read_text(encoding="utf-8")


def test_common_yaml_exists() -> None:
    """The registry file must exist."""
    assert COMMON.exists(), "playtest/_common.yaml is missing"


def test_common_yaml_still_has_every_new_surface() -> None:
    """Every new R3 surface must still be registered in _common.yaml."""
    text = _common_text()
    missing = [s for s in COMMON_SURFACES if s not in text]
    assert not missing, (
        "playtest/_common.yaml lost a new R3 surface — the registry is the "
        "contract the scenarios assert against, do NOT remove it:\n  "
        + "\n  ".join(missing)
    )


def test_red_first_evidence_notes_exist() -> None:
    """At least one R3 red-first evidence note must exist under final/."""
    notes = sorted(FINAL.glob("red_first_notes_r3_*.md"))
    assert notes, (
        "no final/red_first_notes_r3_*.md exists — the red-first discipline is "
        "load-bearing (a round that stops recording its reds is a round that "
        "stopped proving anything). The consolidated ledger "
        "final/delivery_notes_r3_numbers.md must cite these measured reds."
    )


def _make_scenario_test(name: str, lines: tuple[str, ...]):
    def test_load_bearing_lines_present() -> None:
        """Every load-bearing differential line must still appear verbatim."""
        path = PLAYTEST / f"{name}.yaml"
        assert path.exists(), f"playtest/{name}.yaml is missing"
        text = path.read_text(encoding="utf-8")
        missing = [line for line in lines if line not in text]
        assert not missing, (
            f"the {name} nail lost a load-bearing differential line — this is "
            "the anti-accidental-weakening door, do NOT remove or relax it:\n  "
            + "\n  ".join(missing)
        )

    test_load_bearing_lines_present.__name__ = f"test_{name}_load_bearing_lines_present"
    test_load_bearing_lines_present.__doc__ = (
        f"Every load-bearing differential line of {name} must still appear verbatim."
    )
    return test_load_bearing_lines_present


# Generate one test per scenario so a failure names exactly which nail lost which
# line (the failure text above already lists the missing lines per scenario).
for _name, _lines in SCENARIO_LOAD_BEARING_LINES.items():
    globals()[f"test_{_name}_load_bearing_lines_present"] = _make_scenario_test(
        _name, _lines
    )
