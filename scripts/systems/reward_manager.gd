# ---------------------------------------------------------------------------
# systems/reward_manager.gd — Probabilidades de rareza (sección 13-14) y
# selección de recompensas según el tipo de sala. Las probabilidades base son
# 45/30/15/8/2 y pueden variar por sala (élite y jefe mejoran Rare/Epic/Leg).
# ---------------------------------------------------------------------------
class_name RewardManager
extends RefCounted

const RARITIES := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const BASE_WEIGHTS := {"COMMON": 45.0, "UNCOMMON": 30.0, "RARE": 15.0, "EPIC": 8.0, "LEGENDARY": 2.0}

# Pesos por tipo de sala: normal (base), élite (Rare+ arriba), jefe (mejor
# pool de 3), recompensa/reward (similar a élite), resto base.
static func weights_for(kind: String) -> Dictionary:
	var weights := BASE_WEIGHTS.duplicate()
	match kind:
		"elite", "reward":
			weights["COMMON"] = 20.0
			weights["UNCOMMON"] = 28.0
			weights["RARE"] = 28.0
			weights["EPIC"] = 18.0
			weights["LEGENDARY"] = 6.0
		"boss":
			weights["COMMON"] = 0.0
			weights["UNCOMMON"] = 18.0
			weights["RARE"] = 32.0
			weights["EPIC"] = 34.0
			weights["LEGENDARY"] = 16.0
	return weights

# Lanza una rareza según los pesos de la sala.
static func roll_rarity(kind: String, rng: RandomNumberGenerator) -> String:
	var weights := weights_for(kind)
	var total := 0.0
	for rarity in RARITIES:
		total += weights[rarity]
	var roll := rng.randf() * total
	var cumulative := 0.0
	for rarity in RARITIES:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity
	return "COMMON"

# Peso de un ítem para elegir dentro de una rareza (mismos pesos base).
static func rarity_weight(rarity: String) -> int:
	return int(BASE_WEIGHTS.get(rarity, 0))

# ¿Este ítem puede caer en este tipo de sala? (el jefe nunca da comunes, etc.)
static func allowed_in(kind: String, rarity: String) -> bool:
	return weights_for(kind)[rarity] > 0.0