# ---------------------------------------------------------------------------
# combat_hud.gd — HUD de combate (Control). Dibuja la interfaz usando las
# hojas `ui_hud_spritesheet.png`, `ui_menus_spritesheet.png`, los retratos de
# `member_portraits_atlas.png` y los marcos de `member_frames_hud_atlas.png`
# vía AtlasTexture:
#   - barras de Voz y Armonía, nombre de integrante, cadena y cooldowns,
#   - botones de cambio de integrante (1-4) con retrato y marco propio,
#   - paneles de derrota / victoria / resumen, pausa e intros de piso/jefe.
# ---------------------------------------------------------------------------
extends Control

const HUD_SHEET = preload("res://assets/ui/ui_hud_spritesheet.png")
const MENU_SHEET = preload("res://assets/ui/ui_menus_spritesheet.png")
const PORTRAITS = preload("res://assets/ui/portraits/member_portraits_atlas.png")
const FRAMES = preload("res://assets/ui/member_frames_hud_atlas.png")
const VICTORY_ART = preload("res://assets/ui/screens/victory_reference.png")
const DEFEAT_ART = preload("res://assets/ui/screens/game_over_reference.png")
const SUMMARY_ART = preload("res://assets/ui/screens/run_summary_reference.png")
const PAUSE_ART = preload("res://assets/ui/screens/pause_reference.png")
const FLOOR_INTRO_ART = preload("res://assets/ui/screens/floor_intro_reference.png")
const BOSS_INTRO_ART = preload("res://assets/ui/screens/boss_intro_reference.png")
const META = preload("res://scripts/systems/meta_progress.gd")
const SFX = preload("res://scripts/systems/sfx.gd")
const SESSION = preload("res://scripts/systems/session_store.gd")

var voice_bar: TextureProgressBar
var harmony_bar: TextureProgressBar
var voice_text: Label
var harmony_text: Label
var member_text: Label
var chain_text: Label
var cooldown_text: Label
var member_buttons: Array[TextureButton] = []
var member_health_labels: Array[Label] = []
var defeat_panel: Control
var pause_panel: Control
var intro_panel: Control
var intro_title: Label
var intro_body: Label
var intro_timer := 0.0
var end_title: Label
var end_body: Label
var end_art: TextureRect
var summary_art: TextureRect
var player: HarmonyPlayer
var paused_game := false
var hurt_vignette: ColorRect

# Recorta una región de una hoja de sprites en un AtlasTexture.
func atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	texture.filter_clip = true
	return texture

# Crea un TextureRect posicionado (ignora clics del ratón).
func picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.texture = texture
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	view.position = rect.position
	view.size = rect.size
	return view

# Crea una etiqueta con sombra y fuente escalada.
func label_at(parent: Node, text: String, rect: Rect2, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

# Construye una barra de progreso con el marco y el relleno de la hoja HUD.
# `blue` elige el diseño/relleno de Armonía (azul) frente al de Voz.
func meter(origin: Vector2, blue: bool) -> TextureProgressBar:
	var source_x := 350 if blue else 18
	picture(self, atlas(HUD_SHEET, Rect2(source_x, 44, 325, 78)), Rect2(origin, Vector2(325, 78)))
	var bar := TextureProgressBar.new()
	bar.position = origin + Vector2(86, 29)
	bar.texture_progress = atlas(HUD_SHEET, Rect2(440 if blue else 104, 294 if blue else 293, 194, 27))
	bar.max_value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar

# Monta todos los elementos del HUD y el panel de derrota.
func setup(target: HarmonyPlayer) -> void:
	player = target
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label_at(self, "UNIVERSE OF HARMONY", Rect2(24, 8, 340, 24), 19)
	voice_bar = meter(Vector2(16, 36), false)
	harmony_bar = meter(Vector2(350, 36), true)
	voice_text = label_at(self, "", Rect2(110, 44, 220, 24))
	harmony_text = label_at(self, "", Rect2(444, 44, 220, 24))
	member_text = label_at(self, "", Rect2(708, 16, 550, 26), 18)
	chain_text = label_at(self, "SIN CADENA", Rect2(708, 46, 550, 24))
	cooldown_text = label_at(self, "", Rect2(708, 74, 550, 24), 14)
	var frame_rows := [0, 250, 478, 708, 950]
	var names := ["Solar", "Moonbyul", "Wheein", "Hwasa"]
	for index in range(4):
		var button := TextureButton.new()
		button.position = Vector2(24 + index * 112, 594)
		button.size = Vector2(64, 64)
		# Five expressions per row; one row per member. Use the first portrait.
		button.texture_normal = atlas(PORTRAITS, Rect2(0, index * 280.5, 280.4, 280.5))
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.tooltip_text = "%s — tecla %d" % [names[index], index + 1]
		button.pressed.connect(func(): player.switch_to(index))
		add_child(button)
		member_buttons.append(button)
		# Overlay only one frame, with input passing through to the portrait.
		picture(self, atlas(FRAMES, Rect2(0, frame_rows[index], 250, frame_rows[index + 1] - frame_rows[index])), Rect2(20 + index * 112, 590, 72, 72))
		label_at(self, "%d · %s" % [index + 1, names[index]], Rect2(20 + index * 112, 659, 112, 24), 14)
		member_health_labels.append(label_at(self, "", Rect2(20 + index * 112, 683, 112, 22), 13))
	label_at(self, "Flechas: mover    WASD: disparar ↑ ← ↓ →    E: habilidad\nShift: esquivar    1–4: cambiar    Q: Ad-lib    Esc: pausa    R/M: reiniciar", Rect2(505, 641, 750, 56), 16)
	_create_defeat_panel()
	_create_pause_panel()
	_create_intro_panel()
	hurt_vignette = ColorRect.new()
	hurt_vignette.color = Color(0.55, 0.05, 0.08, 0.0)
	hurt_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hurt_vignette)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	if intro_timer > 0.0:
		intro_timer = maxf(0.0, intro_timer - delta)
		if intro_timer <= 0.0 and is_instance_valid(intro_panel):
			intro_panel.hide()
	if is_instance_valid(hurt_vignette) and is_instance_valid(player):
		var a := clampf(player.hurt_flash * 1.6, 0.0, 0.35)
		hurt_vignette.color = Color(0.55, 0.05, 0.08, a)

