# jinyong — Wuxia Crossover Tactics (Godot 4)

**▶ Play it in your browser: https://linxuhao.github.io/jinyong-heroes/**
(中文/English — auto-detected from your browser language, switchable in 设置/Settings)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. This is a fan-crossover brawler, not
a recreation of any single novel. You create your own nobody, borrow the fully
mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, receive a chance to join a great
sect, spend three in-game years (36 cultivation periods) training, and finally
walk the jianghu map to an ending (`design/00_overview.md`).

Visuals use **placeholder art** (96×128 portraits on 64 px tiles are the frozen
art contract). UI text is Chinese, rendered with the bundled NotoSansSC font
(SIL OFL, see `assets/fonts/LICENSE_OFL.txt`). The project is at roadmap
stage 3 (game content); the board's visibility belongs to a **following
camera**, and sprites only stand on their own tiles.

## Latest round: jinyong-event-pool-36 — a full 36-month journey never repeats an event (2026-08-31)

The travel-event pool was 16 rows, so a player who roamed every month hit the
seen-bag reset on roam #17 and started watching 山道遇劫匪 again — roadmap
completeness item 3 was ❌. This round appends 20 new events (pool = **36**, the
exact journey length: 3 years × 12 months) with zero mechanism changes: same
row shape, the same five effect types, draw logic / `events_seen` semantics /
`battle_id` stub / map node-event channel untouched, and the frozen 16 rows
byte-identical (machine-pinned verbatim by the test mirrors).

**What landed:**

- **20 new events** (`scripts/data/event_data.gd`): 河滩论剑 / 荒寺晚钟 /
  荒村毒井 / 虎啸危崖 / 上元灯会 / 当铺旧刀 / 茶馆说书 / 街角残局 / 铸剑回炉 /
  崖上采药 / 山道花轿 / 荒冢埋剑 / 客栈夜账 / 雁足传书 / 风雪隘口 / 醉汉传拳 /
  河伯娶亲 / 疫村施药 / 登门求教 / 坠马客商 — twenty distinct scenes, no
  reskins. Every row is a real trade-off across different currencies
  (silver ↔ attributes, attributes ↔ practice, immediate vs long-term); no
  option strictly dominates the other, and no row assumes the player has money
  (opening silver is 0; negative amounts clamp to 0, so each row keeps at least
  one option a penniless player still gains from). New prose stays
  species-neutral exactly like the frozen 16 — the unresolved 「一切角色都是虾」
  lore question is recorded as **UX-17 (OPEN, owner decision)** in
  `design/40_ux_backlog.md`, not papered over.
- **Two no-repeat gates**: unit `_test_no_repeat_full_journey`
  (`tests/test_event_data.gd` — runs the real `EventLogic.draw_unseen_id` 36
  times on a fresh profile with a fixed-seed RNG, marks each id seen exactly
  the way the game does, asserts the seen-bag ladder 0→36 never shrinks (no
  mid-journey reset) and all 36 ids are distinct, plus ≥20 non-frozen ids and
  a ≥36-row size floor) and playtest `event_pool_new_event_resolved.yaml`
  (the **78th** scenario — a debug seeder marks every id seen except the
  showcase `cliff_herbs`, so the roam draw is deterministic; the scenario pins
  draw → render (`event_title` / `event_body`) → select → resolve with the
  on-screen `events_seen_count` ladder 35→36 and no pool reset).
- **Observables & plumbing** (append-only): `CultivationScreen.event_title` /
  `event_body` surfaces, the `debug_seed_events_seen` debug action
  (`project.godot` + `playtest/_common.yaml`), and ~80 new zh→en keys in the
  i18n EN dictionary (`tests/test_i18n_coverage.py` untouched; a new
  `_test_i18n_entries` unit gate closes the static guard's blind spot by
  requiring every event title / body / option label to be an EN key).
- **Design archive**: `design/20_content.md` §4 (pool 36 + new-row trade-off
  patterns), `design/00_roadmap.md` completeness item 3 ❌→✅ citing both
  gates, `design/90_decisions.md` (2026-08-31 rulings a–e),
  `design/99_changelog.md` row, `design/40_ux_backlog.md` UX-17 (OPEN,
  record-only).

**Verification status (honest, updated 2026-08-31 after the review round):**
the pool (36 unique ids, frozen 16 verbatim), both gates' code, the seeder,
the i18n entries and all five design-doc updates are verified in the tree by
direct read. The playtest scenario's red-first four values were **measured**
via the temporary-rollback protocol (fail frame **f140** /
`events_seen_count == 35` / observed 16 on the 16-row pool / **2** green
asserts before red — `final/delivery_notes_event_pool_playtest.md`), and the
unit gate's red-first values are structurally derived, not sidecar-measured
(the unit-suite leg was unreachable at implementation time —
`final/delivery_notes_event_pool.md`). The first official gate run then
measured the new scenario **13/15** (f200 `event_title` / `event_body`
observed empty — the two new render surfaces; draw / select / resolve and the
35→36 ladder were green; recorded as **UX-18 OPEN** in
`design/40_ux_backlog.md`). The review blocker was root-caused and **fixed in
the tree**: `_on_accept` ACTION_PICK case 3 published the drawn id without
re-syncing the surfaces, so `cultivation.gd:256` now calls `_sync_surface()`
the moment the roam draw lands, the publication (raw zh, matching the zh
playtest pins) carries a defensive `push_warning` for unknown ids
(:862-866), a unit pin `_test_event_title_body_surface`
(`tests/test_cultivation.gd:314`) guards the publish/clear pair, and the
stale file headers in `event_data.gd` now read 36 rows. **No post-fix
official re-run exists yet** (the sidecar was unreachable at the fix task;
`final/delivery_notes_event_pool_playtest.md` §Measured re-run), so the
**15/15** confirmation, the 78/78 no-regression count, zero compile errors,
the pytest / GDScript unit-suite runs and the vision gate are produced by the
downstream gate steps (`compile_report.json` / `playtest_report.json` /
`test_report.json` / `vision_report.json`) and stay pending that evidence —
see `final/verify_report.json`.

## Round: jinyong-equipment-battle — gear you drew can now be equipped, and it fights (previous round)

The 12 equipment cards (铁剑…长剑 / 布衣…软猬甲 / 草鞋…凌波靴) were inventory
dead ends: drawn, displayed, never equippable. This round gives the profile
three slots (兵刃/护甲/鞋履), a touch-only equip surface on the roster panel,
one tier formula, and feeds equipped gear into real encounters.

**What landed:**

- **Save model** (`scripts/data/player_profile.gd`): `equipped` — a plain
  String-keyed Dictionary `{"weapon","armor","boots"}` (JSON-lossless, same
  hard constraint as every other field). `equip()` validates slot / id-in-
  inventory / category match (an armor id can never enter the weapon slot);
  `unequip_slot()` clears; `from_dict()` coerces defensively and repairs
  equipped ⊆ inventory on load, so **legacy saves without `equipped` load as
  three empty slots — no crash, nothing wiped**. No autosave: equipment is a
  free action, following the cultivation save/load model.
- **One formula, one place** (`scripts/data/equipment_data.gd`): tier parsed
  from the id suffix (`eq_sword_1..4 → 1..4`, malformed ids degrade to 0);
  bonuses are category-keyed constants only — weapon → attack `+2×tier`,
  armor → health `+5×tier`, boots → initiative `+2×tier` plus `+1` move at
  tier ≥ 3. Never 12 hand-written per-item literals. The full derivation is
  archived in `design/40_progression.md` §9 (directions, per-tier steps,
  attribute-equivalent anchors, movement threshold, phase-5 re-tune surface).
- **Gear enters battle** (`scripts/data/battle_setup.gd`): `derive_stats`
  adds the equipment bonuses (empty-equipped output is bit-identical to the
  base formulas — the reversibility baseline), `build_character` mirrors
  `gear_attack/health/initiative/move_bonus` onto the CharacterData, and the
  stale "no live caller yet" header was replaced with the real one
  (`battlefield.gd:651` → `BattleSetup.build_character(SaveManager.profile)`).
  Equip before an encounter and the derived stats differ; unequip and they
  return to baseline.
