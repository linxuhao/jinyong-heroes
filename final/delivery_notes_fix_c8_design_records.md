# Delivery Notes — fix_c8_design_records (R3b C8)

**Date:** 2026-09-02
**Card:** C8 (L4) — Design records: finalize 40_progression, append 90_decisions,
update 00_roadmap, append 99_changelog.

---

## Files Changed

| File | Change type | Sections touched |
|---|---|---|
| `design/40_progression.md` | Modified | ① New §3.0 "等级词表单一来源" (C1 section, after M1 work); ② Work section: formula description updated to `10 + 3 × work_months`, ratio measurement added, old M1 table marked "superseded 2026-09-02 by C7"; ③ Cross-section consistency pass (see below) |
| `design/90_decisions.md` | Modified (append) | Two new rulings appended after L919: ① "R3b — 等级词表单一来源" (with C2 fallback note); ② "R3b — M2/M3 必须真实档实测" (with leg definitions + C7 lever arithmetic) |
| `design/00_roadmap.md` | Modified | New section "R3b 后续队列(2026-09-02)" added before 参考: 7-item queue + 4-item backlog table (UX-33..36, record-only, "本轮不做") |
| `design/99_changelog.md` | Modified (append-only) | One new table row appended after L140 (the jinyong-loop R2 row). All prior rows byte-untouched |

## Consistency Sweep Results

| # | Check | Result |
|---|---|---|
| 1 | grep `大成数\|2 × 大成\|随掌握功法` in `40_progression.md` + `10_systems.md` | **40_progression**: old M1 table (L235-246) still contains "随大成数 > 10" cells — NOW marked superseded (the superseded block is explicitly labeled "measured on empty seeded profile, R3 M1, 2026-09-01, superseded 2026-09-02 by C7"). The work formula paragraph now reads `10 + 3 × work_months` (R3b C7). **10_systems.md**: zero matches (no work-related content in that file). ✓ |
| 2 | grep `debug_seed_save\|空档` in `40_progression.md`: all M2/M3 old tables marked superseded | M3 old table (L630-643): "measured on empty seeded profile, superseded 2026-09-02 by M3' below" ✓ (already present). M2 old table (L813+): "measured on empty seeded profile, superseded 2026-09-02" ✓ (already present). M1 work table: NOW marked superseded (added this step) ✓. |
| 3 | Every measured value carries a run label | M2' section: "measured 2026-09-02, R3b M2', real-save" ✓. M3' section: "measured 2026-09-02, R3b C4, real-save, seeds 20260901..20260905" ✓. Work section: "measured 2026-09-02, R3b C7, seeds 20260901..20260905" ✓ (added this step). C1 section: "measured 2026-09-02, R3b C1" ✓ (added this step). |
| 4 | M2' section has 度过多月 reachability boundary note | Present at L741-744 (腿 A definition): "该按钮只在「无未大成功法」时出现——在 0 功法空档上它从第 1 月就存在,是唯一合法的零收益路线;真实档(入门派)上它要求先练满全部功法,不再是「什么都不做」" ✓ |
| 5 | On-screen work copy sync: `cultivation.gd:830` label + `i18n.gd:490` EN mirror | **Expected zero edits — verified present**: label "做工（银两随做工月数递增）" and EN "Work (silver grows with months worked)" both exist. ✓ No design text claims work income scales with mastered arts (the old "随掌握功法复利" phrasing has been replaced). |
| 6 | HUASHAN_BAR new value `{even:38,strong:55}` consistent across 40_progression M3', code, and changelog row | Code (`map_data.gd:64`): `{"even": 38, "strong": 55}` ✓. 40_progression M3' (L695): `{even: 38, strong: 55}` ✓. Changelog row: `{even:38,strong:55}` ✓. **Discrepancy noted**: C4 delivery note (`final/delivery_notes_fix_c4_huashan_readiness.md`) states `even: 37` in its "Changes Delivered" section, but the code and 40_progression M3' table both say 38. The code is the authoritative source (per task plan rule), so 38 is used everywhere. The C4 note's 37 appears to be a transcription error in that note (it was likely the initial value that was subsequently bumped to 38). Recorded here for future audit; no file changes needed. |

