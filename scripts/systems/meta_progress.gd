# ---------------------------------------------------------------------------
# systems/meta_progress.gd — Progreso permanente entre runs (colección +
# contadores). Independiente de SessionStore (partida en curso).
# ---------------------------------------------------------------------------
class_name MetaProgress
extends RefCounted

const PATH := "user://mamamoo_meta.json"
const VERSION := 1
static var path_override := ""

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
	if int(data.get("version", 0)) != VERSION:
		return _empty()
	for key in _empty():
		if not data.has(key):
			data[key] = _empty()[key]
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
