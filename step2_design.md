# Technical Architecture Design - Portrait Visibility Predicate Hole (UX-01a/01b) + Event Pool 4 -> 16

Round: **jinyong-events** (working name). Baseline: 46 playtest scenarios / 45 green
(`terminal_victory_8_12_rounds_hp_15_40` is the single deliberate red), pytest 9 passed,
GDScript unit suite 12 passed, vision gate Q1-Q6 pass. This round adds **no new
mechanisms, no new effect types, no number changes, no map/topology/art changes**. It
does three things, all inside the existing additive discipline:

1. **Close the two holes in the `VisibilityProbe` predicate** so it genuinely decides
   "ink is on the 960x704 frame": a **partial-occlusion** layer (a portrait 72% hidden
   under the 0..92 top strip currently passes because `occluded` demands *full*
   enclosure) and a **blank-texture** layer (a spot where *nothing is drawn* currently
   passes all six layers). Publish the **3-number probe** (sprite `global_position` +
   `texture.get_size()` + health-bar `global_position`) the brief mandates, then fix
   **only what a measured fail-layer id points at**.
2. **Events 4 -> 16** - pure data in `EventData.TABLE`, two real trade-off options per
   row, Chinese Jin Yong flavor, only the 5 implemented effect types
   (`silver`/`attr`/`item`/`practice`/`none`), only real item ids.
3. **Prove the no-repeat bag** - `_draw_event()` already excludes `events_seen` and
   resets on pool exhaustion; this round makes that **observable and tested** (unit
   test + playtest scenario), not rewritten.

Per `step1_sota.md` everything is engine-native Godot 4 APIs extended in place; no new
dependencies, no external content files, no procedural generation.

---

## 1. Overview

| Goal | Current defect | Fix idiom | Red-before-fix proof (A-class) |
|---|---|---|---|
| UX-01b (王重阳) | Portrait drawn but ~72% covered by the opaque panels inside the 0..92 top strip; `sprite_top == 0.0`; predicate passes because `occluded` requires full enclosure | New layer `covered` (partial occlusion by a later-drawn opaque host) -> measured `covered` id unlocks a clamp top-margin fix in `GridManager.clamp_sprite_offset` | Pre-fix `Central_Divine.portrait_visible == false` with `portrait_fail_layer == "covered"` and `portrait_covered_frac >= 0.25`, observed at f40 |
| UX-01a (杨过) | `sprite_top == 224.0` says ink is mid-board, the raw frame shows scenery there; all six layers pass | New layer `blank_texture` (asset-level alpha scan) + the 3-number probe; fix locus chosen ONLY from the measured failing layer | Pre-fix `Player.portrait_visible == false` with a non-empty measured fail-layer id, observed at f40; if every layer measures green with consistent numbers, UX-01a is recorded as a frame-reading divergence and NOT "fixed" (no-guess rule) |
| Events 4 -> 16 | Pool exhausts after 4 travels; 4 rows are near-isomorphic "cost vs gain" | 12 new hand-written rows in `EventData.TABLE` (verbatim below), additive test extensions | `tests/test_event_data.gd` size check `all_defs.size() >= 16` fails at baseline (observed 4) |
| No-repeat bag | Exclusion + reset implemented but unproven | Additive observables (`events_seen_count`) + deterministic unit tests (15-of-16 forced draw; all-16 reset) + one interactive playtest scenario | New unit tests fail at baseline only in the sense of not existing; the interactive scenario's `events_seen_count == k` ladder is the B-class regression guard |

**Probe-first is a hard ordering** (repo rule 先查明再修，不许猜): the visibility fix
task may not start until the extended probe has written measured per-unit values (the
3 numbers + per-layer verdict + `portrait_covered_frac`) into
`final/portrait_cover_probe_notes.md`. A fix PR without probe evidence is rejected at
review. The two units are probed and fixed **independently** - they may fail for
different reasons.

---

## 2. Architecture Diagram (text)