- **Roster panel goes interactive** (`scripts/ui/roster_panel.gd` +
  `scenes/ui/roster_panel.tscn`): a 装/卸 button pool on the 物品 rows
  (focus_mode 0, clicks-only — no parallel keyboard-cursor list,
  `cursor_markers_visible == false` preserved). Equipping consumes no month,
  no action, no phase; the previous round's read-only guarantee was
  deliberately superseded (the panel now writes exactly one profile surface —
  `equipped` — and nothing else), recorded in the panel header.
- **Contracts & tests**: two new playtest nails (`roster_equip_free_action.yaml`
  free-action + panel-level reversibility; `equipment_in_battle_diff.yaml`
  real event grant → click equip → real encounter → `changed` → unequip →
  baseline), append-only surface observables (RosterPanel equipped_*/equip_*
  counts, Player gear_* bonuses, EquipButton blocks), static contract test +
  `tests/test_roster_equipment_guards.py` (no-autosave scan, focus_mode=0,
  surface appends), three new GDScript unit files (formula matrix, profile
  round-trip/hostile/validation, battle-setup legacy equality + per-slot
  direction + reversibility), i18n entries 「装上/卸下」.

**Verification status (honest, updated 2026-08-31 after the review round):**
implementation, unit-test registration, contract appends, i18n, AND the
design-archive updates are all verified in the tree by direct read
(`40_progression.md` §8 equipped row + §9 formula/derivation;
`90_decisions.md` 2026-08-31 ruling explicitly superseding the 2026-08-30
jinyong-roster ruling (e) with the old text preserved; `99_changelog.md`
append-only row; `30_presentation.md` equipment section). Both review
blockers are resolved in the tree:

- The `tests/test_roster_equipment_guards.py` no-autosave guard now strips
  `#`-comment lines before scanning (the `roster_panel.gd:8` doc-comment
  legitimately names the method; two regression pins cover both directions —
  comment-only lines are inert, a real non-comment call still reds).
- `equipment_in_battle_diff.yaml` was root-caused and REWRITTEN: the MAP
  (huashan) battle reuses the tutorial battlefield (`battle_return_state !=
  "CULTIVATION"` never calls `BattleSetup.build_character(profile)`), so the
  gear diff was unreachable there by ANY frame layout. All three encounter
  legs now run the REAL cultivation-encounter path (`debug_enter_encounter` →
  `battlefield.gd:651`); the item is granted via `debug_grant_equip` →
  `EventLogic.apply_option_effects` (never a bare profile write). Red-first
  four values MEASURED: fail frame **f560** / first failing assert
  **`Player.gear_attack_bonus: gear_attack_bonus > 0`** / exact error
  **`FAIL f560 Player.gear_attack_bonus: gear_attack_bonus > 0 (observed=0)`**
  / **46** green before red; post-restore green **47/47** (2026-08-31 sidecar;
  scenario header RED-FIRST EVIDENCE block +
  `final/delivery_notes_equipment.md`). `roster_equip_free_action` measured
  **36/36** with its own measured red-first (f110 / `equipped_weapon changed
  since frame 0` / exact error in the delivery notes / 35 green before red).

**Official gate evidence (2026-08-31, read by 5_review from the landed step
artifacts): compile 95/95 scripts, 0 errors; playtest 77/77 scenarios PASS,
0 runtime errors, hard gate `passed: true` — including
`equipment_in_battle_diff` 47/47, `roster_equip_free_action` 36/36,
`spine_to_ending` 42/42, `save_load_roundtrip` 14/14 and
`cultivation_changes_combat` 30/30; vision gate passed (all six questions
`failed: false`).** One review-round blocker remained after those runs:
`tests/test_roster_equipment_guards.py::test_no_autosave_guard_strips_comment_lines`
expected `"var y = 1"` while the comment-stripping helper preserves the code
line's trailing newline. Fixed test-side exactly as prescribed (the assertion
now reads `assert result_mixed.strip() == "var y = 1"`; the helper and the
other four guards are unchanged; no game code, scenario or threshold
touched). Its official 44/44 pytest re-run and the GDScript unit-suite
re-run are produced by the downstream `test_report.json` (5_test), so that
one criterion stays pending that artifact — everything above is green on
landed evidence. UX-16 is CLOSED on the 47/47 gate evidence
(`design/40_ux_backlog.md`).

## Round: wuxia-shrimp-portraits — every character is now a shrimp (武虾, 2026-08-31)

The 2026-08-28 world ruling (`design/90_decisions.md`) — **all characters are
shrimp** — is now visible on screen: the six 96×128 character portraits were
swapped from human ink-wash martial artists to non-human shrimp bodies
(cartoon head + semi-realistic body). The PNGs are round INPUTS (never
generated, drawn, or rewritten by the pipeline); this round aligned every
record with them and re-measured the pinned portrait geometry.

**What landed:**

- **Roster complete** (`assets/characters/roster.json`): the four
  「待定虾种」 filled by owner ruling — east_heretic 樱花虾(正樱虾) /
  south_emperor 罗氏沼虾 / central_divine 玻璃虾 / yang_guo 枪虾 (one giant
  claw, the other side empty — 独臂) — and all six `art_status` flipped to
  `completed`. west_poison (皮皮虾) / north_beggar (龙虾) were already set and
  untouched; `yang_guo`'s title/note untouched (de-naming is a separate
  round → UX-15).
- **Two-layer seed manifest** (`assets/seed_manifest.json`): flat table →
  `subjects` (6 locked identities: id/name/species/appearance — **no seeds: a
  seed identifies an image, not a person**) + `images` (6 derived:
  subject + scene + path) + the 9 non-character asset records preserved.
  `style_block` is the split-register sentence that produced these six
  images (head fully cartoon / body semi-realistic).
- **Geometry re-measured, all green on the new art** (observed values in
  `final/delivery_notes_wuxia.md` §3; raw runs in
  `final/portrait_geometry_remeasure_notes.md` and
  `final/portrait_alpha_bbox_notes.md`): `portrait_grid_alignment` **30/30**
  — all 24 ink lines `ink_world_dx/dy = 0.0` at f40 and f820; six-unit
  eight-layer visibility `portrait_visible = true`, `portrait_fail_layer = ""`,
  `portrait_covered_frac = 0.0`; `camera_transform_follows_unit` **9/9**;
  `spine_to_ending` **42/42, 0 runtime errors**. Frozen scenarios run
  unmodified; no threshold loosened; no yaml/script/PNG edit.
- **Pixel-true footing check**, independent of the texture-rect pin: alpha
  bbox of all six PNGs — `bottom_gap = 0` (ink touches the bottom row;
  the transparent-bottom-padding blind spot does not exist in this set),
  h_center_offset 0 / −0.5, `east_heretic` top = 3 recorded as a deviation,
  not "fixed".
- **Texture-rect blind-spot finding**: `portrait_ink_rect` / `ink_world_dx/dy`
  derive from the 96×128 texture rect + the constant foot anchor
  `(0, −tex.y/2)`, not from alpha pixels — all-green proves foot-anchoring,
  not ink footing; this round's alpha-bbox check covers the gap. (Full record
  → `design/30_presentation.md`, landed by the 5_design step.)
- **Recipe archived**: how these six images were made — species table, exact
  style sentence, contamination words that pull shrimp into humanoid form,
  age/gender expression, asymmetry-as-positive, composition→post-process
  (bottom-align + horizontal-centre), remove_bg + border flood-fill hole
  repair — all in `final/delivery_notes_wuxia.md` §1, the verbatim archive of
  the transitional `WUXIA_ART_HANDOFF.md` (whose deletion is documented there:
  blocked by a step required-output guard; safe to delete by a step with
  authority).

