# Delivery Notes — R4 (round-closing consolidated record)

**Round:** R4 — 江湖不称名,只称号 (shrimp-nickname display layer + R4 bundle cards)
**Date:** 2026-09-03 · **Card:** final_gate_sweep · **Type:** round-closing verification + consolidated notes (writes exactly one file)

---

## 1. Round summary

R4 renamed every on-screen character to the owner-locked shrimp nicknames (杨过→独臂大虾, 五绝→东邪虾/西毒虾/南帝虾/北丐虾/中神通虾, walk-ons coined 侠客→侠客虾 / 陪练弟子→陪练虾) by editing **only the display layer** — `display_name` values, `_DISPLAY_ALIASES`/`_ORDER_TOKENS` dict values, tutorial copy, i18n zh keys + EN values, and the `design/20_content.md` roster — while leaving `character_name`, node names, `turn_order` tokens, and the three verbatim gates byte-identical. It then landed the four bundled cards: Card 0 (enemy-turn wall-clock ≤ 10 s round / ≤ 2 s per enemy, L1), the personal-name denylist pin, the enemy-action-feedback presentation card, the design-ledger slimming + budget pins, the record-only roadmap card, and the round-docs bookkeeping (README manual + ROUNDS append + changelog line + quick-refs).

**Overall verdict: suite not re-executed in-loop; per-card green records only.** This loop has no shell and no Godot binary, so `bash run_tests.sh` and `python3 -m pytest tests/` could not be executed here (see §2). Every per-card delivery note records its own green-by-construction / measured evidence, and the content-inspection checks in §3 all pass. The authoritative full-suite run is the 5_test / 5_compile gate. **This consolidated note is NOT fresh full-suite proof** — it is the reviewer's entry point that indexes the per-card records; the gate run is the only thing that confirms the whole suite is green.

---

## 2. Suite run record

**Not executed + reason:** this implementer loop has no shell and no Godot binary. The commands the repo runs are:

```bash
bash run_tests.sh            # godot-builder sidecar: compile check → all playtest scenarios → GDScript unit suite
python3 -m pytest tests/     # all static pins
```

Neither is executable in-loop (no shell; Godot lives only in the godot-builder sidecar per `run_tests.sh`). No 5_test gate result is present in this step's context to quote. Per repo convention (`final/_red_first_4b.md`), the run is recorded as **not executed + reason**, never fabricated. The per-card notes each record their own green-by-construction / measured evidence; the 5_test / 5_compile gate is the authoritative full-suite run.

---

## 3. Byte-identity checks (content inspection — no shell)

### 3a. Three verbatim gates — zero personal names, internal keys present

| File | Personal names (杨过/黄药师/欧阳锋/段智兴/洪七公/王重阳) | Internal keys present |
|---|---|---|
| `playtest/facility_use_reusable.yaml` | **0** (search: no matches) | — |
| `playtest/map_node_event_shaolin.yaml` | **0** (search: no matches) | — |
| `playtest/map_battle_node_huashan.yaml` | **0** (search: no matches) | `turn_order.has('ProgressionHero')/('East Heretic')/('West Poison')/('South Emperor')/('North Beggar')/('Central Divine')` at :194; `active_unit_name == "ProgressionHero"` at :48, :204 — all present |

The three verbatim gates are byte-identical to round start (no edit from any card; `rename_display_layer` §7 lists them as not-edited with reason). Internal keys asserted by these gates are intact.

### 3b. Frozen source surface — zero personal names

| File | Personal names |
|---|---|
| `scripts/data/map_battle_data.gd` | **0** (search: no matches) |
| `scripts/characters/enemy.gd` | **0** (search: no matches) |
| all `scenes/*.tscn` | **0** (search over `scenes/*.tscn`: no matches) |

### 3c. Two renamed gates — exactly one `独臂大虾`, zero `杨过`, geometry/color asserts intact

