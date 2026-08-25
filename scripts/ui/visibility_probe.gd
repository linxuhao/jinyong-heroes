class_name VisibilityProbe
##
## Layered on-frame visibility predicate for battle-unit portraits.
##
## Turns "the unit's portrait puts ink on the rendered frame" into a decidable
## fact. Pure static functions — no node, no scene, no state, no signals.
## The SAME predicate serves the probe matrix (record the per-layer inputs),
## the A-class red-before-fix assertions, and the B-class regression guards,
## so it lives in ONE place instead of being re-derived in every playtest yaml.
##
## Layer order is cheap-to-expensive (from step1_sota.md):
##   1 "hidden_in_tree"  leaf's visible chain broken (leaf or an ancestor hidden)
##   2 "null_texture"    Sprite2D/TextureRect texture null or zero-sized
##   3 "zero_rect"       leaf rect zero area / scale zero / alpha chain < 0.01
##   4 "off_viewport"    leaf rect does NOT intersect the viewport rect
##   5 "clipped"         a clip_contents ancestor does not enclose the leaf rect
##   6 "occluded"        a later-drawn, mouse-visible Control fully covers it
##
## `visible == true` is necessary but not sufficient: an ancestor may be hidden,
## the rect may be off-screen, an ancestor may clip it, or a later-drawn host
## may cover it. This probe checks all six.

## Global rect of the ink-drawing leaf (the unit's "Sprite" child). Containers
## are NOT ink — never return the unit root's own rect (a slot).
static func leaf_rect(unit_root: Node2D) -> Rect2:
	if unit_root == null or not is_instance_valid(unit_root):
		return Rect2()
	var leaf: Node = unit_root.get_node_or_null("Sprite")
	if leaf == null or not is_instance_valid(leaf):
		return Rect2()
	if leaf is Control:
		return (leaf as Control).get_global_rect()
	if leaf is Sprite2D:
		return _sprite_global_rect(leaf as Sprite2D)
	return Rect2()

## First failing layer id, "" when fully visible on-frame.
static func first_fail_layer(unit_root: Node2D) -> String:
	if unit_root == null or not is_instance_valid(unit_root):
		return "hidden_in_tree"
	var leaf: Node = unit_root.get_node_or_null("Sprite")
	if leaf == null or not is_instance_valid(leaf):
		return "hidden_in_tree"

	# 1. hidden_in_tree — the FULL visible chain, not just the leaf's own flag.
	if not leaf.is_visible_in_tree():
		return "hidden_in_tree"

	# 2. null_texture — a portrait with no ink resource cannot render.
	if leaf is Sprite2D:
		var sprite: Sprite2D = leaf as Sprite2D
		if sprite.texture == null or sprite.texture.get_size() == Vector2.ZERO:
			return "null_texture"
	elif leaf is TextureRect:
		var tr: TextureRect = leaf as TextureRect
		if tr.texture == null or tr.texture.get_size() == Vector2.ZERO:
			return "null_texture"

	# 3. zero_rect — zero area, zero scale, or a (near-)transparent alpha chain.
	var rect: Rect2 = leaf_rect(unit_root)
	if rect.get_area() <= 0.0:
		return "zero_rect"
	if leaf is Node2D and (leaf as Node2D).scale == Vector2.ZERO:
		return "zero_rect"
	if _combined_alpha(leaf) < 0.01:
		return "zero_rect"

	# 4. off_viewport — the ink must actually intersect the rendered frame
	#    (touching edges do NOT count: Rect2.intersects default include_borders=false).
	var vp: Viewport = unit_root.get_viewport()
	if vp == null:
		return "off_viewport"
	if not rect.intersects(vp.get_visible_rect()):
		return "off_viewport"

	# 5. clipped — every clip_contents ancestor must enclose the leaf rect.
	var anc: Node = leaf.get_parent()
	while anc != null and anc != vp:
		if anc is Control and (anc as Control).clip_contents:
			if not (anc as Control).get_global_rect().encloses(rect):
				return "clipped"
		anc = anc.get_parent()

	# 6. occluded — a later-drawn, non-IGNORE Control fully covers the ink.
	if _is_occluded(unit_root, leaf, rect):
		return "occluded"

	return ""

