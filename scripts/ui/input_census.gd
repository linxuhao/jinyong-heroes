extends RefCounted
class_name InputCensus

# A permanent, in-repo census of "what Control would swallow a click at this
# screen point in the GUI phase". Ported from the deleted InputProbeOverlay
# (temporary diagnostic) so the raw/handled/eater triad lives in the repo
# forever rather than behind a URL flag. Used by Player._input to publish
# `debug_gui_eater` per press (P0 Layer-1 coverage for the Defect A family:
# any STOP-filter Control parked over the board is named here, wherever it is).
#
# The draw-order comparator mirrors scripts/ui/visibility_probe.gd L284–334
# semantics (canvas layer -> effective z -> tree order). That file's helpers are
# private-by-convention, so the ~30 lines are replicated here rather than called
# cross-class. `show_behind_parent` is intentionally omitted: it is irrelevant
# to the engine's GUI picking, which the winner among candidate Controls models.


## Topmost (last-drawn) visible Control whose mouse_filter != IGNORE and whose
## global rect contains `pos`; returns its absolute path string ("/root/...") or
## "" when there is no such Control (or when `root` is null — headless teardown).
static func top_eater(root: Node, pos: Vector2) -> String:
	if root == null:
		return ""
	var candidates: Array = []
	# A single-element array is used as a mutable pre-order counter box so the
	# recursive walk assigns each visited node the same index _tree_index would.
	var counter: Array = [0]
	_walk(root, pos, candidates, counter)
	if candidates.is_empty():
		return ""
	var winner: Dictionary = candidates[0]
	for i in range(1, candidates.size()):
		if _draws_after_keys(candidates[i], winner):
			winner = candidates[i]
	return String((winner["node"] as Node).get_path())


## Pre-order DFS: visit `n`, then its children. Every Control that is visible in
# the tree, non-IGNORE, and contains `pos` becomes a candidate tagged with the
# three comparator keys (canvas layer, effective z, tree index).
static func _walk(n: Node, pos: Vector2, out: Array, counter: Array) -> void:
	var idx: int = counter[0]
	counter[0] = idx + 1
	if n is Control:
		var ctl: Control = n as Control
		if ctl.is_visible_in_tree() \
				and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and ctl.get_global_rect().has_point(pos):
			var ci: CanvasItem = ctl
			out.append({
				"node": ctl,
				"layer": _canvas_layer(ci),
				"z": _effective_z(ci),
				"idx": idx,
			})
	for child in n.get_children():
		_walk(child, pos, out, counter)


## True when candidate `a` draws on top of candidate `b` — the same total order
## as visibility_probe's _draws_after, reduced to the three picking-relevant keys.
static func _draws_after_keys(a: Dictionary, b: Dictionary) -> bool:
	if a["layer"] != b["layer"]:
		return a["layer"] > b["layer"]
	if a["z"] != b["z"]:
		return a["z"] > b["z"]
	return a["idx"] > b["idx"]


## Nearest CanvasLayer ancestor's `layer` (0 if none). Mirrors visibility_probe.
static func _canvas_layer(item: CanvasItem) -> int:
	var node: Node = item
	while node != null:
		if node is CanvasLayer:
			return (node as CanvasLayer).layer
		node = node.get_parent()
	return 0


## Effective z_index, honouring z_as_relative: sum ancestors' z up to the first
## absolute-z node. Mirrors visibility_probe.
static func _effective_z(item: CanvasItem) -> int:
	var z: int = 0
	var n: CanvasItem = item
	while n != null:
		z += n.z_index
		if not n.z_as_relative:
			break
		n = n.get_parent() as CanvasItem
	return z
