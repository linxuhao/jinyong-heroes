# Technical Architecture Design — Seeded Generated Art & Audio for Huashan Sword Tournament

## 1. Overview

**Goal:** Replace the presentation layer of the Godot 4.4 wuxia tactics game "Huashan Sword Tournament" with seeded, deterministically generated art and audio produced by the platform tools `gen_image_asset` (PNG) and `gen_audio_asset` (WAV). The game logic, input map, node names, script variable names, and `playtest_spec.yaml` remain **byte-for-byte untouched**; only the visual/audible skin changes.

**Current placeholder state** (what we replace):
- Player/enemy sprites: procedurally generated `Polygon2D` circles/diamonds tinted via `.color`.
- Summit backdrop: flat `ColorRect`.
- Terrain: runtime `Image.create()` + `Image.fill()` green/gray tiles.
- Audio: none.

**Target state:**
- 6 character `Sprite2D` sprites (player Yang Guo + the Five Greats), 2 terrain tile textures, 1 summit backdrop — all seeded PNGs under `assets/`, deterministically reproducible from a frozen `assets/seed_manifest.json`.
- 5 SFX WAVs + 1 music-bed WAV, played through a new additive `AudioManager` autoload hooked into the existing event flow.
- Same gameplay, same observable surface (`Player.health`, `grid_pos`, `selected_skill_index`, HUD/health-bar visibility and positions), same `run_tests.sh` gates.

**Scope guardrail (from the brief):** edits are restricted to (a) node *type* and visual properties of presentation nodes (keeping node names), (b) the `_damage_flash` cast, (c) the backdrop typed reference, (d) removal of procedural polygon/tile generation, (e) one new autoload (`AudioManager`) + one `[autoload]` line in `project.godot`, (f) new assets + seed manifest + README update. No combat/AI/input/tutorial logic, no renames of nodes or script variables.

---

## 2. Architecture Diagram (text)

```
                         ┌────────────────────────────────────────────────┐
                         │  gen_image_asset / gen_audio_asset (platform) │
                         │  frozen prompts + fixed unique seeds           │
                         └───────────────┬────────────────────────────────┘
                                         │ produces (deterministic)
                                         ▼
                    assets/  (committed, incl. .import sidecars)
   characters/{yang_guo,east_heretic,west_poison,south_emperor,
               north_beggar,central_divine}.png   [transparent=true]
   terrain/{floor,border}.png                     [transparent=false]
   backdrop/summit.png                            [transparent=false, 1088×832]
   audio/{hit,hurt,move,select,victory,music}.wav
   seed_manifest.json   ← path → seed → frozen prompt  (re-run = same bytes)

                 scenes (.tscn, ext_resource references)      scripts (.gd)
   player.tscn ──ext──► yang_guo.png            player.gd       (modulate, texture,
   enemy.tscn  (Sprite2D, texture assigned                        offset, select-sfx)
                per-character at setup())
   battlefield.tscn ──ext──► summit.png         enemy.gd        (per-character texture
                                                                  map, modulate, offset)
                                                battlefield.gd  (load() terrain PNGs,
                                                                  Sprite2D backdrop)
                                                combat_manager.gd (Sprite2D flash cast,
                                                                  hit-SFX hooks)
                                                grid_manager.gd  (move-SFX hook)
                                                audio_manager.gd (NEW autoload)

                    Godot import pass (harness --compile) → .godot/imported/*

   Runtime rendering (draw order = tree order):
     Battlefield
       ├─ SummitBackdrop  (Sprite2D, Linear, 1088×832)
       ├─ Grid            (TileMap, runtime TileSet, 2×1 atlas, Nearest)
       └─ Characters      (6 × Sprite2D, Linear, feet-anchored, modulate WHITE)
     HUDLayer (CanvasLayer 10)   ← floating health bars / skill buttons
     TutorialLayer (CanvasLayer 100)

   Audio flow (signals + direct calls):
     GameManager.battle_started ──► AudioManager.play_music()  (bed, -10 dB vs SFX,
                                      restart on finished, stop on game_won/game_lost)
     GridManager.move_unit        ──► AudioManager.play_move()   (player path)
     CombatManager._execute_move  ──► AudioManager.play_move()   (AI path)
     CombatManager._execute_basic_attack / _execute_skill
                                  ──► AudioManager.play_hit()
     CombatManager.damage_dealt   ──► AudioManager (target==player → play_hurt,
                                      ≥150 ms throttle)          (covers DoT ticks)
     player.select_skill()        ──► AudioManager.play_select() (HUD + keyboard path)
     GameManager.game_won         ──► AudioManager.play_victory() + stop_music()
```

