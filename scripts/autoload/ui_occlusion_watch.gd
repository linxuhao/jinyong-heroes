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
##   1. same effective CanvasLayer — compared by walking each node's parent
##      chain to the NEAREST CanvasLayer ancestor (null-guarded, liveness-
##      checked at every step; both null = both in the root viewport's default
##      canvas = same layer). Cross-layer pairs are out of scope — the
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
##
## CRASH-PROOFING (fix_occlusion_watch_crashproof, 2026-09-01): the previous
## build read `canvas_layer` directly on Controls (NOT a Control property) and
## fired 44,660 "Invalid access to property or key 'canvas_layer'" runtime
## errors — aborting _process BEFORE `violations` was assigned, so it stayed 0
## and the nail's greens were FALSE greens from unscanned frames, and the
## crash took down the whole suite's hard gate. GDScript has no try/catch, so
## crash-impossibility holds BY CONSTRUCTION here: every typed access in the
## scan is guarded (is_instance_valid + is_inside_tree + an `is <Type>` check
## first); the only duck-typed property access ever performed is on nodes
## type-confirmed as Control / CanvasLayer. The watch is read-only (zero RNG
## draws, zero writes to any node) and publishes its own scan-health
## observables so an unscanned frame can NEVER read as green:
##
##   scan_ok: bool          — true iff THIS frame's scan walked the tree and
##                            evaluated every candidate pair to completion
##   scan_failed_frames:int — cumulative incomplete-scan counter (evidence)
##   On an unhonestly-scannable frame (e.g. the tree root vanished mid-frame):
##   scan_ok = false, scan_failed_frames += 1, violations = -1 (UNTESTED
##   sentinel), violations_text = "scan-incomplete" — never a green read.

var violations: int = 0
var violations_text: String = ""   # "Occluder>Label" pairs, semicolon-separated
var scan_ok: bool = false
var scan_failed_frames: int = 0

const _MIN_OVERLAP_PX: int = 4
const _MIN_RESIDUAL_VISIBILITY: float = 0.5


func _process(_delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		_mark_scan_incomplete()
		return
	var root := tree.root
	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		_mark_scan_incomplete()
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
			if not _same_effective_layer(b, l):
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
	scan_ok = true
	violations = found
	violations_text = ";".join(parts)


## Sentinel for a frame the scan cannot complete honestly: UNTESTED, never green.
func _mark_scan_incomplete() -> void:
	scan_ok = false
	scan_failed_frames += 1
	violations = -1
	violations_text = "scan-incomplete"


func _valid_control(c: Control) -> bool:
	return c != null and is_instance_valid(c) \
			and c.is_inside_tree() and c.is_visible_in_tree()


## Same effective layer ⟺ both nodes' NEAREST CanvasLayer ancestor is the same
## instance (both null = both in the root viewport's default canvas = same
## layer). Uses only get_parent() + `is CanvasLayer`; every step of the walk
## is null-guarded and liveness-checked, so a parent freed mid-walk stops the
## walk (treated as the root-viewport layer) instead of erroring.
func _same_effective_layer(a: Node, b: Node) -> bool:
	return _nearest_layer(a) == _nearest_layer(b)


func _nearest_layer(n: Node) -> CanvasLayer:
	var cur: Node = n
	while cur != null and is_instance_valid(cur):
		if cur is CanvasLayer:
			return cur as CanvasLayer
		cur = cur.get_parent()
	return null


func _collect(node: Node, buttons: Array[Control], texts: Array[Control]) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
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
	# If the LCA is the LAST element of either chain (the tree root, e.g. two
	# controls from unrelated top-level subtrees), then the child-branch index
	# find(lca)+1 would read one past the array end — guard it: there is no
	# meaningful draw-order comparison across unrelated subtrees, so the pair
	# is out of scope (never red).
	# _chain() orders nodes node->root (index 0 = the control itself, last =
	# the tree root). The branch child DIRECTLY BENEATH lca on each side is
	# therefore the element just BELOW lca in the chain: index find(lca) - 1
	# (find(lca) + 1 would be lca's PARENT — the pre-crash-proof build used +1
	# and never produced a branch child, so _draws_over always returned false
	# and the gate was vacuous; fixed 2026-09-01, see delivery notes §8).
	var bi: int = bp.find(lca) - 1
	var li: int = lp.find(lca) - 1
	if bi < 0 or li < 0 or bi >= bp.size() or li >= lp.size():
		return false
	var b_branch: Node = bp[bi]
	var l_branch: Node = lp[li]
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
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node is Control and node != b and node != l \
			and not b.is_ancestor_of(node) and not node.is_ancestor_of(b) \
			and node.is_visible_in_tree():
		var c := node as Control
		if _same_effective_layer(c, l) \
				and _draws_over(c, l) \
				and c.get_global_rect().intersects(l.get_global_rect()):
			out.append(c)
	for child in node.get_children():
		if is_instance_valid(child) and child.is_inside_tree():
			_collect_over(child, l, b, out)