```
scripts/ui/visibility_probe.gd  (EXTEND IN PLACE - the single source of truth)
    VisibilityProbe.first_fail_layer(unit_root) -> String
        "" | hidden_in_tree | null_texture | blank_texture(NEW)
          | zero_rect | off_viewport | clipped | occluded | covered(NEW)
    VisibilityProbe.covered_fraction(unit_root) -> float   (NEW, max single-coverer frac)
    Layer order stays cheap-to-expensive; `occluded` (full enclosure) is checked
    BEFORE `covered` (>= COVERED_AREA_FRAC) so a fully-hidden portrait still reports
    the precise id "occluded".
                    │ called per frame (cheap; tree walk already exists for layer 6)
                    ▼
scripts/characters/player.gd + enemy.gd   (ADDITIVE, ~8 lines each)
    _process(): after _refresh_sprite_clamp(), before the undo_available recompute:
        portrait_fail_layer   = VisibilityProbe.first_fail_layer(self)
        portrait_visible      = portrait_fail_layer == ""
        portrait_covered_frac = VisibilityProbe.covered_fraction(self)
        portrait_sprite_pos   = <Sprite child>.global_position   (3-number probe)
        portrait_tex_size     = <Sprite child>.texture.get_size()
        portrait_bar_pos      = <HealthBar child>.global_position or (-1,-1)
                    │ surface (append-only)
                    ▼
playtest/_common.yaml  six unit blocks += the six vars above
        CultivationScreen   += events_seen_count
                    │
scripts/autoload/grid_manager.gd  (GATED FIX, unlocked by measured "covered")
    clamp_sprite_offset(): y lower bound 0 -> BOARD_TOP_MARGIN_Y (= 92, the existing
    top-strip bottom; a presentation-consistency constant, not a new gameplay number)
                    ▼
scripts/data/event_data.gd   TABLE: 4 -> 16 rows (pure data, verbatim in §5)
scripts/segments/cultivation.gd
    _draw_event() / _apply_event_option(): UNCHANGED logic
    _sync_surface(): += events_seen_count (int, len of sanitized events_seen)

GATES (append-only / in-place append / one new file):
    playtest/portrait_visibility.yaml    extend IN PLACE (appended asserts only)
    playtest/event_travel_effects.yaml   NEW scenario (draw -> option -> seen-count ladder)
    tests/test_event_data.gd             extend additively (>= 16, new-row pins, target schema)
    tests/test_cultivation.gd            extend additively (no-repeat + pool-reset unit tests)
    tests/test_playtest_contract_smoke.py ROUND_SCENARIOS += event_travel_effects
                                         + ONE additive test function
    _common.yaml scenario_order          += event_travel_effects (append at end)
    46 scenarios -> 47; terminal_victory stays the only allowed red
```

No `project.godot` change (no new input actions - the new scenario uses only
`ui_accept` / `move_down` / `debug_win_tutorial`). No `.tscn` change. No art change.

---

## 3. Component List

### 3.1 `scripts/ui/visibility_probe.gd` - extend the predicate (the round's core)

**Responsibility:** make "the portrait puts ink on the rendered frame" decidable for
the two hole classes: partial occlusion and nothing-drawn.

**New layer `blank_texture`** (checked immediately after `null_texture`):

- Fires when the leaf's texture resource contains **no pixel with alpha > 0**
  (a fully transparent asset renders nothing no matter how correct the geometry is).
- Implementation: one-time scan per texture via `texture.get_image()` walking the
  alpha channel, cached in a `static var _alpha_scan_cache: Dictionary` keyed by
  `texture.resource_path`. Per-frame cost is a dictionary lookup (6 textures total).
- **Fail-open rule:** if `get_image()` returns null (headless/compressed edge),
  the layer PASSES and the probe notes record "scan unavailable" - never a
  fabricated red.
- This is an **asset-level** measurement, not a frame-pixel verdict: the repo ban is
  on deriving gate verdicts from rendered-frame pixels (the 2.75x
  authored-vs-runtime lesson); scanning the texture resource reports a layer id from
  the resource itself.

**New layer `covered`** (checked after `occluded`):

- Fires when a **later-drawn, `mouse_filter != IGNORE`, visible Control** overlaps the
  ink rect by **>= 25% of the ink rect's area** (and >= 64 px² absolute, to stay above
  antialias/rounding noise on tiny rects).
- Constants (pinned by this design, the one new numeric decision):
  `COVERED_AREA_FRAC := 0.25`, `COVERED_MIN_PX := 64.0`.
- Discrimination check (why 0.25): the brief's real case is a texture ~128 px tall
  with `sprite_top == 0.0` under a 92 px strip -> ~72% of the ink area sits under the
  band, far above the threshold; a unit merely *near* the bar overlaps 0%.
  Semi-transparent hosts are excluded by construction: the repo's opaque-host
  convention is `mouse_filter != IGNORE`, and `TopStrip` itself declares
  `mouse_filter = 2`, so only the opaque children inside the strip (the yellow
  action-bar / turn-order panels) count as coverers.
- **Max-single-coverer semantics:** the measured fraction is the *worst single*
  qualifying coverer, not a union sum (overlapping panels would double-count). Simple,
  deterministic, monotone. The probe notes record per-candidate fractions.
- Reuses the existing candidate machinery (`_draws_after`, `_canvas_layer`,
  `_effective_z`, `_tree_index`, `_is_ancestor_of`) - the same walk `_is_occluded`
  already does; only the geometric test changes from `encloses(rect)` to
  `intersection(rect).get_area() / rect.get_area()`.

**New public helper:** `static func covered_fraction(unit_root: Node2D) -> float` -
the max single-coverer fraction in `[0, 1]`, `0.0` when nothing qualifies. Same
candidates as the `covered` layer. Published per frame so the probe and the
`portrait_covered_frac < 0.25` guards read ONE number, never re-derived math.

**Interface (unchanged):** `leaf_rect`, `first_fail_layer`, `portrait_visible` keep
their signatures and existing layer ids; the doc comment's layer list gains the two
ids. Existing callers (player.gd/enemy.gd `_process`, `portrait_visibility.yaml`
asserts, `tests/test_visibility_probe_canvas_layer.gd`) are unaffected.

### 3.2 `scripts/characters/player.gd` + `scripts/characters/enemy.gd` - additive observables

