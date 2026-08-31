# 技术架构设计 — 武虾立绘:六图换装记录对齐 + 立绘几何重证 (wuxia-shrimp-portraits)

> Round date: **2026-08-31** (use exactly this date in every record this round: changelog row, decision sections, backlog entry, delivery notes, roadmap flip).

## 0. 概述

The six shrimp PNGs are **already in the repo** (committed by the driver before this round) — they are this round's **input**, never its output. Nobody may generate, draw, replace, or "fix" `assets/characters/*.png`; the only permitted interaction is *reading their pixels* to measure ink. This round therefore has exactly three kinds of work:

1. **Records catch up with the art (data + docs).** `roster.json` gets the four owner-ruled species and all six `art_status` flipped; `seed_manifest.json` becomes the two-layer subject/image structure with the new split-register style sentence; the design archive (`30_presentation` / `90_decisions` / `40_ux_backlog` / `99_changelog`) records the art-direction change, the executed 定妆 process, the species rulings, and the de-naming backlog item.
2. **Geometry is re-proven, not assumed.** The new PNGs have different ink silhouettes than the old human figures, and every pinned nail is built on ink. All three nails (`portrait_grid_alignment`, `portrait_visibility` six-unit values, `camera_transform_follows_unit`) are **re-measured with observed values**, plus a pixel-true alpha-bbox footing check per PNG (the texture-rect blind-spot measurement), plus a full gate run. Red nails are reported with root cause — thresholds are never loosened, nails never edited, art never redrawn to fit.
3. **The recipe is archived and the transitional file deleted.** `WUXIA_ART_HANDOFF.md`'s content lands verbatim in `final/delivery_notes_wuxia.md` (archive → verify → delete, in that order), and roadmap completeness item 5 flips ❌→✅ in `5_design` backed by gate evidence.

**Shape of this round:** zero engine-code changes, zero `playtest/*.yaml` changes, zero surface-whitelist changes, zero new UI strings, four guard tests byte-identical. The only code-adjacent artifact is a *transitional* pytest probe (written, run, deleted — never committed, see C7-M2).

## 1. 现状锚点 (verified facts this design is built on — do not re-investigate)

- **PNGs:** six files under `./assets/characters/` (`west_poison / north_beggar / east_heretic / south_emperor / central_divine / yang_guo`), all **96×128 RGBA (colortype 6)**. Filenames unchanged.
- **Guard semantics (`./tests/test_shrimp_roster.py`, read in full):** three tests — PNG stems ↔ roster keys one-to-one both directions, and `title`/`species` non-empty strings per row. It does **not** check `art_status`, does not judge shrimp-ness, and must stay byte-identical. Any non-empty species string passes; `art_status: "completed"` is therefore free.
- **`seed_manifest.json` has no code readers.** Repo-wide search: referenced only from `WUXIA_ART_HANDOFF.md`, `design/30_presentation.md`, `design/99_changelog.md` (prose). Restructuring it is a docs-layer change with zero runtime/compile impact.
- **Roster current state:** `west_poison` / `north_beggar` rows complete (species + `art_status: "pending"`); four rows carry `species: "待定虾种"`; `yang_guo` row carries `title: "待定称号(去名化)"` and the de-naming `note`.
- **Style sentence source of truth:** `WUXIA_ART_HANDOFF.md` §二 (exact English sentence, display-wrapped over 5 lines). The 30_presentation 画风 section currently carries the OLD sentence `Chinese wuxia ink-painting style, flat colors, clean bold outlines, dramatic lighting`.
- **Geometry observables are published and whitelisted:** `portrait_ink_rect`, `ink_world_dx`, `ink_world_dy`, `camera_offset_y`, `sprite_top`, `portrait_tex_size`, `portrait_visible`, `portrait_fail_layer`, `portrait_covered_frac` are on the per-unit blocks of `./playtest/_common.yaml`'s surface whitelist (append-only — names persist; verify by grep before the probe run, never delete). `portrait_ink_rect` is **texture-rect derived** (`player.gd:469` / `enemy.gd:328`; `ink_world_dx/dy` published strictly from it at `player.gd` L502-503 / `enemy.gd` L355-356 — provenance anchors: `.aitelier/knowledge.md` jinyong-camera (2026-08-29) entry, and `README.md` "Alignment observables" section).
- **Measurement precedents:** probe-contradiction inline YAML via `godot_playtest_scenario` (`final/portrait_probe_notes.md`, `final/portrait_cover_probe_notes.md`); gate runs go through the godot-builder sidecar (`run_tests.sh` POSTs `/compile` `/playtest` `/script`; there is no local godot binary).
- **Known art defects to carry verbatim into the report** (handoff §四): `yang_guo`'s giant claw renders smaller than the cast-design image; `central_divine`'s Taoist crest reads helmet-like and the body is extremely pale (low contrast); `east_heretic`'s antenna tips touch the top edge (bbox top == 0 is *expected*); overall cuteness level is the user-pinned direction (2026-08-31 reference images), not a drift.

