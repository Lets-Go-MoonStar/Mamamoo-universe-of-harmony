# ---------------------------------------------------------------------------
# room_modifier.gd — Modifiers de sala (capa de variedad a 20+ runs).
# Cambian reglas del encuentro, no solo spawns: otra camada de replay.
# ---------------------------------------------------------------------------
class_name RoomModifier
extends RefCounted

const DEFS := {
	"high_tempo": {
		"label": "High Tempo",
		"desc": "Enemigos +18% vel · tú +8% vel",
		"enemy_speed": 1.18,
		"player_speed": 1.08,
	},
	"spotlight": {
		"label": "Spotlight",
		"desc": "Das +12% daño · recibes +15%",
		"damage_dealt": 1.12,
		"damage_taken": 1.15,
	},
	"muted_stage": {
		"label": "Muted Stage",
		"desc": "Habilidad +35% CD · Compostura +20%",
		"ability_cd": 1.35,
		"composure_gain": 1.20,
	},
	"harmony_drain": {
		"label": "Harmony Drain",
		"desc": "Armonía cae 4/s · kills +6 Compostura",
		"harmony_drain": 4.0,
		"kill_composure": 1.25,
	},
	"dense_fog": {
		"label": "Dense Fog",
		"desc": "Más zonas · tú −10% vel",
		"extra_hazards": 1,
		"player_speed": 0.90,
	},
	"encore_pressure": {
		"label": "Encore Pressure",
		"desc": "Compostura −25% · Ad-lib daño +10% si activo",
		"composure_gain": 0.75,
		"adlib_damage": 1.10,
	},
}

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in DEFS.keys():
		ids.append(str(key))
	return ids

static func pick(rng: RandomNumberGenerator, floor_number: int, room_type: String) -> String:
	if floor_number < 5:
		return ""
	if room_type == "COMBAT" and rng.randf() > 0.40:
		return ""
	if room_type == "ELITE" and rng.randf() > 0.85:
		return ""
	if room_type not in ["COMBAT", "ELITE"]:
		return ""
	var ids: Array[String] = []
	for id in all_ids():
		# Late floors desbloquean pressure/drain.
		if floor_number < 8 and id in ["encore_pressure", "harmony_drain"]:
			continue
		ids.append(id)
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]

static func apply(player: Node, mod_id: String) -> Dictionary:
	clear(player)
	if mod_id.is_empty() or not DEFS.has(mod_id):
		return {}
	var def: Dictionary = DEFS[mod_id]
	player.room_mod_id = mod_id
	player.room_player_speed_mult = float(def.get("player_speed", 1.0))
	player.room_damage_dealt_mult = float(def.get("damage_dealt", 1.0))
	player.room_damage_taken_mult = float(def.get("damage_taken", 1.0))
	player.room_composure_mult = float(def.get("composure_gain", 1.0))
	player.room_ability_cd_mult = float(def.get("ability_cd", 1.0))
	player.room_harmony_drain = float(def.get("harmony_drain", 0.0))
	player.room_kill_composure_mult = float(def.get("kill_composure", 1.0))
	player.room_adlib_damage_mult = float(def.get("adlib_damage", 1.0))
	player.room_enemy_speed_mult = float(def.get("enemy_speed", 1.0))
	player.room_extra_hazards = int(def.get("extra_hazards", 0))
	return def

static func clear(player: Node) -> void:
	player.room_mod_id = ""
	player.room_player_speed_mult = 1.0
	player.room_damage_dealt_mult = 1.0
	player.room_damage_taken_mult = 1.0
	player.room_composure_mult = 1.0
	player.room_ability_cd_mult = 1.0
	player.room_harmony_drain = 0.0
	player.room_kill_composure_mult = 1.0
	player.room_adlib_damage_mult = 1.0
	player.room_enemy_speed_mult = 1.0
	player.room_extra_hazards = 0
