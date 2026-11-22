# ---------------------------------------------------------------------------
# systems/encounter_director.gd — El equivalente al DifficultyDirector de la
# sección 4 y 19, pero aplicado a cada sala ANTES de entrar (nunca a mitad
# de combate). Decide:
#   - qué enemigos entran según el presupuesto de dificultad de la sala,
#   - variantes élites y su colocación en oleadas posteriores,
#   - división en oleadas si el número supera el tope de activos.
# Toda la selección usa el rng de la run (seed reproducible).
# ---------------------------------------------------------------------------
class_name EncounterDirector
extends RefCounted

# Costes base por variante, según la tabla de la sección 4 (referencia).
const COST_HINTS = {
	"echo": 1, "feedback": 2, "mute": 2, "tuner": 3,
	"echo_elite": 4, "feedback_elite": 5,
}

# Tope de enemigos simultáneos por tamaño de sala (sección 5): Small/Med/Large.
static func max_active(tier: String) -> int:
	match tier:
		"large": return 10
		"medium": return 7
		_: return 4

# Construye la composición de la sala. Devuelve oleadas: Array de Array de
# EnemyData. `budget` es el coste total disponible en la sala.
static func build_encounter(
	pool: Array, budget: int, rng: RandomNumberGenerator, floor_number: int,
	tier: String = "medium"
) -> Array:
	# Solo enemigos que puedan aparecer en este piso.
	var valid: Array = pool.filter(func(e):
		return e is EnemyData and e.min_floor <= floor_number and e.max_floor >= floor_number)
	if valid.is_empty():
		valid = pool.duplicate()
	if valid.is_empty():
		return []

	# Selección por presupuesto. En pisos altos favorece variedad de arquetipos
	# y firma de élites para evitar oleadas monótonas.
	var picks: Array = []
	if budget <= 0:
		return picks
	var remaining := budget
	var guard := 0
	var used_arch: Dictionary = {}
	while remaining > 0 and guard < 300:
		guard += 1
		var affordable: Array = valid.filter(func(e): return e.difficulty_cost <= remaining)
		if affordable.is_empty():
			break
		var preferred: Array = affordable
		if floor_number >= 8 and used_arch.size() < 3:
			var diversify: Array = affordable.filter(func(e): return not used_arch.has(e.archetype))
			if not diversify.is_empty():
				preferred = diversify
		# Pico de diseño: chance extra de élite memorable en tramo largo.
		if floor_number >= 8 and rng.randf() < 0.22:
			var elites_only: Array = preferred.filter(func(e): return e.is_elite)
			if not elites_only.is_empty():
				preferred = elites_only
		var chosen: EnemyData = preferred[rng.randi_range(0, preferred.size() - 1)]
		picks.append(chosen)
		used_arch[chosen.archetype] = true
		remaining -= chosen.difficulty_cost

	# Los élites se reservan para oleadas posteriores (sección 5).
	var normals: Array = picks.filter(func(e): return not e.is_elite)
	var elites: Array = picks.filter(func(e): return e.is_elite)
	var ordered: Array = normals + elites

	# División en oleadas respetando el tope de activos; cada sala termina
	# cuando se agota la última oleada.
	var waves: Array = []
	var active := max_active(tier)
	if ordered.size() <= active:
		waves.append(ordered)
	else:
		var current: Array = []
		for enemy in ordered:
			if current.size() >= active:
				waves.append(current)
				current = []
			current.append(enemy)
		if not current.is_empty():
			waves.append(current)
	return waves

# Coste total de una oleada (para debug/HUD).
static func wave_cost(wave: Array) -> int:
	var total := 0
	for enemy in wave:
		total += enemy.difficulty_cost
	return total