# ---------------------------------------------------------------------------
# systems/meta_progress.gd — Colección, upgrades lineales y rutas divergentes
# por integrante (Solar / Moonbyul / Wheein / Hwasa).
# ---------------------------------------------------------------------------
class_name MetaProgress
extends RefCounted

const PATH := "user://mamamoo_meta.json"
const VERSION := 3
static var path_override := ""

const UPGRADE_DEFS := {
	"voice_bonus": {"max": 5, "cost": 18, "label": "Voz inicial +4", "desc": "Cada rango suma +4 a la Voz máxima."},
	"start_coins": {"max": 5, "cost": 14, "label": "Monedas iniciales +2", "desc": "Empiezas cada run con más monedas."},
	"composure_rate": {"max": 5, "cost": 16, "label": "Compostura +12%", "desc": "Ganas Compostura más rápido."},
	"shop_discount": {"max": 3, "cost": 22, "label": "Descuento tienda −1", "desc": "Los precios de tienda bajan 1 moneda (mín. 1)."},
}

const PATH_DEFS := {
	"solar": {
		"cost": 45,
		"label": "Ruta Solar",
		"desc": "Habilidades +18% · +12 Compostura al E · curar da Compostura.",
		"member": 0,
	},
	"moonbyul": {
		"cost": 45,
		"label": "Ruta Moonbyul",
		"desc": "Esquiva −20% CD · vel +10% · tras esquivar, disparo +18%.",
		"member": 1,
	},
	"wheein": {
		"cost": 45,
		"label": "Ruta Wheein",
		"desc": "Armonía +25% · switch cura 4 · cadena dura +0.6s.",
		"member": 2,
	},
	"hwasa": {
		"cost": 45,
		"label": "Ruta Hwasa",
		"desc": "Kill Compostura +60% · Ad-lib +12% · a Compostura alta +daño.",
		"member": 3,
	},
}

static func file_path() -> String:
	return path_override if not path_override.is_empty() else PATH

static func _empty() -> Dictionary:
	return {
		"version": VERSION,
		"discovered": [],
		"runs_played": 0,
		"runs_won": 0,
		"runs_lost": 0,
		"star_fragments": 0,
		"best_floor": 1,
		"path": "",
		"upgrades": {
			"voice_bonus": 0,
			"start_coins": 0,
			"composure_rate": 0,
			"shop_discount": 0,
		},
	}

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(file_path()):
		return _empty()
	var file := FileAccess.open(file_path(), FileAccess.READ)
	if file == null:
		return _empty()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _empty()
	var data: Dictionary = parsed
	for key in _empty():
		if not data.has(key):
			data[key] = _empty()[key]
	var ups: Dictionary = data.get("upgrades", {})
	for ukey in _empty()["upgrades"]:
		if not ups.has(ukey):
			ups[ukey] = 0
	data["upgrades"] = ups
	data["version"] = VERSION
	return data

static func save_data(data: Dictionary) -> void:
	data["version"] = VERSION
	var file := FileAccess.open(file_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

static func discover(item_id: String) -> void:
	if item_id.is_empty():
		return
	var data := load_data()
	var found: Array = data.get("discovered", [])
	if not found.has(item_id):
		found.append(item_id)
		data["discovered"] = found
		save_data(data)

static func is_discovered(item_id: String) -> bool:
	return load_data().get("discovered", []).has(item_id)

static func discovered_count() -> int:
	return load_data().get("discovered", []).size()

static func current_path() -> String:
	return str(load_data().get("path", ""))

static func select_path(path_id: String) -> bool:
	if not PATH_DEFS.has(path_id):
		return false
	var data := load_data()
	var current := str(data.get("path", ""))
	var cost := 0 if current.is_empty() else 20
	if current == path_id:
		return true
	if current.is_empty():
		cost = int(PATH_DEFS[path_id].get("cost", 45))
	if int(data.get("star_fragments", 0)) < cost:
		return false
	data["star_fragments"] = int(data.get("star_fragments", 0)) - cost
	data["path"] = path_id
	save_data(data)
	return true

static func clear_path() -> bool:
	var data := load_data()
	if str(data.get("path", "")).is_empty():
		return true
	if int(data.get("star_fragments", 0)) < 15:
		return false
	data["star_fragments"] = int(data.get("star_fragments", 0)) - 15
	data["path"] = ""
	save_data(data)
	return true

static func upgrade_level(id: String) -> int:
	return int(load_data().get("upgrades", {}).get(id, 0))

static func upgrade_cost(id: String) -> int:
	var def: Dictionary = UPGRADE_DEFS.get(id, {})
	var level := upgrade_level(id)
	return int(def.get("cost", 20)) + level * 6

static func can_buy_upgrade(id: String) -> bool:
	var def: Dictionary = UPGRADE_DEFS.get(id, {})
	if def.is_empty():
		return false
	var level := upgrade_level(id)
	if level >= int(def.get("max", 0)):
		return false
	return int(load_data().get("star_fragments", 0)) >= upgrade_cost(id)

static func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	var data := load_data()
	var cost := upgrade_cost(id)
	data["star_fragments"] = int(data.get("star_fragments", 0)) - cost
	var ups: Dictionary = data.get("upgrades", {})
	ups[id] = int(ups.get(id, 0)) + 1
	data["upgrades"] = ups
	save_data(data)
	return true

static func run_bonuses() -> Dictionary:
	var data := load_data()
	var ups: Dictionary = data.get("upgrades", {})
	var path_id := str(data.get("path", ""))
	return {
		"voice_max_bonus": int(ups.get("voice_bonus", 0)) * 4.0,
		"start_coins": int(ups.get("start_coins", 0)) * 2,
		"composure_mult": 1.0 + int(ups.get("composure_rate", 0)) * 0.12,
		"shop_discount": int(ups.get("shop_discount", 0)),
		"path": path_id,
	}

static func record_run(won: bool, floor_reached: int, rooms_cleared: int) -> Dictionary:
	var data := load_data()
	data["runs_played"] = int(data.get("runs_played", 0)) + 1
	if won:
		data["runs_won"] = int(data.get("runs_won", 0)) + 1
	else:
		data["runs_lost"] = int(data.get("runs_lost", 0)) + 1
	data["best_floor"] = maxi(int(data.get("best_floor", 1)), floor_reached)
	var gain := floor_reached * 2 + rooms_cleared
	if won:
		gain += 20
	data["star_fragments"] = int(data.get("star_fragments", 0)) + gain
	save_data(data)
	data["last_fragments_gained"] = gain
	return data