# Refresca el HUD con el diccionario emitido por el jugador.
func update_stats(data: Dictionary, defeated: int) -> void:
	voice_bar.max_value = data["voice_max"]
	voice_bar.value = maxf(0.0, data["voice"])
	harmony_bar.value = data["harmony"]
	voice_text.text = "VOZ  %d / %d" % [maxi(0, int(data["voice"])), int(data["voice_max"])]
	harmony_text.text = "ARMONÍA  %d%%   COMPOSTURA  %d%%" % [int(data["harmony"]), int(data.get("composure", 0.0))]
	member_text.text = "%s     KO %d" % [data["member_name"], defeated]
	member_text.modulate = data["member_color"]
	cooldown_text.text = "Habilidad: %s    Esquiva: %s" % [("sin energía" if data["ability_cd"] <= 0.0 and data.get("energy", 100.0) < 100.0 else cooldown(data["ability_cd"])), cooldown(data["dodge_cd"])]
	for index in range(member_buttons.size()):
		var health: float = data["member_voice"][index]
		var fallen := health <= 0.0
		member_buttons[index].disabled = fallen
		member_buttons[index].modulate = Color(0.25, 0.25, 0.25) if fallen else (Color.WHITE if index == data["active_index"] else Color(0.65, 0.65, 0.75))
		member_health_labels[index].text = "CAÍDA" if fallen else "VOZ %d / %d" % [int(health), int(data["voice_max"])]
		member_health_labels[index].modulate = Color("ff8080") if fallen else Color.WHITE

# Texto legible del cooldown: "lista" o segundos restantes.
func cooldown(value: float) -> String:
	return "lista" if value <= 0.0 else "%.1f s" % value

# Muestra el nivel de cadena de Armonía y el tiempo restante de la ventana.
func update_chain(level: int, timer: float) -> void:
	var names := ["SIN CADENA", "SOLO", "DUETO", "TRÍO", "CUARTETO"]
	chain_text.text = "CADENA: %s   %.1f s" % [names[clampi(level, 0, 4)], maxf(timer, 0.0)]

# Panel de fin de run (derrota / victoria + resumen meta).
func _create_defeat_panel() -> void:
	defeat_panel = Control.new()
	defeat_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(defeat_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.03, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_panel.add_child(shade)
	end_art = TextureRect.new()
	end_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	end_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	end_art.position = Vector2(340, 80)
	end_art.size = Vector2(600, 220)
	end_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_panel.add_child(end_art)
	end_title = label_at(defeat_panel, "EQUIPO DERROTADO", Rect2(340, 310, 600, 40), 30)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body = label_at(defeat_panel, "", Rect2(360, 360, 560, 140), 15)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_art = TextureRect.new()
	summary_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	summary_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summary_art.texture = SUMMARY_ART
	summary_art.position = Vector2(40, 80)
	summary_art.size = Vector2(280, 160)
	summary_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_panel.add_child(summary_art)
	var restart := _menu_button(defeat_panel, "REINICIAR (R)", Vector2(390, 520), func():
		SESSION.clear()
		get_tree().reload_current_scene())
	var fresh := _menu_button(defeat_panel, "NUEVA RUN (M)", Vector2(670, 520), func():
		SESSION.clear()
		get_tree().set_meta("run_seed", randi() + 1)
		get_tree().reload_current_scene())
	restart.custom_minimum_size = Vector2(240, 48)
	fresh.custom_minimum_size = Vector2(240, 48)
	defeat_panel.hide()

func _menu_button(parent: Node, caption: String, origin: Vector2, on_press: Callable) -> Button:
	var button := Button.new()
	button.position = origin
	button.size = Vector2(240, 48)
	button.text = caption
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = atlas(MENU_SHEET, Rect2(20, 369, 243, 56))
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		SFX.play("ui")
		on_press.call())
	parent.add_child(button)
	return button

