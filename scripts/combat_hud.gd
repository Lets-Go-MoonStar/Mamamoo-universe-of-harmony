# ---------------------------------------------------------------------------
# combat_hud.gd — HUD de combate (Control). Dibuja la interfaz usando las
# hojas `ui_hud_spritesheet.png`, `ui_menus_spritesheet.png`, los retratos de
# `member_portraits_atlas.png` y los marcos de `member_frames_hud_atlas.png`
# vía AtlasTexture:
#   - barras de Voz y Armonía, nombre de integrante, cadena y cooldowns,
#   - botones de cambio de integrante (1-4) con retrato y marco propio,
#   - panel de derrota con botón REINICIAR.
# ---------------------------------------------------------------------------
extends Control

const HUD_SHEET = preload("res://assets/ui/ui_hud_spritesheet.png")
const MENU_SHEET = preload("res://assets/ui/ui_menus_spritesheet.png")
const PORTRAITS = preload("res://assets/ui/portraits/member_portraits_atlas.png")
const FRAMES = preload("res://assets/ui/member_frames_hud_atlas.png")

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
var player: HarmonyPlayer

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
	label_at(self, "Flechas: mover    WASD: disparar ↑ ← ↓ →    E: habilidad\nShift: esquivar    1–4: cambiar personaje    R: reiniciar    N: escenario", Rect2(505, 641, 750, 56), 16)
	_create_defeat_panel()

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

# Panel oculto que se muestra al perder: oscurece la pantalla, muestra el
# cartel EQUIPO DERROTADO y el botón REINICIAR estilizado con la hoja de menú.
func _create_defeat_panel() -> void:
	defeat_panel = Control.new()
	defeat_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(defeat_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.03, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_panel.add_child(shade)
	picture(defeat_panel, atlas(MENU_SHEET, Rect2(431, 20, 324, 163)), Rect2(390, 214, 500, 252))
	var title := label_at(defeat_panel, "EQUIPO DERROTADO", Rect2(440, 258, 400, 45), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := label_at(defeat_panel, "Pulsa R o reinicia para volver a jugar", Rect2(415, 310, 450, 32))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var button := Button.new()
	button.position = Vector2(510, 365)
	button.size = Vector2(260, 50)
	button.text = "REINICIAR"
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = atlas(MENU_SHEET, Rect2(20, 369, 243, 56))
		button.add_theme_stylebox_override(state, style)
	# Cover the sheet's sample text with the actual, localized button caption.
	button.add_theme_font_size_override("font_size", 18)
	var caption_bg := StyleBoxFlat.new()
	caption_bg.bg_color = Color("10102c")
	var caption := Panel.new()
	caption.position = Vector2(46, 9)
	caption.size = Vector2(168, 32)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel", caption_bg)
	button.add_child(caption)
	var caption_text := label_at(caption, "REINICIAR", Rect2(0, 0, 168, 32), 18)
	caption_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.pressed.connect(func(): get_tree().reload_current_scene())
	defeat_panel.add_child(button)
	defeat_panel.hide()

# Muestra la derrota y bloquea el cambio de integrante.
func show_defeat() -> void:
	defeat_panel.show()
	for button in member_buttons:
		button.disabled = true
