extends Node
## UiOcclusionWatch — structural occlusion gate (jinyong-loop R2, task D6).
##
## Recomputed every frame in _process over the live scene tree. Pure reads,
## ZERO RNG draws, zero writes, no caching across frames (SceneManager frees
## MapScreen mid-battle-return, so nothing may go stale mid-swap — every frame
## rebuilds its own node lists).
##
## SCOPE (honest, per the design decision D6): all three measured occlusion
## defects of the jinyong-theme round are BUTTON-over-TEXT overlaps, and in this
## game's vocabulary an interactive button drawn on top of prose is always a
## defect, while Panel/ColorRect overlaps are the designed backdrop / dim layer.
## This watch therefore watches button-over-text pairs; it does NOT claim to
## catch non-button container-over-label overlaps.
##
## RED pair = a visible Button B and a visible, non-empty-text Label or
## RichTextLabel L where ALL of:
##   1. same effective CanvasLayer (cross-layer pairs are out of scope — the
##      tutorial/roster full-screen dims are this game's DESIGNED vocabulary
##      for covering inactive screens, not defects);
##   2. B is neither an ancestor nor a descendant of L (a label's own panel is
##      containment, not covering);
##   3. B draws over L — later sibling order at the lowest common ancestor
##      (Godot draws later siblings on top);
##   4. the two rects intersect >= 4 px on BOTH axes (a graze is not occlusion);
##   5. L is actually readable: residual visibility through overlying
##      translucent controls, product of (1 - alpha), >= 0.5 (a 0.88 dim pushes
##      under-labels to 0.12 — excluded; the defect labels sit at 1.0).
##   When B and L share no common ancestor within the same effective layer, the
##   pair is out of scope (no LCA => no draw-order comparison => never red).

var violations: int = 0
var violations_text: String = ""   # "Occluder>Label" pairs, semicolon-separated

const _MIN_OVERLAP_PX: int = 4
const _MIN_RESIDUAL_VISIBILITY: float = 0.5


func _process(_delta: float) -> void:
	var root := get_tree().root
	if root == null or not is_instance_valid(root):
		violations = 0
		violations_text = ""
		return
	var buttons: Array[Control] = []
	var texts: Array[Control] = []
	_collect(root, buttons, texts)
	var found: int = 0
	var parts: PackedStringArray = []
	for b in buttons:
		if not _valid_control(b):
			continue
		for l in texts:
			if not _valid_control(l) or l == b:
				continue
			if b.is_ancestor_of(l) or l.is_ancestor_of(b):
				continue
			if b.get_canvas_layer() != l.get_canvas_layer():
				continue
			var br: Rect2 = b.get_global_rect()
			var lr: Rect2 = l.get_global_rect()
			var ix: float = minf(br.end.x, lr.end.x) - maxf(br.position.x, lr.position.x)
			var iy: float = minf(br.end.y, lr.end.y) - maxf(br.position.y, lr.position.y)
			if ix < float(_MIN_OVERLAP_PX) or iy < float(_MIN_OVERLAP_PX):
				continue
			if not _draws_over(b, l):
				continue
			if _residual_visibility(l, b) < _MIN_RESIDUAL_VISIBILITY:
				continue
			found += 1
			parts.append("%s>%s" % [b.name, l.name])
	violations = found
	violations_text = ";".join(parts)


func _valid_control(c: Control) -> bool:
	return is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree()


func _collect(node: Node, buttons: Array[Control], texts: Array[Control]) -> void:
	if node is Control and node.is_visible_in_tree():
		if node is Button:
			buttons.append(node)
		elif node is Label or node is RichTextLabel:
			if node is Label:
				if (node as Label).text.strip_edges() != "":
					texts.append(node)
			else:
				if (node as RichTextLabel).text.strip_edges() != "":
					texts.append(node)
	for child in node.get_children():
		if is_instance_valid(child) and child.is_inside_tree():
			_collect(child, buttons, texts)


## LCA sibling order: walk both parent chains, find the lowest common ancestor,
## then compare the get_index() of the two branch children directly beneath it.
## A later index draws on top. No common ancestor => pair out of scope (false).
func _draws_over(b: Control, l: Control) -> bool:
	var bp := _chain(b)
	var lp := _chain(l)
	var lca: Node = null
	for i in range(mini(bp.size(), lp.size())):
		if bp[bp.size() - 1 - i] == lp[lp.size() - 1 - i]:
			lca = bp[bp.size() - 1 - i]
		else:
			break
	if lca == null:
		return false
	var b_branch: Node = bp[bp.find(lca) + 1]
	var l_branch: Node = lp[lp.find(lca) + 1]
	if b_branch.get_parent() != lca or l_branch.get_parent() != lca:
		return false
	return b_branch.get_index() > l_branch.get_index()


func _chain(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	var cur: Node = n
	while cur != null:
		out.append(cur)
		cur = cur.get_parent()
	return out


## Residual visibility of L under everything drawn OVER it except B itself:
## for every other control C that draws over L, intersects L's rect, and is not
## an ancestor/descendant of B, multiply (1 - effective alpha). An opaque
## ancestor panel of L never appears here (ancestors do not draw over a child).
func _residual_visibility(l: Control, b: Control) -> float:
	var residual := 1.0
	var root := get_tree().root
	if root == null or not is_instance_valid(root):
		return residual
	var others: Array[Control] = []
	_collect_over(root, l, b, others)
	for c in others:
		var a: float = c.modulate.a * c.self_modulate.a
		residual *= (1.0 - a)
	return residual


func _collect_over(node: Node, l: Control, b: Control, out: Array[Control]) -> void:
	if node is Control and node != b and node != l \
			and not b.is_ancestor_of(node) and not node.is_ancestor_of(b) \
			and node.is_visible_in_tree():
		var c := node as Control
		if c.get_canvas_layer() == l.get_canvas_layer() \
				and _draws_over(c, l) \
				and c.get_global_rect().intersects(l.get_global_rect()):
			out.append(c)
	for child in node.get_children():
		if is_instance_valid(child) and child.is_inside_tree():
			_collect_over(child, l, b, out)