func _create_pause_panel() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(shade)
	picture(pause_panel, PAUSE_ART, Rect2(390, 120, 500, 280))
	var title := label_at(pause_panel, "PAUSA", Rect2(390, 420, 500, 36), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := label_at(pause_panel, "Esc para continuar · R reinicia · M nueva run", Rect2(390, 465, 500, 28), 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button(pause_panel, "CONTINUAR", Vector2(520, 510), toggle_pause)
	pause_panel.hide()

func _create_intro_panel() -> void:
	intro_panel = Control.new()
	intro_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intro_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.04, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_panel.add_child(shade)
	var art := TextureRect.new()
	art.name = "IntroArt"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(340, 140)
	art.size = Vector2(600, 260)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_panel.add_child(art)
	intro_title = label_at(intro_panel, "", Rect2(340, 420, 600, 36), 26)
	intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_body = label_at(intro_panel, "", Rect2(360, 460, 560, 40), 15)
	intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_panel.hide()

# Compat: derrota simple.
func show_defeat() -> void:
	show_run_end(false, {})

# Victoria o derrota con resumen de la run + meta.
func show_run_end(won: bool, summary: Dictionary) -> void:
	var meta: Dictionary = META.record_run(won, int(summary.get("floor", 1)), int(summary.get("rooms", 0)))
	end_art.texture = VICTORY_ART if won else DEFEAT_ART
	end_title.text = "VICTORIA · HARMONY CLEAR" if won else "EQUIPO DERROTADO"
	var cov: Dictionary = summary.get("playtest_coverage", {})
	var cov_line := ""
	if not cov.is_empty():
		cov_line = "\nPlaytest 5×ruta: S%d M%d W%d H%d · log user://playtest_runs.jsonl" % [
			int(cov.get("solar", 0)), int(cov.get("moonbyul", 0)),
			int(cov.get("wheein", 0)), int(cov.get("hwasa", 0)),
		]
	end_body.text = "Piso %d · Salas %d · Jefes %d · Monedas %d · Ítems %d\nColección %d · Fragmentos +%d (total %d) · Mejor piso %d\nRuns %d (W %d / L %d)%s" % [
		int(summary.get("floor", 1)),
		int(summary.get("rooms", 0)),
		int(summary.get("bosses", 0)),
		int(summary.get("coins", 0)),
		int(summary.get("items", 0)),
		META.discovered_count(),
		int(meta.get("last_fragments_gained", 0)),
		int(meta.get("star_fragments", 0)),
		int(meta.get("best_floor", 1)),
		int(meta.get("runs_played", 0)),
		int(meta.get("runs_won", 0)),
		int(meta.get("runs_lost", 0)),
		cov_line,
	]
	defeat_panel.show()
	pause_panel.hide()
	if paused_game:
		get_tree().paused = false
		paused_game = false
	SFX.play("victory" if won else "defeat")
	for button in member_buttons:
		button.disabled = true

func toggle_pause() -> void:
	if defeat_panel.visible:
		return
	paused_game = not paused_game
	pause_panel.visible = paused_game
	get_tree().paused = paused_game
	if paused_game:
		SFX.play("pause")
	else:
		SFX.play("ui")

func show_floor_intro(floor_number: int, biome_name: String, path_line: String = "") -> void:
	var body := biome_name if path_line.is_empty() else "%s\n%s" % [biome_name, path_line]
	_show_intro(FLOOR_INTRO_ART, "PISO %d" % floor_number, body, 2.4)

func show_boss_intro(boss_name: String) -> void:
	_show_intro(BOSS_INTRO_ART, "JEFE", boss_name, 2.4)

func _show_intro(art: Texture2D, title: String, body: String, duration: float) -> void:
	var view: TextureRect = intro_panel.get_node("IntroArt")
	view.texture = art
	intro_title.text = title
	intro_body.text = body
	intro_panel.show()
	intro_timer = duration
	SFX.play("intro")