## 2. 架构图(数据流)

```
INPUTS (read-only)                      WORK                                   OUTPUTS
------------------                      ----                                   -------
WUXIA_ART_HANDOFF.md ──§一/§二/§三..六──→ C1 roster.json (species+art_status) ─→ tests/test_shrimp_roster.py GREEN
                     ──§二 exact sentence→ C2 seed_manifest.json two-layer ──→ (no code readers; docs sync target)
                     ──§一..§六 verbatim ─→ C8 final/delivery_notes_wuxia.md ──→ THEN delete WUXIA_ART_HANDOFF.md
assets/characters/*.png (6, read-only)─→ C7-M1 godot_playtest_scenario       ─→ observed ink_world_dx/dy, portrait_visible/fail_layer, camera pass counts
                                      ─→ C7-M2 temp pytest alpha-bbox probe  ─→ per-PNG footing values (probe file deleted after capture)
                                      ─→ C7-M3 full gate (sidecar)           ─→ compile 0 errors / all scenarios / spine_to_ending / unit suite
C1+C2 observed values ─────────────────→ C3..C6 design/ archive (5_design)   ─→ 30/90/40_ux_backlog/99 updated, roadmap item 5 ✅
```

Ordering invariant: **nothing in `design/` needs to exist before measurement** (M1/M2 are read-only against the PNGs and engine). The final gate run (M3) must execute on the tree that already contains C1+C2, so the measured tree is the delivered tree.

## 3. 组件列表

