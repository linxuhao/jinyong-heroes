## CreationScreen — segment 3: 30-point character creation.
## Three phases: ATTRS (5 attrs, tiered pricing, clamps 10..20) -> TRAITS
## (13 trait/flaw toggles) -> CONFIRM. Leftover points are allowed. Confirm
## calls SaveManager.new_profile(attrs, trait_ids) exactly once, then routes via
## GameManager.finish_creation(): MENU entry -> TUTORIAL (new flow); legacy
## TRANSITION entry (boot default) -> enter_segment("SECT_SELECTION"), byte-identical.
extends Control

const START_POINTS: int = 30
const ATTR_MIN: int = 10
const ATTR_MAX: int = 20
## Layout constant: the equal-width cost cell shared by each row's
## AttrCostSpacer{i} FIRST child and AttrCostLabel{i} LAST child, so the cost
## text-width changes cancel symmetrically and the measured ink cluster
## (AttrLabel text ∪ AttrMinus ∪ AttrPlus) stays centered at the viewport
## center. Floor only (custom_minimum_size never clips text). The 560px
## AttrBox must fit 2×cell + cluster(≈147) + 4×separation(24) so both slots
## plus the measured cluster sit inside the box while the row stays shrink-
## centered — 190 keeps a ≤560px row (2×190+147+24 = 551), leaving the long
## cost line to grow past the floor into the cell (text overflow is absorbed
## by the symmetric slot, never occluding the cluster).
const _ATTR_COST_CELL: int = 190

## Chinese descriptions per attribute, keyed by PlayerProfile.ATTR_KEYS.
## Formulas verbatim from design/40_progression.md §7.1, meanings from
## design/10_systems.md §1 — never paraphrased (numbers are the contract).
const _ATTR_DESCS: Dictionary = {
	"bone": "气血 = 根骨 × 5",
	"inner": "内力值 = 内力 × 2",
	"agility": "移动力 = 2 + 身法 ÷ 20(向下取整);先攻 = 身法",
	"wisdom": "决定学功法的速度(修习查表)",
	"fortune": "影响事件与奇遇（福缘越高，每年游历事件可重掷次数越多）",
}

## Surface: "ATTRS" | "TRAITS" | "CONFIRM".
var phase: String = "ATTRS"

## Surface: remaining creation points (never negative).
var points_left: int = START_POINTS

## Surface: focused attr row index (0..4, PlayerProfile.ATTR_KEYS order).
var attr_index: int = 0

## Surface: composed per-row cost + remaining line for the focused row.
## Format: tr("＋1 需 %d 点 · −1 退 %d 点 · 剩 %d") % [_step_cost(v), _step_cost(v-1), points_left].
var attr_cost_text: String = ""

## Surface: next-point cost of the focused row's current value = _step_cost(current_value).
var attr_step_cost: int = 1

## Surface (layout, append-only): x-center and width of the ATTRS first-row
## ink cluster (AttrLabel text rect ∪ AttrMinus ∪ AttrPlus) via _row_ink_union.
## ATTRS-gated: updated each ATTRS frame, last value kept otherwise (the same
## phase-gated convention as the other layout facts). Zero-size union keeps the
## previous value so a transient lookup gap never fakes a verdict.
var ink_cluster_center_x: float = 0.0
var ink_cluster_width: float = 0.0

## Surface: the five attrs (PlayerProfile.ATTR_KEYS -> int).
var attrs: Dictionary = {"bone": 10, "inner": 10, "agility": 10, "wisdom": 10, "fortune": 10}

var trait_index: int = 0

## Surface: DISPLAY-ONLY hover preview channel (Defect C). -1 = no hover. When
## >= 0, _render() shows _traits[trait_hover_index].description in TraitDescLabel
## WITHOUT touching trait_index, never triggers a toggle, and never affects the
## focus `modulate` (which stays driven solely by trait_index). Reset to -1 on
## mouse_exited and whenever phase != "TRAITS" (a hidden button does not reliably
## emit mouse_exited while the pointer sits on its old rect).
var trait_hover_index: int = -1

## Surface: chosen trait/flaw ids.
var trait_ids: Array[String] = []

## Surface: true after confirm routed onward.
var confirmed: bool = false

## Surface: pressed_connected[widget_name] is true when that mouse widget's
## pressed signal is wired to its bound handler. The ONLY observable proof of
## the middle of the mouse chain — debug_click_creation_widget calls the handler
## directly and deliberately bypasses the signal link. Snapshot AFTER all
## connects in _ready (before connect() the connection list is empty).
var pressed_connected: Dictionary = {}

## Surface: hover_connected[widget_name] is true when that TraitToggle's mouse_entered
## AND mouse_exited signals are both wired to the hover-preview handlers (Defect C).
## Same snapshot-after-connects discipline as pressed_connected (the connection list is
## empty before connect()).
var hover_connected: Dictionary = {}

## Surface: true iff any rendered Label still shows the keyboard-cursor marker
## (U+25B6 BLACK RIGHT-POINTING TRIANGLE) of the removed text list. Recomputed
## at the END of every _render(); the playtest gate asserts it stays false — the
## runtime proof the cursor-list surface is gone (a missing node alone would not
## prove that).
var cursor_markers_visible: bool = false

## Surface: current HP of the build under construction, derived exactly as
## design/40_progression.md §7 defines it for player-created characters
## (气血 = 根骨 × 5). Display-only — no rule or stored value changes (UX-07).
var hp_value: int = 50

