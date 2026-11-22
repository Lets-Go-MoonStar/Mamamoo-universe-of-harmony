# ---------------------------------------------------------------------------
# systems/session_store.gd — Persistencia de la partida en curso (user://).
# Guarda inventario + progreso de piso para reanudar entre sesiones.
# ---------------------------------------------------------------------------
class_name SessionStore
extends RefCounted

const PATH := "user://mamamoo_session.json"
const VERSION := 1
# Tests pueden redirigir el archivo sin tocar la partida real.
static var path_override := ""

static func file_path() -> String:
	return path_override if not path_override.is_empty() else PATH

static func has_save() -> bool:
	return FileAccess.file_exists(file_path())

static func clear() -> void:
	var path := file_path()
	if not FileAccess.file_exists(path):
		return
	var dir_path := path.get_base_dir()
	var file_name := path.get_file()
	var dir := DirAccess.open(dir_path)
	if dir != null:
		dir.remove(file_name)

static func write(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = VERSION
	var file := FileAccess.open(file_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true

static func read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(file_path(), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		return {}
	return data
