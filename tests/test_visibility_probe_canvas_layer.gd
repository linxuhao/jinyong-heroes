## Unit tests for VisibilityProbe._canvas_layer — the effective draw-layer walk
## that replaces the invalid `Canvas` type annotation (CanvasItem.get_canvas()
## returns a RID in Godot 4; there is no `Canvas` class in GDScript, so the old
## annotation was a hard parse error that cascaded into every playtest scenario).
##
## Contract: top-level static func run() -> bool; push_error on failure; never
## relies on assert() (stripped in release). Collected into unit_test_runner.gd.
##
## Fully headless: node trees are built off-tree (parent.add_child establishes
## get_parent() without a running SceneTree) — enough for a function that only
## walks get_parent().

static func run() -> bool:
	var ok := true

	# 1. No CanvasLayer anywhere in the ancestor chain -> 0 (the engine default).
	var plain_root: Node = Node.new()
	var plain_leaf: Node2D = Node2D.new()
	plain_root.add_child(plain_leaf)
	ok = _expect(ok, VisibilityProbe._canvas_layer(plain_leaf) == 0,
			"_canvas_layer: no CanvasLayer ancestor -> 0")

	# 2. Direct parent is a CanvasLayer (layer 3) -> 3.
	var cl_parent: CanvasLayer = CanvasLayer.new()
	cl_parent.layer = 3
	var leaf_parent: Node2D = Node2D.new()
	cl_parent.add_child(leaf_parent)
	ok = _expect(ok, VisibilityProbe._canvas_layer(leaf_parent) == 3,
			"_canvas_layer: direct CanvasLayer parent (layer=3) -> 3")

	# 3. Grandparent layer 5, parent layer 2 -> the NEAREST ancestor wins (2).
	var cl_grandparent: CanvasLayer = CanvasLayer.new()
	cl_grandparent.layer = 5
	var cl_mid: CanvasLayer = CanvasLayer.new()
	cl_mid.layer = 2
	cl_grandparent.add_child(cl_mid)
	var leaf_chain: Node2D = Node2D.new()
	cl_mid.add_child(leaf_chain)
	ok = _expect(ok, VisibilityProbe._canvas_layer(leaf_chain) == 2,
			"_canvas_layer: nearest CanvasLayer ancestor (parent layer=2) -> 2")

	# 4. The walk crosses intermediate NON-CanvasItem nodes (a plain Node) on the
	#    way to a CanvasLayer ancestor (layer 9) -> 9. `_canvas_layer` walks
	#    Node.get_parent() and tests each node regardless of its concrete type,
	#    so a non-2D intermediate must not stop the walk.
	#    NOTE: the "item ITSELF is a CanvasLayer" case (the depth-0 `is
	#    CanvasLayer` branch) is UNREACHABLE through this typed signature —
	#    `_canvas_layer` takes a CanvasItem, and CanvasLayer is not a CanvasItem
	#    (both derive from Node, sibling branches), so the engine rejects such a
	#    call at runtime. Passing it as a Variant does not dodge that check and
	#    would hard-abort the suite. The branch is therefore dead for any valid
	#    call and is not separately testable; cases 2-3 exercise it at depth > 0.
	var cl_deep: CanvasLayer = CanvasLayer.new()
	cl_deep.layer = 9
	var mid_node: Node = Node.new()
	cl_deep.add_child(mid_node)
	var leaf_deep: Node2D = Node2D.new()
	mid_node.add_child(leaf_deep)
	ok = _expect(ok, VisibilityProbe._canvas_layer(leaf_deep) == 9,
			"_canvas_layer: walk crosses plain Node intermediate (layer=9) -> 9")

	# Free the off-tree subtrees (no SceneTree to clean them up for us).
	plain_root.free()
	cl_parent.free()
	cl_grandparent.free()
	cl_deep.free()

	if ok:
		print("PASS: test_visibility_probe_canvas_layer")
	else:
		print("FAIL: test_visibility_probe_canvas_layer")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_visibility_probe_canvas_layer: " + what)
	return ok_so_far and cond