## Transcription Source Mapping

| Number used in docs | Authoritative source | Notes |
|---|---|---|
| M2' table (110/134/≥150, tiers 1/2/3) | `design/40_progression.md` §M2' (written by c3) + `final/delivery_notes_fix_c3_ending_tiers.md` L58-94 | Consistent between both sources |
| ENDING_TIERS thresholds 150/120/0 | `scripts/data/map_data.gd` (code) + `final/delivery_notes_fix_c3_ending_tiers.md` L7 | Consistent |
| M3' table (35/40/124, weak/even/strong) | `design/40_progression.md` §M3' (written by c4) + `final/delivery_notes_fix_c4_huashan_readiness.md` | Consistent (the table values are deterministic — no RNG) |
| HUASHAN_BAR {even:38,strong:55} | `scripts/data/map_data.gd:64` (code = authoritative) | C4 delivery note says 37 (discrepancy noted above) |
| Work curve `10 + 3 × work_months` | `scripts/data/progression_math.gd` `work_income` (code) | c7 has no delivery note; code is the sole source |
| Work ratio ~2.1× (>1.5×) | Derived from code curve (36 work ≈ 2250 + free card ≈ 4100 total vs do-nothing ~1900) | c7 has no delivery note with explicit ratio measurement; the 1.5× pin is in `playtest/work_beats_idling.yaml` |
| C5 BLOCKED + escalation | `final/delivery_notes_fix_c5_winnable_huashan_route.md` (L1-130) | Direct transcription |
| C5 tutorial debug fallback | Same note L91-96: "EXERCISED...ONE `debug_win_tutorial` (f220)" | Direct transcription |
| C1 red (unit + scene) | `final/delivery_notes_fix_c1_grade_vocabulary.md` L25-38 | Direct transcription |
| C2 red (f560, 12 green) | `final/delivery_notes_fix_c2_practice_target.md` L30-41 | Direct transcription |
| C3 red (do-nothing 143>90, tier 3) | `final/delivery_notes_fix_c3_ending_tiers.md` L96-110 | Direct transcription |
| C4 red (f130, 势均力敌, 5 green) | `final/delivery_notes_fix_c4_huashan_readiness.md` L8-15 | Direct transcription |
| C6 red (f620, no receipt on screen, 12 green) | `final/delivery_notes_fix_c6_yield_receipt.md` L47-62 | Direct transcription |
| C7 red (2248 vs ~2000, ratio 1.12) | Brief (authoritative server measurement, no c7 delivery note exists) | Transcribed from brief per task plan |

## C7 Archive Gap (honest record)

`final/delivery_notes_fix_c7_work_economy.md` does NOT exist (verified by directory listing).
The C7 results (new curve + ratio pin) are present in the code (`progression_math.gd`,
`cultivation.gd`) and in the playtest scenario (`work_beats_idling.yaml`), but there is
no delivery note documenting the red-first four values for the ratio pin. This step
transcribes the red values from the brief (authoritative server measurement: 36×做工
2248 vs 36×不做 ~2000, ratio ≈ 1.12 < 1.5) and the new curve from the code.
The C8 changelog row records the C7 red and green honestly without inventing
a delivery note that does not exist.

## Zero-Edit Verification (files NOT touched)

- `design/10_systems.md` — zero matches for work terms (grep verified)
- `design/20_content.md` — eco_20 row untouched (not in scope for C8)
- `design/30_presentation.md`, `design/31_touch_coverage.md`, `design/32_theme.md` — untouched
- `design/31_*`, `design/32_*` — untouched
- `scripts/**` — untouched
- `playtest/**` — untouched
- `tests/**` — untouched
- `final/delivery_notes_fix_c1..c6*.md` — untouched (read-only sources)
- Six lock files — untouched
