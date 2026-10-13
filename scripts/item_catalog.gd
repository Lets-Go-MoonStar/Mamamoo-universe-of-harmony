# ---------------------------------------------------------------------------
# item_catalog.gd — Catálogo estático de ítems (RefCounted, sin nodo).
#   - carga `data/items.json` una sola vez (caché estática),
#   - acceso por identificador (`entry`) y
#   - genera el AtlasTexture del icono desde las hojas de sprites
#     (reward_items_spritesheet / relic_items_spritesheet), usando la
#     celda definida en el JSON.
# ---------------------------------------------------------------------------
extends RefCounted

const VISUALS = preload("res://scripts/visual_assets.gd")

const SHEETS = [preload("res://assets/items/reward_items_spritesheet.png"), preload("res://assets/items/relic_items_spritesheet.png")]
static var records: Array = []

# Todos los registros del catálogo; se parsean del JSON en el primer acceso.
static func all() -> Array:
	if records.is_empty():
		records = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	return records

# Busca un ítem del catálogo por su identificador ("" si no existe).
static func entry(id: String) -> Dictionary:
	for item in all():
		if item.id == id:
			return item
	return {}

# Icono del ítem: cada hoja está dividida en una cuadrícula de 4x4 celdas;
# la celda indicada en el JSON se recorta con AtlasTexture.
static func icon(id: String) -> AtlasTexture:
	var item := entry(id)
	if item.is_empty():
		return AtlasTexture.new()
	var new_cells := {"star_coin": 0, "golden_key": 1, "heart_recovery_potion": 2, "echo_orb": 3, "music_note_gem": 4, "flame_emblem": 5, "exp_star_orb": 6, "treasure_chest": 7}
	if new_cells.has(id):
		var index: int = new_cells[id]
		return VISUALS.icon_cell(index)
	var sheet: Texture2D = SHEETS[int(item.sheet)]
	var size := Vector2(sheet.get_size()) / 4.0
	var cell := int(item.cell)
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(Vector2(cell % 4, cell / 4) * size, size)
	texture.filter_clip = true
	return texture
