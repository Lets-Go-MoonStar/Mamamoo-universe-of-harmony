extends RefCounted
# Shared, non-destructive atlas regions. All effects are cosmetic children.
const PROJECTILES = preload("res://assets/vfx/projectiles_atlas.png")
const COMBAT = preload("res://assets/vfx/combat_effects_atlas.png")
const STATUS = preload("res://assets/vfx/status_effects_atlas.png")
const ABILITIES = preload("res://assets/vfx/elemental_abilities_atlas.png")
const ICONS = preload("res://assets/ui/icons/rewards_and_card_frames_atlas.png")
const ARCHITECTURE = preload("res://assets/environment/tilesets/celestial_architecture_atlas.png")
const OVERVIEW = preload("res://assets/enemies/atlases/enemy_variants_overview.png")
const ECHO_ABILITIES = preload("res://assets/vfx/bosses/echo_overlord_abilities_atlas.png")
const CRITIC_ABILITIES = preload("res://assets/vfx/bosses/crystal_critic_abilities_atlas.png")
const MAP_ICONS = preload("res://assets/ui/icons/status_and_map_icons_atlas.png")
const LUNAR_TILESET = preload("res://assets/environment/lunar_ruins/tiles/lunar_ruins_production_tileset.png")
const NEON_TILESET = preload("res://assets/environment/neon_district/tiles/neon_district_production_tileset.png")

static func region(sheet: Texture2D, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = rect
	texture.filter_clip = true
	return texture

static func icon_cell(index: int) -> AtlasTexture:
	var bands := [0, 315, 610, 900, 1254]
	var row := index / 4
	return region(ICONS, Rect2((index % 4) * 313.5, bands[row], 313.5, bands[row + 1] - bands[row]))

static func flash(parent: Node, texture: Texture2D, width: float, offset := Vector2.ZERO) -> void:
	var node := sprite(parent, texture, width, offset)
	node.z_index = 2
	var fade := node.create_tween()
	fade.tween_property(node, "modulate:a", 0.0, 0.45)
	fade.tween_callback(node.queue_free)

static func cell(sheet: Texture2D, column: int, row: int, columns: int, rows: int) -> AtlasTexture:
	var size := sheet.get_size() / Vector2(columns, rows)
	return region(sheet, Rect2(Vector2(column, row) * size, size))

static func sprite(parent: Node, texture: Texture2D, width: float, offset := Vector2.ZERO) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = texture
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.scale = Vector2.ONE * width / texture.get_width()
	node.position = offset
	parent.add_child(node)
	return node

# Número/aviso flotante (daño, botín, peligro).
static func float_text(parent: Node, world_pos: Vector2, text: String, color: Color = Color.WHITE, rise := 42.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 8
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	label.global_position = world_pos + Vector2(-18, -28)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - rise, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(label.queue_free)

static func burst(parent: Node, sheet: Texture2D, row: int, rows: int, width: float, offset := Vector2.ZERO, duration := 0.45, regions: Array[Rect2] = []) -> AnimatedSprite2D:
	var node := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	var count := regions.size() if not regions.is_empty() else 4
	frames.set_animation_speed("default", count / duration)
	for column in range(count):
		frames.add_frame("default", region(sheet, regions[column]) if not regions.is_empty() else cell(sheet, column, row, 4, rows))
	node.sprite_frames = frames
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.scale = Vector2.ONE * width / frames.get_frame_texture("default", 0).get_width()
	node.position = offset
	node.z_index = 2
	parent.add_child(node)
	node.animation_finished.connect(node.queue_free)
	node.play()
	return node

# The elemental sheet has seven large columns at the top and eleven below.
# Use only the matching element's lower sequence, inset to exclude cell borders.
static func elemental_regions(member: int) -> Array[Rect2]:
	var bands := [Vector2(320, 440), Vector2(555, 680), Vector2(808, 935), Vector2(1062, 1207)]
	var band: Vector2 = bands[clampi(member, 0, 3)]
	var start_column := 4 if member == 1 else 0
	var regions: Array[Rect2] = []
	for column in range(start_column, start_column + 4):
		regions.append(Rect2(column * 114 + 3, band.x + 3, 108, band.y - band.x - 6))
	return regions

static func elemental_burst(parent: Node, member: int) -> AnimatedSprite2D:
	return burst(parent, ABILITIES, 0, 1, 100.0, Vector2(0, -30), 0.45, elemental_regions(member))

static func boss_ability_burst(parent: Node, boss_id: String, row: int, width := 120.0) -> AnimatedSprite2D:
	var sheet: Texture2D = ECHO_ABILITIES if boss_id == "overlord" else CRITIC_ABILITIES
	var regions: Array[Rect2] = []
	var cell_size: float = sheet.get_width() / 8.0
	for column in range(4):
		regions.append(Rect2(column * cell_size + 2, row * cell_size + 2, cell_size - 4, cell_size - 4))
	return burst(parent, sheet, row, 8, width, Vector2(0, -30), 0.55, regions)

static func room_icon(room_type: String) -> AtlasTexture:
	var index: int = {"START": 0, "COMBAT": 1, "ELITE": 2, "EVENT": 3, "SHOP": 4, "REWARD": 5, "REST": 6, "BOSS": 7}.get(room_type, 8)
	return cell(MAP_ICONS, index, 0, 12, 12)
