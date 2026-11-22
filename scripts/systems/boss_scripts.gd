# ---------------------------------------------------------------------------
# boss_scripts.gd — Comportamientos propios por jefe (no clones de phase_storm).
# main llama on_phase / pattern_for; cada id tiene firma distinta.
# ---------------------------------------------------------------------------
class_name BossScripts
extends RefCounted

# Patrón de hazard + estilo + extras por jefe/fase.
static func pattern_for(boss_id: String, phase: int) -> Dictionary:
	match boss_id:
		"overlord":
			# Eco: anillo que se estrecha (más zonas, radio menor).
			return {"pattern": "ring", "count": 4 if phase >= 3 else 3, "style": "storm", "rad_mult": 0.85, "dmg_mult": 0.9, "label": "ECHO RING"}
		"critic":
			# Crítico: esquinas + telegraphs densos.
			return {"pattern": "corners", "count": 4, "style": "elite", "rad_mult": 1.0, "dmg_mult": 1.1, "label": "CRYSTAL CORNERS"}
		"crystal_warden":
			# Warden: lanes que bloquean el escenario.
			return {"pattern": "lanes", "count": 2 if phase == 2 else 3, "style": "storm", "rad_mult": 1.15, "dmg_mult": 1.0, "label": "WARDEN LANES"}
		"void_conductor":
			# Void: diagonal → lanes (metrónomo).
			if phase >= 3:
				return {"pattern": "lanes", "count": 3, "style": "storm", "rad_mult": 1.05, "dmg_mult": 1.2, "label": "VOID BEAT"}
			return {"pattern": "diagonal", "count": 4, "style": "storm", "rad_mult": 1.0, "dmg_mult": 1.15, "label": "VOID DIAGONAL"}
		"eclipse":
			# Eclipse: ring → diagonal → cross (ya conocido, firma propia).
			match phase:
				2:
					return {"pattern": "ring", "count": 3, "style": "storm", "rad_mult": 1.0, "dmg_mult": 1.0, "label": "ECLIPSE RING"}
				3:
					return {"pattern": "diagonal", "count": 4, "style": "storm", "rad_mult": 1.05, "dmg_mult": 1.1, "label": "ECLIPSE CUT"}
				_:
					return {"pattern": "cross", "count": 4, "style": "storm", "rad_mult": 1.1, "dmg_mult": 1.15, "label": "ECLIPSE CROSS"}
		_:
			return {"pattern": "ring", "count": 3, "style": "storm", "rad_mult": 1.0, "dmg_mult": 1.0, "label": "PHASE STORM"}

# Buffs al jefe en cambio de fase (velocidad / daño / telegraph).
static func apply_phase_buff(enemy: Node, boss_id: String, phase: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	match boss_id:
		"overlord":
			enemy.move_speed *= 1.08
			if phase >= 3 and enemy.has_method("_begin_telegraph"):
				enemy.attack_cooldown = maxf(0.55, enemy.attack_cooldown * 0.85)
		"critic":
			enemy.contact_damage *= 1.10
		"crystal_warden":
			enemy.move_speed *= 0.92 # más tank, zonas hacen el trabajo
			enemy.contact_damage *= 1.12
		"void_conductor":
			enemy.move_speed *= 1.12
			enemy.attack_cooldown = maxf(0.50, enemy.attack_cooldown * 0.80)
		"eclipse":
			if phase >= 3:
				enemy.contact_damage *= 1.15
		_:
			pass

static func sfx_for(boss_id: String) -> String:
	return "boss" if boss_id in ["overlord", "critic", "eclipse", "void_conductor", "crystal_warden"] else "phase"