**Key invariants preserved:**
- `GridManager` grid math, occupancy, AStar2D, world↔grid conversion: untouched.
- `CombatManager` action queue, damage/DoT/knockback/death logic: untouched except the flash cast and two SFX hook lines.
- `playtest_spec.yaml` surface names (`HUD`, `Player`, `HealthBar`; `health`, `max_health`, `grid_pos`, `global_position`, `selected_skill_index`, `visible`): untouched.

---

## 3. Component List

### Component A — Asset Generation Layer (deterministic, seeded)

- **Responsibility:** produce the 15 binary assets exactly as specified by frozen prompts + unique fixed seeds; record them in `assets/seed_manifest.json`.
- **Interface:** calls to `gen_image_asset(prompt, seed, transparent, path)` and `gen_audio_asset(prompt, seed, path)` by the Implementer; output paths under `assets/`. Same seed + frozen prompt + same model ⇒ identical bytes (brief contract).
- **Seed rule:** one **unique** fixed seed per asset (two assets sharing a seed produce identical output — SOTA Edge Case 4). Re-running the manifest must reproduce the cast byte-for-byte; prompts are frozen once verified.
- **Delivery:** PNGs + WAVs committed together with their Godot `.import` sidecar files (text, deterministic import settings). Never reference or commit `res://.godot/…`.

#### Asset inventory

| # | Asset | Path | Tool / flags | Seed | Size guidance |
|---|-------|------|--------------|------|---------------|
| 1 | Yang Guo | `assets/characters/yang_guo.png` | image, `transparent=true` | `1001` | full body, ~96×128 |
| 2 | East Heretic | `assets/characters/east_heretic.png` | image, `transparent=true` | `1002` | ~96×128 |
| 3 | West Poison | `assets/characters/west_poison.png` | image, `transparent=true` | `1003` | ~96×128 |
| 4 | South Emperor | `assets/characters/south_emperor.png` | image, `transparent=true` | `1004` | ~96×128 |
| 5 | North Beggar | `assets/characters/north_beggar.png` | image, `transparent=true` | `1005` | ~96×128 |
| 6 | Central Divine | `assets/characters/central_divine.png` | image, `transparent=true` | `1006` | ~96×128 |
| 7 | Floor tile | `assets/terrain/floor.png` | image, `transparent=false` | `1010` | 64×64, seamless |
| 8 | Border tile | `assets/terrain/border.png` | image, `transparent=false` | `1011` | 64×64, seamless |
| 9 | Summit backdrop | `assets/backdrop/summit.png` | image, `transparent=false` | `1020` | 1088×832 (17:13) |
| 10 | Hit SFX | `assets/audio/hit.wav` | audio | `2001` | < 0.5 s |
| 11 | Hurt SFX | `assets/audio/hurt.wav` | audio | `2002` | < 0.5 s |
| 12 | Move SFX | `assets/audio/move.wav` | audio | `2003` | < 0.5 s |
| 13 | Select SFX | `assets/audio/select.wav` | audio | `2004` | < 0.5 s |
| 14 | Victory jingle | `assets/audio/victory.wav` | audio | `2005` | ~2–4 s |
| 15 | Music bed | `assets/audio/music.wav` | audio | `2006` | ~30–60 s, low volume |

Exact seed values are Implementer-assignable (any fixed unique integers) — they are recorded once in `seed_manifest.json` and frozen.

