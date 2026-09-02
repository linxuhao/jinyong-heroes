# Delivery Notes — fix_combat_repin_mastery_terms

**Date:** 2026-09-02
**Card:** fix_combat_repin_mastery_terms — property pins for post-C1 mastery in `cultivation_changes_combat` (27/30 → 30/30).
**Owner ruling (feedback round #2, 2026-09-02):** do NOT re-pin `×1.1` / `27` as new literals — the next balance pass would red them again. Convert to PROPERTY PINS (re-derivation, not literal swap). This is the 00_roadmap「数字本身就是契约」exception clause exercised as property pins.

---

## Measured Red (official 2026-09-02 playtest_summary.md — cultivation_changes_combat 27/30)

| Frame | Surface | Old nail (equality literal) | Observed |
|---|---|---|---|
| f1040 | `SkillButton1.fahui_text` | `fahui_text == "发挥 ×0.85"` | `发挥 ×1.1` |
| f1110 | `Sparring_Partner.health` | `health == 34` | `27` |
| f1110 | `SkillButton1.fahui_text` | `fahui_text == "发挥 ×0.85"` | `发挥 ×1.1` |

**Root cause (diagnosed):** the C1 grade-vocabulary fix made `mastery_points` non-zero on real profiles for the FIRST time, so `BattleSetup.derive_stats`'s mastery term (`max_health += 6×mp`, `energy += 4×mp`, `initiative += 3×mp`) now applies in the encounter this scenario drives — the hero's inner-power multiplier reads ×1.1 instead of ×0.85 and the sparring partner's HP shifted 34 → 27. This is the EXPECTED consequence of C1 landing, not a game defect.

---

## Change Table (one row per touched line)

### `playtest/cultivation_changes_combat.yaml`

| Line | Old nail | New nail | Why the property is stable |
|---|---|---|---|
| f1040 `SkillButton1.fahui_text` | `fahui_text == "发挥 ×0.85"` | `fahui_text != "发挥 ×0.7"` | The fahui multiplier tracks the same-attribute mastery count. f490 (battle 1, no mastered arts) pins the no-mastery baseline `×0.7` (kept verbatim, green). f1040 (battle 2, post-practice mastered ≥ 1) asserts the multiplier has CHANGED from that baseline — the differential tracks its driver (mastery count), so any future rebalance that keeps mastery affecting fahui stays green, and a regression that drops mastery back to ×0.7 reds it. Direction backed by the official red value f1040 observed `发挥 ×1.1`. |
| f1110 `Sparring_Partner.health` | `health == 34` | `health > 0 and health < max_health` | Computed-boolean property: the partner took a hit but did not die. Both sides recomputed at runtime from live published observables (`Sparring_Partner.health`, `Sparring_Partner.max_health` — both on the surface whitelist, `_common.yaml:640-642`). Survives any future rebalance; reds only if damage becomes 0 (partner full HP) or lethal (partner dead). Direction (battle 1 drop 21, battle 2 drop 33) recorded as measured values below, not as an assertion. |
| f1110 `SkillButton1.fahui_text` | `fahui_text == "发挥 ×0.85"` | `fahui_text != "发挥 ×0.7"` | Same property as the f1040 row: multiplier changed from the no-mastery baseline. |
| f560 `Sparring_Partner.health` | `health == 39` (kept verbatim) | `health == 39 and health > 0 and health < max_health` | The existing green `health == 39` (battle 1, no mastery) is preserved byte-identical; the bounds pin is ADDED (new assertion, not a replacement) so battle 1 also carries the same computed-boolean property. Combined into one expression because the harness parses the assert block with `yaml.safe_load`, which collapses duplicate mapping keys — two `Sparring_Partner.health` keys in one block would silently drop one. |
| description (line 5) | prose claiming battle-2 values `×0.85/26/34` | prose marked `PRE-C1 VALUES, SUPERSEDED 2026-09-02` + pointer to this file | The header prose encoded the now-superseded arithmetic contract. It is prose, not an assertion, so the anti-relaxation rule does not apply; it is marked superseded so a future reader does not trust stale numbers. |

**Directionality (measured values, not assertions):** battle 1 (no mastery) the partner drops 60 → 39 (21 damage); battle 2 (post-practice mastery) the partner drops 60 → 27 (33 damage). The harness assert language is single-frame single-expression (`_common.yaml:113`): values may be `changed` (baselined against frame 0 = null), a YAML literal, or a single-quoted GDScript boolean expression. There is NO cross-frame reference syntax (no `@battle1`/`@battle2`), and `changed` at f1040 would compare against frame 0 (null) — trivially green, unable to prove battle 2 differs from battle 1. Hence the cross-frame differential form is deliberately abandoned; directionality is recorded here as measured values instead of an assertion.

---

## Mirror Sweep (tests/ + playtest/)

| Search | Occurrences | Disposition |
|---|---|---|
| `发挥 ×0.85` | `playtest/cultivation_changes_combat.yaml:227,243` (the two failing pins) | Converted to `!= "发挥 ×0.7"` (this card). |
| `health == 34` | `playtest/cultivation_changes_combat.yaml:241` (the failing pin) | Converted to `health > 0 and health < max_health` (this card). |
| `发挥 ×1.1` | none | — |
| `== 27` | none | — |
| `×1.3` | `playtest/fahui_du_multiplies_damage.yaml:38-44`, `playtest/skill_button_effect_info.yaml:44` | **Unrelated, kept.** Pre-existing pins in a different scenario (fahui_du_multiplies_damage) that assert a ×1.3 multiplier from a different mechanic (the 独孤九剑 甲级 sword's own fahui, not the C1 mastery term). Not a C1 mastery-term mirror; left byte-untouched. |
| `发挥 ×0.85` | `scripts/ui/skill_button.gd:138,253` | **Unrelated, kept.** Code comments documenting the fahui_text rendering format (0.85 → "发挥 ×0.85"), not test/playtest assertions. |

**Result: zero C1 mastery-term literal mirrors remain in tests/ or playtest/.**

---

## Cross-Card Note

`fix_huashan_route_honest_red` (a later row) additionally feeds mp into `attack_damage`/`move_range` per the owner's unlock ruling. Property pins (never literals) are what keep this scenario green through that change: the fahui multiplier differential tracks the same-attribute mastery count, and the partner HP bounds recompute both sides at runtime — neither depends on a specific numeric value that a future balance pass could shift.

---

## Hard Rules Compliance

- **Six-file lock:** untouched (battlefield.gd, game_manager.gd, scene_manager.gd, map.gd, map_battle_data.gd, map_battle_node_huashan.yaml).
- **Three verbatim gates:** untouched (facility_use_reusable, map_node_event_shaolin, map_battle_node_huashan).
- **Zero new RNG ops:** this card changes only yaml assert expressions + prose — no game code, no RNG.
- **No assertion deletions:** the 27 currently-green asserts stay as-is; the f560 bounds pin is an ADDITION, not a replacement.
- **No loosening:** every property conversion preserves the binding (fahui tracks its driver; HP bounds recompute both sides). A conversion that dropped a binding would be a weakening and is forbidden.
- **Zero game-code edits:** `scripts/` untouched.

## Verification

`godot_playtest_scenario(scenario="cultivation_changes_combat")` → **30/30 PASS** (was 27/30). Staged file applied: `playtest/cultivation_changes_combat.yaml`.