Identical shape in both files, **no existing line touched**:

- Six new declared vars (documented, playtest surface):
  - `var portrait_covered_frac: float = 0.0`
  - `var portrait_sprite_pos: Vector2 = Vector2.ZERO` - the `Sprite` child's
    `global_position` (canvas space)
  - `var portrait_tex_size: Vector2 = Vector2.ZERO` - `texture.get_size()`
  - `var portrait_bar_pos: Vector2 = Vector2(-1, -1)` - the unit's health-bar node's
    `global_position`; `(-1, -1)` sentinel when no bar node resolves (implementer
    verifies the bar node name/path on `player.tscn` / `enemy.tscn`; if the bars are
    HUD-side, resolve through the existing `follow_character()` pairing and record the
    resolution in the probe notes)
- In `_process()`, immediately after the existing `_refresh_sprite_clamp()` /
  `portrait_fail_layer` / `portrait_visible` block and **before** the
  `undo_available` recompute (the proven ordering - the dead-probe abort class cannot
  recur through this path): assign the four new vars.

**The 3-number probe is mandatory before any fix:** the brief forbids resolving the
Yang Guo contradiction (`sprite_top = 224.0` vs scenery on the raw frame) from pixels
or inference. Only `portrait_sprite_pos` + `portrait_tex_size` +
`portrait_bar_pos` read together decide (texture actually blank, leaf not a
`Sprite2D`/`Control`, wrong node targeted by the clamp, or the ink truly elsewhere).
They are published per frame on all six units and recorded in
`final/portrait_cover_probe_notes.md`.

### 3.3 UX-01 fix - `scripts/autoload/grid_manager.gd` + character scripts (GATED ON PROBE)

**Responsibility:** make the measured-red units pass all layers, changing only what
the probe identified.

**Probe task (runs first, writes `final/portrait_cover_probe_notes.md`):** an inline
`godot_playtest_scenario` probe (never staged in `playtest/`, per the established
pattern in `final/portrait_probe_notes.md`) that boots the tutorial battle
(7x `ui_accept` f3..f15, 3x `tutorial_next` f20/25/30, sample f40) with
always-false contradiction asserts forcing the harness to print each unit's
`observed` values: `portrait_visible`, `portrait_fail_layer`,
`portrait_covered_frac`, `portrait_sprite_pos`, `portrait_tex_size`,
`portrait_bar_pos`, `sprite_top`. The notes file records the per-unit table plus the
per-candidate coverer fractions for the `covered` units.

**Fix-loci table (fix chosen ONLY from the measured failing layer):**

