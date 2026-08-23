## AIControllerSparring — the sparring partner's trivial wait-AI (design C7/C8).
##
## evaluate() always returns {} (the base's no-op decision): the partner never
## moves, never attacks, and never casts — a stationary damage dummy for the
## cultivation->combat 发挥度 comparison. Mirrors ai_base.gd's contract
## (extends the base, one evaluate(enemy) -> Dictionary decision dict).
## Requires NO tutorial content — it works in any battle context.
extends "res://scripts/ai/ai_base.gd"


func evaluate(enemy: Node) -> Dictionary:
	return {}
