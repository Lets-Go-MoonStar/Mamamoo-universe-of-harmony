# ---------------------------------------------------------------------------
# actor_art.gd — AnimatedSprite2D. Convierte las hojas de sprites en
# animaciones editables (SpriteFrames):
#   - recorta regiones por filas usando AtlasTexture (sin tocar los PNG),
#   - guarda en caché estático los frames de personajes y enemigos,
#   - expone una API mínima: `configure` (cambiar personaje/enemigo),
#     `locomotion` (idle/move) y `action` (ataque, habilidad, daño...).
# ---------------------------------------------------------------------------
extends AnimatedSprite2D

# Atlas regions use the source artwork directly; no destructive image processing.
const CHARACTERS = [
	preload("res://assets/characters/transparent/solar_spritesheet.png"),
	preload("res://assets/characters/transparent/moonbyul_spritesheet.png"),
	preload("res://assets/characters/transparent/wheein_spritesheet.png"),
	preload("res://assets/characters/transparent/hwasa_spritesheet.png")
]
const RECOVERY = [
	preload("res://assets/characters/recovery/solar_recovery_spritesheet.png"),
	preload("res://assets/characters/recovery/moonbyul_recovery_spritesheet.png"),
	preload("res://assets/characters/recovery/wheein_recovery_spritesheet.png"),
	preload("res://assets/characters/recovery/hwasa_recovery_spritesheet.png")
]
# Hoja única de jefe y hojas dedicadas por arquetipo de enemigo (1024x1536,
# misma rejilla de filas que los personajes: idle/move/attack/ability).
const ENEMY_SHEETS = [
	preload("res://assets/enemies/crimson_reaper_spritesheet.png"),    # 0 chaser
	preload("res://assets/enemies/astral_mage_spritesheet.png"),       # 1 ranged
	preload("res://assets/enemies/neon_assassin_spritesheet.png"),     # 2 resto / default
	preload("res://assets/enemies/crystal_sentinel_spritesheet.png"),  # 3 tank (art_index 4)
	preload("res://assets/enemies/resonance_totem_spritesheet.png")    # 4 swarm (art_index 5)
]
const BOSS_ATLAS = preload("res://assets/enemies/bosses/void_mage_spritesheet.png")
const BOSS_SHEETS = {
	"overlord": preload("res://assets/enemies/bosses/twin_echo/echo_overlord_spritesheet.png"),
	"critic": preload("res://assets/enemies/bosses/crystal_critic/crystal_critic_spritesheet.png")
}
var display_width := 84.0
# Caché compartida entre todas las instancias: evita recrear frames en cada spawn.
static var character_cache: Dictionary = {}
static var enemy_cache: Dictionary = {}
# Tiempo restante de la animación de "acción" (mientras dure, no vuelve a idle/move).
var action_time := 0.0
var dead := false

# Añade una fila de la hoja como animación: recorta `count` celdas iguales
# dentro de la tira vertical (top -> bottom) y las registra con fps/loop.
func add_row(frames: SpriteFrames, sheet: Texture2D, anim: String, top: int, bottom: int, columns: int, count: int, fps: float, looping: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, looping)
	var cell_width := float(sheet.get_width()) / columns
	for column in range(count):
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = sheet
		frame_texture.region = Rect2(column * cell_width, top, cell_width, bottom - top)
		frame_texture.filter_clip = true
		frames.add_frame(anim, frame_texture)