#### Prompt strategy (style cohesion, per addon guidance)

The **shared style block** describes ONLY art style — never any game object (naming objects in the shared block makes the model draw them into every image):

> `Chinese wuxia ink-painting style, flat colors, clean bold outlines, dramatic lighting`

Each **per-asset prompt** = shared style block + composition suffix + its own subject only. Composition suffixes:

- Characters: `full body, side view, plain solid white background` — the solid white background is what the keyer removes (`transparent=true`); therefore **no white/silver in any costume** (Central Divine wears robes with gray tones but keeps them clearly non-white, e.g. ivory-ink shading, so keying does not punch holes — verify in frame captures).
- Floor tile: `top-down seamless square tile, subtle texture variation` (no objects — a tile prompt naming objects would embed them in every tile).
- Border tile: `top-down seamless square rock wall tile with stone edges`.
- Backdrop: `wide panoramic landscape, misty mountain summit at dawn, distant peaks and clouds, no characters, no buildings in foreground`.

Per-character subject blocks (grounded in `resources.md` §2 art direction):

| Asset | Subject block (appended to style block) |
|-------|------------------------------------------|
| Yang Guo | `a young swordsman in deep blue robes holding a heavy iron sword, full body, side view, plain solid white background` |
| East Heretic | `an elegant middle-aged scholar in teal-blue robes playing a jade flute, full body, side view, plain solid white background` |
| West Poison | `a fierce fighter in dark purple robes with a faint green poison aura, full body, side view, plain solid white background` |
| South Emperor | `a regal monk in imperial golden-yellow robes, full body, side view, plain solid white background` |
| North Beggar | `a ragged beggar in faded red robes with a wine gourd, powerful stance, full body, side view, plain solid white background` |
| Central Divine | `a Taoist immortal in pale gray-white robes with a divine aura, full body, side view, plain solid white background` |

All characters also add: `feet at the bottom edge of the frame, centered composition, no text, no watermark`. Distinguishability comes from silhouette/prop/color; cohesion from the frozen shared block.

**`seed_manifest.json` schema** (committed under `assets/`):
```json
{
  "style_block": "Chinese wuxia ink-painting style, flat colors, clean bold outlines, dramatic lighting",
  "assets": [
    {"path": "res://assets/characters/yang_guo.png", "seed": 1001, "transparent": true,  "prompt": "<frozen full prompt>"},
    {"path": "res://assets/audio/hit.wav",        "seed": 2001, "transparent": null, "prompt": "<frozen full prompt>"}
  ]
}
```

### Component B — Character Presentation (scenes + scripts)

- **Files:** `scenes/player.tscn`, `scenes/enemy.tscn`, `scripts/characters/player.gd`, `scripts/characters/enemy.gd`.
- **Responsibility:** render each character as a feet-anchored `Sprite2D` with Linear filtering; drop all procedural polygon generation; keep the node name `Sprite` and script variable `_sprite`.
- **Scene edits (`player.tscn`):**
  - Node `Sprite`: type `Polygon2D` → `Sprite2D`; properties: `texture = ExtResource("<yang_guo.png id>")`, `centered = true`, `texture_filter = 1` (Linear), `offset` set at runtime from actual texture height (robust to model size variance).
  - `[gd_scene load_steps=N]`: +1 for the new texture `ext_resource`; ext_resource entries precede sub_resources/nodes (SOTA Edge Case 1); Godot 4.4 mandates `load_steps`.
  - `NameLabel` stays **last child** so it draws above the taller sprite (Edge Case 9).