## Surface: the HpValueLabel text ("当前气血 N"); kept equal to the label so
## asserts can pin the exact rendered format (UX-07).
var hp_text: String = ""

## Surface: the ConfirmSummaryLabel text — one "名 值" line per attribute, the
## final-value checklist the confirm page was missing (UX-08).
var confirm_summary_text: String = ""

## Round-2 geometry observables (surface, append-only): per-frame, decidable
## creation-screen layout facts consumed by the playtest gate under
## CreationScreen.* (creation_layout_readability.yaml). Phase-gated facts
## (attr_rows_uniform / attr_label_alignment_ok) keep their last value outside
## the ATTRS phase; _ref_box_top records the ATTRS skeleton top on the first
## ATTRS frame so TRAITS/CONFIRM can prove they share one vertical skeleton.
var attr_rows_uniform: bool = true
var attr_label_alignment_ok: bool = true
var points_attrs_gap_ok: bool = true
var phase_skeleton_same: bool = true
var creation_in_viewport: bool = true
var creation_box_fits: bool = true
## Round-3 leaf-ink layout observables (surface, append-only): measured on INK
## (label TEXT rects via Font.get_string_size and button rects), never container
## rects — the expand-fill AttrLabel's full rect centers at 480 by construction
## while its text sits at the right edge (the container-rect lie this round
## removes, design/99_changelog.md). Phase-gated facts keep their last value
## outside their phase. All six are probe-first A/B-class facts: the probe notes
## (final/creation_probe_notes.md) record their pre-fix values.
var attr_cluster_center_ok: bool = true
var attr_cluster_width_ok: bool = true
var nav_cluster_center_ok: bool = true
var trait_cluster_center_ok: bool = true
var desc_center_ok: bool = true
var desc_alignment_ok: bool = true
var _ref_box_top: float = 0.0

var _traits: Array = []


func _ready() -> void:
	_traits = TraitData.all()
	_wire_mouse_widgets()
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if confirmed:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_accept()
	elif event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_cycle_attr_or_trait(-1)
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		_cycle_attr_or_trait(1)
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_on_move_left()
	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_on_move_right()


func _process(_delta: float) -> void:
	# Equal-width cost-cell sync every frame so the measured cluster geometry is
	# stable BEFORE the layout facts are computed (the container reflows at the
	# end of the frame). Purely additive — the measurement code below is byte-identical.
	_sync_attr_cost_cells()
	# Round-2 geometry observables: computed every frame (cheap rect reads) so
	# the playtest gate can assert them at any deterministic frame. Runs before
	# the DEBUG branch; the branch below is unchanged.
	_update_geometry_observables()
	# ATTRS-gated leaf-ink layout diagnostics (surface, append-only): fill from
	# the SAME _row_ink_union the facts read, so a green ink_cluster_center_x
	# here is a first-class observed value, not a re-derivation. Zero-size union
	# (= missing node / not ATTRS) keeps the previous value instead of writing 0.
	if phase == "ATTRS":
		var u: Rect2 = _row_ink_union(0)
		if u.size != Vector2.ZERO:
			ink_cluster_center_x = u.get_center().x
			ink_cluster_width = u.size.x
	# Harness-only DEBUG action (defined by project.godot [input]; an absent
	# action just returns false from is_action_just_pressed — never crashes).
	# debug_click_creation_widget drives the SAME _on_attr_plus_pressed the
	# AttrPlus buttons call, proving the handler without coordinate input.
	# Guarded to the ATTRS phase so a stray press cannot advance TRAITS/CONFIRM.
	if Input.is_action_just_pressed("debug_click_creation_widget"):
		if not confirmed and phase == "ATTRS":
			_on_attr_plus_pressed(attr_index)


