## Pure static math helpers for the implemented trait effects (design §4.1 / §4.4).
## Deterministic helpers only — no RNG, no autoload references, no scene tree.
## All float math via GDScript round() (half-away-from-zero); every round()
## result is wrapped in int() because GDScript 4 has no implicit float->int.
## Consumers get this script via `const TraitEffects = preload(...)` and call
## the static funcs directly on the constant.

## 修习 lookup table (design §4.1). roll ∈ [0, 1) is supplied by the caller
## (exactly one SaveManager.rng.randf() draw per 修习 — never generated here).
## Cumulative thresholds:
##   wisdom ≤ 15 : +1 if roll < 0.60, +2 if roll < 0.90, else +3 (60/30/10, exp 1.50)
##   wisdom 16–25: +1 if roll < 0.35, +2 if roll < 0.80, else +3 (35/45/20, exp 1.85)
##   wisdom 26–35: +1 if roll < 0.20, +2 if roll < 0.70, else +3 (20/50/30, exp 2.10)
##   wisdom ≥ 36 : +1 if roll < 0.10, +2 if roll < 0.55, else +3 (10/45/45, exp 2.35)
static func practice_gain(wisdom: int, roll: float) -> int:
	var t1: float = 0.60
	var t2: float = 0.90
	if wisdom >= 36:
		t1 = 0.10
		t2 = 0.55
	elif wisdom >= 26:
		t1 = 0.20
		t2 = 0.70
	elif wisdom >= 16:
		t1 = 0.35
		t2 = 0.80
	if roll < t1:
		return 1
	if roll < t2:
		return 2
	return 3


## 破: gongfa practice experience ×1.5, rounded half-away-from-zero
## (1→2, 2→3, 4→6, 6→9). No extra RNG.
static func pojun_practice(amount: int) -> int:
	return int(round(amount * 1.5))


## 狼 attack side: +8% damage per living enemy of the owner at resolve time.
static func lang_attack_mult(living_enemies: int) -> float:
	return 1.0 + 0.08 * float(living_enemies)


## 狼 defense side: +5% damage reduction per living enemy of the owner.
static func lang_dr(living_enemies: int) -> float:
	return 0.05 * float(living_enemies)


## 杀: heal 20% of the actual HP loss dealt, capped at 15% of the owner's max
## HP per round. `healed_this_round` is the already-consumed per-round budget.
## Never returns below 0 when the budget is exhausted (or its 15% rounds to 0).
static func sha_heal_amount(loss: int, max_hp: int, healed_this_round: int) -> int:
	var cap: int = int(round(max_hp * 0.15)) - healed_this_round
	if cap <= 0:
		return 0
	return min(int(round(loss * 0.2)), cap)