### C1 — Roster completion — `./assets/characters/roster.json`
- **职责:** fill the four 「待定虾种」 with the owner rulings (verbatim, no rewording), flip all six `art_status` from `"pending"` to `"completed"`.
- **接口/契约:** JSON shape unchanged (`_why` array + `characters` map of `{title, species, art_status, note?}`). The two already-written rows (`west_poison`, `north_beggar`) stay **byte-identical except `art_status`**. `yang_guo`'s `title` and `note` stay byte-identical (de-naming is a separate round → C5). Validation: `python -m pytest tests/test_shrimp_roster.py` green; `json.loads` parses.
- **Exact values to write** (format follows the roster's established `<species> — <reason>` prose):
  - `east_heretic.species` = `"樱花虾(正樱虾) — 深海群游、绯红半透,聚散如落英,对桃花岛"`
  - `south_emperor.species` = `"罗氏沼虾 — 南方淡水巨虾,一对细长蓝螯,对大理段皇爷"`
  - `central_divine.species` = `"玻璃虾 — 通体透明、内里一览无余,对先天功"`
  - `yang_guo.species` = `"枪虾 — 一只螯极大而另一侧空缺(独臂),与虾虎鱼结伴共生(神雕)"`
  - all six rows: `"art_status": "completed"`

### C2 — Manifest restructure — `./assets/seed_manifest.json`
- **职责:** convert the flat table into the two-layer structure that `design/30_presentation.md` §重画的流程 already mandates, and swap `style_block` to the sentence that actually produced these six images.
- **接口/契约:** top-level shape:
  ```json
  {
    "_why": [ "...two-layer rationale, seeds are not identity..." ],
    "style_block": "<S — exact string below>",
    "subjects": [ { "id": "...", "name": "...", "species": "...", "appearance": "..." } × 6 ],
    "images":  [ { "subject": "...", "scene": "...", "path": "res://assets/characters/<id>.png", "transparent": true } × 6 ],
    "assets":  [ ...the 9 non-character records (terrain floor/border, backdrop summit, 6 audio) byte-unchanged... ]
  }
  ```
- **The style sentence S (canonical, single physical line):**
  `Chinese wuxia game-art illustration with a deliberate SPLIT REGISTER: the head is fully cartoon (rounded simplified head-carapace, large expressive eyes with clear highlights, appealing, never scary); the body is semi-realistic (overlapping carapace plates, distinct segment joints, ridges and spines, clear directional light, soft shadow, glossy shell sheen)`
  - **Normalization rule (pin this):** the handoff §二 wraps S across 5 display lines; the canonical value joins those lines with **single spaces**, no other change. Store S in `style_block` as ONE JSON string, and in `design/30_presentation.md`'s 画风 blockquote as ONE physical markdown line (no internal newline — a wrapped blockquote would break byte-identity). Byte-exact equality between the two files is an acceptance criterion.
- **Identity fields:**
  - `subjects[].id` = the six roster/PNG stems. `subjects[].species` = **copies the C1 species string verbatim** (roster is the guard-enforced source of truth; the manifest mirrors it for the art recipe reader — one prose, two consumers).
  - `subjects[].name` = title + identity, e.g. `"西毒(皮皮虾)"`, `"杨过(独臂神雕侠)"`.
  - `subjects[].appearance` = English prompt-style locked appearance (the 定妆 record). **Assembled only from recorded facts**, never from pixel guessing: (a) the split register (cartoon head / semi-realistic body); (b) shrimp body plan: head-carapace in front, curled segmented abdomen as the base, **NO torso / NO waist / NO legs**; (c) identity carried by shell base colour + non-human accessories (straw hat, headscarf, gourd, bamboo staff) — the old robe colours map to shell tones: west_poison dark shell with faint toxic-green sheen; north_beggar faded red, worn/scarred shell, long drooping maxillipeds (age on the body); east_heretic cold crimson (never pink), square kerchief tied at the back of the head (never wrapping cheeks), angular eyes + flat hard brows, no lashes; south_emperor imperial golden-amber shell; central_divine near-fully transparent glass body, pale Taoist crest; yang_guo deep-blue clean glossy shell, erect antennae, **no maxillipeds** (young); (d) `yang_guo` asymmetry written **positively** (the recipe's proven phrasing): one giant right claw larger than the head + a smooth round residual plate on the left — never "no arm / armless / empty sleeve".
  - `images[].scene` = pose/scene only, per handoff §三.4: side-view standing portrait, **compact vertical silhouette with claws held in front (not splayed)**, plain solid background, full body inside the frame, no text, no watermark. Composition/crop/scale/bottom-align/centering are **post-process**, not prompt, and are recorded as such (handoff §三.4/§三.5/§六).
  - **No seeds on subjects/images.** A seed identifies a *reproducible image*, not a *person* — that is the recorded reason the shape changed. The 9 non-character `assets` records keep their `seed`/`prompt`/`transparent` fields unchanged.
- **Validation:** `json.loads` parses; the six `images[].path` basenames == the six `subjects[].id` == the six PNG stems == the six roster keys; the 9 legacy `assets` records diff-clean against the old file.

### C3 — `./design/30_presentation.md` (executed by the `5_design` step; content fixed HERE)
Four surgical edits; the executor locates anchors by quoted text (line numbers drift):
1. **画风 section — sentence swap + dated rationale.** Replace the current blockquote sentence with **S** (one physical line). Append a dated paragraph (2026-08-31): the style changed to the split register (head fully cartoon + body semi-realistic) because pure realism scared, pure chibi under-delivered, and "somewhere between" produced mush — the two halves must be written explicitly inside one sentence; the only-one-sentence rule is unchanged (change `style_block`, sync this section, both or nothing).
2. **Art-direction record.** A dated entry: characters changed from *human ink-wash martial-artist figures* to **non-human real shrimp bodies, cartoon head + semi-realistic body**, executed under the 2026-08-28 「一切角色都是虾」 world constraint (cold-face: only image + title are shrimp; event/gongfa/skill prose untouched). Rationale per handoff §三: contamination words that pull shrimp into humanoid form (head-to-body ratio, short thick legs, robes with belts, two forelimbs, `mascot`) are replaced by carapace-front + curled-abdomen-base + NO torso/waist/legs; age/gender expression rules; asymmetry-as-positive; composition→post-process; `remove_bg` + border flood-fill hole repair.
3. **「重画的流程:先定妆,再出图」 → executed.** Add a dated line above the 4-step table: **this table was executed exactly once, 2026-08-31, producing these six portraits**, with two hard rules learned in production (step 3 `remove_bg` is mandatory — generative models cannot draw alpha; after cutout, flood-fill from the canvas border to repair interior holes — 0–6770 px repaired across the six). Below the 「现状/该是什么」 table: mark rows 1–2 (yang_guo missing one-arm / north_beggar missing dog-beating staff) as **resolved by this round's portraits** (one-arm via positive asymmetry; staff as a non-human accessory); rows 3–6 (backdrop aspect, defeat SFX, music loop, per-category SFX) remain open. Mark the two-layer manifest shape as **now implemented** (point at `assets/seed_manifest.json`).
4. **Texture-rect blind-spot record (Step-1 reviewer-mandated, record-level deliverable) — insert as a new dated blockquote directly after the blockquote containing `裁定立对位的是新 pin playtest/portrait_grid_alignment.yaml`… (the camera-owns-visibility block whose 两条原则 ends the paragraph — the caveat must sit next to the claim it qualifies).** Required content, all five points:
   1. `portrait_ink_rect` is **texture-rect derived** (`player.gd:469` / `enemy.gd:328`; `ink_world_dx/dy` published strictly from it at `player.gd` L502-503 / `enemy.gd` L355-356 — verify line numbers at write time; provenance: `.aitelier/knowledge.md` jinyong-camera 2026-08-29 entry + `README.md` Alignment observables), never alpha;
   2. therefore `abs(ink_world_dx/dy) <= 1.0` all-green does **not** prove the drawn content stands on its own tile — the two numbers read ≈0 for *any* pixel content;
   3. transparent bottom padding floats a portrait while the nail stays green — a **structural blind spot of the nail**, not a defect of any particular image;
   4. the true footing check is each PNG's **alpha bbox** (bottom edge vs y=127, horizontal centre vs x=48), measured this round, values in `final/delivery_notes_wuxia.md`;
   5. this round's bottom padding is expected ≈0 because post-processing is bottom-aligned — the green is **constructed** by the constant foot-anchor offset `(0, −tex.y/2)`, not coincidentally matching pixels; that distinction is the point of the record.
   End the record with: nail, thresholds, surface whitelist, and the name `portrait_ink_rect` are **not** changed; the optional future footing nail is **proposed to the owner, not landed** — (a) cheap: commit the stdlib alpha-bbox script + a pytest pinning each PNG's bbox bottom gap ≈ 0 and centre ≈ x=48 (asset-level, zero engine change, freezes six values); (b) thorough: extend `visibility_probe.gd`'s existing `blank_texture` asset-level alpha scan to publish bbox edges onto the surface (whitelist append-only) + a new playtest card (engine change + self-run per `configs/addons/game_harness/implementer.md:23`).

### C4 — `./design/90_decisions.md` append (5_design executes; content fixed HERE)
Append ONE new section at the end of the file, following the house format `## Title (date, context)`:
- **Title:** `## 武虾立绘落地:四个虾种裁定 + 画风换向(2026-08-31,项目所有者裁定)`
- **Four species rulings table** (verbatim from the brief/handoff §一): east_heretic→樱花虾(正樱虾) — deep-sea schooling, crimson translucent, gathering/scattering like falling blossoms — Peach Blossom Island; south_emperor→罗氏沼虾 — southern freshwater giant prawn, one pair of long blue claws — Dali; central_divine→玻璃虾 — fully transparent, innards visible — 先天功; yang_guo→枪虾 — one claw huge, other side empty (one-armed); partners with goby (神雕). Explicitly resolve the 2026-08-28 mapping table's 待定 rows; state that `yang_guo`'s title change is **deferred** (→ UX-15, C5).
- **Art-direction ruling:** human→non-human shrimp body; split register head-cartoon/body-semi-realistic with the trial-and-error convergence record (realistic→scary; chibi→flat; in-between→mush); style-sentence single source = `seed_manifest.json` `style_block`, byte-synced with `30_presentation.md`; full recipe archived in `final/delivery_notes_wuxia.md`.

### C5 — `./design/40_ux_backlog.md` append (5_design executes; content fixed HERE)
- **One new OPEN row (next free id: UX-15)** in the 队列 table: **de-naming `yang_guo`** — the roster `note` converted per brief. Fields: 状态 = `**OPEN** — 独立一轮(资源改名会打断编译期引用,不得与几何证明轮混做)`; 界面 = `角色资源命名`; 看见什么 = `yang_guo.png` is the only human-named resource; renaming touches the PNG/resource name + three reference sites (`scenes/player.tscn`, `assets/characters/roster.json`, `assets/seed_manifest.json`) + the title de-naming (「杨过/独臂神雕侠」→ a non-human-name title); 玩家因此做不到什么 = a human name appears in a public build; the five experts are titles and survive as-is, the protagonist has no non-name title yet — needs its own round (rename + three references + title in one step, compile + full gate re-run).
- **One dated 记录 line** (2026-08-31, round `wuxia-shrimp-portraits`): the roster note was converted to UX-15 (OPEN) per brief; this round does NOT rename the resource, the title, or any reference. **Do not** touch any other row's status (no OPEN→CLOSED flips belong to this round).

### C6 — `./design/99_changelog.md` append (5_design executes; content fixed HERE)
- **Append exactly ONE row** to the existing table; **no existing row may change** (append-only archive). Round id `wuxia-shrimp-portraits`, date `2026-08-31`. Content (what column): six portraits swapped to 武虾 (round input, PNGs never rewritten); roster four species filled by owner ruling + six `art_status` → completed, guard green; manifest two-layer + split-register `style_block` byte-synced with 30_presentation 画风; 30_presentation art-direction record + 定妆 table → executed + texture-rect blind-spot record; 90_decisions species + direction rulings; 40_ux_backlog UX-15 (OPEN, de-naming deferred); geometry re-measured with observed values (dx/dy, six-unit visibility, camera nail) + per-PNG alpha-bbox footing, values in `final/delivery_notes_wuxia.md`; recipe archived then `WUXIA_ART_HANDOFF.md` deleted; roadmap item 5 ✅. Reason column: first visible landing of the world constraint for build-in-public audiences; layers unchanged so nails must be re-measured, not inherited — a red is a finding, never loosened.

### C7 — Measurement instruments (the round's true deliverable)

**M1 — Engine-true re-measurement (`godot_playtest_scenario`, primary instrument; zero repo-file changes):**
- **M1a.** Run the existing `playtest/portrait_grid_alignment.yaml` **unmodified**. Record per unit (Player + five enemies) the observed `ink_world_dx` / `ink_world_dy` at the f40 static leg AND at the walk-arrival leg (f820), plus the scenario's pass count. 12 alignment lines × 2 legs expected.
- **M1b.** Run the existing `playtest/camera_transform_follows_unit.yaml` **unmodified**. Record pass count (e.g. 9/9).
- **M1c. Probe-contradiction inline YAML (established technique; passed as the `scenario=` parameter, NEVER staged into `playtest/`):** one inline timeline asserting, at f40, a sentinel equality for each of 6 units × 8 observables (`portrait_visible`, `portrait_fail_layer`, `portrait_covered_frac`, `sprite_top`, `portrait_tex_size`, `portrait_ink_rect`, `ink_world_dx`, `ink_world_dy`) — every assert deliberately false so the harness prints the `observed` value; transcribe all 48 observed values into the delivery notes. This is how the brief's six-unit `portrait_visible` / `portrait_fail_layer` requirement is satisfied without editing the frozen camera-level `portrait_visibility.yaml`. Precondition: grep `_common.yaml` first to confirm every observable name is still whitelisted (append-only — if a name is somehow absent, STOP and report; do not edit the whitelist).
- If any M1 leg reds for the wrong reason (e.g. the timing-sensitive walk leg misses its tile — impossible from a PNG swap, which changes neither AI nor timing): follow the yaml's own red-for-the-wrong-reason protocol — report the five enemies' `grid_pos`, treat as a finding; **ink thresholds untouched**.

**M2 — Pixel-true footing measurement (one-off transitional pytest probe):**
- **Artifact location (Step-1 reviewer suggestion #1, resolved):** a **temporary** file `./tests/test_tmp_alpha_bbox_probe.py`, written via `test_write`, executed via the pytest runner, **then deleted with `delete_file` in the same task — it is NEVER committed**. Only the measured VALUES land (in the delivery notes). Committing a pinned version is exactly the optional future nail (a) in C3.4, which stays owner-decision-only.
- **Decoder:** pure stdlib (`zlib` + `struct`) RGBA-8-bit non-interlaced PNG reader — parse IHDR/IDAT/IEND, concatenate + decompress IDAT, undo per-scanline filters 0–4 (None/Sub/Up/Average/Paeth), 4 bytes/px. **Reject anything else loudly** (bit depth ≠ 8, colortype ≠ 6, interlaced → hard error, no silent fallback). ~60 lines, no dependencies (repo pytest imports stdlib + PyYAML only).
- **Metrics per PNG (all six):** bbox at `alpha > 0` AND bbox at `alpha ≥ 8` (antialiasing-fringe guard); report left/right/top/bottom, from which the report derives `bottom_gap = 127 − bottom` (0 = touches the bottom row → feet anchor true) and `h_center_offset = (left+right)/2 − 47.5`; opaque-pixel counts at both thresholds. Expected: `east_heretic` top == 0 (known defect, not a geometry bug); all six bottom_gap ≈ 0 (bottom-aligned post-process) and h_center_offset ≈ 0.
- **Edge cases (from Step-1):** an all-transparent decode (bbox undefined) must be reported explicitly, never folded into a pass; both raw and thresholded bboxes recorded; interior holes are not expected (flood-fill was applied) but per-image counts are recorded, not assumed.
- **Extraction:** a single always-false assert embedding all six result rows in its message (pytest prints it) — the same probe-contradiction trick as M1c. Cross-check option (only if stdlib and M1 numbers disagree): Godot `Image.get_used_rect()` via the sidecar `/script` endpoint; not planned by default.

**M3 — Official gate evidence (supporting + formal):**
- Full `run_tests.sh` (sidecar `/compile` + `/playtest` + `/script`) on the final tree (after C1+C2). Official counts land in downstream step artifacts (`compile_report.json` / `playtest_summary.md` / `test_report.json`); the implementer's own run is supporting evidence pasted into the delivery notes. Required: compile 0 errors; all playtest scenarios green with 0 runtime errors; hard gate `passed: true`; GDScript unit suite green; `spine_to_ending` fully green; `tests/test_shrimp_roster.py` green.
- **5_vision** frames support the 肉眼可见 descriptions. **Blind-gate fallback (Step-1 reviewer suggestion #3, resolved):** if the vision gate is blind AND no usable frames exist for the new portraits, the delivery notes state that explicitly and mark the visual-acceptance sub-item **unverified-this-round** — descriptions of what is visible are then written ONLY from the handoff's cast-design record and labelled as such, never presented as frame-verified. No fabricated descriptions, ever.

### C8 — `./final/delivery_notes_wuxia.md` + deletion of `WUXIA_ART_HANDOFF.md`
- **职责:** the round's report AND the recipe archive. Structure:
  1. **Recipe archive** — `WUXIA_ART_HANDOFF.md` §一–§六 **verbatim**: species table; the style sentence (with the trial-and-error note); contamination words; age expression (body, not squinting; no human beards); gender pitfalls (pink + lashes + cheek-wrapping headscarf; fix = angular eyes/hard brows/no lashes, back-tied square kerchief, cold crimson, re-assert "shrimp head, no human face"); asymmetry-as-positive (the only way to draw "missing"); composition → post-process (compact vertical silhouette; crop by ink bbox → scale into 96×128 → **bottom-align + horizontal-centre**; height-normalize is rejected — it cuts yang_guo's claw by up to 42px); `remove_bg` mandatory (models paint the checkerboard opaque; 47.8–66.8% transparent measured); border flood-fill hole repair (interior holes 15.7% east_heretic / 5.2% west_poison; 0–6770 px filled); known defects §四.
  2. **Records changed** — C1/C2 summary (before → after).
  3. **Observed geometry values** — M1 tables (six units × dx/dy at both legs; six-unit `portrait_visible` / `portrait_fail_layer` / `portrait_covered_frac`; camera pass counts), M2 alpha-bbox table (six PNGs × bbox / bottom_gap / h_center_offset / counts, both thresholds), M3 gate counts. Every `observed` value from every self-run scenario pasted here (implementer.md:23 hard condition).
  4. **肉眼可见 per-portrait descriptions** — which is the mantis shrimp's folded club; which has the lobster's double claws + bamboo staff (+ gourd); which has the giant river prawn's extra-long blue claws; which is near-fully transparent; which has exactly one giant claw. Each description tied to vision-gate frames (or honestly marked unverified per the M3 fallback).
  5. **Red-nail findings** — any red with root cause; post-process fix suggestions ONLY when the root cause is image footing (e.g. bottom transparent padding); owner decides; this round redraws nothing.
  6. **Known art defects** — handoff §四 verbatim, so they are not mistaken for new geometry bugs.
- **Deletion protocol (irreversible — see §6):** write the notes → **verify the archive** (read back; every section §一–§六 present, sentence S byte-identical) → only then `delete_file ./WUXIA_ART_HANDOFF.md` → the changelog row records the deletion. Rollback = recreate the root file from the notes (byte-faithful source).

### C9 — `5_design` closure
- Flip roadmap completeness item 5 ❌ → ✅ (`./design/00_roadmap.md`), wording: reached 2026-08-31 — six shrimp portraits shipped, roster complete with guard green, style sentence synced; evidence paths `final/delivery_notes_wuxia.md` + gate artifacts. Add one dated line to the 第 4 阶段 bullet (replacement executed after the geometry nails landed, per its own timing constraint). Leave every other row/bullet untouched.
- Execute C3–C6 design edits; run the **final sync check**: `style_block` in `assets/seed_manifest.json` vs the 30_presentation 画风 sentence — must be byte-identical (diff the exact character sequences, not an eyeball pass).

## 4. playtest 契约影响(零改动)

No `playtest/*.yaml` is added, edited, or deleted. No `_common.yaml` surface change. No superset-fixture or `ROUND_SCENARIOS` change. M1c probes exist only as inline `scenario=` YAML at call time — nothing staged. The append-only contract is untouched by construction; `test_edited_scenarios_assert_superset` has nothing new to check.

## 5. 红钉协议 (red nails are findings)

If any pinned check reds: report the observed value + root cause; do **not** loosen a threshold, do **not** edit a nail/yaml, do **not** touch the camera/coordinate layer, do **not** redraw a PNG. Only if the root cause is demonstrably the **image's footing** (e.g. bottom transparent padding shifting the effective feet) may the report PROPOSE a post-process fix for the owner. A red `portrait_grid_alignment` on the new art is precisely the experiment's point: it would reveal whether the old geometry was merely coincidental. Timing-leg reds are handled per M1's wrong-reason protocol.

## 6. 不可逆操作与回滚

Exactly one irreversible operation exists: deleting `WUXIA_ART_HANDOFF.md`. Sequence: **archive (C8 §1) → verify (read-back, all six sections + S byte-identical) → delete → record**. Never "delete then write". Rollback = recreate from `final/delivery_notes_wuxia.md`. All other writes (roster, manifest, design docs) are plain file writes with parse/diff validation and no destructive step; the transitional M2 probe is deleted only after its values are transcribed into the notes.

## 7. 实施顺序 (PM decomposes along this; dependencies explicit)

1. **T1** C1 roster edit + guard pytest green. *(independent)*
2. **T2** C2 manifest restructure + parse/diff validation. *(independent of T1)*
3. **T3** M2 alpha-bbox probe → capture values → delete probe. *(independent of T1/T2; PNGs fixed)*
4. **T4** M1a/M1b/M1c harness runs → capture observed values. *(independent of T1/T2/T3)*
5. **T5** M3 full gate self-run. *(after T1+T2 — measured tree must be the delivered tree)*
6. **T6** C8 delivery notes (needs T3+T4+T5 outputs + handoff verbatim) → verify archive → `delete_file` handoff. *(strictly last of the implementer tasks)*
7. **T7 = `5_design` step** C3–C6 design edits + C9 roadmap flip + final byte-sync check, citing gate artifacts.

## 8. 技术栈

- **stdlib `json`** — roster/manifest edits + parse validation (no new dependencies anywhere).
- **pytest (existing runner)** — roster guard + the transitional M2 probe (stdlib-only decoder inside).
- **`godot_playtest_scenario(scenario=...)`** — M1 measurements; inline probe YAML for M1c.
- **Existing gate (`run_tests.sh` → godot-builder sidecar)** — M3 official evidence; no local godot binary exists and none is sought.
- **`test_write` / `read_test_written` / `delete_file`** — the implementer's write path (it cannot write binary — which is exactly why the PNGs are inputs).
- **Linters per `linter_manifest.json`** — `.json`/`.md`/`.yaml` = `basic`; `.py` = `ruff` (covers the transient probe file, which is deleted in-task); **`.gd` deliberately absent** — GDScript is checked by the `gdscript_check` gate, and this round writes zero GDScript anyway.

## 9. 扩展性考虑

- The two-layer manifest is the **template for the next character**: add one `subjects` row (name + appearance + species), one `images` row (subject + scene + path), one roster row, one PNG — the recipe in `final/delivery_notes_wuxia.md` is the how-to that saves a dozen rerolls (contamination words, age/gender rules, asymmetry phrasing, hole-fill).
- The texture-rect blind-spot record + the proposed optional nail (a/b) leave the owner a cheap path to a real footing pin without this round pre-empting the decision.
- `subjects[].species` mirroring the roster string keeps one prose for two consumers (guard-enforced roster; art-recipe manifest) and prevents the next rewrite from drifting the two apart.

## 10. Step-1 评审意见的处置 (all three addressed)

1. **Decoder artifact location ambiguity** → resolved in C7-M2: one-off temp pytest probe, deleted in-task, never committed; values only in the delivery notes; committing is the optional future nail (a), owner-decision-only.
2. **Missing provenance anchor for `portrait_ink_rect`** → resolved in §1 and C3.4: `.aitelier/knowledge.md` jinyong-camera (2026-08-29) entry (player.gd L502-503 / enemy.gd L355-356 publish `ink_world_dx/dy` strictly from the published `portrait_ink_rect`) + `README.md` "Alignment observables" section; line numbers verified at write time.
3. **Blind vision gate with no prior frames** → resolved in C7-M3: state it explicitly, mark the visual sub-item unverified-this-round, describe only from the handoff's cast-design record and label it, never fabricate.

## 11. 禁改清单 (touching any of these is rework)

- `./assets/characters/*.png` — read pixels only; never generate/draw/replace/repair.
- `./tests/test_shrimp_roster.py`, `tests/test_playtest_contract_smoke.py`, `tests/test_facility_copy_location.py`, `tests/test_i18n_coverage.py` — byte-identical.
- `./playtest/**` (all yamls, `_common.yaml` whitelist), superset fixture, `ROUND_SCENARIOS` — zero edits.
- `./scripts/camera_follower.gd`, `./scripts/coord.gd`, `ink_world_dx/dy` math, `camera_offset_y`, `PORTRAIT_TEX_Y` — zero edits.
- `./scripts/autoload/i18n.gd` — zero new strings (no UI text this round).
- `./design/99_changelog.md` — append-only; existing rows untouched.
- `yang_guo` naming — file name, title, and note stay; de-naming is UX-15 (OPEN), a separate round.
- No new systems, numbers, equipment/gongfa/event pools; no threshold relaxation anywhere.

## 12. 自检

- [x] Covers every brief goal: C1 (roster+status+guard), C2 (two-layer manifest+style), C3/C4/C5/C6 (design docs), C7 (geometry re-measurement with observed values + red protocol), C8 (recipe archive + deletion), C9 (roadmap item 5 with gate evidence).
- [x] Single-responsibility components; no new abstraction layers; measurement reuses the repo's own instruments (harness + pytest) per Step-1 recommendations.
- [x] Interfaces concrete enough for PM to split: exact strings, exact JSON shape, exact anchors, explicit task order with dependencies.
- [x] Irreversible operation (handoff deletion) has archive→verify→delete→record with a rollback path.
- [x] Over-engineering avoided: zero engine/code changes, no new nail landed, no framework introduced.
- [x] `linter_manifest.json` matches the file types this round touches (`.json`, `.md`, transient `.py`; `.gd` intentionally excluded).