## Round-2 geometry observables (the "把界面排出来" gate): per-frame, decidable
## creation-screen layout facts for the playtest harness, same shape as hud.gd's
## _update_geometry_observables(). Every rect comes from get_global_rect() on the
## shared canvas coordinate system (creation screen is a full-viewport Control —
## global rect == viewport px). Every measurement of a phase box is gated on
## `visible` (hidden Controls still report rects). Phase-gated facts keep their
## last value outside their phase. Purely additive — no existing surface var or
## behavior is touched.
func _update_geometry_observables() -> void:
	var points_label: Label = get_node_or_null("PointsLabel") as Label
	var mouse_box: Control = get_node_or_null("MouseBox") as Control
	var attr_box: Control = get_node_or_null("MouseBox/AttrBox") as Control
	var trait_box: Control = get_node_or_null("MouseBox/TraitBox") as Control
	var confirm_box: Control = get_node_or_null("MouseBox/ConfirmBox") as Control
	# The current visible phase box: exactly one of the three is visible per phase
	# (set by _render's per-leaf visible sync).
	var phase_box: Control = null
	if attr_box != null and attr_box.visible:
		phase_box = attr_box
	elif trait_box != null and trait_box.visible:
		phase_box = trait_box
	elif confirm_box != null and confirm_box.visible:
		phase_box = confirm_box
	# 1. attr_rows_uniform (ATTRS only): all five visible rows share height,
	#    left and right edges (±1px) and are tall enough to group the value label
	#    with its -/+ cluster into one touch row (>= 32px).
	if phase == "ATTRS":
		attr_rows_uniform = true
		var ref_rect: Rect2 = Rect2()
		var have_ref: bool = false
		for i in 5:
			var row: Control = get_node_or_null("MouseBox/AttrBox/AttrRow%d" % i) as Control
			if row == null or not row.visible:
				attr_rows_uniform = false
				break
			var r: Rect2 = row.get_global_rect()
			if not have_ref:
				ref_rect = r
				have_ref = true
			if r.size.y < 32.0 \
					or absf(r.size.y - ref_rect.size.y) > 1.0 \
					or absf(r.position.x - ref_rect.position.x) > 1.0 \
					or absf(r.end.x - ref_rect.end.x) > 1.0:
				attr_rows_uniform = false
				break
	# 2. attr_label_alignment_ok (ATTRS only): all five AttrRow*/AttrLabel carry
	#    horizontal_alignment == 2 (right) AND size_flags_horizontal == 3
	#    (expand-fill) — the property pair that makes the value text hug its -/+
	#    cluster. Computed bool, not node asserts: the five labels share the bare
	#    name "AttrLabel" (the harness's recursive bare-name search cannot
	#    disambiguate five matches), so they are resolved by indexed path.
	if phase == "ATTRS":
		attr_label_alignment_ok = true
		for i in 5:
			var label: Label = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrLabel" % i) as Label
			if label == null \
					or int(label.horizontal_alignment) != 2 \
					or label.size_flags_horizontal != 3:
				attr_label_alignment_ok = false
				break
	# 3. points_attrs_gap_ok (always): PointsLabel TEXT rect bottom .. current
	#    phase's FIRST-ROW ink cluster top ∈ [4, 24] px AND the two x-centers
	#    within 4px. Round-3 rework: the MEASURED QUANTITIES changed — from
	#    container rects (PointsLabel full rect vs phase box rect: both center
	#    at 480 by construction, so the old fact could never go red) to INK
	#    (PointsLabel text rect via _label_text_rect vs the phase's first-row
	#    cluster). Same var name, same yaml assert lines — only what is measured
	#    differs. TRAITS/CONFIRM clusters are BUTTON rects (shrink-centered, no
	#    expand-fill slack — rect == ink there); ATTRS uses the row ink union.
	if points_label != null:
		var p_rect: Rect2 = _label_text_rect(points_label)
		var cluster: Rect2 = Rect2()
		match phase:
			"ATTRS":
				cluster = _row_ink_union(0)
			"TRAITS":
				var gap_toggle0: Button = get_node_or_null("MouseBox/TraitBox/TraitToggle0") as Button
				if gap_toggle0 != null:
					cluster = gap_toggle0.get_global_rect()
			"CONFIRM":
				# points_attrs_gap_ok CONFIRM cluster: re-pointed from the
				# ConfirmButton rect to the ConfirmSummaryLabel rect. Same
				# observable, same yaml assert lines — a measured-quantity change
				# per the jinyong-layout-r2 precedent. The summary label is now
				# the phase's first-row ink cluster: its rect top == its first ink
				# line's top and its centered lines make rect center == ink
				# center, so both conjuncts the gap check reads (top y, center x)
				# remain ink facts. ConfirmButton fallback for a missing node.
				var gap_summary: Control = get_node_or_null("MouseBox/ConfirmBox/ConfirmSummaryLabel") as Control
				if gap_summary != null:
					cluster = gap_summary.get_global_rect()
				else:
					var gap_confirm: Button = get_node_or_null("MouseBox/ConfirmBox/ConfirmButton") as Button
					if gap_confirm != null:
						cluster = gap_confirm.get_global_rect()
		# Zero-size cluster = missing node: keep the previous value (do not
		# force true/false) so a transient lookup gap never fakes a verdict.
		if cluster.size != Vector2.ZERO:
			var gap: float = cluster.position.y - p_rect.end.y
			points_attrs_gap_ok = gap >= 4.0 and gap <= 24.0 \
					and absf(cluster.get_center().x - p_rect.get_center().x) <= 4.0
	# 4. phase_skeleton_same: record the AttrBox top on the first ATTRS frame;
	#    TRAITS/CONFIRM compare the visible box top against it (±2px). ATTRS is
	#    the reference itself, so the fact reads true by construction.
	if phase == "ATTRS":
		if attr_box != null:
			_ref_box_top = attr_box.get_global_rect().position.y
		phase_skeleton_same = true
	elif phase_box != null and _ref_box_top > 0.0:
		phase_skeleton_same = absf(phase_box.get_global_rect().position.y - _ref_box_top) <= 2.0
	# 5. creation_in_viewport (always): MouseBox rect fully inside the viewport
	#    inset by 16px.
	if mouse_box != null:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		creation_in_viewport = viewport_rect.grow(-16.0).encloses(mouse_box.get_global_rect())
	# 6. creation_box_fits (always): current visible phase box content bottom
	#    stays 8px clear of the MouseBox bottom.
	if mouse_box != null and phase_box != null:
		creation_box_fits = phase_box.get_global_rect().end.y <= mouse_box.get_global_rect().end.y - 8.0
	# ---- Round-3 leaf-ink layout facts (surface, append-only). Measured on
	# INK (label TEXT rects via _label_text_rect and button rects), never
	# container rects — the expand-fill AttrLabel's full rect centers at 480 by
	# construction while its text sits at the right edge (the container-rect lie
	# this round removes). Phase-gated facts keep their last value outside their
	# phase (existing convention). Every node lookup is get_node_or_null +
	# cast: a missing node must never crash the frame.
	var vcx: float = get_viewport().get_visible_rect().size.x * 0.5
	# 7. attr_cluster_center_ok (ATTRS only): every attr row's ink union is
	#    non-empty and its x-center is within ±6px of the viewport center.
	if phase == "ATTRS":
		attr_cluster_center_ok = true
		for i in 5:
			var u: Rect2 = _row_ink_union(i)
			if u.size == Vector2.ZERO or absf(u.get_center().x - vcx) > 6.0:
				attr_cluster_center_ok = false
				break
	# 8. attr_cluster_width_ok (ATTRS only, B-class guard): every row's ink
	#    union stays within 340px (no cluster re-expansion).
	if phase == "ATTRS":
		attr_cluster_width_ok = true
		for i in 5:
			var u: Rect2 = _row_ink_union(i)
			if u.size == Vector2.ZERO or u.size.x > 340.0:
				attr_cluster_width_ok = false
				break
	# 9. nav_cluster_center_ok (every phase): the phase's two nav buttons'
	#    rects union is centered on vcx (±6px) AND at most 240px wide. Missing
	#    node -> false. ATTRS/TRAITS pre-fix buttons are FILL-stretched across
	#    the 560px box, so the width conjunct is what makes this robustly red.
	nav_cluster_center_ok = true
	var nav_union: Rect2 = Rect2()
	var nav_paths: Array[String] = []
	match phase:
		"ATTRS":
			nav_paths = ["MouseBox/AttrBox/AttrNavRow/AttrBackButton", "MouseBox/AttrBox/AttrNavRow/AttrNextButton"]
		"TRAITS":
			nav_paths = ["MouseBox/TraitBox/TraitNavRow/TraitBackButton", "MouseBox/TraitBox/TraitNavRow/TraitNextButton"]
		"CONFIRM":
			nav_paths = ["MouseBox/ConfirmBox/ConfirmButton", "MouseBox/ConfirmBox/BackButton"]
	for nav_path in nav_paths:
		var nav_button: Button = get_node_or_null(nav_path) as Button
		if nav_button == null:
			nav_union = Rect2()
			break
		if nav_union.size == Vector2.ZERO:
			nav_union = nav_button.get_global_rect()
		else:
			nav_union = nav_union.merge(nav_button.get_global_rect())
	if nav_union.size == Vector2.ZERO \
			or absf(nav_union.get_center().x - vcx) > 6.0 \
			or nav_union.size.x > 240.0:
		nav_cluster_center_ok = false
	# 10. trait_cluster_center_ok (TRAITS only): the union of every visible
	#     trait toggle rect is centered on vcx (±6px) AND at most 340px wide.
	if phase == "TRAITS":
		trait_cluster_center_ok = true
		var trait_union: Rect2 = Rect2()
		for i in 13:
			var toggle: Button = get_node_or_null("MouseBox/TraitBox/TraitToggle%d" % i) as Button
			if toggle == null or not toggle.visible:
				trait_cluster_center_ok = false
				break
			if trait_union.size == Vector2.ZERO:
				trait_union = toggle.get_global_rect()
			else:
				trait_union = trait_union.merge(toggle.get_global_rect())
		if trait_union.size == Vector2.ZERO \
				or absf(trait_union.get_center().x - vcx) > 6.0 \
				or trait_union.size.x > 340.0:
			trait_cluster_center_ok = false
	# 11. desc_center_ok (ATTRS only): the AttrDescLabel TEXT rect is centered
	#     on vcx (±6px). The TRAITS desc is wrapped multi-line and is NOT
	#     measured here (its centering is pinned by the desc_alignment_ok
	#     property check instead — get_string_size is not exact for wrapping).
	if phase == "ATTRS":
		var desc_label: Label = get_node_or_null("MouseBox/AttrBox/AttrDescLabel") as Label
		if desc_label == null:
			desc_center_ok = false
		else:
			var desc_rect: Rect2 = _label_text_rect(desc_label)
			desc_center_ok = desc_rect.size != Vector2.ZERO \
					and absf(desc_rect.get_center().x - vcx) <= 6.0
	# 12. desc_alignment_ok (every phase): both phase description labels carry
	#     horizontal_alignment == CENTER (1) — the property pin that keeps the
	#     wrapped TRAITS description on the same axis as the nav buttons.
	desc_alignment_ok = true
	var desc_attr: Label = get_node_or_null("MouseBox/AttrBox/AttrDescLabel") as Label
	var desc_trait: Label = get_node_or_null("MouseBox/TraitBox/TraitDescLabel") as Label
	if desc_attr == null or desc_trait == null \
			or int(desc_attr.horizontal_alignment) != 1 \
			or int(desc_trait.horizontal_alignment) != 1:
		desc_alignment_ok = false