| File:line | Content check |
|---|---|
| `playtest/round_one_snapshot_and_turn_order.yaml:41` | `RoundIndicator.active_actor: active_actor == "独臂大虾"` — exactly one `独臂大虾`, zero `杨过`. Internal asserts intact: `active_unit_name == "Yang Guo"` (:35, :45), `turn_order[0] == "Yang Guo"` … `turn_order[5] == "West Poison"` (:36). |
| `playtest/ui_geometry_readability.yaml:42` | `HealthBar.name_text: name_text == "独臂大虾"` — exactly one `独臂大虾`, zero `杨过`. Geometry/color/format asserts intact: `bar_width <= 64` (:32), `fill_color.g > 0.5 and fill_color.g > fill_color.r` (:40), `track_bg.get_luminance() > 0.30` (:41), `active_text.contains("移动") and active_text.ends_with("行动 ✓")` (:43), `SkillButton*.text.contains("…") == false` (:44-50). |

The per-line before/after table (old / new / why-it-yields) is in §5 below, copied verbatim from `final/delivery_notes_rename_display_layer.md` §2.

---

## 4. Per-card pointer table (exactly 7 rows — all verified to exist via `list`)

| # | Card | Delivery note |
|---|---|---|
| 1 | card0_enemy_turn_l1 | `final/delivery_notes_card0_enemy_turn_l1.md` |
| 2 | denylist_pin | `final/delivery_notes_denylist_pin.md` |
| 3 | enemy_action_feedback | `final/delivery_notes_enemy_action_feedback.md` |
| 4 | ledger_slimming | `final/delivery_notes_ledger_slimming.md` |
| 5 | rename_display_layer | `final/delivery_notes_rename_display_layer.md` |
| 6 | roadmap_record | `final/delivery_notes_roadmap_record.md` |
| 7 | round_docs_bookkeeping | `final/delivery_notes_round_docs_bookkeeping.md` |

