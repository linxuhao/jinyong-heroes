"""The 武虾 roster guard.

design/90_decisions.md fixes a WORLD CONSTRAINT: every character in this game is
a shrimp — the six that exist and every one added afterwards. That is a rule
nobody can enforce by remembering it. This pipeline is agent-driven; the round
three from now will add a character and will not have read the decision record.

So the rule is converted into a door. assets/characters/roster.json names every
portrait and says which shrimp it is; this test holds the roster and the PNGs on
disk to a strict one-to-one. Adding a portrait without a roster row is red.
Deleting a portrait while its row survives is red too — a roster that quietly
describes files that are gone stops being evidence of anything.

What this DOES NOT do, on purpose: it cannot look at a PNG and judge whether the
thing in it is a shrimp. Claiming otherwise would be the kind of guard that reads
green over nothing. What it enforces is narrower and actually mechanical — that
adding a character forces the author to write down which shrimp it is, in a file
a reviewer reads. The judgement stays human; the reminder is automatic.

Lives in pytest rather than in the GDScript unit suite for one blunt reason: as
of 2026-08-28 NOTHING in the pipeline runs tests/unit_test_runner.gd (the DPE
5_test step's run_tests tool is a pytest runner, and no config invokes
run_tests.sh). A guard in the unenforced suite would be decoration.
"""
import json
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
PORTRAIT_DIR = REPO_ROOT / "assets" / "characters"
ROSTER = PORTRAIT_DIR / "roster.json"


def _roster() -> dict:
    doc = json.loads(ROSTER.read_text(encoding="utf-8"))
    assert isinstance(doc.get("characters"), dict), (
        "roster.json must carry a 'characters' object")
    return doc["characters"]


def test_every_portrait_is_registered_in_the_roster():
    """A portrait with no roster row means a character got added without anyone
    saying which shrimp it is — exactly the drift the constraint exists to stop."""
    on_disk = {p.stem for p in PORTRAIT_DIR.glob("*.png")}
    registered = set(_roster())
    unregistered = sorted(on_disk - registered)
    assert not unregistered, (
        f"portraits with no roster.json entry: {unregistered}. Every character in "
        f"this game is a shrimp (design/90_decisions.md) — add a row naming which "
        f"shrimp, or remove the portrait.")


def test_every_roster_row_has_its_portrait():
    """The other direction. A roster describing files that no longer exist reads
    as coverage while covering nothing."""
    on_disk = {p.stem for p in PORTRAIT_DIR.glob("*.png")}
    missing = sorted(set(_roster()) - on_disk)
    assert not missing, (
        f"roster.json rows with no portrait on disk: {missing}. Delete the row or "
        f"restore the file — a roster that describes absent art is not evidence.")


def test_every_row_names_a_species_and_a_title():
    """The one machine-checkable part of an otherwise human judgement: the fields
    are present and non-empty. An empty species is the same as no row at all."""
    for name, row in sorted(_roster().items()):
        assert isinstance(row, dict), f"{name}: roster row must be an object"
        for field in ("title", "species"):
            value = row.get(field)
            assert isinstance(value, str) and value.strip(), (
                f"{name}: '{field}' must be a non-empty string — a blank one "
                f"records nothing and passes silently")
