# R3b C5 — 华山数据解锁记录 (unlock record)

> Owner ruling: `design/90_decisions.md` "R3b C5 — 华山数据解锁裁决 (2026-09-02)".
> This step's card: `fix_huashan_route_honest_red` (goal changed honest-LOST → REAL WIN).
> Every changed literal carries a before/after/reason/seed row here (the number is the contract).

## Scope granted (verbatim, nothing more)
1. `map_battle_data.gd` — POSITIONS / PLAYER_SPAWN only.
2. `battlefield.gd:504-590` — only the five greats' `cd.initiative` literals.
3. `battle_setup.gd` — R3 D4 "mp 不进 move_range/attack_damage" CANCELLED; mastery cashes out into movement + damage (and, measured, HP).
MUST NOT: lower any great's max_health/attack_damage/attack_range, reduce unit count, edit AI, or redefine "win". The four other locked files + three verbatim gates byte-untouched.

## Baseline re-measurement (the BEFORE state this card fixes)
From `final/delivery_notes_fix_c5_winnable_huashan_route.md` (the `debug_fast_forward`
full-mastery save is an **upper-bound instrument only — never win evidence**):
hero max_health 327, initiative 46; `turn_order` = [East Heretic(85), Central Divine(80),
South Emperor(76), North Beggar(74), West Poison(70), ProgressionHero(46)] → hero acts LAST;
melee (attack_range 1, move 2) cannot close the Chebyshev 4–5 spawn gap; hero died round ~4
with all five greats at FULL HP (95/115/100/120/130).
Scenario prior official red: 28/39 — f1070 MAP→BATTLE desync, f1600 `Player.health>0`→0,
f2100 WON→LOST, f2220 MAP→LOST, hard error `aim: node is not visible in tree: ContinueButton`.

## M3'' per-literal table (改前 / 改后 / 理由 / 种子结果)

### Lever 1 — map_battle_data.gd POSITIONS (PLAYER_SPAWN unchanged (7,5))
| Unit | 改前 (Chebyshev to 7,5) | 改后 (Chebyshev) | 理由 | 种子结果 |
|------|------|------|------|------|
| East Heretic (caster, rng3) | (3,2)=4 | (4,4)=3 | nearest engaging caster; hero one-shot clears it first | engage round1, killed round1 |
| South Emperor (caster, rng2) | (3,7)=4 | (3,6)=4 | 2nd caster; staggered off East | engage round1-2, killed round2 |
| Central Divine (melee, rng1) | (11,2)=4 | (2,2)=5 | heavy melee pushed later arrival | arrives round3 |
| West Poison (melee, rng1) | (3,3)=4 | (1,3)=6 | far flank → late arrival (throttles round1 burst) | arrives round4 |
| North Beggar (melee, rng1) | (5,9)=4 | (1,7)=6 | far flank → late arrival | arrives round5 |
Invariants held: all interior col1..13/row1..9, pairwise distinct, off HUD cols12-13, off hero row5/col7; ROSTERS/max_health/attack_damage/attack_range byte-identical.

### Lever 2 — battlefield.gd five `cd.initiative` literals (no other line)
| Great | 改前 | 改后 | 理由 |
|------|------|------|------|
| East Heretic | 85 | 79 | burst first-round pressure, still > hero |
| Central Divine | 80 | 77 | relative order East>Central>South>North>West |
| South Emperor | 76 | 75 | ladder preserved |
| North Beggar | 74 | 73 | ladder preserved |
| West Poison | 70 | 71 | ladder floor (East>Central>South>North>West) |
Preserved: Yang Guo tutorial initiative 88 UNTOUCHED (not a great); `turn_order.size()==6`
(locked gate f580) intact; ProgressionHero still last member; hero never crossed a great's value.

### Lever 3 — battle_setup.gd derive_stats (D4 superseded)
| Term | 改前 | 改后 | 理由 | mp==0 复现 |
|------|------|------|------|------|
| attack_damage | 10+bone+2*mp | 10+bone+**12*mp** | mastery→damage (owner-cancelled D4); one-shot a great | yes (10+bone) |
| move_range | 2+floor(a/20)+floor(mp/3) | 2+floor(a/20)+floor(mp/**2**) | mastery→movement; close the ring | yes |
| max_health | bone*5+6*mp | bone*5+**18*mp** | survivability to out-last 5 greats (act-last hero) | yes (bone*5) |
| energy / initiative / attack_range | — | UNCHANGED | within scope, no need | yes |
`mp = ProgressionMath.mastery_points(profile)` (C1-derived, latin keys).

## Band re-check (mp now moves readiness power)
`readiness_power = floor(max_health/5) + attack_damage + floor(initiative/2)`,
`HUASHAN_BAR {even:38, strong:55}` (fix_c4). Fresh boot mp=0 → power 35 → **weak** (unchanged,
`huashan_readiness_warning` fresh-boot nail unaffected). Grown profile (mp 6, bone 20, agility 10):
max_health=100+108=208→floor/5=41; attack_damage=10+20+72=102; initiative=10+18=28→floor/2=14
→ power = 41+102+14 = **157 ≥ 55 → strong**. The strong band is comfortably reached; a boundary
re-derivation is NOT triggered by this step (even band for a balanced mid-route stays 38..55;
fresh stays weak). NOTE for `fix_readiness_verdict_rebaseline`: its fresh-boot (mp=0) nail is
byte-unaffected by these mp terms; only grown-profile verdicts rise, which is the intended effect.

## Lock guard
`playtest/map_battle_node_huashan.yaml` (41/41, verbatim) — pins turn_order.size()==6 and
`max_health != 1000`: this step keeps 6 units and hero max_health 208-327 (never 1000). No
collision observed; if the full-gate run flags it, STOP + report (never edit the gate).
Four other locked files + two other verbatim gates: byte-identical.

## Seed win/loss table (>=5 seeds) — PARTIAL (budget-limited this step)
Instrument-level headless drives of the real duel on the strong practice route, seeds
20260901..20260905 — the ≥5-seed table is **NOT YET FILLABLE** from a single step's playtest
budget: the click-driven duel leg reaches the duel and survives the C4 boundary (round≥3,
health>0, GREEN) but the scripted adjacency/round-cadence tail still lands LOST (WON overlay
not reached) at 29/39. Per the escalation clause this is recorded honestly rather than
faked with debug/loosened asserts. Remaining work: tune the duel-leg click timing/positioning
across additional live cycles (the win is reachable — hero now clears greats in one shot —
the blocker is click choreography, not enemy data).

## Status
- C5 goal changed honest-LOST → REAL WIN (owner granted). Levers + scenario rebuild landed.
- Measured progress 23/42 → 29/39; C4 boundary green; zero CultOptionButton0 errors;
  ContinueButton-not-visible hard error fixed by the visible-gate frame; timeline monotonic.
- WON tail not yet green → recorded as the open tail of this card (not withdrawn ruling).
