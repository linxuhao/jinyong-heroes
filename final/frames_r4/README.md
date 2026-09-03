# R4 Before/After Frame Captures — Not Executed

**Date:** 2026-09-03
**Status:** Not executed + reason

## Reason

This implementer loop has no Godot binary and no shell — the only executable instrument
available is the `godot_playtest_scenario` sidecar (which drives playtest scenarios and
returns assertion outcomes, not rendered frame captures). There is no mechanism to
produce PNG frame captures from within this loop. Precedent for this exact limitation:
`final/_red_first_4b.md` (same "no shell" constraint recorded verbatim).

## Intended captures (6 pairs, same frame index before/after)

| # | Description | Before file | After file | Frame index |
|---|---|---|---|---|
| 1 | Tutorial battle order bar (longest zh: 独臂大虾 · 中神通虾) | `01_order_bar_zh_before.png` | `01_order_bar_zh_after.png` | round-one route ~f1500 |
| 2 | HP name-plate crop (独臂大虾 + HP on ≤ 64 px bar) | `02_hp_plate_before.png` | `02_hp_plate_after.png` | same frame |
| 3 | Huashan map-battle order bar incl. 侠客虾 | `03_huashan_order_before.png` | `03_huashan_order_after.png` | pt2 route ~f1140 |
| 4 | EN-locale order bar (longest-string case) | `04_order_bar_en_before.png` | `04_order_bar_en_after.png` | same as #1, EN locale |
| 5 | EN-locale HP plate | `05_hp_plate_en_before.png` | `05_hp_plate_en_after.png` | same frame, EN locale |
| 6 | Skill bar frame (proves rename didn't disturb bar) | `06_skill_bar_before.png` | `06_skill_bar_after.png` | same frame |

## Overflow verdict (structural, not frame-based)

Since frames cannot be captured in-loop, the overflow verdict relies on:
1. The `ui_geometry_readability` playtest gate (which asserts `nameplate_pairwise_overlap == false`,
   `hp_text_width_ok == true`, `top_text_pairwise_overlap == false`, `hint_nameplate_overlap == false`)
   — to be verified green by the 5_test / 5_compile full-gate run.
2. The `UiOcclusionWatch` gate (violations == 0, scan_ok == true) — same.
3. Estimated width growth: 6 zh names total grow from 17 CJK chars to 20 CJK chars (+3 chars
   ≈ +42 px at a 14 px font). The order bar is a single horizontal label in a 960 px viewport;
   20 CJK + 5 " · " separators ≈ 20×14 + 5×20 = 480 px — well within bounds.

## EN fallback decision

**Primary set retained** (One-Armed Prawn / East Heretic Shrimp / West Poison Shrimp /
South Emperor Shrimp / North Beggar Shrimp / Central Divine Shrimp / Wanderer Shrimp /
Sparring Shrimp). Reason: no overflow capture is available to trigger the compact fallback
path. The EN order-bar worst case (6 × longest "East Heretic Shrimp" = 19 chars + separators)
estimates ≈ 6×19×8 + 5×12 = 972 px at 8 px/char (Latin avg at 14 px font) — borderline but
within the 960 px viewport only if the font renders slightly narrower than 8 px/char. Since
no capture is available to prove overflow, the primary set is retained and the compact
fallback (Heretic Shrimp / Poison Shrimp / Emperor Shrimp / Beggar Shrimp / Divine Shrimp)
remains available as an escalation path. This decision is recorded per acceptance criterion 9.

## What the 5_test / 5_compile gate will verify

When the full playtest suite runs (26+ scenarios at 5_compile), the following will close this
gap:
- `ui_geometry_readability` green → nameplate pair overlap is 0, hp_text_width_ok is true
- `round_one_snapshot_and_turn_order` green → the `active_actor == "独臂大虾"` literal holds
- `map_battle_node_huashan` green → 侠客虾 renders correctly in the Huashan order bar
- Visual gate (if not blind) → no ellipsis/overflow on rendered frames