## Convenience: all six layers pass.
static func portrait_visible(unit_root: Node2D) -> bool:
	return first_fail_layer(unit_root) == ""

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Global rect of a Sprite2D ink leaf: transform the four local-rect corners by
## the sprite's canvas-space transform and take the AABB (rotation-safe — the
## Godot 4 idiom; there is no Transform2D.xform in 4.x, only the * operator).
static func _sprite_global_rect(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2()
	var tex_size: Vector2 = sprite.texture.get_size()
	var scaled: Vector2 = tex_size * sprite.scale
	var local: Rect2
	if sprite.centered:
		local = Rect2(sprite.offset - scaled / 2.0, scaled)
	else:
		local = Rect2(sprite.offset, scaled)
	var xf: Transform2D = sprite.get_global_transform_with_canvas()
	var p0: Vector2 = xf * local.position
	var p1: Vector2 = xf * (local.position + Vector2(local.size.x, 0.0))
	var p2: Vector2 = xf * (local.position + local.size)
	var p3: Vector2 = xf * (local.position + Vector2(0.0, local.size.y))
	var out := Rect2(p0, Vector2.ZERO)
	out = out.expand(p1)
	out = out.expand(p2)
	out = out.expand(p3)
	return out

## Combined modulate.a of the leaf multiplied through every ancestor.
static func _combined_alpha(leaf: Node) -> float:
	var alpha: float = 1.0
	var node: Node = leaf
	while node != null:
		if node is CanvasItem:
			alpha *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha

## A later-drawn, mouse-visible Control fully covering the ink = occluded.
## Uses the repo's opaque-host convention: candidates must declare a non-IGNORE
## mouse_filter (pure-visibility test, no mouse/hover API involved).
static func _is_occluded(unit_root: Node2D, leaf: Node, rect: Rect2) -> bool:
	var tree: SceneTree = unit_root.get_tree()
	if tree == null:
		return false
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and n.is_visible_in_tree() \
				and n != leaf and not _is_ancestor_of(n, leaf):
			var c: Control = n as Control
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and c.get_global_rect().encloses(rect) \
					and _draws_after(c, leaf):
				return true
		for child in n.get_children():
			stack.append(child)
	return false

static func _is_ancestor_of(anc: Node, n: Node) -> bool:
	var cur: Node = n.get_parent()
	while cur != null:
		if cur == anc:
			return true
		cur = cur.get_parent()
	return false

## True when `c` draws on top of the leaf: higher CanvasLayer, higher effective
## z_index, then tree order (later DFS pre-order index).
static func _draws_after(c: CanvasItem, leaf: Node) -> bool:
	var leaf_ci: CanvasItem = leaf as CanvasItem
	if leaf_ci == null:
		return false
	if _canvas_layer(c) > _canvas_layer(leaf_ci):
		return true
	if _canvas_layer(c) < _canvas_layer(leaf_ci):
		return false
	if _effective_z(c) > _effective_z(leaf_ci):
		return true
	if _effective_z(c) < _effective_z(leaf_ci):
		return false
	if leaf_ci.show_behind_parent and not c.show_behind_parent:
		return true
	var tree: SceneTree = c.get_tree()
	if tree == null:
		return false
	return _tree_index(tree.root, c) > _tree_index(tree.root, leaf)

static func _canvas_layer(item: CanvasItem) -> int:
	var canvas: Canvas = item.get_canvas()
	if canvas == null:
		return 0
	return canvas.layer

## Effective z_index, honouring z_as_relative (sum ancestors' z until an
## absolute-z node is found).
static func _effective_z(item: CanvasItem) -> int:
	var z: int = 0
	var n: CanvasItem = item
	while n != null:
		z += n.z_index
		if not n.z_as_relative:
			break
		n = n.get_parent() as CanvasItem
	return z

## DFS pre-order index of `target` under `root` (-1 if absent). A greater index
## means the node is later in tree order and thus drawn on top (same layer/z).
static func _tree_index(root: Node, target: Node) -> int:
	if root == target:
		return 0
	var idx: int = 1
	for child in root.get_children():
		var found: int = _tree_index(child, target)
		if found >= 0:
			return idx + found
		idx += _subtree_size(child)
	return -1

static func _subtree_size(n: Node) -> int:
	var s: int = 1
	for child in n.get_children():
		s += _subtree_size(child)
	return s
