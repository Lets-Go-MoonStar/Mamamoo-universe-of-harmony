# ---------------------------------------------------------------------------
# playtest_log.gd — Telemetría de runs humanas (5×ruta). Append JSONL.
# ---------------------------------------------------------------------------
class_name PlaytestLog
extends RefCounted

const PATH := "user://playtest_runs.jsonl"
static var path_override := ""
static var active := true
static var _run: Dictionary = {}

static func file_path() -> String:
	return path_override if not path_override.is_empty() else PATH

static func begin_run(path_id: String, seed_value: int) -> void:
	if not active:
		return
	_run = {
		"started_at": Time.get_datetime_string_from_system(),
		"path": path_id,
		"seed": seed_value,
		"floors": 1,
		"rooms_cleared": 0,
		"bosses": 0,
		"mods": [],
		"boss_phases": [],
		"deaths": 0,
		"won": false,
		"notes": "",
	}

static func note_floor(floor_number: int) -> void:
	if _run.is_empty():
		return
	_run["floors"] = maxi(int(_run.get("floors", 1)), floor_number)

static func note_room_clear() -> void:
	if _run.is_empty():
		return
	_run["rooms_cleared"] = int(_run.get("rooms_cleared", 0)) + 1

static func note_mod(mod_id: String) -> void:
	if _run.is_empty() or mod_id.is_empty():
		return
	var mods: Array = _run.get("mods", [])
	mods.append(mod_id)
	_run["mods"] = mods

static func note_boss_phase(boss_id: String, phase: int) -> void:
	if _run.is_empty():
		return
	var phases: Array = _run.get("boss_phases", [])
	phases.append("%s:p%d" % [boss_id, phase])
	_run["boss_phases"] = phases

static func note_boss_clear() -> void:
	if _run.is_empty():
		return
	_run["bosses"] = int(_run.get("bosses", 0)) + 1

static func note_death() -> void:
	if _run.is_empty():
		return
	_run["deaths"] = int(_run.get("deaths", 0)) + 1

static func finish_run(won: bool, extra: Dictionary = {}) -> String:
	if _run.is_empty():
		return ""
	_run["won"] = won
	_run["ended_at"] = Time.get_datetime_string_from_system()
	for key in extra:
		_run[key] = extra[key]
	var line := JSON.stringify(_run)
	var file := FileAccess.open(file_path(), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path(), FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(line)
		file.close()
	var saved_path := file_path()
	_run = {}
	return saved_path

static func count_runs_for_path(path_id: String) -> int:
	if not FileAccess.file_exists(file_path()):
		return 0
	var file := FileAccess.open(file_path(), FileAccess.READ)
	if file == null:
		return 0
	var n := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("path", "")) == path_id:
			n += 1
	file.close()
	return n

static func coverage_summary() -> Dictionary:
	var out := {"solar": 0, "moonbyul": 0, "wheein": 0, "hwasa": 0, "none": 0}
	if not FileAccess.file_exists(file_path()):
		return out
	var file := FileAccess.open(file_path(), FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var pid := str(parsed.get("path", ""))
		if pid.is_empty():
			pid = "none"
		if out.has(pid):
			out[pid] = int(out[pid]) + 1
		else:
			out[pid] = 1
	file.close()
	return out