## Text sub-rect of a Label inside its global rect, honoring its
## horizontal_alignment (LEFT 0 / CENTER 1 / RIGHT 2). The label's FULL rect is
## not ink: an expand-fill AttrLabel's rect spans the whole row while its text
## hugs the right edge — the container-rect lie this round removes. Returns the
## text's pixel rect via Font.get_string_size (exact for the single-line labels
## measured here).
func _label_text_rect(l: Label) -> Rect2:
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var sz: Vector2 = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var lr: Rect2 = l.get_global_rect()
	match int(l.horizontal_alignment):
		2:  # RIGHT: text hugs the label's right edge.
			return Rect2(lr.end.x - sz.x, lr.position.y + (lr.size.y - sz.y) * 0.5, sz.x, sz.y)
		1:  # CENTER: text is centered inside the label rect.
			return Rect2(lr.position.x + (lr.size.x - sz.x) * 0.5, lr.position.y + (lr.size.y - sz.y) * 0.5, sz.x, sz.y)
		_:  # LEFT (0) and anything unknown: text starts at the rect origin.
			return Rect2(lr.position, sz)


## Sync each row's cost-label cell width to its equal-width spacer, so cost-text
## width changes cancel symmetrically and the measured cluster (AttrLabel text
## rect ∪ AttrMinus ∪ AttrPlus) stays centered at the viewport center regardless
## of "剩 %d" digit / tier differences. Runs every frame BEFORE the layout facts
## are computed. Only writes a spacer when its width actually changed (avoids
## re-triggering the container layout pass every frame). Null-safe: any missing
## row node is skipped.
func _sync_attr_cost_cells() -> void:
	for i in 5:
		var label: Control = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrCostLabel%d" % [i, i]) as Control
		var spacer: Control = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrCostSpacer%d" % [i, i]) as Control
		if label == null or spacer == null:
			continue
		if label.custom_minimum_size.x != _ATTR_COST_CELL:
			label.custom_minimum_size = Vector2(_ATTR_COST_CELL, 0.0)
		var sp: float = label.get_combined_minimum_size().x
		if spacer.custom_minimum_size.x != sp:
			spacer.custom_minimum_size = Vector2(sp, 0.0)


