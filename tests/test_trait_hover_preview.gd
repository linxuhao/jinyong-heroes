## Headless unit pin for Defect C (trait hover preview) in scripts/segments/creation.gd.
##
## Covers the PURE selection rule (static hover_desc_index) and the hover-isolation
## invariants on a BARE instance (creation.gd.new() without _ready / without a tree):
## hovering must NEVER write trait_index, NEVER toggle (trait_ids), NEVER spend points,
## and the phase gate at the top of _render() must clear a stale hover index.
##
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Registered in tests/unit_test_runner.gd (deterministic TESTS registry).

const CreationScript = preload("res://scripts/segments/creation.gd")


static func run() -> bool:
	var ok := true
	ok = _test_hover_desc_index_truth_table(ok)
	ok = _test_hover_isolation_bare_instance(ok)
	ok = _test_phase_gate_clears_hover(ok)
	ok = _test_render_leaves_trait_index_untouched(ok)
	if ok:
		print("PASS test_trait_hover_preview")
	else:
		print("FAIL test_trait_hover_preview")
	return ok


# --- 1. hover_desc_index: the pure selection rule (criterion 2) --------------
static func _test_hover_desc_index_truth_table(ok: bool) -> bool:
	# Unset hover (-1 and any negative) => fall back to the focused trait_index.
	ok = _expect(ok, CreationScript.hover_desc_index(0, -1) == 0, "hover_desc_index(0,-1)==0")
	ok = _expect(ok, CreationScript.hover_desc_index(3, -1) == 3, "hover_desc_index(3,-1)==3")
	ok = _expect(ok, CreationScript.hover_desc_index(5, -2) == 5, "hover_desc_index(5,-2)==5 (any negative unset)")
	# A set hover (>= 0) wins over the focus index.
	ok = _expect(ok, CreationScript.hover_desc_index(0, 5) == 5, "hover_desc_index(0,5)==5")
	ok = _expect(ok, CreationScript.hover_desc_index(2, 0) == 0, "hover_desc_index(2,0)==0 (hover 0 is set, not unset)")
	return ok


# --- 2. Hover isolation on a bare instance (criterion 4) ---------------------
# .new() does not run _ready, so phase/trait_index/trait_ids are at their
# declaration defaults unless set here; every node access in _render() is
# get_node_or_null-guarded, so a nodeless instance renders without error.
static func _make_bare():
	var c = CreationScript.new()
	c._traits = TraitData.all()
	c.phase = "TRAITS"
	c.trait_index = 0
	c.trait_ids = []
	c.points_left = 30
	return c


static func _test_hover_isolation_bare_instance(ok: bool) -> bool:
	var c = _make_bare()
	# Hover-enter trait 5: only the display channel moves.
	c._on_trait_toggle_hover_entered(5)
	ok = _expect(ok, c.trait_hover_index == 5, "hover-entered sets trait_hover_index==5")
	ok = _expect(ok, c.trait_index == 0, "hover-entered never writes trait_index")
	ok = _expect(ok, c.trait_ids.is_empty(), "hover-entered never toggles (trait_ids empty)")
	ok = _expect(ok, c.points_left == 30, "hover-entered never spends points")
	# Hover-exit resets the preview; focus is still untouched.
	c._on_trait_toggle_hover_exited()
	ok = _expect(ok, c.trait_hover_index == -1, "hover-exited resets trait_hover_index==-1")
	ok = _expect(ok, c.trait_index == 0, "hover-exited never writes trait_index")
	c.free()
	return ok


# --- 3. Phase gate clears a stale hover (criterion 5) ------------------------
# _on_trait_toggle_hover_entered sets the index then calls _render(); the FIRST
# statement of _render() is `if phase != "TRAITS": trait_hover_index = -1`, so a
# handler fired in a non-TRAITS phase leaves the preview cleared.
static func _test_phase_gate_clears_hover(ok: bool) -> bool:
	var c = _make_bare()
	c.phase = "CONFIRM"
	c._on_trait_toggle_hover_entered(2)
	ok = _expect(ok, c.trait_hover_index == -1, "phase gate resets hover when phase != TRAITS")
	c.free()
	return ok


# --- 4. _render() itself never writes trait_index ----------------------------
# The desc-text path must not mutate the focus index even through a full render.
static func _test_render_leaves_trait_index_untouched(ok: bool) -> bool:
	var c = _make_bare()
	c.trait_hover_index = 7
	c._render()
	ok = _expect(ok, c.trait_index == 0, "_render() with a set hover never writes trait_index")
	ok = _expect(ok, c.trait_ids.is_empty(), "_render() never toggles (trait_ids empty)")
	c.free()
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_trait_hover_preview: " + msg)
	return false
