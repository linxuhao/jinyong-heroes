## Unit tests for the §3.B2 portrait-rect click priority rule:
##   scripts/characters/player.gd  — static attack_reach_covers + resolve_click_step
##
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## Fully headless: the predicates under test are pure statics (no autoloads, no
## scene tree, no instance state), so they are preloaded and called directly on
## the GDScript resource. This pins the priority rule's truth table (design
## §3.B2) — including the rejected-§3.1 guarantee that an empty tile never
## becomes unclickable behind a tall OUT-OF-REACH unit.

const Player = preload("res://scripts/characters/player.gd")


static func run() -> bool:
	var ok := true
	ok = _test_attack_reach_covers(ok)
	ok = _test_resolve_click_step(ok)
	if ok:
		print("PASS test_click_priority")
	else:
		print("FAIL test_click_priority")
	return ok


# --- 1. attack_reach_covers: pure range-only reach ----------------------------

static func _test_attack_reach_covers(ok: bool) -> bool:
	# Basic attack (index -1) = Chebyshev reach 1 (adjacent incl. diagonal).
	ok = _expect(ok, Player.attack_reach_covers(Vector2i(7, 5), Vector2i(7, 4), -1, []),
			"(7,5)->(7,4) basic reach covers")
	ok = _expect(ok, Player.attack_reach_covers(Vector2i(7, 5), Vector2i(8, 6), -1, []),
			"(7,5)->(8,6) diagonal Chebyshev 1 covers")
	ok = _expect(ok, not Player.attack_reach_covers(Vector2i(7, 5), Vector2i(7, 3), -1, []),
			"(7,5)->(7,3) basic reach NOT covers (dist 2)")
	ok = _expect(ok, not Player.attack_reach_covers(Vector2i(7, 5), Vector2i(9, 6), -1, []),
			"(7,5)->(9,6) dist 2 NOT covers")
	# Out-of-range / null skill index -> reach 1 (basic).
	ok = _expect(ok, not Player.attack_reach_covers(Vector2i(7, 5), Vector2i(7, 3), 99, []),
			"out-of-range skill index -> reach 1")
	ok = _expect(ok, not Player.attack_reach_covers(Vector2i(7, 5), Vector2i(7, 3), -1, [null]),
			"null skill at index 0 -> reach 1")
	# Selected skill: reach reads the skill's `range` field (can_skill_hit口径).
	var skill = _skill(3)
	ok = _expect(ok, Player.attack_reach_covers(Vector2i(7, 5), Vector2i(7, 2), 0, [skill]),
			"skill range 3 covers dist 3")
	ok = _expect(ok, not Player.attack_reach_covers(Vector2i(7, 5), Vector2i(7, 1), 0, [skill]),
			"skill range 3 NOT covers dist 4")
	return ok


# --- 2. resolve_click_step: the five-step truth table -------------------------

static func _test_resolve_click_step(ok: bool) -> bool:
	# Enemy data is pure: grid_pos + the live clamped portrait ink rect.
	# Central_Divine-style clamped rect hangs DOWN over the tiles above its feet
	# (top-row clamp): grid (7,1), ink rect x[432,528] y[92,220] covers (7,2)/(7,3).
	var out_of_reach := {"grid_pos": Vector2i(7, 1), "rect": Rect2(Vector2(432, 92), Vector2(96, 128))}
	# An adjacent enemy at (7,4) (reach 1) whose body hangs over tile (7,3):
	# ink rect x[432,528] y[160,288].
	var in_reach := {"grid_pos": Vector2i(7, 4), "rect": Rect2(Vector2(432, 160), Vector2(96, 128))}
	var player_grid := Vector2i(7, 5)
	# Reachable-empty-tile set from plan_movement (the move-range highlight);
	# own tile (7,5) is never in it.
	var reachable := {
		Vector2i(7, 2): true,
		Vector2i(7, 3): true,
		Vector2i(7, 4): true,
	}

	# Row 1 — an enemy occupies the clicked tile -> step 1 (attack, existing).
	# Click in_reach's own tile centre (world 480,288 for grid (7,4)).
	ok = _expect(ok, Player.resolve_click_step(
			Vector2(480, 288), Vector2i(7, 4), player_grid,
			[out_of_reach, in_reach], reachable, -1, []) == 1,
			"enemy on clicked tile -> step 1")

	# Row 2 — reachable empty tile crossed by an OUT-OF-REACH rect -> step 3 (move).
	# Click tile (7,2) at y=140 (inside out_of_reach rect, below in_reach's 160 top).
	ok = _expect(ok, Player.resolve_click_step(
			Vector2(480, 140), Vector2i(7, 2), player_grid,
			[out_of_reach, in_reach], reachable, -1, []) == 3,
			"reachable empty tile + out-of-reach rect crossing -> step 3 (move)")

	# Row 3 — reachable empty tile crossed by an IN-REACH rect -> step 2 (attack).
	# Click tile (7,3) at y=220 (inside in_reach rect, below out_of_reach's 220 edge).
	ok = _expect(ok, Player.resolve_click_step(
			Vector2(480, 220), Vector2i(7, 3), player_grid,
			[out_of_reach, in_reach], reachable, -1, []) == 2,
			"reachable empty tile + in-reach rect crossing -> step 2 (attack)")

	# Row 4 — out-of-reach body, non-highlighted -> step 4 (select/no-op).
	# Click out_of_reach's own tile (7,1) at y=120; not in reachable, not in reach.
	ok = _expect(ok, Player.resolve_click_step(
			Vector2(450, 120), Vector2i(7, 1), player_grid,
			[out_of_reach, in_reach], reachable, -1, []) == 4,
			"out-of-reach body, non-highlighted -> step 4")

	# Row 5 — own empty non-highlighted tile -> step 5 (silent no-op).
	# Click own tile (7,5) at (450,340); not in any rect, not in reachable.
	ok = _expect(ok, Player.resolve_click_step(
			Vector2(450, 340), Vector2i(7, 5), player_grid,
			[out_of_reach, in_reach], reachable, -1, []) == 5,
			"own empty non-highlighted tile -> step 5")

	# Row 6 — reachable empty tile, no rect crossing -> step 3 (move), and the
	# in-reach gate genuinely fires only for reach (a reachable enemy body that
	# IS in reach still beats an empty move — already row 3).
	ok = _expect(ok, Player.resolve_click_step(
			Vector2(480, 140), Vector2i(7, 2), player_grid,
			[], reachable, -1, []) == 3,
			"reachable empty tile, no rect -> step 3 (move)")
	return ok


# --- helpers ------------------------------------------------------------------

## Build a fake skill resource with an explicit `range`.
static func _skill(range_val: int) -> Resource:
	var s = load("res://scripts/data/skill_data.gd").new()
	s.range = range_val
	s.aoe_shape = "single"
	return s


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_click_priority: " + msg)
	return false