**Status (honest, 2026-08-31): measured this round, verdict pending
downstream gates.** The geometry numbers above are real harness self-run
values, but the OFFICIAL evidence is produced after verification:
`5_compile`/`5_test` (compile 0 errors, all scenarios green, hard gate
passed, GDScript unit suite, pytest guards incl.
`tests/test_shrimp_roster.py`), `5_vision` (frame support for the
per-portrait descriptions — the delivery notes mark them
unverified-this-round), and `5_design` (the design-doc updates:
30_presentation style sync + art-direction record + 重画流程→已执行,
90_decisions species rulings, 40_ux_backlog UX-15, 99_changelog row,
roadmap item 5 ❌→✅, and the `WUXIA_ART_HANDOFF.md` deletion). Do not treat
this round as GREEN until those land.

## Round: jinyong-roster — the roster panel: what you own, finally visible (taps only) (previous round)

Everything the profile already stored but nothing ever rendered — five
attributes, silver, innate traits, current year/month and sect, every learned
gongfa (grade / practice / mastered), and every inventory item resolved to its
Chinese name — is now one tap away.

**What landed:**

- **`RosterOpenButton`「角色」** (top-right, `focus_mode = 0`) in BOTH stable
  segments — `scenes/segments/cultivation.tscn` and `scenes/segments/map.tscn`
  each instance `scenes/ui/roster_panel.tscn` as a node named `RosterPanel`.
  `scripts/ui/roster_panel.gd` reads `SaveManager.profile` and writes nothing:
  open/close never autosave, never consume a month or action, never touch a
  phase (each host's `_unhandled_input` gates on `RosterPanel.is_open`).
- **The panel** is a centered read-only box over a tap-outside dim layer:
  「人物」 (根骨/内力/身法/悟性/福缘, 银两, 先天特质, 第 N 年 N 月, 门派),
  「功法」 (per art: name, grade, 练度 practice/cap from
  `ProgressionGongfaData.PRACTICE_TO_MASTER`, 大成 marker), and 「物品」 (each
  `profile.inventory` id through the frozen `CardData.display_name_of`; an
  unknown id degrades lazily to the raw id — never a crash, never a
  `push_error`; empty sections render 「（无）」). Close via the 「关闭」
  button or by tapping outside. The panel has zero internal selectables, so it
  publishes `cursor_markers_visible == false` exactly like every segment.
- **Contract (append-only)**: four `Roster*` surface blocks in
  `playtest/_common.yaml`; two new scenarios at the `scenario_order` tail
  (73 → **75**) mirrored in `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS`;
  GDScript unit pins in `tests/test_roster_panel.gd` (compose purity, item
  name resolution, unknown-id degradation, honest empty states, read-only
  `to_dict()` invariance); every new string in the `scripts/autoload/i18n.gd`
  EN dictionary.
- **The correspondence nail, MEASURED red-first** (TEMPORARY RED-FIRST REVERT
  applied to `roster_panel.gd open()`, direct sidecar run, restored
  byte-identical): failing frame **f70**, first failing assert
  **`RosterPanel.is_open: is_open == true`**, exact error
  **`FAIL f70 RosterPanel.is_open: is_open == true` / `observed=false`**,
  **8** green asserts before red. The nail drives the REAL grant path (map
  `merchant` event → `EventLogic.apply_option_effects` → `eq_sword_3`
  青锋剑) and then clicks the panel open and asserts 「青锋剑」 inside
  `RosterBodyLabel.text`.
- **Design record**: `design/30_presentation.md` (roster panel section),
  `design/90_decisions.md` (seven rulings a–g), `design/40_ux_backlog.md`
  (UX-13 no-`equipped` field / UX-14 §9 loadout promise vs auto-equip — both
  OPEN, record-only), and the `design/99_changelog.md` `roster_panel` row.

**Status (updated 2026-08-31): the review blockers are fixed and both new
scenarios self-run green on the current tree** (sidecar runs, see
"Verification status (honest)" below): `roster_panel_item_nail` **36/36
PASS** — the f110 silver differential was resolved by funding silver BEFORE
the merchant event with the whitelisted `debug_grant_silver` action (frame
f35; grants 32 = 4 × max facility cost through
`EventLogic.apply_option_effects`, never a bare profile write, so merchant
`option_a` −20 leaves 12 and the frame-0-baseline `changed` holds).
`roster_panel_cultivation_open_close` **16/16 PASS, hard gate
`passed: true`, 0 runtime errors** — the month advance is now a real
clicks-only month (CultOptionButton0 card pick → CultOptionButton2 做工 →
`_after_action` calendar advance; the `debug_step_month` token was gated on
`GameManager.current_state`, which a direct scene boot never sets), and the
6 direct-boot runtime errors are eliminated by a
`save_manager.gd::_ensure_deck` deck-boot guard
(`if not decks.has(cat): _init_decks()`). Both scenarios' red-first evidence
is MEASURED (never predicted) — the nail's four values are in the bullet
above; the cultivation scenario's measured four values are **f50** /
**`RosterPanel.is_open: is_open == true`** / **`observed=false`** /
**4** green asserts before red. No official post-fix 75-scenario gate run
exists yet; the 75 in the counts below is the `scenario_order` registry
count, not a gate-measured green count.

## Round: touch-single-surface — buttons are the option list, every state has a tappable exit (previous round)

The touch-reach round gave every screen a button; player feedback (2026-08-30)
then showed the screens were *doubled*: the same option list rendered twice (a
`▶` cursor text row in `BodyLabel` **and** an identical row of buttons), and
one state had a button count of zero — `GONGFA_PICK` with no unmastered art
hid its whole button box, leaving Enter (`_on_accept`'s empty branch) as the
only exit. On a phone there is no Enter.

**What landed (keyboard branches byte-identical; clicks delegate to the same
handlers; no art assets; `focus_mode = FOCUS_NONE` kept):**

- **One surface, one rendering** — `cultivation.gd` / `map.gd` /
  `sect_select.gd` no longer print option rows (or the `▶` cursor) into
  `BodyLabel`; the button pool is the only option list. Descriptive text
  (event title/prose, facility cost summary, the map overview node list, stats
  header, sect info lines) is untouched. Selection lives **on the button**: the
  focused row is full-bright `modulate`, the rest dimmed (the creation.gd
  precedent) — arrow keys still move the focus var and the highlight follows
  (`map.gd:483/:494/:505/:510`, `sect_select.gd:84`, `cultivation.gd`
  `_rebuild_options_box`). `creation.gd` was already single-surface (parity
  check only). The transition screen's 「继续 ▶」 glyph stays: it lives inside
  the button's own text — one surface, no duplication (recorded in
  `design/90_decisions.md`).
- **GONGFA_PICK empty-list exit** — with no unmastered art the box builds one
  「返回行动」 button (`cultivation.gd:572-576`) whose press walks the SAME
  `_on_option_pressed → _on_accept` chain every other option uses (the existing
  empty branch `:235-238` returns to `ACTION_PICK`; no forked phase logic).
  The on-screen hint states the way out (「暂无未大成武功。点击「返回行动」
  回到本月行动。」), and the self-justifying comment at the old
  `cultivation.gd:529` is rewritten to describe the actual guarantee: every
  player-choice phase leaves the box with ≥ 1 visible, wired button.
- **New observables** (`playtest/_common.yaml` surface, only-add):
  `cursor_markers_visible` (false ⇒ no `▶` anywhere in the rendered body) on
  cultivation / map / sect_select, plus `option_focus` /
  `focused_option_text` on cultivation.
- **The clicks-only nail** — `playtest/clicks_only_gongfa_empty_exit.yaml`
  seeds a fresh no-sect save (the one sanctioned debug seed), loads it by
  CLICKING the menu's 读取存档 entry, then clicks-only through card → 练功 →
  the empty `GONGFA_PICK` (exactly one 返回行动 button, wired, no `▶`),
  clicks it, and asserts `CultivationScreen.phase == "ACTION_PICK"` — the
  phase really changed; a merely-present button would not satisfy it.
  Registered two places (`_common.yaml::scenario_order` tail +
  `ROUND_SCENARIOS` tail) with a new keyboard-free smoke pin; keyboard twin
  `gongfa_pick_empty_keyboard_return.yaml` pins the Enter path of the same fix.
- **Property-based coverage gate** — `tests/test_touch_option_surface_gate.gd`
  (SceneTree script; auto-discovered by `run_tests.sh`'s sidecar scan) drives
  the cultivation / map / sect_select phase machines through their OWN handlers
  and asserts every reached player-choice phase produced ≥ 1 visible, wired
  control and no `▶` marker — not a literal phase-name list. A future phase
  with zero buttons reds the gate with a self-explaining message; the EXEMPT
  table (no-input states only, with its rule text) lives inside the gate.
- **Copy guard maintained, not dodged** (round-owner-granted scope):
  `tests/test_facility_copy_location.py` now detects `tr()` call-site keys
  structurally (`_tr_call_literals`), the map-chrome ALLOWED entries are
  emptied, and the shortened map copy keys land in the same commit as their
  slot-matched `i18n.gd` EN values. No wording was chosen for its CJK count.
- **Design archive**: new `design/31_touch_coverage.md` (every segment × phase
  with file:line — every touch-only exit Y; defensive unreachable zero-button
  branches recorded, not treated as dead-ends); rule (g) in
  `design/30_presentation.md`; the round's rulings in
  `design/90_decisions.md`; the `design/99_changelog.md` row; the
  `design/40_ux_backlog.md` record (UX-11 / UX-12 stay OPEN, nothing newly
  deferred).
- **Tails corrections** (carried over card): the Q6 clause below now carries
  the measured values (good_answers 71 / bad_answers 0 — nothing parked), and
  `final/delivery_notes_touch_reach_walkthrough.md` points at
  `final/delivery_notes_touch_reach_red_first.md` for the authoritative
  measured first-red values while keeping the f180/5 prediction as the
  prediction-vs-measurement record.

**The visibly-fixed dead end:** enter 养成 → tap 练功 with no trainable art →
【练功】 shows one 返回行动 button → tap it once → back at 本月行动 → keep
playing. Zero keyboard.

## Round: touch-reach — the whole storyline is playable with taps only (previous round)

A real player (2026-08-29) hit a wall at the end of the tutorial: 「玩完需要回车继续，
但是我在手机上没有回车」. Investigation showed it was not one missing button — the
main storyline was **pointer-dead from the tutorial-end screen onward**. The
tutorial-end overlay is built in code (`GameManager._show_end_game_overlay`:
CanvasLayer + dim + Panel + Label, zero Buttons), and the five later segment
scenes (`transition` / `sect_select` / `cultivation` / `map` / `ending`) were
`Backdrop + Label` with zero Buttons. This stayed invisible to a 69/69-green
playtest contract because `actions:` key injection (`Input.parse_input_event`)
feeds `_input` directly and **bypasses GUI hit-testing** — a screen with zero
clickable controls still passes a key-driven scenario (same root as the recorded
SegmentHost full-rect swallow). This round closes both halves of that: the
missing controls, and the observation gap that hid them.

**What landed (additive only — every keyboard branch byte-identical; every new
button delegates to the same handler the key shortcut calls; no `*_ClickTarget`
anchors; no art assets; `focus_mode = FOCUS_NONE` everywhere so no double-fire):**

- **Tutorial-end overlay** (`scripts/autoload/game_manager.gd`): the code-built
  overlay now also builds `Panel/ContinueButton` and `Panel/RetryButton`
  (`pressed → request_continue` / `request_retry`, per-state visibility, synced
  in both the construction and the re-show branch). The prompt copy now
  describes a real, tappable action — 「胜利！华山论剑的胜者！点击「继续」进入江湖」 /
  「战败于华山论剑 点击「重试」再战」 — with the call-site literals and the
  `i18n.gd` EN-dictionary keys changed together (the old 「按回车…」 keys were
  used nowhere else).
- **transition**: `NextButton` → `_advance()` · **sect_select**: `SectButton0..4`
  → `focus_index` + `_pick()` · **cultivation**: an `OptionsBox` whose
  `CultOptionButton{i}` pool is rebuilt each render to mirror the current
  phase's options → set the phase's focus var + `_on_accept()` (one handler,
  two triggers; month advancement / gongfa / attr / event logic untouched) ·
  **map**: `TravelButton{i}` → `focus_id` + `_travel()`, `EventOptionButton0/1`
  → `event_focus` + `_resolve_node_event()`, and three **facility delegate
  buttons** `FacilityEnterButton` / `FacilityUseButton` / `FacilityLeaveButton`
  → the existing `_enter_facility()` / `_use_facility()` / `_leave_facility()`
  (delegation only — facility semantics, the F-key gate and the data modules
  are byte-untouched, per the two-outcome protocol in `design/90_decisions.md`) ·
  **ending**: `RestartButton` → `restart_game()`.
- **New surface observables**: `GameManager.end_overlay_pressed_connected`
  (both overlay buttons' wiring, refreshed in both branches) and
  `pressed_connected` on all five previously button-less segment screens —
  the click gate proves hittability for the buttons the route reaches;
  `pressed_connected` proves wiring for **every** button (e.g. `RetryButton`,
  which no WON run clicks).
- **The nail**: `playtest/clicks_only_storyline.yaml` walks the whole storyline
  — menu → creation → tutorial battle → **tutorial-end overlay** → transition →
  sect select → 36-month cultivation → map → events → ending → restart — with
  `clicks:` only (true GUI hit-testing; a screen without a hittable control is
  a hard red, never a silent skip). It contains **zero keyboard actions**: every
  timeline `actions:` entry is empty except one `debug_win_tutorial` battle
  outcome seed (an unbound DEBUG action consumed in `_process`, the same seed
  the keyboard spine uses; adjudicated in `design/90_decisions.md` (a)). The
  battle screen's own clickability is separately proven by
  `battle_end_turn_attack_buttons` / `click_targeting_fixed` /
  `undo_button_retreat` / `click_portrait_body_targets_enemy` plus an in-scenario
  real click on `AttackButton`.
- **Companion scenario**: `playtest/map_facility_buttons_click.yaml` proves the
  three facility delegate buttons by clicks while `facility_use_reusable.yaml`
  stays byte-untouched.
- **The clicks-only path paid for itself twice**: aligning it to screen-ready
  timing re-projected every `at:` frame and grew the tutorial-intro leg to 7
  `Next` clicks (`TutorialManager.STEP_COUNT == 7`), and it exposed a real game
  bug the keyboard path never hits — `cultivation.gd`'s `_rebuild_options_box()`
  called `free()` on the button mid-emission of its own `pressed` signal
  ("Attempted to free a locked object"; measured 21/47 red). Fixed minimally
  with `queue_free()` (no month-advance/phase logic change; seven related
  scenarios re-measured green, `spine_to_ending` 42/42 among them).
- **Contract guards** (append-only): both new scenarios appended to
  `playtest/_common.yaml::scenario_order` **and** `ROUND_SCENARIOS` in
  `tests/test_playtest_contract_smoke.py` (two-place sync); surface whitelist
  grew by the twelve new button blocks + the six `pressed_connected` vars; two
  new smoke pins — `test_clicks_only_storyline_is_keyboard_free` (any keyboard
  action in the clicks-only file is a hard red; self-explaining failure message)
  and `test_touch_reach_surface_contract` (the new observables cannot be
  silently deleted). The stale `*_ClickTarget` example in `_common.yaml`'s
  clicks-grammar docs was corrected to a unit-body anchor.
- **Red-first record (measured)**: the nail is authored to first go red at the
  tutorial-end overlay (`ContinueButton` did not exist pre-fix) — and it DID,
  measured: with the documented TEMPORARY RED-FIRST REVERT applied to
  `game_manager.gd`, a real direct harness invocation
  (`godot_playtest_scenario(scenario="clicks_only_storyline")`) ran
  **RED 8/47** — failing frame **265**, first failing assert
  **`ContinueButton.visible`**, exact error **`aim: node not found:
  ContinueButton (spec: ContinueButton)`**, green asserts before red **8**;
  after the byte-identical restore it re-ran **47/47 green**. Values live in
  `final/delivery_notes_touch_reach_red_first.md`, the scenario header and
  `design/00_roadmap.md` / `90_decisions.md`; the earlier f180/5 numbers were
  the structural prediction and are superseded (same screen, same first
  assert).
- **Measurement-only debts** (`design/40_ux_backlog.md`, no gates):
  **UX-11** — touch-target sizes of every storyline control at the 960×704
  design resolution (measure and record the smallest few; Material 48 dp /
  HIG 44 pt / WCAG 2.5.8 24 px as references only; no size threshold);
  **UX-12** — residual keyboard-only hint copy with re-verified line numbers
  (`i18n.gd` :350/:354/:359/:364/:369/:378/:380/:122-123, scene literals
  `transition.tscn:50` / `sect_select.tscn:49` / `cultivation.tscn:47` /
  `ending.tscn:48`, `sect_select.gd:75`) — every one of those screens *now has*
  a control; only the copy still names the keyboard route.
- **Docs-first archive**: `design/30_presentation.md` new pointer-reachability
  section (incl. the observation conclusion: key injection cannot see this
  defect class, `clicks:` can); `design/00_roadmap.md` Phase 2 update;
  `design/90_decisions.md` rulings (a)–(e); `design/99_changelog.md` row
  dated 2026-08-29.

### The storyline, tapped screen by screen

Recorded in `final/delivery_notes_touch_reach_walkthrough.md` (≈90 clicks,
zero keyboard):

| Screen | What was tapped |
|---|---|
| 主菜单 | `MenuEntry0` (新的冒险) |
| 捏人 · 属性/特质/确认 | `AttrNextButton` → `TraitNextButton` → `ConfirmButton` |
| 教程战 · 开场页 | `Next` ×7 |
| 教程战 · 战斗 | `AttackButton` (one real click; outcome seeded with `debug_win_tutorial` — see above) |
| 教程结算 overlay | `ContinueButton` ← **the first-red screen** |
| 过场 | `NextButton` ×2 |
| 拜师 | `SectButton0` (少林) |
| 养成 · 36 个月 | each month `CultOptionButton0` (选卡/年初培元/岁末留门) + `CultOptionButton2` (做工 → the month advances through the existing path); year-boundary extra clicks; checkpoints at y1m1 / y2m1 / y3m1 |
| 大地图 | `TravelButton0/1…` per leg (无名谷→洛阳→武当→襄阳→昆仑), `EventOptionButton0` at each entry event |
| 结局 | `RestartButton` → back to the tutorial, storyline closed by taps alone |

## Previous rounds

- **jinyong-facility** — the third map-node content type: `FacilityData.TABLE`
  (2 rows, closed effect domain, §433 single prose source), shaolin/wudang
  facility slots `declared → active`, opt-in `FACILITY` phase (F key in TRAVEL,
  never auto-fires on arrival — pinned by the permanent negative assertion in
  `facility_use_reusable.yaml`, red-then-green measured 34/47 → 49/49), effects
  via the shared `EventLogic.apply_option_effects`, plus the
  `test_facility_use_reusable_surface_contract` anti-deletion pin and the
  `test_facility_copy_location.py` §433 guard.
- Earlier: **camera-owns-visibility** (following camera owns visibility, clamp
  deleted, canvas-transform click mapping, portrait-grid alignment),
  **interaction-defects** (floating-bar STOP filter, feet-tile undo, real-input
  coverage, touch undo, nameplate/ground marker, 5-step click priority, trait
  hover preview), **jinyong-nodes** (five main story nodes get content),
  **jinyong-map-events** (node entry-content + shared `EventLogic` + map EVENT
  phase), **jinyong-spend-qi** (real inner-qi costs), **jinyong-clarity**
  (creation-screen information layer), **jinyong-hud** (battle-HUD information
  layer), **jinyong-events** (event pool 4 → 16 rows), plus the owner's
  hand-added 华山 battle node. All recorded in `design/99_changelog.md`.

## Requirements

- Godot 4.x. No external dependencies, no build step.

## Install

```bash
git clone <this repo> jinyong && cd jinyong
# open project.godot in the Godot 4 editor (import happens automatically)
```

## Run

Open the project in the Godot 4 editor and press Play — the game boots into
the main menu (新的冒险 / 读取存档 / 设置 / 退出). Headless:

```bash
godot --path .
```

Flow: main menu → character creation (fixed 30-point budget: five attributes
with live effect explanations and current HP; 13 innate trait/flaw toggles
whose descriptions preview on hover; a confirm page listing the final values)
→ tutorial battle as a fully mastered Yang Guo vs the Five Masters (you are
meant to win) → tutorial-end overlay → transition → sect choice → 36-month
cultivation → the jianghu map → tiered ending → restart. **The whole storyline
is now playable with pointer/touch alone — every screen has a visible, tappable
control** (main menu buttons; creation's plus/minus/toggle/nav buttons; the
HUD's attack/end-turn/undo buttons; the overlay's 继续/重试; transition's 继续 ▶;
the sect list; cultivation's option pool; the map's travel/event/facility
buttons; the ending's 重新开始). The keyboard paths are unchanged and sit
alongside: in battle the **camera follows the acting unit** and keeps it in the
unobstructed band between the top bar and the action bar — left-click a
highlighted empty tile to move, left-click an enemy (its own tile **or** the
drawn portrait body of an enemy in reach) to attack, right-click **or the HUD
「退回」 button** to retreat to the turn-start tile until you act (acting locks
the move), 结束回合 to end the turn; each unit's nameplate rides at its portrait
head and a gold ground marker marks the occupied tile; casting a move spends
its inner-qi cost (内力: N in the top strip; a too-expensive move greys into
「内力不足」; the free basic 重剑无锋 always stays available). On the map,
左右/上下 cycle the adjacent nodes and 回车 travels (or tap `TravelButton{i}`);
every mainline stop opens its node event on arrival (洛阳 行商路过 / 武当 全真抄经 /
襄阳 降龙残谱; 无名谷 fires on the return trip; 少林 off the 洛阳 branch fires
破庙夜雨) — resolve with 上下选择，回车定夺 or by tapping the option buttons.
**At 少林 and 武当 (the two sect nodes), press F — or tap the 进入设施 button — to
enter the sect facility** (木人巷 / 紫霄静修): 回车 or the facility button uses it
once (pays silver, gains an attribute — reusable as long as you can pay),
上下/离开 leaves. The travel hint shows a `门派设施：…（F 使用）` line when a
facility is available at the current node. Entering 昆仑 routes straight to the
tiered ending (end-node routing runs before entry content, so nothing can block
it), and events fire only on travel — never on boot or load, so save/load
roundtrips don't re-trigger.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check → headless playtest of all scenarios → GDScript unit
suite). It fails loudly when the sidecar is unreachable — the code then ships
unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (superset pin, copy-location guard with tr() call-site detection, keyboard-free pins incl. the gongfa empty-exit nail, touch surface contracts)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite (28 files)
godot --headless --path . -s res://tests/test_touch_option_surface_gate.gd  # property-based touch-coverage gate (traverses the cultivation/map/sect_select phase machines)
godot --headless --path . -s res://tests/test_game_manager_fsm.gd  # SceneTree-style suites
```

## Key interfaces

- **Touch-single-surface controls & observables** (2026-08-30 round): buttons
  are the sole option surface in cultivation / map / sect_select — selection is
  the button's own `modulate` (bright focused / dim rest), arrow keys move the
  focus var the highlight follows; `GONGFA_PICK` with an empty unmastered list
  offers the single `CultOptionButton0` 「返回行动」 → the same
  `_on_accept` empty branch → `ACTION_PICK`; observables
  `cursor_markers_visible` (cultivation / map / sect_select), `option_focus` /
  `focused_option_text` (cultivation); scenarios
  `clicks_only_gongfa_empty_exit.yaml` (clicks-only, phase-diff nail) +
  `gongfa_pick_empty_keyboard_return.yaml` (keyboard twin); coverage gate
  `tests/test_touch_option_surface_gate.gd` (traverses the phase machines).
- **Touch-reach controls & observables** (touch-reach round): overlay
  `Panel/ContinueButton` / `Panel/RetryButton` in
  `GameManager._show_end_game_overlay` (delegates to `request_continue` /
  `request_retry`; keyboard branch byte-identical) with the
  `GameManager.end_overlay_pressed_connected` observable; segment buttons
  `NextButton` (transition), `SectButton0..4` (sect_select),
  `CultOptionButton{i}` (cultivation, dynamic per-phase pool in `OptionsBox`),
  `TravelButton{i}` / `EventOptionButton0/1` / `FacilityEnterButton` /
  `FacilityUseButton` / `FacilityLeaveButton` (map), `RestartButton` (ending) —
  each with `pressed_connected` published on its screen; every button is
  `focus_mode = FOCUS_NONE` and delegates to the same handler its keyboard
  shortcut calls.
- **Equipment system** (jinyong-equipment-battle round): `PlayerProfile.equipped`
  (three String-keyed slots) with `equipped_id(slot)` / `equip(slot, id)` /
  `unequip_slot(slot)` — `equip` returns `false` unless the id is in
  `inventory` and its category matches the slot; `scripts/data/equipment_data.gd`
  (pure statics `slot_of` / `tier_of` / `bonuses_for` / `sum_bonuses`, five
  category constants, defensive tier parse); `BattleSetup.derive_stats`
  consumes `sum_bonuses(profile.get("equipped"))` so an empty/legacy profile
  is bit-identical to the base formulas; `CharacterData.gear_*_bonus` mirrors
  expose the bonuses to battle; RosterPanel publishes
  `equipped_weapon/armor/boots`, `equip_button_count`,
  `equip_pressed_connected` and drives the 装/卸 pool
  (`EquipButton{i}`, `focus_mode = 0`); playtest surface: those RosterPanel
  observables + `Player.gear_attack_bonus/gear_health_bonus/
  gear_initiative_bonus/gear_move_bonus` in `playtest/_common.yaml`.
- **Camera ownership** (`scripts/camera_follower.gd`, attached to the
  `Camera` node of `main.tscn` / `menu.tscn`): follows
  `CombatManager.get_active_unit()` during `STATE_BATTLE`, clamps to the
  no-blank range derived from `GridManager.board_rect()` + viewport + HUD
  rects, and publishes the playtest surface `Camera.camera_position`,
  `camera_x_lo/hi`, `camera_y_lo/hi`, `hud_band_top/bottom`,
  `active_unit_screen_y`, `active_unit_world_y`, `viewport_half_y`,
  `follow_target_id`, `follow_target_is_active`.
- **Coordinate mapping** (`scripts/coord.gd`, `class_name Coord`): pure
  statics `world_to_screen(world, viewport)` / `screen_to_world(screen,
  viewport)` over the **canvas** transform (the one that contains the
  camera). The health-bar follow and the follower's published screen y both
  go through it; click entries already map through
  `get_canvas_transform().affine_inverse()`.
- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`, `get_enemies_alive()`, the end-game overlay +
  `end_overlay_pressed_connected`), `CombatManager` (battle state:
  `tutorial_battle`, `current_round`, `phase`, `is_player_turn()`,
  `get_active_unit()`, the qi spend path `spend_unit_energy(unit, cost)` +
  the `debug_spend_player_qi()` drain fixture), `GridManager` (grid /
  movement planning, `world_to_grid` / `grid_to_world` / **`board_rect()`**),
  `SaveManager` (profile, slots, `rng`, autosave), `InputGate` (real-input
  gate — inert unless the env var `AITELIER_INPUT_GATE_REPORT` is set).
  `SceneManager` must stay the LAST autoload entry (compile ordering).
- **Alignment observables** (`player.gd` / `enemy.gd`): `portrait_ink_rect`,
  `ink_world_dx` / `ink_world_dy`, `camera_offset_y`, `sprite_top`,
  `portrait_sprite_pos` / `portrait_tex_size` / `portrait_bar_pos` /
  `health_bar_screen_y` / `health_bar_world_y`, plus the input-differential
  counters (`debug_input_events`, `debug_click_events`,
  `debug_right_input_events`, `debug_undo_events`, `debug_gui_eater`,
  `Enemy.debug_click_target_fires`).
- **Battle click priority**: `Player.resolve_click_step(...) -> int` and
  `Player.attack_reach_covers(...) -> bool` — pure statics implementing the
  5-step rule (own-tile enemy → attack; in-reach body → attack; reachable
  empty tile → move; out-of-reach body → select/no-op; own tile no-op),
  unit-pinned by `tests/test_click_priority.gd` against the unclamped
  geometry.
- **Floating health bar** (`scripts/ui/health_bar.gd`,
  `scenes/ui/health_bar.tscn`): follows its unit through
  `Coord.world_to_screen`; above-portrait anchor with a flip below the ink
  bottom for top-band units; every node in the subtree is
  `mouse_filter = IGNORE` so it can never eat a board click. Observables:
  `bar_width/height/top/bottom`, `hp_text`, `hp_value`, `hp_max`,
  `hp_text_width_ok`, `empty_area_px`, `empty_cap_px`.
- **Ground markers** (`scripts/ui/tile_markers.gd`): click-inert Node2D
  overlay painting one ellipse per living unit; observables
  `tile_marker_count` / `tile_marker_visible`.
- **Creation / map / events / qi costs / facility**: `creation.gd` (`phase`,
  `points_left`, `attrs`, `trait_ids`, `trait_index`, `trait_hover_index`,
  `hp_value`/`hp_text`, `confirm_summary_text`, `pressed_connected`);
  `MapData.NODES` entry-content + `active_event_id` / `active_battle_id` /
  `active_facility_id` / `declared_gap_types`, `MapScreen` EVENT + FACILITY
  phase + `pressed_connected`; `EventLogic` pure statics over
  `EventData.TABLE` (36 rows — 16 frozen + 20 added 2026-08-31;
  `draw_unseen_id` draws unseen ids and only resets when the pool is
  exhausted, so a 36-month all-roam journey never resets); `FacilityData.TABLE` (2 rows) +
  `silver_cost()` / `for_node()` / `def(id)`; `SkillData.cost` /
  `insufficient_energy` / `spend` with `Player.energy` / `energy_max`.
- **i18n** (`scripts/autoload/i18n.gd`): the EN dictionary is the copy
  contract — the overlay keys are the exact call-site literals
  (`胜利！华山论剑的胜者！\n\n点击「继续」进入江湖` / `战败于华山论剑\n\n点击「重试」再战`)
  and every new button label (重试 / 重新开始 / 进入设施 / 离开) is keyed;
  `tests/test_i18n_coverage.py` keeps lookups honest.
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections and
  `use_facility` / `debug_grant_silver` / `debug_grant_equip` /
  `debug_seed_events_seen`), the
  observable-surface whitelist
  (incl. the twelve new touch-reach button blocks and the six
  `pressed_connected` vars) and `scenario_order`; each `playtest/*.yaml` is
  one scenario (name == basename, single-integer `at:`, a comparison operator
  or changed/unchanged token on every assert line). `clicks:` entries are
  `<Node>[ +dx,dy][ left|right|middle]` — a **true GUI hit test** (aim at the
  control/unit body, never a `*_ClickTarget`); `hovers:` are motion-only.
  78 scenarios, including the keyboard spine `spine_to_ending.yaml`, the
  clicks-only storyline spine `clicks_only_storyline.yaml`, the facility
  click companion `map_facility_buttons_click.yaml`, and the no-repeat
  proof `event_pool_new_event_resolved.yaml` (a NEW travel event drawn,
  rendered, selected and resolved on screen).
- **Unit tests**: GDScript files with a top-level `static func run() -> bool`
  are collected by `tests/unit_test_runner.gd`'s explicit append-only `TESTS`
  registry (28 files), run headless. SceneTree-extending integration suites
  (`test_game_manager_fsm.gd` — extended this round with the overlay-button
  wiring pins — and friends) are driven with their own `-s` invocation. The
  pytest smoke (`tests/test_playtest_contract_smoke.py`) statically pins the
  scenario contract, the two-place sync, the "assertions only added" rule,
  the facility anti-deletion pin, the **keyboard-free pin** and the
  **touch-reach surface contract**. `tests/test_facility_copy_location.py`
  guards the §433 copy-location rule.

## Verification status (honest)

**jinyong-roster (this round, 2026-08-30; blockers fixed + both red-firsts
measured 2026-08-31) — delivery verified by direct read; both new scenarios
self-run green on the current tree; downstream gates pending:**

- **Landed and verified in the tree**: `scripts/ui/roster_panel.gd` +
  `scenes/ui/roster_panel.tscn` instanced as `RosterPanel` into BOTH segment
  scenes; host input gates (`cultivation.gd:149-150`, `map.gd:112-119`); the
  four `Roster*` surface blocks; `scenario_order` 73→75 + `ROUND_SCENARIOS`
  two-place sync; the i18n roster block (`i18n.gd:474-487`);
  `tests/test_roster_panel.gd` registered in the unit-suite registry; the
  facility anti-delete pin's FORM-gate failure message
  (`test_playtest_contract_smoke.py:1078-1086`, additive only); the five
  design-doc updates (30 / 40_ux_backlog UX-13+UX-14 / 90 / 99). MEASURED nail
  red-first: f70 / `RosterPanel.is_open: is_open == true` /
  `FAIL f70 RosterPanel.is_open: is_open == true` + `observed=false` /
  red-before-green **8** (scenario header RED-FIRST EVIDENCE block +
  `final/delivery_notes_roster.md` §1). `design/99_changelog.md` row :126
  re-verified to hold the measured touch_single_surface values verbatim
  (f140 / `CultOptionButton0.visible: visible == true` /
  `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)` /
  red-before-green 9) — no third correction row (append-only archive
  honored).
- **Fixed and self-run green (2026-08-31 sidecar runs, per
  `final/delivery_notes_roster.md` §2/§9/§10)**: the 2026-08-30 baseline reds
  (`roster_panel_item_nail` 35/36 at f110 `MapScreen.silver: changed`;
  `roster_panel_cultivation_open_close` 15/16 at f110
  `CultivationScreen.month: changed` plus 6 `save_manager.gd:365/:382`
  deck-table runtime errors) are all resolved on the tree:
  (1) `save_manager.gd::_ensure_deck` now boots the six decks on demand
  (`if not decks.has(cat): _init_decks()`) — a direct scene boot no longer
  indexes an uninitialized deck table; (2) the nail funds silver at f35 via
  the whitelisted `debug_grant_silver` action (32 = 4 × max facility cost,
  routed through `EventLogic.apply_option_effects` — never a bare profile
  write), so `silver: changed` is satisfiable; (3) the cultivation scenario's
  month advance is a real clicks-only month (CultOptionButton0 card pick →
  CultOptionButton2 做工 → `_after_action` advances the calendar), phase-gated
  and not state-gated. Measured self-run results on the fixed tree:
  `roster_panel_item_nail` **36/36 PASS** (青锋剑 pin green at f130),
  `roster_panel_cultivation_open_close` **16/16 PASS, hard gate
  `passed: true`, 0 runtime errors**. The cultivation scenario's RED-FIRST
  block is now MEASURED (no placeholder remains): fail frame **50** / first
  assertion **`RosterPanel.is_open: is_open == true`** / exact error
  **`observed=false`** / red-before-green **4** (TEMPORARY RED-FIRST REVERT on
  `roster_panel.gd open()`, direct sidecar run, restored byte-identical).
- **Pending downstream evidence (not producible at verification time — not
  guessed, counted as unmet)**: compile 0 errors; GDScript unit suite green;
  `tests/test_i18n_coverage.py` / `tests/test_playtest_contract_smoke.py` /
  `tests/test_facility_copy_location.py` green; the vision gate;
  `spine_to_ending` timing. Their reports (`compile_report.json`,
  `vision_report.json`, `test_report.json`) are pipeline artifacts produced
  after this step. No official POST-FIX 75-scenario playtest gate run exists
  yet — the registry count (75) is not a gate-measured green count; the
  latest OFFICIAL gate run (2026-08-30, pre-fix) measured 73/75 with the two
  scenario defects, and the 2026-08-31 fixes are evidenced by direct sidecar
  self-runs (36/36 and 16/16, 0 runtime errors) until the downstream gate
  re-run lands the official 75/75 count.

**touch-single-surface (previous round, 2026-08-30) — fully evidenced (red-first
MEASURED post-review + official gate run):**

- **Direct-read verified in the tree**: the single-surface renders (`▶` option
  rows deleted from the cultivation / map / sect_select bodies; selection on
  the button via `modulate`; keyboard focus vars and `_unhandled_input`
  branches byte-identical), the `GONGFA_PICK` empty-exit button + rewritten
  hint + rewritten comment (`cultivation.gd:542-550`), the new observables in
  the `_common.yaml` surface (only-add), the two new scenarios + two-place
  registration + the keyboard-free smoke pin, the traversal-based coverage
  gate (SceneTree script; `run_tests.sh` discovers every `extends SceneTree`
  script by property — no list edit needed), the maintained copy-location
  guard (`_tr_call_literals` detection, ALLOWED emptied, anti-triviality floor
  re-based, the two symbol exclusions untouched), the design-archive rows
  (30 (g) / 31 new / 40 / 90 / 99), and the tails corrections (README Q6
  measured 71/0; walkthrough pointer line with the f180/5 prediction
  preserved).
- **MEASURED first-red values landed (2026-08-30, after the review round)**:
  the `godot_playtest_scenario` sidecar was invoked with the TEMPORARY
  RED-FIRST REVERT applied to `scripts/segments/cultivation.gd` and the nail
  went RED as the brief requires — failing frame **f140**, first failing
  assert **`CultOptionButton0.visible: visible == true`**, exact error
  **`aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`**,
  **9** green asserts before red (f80 6 + f110 2 + the f140
  `phase == "GONGFA_PICK"` assert, which passes even with the revert). The
  earlier structural prediction (8 green before red) is preserved verbatim in
  the scenario header, explicitly marked superseded by the measured run. The
  revert was restored byte-identically (zero `TEMPORARY RED-FIRST REVERT`
  hits in `scripts/`) and both new scenarios re-ran GREEN on the restored
  tree: `clicks_only_gongfa_empty_exit` **16/16**,
  `gongfa_pick_empty_keyboard_return` **13/13** (hard gate `passed: true`).
  All values live in the scenario header's RED-FIRST EVIDENCE block and in
  `final/delivery_notes_touch_single_surface.md` (Part A §4/§5 + Part B §4/§5) —
  the `implementer.md:23` self-run hard condition is MET.
- **Downstream gates measured (read by `5_review` from the gate artifacts)**:
  compile **89/89** scripts, 0 errors; playtest **73/73** scenarios PASS, 0
  runtime errors, hard gate `passed: true` (including
  `clicks_only_gongfa_empty_exit` 16/16, `gongfa_pick_empty_keyboard_return`
  13/13, `spine_to_ending` 42/42, `clicks_only_storyline` 47/47,
  `facility_use_reusable` 49/49); vision gate **passed** (non-blind, 73
  scenarios / 292 frames, all six questions `failed: false`, Q6 text
  readability 73 good / 0 bad); GDScript unit suite **38/38** green
  (including the traversal coverage gate `tests/test_touch_option_surface_gate.gd`
  and the two re-targeted map unit tests); `tests/test_i18n_coverage.py` +
  `tests/test_playtest_contract_smoke.py` + `tests/test_facility_copy_location.py`
  green.

The rest of this section describes the previous (touch-reach) round.

The only authoritative gate evidence is the pipeline step products —
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` — pipeline artifacts, not repo files. The touch-reach
round's official full-suite run has executed (2026-08-30); its measured
results are transcribed into the design archive (`design/00_roadmap.md`,
`design/40_ux_backlog.md`, `design/30_presentation.md`) and were relayed by
`5_review`. In short:

- **Direct-read verified this round (touch-reach)**: the overlay buttons +
  re-show branch + `end_overlay_pressed_connected` in `game_manager.gd`; the
  five segment scenes' new buttons + `OptionsBox` + facility delegate buttons;
  `pressed_connected` on all six segment scripts; the two-sided copy edit
  (`game_manager.gd:203/:208` ↔ `i18n.gd:104/:105`) plus the new label keys;
  `clicks_only_storyline.yaml` (zero keyboard actions; single
  `debug_win_tutorial` seed) and `map_facility_buttons_click.yaml`; the
  two-place sync (`_common.yaml::scenario_order` tail + `ROUND_SCENARIOS`
  tail); the two new smoke pins; the extended `test_game_manager_fsm.gd`
  overlay pins; the design-archive records (30/40/00/90/99).
- **Red-first status (measured)**: the first-red and the post-fix green are now
  MEASURED — via direct per-scenario invocation of the same external sidecar
  the gate drives (not via the `5_compile` gate): RED 8/47 at f265
  (`ContinueButton.visible`, exact error `aim: node not found: ContinueButton
  (spec: ContinueButton)`, 8 green asserts before red) with the documented
  temporary revert applied, then GREEN 47/47 after the byte-identical restore;
  a second parse-clean measured run (frame-timing re-projection plus the
  `cultivation.gd` `free()` → `queue_free()` fix) re-measured the nail 47/47
  green with seven regression probes green (`spine_to_ending` 42/42,
  `map_facility_buttons_click` 38/38, `facility_use_reusable` 49/49, plus four
  cultivation/sect scenarios). The earlier f180/5 numbers were the structural
  prediction (superseded).
- **Official full-suite gate run (2026-08-30) — MEASURED**, transcribed into
  `design/00_roadmap.md` / `design/40_ux_backlog.md` /
  `design/30_presentation.md` (e) and relayed by `5_review`: playtest
  **71/71 scenarios PASS** (hard gate `passed: true`, `spec_used: true`,
  **0 runtime errors**) — incl. `clicks_only_storyline` **47/47** (zero
  keyboard actions), `map_facility_buttons_click` **38/38**, the keyboard-path
  proof `spine_to_ending` **42/42** (byte-untouched, still fully green),
  `facility_use_reusable` **49/49**, `tutorial_win_routes_to_transition`
  **8/8**, `tutorial_loss_restarts_tutorial` **5/5**; compile **88/88**
  scripts, zero errors; vision gate **passed** (non-blind, 71 scenarios /
  284 frames, all six questions `failed: false`; Q6 text-truncation question
  measured good_answers 71 / bad_answers 0 — no Q6 bad answers that round,
  nothing parked); the pytest smoke
  ran **31/32** in `5_review`'s pass — the single failure was a test-side
  false positive on a comment line, root-caused and fixed after that run
  (bullet below).
- **Gate runs for this round**: `design/99_changelog.md`'s
  `record_parse_lesson_and_reconcile` row records that the round's `5_compile`
  run measured `Parse failed — play-test skipped` (`spec_used: false`,
  `frames: 0`): a parse error in a new `tests/*.gd` file reds Godot's
  project-wide parse check, the playtest is skipped entirely, and the hard gate
  still reads `passed: true` with zero frames. That lesson is closed by the
  official parse-clean full run above (`spec_used: true`, 71/71 PASS).
- **Smoke-gate hardening (post-gate fix, 2026-08-30,
  `final/delivery_notes_fix_at_gate_strip_comments.md`)**:
  `tests/test_playtest_contract_smoke.py::test_timeline_at_values_are_integers`
  false-reded on a `#` comment — `clicks_only_storyline.yaml:99` carries a
  backtick-wrapped `` `at:` `` in prose and the old regex matched comments
  too, capturing the backtick and failing `isdigit()`. Root cause fixed in
  the TEST (the scenario file stays byte-identical): a pure
  `_bad_timeline_at_values()` helper now strips each line's `#` comment
  before applying the original regex + `isdigit()` check, the docstring's
  false "word-boundary-guarded, so `at` inside prose never matches" claim was
  deleted, and two regression pins were added — a real non-integer `at:`
  value still reds, and the exact backtick-in-comment case is inert. Net
  effect: two tests added, the gate property preserved (only comments are
  excluded from matching), no scenario or threshold touched.
- If the downstream playtest gate reddens any scenario, that is reported with
  its cause, never papered over: no assertion is removed or relaxed, no
  frozen yaml is edited to route around a defect, and thresholds are never
  loosened — numbers come from constants or fresh measurement only.

## Repository layout

- `scripts/` — game code: `autoload/` (GameManager incl. the end-game overlay
  buttons, CombatManager, GridManager, SaveManager, InputGate,
  SceneManager-last, …), `camera_follower.gd`, `coord.gd`, `characters/`
  (`player.gd`, `enemy.gd`), `data/` (map/event/facility data,
  `event_logic.gd`, `facility_data.gd`, player_profile, …), `ui/` (HUD,
  health_bar.gd, tile_markers.gd, input_census.gd, highlights, visibility
  probe), `segments/` (creation / cultivation / **map** / **transition** /
  **sect_select** / **ending**, all with tappable controls), `ai/`,
  `battlefield.gd`
- `scenes/` — Godot scenes: `ui/` (hud, health_bar), `segments/`
  (creation, map, transition, sect_select, cultivation, ending),
  `battlefield.tscn`, `main.tscn` / `menu.tscn`
- `playtest/` — 78 headless playtest scenarios + the `_common.yaml` contract
  (79 yaml files); incl. the clicks-only storyline spine and the facility
  click companion; frozen yamls are append-only (authorized edits stay
  machine-pinned by the superset fixture)
- `tests/` — GDScript unit suites (28 files in the TESTS registry),
  SceneTree-style integration suites (incl. `test_game_manager_fsm.gd` with
  the overlay-button pins), `test_playtest_contract_smoke.py` (incl. the
  keyboard-free pin + touch-reach surface contract),
  `test_facility_copy_location.py`, and the frozen
  `fixtures/playtest_assert_superset.json` baseline
- `design/` — the design archive (`00_overview.md` … `99_changelog.md`);
  this round's records: `30_presentation.md` pointer-reachability section,
  `40_ux_backlog.md` UX-11/UX-12 measurement debts, `00_roadmap.md` Phase 2
  update, `90_decisions.md` touch-reach rulings (a)–(e), `99_changelog.md`
  touch-reach row (2026-08-29)
- `final/` — per-round delivery notes and probe notes (this round's
  red-first evidence: `final/delivery_notes_touch_reach_red_first.md`;
  the taps-only walkthrough:
  `final/delivery_notes_touch_reach_walkthrough.md`; the facility round's
  red-then-green record: `final/delivery_notes_facility.md`; the
  event-pool round's gate evidence:
  `final/delivery_notes_event_pool.md` +
  `final/delivery_notes_event_pool_playtest.md`)
- `assets/` — placeholder textures, seed portraits, NotoSansSC font, audio