# Prepara el sprite para un personaje (index 0-3) o enemigo (is_enemy).
# Construye los frames la primera vez y los reutiliza de la caché después;
# también ajusta la escala para un ancho de visualización fijo.
func configure(index: int, is_enemy: bool = false, boss_id: String = "") -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var cache: Dictionary = enemy_cache if is_enemy else character_cache
	var cache_key: String = "%d:%s" % [index, boss_id] if is_enemy else str(index)
	if not cache.has(cache_key):
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		if not is_enemy:
			var sheet: Texture2D = CHARACTERS[index]
			add_row(frames, sheet, "idle", 0, 280, 4, 4, 5.0, true)
			add_row(frames, sheet, "move", 280, 540, 4, 4, 9.0, true)
			add_row(frames, sheet, "attack", 540, 780, 4, 4, 16.0, false)
			add_row(frames, sheet, "ability", 780, 1040, 4, 4, 9.0, false)
			add_row(frames, sheet, "dodge", 1040, 1250, 4, 4, 18.0, false)
			var recovery: Texture2D = RECOVERY[index]
			# Rows are not evenly spaced: hurt / falling / prone / rising.
			add_row(frames, recovery, "hurt", 0, 360, 4, 2, 10.0, false)
			add_row(frames, recovery, "death", 360, 650, 4, 4, 8.0, false)
			add_row(frames, recovery, "recover", 875, 1254, 4, 4, 6.0, false)
		else:
			var sheet: Texture2D = BOSS_SHEETS.get(boss_id, BOSS_ATLAS) if index == 3 else ENEMY_SHEETS[{0: 0, 1: 1, 2: 2, 4: 3, 5: 4}.get(index, 0)]
			if index == 3:
				for row in range(8):
					var action_name: String = ["idle", "move", "attack_1", "attack_2", "special", "phase_change", "hurt", "death"][row]
					for direction in range(8):
						var animation_name := "%s_%s" % [action_name, ["s", "se", "e", "ne", "n", "nw", "w", "sw"][direction]]
						var texture := AtlasTexture.new()
						texture.atlas = sheet
						texture.region = Rect2(direction * 128, row * 128, 128, 128)
						texture.filter_clip = true
						frames.add_animation(animation_name)
						frames.set_animation_speed(animation_name, 6.0)
						frames.set_animation_loop(animation_name, row < 2)
						frames.add_frame(animation_name, texture)
				# Compatibility aliases used by the existing enemy controller.
				for alias in ["idle", "move", "attack", "ability"]:
					var source: String = {"idle": "idle_s", "move": "move_s", "attack": "attack_1_s", "ability": "special_s"}[alias]
					frames.add_animation(alias)
					for frame_index in range(4):
						frames.add_frame(alias, frames.get_frame_texture(source, 0))
			else:
				# Hojas dedicadas 1024x1536: misma rejilla que los personajes.
				add_row(frames, sheet, "idle", 0, 280, 4, 4, 6.0, true)
				add_row(frames, sheet, "move", 280, 540, 4, 4, 8.0, true)
				add_row(frames, sheet, "attack", 540, 780, 4, 4, 8.0, false)
				add_row(frames, sheet, "ability", 780, 1040, 4, 4, 8.0, false)
		cache[cache_key] = frames
	sprite_frames = cache[cache_key]
	display_width = (116.0 if index == 3 else 76.0) if is_enemy else 84.0
	dead = false
	action_time = 0.0
	play("idle")
	_align_feet()

# Coloca los pies del sprite sobre el centro del nodo (ajuste de alto).
func _align_feet() -> void:
	var current := sprite_frames.get_frame_texture(animation, frame)
	scale = Vector2.ONE * display_width / current.get_width()
	position.y = -current.get_height() * scale.y * 0.5 + 14.0

func _process(delta: float) -> void:
	action_time = maxf(0.0, action_time - delta)
	_align_feet()

# Estado de locomoción: reproduce move/idle según si se desplaza y orienta
# horizontalmente con `direction`. NO interrumpe una acción en curso.
func locomotion(moving: bool, direction: float) -> void:
	if dead:
		return
	if absf(direction) > 0.05:
		flip_h = direction < 0.0
	if action_time <= 0.0:
		play("move" if moving else "idle")

# Reproduce una animación puntual (`attack`, `ability`, `hurt`, `death`...)
# durante `duration` segundos; `death` además marca al actor como caído.
func action(anim: String, duration: float) -> void:
	if dead or not sprite_frames.has_animation(anim):
		return
	action_time = duration
	stop()
	play(anim)
	if anim == "death":
		dead = true