- **Scene edits (`enemy.tscn`):** same node swap to `Sprite2D` (textureless — see decision log D2), `centered = true`, `texture_filter = 1`; `NameLabel` last child.
- **`player.gd` edits (presentation-only):**
  - `@onready var _sprite: Polygon2D = $Sprite` → `@onready var _sprite: Sprite2D = $Sprite` (variable name kept).
  - Delete `CIRCLE_SEGMENTS`, `CIRCLE_RADIUS`, `_generate_circle_polygon()` and its `_ready()` call.
  - In `_ready()` / `setup()`: set `_sprite.offset = Vector2(0, -(_sprite.texture.get_height() / 2.0))` (feet at tile center; for 96×128 → `(0, -64)`, SOTA Edge Case 9).
  - Replace `_sprite.color = data.color` with `_sprite.modulate = Color.WHITE` (no tint — the generated art already carries each character's palette; see D3).
  - Selection hook (Edge Case 12): `select_skill(index)` ends with `AudioManager.play_select()`. Refactor `_try_select_skill(index)` to call `select_skill(index)` after its tutorial gate (behavior-neutral: identical toggle semantics, one sound hook for both HUD clicks and keys 1/2).
  - Everything else (`_try_move`, targeting, cooldown ticking, signals) untouched.
- **`enemy.gd` edits (presentation-only):**
  - `@onready var _sprite: Polygon2D` → `Sprite2D`; delete `DIAMOND_RADIUS`, `DIAMOND_POINTS`, `_generate_diamond_polygon()` and its `_ready()` call.
  - Add a frozen `const TEXTURE_PATHS: Dictionary = {"East Heretic": "res://assets/characters/east_heretic.png", …}` (name → path; names must match `character_data.character_name` set in `battlefield.gd`).
  - In `setup()`: `_sprite.texture = _texture_for(data.character_name)` (preload-backed helper; null-safe fallback → keep texture null, sprite invisible but logic intact), then set offset from texture height and `modulate = Color.WHITE`.
  - AI logic (`_process`, `_evaluate_ai`, FSM) untouched.

### Component C — Backdrop & Terrain (battlefield)

- **Files:** `scenes/battlefield.tscn`, `scripts/battlefield.gd`.
- **Backdrop (Edge Case 8):**
  - `battlefield.tscn`: node `SummitBackdrop` type `ColorRect` → `Sprite2D`, `texture = ExtResource("<summit.png id>")`, `centered = true`, `position = Vector2(480, 352)` (grid + 64 px padding rect `(-64,-64)–(1024,768)`), `texture_filter = 1`. Keep first-child order (draws under `Grid`). `load_steps` +1.
  - `battlefield.gd`: `@onready var _backdrop: ColorRect` → `Sprite2D`; **delete** the `_backdrop.size = …` / `_backdrop.position = …` block (texture defines size now).
- **Terrain (Edge Case 14, keep runtime TileSet):**
  - `_create_tile_textures()`: replace `Image.create()`/`fill()` with `load("res://assets/terrain/floor.png")` / `load("res://assets/terrain/border.png")` returned as `Texture2D`s (runtime `load()` explicitly allowed by the constraint for the code-built TileSet).
  - Keep the 2×1 atlas blit (`_setup_tilemap`) and every `set_cell` call byte-identical so GridManager occupancy/AStar are unaffected. Keep the atlas at project-default **Nearest** filtering (shared atlas + Linear would bleed tile edges, Edge Case 5/14).
  - Fallback (only if a texture fails to load): generate the old procedural image so the game never hard-crashes (log a warning).

### Component D — Combat / Grid presentation touchpoints

- **Files:** `scripts/autoload/combat_manager.gd`, `scripts/autoload/grid_manager.gd`.
- **`combat_manager.gd`:**
  - `_damage_flash()` (Edge Case 7): change `target.get_node_or_null("Sprite") as Polygon2D` (and the `get_child(0) as Polygon2D` fallback) to `as Sprite2D`; `if target is Polygon2D` → `if target is Sprite2D`. Without this the cast silently returns null and the flash dies.
  - Flash visibility (D3): sprites now have `modulate = WHITE`, so flashing to WHITE would be invisible — flash to overbright `Color(2, 2, 2)` and restore to the captured original modulate after 0.1 s.
  - **Hit SFX hook** (Edge Case 12): one `AudioManager.play_hit()` call at the top of `_execute_basic_attack()` (after validity check) and one at the top of `_execute_skill()` (after skill lookup). **Not** in `apply_damage()` — that also fires per DoT tick.
  - All combat logic (queue, AoE, knockback, DoT, death) otherwise untouched.
- **`grid_manager.gd`:** **Move SFX hook** — one `AudioManager.play_move()` in `move_unit()` right after `reserve_tile(to_pos, unit)` succeeds (player path; `_execute_move` in CombatManager covers the AI path — Edge Case 12). No other changes.

### Component E — AudioManager (new autoload)

- **Files:** `scripts/autoload/audio_manager.gd` (new), `project.godot` (`[autoload]` +1 line).
- **Responsibility:** sole owner of all audio playback; preloads the 6 WAVs; exposes six no-arg, always-safe public methods callable from any autoload/character script.
- **Interface (public API):**

| Method | Behavior |
|--------|----------|
| `play_hit()` | play hit.wav on SFX player |
| `play_hurt()` | play hurt.wav; throttled to ≥150 ms since last hurt (DoT tick spam guard) |
| `play_move()` | play move.wav on SFX player |
| `play_select()` | play select.wav on SFX player |
| `play_victory()` | stop music, play victory.wav once |
| `play_music()` | play music.wav on the music player (if not playing) |
| `stop_music()` | stop the music player |

- **Internal structure:** two `AudioStreamPlayer` nodes created in `_ready()` (autoloads have no scene):
  - `_sfx_player`: `max_polyphony = 8` (SOTA Edge Case 10 — rapid hits/moves must not cut each other off), `volume_db = 0.0`.
  - `_music_player`: `volume_db = -10.0` (music ~10 dB under SFX, Edge Case 11), `finished` connected to re-`play()` (restart-on-finished; a small seam gap is explicitly acceptable — do NOT use `AudioStreamWAV.loop_mode` on a WAV with no authored loop point).
  - `_last_hurt_msec` throttle timestamp.
- **Signal wiring in `_ready()`** (requires autoload order: `AudioManager` declared **after** `CombatManager`/`GameManager` in `project.godot` — add it as the 5th entry, after `TutorialManager`):
  - `GameManager.battle_started` → `play_music` (bed autoplays from battle start).
  - `GameManager.game_won` → `play_victory`; `GameManager.game_lost` → `stop_music`.
  - `CombatManager.damage_dealt` → if `target == GameManager.get_player()` (or `target.name == "Player"`) → `play_hurt()` (throttled). Covers DoT ticks on the player (acceptable per Edge Case 12).
- **Pause note (Edge Case 13):** `Engine.time_scale = 0` does not gate audio; music keeps playing during pause — accepted, no pause logic touched.
- Preloaded streams via `const … = preload("res://assets/audio/…")` — the idiomatic equivalent of `.tscn` ext_resources for a scene-less autoload (SOTA "Existing Solutions" recommendation).

### Component F — Verification & Regression Gates

- **`run_tests.sh` unchanged:** harness `--compile` (Godot import pass for the new PNG/WAVs runs here — SOTA Edge Case 2) then headless `--playtest` against the untouched `playtest_spec.yaml`.
- **Visual verification (manual, post-playtest):** review captured playtest frames for (1) 6 distinct drawn characters on drawn terrain, (2) alpha edges clean (no white halo from keying), (3) HUD + floating health bars legible above sprites, (4) backdrop not stretched.
- **Determinism verification:** re-run all `gen_*` calls from the manifest; byte-compare outputs to committed assets (same seed + frozen prompt + same model ⇒ identical output).
- **Audio spot check:** headless playtest output free of audio errors; optionally dump `AudioStreamPlayer` state in a debug run.

---

## 4. Data Flow (runtime)

```
battlefield.gd _ready()
  ├─ load() terrain PNGs → 2×1 atlas → TileSet → set_cell paint   (unchanged geometry)
  ├─ GridManager.setup_grid()
  ├─ instantiate player.tscn (Sprite2D w/ yang_guo.png ext_resource)
  ├─ instantiate enemy.tscn ×5 (enemy.setup assigns per-character texture + offset)
  └─ wire HUD / tutorial (deferred, unchanged)

per-frame:
  player/enemy._process → cooldowns/AI (unchanged; sprites static)
  HUD._process → health_bar.follow_character() (unchanged)

events:
  player._try_move ─► GridManager.move_unit ✓reserve ─► AudioManager.play_move()
  AI decision      ─► CombatManager._execute_move ✓reserve ─► play_move()
  click/attack     ─► CombatManager._execute_basic_attack/_execute_skill ─► play_hit(),
                      apply_damage ─► damage_dealt ─► AudioManager (player? → play_hurt)
  HUD button / key ─► player.select_skill ─► play_select()
  all dead         ─► GameManager.end_battle(true) ─► game_won ─► play_victory + stop_music
  player dead      ─► end_battle(false) ─► game_lost ─► stop_music
  battle_started   ─► play_music (bed, restarts on finished)
```

---

## 5. Migration & Rollback Plan (irreversible-op safety)

The migration is file-based and fully git-reversible, but the constraint requires *backup → execute → verify → only then delete* ordering. Therefore tasks are ordered so that **destructive edits (deleting placeholder generators) come last**:

1. **Additive first (zero risk):** generate + commit all 15 assets, `.import` sidecars, `assets/seed_manifest.json`; add `AudioManager` + `[autoload]` line (pure additions — old visuals/scripts still fully functional).
2. **Execute swaps in isolation, one component per subtask** (B → C → D), each ending with its own `run_tests.sh` gate:
   - Swap `player.tscn`/`player.gd` → gate.
   - Swap `enemy.tscn`/`enemy.gd` → gate.
   - Swap `battlefield.tscn`/`battlefield.gd` (backdrop + terrain loads) → gate.
   - `combat_manager.gd` (flash cast + hit hooks) + `grid_manager.gd` (move hook) → gate.
3. **Verify new state:** headless playtest green + frame-capture review (characters drawn, bars legible, no halos, backdrop intact) + seed-manifest reproduction check.
4. **Only after verification:** delete the now-dead procedural code (`_generate_circle_polygon`, `_generate_diamond_polygon`, `Image.create`/`fill` tile generation, `_backdrop.size/position` sizing). Keep the terrain `load()`-failure fallback that still constructs procedural tiles.
5. **Rollback path (any gate failure):** `git checkout -- <file>` per subtask — each subtask touches disjoint files, so rollback is component-local with no cross-file undo ordering. No data migration, no schema, nothing non-reversible.

---

## 6. Technical Stack

| Concern | Choice | Rationale (SOTA) |
|---|---|---|
| Character/backdrop rendering | `Sprite2D` + per-node `texture_filter = 1` (Linear) | Painted ink art jagged under project default Nearest (Edge Case 5); per-node avoids flipping the global default |
| Terrain rendering | Runtime `TileSet` + 2×1 `TileSetAtlasSource`, default Nearest | Existing construction works; swap only texture sources; shared atlas must stay Nearest to avoid edge bleed (Edge Case 5/14) |
| Character tinting | `modulate = WHITE`, no per-character tint | Generated art carries identity; `Polygon2D.color` no longer exists on Sprite2D (Edge Case 6) |
| Damage flash | `as Sprite2D` cast + overbright `Color(2,2,2)` | Fixes silent null cast (Edge Case 7); white-on-white invisible otherwise |
| Anchoring | `centered = true`, `offset.y = -h/2` computed from texture height | Feet-anchored at tile center, robust to model output size variance (Edge Case 9) |
| Audio playback | `AudioManager` autoload, preloaded WAVs, `max_polyphony = 8`, music `finished`→`play()` | Callable from every autoload hook without scene-graph lookups (SOTA "Existing Solutions"); WAV = native `AudioStreamWAV`, no transcode; no `loop_mode` (no authored loop point → seam click) |
| Asset delivery | Raw PNG/WAV + `.import` sidecars committed; `.godot/` gitignored | Import pass runs in harness `--compile` before playtest (Edge Case 2) |
| Determinism | `seed_manifest.json` (path→seed→prompt), unique fixed seeds, frozen prompts | Re-runs reproduce the cast; prompt edits change art (Edge Case 4) |
| Verification | Existing `run_tests.sh` + frame-capture review + manifest re-run | Unchanged gates; presentation verified visually |

---

## 7. Playtest Contract (frozen — implementation must not break it)

`playtest_spec.yaml` is **untouched** by this work (brief). It is the regression gate; every name below must remain resolvable at runtime:

### scene
```yaml
scene: "res://scenes/main.tscn"
```

### actions (must stay defined in `project.godot` `[input]` — no changes needed)
```yaml
actions: [move_up, move_down, move_left, move_right, skill_1, skill_2, pause_game, ui_accept]
```

### surface (hard contract for implementers)
```yaml
surface:
  HUD:        [visible]
  Player:     [health, max_health, grid_pos, global_position, selected_skill_index]
  HealthBar:  [visible, global_position]
```
- `Player` = root of `player.tscn` (name kept), `HealthBar` = root of `health_bar.tscn`, `HUD` under `HUDLayer`. No renames, no removed script variables.

### scenarios (existing, PM-owned thresholds — unchanged)
- `health_bar_visibility_on_startup` — HUD + HealthBar visible at frame 5.
- `health_bar_follows_player_movement` — tutorial advance via `ui_accept` presses, then `move_right`, HealthBar remains visible and `Player.grid_pos != null`.
- `no_runtime_errors_on_launch` — no `Invalid call`/`Nonexistent function` errors at frame 2.

Implementation notes for PM/Implementer: the flash-cast change (Component D) is exactly what `no_runtime_errors_on_launch` protects against; the sprite swap must keep `Sprite` node + `_sprite` var so nothing in the assert expressions changes.

---

## 8. Deliverables & Final File Tree

```
./assets/                                (NEW)
  characters/{yang_guo,east_heretic,west_poison,south_emperor,north_beggar,central_divine}.png (+.import)
  terrain/{floor,border}.png (+.import)
  backdrop/summit.png (+.import)
  audio/{hit,hurt,move,select,victory,music}.wav (+.import)
  seed_manifest.json                     (NEW)
./scripts/autoload/audio_manager.gd      (NEW)
./scripts/characters/player.gd           (edited — presentation only)
./scripts/characters/enemy.gd            (edited — presentation only)
./scripts/battlefield.gd                 (edited — backdrop type + terrain loads)
./scripts/autoload/combat_manager.gd     (edited — flash cast + hit hooks)
./scripts/autoload/grid_manager.gd       (edited — move hook, 1 line)
./scenes/player.tscn                     (edited — Sprite2D + ext_resource)
./scenes/enemy.tscn                      (edited — Sprite2D swap)
./scenes/battlefield.tscn                (edited — Sprite2D backdrop + ext_resource)
./project.godot                          (edited — +1 [autoload] line only)
./README.md                              (edited — assets, seeds, controls, run instructions)
./playtest_spec.yaml                     (UNTOUCHED)
./run_tests.sh                           (UNTOUCHED)
./resources.md                           (UNTOUCHED — remains the art-direction reference)
```

**README.md update (required deliverable):** document Godot 4.4+ → F5 to play; controls (WASD/arrows move, 1/2 skills, click enemy to act, Space/Esc pause); list which assets are generated (6 character PNGs, 2 tiles, 1 backdrop, 5 SFX, 1 music bed), their seed manifest location, and that everything is deterministic from `seed_manifest.json`.

---

## 9. Suggested Task Decomposition for PM

Independent subtasks, each ending with a `run_tests.sh` gate (order follows §5):

1. **T1** Generate 9 image assets + `seed_manifest.json` (image entries). Gate: compile still green (assets inert).
2. **T2** Generate 6 audio assets + manifest audio entries. Gate: compile green.
3. **T3** `AudioManager` autoload + `project.godot` autoload entry (playback API + signal wiring). Gate: compile + playtest green (no sounds wired yet, nothing observable changes).
4. **T4** `player.tscn`/`player.gd` sprite swap (+select hook via `select_skill`). Gate: playtest green.
5. **T5** `enemy.tscn`/`enemy.gd` per-character texture map. Gate: playtest green.
6. **T6** `battlefield.tscn`/`battlefield.gd` backdrop + terrain loads. Gate: playtest green.
7. **T7** `combat_manager.gd` flash cast + hit hooks; `grid_manager.gd` move hook; hurt wiring (in T3's AudioManager already). Gate: playtest green.
8. **T8** Dead-code removal (polygon generators, procedural tiles, backdrop sizing) — only after frame-capture verification. Gate: playtest green.
9. **T9** README update + determinism re-run check + final frame review.

---

## 10. Design Decisions Log

- **D1 — Enemy textures assigned at runtime, not via `.tscn` ext_resource.** One shared `enemy.tscn` must render 5 different characters. Five unused `ext_resource`s in the scene would trip unused-resource warnings and can't bind per-instance anyway. The per-character `const TEXTURE_PATHS` map in `enemy.gd` + `preload()` is the minimal compliant form (Edge Case 15: script preloads are compile-time resource dependencies). Player/backdrop use real `.tscn` `ext_resource`s per the constraint.
- **D2 — No `CharacterData` field added.** `character_name` (already present) is the texture-map key, so the data layer needs zero changes — smallest possible diff and no risk to data-driven logic.
- **D3 — No per-character tint; overbright flash.** Tinting generated ink art with `data.color` would destroy the model's palette (a green-tinted East Heretic, etc.). Sprites keep `modulate = WHITE`; the damage flash therefore uses overbright `Color(2,2,2)` so it stays visible. `CharacterData.color` is left intact (unused by presentation, available for fallbacks).
- **D4 — Music starts on `battle_started`, not `_ready()`.** Avoids the bed playing over the tutorial and makes the start deterministic for playtesting; restart-on-`finished` handles the no-loop-point WAV; ~10 dB under SFX.
- **D5 — Terrain keeps runtime TileSet + Nearest.** Prebuilt `.tres` would add a hand-authored resource file for no benefit; the existing builder needs only texture-source swaps (SOTA "Existing Solutions").
- **D6 — `select_skill()` becomes the single select-sound hook** via a behavior-neutral refactor of `_try_select_skill` (Edge Case 12); HUD buttons already route through `select_skill()`.
- **D7 — `project.godot` engine config otherwise untouched.** `config/features`/`default_texture_filter` stay as-is; only the additive `[autoload]` line is added (per-node `texture_filter` handles filtering, Edge Case 5).

---

## 11. Extensibility Considerations

- **More characters/skins:** add PNG + manifest entry + one line in `enemy.gd`'s `TEXTURE_PATHS` (or a path in `character_data` if the data layer ever grows) — no scene or logic changes.
- **Animation later (explicit non-goal now):** the `Sprite2D` node could be swapped for `AnimatedSprite2D` keeping the name `Sprite`; the `_sprite` var + offset code would move into the new node config.
- **Music variety/loops:** `play_music()` is the single entry point; swapping restart-on-finished for authored `loop_begin/loop_end` is a one-line change if a looped WAV is ever produced.
- **Audio ducking/mute:** `AudioManager` centralizes playback — future pause-mute, settings toggles, or per-event volume all land there without touching hook sites.
- **Fallback policy:** if any `gen_*` asset is missing at load time, terrain falls back to procedural tiles and characters render label-only — the game never hard-crashes (no `assert` on asset load).

---

## 12. Non-Goals (explicit)

- No frame-sheet animation, no Spine/Live2D, no hand-authored art, no user-supplied assets (brief).
- No `.tres` TileSet resources, no prebuilt audio scene — runtime construction + autoload only.
- No seamless music looping (non-goal: restart-on-finished with small gap is acceptable).
- No changes to combat balance, AI, tutorial flow, input map, `playtest_spec.yaml`, or `resources.md`.