## Ink union of attr row i: label TEXT rect ∪ AttrMinus{i} rect ∪ AttrPlus{i}
## rect. Returns Rect2() (zero size — the missing/invalid sentinel every
## consumer checks) if any of the three nodes is missing or not visible.
## The minus/plus node names carry the same index twice (AttrMinus%d / AttrPlus%d),
## per _wire_mouse_widgets.
func _row_ink_union(i: int) -> Rect2:
	var label: Label = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrLabel" % i) as Label
	var minus: Button = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button
	var plus: Button = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button
	if label == null or minus == null or plus == null \
			or not label.visible or not minus.visible or not plus.visible:
		return Rect2()
	var union: Rect2 = _label_text_rect(label)
	union = union.merge(minus.get_global_rect())
	union = union.merge(plus.get_global_rect())
	return union


## Wire every mouse widget's pressed signal to the bound handler — the keyboard
## handlers stay the only logic, the buttons just delegate (single source of
## truth). Code wiring (menu_panel/settings_panel precedent) keeps the
## pressed_connected snapshot adjacent to the connects. Snapshot AFTER all
## connects: before connect() the signal's connection list is empty.
func _wire_mouse_widgets() -> void:
	for i in 5:
		(get_node("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button).pressed.connect(_on_attr_minus_pressed.bind(i))
		(get_node("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button).pressed.connect(_on_attr_plus_pressed.bind(i))
	for i in min(_traits.size(), 13):
		(get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button).pressed.connect(_on_trait_toggle_pressed.bind(i))
		# Defect C: hover-preview. mouse_entered carries the index via .bind(i)
		# (bind PREPENDS, so the handler takes one int arg); mouse_exited is
		# connected UNBOUND (the signal emits 0 args — a .bind here would make
		# emission a runtime error).
		(get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button).mouse_entered.connect(_on_trait_toggle_hover_entered.bind(i))
		(get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button).mouse_exited.connect(_on_trait_toggle_hover_exited)
	(get_node("MouseBox/ConfirmBox/ConfirmButton") as Button).pressed.connect(_on_accept)
	(get_node("MouseBox/ConfirmBox/BackButton") as Button).pressed.connect(_on_move_left)
	# Phase-navigation buttons (defect 2): every keyboard-only transition gets a
	# mouse button delegating to the SAME handler — keyboard degrades to a
	# shortcut, the button is the convergence point. AttrBackButton is the one
	# NEW handler (menu routing); the rest reuse existing keyboard arms.
	(get_node("MouseBox/AttrBox/AttrNavRow/AttrBackButton") as Button).pressed.connect(_on_creation_back_to_menu)
	(get_node("MouseBox/AttrBox/AttrNavRow/AttrNextButton") as Button).pressed.connect(_on_accept)
	(get_node("MouseBox/TraitBox/TraitNavRow/TraitBackButton") as Button).pressed.connect(_on_move_left)
	(get_node("MouseBox/TraitBox/TraitNavRow/TraitNextButton") as Button).pressed.connect(_on_move_right)
	pressed_connected.clear()
	for i in 5:
		pressed_connected["AttrMinus%d" % i] = (get_node("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button).get_signal_connection_list("pressed").size() > 0
		pressed_connected["AttrPlus%d" % i] = (get_node("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button).get_signal_connection_list("pressed").size() > 0
	for i in min(_traits.size(), 13):
		pressed_connected["TraitToggle%d" % i] = (get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button).get_signal_connection_list("pressed").size() > 0
	# Snapshot AFTER all connects (Defect C): true iff BOTH hover signals are wired.
	# Same range as the wiring loop above, so no key exists for an unwired toggle.
	hover_connected.clear()
	for i in min(_traits.size(), 13):
		var hover_btn: Button = get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button
		hover_connected["TraitToggle%d" % i] = (
			hover_btn.get_signal_connection_list("mouse_entered").size() > 0
			and hover_btn.get_signal_connection_list("mouse_exited").size() > 0
		)
	pressed_connected["ConfirmButton"] = (get_node("MouseBox/ConfirmBox/ConfirmButton") as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["BackButton"] = (get_node("MouseBox/ConfirmBox/BackButton") as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["AttrBackButton"] = (get_node("MouseBox/AttrBox/AttrNavRow/AttrBackButton") as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["AttrNextButton"] = (get_node("MouseBox/AttrBox/AttrNavRow/AttrNextButton") as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["TraitBackButton"] = (get_node("MouseBox/TraitBox/TraitNavRow/TraitBackButton") as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["TraitNextButton"] = (get_node("MouseBox/TraitBox/TraitNavRow/TraitNextButton") as Button).get_signal_connection_list("pressed").size() > 0


## Cost to raise an attr from `v` to `v + 1` (v in 10..19): 1 for 10..14,
## 2 for 15..19 (step2_design §2.2 tiered pricing).
func _step_cost(v: int) -> int:
	return 1 if v < 15 else 2


func _cycle_attr_or_trait(dir: int) -> void:
	match phase:
		"ATTRS":
			attr_index = (attr_index + dir + 5) % 5
		"TRAITS":
			trait_index = (trait_index + dir + _traits.size()) % _traits.size()
		_:
			return
	_render()


func _on_move_left() -> void:
	match phase:
		"ATTRS":
			var key: String = PlayerProfile.ATTR_KEYS[attr_index]
			var v: int = int(attrs[key])
			if v > ATTR_MIN:
				# Going v -> v-1 refunds the cost that was paid for v-1 -> v.
				points_left += _step_cost(v - 1)
				attrs[key] = v - 1
		"TRAITS":
			phase = "ATTRS"
			_render()
			return
		"CONFIRM":
			phase = "TRAITS"
			_render()
			return
	_render()


func _on_move_right() -> void:
	match phase:
		"ATTRS":
			var key: String = PlayerProfile.ATTR_KEYS[attr_index]
			var v: int = int(attrs[key])
			if v < ATTR_MAX:
				var cost: int = _step_cost(v)
				if points_left >= cost:
					points_left -= cost
					attrs[key] = v + 1
		"TRAITS":
			phase = "CONFIRM"
		"CONFIRM":
			return
	_render()


func _on_accept() -> void:
	match phase:
		"ATTRS":
			phase = "TRAITS"
			trait_index = 0
		"TRAITS":
			_toggle_trait(trait_index)
		"CONFIRM":
			if not confirmed and not SceneManager.pending_swap:
				confirmed = true
				SaveManager.new_profile(attrs, trait_ids)
				GameManager.finish_creation()
			return
	_render()


## Mouse AttrBackButton (ATTRS phase): leave creation back to the main menu.
## Routes through GameManager.enter_menu() — idempotent, emits state_changed
## ("MENU") and SceneManager swaps to the menu scene (needs the /root/Main
## shell; a direct creation.tscn boot cannot host the swap). Deliberately NOT
## _on_move_left: in ATTRS its arm DECREMENTS the focused attribute, which
## would silently eat a creation point on every back-press.
func _on_creation_back_to_menu() -> void:
	if confirmed or SceneManager.pending_swap:
		return
	GameManager.enter_menu()


## Toggle a trait/flaw: positive cost spends points; a flaw (negative cost)
## refunds points. Toggling ON is refused when it would drive points negative;
## leftover points are allowed at confirm.
func _toggle_trait(idx: int) -> void:
	if idx < 0 or idx >= _traits.size():
		return
	var def = _traits[idx]
	var id: String = def.id
	var cost: int = def.cost
	if trait_ids.has(id):
		trait_ids.erase(id)
		points_left += cost
	else:
		if points_left - cost < 0:
			return
		trait_ids.append(id)
		points_left -= cost


## Mouse: focus a row without any other side effect — the following minus/plus
## press acts on the clicked row.
func _focus_attr(i: int) -> void:
	attr_index = i


## Mouse AttrMinus{i}: delegate to the same handler keyboard move_left uses.
func _on_attr_minus_pressed(i: int) -> void:
	_focus_attr(i)
	_on_move_left()


## Mouse AttrPlus{i}: delegate to the same handler keyboard move_right uses.
func _on_attr_plus_pressed(i: int) -> void:
	_focus_attr(i)
	_on_move_right()


## Mouse TraitToggle{i}: delegate to the same toggle keyboard ui_accept uses.
func _on_trait_toggle_pressed(i: int) -> void:
	trait_index = i
	_toggle_trait(i)
	_render()


## Pure selection rule (Defect C): which trait index the description label shows.
## The hover preview wins whenever it is set (>= 0); otherwise fall back to the
## keyboard-focused trait_index. Static on purpose — unit-testable without an
## instance; _render() obtains its desc index ONLY via this call. Any negative
## hover value counts as "unset".
static func hover_desc_index(trait_index: int, trait_hover_index: int) -> int:
	if trait_hover_index >= 0:
		return trait_hover_index
	return trait_index


## Mouse TraitToggle{i} hover-entered: preview trait i's description WITHOUT
## touching trait_index, WITHOUT toggling, and WITHOUT affecting the focus
## modulate (display-only channel — see trait_hover_index).
func _on_trait_toggle_hover_entered(i: int) -> void:
	trait_hover_index = i
	_render()


## Mouse TraitToggle{i} hover-exited: drop the preview; the description falls back
## to trait_index's entry. Connected UNBOUND (mouse_exited emits 0 args).
func _on_trait_toggle_hover_exited() -> void:
	trait_hover_index = -1
	_render()


func _render() -> void:
	# Defect C phase gate (FIRST statement): a hidden button does not reliably emit
	# mouse_exited while the pointer sits on its old rect, so this — not the exit
	# signal — is the only guarantee a stale hover index cannot leak into ATTRS/CONFIRM.
	if phase != "TRAITS":
		trait_hover_index = -1
	# Single-surface model: the MouseBox button set is the ONLY operation
	# surface; the old keyboard-cursor text list (BodyLabel) is gone. Keyboard
	# input remains a pure shortcut layer acting on this button surface (row
	# focus + +/- / toggle / accept). PointsLabel carries the points display
	# that used to live inside the removed text list.
	var points_label: Label = get_node_or_null("PointsLabel") as Label
	if points_label != null:
		points_label.text = tr("剩余点数 %d") % points_left
	var hint_label: Label = get_node_or_null("HintLabel") as Label
	if hint_label != null:
		match phase:
			"ATTRS":
				hint_label.text = "点击 ± 调整属性 · 回车下一步"
			"TRAITS":
				hint_label.text = "点击切换特质 · 回车进入确认"
			"CONFIRM":
				hint_label.text = "点击确认踏上江湖 · 回车确认"
	# Mouse widget surface: per-phase group visibility + row/toggle texts. The
	# buttons ARE the single operation surface (the keyboard text model is gone).
	# Every leaf's `visible` mirrors the phase so node-level asserts
	# (TraitToggle0.visible == false in ATTRS) hold, not just the group.
	var attr_box: Control = get_node_or_null("MouseBox/AttrBox") as Control
	var trait_box: Control = get_node_or_null("MouseBox/TraitBox") as Control
	var confirm_box: Control = get_node_or_null("MouseBox/ConfirmBox") as Control
	if attr_box != null:
		attr_box.visible = phase == "ATTRS"
	if trait_box != null:
		trait_box.visible = phase == "TRAITS"
	if confirm_box != null:
		confirm_box.visible = phase == "CONFIRM"
	for i in range(PlayerProfile.ATTR_KEYS.size()):
		var row: Control = get_node_or_null("MouseBox/AttrBox/AttrRow%d" % i) as Control
		if row != null:
			row.visible = phase == "ATTRS"
		var minus: Button = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button
		if minus != null:
			minus.visible = phase == "ATTRS"
		var plus: Button = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button
		if plus != null:
			plus.visible = phase == "ATTRS"
		var row_label: Label = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrLabel" % i) as Label
		if row_label != null:
			row_label.text = "%s %2d" % [_attr_label(PlayerProfile.ATTR_KEYS[i]), int(attrs[PlayerProfile.ATTR_KEYS[i]])]
		var cost_label: Label = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrCostLabel%d" % [i, i]) as Label
		if cost_label != null:
			var v: int = int(attrs[PlayerProfile.ATTR_KEYS[i]])
			cost_label.visible = phase == "ATTRS"
			if phase == "ATTRS":
				cost_label.text = tr("＋1 需 %d 点 · −1 退 %d 点 · 剩 %d") % [_step_cost(v), _step_cost(v - 1), points_left]
		if i == attr_index:
			var fv: int = int(attrs[PlayerProfile.ATTR_KEYS[i]])
			attr_step_cost = _step_cost(fv)
			attr_cost_text = tr("＋1 需 %d 点 · −1 退 %d 点 · 剩 %d") % [_step_cost(fv), _step_cost(fv - 1), points_left]
	for i in range(min(_traits.size(), 13)):
		var toggle: Button = get_node_or_null("MouseBox/TraitBox/TraitToggle%d" % i) as Button
		if toggle != null:
			toggle.visible = phase == "TRAITS"
			var def = _traits[i]
			var owned: String = tr("已选") if trait_ids.has(def.id) else ("+" + str(def.cost) if def.cost > 0 else str(def.cost))
			toggle.text = tr(def.display_name) + " " + owned
	var confirm_button: Button = get_node_or_null("MouseBox/ConfirmBox/ConfirmButton") as Button
	if confirm_button != null:
		confirm_button.visible = phase == "CONFIRM"
	var back_button: Button = get_node_or_null("MouseBox/ConfirmBox/BackButton") as Button
	if back_button != null:
		back_button.visible = phase == "CONFIRM"
	# Phase-navigation buttons (defect 2): same per-leaf visible sync so
	# node-level asserts hold, not just the parent group boxes.
	var attr_back: Button = get_node_or_null("MouseBox/AttrBox/AttrNavRow/AttrBackButton") as Button
	if attr_back != null:
		attr_back.visible = phase == "ATTRS"
	var attr_next: Button = get_node_or_null("MouseBox/AttrBox/AttrNavRow/AttrNextButton") as Button
	if attr_next != null:
		attr_next.visible = phase == "ATTRS"
	var trait_back: Button = get_node_or_null("MouseBox/TraitBox/TraitNavRow/TraitBackButton") as Button
	if trait_back != null:
		trait_back.visible = phase == "TRAITS"
	var trait_next: Button = get_node_or_null("MouseBox/TraitBox/TraitNavRow/TraitNextButton") as Button
	if trait_next != null:
		trait_next.visible = phase == "TRAITS"
	# Description labels (defects 4/5) + the clarity info layer (UX-06/07/08).
	# All derivations are display-only — no rule or stored value changes.
	hp_value = hp_from_bone(int(attrs["bone"]))
	hp_text = tr("当前气血 %d") % hp_value
	confirm_summary_text = confirm_summary_text_from(attrs)
	var attr_desc_label: Label = get_node_or_null("MouseBox/AttrBox/AttrDescLabel") as Label
	if attr_desc_label != null:
		attr_desc_label.visible = phase == "ATTRS"
		if phase == "ATTRS":
			# UX-06: the desc slot now lists ALL FIVE attribute effects at rest
			# (name-prefixed, verbatim from _ATTR_DESCS) instead of only the
			# focused attribute's desc — a deliberate D1 semantic change so the
			# at-rest page tells the player what each attribute does. attr_index
			# still drives the focus highlight (modulate) and the +/- target.
			# Do NOT "fix" this back to the focused desc; it is the point of UX-06.
			attr_desc_label.text = attr_effects_text()
	# UX-07: current HP value next to the formula list (ATTRS only).
	var hp_label: Label = get_node_or_null("MouseBox/AttrBox/HpValueLabel") as Label
	if hp_label != null:
		hp_label.visible = phase == "ATTRS"
		if phase == "ATTRS":
			hp_label.text = hp_text
	# UX-08: the confirm-page final-value checklist (CONFIRM only).
	var confirm_summary_label: Label = get_node_or_null("MouseBox/ConfirmBox/ConfirmSummaryLabel") as Label
	if confirm_summary_label != null:
		confirm_summary_label.visible = phase == "CONFIRM"
		if phase == "CONFIRM":
			confirm_summary_label.text = confirm_summary_text
	var trait_desc_label: Label = get_node_or_null("MouseBox/TraitBox/TraitDescLabel") as Label
	if trait_desc_label != null:
		trait_desc_label.visible = phase == "TRAITS"
		# Defect C: resolve the display index through the pure helper so the
		# "hover wins over focus" rule lives in exactly ONE place (unit-testable).
		var desc_idx: int = hover_desc_index(trait_index, trait_hover_index)
		if phase == "TRAITS" and desc_idx >= 0 and desc_idx < _traits.size():
			trait_desc_label.text = _traits[desc_idx].description
	# Focused-row visual: attr_index / trait_index drive which row minus/plus or
	# toggle acts on; show the focus on the single button surface via modulate
	# (full vs dim) instead of a duplicated text list. modulate propagates to a
	# row's buttons/labels — intended. Deterministic in every phase: CONFIRM
	# dims everything.
	for i in range(PlayerProfile.ATTR_KEYS.size()):
		var row: Control = get_node_or_null("MouseBox/AttrBox/AttrRow%d" % i) as Control
		if row != null:
			row.modulate = Color(1, 1, 1, 1) if (phase == "ATTRS" and i == attr_index) else Color(0.72, 0.72, 0.72, 1)
	for i in range(13):
		var toggle: Button = get_node_or_null("MouseBox/TraitBox/TraitToggle%d" % i) as Button
		if toggle != null:
			toggle.modulate = Color(1, 1, 1, 1) if (phase == "TRAITS" and i == trait_index) else Color(0.72, 0.72, 0.72, 1)
	# Runtime proof the keyboard-cursor surface is gone: scan every Label
	# descendant for the U+25B6 marker (BLACK RIGHT-POINTING TRIANGLE) the
	# removed text model rendered in front of the focused row. Must run LAST so
	# freshly-written texts are seen.
	cursor_markers_visible = false
	for label in find_children("*", "Label", true, false):
		var label_node: Label = label as Label
		if label_node != null and label_node.text.contains("▶"):
			cursor_markers_visible = true
			break


func _attr_label(key: String) -> String:
	match key:
		"bone":
			return tr("根骨")
		"inner":
			return tr("内力")
		"agility":
			return tr("身法")
		"wisdom":
			return tr("悟性")
		"fortune":
			return tr("福缘")
	return key


## Pure derivation: HP from 根骨 (design/40_progression.md §7 气血 = 根骨 × 5).
## Reads no nodes, so tests can call it on a bare instance. The multiplier 5
## IS the documented formula — the only number this round is allowed to show.
func hp_from_bone(bone: int) -> int:
	return bone * 5


## Pure composition: all five attribute effects, name-prefixed, each segment
## VERBATIM from _ATTR_DESCS (design/10_systems.md §1 + 40_progression.md §7
## formulas). Nothing is invented; _attr_desc("") never throws for unknown keys.
func attr_effects_text() -> String:
	var parts: Array[String] = []
	for key in PlayerProfile.ATTR_KEYS:
		parts.append("%s:%s" % [_attr_label(key), _attr_desc(key)])
	return " · ".join(parts)


## Pure composition: the confirm-page summary, one line per attribute in
## PlayerProfile.ATTR_KEYS order, same "名 值" shape as the ATTRS row labels.
func confirm_summary_text_from(values: Dictionary) -> String:
	var lines: Array[String] = []
	for key in PlayerProfile.ATTR_KEYS:
		lines.append("%s %2d" % [_attr_label(key), int(values.get(key, 0))])
	return "\n".join(lines)


## Description for an attribute key (zh source, translated for the active
## locale); "" for unknown keys (never throws).
func _attr_desc(key: String) -> String:
	var desc: String = _ATTR_DESCS.get(key, "")
	return tr(desc) if desc != "" else ""