| Observed failing layer | Fix locus (verify against the probe's measured numbers first) |
|---|---|
| `covered` (expected for Central_Divine: `sprite_top == 0.0`, covered_frac ~0.7) | `GridManager.clamp_sprite_offset`: the y lower bound currently clamps the texture center into `[half.y, board.y - half.y]`, i.e. the *board* top = 0. Add `const BOARD_TOP_MARGIN_Y := 92.0` (the existing top-strip bottom) so the lower bound becomes `BOARD_TOP_MARGIN_Y + half.y`. One constant + one line; the guard for textures taller than the board is unchanged. This is the round-protected clamp, unlocked by the measured `covered` id exactly as the protection rule allows |
| `blank_texture` | Texture assignment: the unit's texture path/asset (assign the correct `assets/characters/<unit>.png`, keep the null-safe fallback). If the asset itself is fine but the *player's* leaf differs (e.g. `leaf_rect()` resolving a different child than the clamp writes), correct the resolution, never the clamp |
| `zero_rect` / `off_viewport` from a bad offset | `clamp_sprite_offset` bounds math or `_refresh_sprite_clamp`'s use of it - correct the math so the clamped rect stays on-board **and** below the strip |
| `clipped` | remove/relax `clip_contents` on the offending ancestor |
| `occluded` (full enclosure) | draw order / `z_index` of the covering host |
| All layers green AND the 3 numbers geometrically consistent | **Record the divergence and do NOT fix that unit** (no-guess rule). UX-01a is then a frame-reading artifact on the 960x704 frame and gets dispositioned from the measurement, mirroring the prior round's honest handling |

**Constraints on whatever fix lands:**

- The other units' `portrait_visible` must stay `true` (B-class guards) and the
  existing `sprite_top >= 0.0` asserts keep passing (a 92 px margin keeps them true).
- The clamp change affects every top-row unit uniformly (rows 1-2 get pushed down so
  their ink starts at y >= 92). Bottom-row units are untouched (their tops are far
  below 92). Grid positions, movement, click-targeting, health-bar geometry are all
  untouched - the clamp only moves the sprite's *offset within the tile*, and the
  health-bar clamp (`top >= 94`) already agrees with the 92 px strip.
- `_refresh_sprite_clamp` / `clamp_sprite_offset` are otherwise byte-identical; no
  click-move / undo / commit / focus / top-bar / creation-layout code changes.

### 3.4 `scripts/data/event_data.gd` - TABLE 4 -> 16 rows (pure data)

**Responsibility:** supply the travel-event pool. Pure data layer - resolution (RNG
draw, no-repeat bag, consequence application) stays in `cultivation.gd` untouched.

**Hard contract (from `cultivation.gd:_apply_event_option` - anything outside
silently no-ops = dead content):**

- Effect `type` in exactly `{silver, attr, item, practice, none}`.
- `attr.target` in `{bone, inner, agility, wisdom, fortune}`.
- `item.target` in the real CardData equipment ids:
  `eq_sword_1..4`, `eq_armor_1..4`, `eq_boots_1..4` (the only real inventory ids;
  inventory is data-only this round).
- `silver` clamps at 0 (`maxi(silver + value, 0)`) - every cost below is sized to be a
  real cost at typical early holdings, never a free discount.
- `item` is dedup'd (`not inventory.has(target)`) - no new row offers an item the
  player may already own from another row (each new row uses a distinct item id).
- `practice` is a no-op when everything is mastered - accepted; rows mixing practice
  with other effect types keep the *other* option meaningful.
- `battle_id == null` (reserved stub), unique `id`, non-empty title, 2-3-line Chinese
  text (> 10 chars), both options non-empty labels and non-empty effects arrays.
- **No new randomness anywhere.** Resolution stays in `_apply_event_option`; the draw
  stays one `SaveManager.rng.randi_range` per travel (op-count unchanged vs the 4-row
  pool, so the seeded stream's interleaving with deck draws is preserved).
- **No two rows interchangeable:** the 16 rows between them cover item-with-cost,
  item-vs-item, item-vs-attr, paid-attr-vs-free-attr, attr-A-vs-attr-B (different
  pairs AND different magnitudes), silver-now-vs-growth, growth-vs-money, and the
  moral silver-vs-fortune shape. The four baseline rows are byte-identical.

The 12 new rows, verbatim (lore from `design/20_content.md` and the crossover
setting of `design/00_overview.md`):

```gdscript
{ "id": "tomb_bed", "title": "古墓寒玉",
  "text": "荒山之中藏着一座古墓，\n石室中央横着一张寒玉床。",
  "option_a": {"label": "卧床练气", "effects": [{"type": "attr", "value": 2, "target": "inner"}]},
  "option_b": {"label": "床畔拾剑", "effects": [{"type": "item", "value": 0, "target": "eq_sword_2"}]} },
{ "id": "wounded_eagle", "title": "神雕负伤",
  "text": "一只巨雕伏在崖边，\n翅上箭伤未愈，目光如炬。",
  "option_a": {"label": "施药疗伤", "effects": [{"type": "silver", "value": -8, "target": ""}, {"type": "practice", "value": 2, "target": ""}]},
  "option_b": {"label": "静观其变", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]} },
{ "id": "peach_maze", "title": "桃花迷阵",
  "text": "海岛风送来桃花香，\n花影错落，隐成阵势。",
  "option_a": {"label": "循隙闯阵", "effects": [{"type": "attr", "value": 2, "target": "agility"}]},
  "option_b": {"label": "阵外观潮", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]} },
{ "id": "snake_bile", "title": "蛇胆奇效",
  "text": "白驼山弟子叫卖蛇胆，\n称其大补真元，价钱不菲。",
  "option_a": {"label": "重金购之", "effects": [{"type": "silver", "value": -15, "target": ""}, {"type": "attr", "value": 2, "target": "bone"}]},
  "option_b": {"label": "掉头就走", "effects": [{"type": "attr", "value": 1, "target": "fortune"}]} },
{ "id": "dragon_scrap", "title": "降龙残谱",
  "text": "书摊上一册残破掌谱，\n隐见「降龙」二字，纸色发黄。",
  "option_a": {"label": "强记于心", "effects": [{"type": "practice", "value": 4, "target": ""}]},
  "option_b": {"label": "卖与书贾", "effects": [{"type": "silver", "value": 25, "target": ""}]} },
{ "id": "flood_ferry", "title": "渡口风波",
  "text": "河水暴涨，渡口只余一舟，\n艄公索价甚高，爱搭不理。",
  "option_a": {"label": "付钱渡河", "effects": [{"type": "silver", "value": -10, "target": ""}]},
  "option_b": {"label": "泅水而过", "effects": [{"type": "attr", "value": 1, "target": "inner"}]} },
{ "id": "escort_job", "title": "镖行招募",
  "text": "镖头缺人手，见你身手，\n便邀你押一趟去南边的镖。",
  "option_a": {"label": "接下镖单", "effects": [{"type": "silver", "value": 22, "target": ""}]},
  "option_b": {"label": "婉拒独行", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]} },
{ "id": "dali_market", "title": "大理市集",
  "text": "市集上皮甲快靴俱全，\n掌柜的拍着胸脯称分量十足。",
  "option_a": {"label": "购皮甲", "effects": [{"type": "silver", "value": -18, "target": ""}, {"type": "item", "value": 0, "target": "eq_armor_2"}]},
  "option_b": {"label": "购快靴", "effects": [{"type": "silver", "value": -14, "target": ""}, {"type": "item", "value": 0, "target": "eq_boots_2"}]} },
{ "id": "night_rain", "title": "破庙夜雨",
  "text": "夜雨滂沱，破庙漏得厉害，\n老僧独坐，就着灯火补屋檐。",
  "option_a": {"label": "帮工换宿", "effects": [{"type": "silver", "value": -6, "target": ""}, {"type": "attr", "value": 1, "target": "bone"}]},
  "option_b": {"label": "檐下练剑", "effects": [{"type": "practice", "value": 2, "target": ""}]} },
{ "id": "gambling_den", "title": "赌坊喧嚣",
  "text": "镇上赌坊彻夜喧闹，\n有人一夜输光了全部盘缠。",
  "option_a": {"label": "入局三把", "effects": [{"type": "silver", "value": 30, "target": ""}]},
  "option_b": {"label": "袖手旁观", "effects": [{"type": "attr", "value": 2, "target": "fortune"}]} },
{ "id": "quanzhen_scripture", "title": "全真抄经",
  "text": "全真宫外老道伏案抄经，\n见你驻足，递来一卷道德经。",
  "option_a": {"label": "随他抄经", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
  "option_b": {"label": "求教剑理", "effects": [{"type": "silver", "value": -5, "target": ""}, {"type": "practice", "value": 3, "target": ""}]} },
{ "id": "lost_purse", "title": "遗落的褡裢",
  "text": "路旁褡裢里散着银两，\n四下无人，只有风声掠过草叶。",
  "option_a": {"label": "送还失主", "effects": [{"type": "attr", "value": 2, "target": "fortune"}]},
  "option_b": {"label": "收起走人", "effects": [{"type": "silver", "value": 20, "target": ""}]} },
```

Variety audit (why no two rows are interchangeable): item-with-cost
(`dali_market`), item-vs-item (`dali_market` A/B), item-vs-attr (`tomb_bed`),
practice-with-cost (`wounded_eagle`, `quanzhen_scripture` B), paid-attr-vs-free-attr
(`snake_bile`), attr-2-vs-attr-1 (`peach_maze`, `lost_purse` is attr-2-vs-silver),
growth-vs-money (`dragon_scrap`), pay-vs-swim (`flood_ferry`), silver-now-vs-wisdom
(`escort_job`), silver-vs-bone (`night_rain`), silver-vs-fortune (`gambling_den`).
All five attr targets are used by at least two rows; the three new item grants
(`eq_sword_2`, `eq_armor_2`, `eq_boots_2`) are distinct from each other, from the
baseline `eq_sword_3`, and from every CardData deck draw the player may already hold.

### 3.5 `scripts/segments/cultivation.gd` - verify + observe, do NOT rewrite

**Responsibility:** keep the existing bag semantics; make them observable.

- `_draw_event()` (L424) and `_apply_event_option()` (L438): **logic unchanged**.
  The exclusion (`pool` = TABLE ids not in `events_seen`) and the pool-exhausted
  reset (clear `events_seen`, refill the pool - never an empty draw, never a stall)
  are already correct per direct read. Stale/duplicate ids in `events_seen` from
  hostile saves are harmless to the `has()` filter and already sanitized to
  non-empty Strings by `PlayerProfile.from_dict`.
- `_sync_surface()` (additive): `events_seen_count: int =
    (SaveManager.profile.flags.get("events_seen", []) as Array).size()` - declared as
  a surface var, refreshed wherever `_sync_surface()` already runs. This is the ONE
  code addition in this file.
- **RNG/determinism audit (implementer verifies, design flags it):** the draw stays
  exactly one `randi_range` per travel, so the seeded stream's op order is unchanged;
  the *pool size* changing 4 -> 16 alters which id a given seed picks, which is
  intended. Verify no existing scenario pins a specific `event_id` value or a
  downstream rng-dependent value reached *through* an event draw (grep
  `playtest/*.yaml` for `event_id` and `debug_step_month` paths that travel). If a
  fast-forward path consumes event draws, re-baseline the affected scenario
  explicitly and record it in the Design Changes section - never silently.

### 3.6 `tests/test_event_data.gd` - additive extension

- `ROW_EFFECTS` and `ROW_TITLES` gain the 12 new ids with their verbatim effects
  (the four existing entries byte-identical).
- The size check changes from `all_defs.size() == 4` to `all_defs.size() >= 16`
  (the one permitted modification - the SOTA report explicitly authorizes extending
  the size check rather than deleting assertions).
- ONE new test function `_test_effect_targets` (additive): for every row, every
  effect with `type == "attr"` has `target` in the five attr keys; every effect with
  `type == "item"` has `target` in the 12 real equipment ids; every effect `type` is
  one of the five; no duplicate `item.target` across rows offering items without a
  paired cost; both options' labels non-empty. This pins the dead-content contract
  statically so a future typo'd target fails at unit time, not as a silent no-op.

### 3.7 `tests/test_cultivation.gd` - no-repeat + pool-reset unit tests (additive)

Deterministic, no RNG dependence:

1. **Exclusion + forced draw:** with a stubbed profile whose `events_seen` holds 15
   of the 16 TABLE ids, `_draw_event()` returns exactly the missing id (pool size 1 -
   the single `randi_range` is forced regardless of seed).
2. **Pool-exhausted reset:** with `events_seen` holding all 16 ids, `_draw_event()`
   returns a non-empty id AND `flags["events_seen"]` is empty immediately after the
   draw (the reset branch) - never `""`, never a stall.
3. **Effects really land (A-class for goal 2):** for each of the 16 defs x both
   options, apply `_apply_event_option` against a fresh stubbed profile and assert
   the expected field moved: silver delta (clamped at 0), attr delta,
   `inventory.has(target)`, or the first unmastered gongfa's practice delta. 32
   deterministic cases - this is the proof that no new row is dead content.
   Follow the file's existing instantiation pattern for the segment; if the segment
   cannot be instantiated headlessly from that file's harness, fall back to the
   inline-probe path (below) and record the values in `final/event_probe_notes.md`.

### 3.8 `playtest/portrait_visibility.yaml` - extend IN PLACE (appended asserts only)

The existing 10 asserts stay byte-identical (including the two `sprite_top >= 0.0`
lines - a 92 px margin keeps them true, and duplicate YAML keys would silently drop
asserts, so nothing is rewritten). Appended to the same f40 assert block:

```yaml
    East_Heretic.portrait_fail_layer: portrait_fail_layer == ""
    West_Poison.portrait_fail_layer: portrait_fail_layer == ""
    South_Emperor.portrait_fail_layer: portrait_fail_layer == ""
    North_Beggar.portrait_fail_layer: portrait_fail_layer == ""
    Player.portrait_covered_frac: portrait_covered_frac < 0.25
    Central_Divine.portrait_covered_frac: portrait_covered_frac < 0.25
    East_Heretic.portrait_covered_frac: portrait_covered_frac < 0.25
    West_Poison.portrait_covered_frac: portrait_covered_frac < 0.25
    South_Emperor.portrait_covered_frac: portrait_covered_frac < 0.25
    North_Beggar.portrait_covered_frac: portrait_covered_frac < 0.25
    Player.portrait_tex_size: portrait_tex_size.x > 0.0 and portrait_tex_size.y > 0.0
    Central_Divine.portrait_tex_size: portrait_tex_size.x > 0.0 and portrait_tex_size.y > 0.0
```

Pre-fix, the four `covered_frac` lines for the top-row units and the fail-layer
lines are the A-class reds (with the measured values printed by the harness); the
`portrait_tex_size` lines are the 3-number-probe B-class sanity guards. Post-fix all
green.

### 3.9 `playtest/event_travel_effects.yaml` - NEW scenario (one file, 46 -> 47)

Skeleton (PM calibrates exact frame spacing against the proven
`cultivation_month_cycle_and_deck_bookkeeping.yaml` preamble; all `at:` values are
single integers; every assert value carries a comparison operator):

- Preamble (proven timings, byte-equivalent shape): f3..f15 7x `ui_accept`; f20
  `debug_win_tutorial`; f40/60/70/80 `ui_accept`; f90 `move_right`; f100/110
  `ui_accept`; f130 assert `GameManager.current_state == "CULTIVATION"` and
  `CultivationScreen.phase == "CARD_PICK"` and `CultivationScreen.events_seen_count == 0`.
- Travel 1: `ui_accept` (card 0) -> 3x `move_down` (ACTION_PICK focus 0 -> 3 = 游历) ->
  `ui_accept` -> assert `phase == "EVENT"`, `event_id != ""`,
  `events_seen_count == 0` (drawn, not yet resolved) -> `ui_accept` (option A) ->
  assert `events_seen_count == 1`, `phase == "CARD_PICK"`, `month == 2`.
- Travel 2 and 3: same cycle, asserting `events_seen_count == 2` then `== 3` and
  `event_id != ""` each time. The count ladder IS the no-repeat proof:
  `events_seen` only appends ids it does not already hold, so count == k after k
  travels proves k distinct draws.
- Registration (two-place sync rule): appended to `scenario_order` in
  `playtest/_common.yaml` AND to `ROUND_SCENARIOS` in
  `tests/test_playtest_contract_smoke.py`, in the same order, both at the end.

### 3.10 `playtest/_common.yaml` - surface append (append-only)

- The six unit blocks (`Player`, `East_Heretic`, `West_Poison`, `South_Emperor`,
  `North_Beggar`, `Central_Divine`) each append: `portrait_covered_frac`,
  `portrait_sprite_pos`, `portrait_tex_size`, `portrait_bar_pos`.
- `CultivationScreen` appends: `events_seen_count`.
- `scenario_order` appends `event_travel_effects` (end). `actions:` is unchanged -
  the new scenario uses only already-declared actions.

### 3.11 `tests/test_playtest_contract_smoke.py` - additive contract pin

- `ROUND_SCENARIOS` appends `event_travel_effects` (same order as
  `scenario_order`; existing entries untouched).
- ONE new test function `test_event_content_surface_contract`, asserting statically
  (stdlib only, following the existing regex helpers): the six unit blocks contain
  the four new portrait vars; the `CultivationScreen` block contains
  `events_seen_count`; `event_travel_effects.yaml` exists with `name:` equal to the
  basename, single-integer `at:` values, and a comparison operator in every assert
  value; `portrait_visibility.yaml` contains the `covered_frac` assert lines.

---

## 4. Observable Contract (interface spec - names are exact)

| Node | Var | Type | Meaning | Class |
|---|---|---|---|---|
| all six battle units | `portrait_visible` | bool | all layers pass (existing) | gate |
| all six battle units | `portrait_fail_layer` | String | first failing layer id; `""` when visible; now 8 possible ids | gate |
| all six battle units | `portrait_covered_frac` | float | worst single later-drawn opaque-host cover fraction of the ink rect | gate (`< 0.25`) + probe |
| all six battle units | `portrait_sprite_pos` | Vector2 | Sprite child `global_position` (3-number probe #1) | probe |
| all six battle units | `portrait_tex_size` | Vector2 | Sprite texture size (3-number probe #2) | probe + sanity gate (`> 0`) |
| all six battle units | `portrait_bar_pos` | Vector2 | health-bar `global_position`, `(-1,-1)` sentinel (3-number probe #3) | probe only (never a gate this round) |
| `CultivationScreen` | `events_seen_count` | int | size of the sanitized `events_seen` bag | gate (ladder `== k`) |

Layer id set (order = check order):
`hidden_in_tree`, `null_texture`, `blank_texture` (NEW), `zero_rect`, `off_viewport`,
`clipped`, `occluded`, `covered` (NEW).

Dead-probe invariant (kept from the prior round): `portrait_visible == false` with
`portrait_fail_layer == ""` is a CONTRADICTION (probe dead) - never a pass signal,
never defect evidence.

---

## 5. Event pool content

Specified verbatim in §3.4 (16 rows total: `bandits`, `merchant`, `ruins`, `beggar`
unchanged + the 12 new rows). `EventData.all()` / `EventData.def(id)` /
`_build` / `_build_option` are unchanged - fresh `EventDef`/`EventOption` instances
per call, deep-duplicated effect dictionaries (the existing
`_test_fresh_instances` contract keeps holding).

---

## 6. Edge Cases (from `step1_sota.md`) -> how this design handles them

- **Partial occlusion vs full enclosure:** `covered` (>= 25%, max-single-coverer)
  is checked *after* `occluded` (full enclosure), so the precise id survives and the
  Central Divine case (72% under the strip band) goes RED while a unit merely near
  the bar (0%) stays GREEN. The threshold is above antialias noise (>= 64 px²
  absolute floor) and below any "meaningfully hidden" fraction.
- **Yang Guo resolved by 3 numbers, never pixels:** `portrait_sprite_pos` +
  `portrait_tex_size` + `portrait_bar_pos` are published per frame and recorded in
  the probe notes before any fix; the fix-loci table keys strictly off the measured
  failing layer id. If every layer measures green with consistent geometry, the
  honest disposition is "frame-reading divergence, no fix" - recorded, not guessed.
- **Both units must genuinely go red (A-class), not one:** the probe records both
  units' pre-fix values; the A-class evidence is `portrait_visible == false` with a
  non-empty fail-layer id for each; post-fix all six GREEN with the four healthy
  units guarded. The dead-probe invariant guards against a false pass.
- **Leaf-type assumption:** `leaf_rect()` handles `Control` and `Sprite2D`; if a
  unit's ink leaf is another type, `zero_rect`/`hidden_in_tree` fires and the probe
  notes record the actual node class - extending leaf support only then.
- **Protected code:** `_refresh_sprite_clamp` / `clamp_sprite_offset` change ONLY
  behind a measured `covered` id, as a one-constant margin (92 = the existing strip
  bottom, not a new gameplay number). Click-move / undo / commit / focus / creation
  layout / top-bar / health-bar geometry are untouched.
- **960x704 native frame only:** all visibility evidence is judged on the un-zoomed
  original frame; the raw frame remains the human cross-check, never the gate input.
- **Effect vocabulary is a hard contract:** pinned statically by the new
  `_test_effect_targets` and dynamically by the 32-case effects-land unit test -
  a typo'd target fails loudly instead of silently no-opping.
- **`silver` clamps at 0 / `item` dedups / `practice` no-ops when mastered:** every
  cost is sized to be a real cost; item targets are unique per row; every practice
  option is paired so the row's other option stays meaningful.
- **Pool-exhausted behavior stays defined:** reset + refill -> `event_id != ""`
  always; proven deterministically by the unit tests (forced 1-id pool and the
  all-16 reset branch).
- **RNG/determinism:** no new randomness; one rng op per travel regardless of pool
  size; new rows add no rolls. Existing-scenario dependence on event outcomes is
  audited and any re-baseline is declared in Design Changes.
- **YAML duplicate keys:** appended asserts never repeat an existing
  `Node.var:` key in the same assert block (a duplicate would silently drop one).

---

## 7. Design Changes (declared for `5_design` - design/ is NOT edited this round)

1. `design/30_presentation.md` - the portrait-visibility section's six-layer list
   becomes **eight** layers (`blank_texture` after `null_texture`; `covered` after
   `occluded`), with the 25% / 64 px² threshold and the max-single-coverer
   semantics; note that `TopStrip` (semi-transparent, `mouse_filter = 2`) is
   excluded by the opaque-host convention while its opaque children count.
2. `design/40_ux_backlog.md` - UX-01a / UX-01b move to CLOSED only in the fixing
   commit and only from measured gate evidence (backlog rule 2: closure is an
   action, not an inference). If either unit measures all-green, its disposition is
   recorded from the measurement instead.
3. `design/99_changelog.md` - one row for the round (predicate extension + clamp
   margin + 16-row event pool + the new scenario, 46 -> 47).
4. `design/40_progression.md` §4 - no rule change; the travel-event pool growing
   4 -> 16 is content volume, recorded in the changelog only.
5. If the RNG audit forces a scenario re-baseline, list each re-baselined assert
   here explicitly.

No numbers from `20_content.md` change; no `10_systems.md` rule changes; no
`90_decisions.md` Out-of-scope idea is reintroduced (no hover-based visibility, no
frame-pixel verdicts, no speculative clamp edits without probe evidence, no external
JSON content, no procedural events).

---

## 8. Safety, Baseline Protection, Rollback

- **Baseline protection:** the 45 green scenarios stay green;
  `terminal_victory_8_12_rounds_hp_15_40` stays the only allowed red. The five
  protected click-move scenarios are byte-untouched. No node renames/reparents; no
  `.tscn` or `project.godot` changes at all.
- **No irreversible operations:** everything is additive source/contract edits; no
  data migration, no file deletion, no save-schema change (`events_seen` shape is
  unchanged; old saves with 4-row-era seen lists simply draw from the 16-row pool).
- **Rollback path:** every component is one commit-sized revert (probe extension,
  two var blocks, one clamp constant, one data table, one observable, two test
  files, one extended scenario, one new scenario, one smoke function). Reverting the
  clamp constant alone restores the old sprite layout while leaving the predicate
  and observables valid - the probe evidence survives either way.
- **Probe-first gating:** the 3.3 fix task is blocked until
  `final/portrait_cover_probe_notes.md` exists with per-unit measured values. A fix
  without probe evidence is rejected at review.
- **Delivery hygiene:** new scenario registered in `scenario_order` AND
  `ROUND_SCENARIOS` (same order) and actually run via `godot_playtest_scenario`
  before delivery; all numbers in delivery notes are probe-measured; observables
  classified A (defect-proof, red before fix) vs B (regression guard); unproduced
  gate reports are never claimed as passed.

---

## 9. Suggested Task Decomposition (for PM)

1. **A1 - Predicate extension + observables** (3.1, 3.2, 3.10 surface part): the two
   new layers + `covered_fraction` + the six new vars on both character scripts +
   `_common.yaml` surface append. No behavior change yet.
2. **A2 - Probe run + notes** (3.3 probe task): inline probe, record the per-unit
   table (3 numbers, per-layer verdicts, covered fractions) in
   `final/portrait_cover_probe_notes.md`. Gate for A3.
3. **A3 - Visibility fix** (3.3 fix loci, keyed off A2's measured layer ids) +
   `portrait_visibility.yaml` in-place assert append (3.8).
4. **B1 - Event content** (3.4 + 3.6): 12 new rows + test extensions. Independent of
   A1-A3; can run in parallel.
5. **B2 - Cultivation observables + tests** (3.5 + 3.7): `events_seen_count` +
   no-repeat / pool-reset / effects-land unit tests. Depends on B1's rows.
6. **C1 - Scenario + contract wiring** (3.9, 3.10 order part, 3.11): the new
   `event_travel_effects.yaml`, `scenario_order` + `ROUND_SCENARIOS` + the smoke
   test function. Depends on B2.
7. **C2 - Full gate run + delivery notes**: 47 scenarios, only `terminal_victory`
   red; A/B classification table in the delivery notes.

---

## 10. Out of Scope / Not This Round

- No new effect types, no battle-triggering events (`battle_id` stays null), no
  inventory UI (items remain data-only), no event illustrations or art of any kind.
- No hover/mouse-query visibility checks, no rendered-frame pixel diffing, no
  snapshot comparison gates.
- No balance/number changes (no damage, HP, cooldown, deck-count, or
  difficulty-window edits) - `terminal_victory` stays deliberately red.
- No map/topology changes, no new input actions, no `.tscn`/`project.godot` edits.
- No rewrites of `_draw_event` / `_apply_event_option` / the card-deck machinery.

---

## 11. Tech Stack

Godot 4.4+ (`config/features` records 4.7) + GDScript only; engine-native APIs
(`Rect2.intersection/get_area`, `Control.get_global_rect`, `mouse_filter`,
`CanvasLayer`/`z_index`/tree-order draw comparison, `Texture2D.get_image`). Gates:
the existing godot-builder sidecar (`/compile`, `/playtest`), the static pytest
contract smoke, the GDScript unit suite via `run_tests.sh`, and the vision gate for
the human cross-check on native 960x704 frames. Lint: `.py` -> ruff, `.yaml` /
`.json` / `.md` -> basic (`.gd` deliberately absent - the `gdscript_check` gate owns
it, per the addon guidance).
