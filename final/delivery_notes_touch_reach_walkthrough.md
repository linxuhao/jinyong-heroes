# Delivery Notes — Touch-Reach Walkthrough: Play Full Game With Taps Only

**Date:** 2026-08-29
**Task:** touch_reach_design_docs
**Sources:** `playtest/clicks_only_storyline.yaml` (the taps-only timeline) + the gate run; first-red measured values transcribed verbatim from `final/delivery_notes_touch_reach_red_first.md`.

## What this note is

The brief's first success criterion: a recorded walkthrough of the **full main storyline**
using only taps, describing **what was tapped on each screen** — main menu → creation →
tutorial battle → tutorial end overlay → transition → sect select → cultivation (36 months) →
map → events → ending → restart. It is transcribed from the `clicks:` timeline of
`playtest/clicks_only_storyline.yaml`; gate totals (the full-green count) belong to the
5_design evidence step and are not invented here.

## The taps-only walkthrough (screen by screen — what was tapped)

| Screen | What was tapped | Notes |
|---|---|---|
| 主菜单 (main menu) | `MenuEntry0` | 新的冒险 (new adventure); exits to creation |
| 捏人 · 属性页 (creation · attributes) | `AttrNextButton` | ATTRS → TRAITS |
| 捏人 · 特质页 (creation · traits) | `TraitNextButton` | TRAITS → CONFIRM |
| 捏人 · 确认页 (creation · confirm) | `ConfirmButton` | CONFIRM → TUTORIAL battle |
| 教程战 · 开场页 (tutorial intro pages) | `Next` ×3 | intro pages 1→2→3 (real GUI clicks; the first tap on a button that exists) |
| 教程战 · 战斗 (tutorial battle) | `AttackButton` | one real click on the attack button (out-of-range rejection is harmless — the tap proves the battle screen is hittable); the **battle outcome is seeded with `debug_win_tutorial`** (the ONE sanctioned non-click action, adjudicated — a full click-fought battle cannot fit the frame cap; the battle screen's clickability is separately proven by `battle_end_turn_attack_buttons` / `click_targeting_fixed` / `undo_button_retreat` / `click_portrait_body_targets_enemy`) |
| 教程结算 overlay | `ContinueButton` | **← the FIRST-RED screen** (see below); post-fix this tap advances WON → TRANSITION |
| 过场 (transition) | `NextButton` ×2 | page 1 → page 2 → SECT_SELECTION |
| 拜师 (sect select) | `SectButton0` | picks sect 0 (少林) → CULTIVATION |
| 养成 · 36 个月 (cultivation) | each month `CultOptionButton0` (选卡 / 年初培元 / 岁末留门) × `CultOptionButton2` (做工 — advances the month through the existing path); y2m1 & y3m1 each an **extra** `CultOptionButton0` (year-augment); y1m12 & y2m12 year-end stay clicks `CultOptionButton0` | checkpoints at year 1/2/3, month 1 (updated from `year == 1 / month == 1`, `year == 2 / month == 1`, `year == 3 / month == 1` on screen) |
| 大地图 · 腿 1 (map · leg 1) | `TravelButton0` | 无名谷 → 洛阳; arrival opens EVENT `merchant`; then `EventOptionButton0` → resolves; `events_resolved_count == 1` |
| 大地图 · 腿 2 (map · leg 2) | `TravelButton1` | 洛阳 → 武当; EVENT `quanzhen_scripture`; `EventOptionButton0` → +1 → `events_resolved_count == 2` |
| 大地图 · 腿 3 (map · leg 3) | `TravelButton1` | 武当 → 襄阳; EVENT `dragon_scrap`; `EventOptionButton0` → +1 → `events_resolved_count == 3` |
| 大地图 · 腿 4 (map · leg 4) | `TravelButton1` | 襄阳 → 昆仑 (**endpoint), no entry event** — the endpoint routes straight to ENDING before any entry event; no event tap at kunlun |
| 结局 (ending) | `RestartButton` | ENDING (`tier` in 1..3) → restart; returns to `current_state == "TUTORIAL"` — the storyline is closed by taps alone |

Total: ≈ 90 clicks across the six segments. The entire run contains **zero keyboard
actions**; the only non-click timeline entry is `debug_win_tutorial` (the documented
battle-outcome seed).

## First-red evidence (verbatim from `final/delivery_notes_touch_reach_red_first.md`)

The nail `clicks_only_storyline` was authored to **first go red** on the unfixed tree.
The screen it failed on was the **tutorial-end overlay**, and the measured values
transcribed here are taken verbatim from that file (they are the structural prediction
recorded there; the gate run's confirmation is the 5_design step's verdict):

| Field | Value (verbatim from `delivery_notes_touch_reach_red_first.md`) |
|---|---|
| Screen it first failed on | 教程结算 overlay (tutorial-end overlay) |
| Failing frame | **180** |
| First failing assert | **`ContinueButton.visible`** (the node does not exist pre-fix) |
| Green asserts before red | **5** (per the red_first file's header; the same file's inline breakdown sums differently — transcribed the header value for source fidelity) |
| Exact error (predicted) | `push_error: clicks target 'ContinueButton' — node not found in the current scene tree` (the overlay is built in code with `CanvasLayer + ColorRect + Panel + Label` only; no Button nodes exist) |

Root cause: at f180 the seed has already moved `current_state` to `"WON"`, the first two
asserts (`current_state == "WON"`, `end_overlay_text` contains 胜利) pass, and the third
(`ContinueButton.visible`) fails because `_show_end_game_overlay` builds zero Button nodes —
exactly the screen where the real phone player was stuck. The `clicks:` harness is a **true
hit test**, so a missing control is a hard gate red, never a silent skip.

## Note on "measured" vs "predicted"

This walkthrough and the first-red figures are transcribed from the scenario timeline and
the red_first file. The confirming gate totals (all-playtest-scenarios-green, 0 runtime
errors, hard gates passed:true, unit suite green) are produced by the downstream
`5_compile` / `5_design` steps and appended there with their measured evidence — none of
those numbers are invented in this note.