extends SceneTree
# Verifica que los atlas / hojas referenciados cargan y tienen regiones útiles.
# godot --headless --path . --fixed-fps 60 --script res://tests/visual_integration.gd

const VISUALS = preload("res://scripts/visual_assets.gd")
const ACTOR_ART = preload("res://scripts/actor_art.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func run() -> void:
	var sheets := {
		"projectiles": VISUALS.PROJECTILES,
		"combat": VISUALS.COMBAT,
		"status": VISUALS.STATUS,
		"abilities": VISUALS.ABILITIES,
		"icons": VISUALS.ICONS,
		"architecture": VISUALS.ARCHITECTURE,
		"overview": VISUALS.OVERVIEW,
		"echo_abilities": VISUALS.ECHO_ABILITIES,
		"critic_abilities": VISUALS.CRITIC_ABILITIES,
		"map_icons": VISUALS.MAP_ICONS,
		"lunar": VISUALS.LUNAR_TILESET,
		"neon": VISUALS.NEON_TILESET,
	}
	for name in sheets.keys():
		var tex: Texture2D = sheets[name]
		check(tex != null and tex.get_width() > 0 and tex.get_height() > 0, "Atlas %s carga con tamaño > 0" % name)

	for index in range(4):
		var cell := VISUALS.cell(VISUALS.MAP_ICONS, index, 0, 12, 12)
		check(cell != null and cell.region.size.x > 0, "Celda de mapa índice %d" % index)

	for member in range(4):
		var regions := VISUALS.elemental_regions(member)
		check(regions.size() == 4, "Regiones elementales miembro %d" % member)

	for enemy_index in range(ACTOR_ART.ENEMY_SHEETS.size()):
		var sheet: Texture2D = ACTOR_ART.ENEMY_SHEETS[enemy_index]
		check(sheet != null and sheet.get_width() > 0, "Hoja enemigo índice %d" % enemy_index)

	for path in [
		"res://assets/characters/transparent/solar_spritesheet.png",
		"res://assets/characters/transparent/moonbyul_spritesheet.png",
		"res://assets/characters/transparent/wheein_spritesheet.png",
		"res://assets/characters/transparent/hwasa_spritesheet.png",
		"res://assets/ui/ui_hud_spritesheet.png",
		"res://assets/ui/portraits/member_portraits_atlas.png",
		"res://assets/backgrounds/eclipse_arena_background.png",
	]:
		check(ResourceLoader.exists(path), "Existe %s" % path)

	print("VISUAL INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
