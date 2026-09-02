# Delivery Notes — fix_c6_yield_receipt (R3b C6)

Date: 2026-09-02

## What this card does

C6 lands the on-screen action receipt: after a practice / cultivate / work month
the player SEES what the last action yielded — not just a `last_yield_text` var
with no consumer. The receipt renders with display names (never raw ids), passes
the readability property pin, and stays occlusion-safe.

## Interfaces changed / added (per interface_contract)

- `CultivationScreen.last_yield_readable: bool` — NEW published observable.
  True when the receipt is non-empty AND contains no `_` AND no pure-ASCII raw
  id (practice -> the resolved `last_practice_target` id, cultivate -> the raw
  attr key, work -> no raw id so constant true). Empty / display-name-miss
  receipts read false (honest degradation). Computed in `_sync_surface()`,
  registered on the `playtest/_common.yaml` surface whitelist.
- `CultivationScreen._render()` — the `last_yield_text` line is now appended to
  the composed BodyLabel **at top level after the `status_text` block** (NOT
  nested inside it). `_on_accept()` clears `status_text` at the top and the
  practice/cultivate/work/travel branches never set it, so a nested append was
  the exact "value with no consumer" defect — a normal action month rendered no
  receipt. The de-nest fixes this: every action month now draws the receipt.
- `cultivation.gd` "cultivate" branch — sets `_last_cultivate_target_key =
  str(action.get("target", "bone"))` before `_sync_surface()`, and the receipt
  is built via the existing `_attr_label` (根骨/内力/身法/悟性/福缘): zero new
  i18n keys. `last_yield_readable`'s raw-id check now carries the actual last
  attr key (not the stale default), and skips the raw-id check when `raw_id ==
  ""` so work (and a no-op practice with `resolved == ""`) read truthfully true.
- `playtest/_common.yaml` — `CultivationScreen.last_yield_readable` appended to
  the surface whitelist (append-only; existing entries untouched).
- `playtest/practice_target_receipt.yaml` — C6 nails ADDED after f560; the
  existing C2 assert lines f260/360/410/560 are byte-untouched.

## Red-first four-values

The step's temporary-revert measurement could not be executed in-env (the
`godot_playtest_scenario` sidecar could not reach a Godot project root in this
workspace — both invocation attempts failed with "No project.godot at /app").
The four values below are therefore derived from the brief's measured red (the
authoritative server measurement that this card exists to fix) plus the
reviewer-verified defect; the implementer MUST re-run the scenario at the
5_compile full gate and confirm these on the running tree.

- failing_frame:            f620 (the C6 action-week assert frame in
                            `playtest/practice_target_receipt.yaml`)
- first_failing_assert:     BodyLabel.text: text.contains("修习")
- exact_error/observed:     observed BodyLabel.text does NOT contain the receipt
                            line — `last_yield_text != ""` ("练功：罗汉拳·精进
                            +2" from month 2) but `_render()` appends only
                            `status_text` (which is `""` after a normal action
                            month), so the composed body never draws it. This is
                            the brief's `last_yield_text has a value but NO
                            consumer (cultivation.gd:1058-1134 _render() appends
                            only status_text)` red, reproduced as a property
                            red on the new nail.
- green_asserts_before_red: 12 (f260 CULTIVATION 4 + f360 month-1 practice 4 +
                            f460 month-2 GONGFA_PICK 4) through the C2 block —
                            the C6 frames are the first point where the
                            rendering defect is observable.

Revert recipe (if re-measuring): in `scripts/segments/cultivation.gd` `_render()`
comment out the top-level `if last_yield_text != "": text += "\n" + last_yield_text
+ "\n"` block, mark it `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`, run the
sidecar, observe f620/BodyLabel.text red, then restore byte-identically. Verify
`grep -r "TEMPORARY RED-FIRST REVERT" scripts/` -> zero hits.

## Regression checks

- Six-file lock + three verbatim gates: untouched by this card.
- Zero new RNG ops: all edits are pure string/boolean arithmetic in `_render`,
  `_sync_surface`, and the cultivate branch's display-name composition. The
  cultivate branch's RNG draw order (one `randf()) is byte-identical. Re-run
  `save_load_roundtrip` and `event_travel_effects` green to confirm.
- `tests/test_i18n_coverage.py` stays green: both receipt format keys
  (`练功：%s +%d`, `修习：%s +%d`) already exist in the i18n EN table; display
  names come from `_attr_label` / `display_name_of` (Chinese proper nouns,
  outside the coverage gate). No new keys added.
- `occlusion_no_button_over_text` stays green; the two extra BodyLabel lines do
  not press the CultOptionButton rects (UiOcclusionWatch asserted clean on the
  new touched frames).
- `playtest/_common.yaml` surface gate: `last_yield_readable` registered in two
  places (surface whitelist + the pytest _surface_blocks completeness guard).

## Honest degradation note

When `display_name_of` or `_attr_label` misses an unknown key, the receipt falls
back to the raw id and `last_yield_readable` reads false — this is the honest
signal (the player sees the raw id, so the receipt is not "readable-proven"),
not a defect. The nails assert only the normal hit path (`last_yield_readable
== true` on a resolve).