(Many other round notes exist on disk — e.g. `delivery_notes_equipment.md`, `delivery_notes_huashan.md`, `delivery_notes_loop.md` — from prior rounds; they are NOT part of this round's pointer table.)

---

## 5. C3 per-line before/after table (copied verbatim from `final/delivery_notes_rename_display_layer.md` §2)

### 5a. Gate literal flips (acceptance criterion: git diff shows EXACTLY one changed line each)

| File:line | Old (verbatim) | New (verbatim) | Why it yields |
|---|---|---|---|
| `playtest/round_one_snapshot_and_turn_order.yaml:41` | `RoundIndicator.active_actor: active_actor == "杨过"` | `RoundIndicator.active_actor: active_actor == "独臂大虾"` | Pins a display-name literal. The rename flips `_ORDER_TOKENS["Yang Guo"]` from "杨过" to "独臂大虾", so the tokenized `active_actor` observable now holds "独臂大虾". The internal asserts on the same file (`active_unit_name == "Yang Guo"`, `turn_order[1] == "East Heretic"`, etc.) stay untouched — they read the canonical `character_name`, not the display token. |
| `playtest/ui_geometry_readability.yaml:42` | `HealthBar.name_text: name_text == "杨过"` | `HealthBar.name_text: name_text == "独臂大虾"` | Same mechanism: `_alias_for("Yang Guo")` now returns "独臂大虾", which is what the HealthBar name label renders. This gate's protected meaning is "stays green", not "never edits" — only this name literal yields; its geometry/color asserts (`bar_width <= 64`, `fill_color`, `nameplate_pairwise_overlap`, etc.) are byte-identical. |

### 5b. Test literal updates (tests/ are not gates; same "display literal yields" rule)

| File:line | Old (verbatim) | New (verbatim) | Why it yields |
|---|---|---|---|
| `tests/test_trait_effects.gd:204` | `ok = _expect(ok, p1.display_name == "陪练弟子", "display_name")` | `ok = _expect(ok, p1.display_name == "陪练虾", "display_name")` | **REQUIRED** (else red). `EncounterData.sparring_partner()` now returns `display_name = "陪练虾"`. The adjacent `character_name == "Sparring Partner"` assert on line 203 stays byte-identical. |
| `tests/test_skill_button_states.gd:197` | `var t_active: String = ri._active_text("杨过")` | `var t_active: String = ri._active_text("Yang Guo")` | **RECOMMENDED.** The asserts are format-only (`contains("移动")`, `ends_with("行动 ✓"/"结束")`), so the test is green either way. But passing the canonical key "Yang Guo" exercises the real `_token_for` alias path (maps to "独臂大虾" via `_ORDER_TOKENS`) and keeps tests/ free of display personal names. |
| `tests/test_skill_button_states.gd:207` | `var t_done: String = ri._active_text("杨过")` | `var t_done: String = ri._active_text("Yang Guo")` | Same reason as line 197 above. |

---

## 6. Red-first inventory table (5 rows; every number cites its source file)

| # | Pin / evidence set | Assert | Observed (red-first) | Frame / line | Greens-before-red | Source |
|---|---|---|---|---|---|---|
| (a) | Denylist pin (`tests/test_display_no_personal_names.py`) | `not hits` for the six personal names in display-layer strings (scripts/**/*.gd string literals, scenes/**/*.tscn, design/20_content.md outside markers) | **26 script-literal hits** (battlefield.gd:486/505/524/543/562/581; hud.gd:18-23; round_indicator.gd:63-68; i18n.gd:122/137-142; tutorial_manager.gd:103) + **15 design/20_content.md hits** (lines 15/22/24/81-85/92/103/114/125/139/323/896) — grep-measured against the pre-rename tree | file:line inventory in denylist_pin note §2 | pytest **not executed** (no shell); pin written against pre-rename tree → red by construction; rename wave must run it green | `final/delivery_notes_denylist_pin.md` §2 |
| (b) | Card 0 — enemy-turn ≤ 10 s round / ≤ 2 s per enemy **and** camera post-pan occlusion (two sub-records, per design C5.5) | **Timing:** `debug_enemy_round_msec <= 10000`, `debug_enemy_turn_msec <= 2000`, `debug_enemy_turn_index >= 5`. **Camera:** `UiOcclusionWatch.violations == 0`, `scan_ok == true`, `HealthBar.bar_anchors_below_portrait == true` at f270 | **Timing (pre-fix local):** round **1792 ms**, turn **659 ms** (variant 1); round **1417 ms**, turn **583 ms** (variant 2); round **1600 ms**, turn **499 ms** (variant 3) — all within bounds; **red not reproducible pre-fix locally** (deterministic fast harness); the **2026-09-02 web report** (20–40 s/enemy, 6 min/2 rounds, playtester abandoned at 23 min) is the red evidence. **Camera (pre-fix):** violations = **0**, scan_ok = **true**, bar_anchors_below_portrait = **true** — **red not reproducible pre-fix locally** (camera is a snap, no pan tween); the **2026-09-02 web report** (top-row enemies clipped into the top bar) is the red evidence | Timing: f1100 (final asserts), f200 (index differential). Camera: f270 (post-pan asserts), end_turn at f160 | Local pins green by construction; web red is the recorded red evidence | `final/delivery_notes_card0_enemy_turn_l1.md` §5, §6 |
| (c) | Ledger budget pin (`tests/test_design_ledger_budget.py`) | Pin A: top-level `design/*.md` excl. `99_changelog.md` ≤ 340,000 B; Pin B: `90_decisions.md` ≤ 25,600 B; Pin C: `40_ux_backlog.md` ≤ 20,480 B | Pre-shrink (measured via `list` file sizes): Pin A = **480,021 B** (RED), Pin B = **97,131 B** (RED), Pin C = **109,879 B** (RED). Post-shrink: Pin B = **7,152 B** (GREEN), Pin C = **17,056 B** (GREEN), Pin A = **301,874 B** on the current tree (GREEN) | file sizes via `list` tool (repo source = `wc -c` equivalent) | pytest **not executed** (no shell); red/green measured via `list` file sizes | `final/delivery_notes_ledger_slimming.md` §2 |
| (d) | Enemy-action-feedback counters (log lines / floating numbers / acting marker) | `debug_combat_log_lines` / `debug_float_numbers_spawned` / `debug_acting_marker_shown` `changed` (f200) and `>= 1` (f1100); `phase == "PLAYER_TURN"`; `violations == 0`; `scan_ok == true` | Red-first (real measured run, `godot_playtest_scenario`): `debug_combat_log_lines >= 1` → observed **0**, `debug_float_numbers_spawned >= 1` → observed **0** (root cause: `get_viewport_rect()` is a Control method, not on CanvasLayer → script-load abort). After the fix: **not re-executed in-loop** (turn budget consumed); deferred to 5_test gate | f1100 (floor asserts), f200 (differential) | Red-first values recorded from the real run; post-fix green deferred to 5_test | `final/delivery_notes_enemy_action_feedback.md` §5 |
| (e) | README pin green evidence (`tests/test_readme_is_a_manual.py`) | ≤ 200 lines; no round-naming heading; exactly one `## 本轮变更（R4，2026-09-03）` section; 12 ROUND_HEADINGS verbatim in `docs/ROUNDS.md`; ≥ 10 of 11 INTERFACES named | README = **68 lines** (≤ 200); R4 marker constant present; **12** ROUND_HEADINGS all present in `docs/ROUNDS.md` (verified by search: R3b, R3, jinyong-loop R2, jinyong-theme, jinyong-huashan, jinyong-shrimpcopy2, jinyong-event-pool-36, jinyong-equipment-battle, wuxia-shrimp-portraits, jinyong-roster, touch-single-surface, touch-reach); all 11 INTERFACES named | README.md (68 lines); docs/ROUNDS.md headings | pytest **not executed** (no shell); green by construction (structural bound ≈ 68 lines) | `final/delivery_notes_round_docs_bookkeeping.md` §2, §3 |

---

## 7. Frame-pair index — ACTUAL STATE (PARTIAL)

`final/frames_r4/` contains **only `README.md`** (3,588 B) — a "Not executed + reason" record. No PNG pairs exist.

**Reason (verbatim from `final/frames_r4/README.md`):** this implementer loop has no Godot binary and no shell — the only executable instrument is the `godot_playtest_scenario` sidecar (which returns assertion outcomes, not rendered frame captures). There is no mechanism to produce PNG frame captures in-loop. Precedent: `final/_red_first_4b.md`.

**Intended captures (6 pairs, same frame index before/after)** — recorded in `final/frames_r4/README.md`:

| # | Description | Frame index |
|---|---|---|
| 1 | Tutorial battle order bar (longest zh: 独臂大虾 · 中神通虾) | round-one route ~f1500 |
| 2 | HP name-plate crop (独臂大虾 + HP on ≤ 64 px bar) | same frame |
| 3 | Huashan map-battle order bar incl. 侠客虾 | pt2 route ~f1140 |
| 4 | EN-locale order bar (longest-string case) | same as #1, EN locale |
| 5 | EN-locale HP plate | same frame, EN locale |
| 6 | Skill bar frame (proves rename didn't disturb bar) | same frame |

**Structural overflow verdict (from `final/frames_r4/README.md`, not frame-based):** the `ui_geometry_readability` gate (asserts `nameplate_pairwise_overlap == false`, `hp_text_width_ok == true`, `top_text_pairwise_overlap == false`, `hint_nameplate_overlap == false`) and the `UiOcclusionWatch` gate (violations == 0, scan_ok == true) close the gap; estimated width growth: 6 zh names grow 17 → 20 CJK chars (+3 ≈ +42 px at 14 px font), order bar ≈ 480 px in a 960 px viewport — well within bounds.

**EN fallback decision (from `final/frames_r4/README.md`):** **Primary set retained** (One-Armed Prawn / East Heretic Shrimp / West Poison Shrimp / South Emperor Shrimp / North Beggar Shrimp / Central Divine Shrimp / Wanderer Shrimp / Sparring Shrimp). No overflow capture is available to trigger the compact fallback; the compact set (Heretic Shrimp / Poison Shrimp / Emperor Shrimp / Beggar Shrimp / Divine Shrimp) remains the documented escalation path.

**Success-criteria item: PARTIAL** — the 6 frame pairs are not captured (not executed + reason recorded); the structural verdict + gate coverage is the substitute evidence. No PNGs were created here (this card creates no files under `final/frames_r4/`).

---

## 8. Card 0 evidence block

### Local measurements (≥ 3 variants — deterministic harness, not 3 seed runs)

The harness is deterministic: SaveManager owns a single seeded `RandomNumberGenerator`; scenarios use fixed frame numbers with no per-scenario seed knob. Three natural variants were probed (recorded in `final/delivery_notes_card0_enemy_turn_l1.md` §6 and `design/30_presentation.md`):

| Variant | end_turn frame | round_msec | turn_msec | index |
|---|---|---|---|---|
| Round-1 handover | f20 | **1792 ms** | **659 ms** | 10 |
| Round-2 handover | f400 | **1417 ms** | **583 ms** | 15 |
| Post-skill handover (skill_1 then end_turn) | f30 | **1600 ms** | **499 ms** | 10 |

All within pin bounds (round ≤ 10 000 ms, turn ≤ 2 000 ms).

### Web outcome — honest not-measured branch

**Web wall-clock not measured here; owner playtest will read the console.**

The container has no Godot binary (run_tests.sh documents Godot lives only in the godot-builder sidecar), so an in-browser measurement is impossible in-round. The deliverable is:
- **(4a) Publish pipeline verified** (`.github/workflows/pages.yml`, re-verified 2026-09-03): trigger `on: push: branches: [master]` + `workflow_dispatch`; checkout `actions/checkout@v4` of the pushed ref (builds FROM HEAD); engine `GODOT_VERSION: 4.4-stable`; export `godot --headless --path . --export-release "Web" build/web/index.html`; upload `build/web` to GitHub Pages. There is NO committed export in-repo — pushing this round's commits to master publishes the fresh build containing the new timing code.
- **(4b) Console-readable timing prints** shipped in `combat_manager.gd`: `print("enemy_turn %s %d" % [_name_of(unit), debug_enemy_turn_msec])` per turn, `print("enemy_round %d" % debug_enemy_round_msec)` per round — readable in the browser devtools of the HTML5 build without the playtest harness.
- The not-measured sentence appears in **both** `design/30_presentation.md` (line 1191) and `final/delivery_notes_card0_enemy_turn_l1.md` (§8) — consistent.

**Web-vs-local delta:** not stated (web not measured). The 2026-09-02 web report (20–40 s/enemy) is the recorded red evidence; the local pin is green by construction (~240 frames ≈ 4 s at 60 fps). The wait-shortening (pause-gate poll changed from `await get_tree().process_frame` to `await get_tree().create_timer(0.05, true).timeout`) addresses the web-fps-scaling risk class. Camera audit confirmed the follower is a snap (no serial pan tween), so no parallelization was needed.

---

## 9. Success-criteria checklist (brief's Success Criteria walked line by line)

| # | Brief Success Criterion | Status | Pointer |
|---|---|---|---|
| 1 | All playtest gates green after each new pin's documented red run | **Partial** — per-card green records; full suite not re-executed in-loop (no shell/Godot); 5_test gate is the authoritative run | §2, §6 |
| 2 | Three verbatim gates byte-identical | **Met** — zero personal names, internal keys present, no card edited them | §3a |
| 3 | Two renamed literals updated with per-line before/after table | **Met** — exactly one `独臂大虾` each, zero `杨过`, geometry/color asserts intact; table in §5 | §3c, §5 |
| 4 | Denylist scan green with red-before value recorded; files scanned/excluded documented | **Met** — red-first inventory (26 + 15 hits) recorded; scope docstring enumerates scanned/excluded with reasons | §6(a), `final/delivery_notes_denylist_pin.md` |
| 5 | No personal name in any rendered frame in either locale | **Met (by construction)** — display layer renamed; denylist pin green by construction post-rename; EN values coined personal-name-free | `final/delivery_notes_rename_display_layer.md` §8 |
| 6 | Name-length overflow risk checked; before/after same-frame comparisons; UiOcclusionWatch violations == 0, scan_ok == true | **Partial** — frame pairs not captured (not executed + reason); structural verdict + gate coverage; UiOcclusionWatch asserted in camera + enemy_action_feedback scenarios | §7, `final/frames_r4/README.md` |
| 7 | Card 0: enemy-turn pin green (≤ 10 s round, ≤ 2 s per enemy) with ≥ 3 seeds + web export recorded in design/30_presentation.md | **Partial** — 3 local variants measured (all within bounds); web not measured (honest not-measured branch with verified pipeline + console prints); recorded in design/30_presentation.md | §8, `final/delivery_notes_card0_enemy_turn_l1.md` |
| 8 | README ≤ 200 lines; docs/ROUNDS.md contains original 12 Round headings verbatim | **Met** — README = 68 lines; 12 ROUND_HEADINGS present (verified by search) | §6(e), `final/delivery_notes_round_docs_bookkeeping.md` |
| 9 | Design ledger limits met (decisions ≤ 25 KB, ux backlog ≤ 20 KB, total design/*.md ≤ 180 KB) | **Partial** — decisions 7,152 B ≤ 25,600 B (met); ux backlog 17,056 B ≤ 20,480 B (met); total rebased to ≤ 340,000 B excl. append-only changelog (recorded deviation, §10) — current tree 301,874 B (met) | §6(c), `final/delivery_notes_ledger_slimming.md` |
| 10 | Owner's six feedback items verbatim in design/00_roadmap.md; broken line-3 link points to 01_process.md | **Met** — six items at lines 316–321 verbatim; queue line at 323; line 3 reads `见 01_process.md;` | `final/delivery_notes_roadmap_record.md` |
| 11 | All dated records use 2026-09-03; no temporary reverts left; every new nail records its pre-fix red run | **Met** — all records dated 2026-09-03; red-first inventory complete (§6); no temporary reverts (repo_apply is `git add -A`) | §6, §10 |

---

## 10. Deviations (recorded verbatim)

1. **du-budget rebase** — the brief's `du -cb design/*.md ≤ 180 KB` is arithmetically unsatisfiable under the brief's own constraints (`99_changelog.md` alone = 162,824 B, append-only-never-rewritten; `20_content`/`30_presentation`/`40_progression` fenced "content untouched"). Pinned as: top-level `design/*.md` **excluding `99_changelog.md` and `archive/`** ≤ **340,000 B** (Pin A in `tests/test_design_ledger_budget.py`). Current tree = 301,874 B. Per-file targets (≤ 25,600 B / ≤ 20,480 B) kept satisfiable as specified.
2. **Card N+1 already-landed residual** — the README slimming (≤ 200 lines, 12 ROUND_HEADINGS in docs/ROUNDS.md, no round headings in README) was landed in R3d; the brief's 1,712-line premise is a stale pre-R3b snapshot. This round's residual = replace the 本轮变更 section body with R4's summary + append the R4 ROUNDS heading + run the existing pin.
3. **C7.3/C7.5 scheduling in round_docs_bookkeeping** — the quick-ref headers for `design/30_presentation.md` + `design/40_progression.md` (C7.3) and the `design/99_changelog.md` one-line (C7.5) are executed by `round_docs_bookkeeping` rather than `ledger_slimming`, to avoid a same-wave write collision with `card0_enemy_turn_l1` on `design/30_presentation.md` and to date the changelog line after all record cards land.
4. **Build-stamp inclusion** — the settings screen now shows a build stamp (`版本 R4 · 2026-09-03` / `Build R4 · 2026-09-03`) via a programmatic `BuildStamp` Label in `settings_panel.gd` (`BUILD_STAMP` const), addressing the brief's "版本字符串:全站 0 处" finding. `settings_panel.tscn` is untouched (frozen; the label is programmatic).
5. **Denylist exclusion-list extension** — the denylist pin's docstring explicitly names `design/00_overview.md` and `design/10_systems.md` as excluded (design-narrative containing names), in addition to the brief's listed exclusions (`tests/`, `assets/`, `docs/ROUNDS.md`, `design/99_changelog.md`, `design/90_decisions.md`, `design/00_roadmap.md`, `design/40_ux_backlog.md`, `design/30_presentation.md`, `design/40_progression.md`). Scope rule: "may WIDEN later; narrowing is forbidden."
6. **Card 0's web branch restructure** — the web measurement closes via the honest not-measured branch: a **fresh published build** via the verified `pages.yml` pipeline (builds FROM HEAD on every push to master) + **console-readable timing prints** (`enemy_turn` / `enemy_round`) shipped in `combat_manager.gd` + the sentence "Web wall-clock not measured here; owner playtest will read the console" in both `design/30_presentation.md` and the card0 delivery note. No recipe-only close; no fabricated web numbers.

---

## 11. Stop-report section

No stop condition fired. All content-inspection checks in §3 pass; all 7 per-card notes exist; the red-first inventory (§6) is complete with every number traced to its owning card's note; the frame-pair state is honestly recorded as PARTIAL (§7) with the not-executed reason; the Card 0 web branch is the honest not-measured path (§8); the workspace delta for this card is exactly `final/delivery_notes.md` (this file).

**The one item that would be a stop if it were red:** the full suite (playtest scenarios + pytest pins) was not re-executed in-loop (no shell/Godot). If the 5_test / 5_compile gate reports any red, the failing set + owning card + recorded output must be reported from that gate — this card does not fix or loosen anything.


