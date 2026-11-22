# ---------------------------------------------------------------------------
# item_ui.gd — Interfaz de inventario, catálogo, recompensas y navegación:
#   - panel superpuesto que pausa el juego (show_panel/close),
#   - elección de recompensas con rarezas del RewardManager (45/30/15/8/2)
#     y 3 opciones por sala (combat/elite/reward/boss),
#   - selección de la siguiente sala del grafo (rutas alternativas),
#   - tienda (precio por rareza), evento y descanso de las salas no-combate,
#   - inventario (I) y catálogo completo de los 32 ítems.
# ---------------------------------------------------------------------------
extends Control

const VISUALS = preload("res://scripts/visual_assets.gd")

const CATALOG = preload("res://scripts/item_catalog.gd")
const REWARD_MANAGER = preload("res://scripts/systems/reward_manager.gd")
const META = preload("res://scripts/systems/meta_progress.gd")
const SFX = preload("res://scripts/systems/sfx.gd")
const FLOOR_MAP = preload("res://scripts/floor_map.gd")
var game
# Referencia al sistema de ítems de la partida (run_items del jugador).
var system
var overlay: Panel
var content: VBoxContainer
var status: Label
# Cola de recompensas pendientes (combat/elite/reward/boss/chest/legendary/special).
var pending: Array[String] = []
var current_kind := ""
var choices: Array[String] = []
var selection_id := ""
# Primer miembro elegido para el vínculo de dúo (segunda elección).
var first_member := -1
var catalog_mode := false
# Ofertas de la tienda: Array[Dictionary] {id, price}.
var shop_offers: Array = []
const PHASE3_REFERENCE_ASSETS: Array[String] = [
	"res://assets/backgrounds/cosmic_archive_background.png",
	"res://assets/backgrounds/neon_district_background.png",
	"res://assets/backgrounds/eclipse_nexus_background.png",
	"res://assets/backgrounds/igneous_realm_background.png",
	"res://assets/backgrounds/celestial_ruins_background.png",
	"res://assets/backgrounds/lunar_ruins_background.png",
	"res://assets/backgrounds/aquatic_sanctuary_background.png",
	"res://assets/environment/cosmic_archive/tiles/cosmic_archive_tileset_reference.png",
	"res://assets/environment/eclipse_nexus/tiles/eclipse_nexus_tileset_reference.png",
	"res://assets/environment/igneous_realm/tiles/igneous_realm_tileset_reference.png",
	"res://assets/environment/aquatic_sanctuary/tiles/aquatic_sanctuary_tileset_reference.png",
	"res://assets/ui/npcs/archivist_reference.png",
	"res://assets/ui/npcs/challenge_keeper_reference.png",
	"res://assets/ui/npcs/corruption_dealer_reference.png",
	"res://assets/ui/npcs/event_npc_reference.png",
	"res://assets/ui/npcs/harmony_shrine_reference.png",
	"res://assets/ui/npcs/merchant_reference.png",
	"res://assets/ui/npcs/mysterious_dealer_reference.png",
	"res://assets/ui/shop/black_market_reference.png",
	"res://assets/ui/shop/harmony_shrine_shop_reference.png",
	"res://assets/ui/shop/relic_trader_reference.png",
	"res://assets/ui/shop/normal_shop_reference.png",
	"res://assets/ui/shop/phase3_special_shops_reference.png",
	"res://assets/ui/events/phase3_events_reference.png",
	"res://assets/ui/bosses/phase3_bosses_reference.png",
	"res://assets/ui/vfx/phase3_expanded_vfx_reference.png",
	"res://assets/ui/screens/phase3_key_screens_reference.png",
	"res://assets/ui/screens/boss_intro_reference.png",
	"res://assets/ui/screens/floor_intro_reference.png",
	"res://assets/ui/screens/game_over_reference.png",
	"res://assets/ui/screens/new_endings_reference.png",
	"res://assets/ui/screens/pause_reference.png",
	"res://assets/ui/screens/run_summary_reference.png",
	"res://assets/ui/screens/victory_reference.png",
	"res://assets/ui/systems/builds_reference.png",
	"res://assets/ui/systems/advanced_difficulty_reference.png",
	"res://assets/ui/systems/optional_bosses_reference.png",
	"res://assets/ui/systems/elite_modifiers_reference.png",
	"res://assets/ui/systems/secret_rooms_reference.png",
	"res://assets/ui/systems/phase3_permanent_progression_reference.png",
	"res://assets/ui/systems/phase3_item_synergies_reference.png",
	"res://assets/ui/systems/phase3_narrative_system_reference.png",
	"res://assets/ui/systems/phase3_extra_content_reference.png",
	"res://assets/ui/systems/phase3_room_templates_reference.png",
	"res://assets/ui/systems/phase3_biome_tilesets_reference.png",
	"res://assets/ui/systems/phase3_enemy_archetypes_reference.png",
	"res://assets/ui/systems/phase3_npcs_reference.png",
	"res://assets/ui/systems/phase3_biomes_reference.png"
]

func setup(scene) -> void:
	game = scene
	system = game.player.items
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bag := Button.new()
	bag.text = "Inventario [I]"
	bag.position = Vector2(20, 114)
	bag.size = Vector2(175, 34)
	bag.pressed.connect(open_inventory)
	add_child(bag)
	status = Label.new()
	status.position = Vector2(210, 116)
	status.add_theme_font_size_override("font_size", 14)
	add_child(status)
	overlay = Panel.new()
	overlay.position = Vector2(145, 90)
	overlay.size = Vector2(990, 540)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111327")
	style.border_color = Color("b49adc")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	overlay.add_theme_stylebox_override("panel", style)
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.position = Vector2(20, 14)
	margin.size = Vector2(950, 510)
	overlay.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	overlay.hide()
	system.reward_requested.connect(queue_reward)

func _process(_delta: float) -> void:
	if not is_instance_valid(system): return
	var seed_text := "Seed %d" % game.run.run_seed
	status.text = "Piso %d · Sala %d · %d monedas · Nv %d (EXP %d/100)\nEnergía %d · Escudo %d · Compostura %d%%%s · %s" % [game.run.current_floor, game.room_number, system.coins, system.level, int(system.xp), int(system.energy), int(system.shields[game.player.active_index]), int(game.player.composure), " · AD-LIB" if system.active("adlib") else " · Q: Ad-lib (100 Compostura)", seed_text]

func _unhandled_key_input(event: InputEvent) -> void:
	# Tecla I: abre/cierra el inventario (no cuando hay otra ventana abierta).
	if event.is_action_pressed("inventory") and not event.is_echo():
		if overlay.visible and current_kind == "inventory":
			close()
		elif not overlay.visible:
			open_inventory()
		get_viewport().set_input_as_handled()

# Vacía los controles del panel de contenido.
func clear() -> void:
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()

func label(text: String, parent: Node = null, size: int = 18) -> Label:
	if parent == null: parent = content
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(text: String, callback: Callable, parent: Node = null) -> Button:
	if parent == null: parent = content
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

# Pausa el combate y muestra el panel superpuesto.
func show_panel() -> void:
	get_tree().paused = true
	overlay.show()

# Cierra el panel, reanuda el juego y procesa la siguiente ventana pendiente
# (otra recompensa o los servicios de ruta tras completar la sala).
func close() -> void:
	overlay.hide()
	current_kind = ""
	get_tree().paused = false
	if not pending.is_empty():
		open_next.call_deferred()
	elif game.awaiting_reward:
		show_routes.call_deferred()

# Encola una recompensa y abre el panel si está cerrado.
func queue_reward(kind: String) -> void:
	pending.append(kind)
	if not overlay.visible:
		open_next.call_deferred()

# Saca la siguiente recompensa pendiente de la cola y muestra las opciones.
func open_next() -> void:
	if overlay.visible or pending.is_empty() or game.player.team_defeated: return
	current_kind = pending.pop_front()
	roll_choices()
	show_choices()

# Genera hasta 3 opciones ponderadas por rareza desde RewardsManager,
# ajustadas al tipo de sala (combat/elite/reward/boss/chest/legendary/special).
func roll_choices() -> void:
	choices.clear()
	var kind := current_kind
	# Cofre celestial: exactamente hasta 3 reliquias LEGENDARY distintas
	# (excluye el propio cofre). Ya no cae a épicas.
	if kind == "legendary":
		var legendary_pool: Array[String] = []
		for entry in CATALOG.all():
			var id: String = entry.id
			if entry.rarity != "LEGENDARY": continue
			if id == "legendary_celestial_chest": continue
			if not system.can_acquire(id): continue
			legendary_pool.append(id)
		while not legendary_pool.is_empty() and choices.size() < 3:
			var pick: int = system.rng.randi_range(0, legendary_pool.size() - 1)
			choices.append(legendary_pool[pick])
			legendary_pool.remove_at(pick)
		return
	# Los pesos de la sala determinan qué rarezas pueden caer (45/30/15/8/2,
	# con variantes élite y jefe que mejoran la rareza, sección 13-14). Se
	# elige primero la rareza por su peso y después un ítem uniforme de esa
	# rareza, para respetar los porcentajes documentados sin que la cantidad
	# de objetos por rareza del catálogo distorsione la probabilidad.
	var weights := REWARD_MANAGER.weights_for(kind if kind in ["combat", "elite", "reward", "boss"] else "combat")
	var rarities: Array[String] = []
	var by_rarity: Dictionary = {}
	for entry in CATALOG.all():
		var id: String = entry.id
		if not system.can_acquire(id): continue
		if weights.get(entry.rarity, 0.0) <= 0.0: continue
		if id in ["treasure_chest", "legendary_celestial_chest"] and kind in ["chest", "legendary"]: continue
		if kind == "special" and entry.rarity not in ["RARE", "EPIC", "LEGENDARY"]: continue
		if kind == "chest" and entry.rarity not in ["EPIC", "LEGENDARY"]: continue
		if not by_rarity.has(entry.rarity):
			by_rarity[entry.rarity] = []
			rarities.append(entry.rarity)
		by_rarity[entry.rarity].append(id)
	if by_rarity.is_empty():
		return
	var weight_total := 0.0
	for rarity in rarities:
		weight_total += weights.get(rarity, 0.0)
	while choices.size() < 3 and not by_rarity.is_empty():
		var roll: float = system.rng.randf_range(0.0, weight_total)
		var picked: String = rarities[0]
		for rarity in rarities:
			roll -= weights.get(rarity, 0.0)
			if roll <= 0.0:
				picked = rarity
				break
		var candidates: Array = by_rarity.get(picked, [])
		if candidates.is_empty():
			by_rarity.erase(picked)
			rarities.erase(picked)
			weight_total -= weights.get(picked, 0.0)
			continue
		var id: String = candidates[system.rng.randi_range(0, candidates.size() - 1)]
		if not choices.has(id): choices.append(id)
		by_rarity[picked] = by_rarity[picked].filter(func(candidate: String): return candidate != id)

# Muestra las tres tarjetas de recompensa con icono, nombre, rareza y
# descripción, junto con las acciones renovar (1 moneda) y omitir.
func show_choices() -> void:
	clear()
	label("Elige una recompensa · %s" % current_kind.to_upper())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	for id in choices:
		var entry := CATALOG.entry(id)
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 295
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var icon := TextureRect.new()
		icon.texture = CATALOG.icon(id)
		icon.custom_minimum_size = Vector2(100, 95)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var frame_index: int = {"COMMON": 8, "UNCOMMON": 9, "RARE": 10, "EPIC": 11, "LEGENDARY": 12}.get(entry.rarity, 8)
		var framed := TextureRect.new()
		framed.texture = VISUALS.icon_cell(frame_index)
		framed.custom_minimum_size = Vector2(100, 95)
		framed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		framed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		framed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(framed)
		icon.custom_minimum_size = Vector2.ZERO
		framed.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -30
		icon.offset_top = -30
		icon.offset_right = 30
		icon.offset_bottom = 30
		label(entry.display_name, card, 17)
		label(entry.rarity, card, 13)
		var desc := label(entry.description, card, 15)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button("Elegir", func(): choose(id), card)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var reroll := button("Renovar · 1 moneda", func():
		system.coins -= 1
		roll_choices()
		show_choices(), actions)
	reroll.disabled = system.coins < 1
	button("Omitir", close, actions)
	show_panel()

# Aplica la recompensa elegida; los ítems que requieren integrante
# (pergamino, vínculo de dúo) abren antes su selector.
func choose(id: String) -> void:
	if not overlay.visible or not choices.has(id): return
	if id in ["duo_bond_charm", "skill_scroll"]:
		selection_id = id
		first_member = -1
		show_member_selection()
		return
	if system.acquire(id): close()

# Selector de integrante para pergamino (una) y vínculo de dúo (dos).
func show_member_selection() -> void:
	clear()
	label("Elige una integrante" if selection_id == "skill_scroll" else "Elige las dos integrantes del vínculo")
	if selection_id == "skill_scroll":
		label("Mejora de prototipo: +20% potencia por nivel. Solar: daño/curación; Moonbyul: distancia/control; Wheein y Hwasa: daño.")
	for i in range(4):
		var index := i
		var pick := button(game.player.members[index].name, func():
			if selection_id == "duo_bond_charm" and first_member < 0:
				first_member = index
				show_member_selection()
			else:
				var ok: bool = system.acquire(selection_id, index if selection_id == "skill_scroll" else first_member, index)
				if ok: close())
		pick.disabled = first_member == index
	button("Volver", show_choices)

# Inventario (objetos poseídos) o catálogo completo (los 32, I para abrir).
func open_inventory() -> void:
	if game.player.team_defeated or (overlay.visible and current_kind not in ["inventory", "phase3_gallery", "meta_upgrades"]): return
	current_kind = "inventory"
	clear()
	var meta: Dictionary = META.load_data()
	label("Inventario · %d monedas · %d llaves · %d tickets · Colección %d · ✦ %d" % [
		system.coins, system.keys, system.tickets, META.discovered_count(), int(meta.get("star_fragments", 0))
	])
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	button("Mis objetos", func(): catalog_mode = false; SFX.play("ui"); open_inventory(), tabs)
	button("Catálogo", func(): catalog_mode = true; SFX.play("ui"); open_inventory(), tabs)
	button("Mejoras ✦", open_meta_upgrades, tabs)
	button("Galería Fase 3", open_phase3_gallery, tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 305
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in CATALOG.all():
		var quantity: int = system.count(entry.id)
		if entry.id == "star_coin": quantity = system.coins
		if quantity == 0 and not catalog_mode: continue
		var known: bool = quantity > 0 or META.is_discovered(entry.id)
		var row := HBoxContainer.new()
		list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = CATALOG.icon(entry.id)
		icon.custom_minimum_size = Vector2(58, 58)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.modulate = Color.WHITE if known else Color(0.25, 0.25, 0.3)
		row.add_child(icon)
		var title: String = str(entry.display_name) if known else "???"
		var desc: String = str(entry.description) if known else "Aún no descubierto en ninguna run."
		var text := label("%s · %s · x%d\n%s" % [title, entry.rarity if known else "?", quantity, desc], row, 15)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.tooltip_text = "%s\n%s" % [title, desc]
		icon.tooltip_text = row.tooltip_text
		text.tooltip_text = row.tooltip_text
	button("Volver al combate [I]", close)
	show_panel()

func open_meta_upgrades() -> void:
	if game.player.team_defeated:
		return
	current_kind = "meta_upgrades"
	clear()
	var meta: Dictionary = META.load_data()
	label("Mejoras permanentes · ✦ %d fragmentos" % int(meta.get("star_fragments", 0)))
	label("Se compran entre runs y aplican al empezar la siguiente.", content, 13)
	var path_id: String = str(meta.get("path", ""))
	var path_label: String = "ninguna (elige una build)"
	if META.PATH_DEFS.has(path_id):
		path_label = str(META.PATH_DEFS[path_id].get("label", path_id))
	label("Ruta activa: %s" % path_label, content, 14)
	for pid in META.PATH_DEFS:
		var pdef: Dictionary = META.PATH_DEFS[pid]
		var selected: bool = str(pid) == path_id
		var cost: int = 0 if path_id.is_empty() else 20
		if path_id.is_empty():
			cost = int(pdef.get("cost", 45))
		var ptxt: String = "%s — %s" % [str(pdef.get("label", pid)), str(pdef.get("desc", ""))]
		if selected:
			label("✓ " + ptxt, content, 13)
		else:
			var path_btn := button("Elegir (%d ✦) · %s" % [cost, ptxt], func():
				if META.select_path(pid):
					SFX.play("pickup")
					open_meta_upgrades()
				else:
					SFX.play("ui"), content)
			path_btn.disabled = int(meta.get("star_fragments", 0)) < cost
	if not path_id.is_empty():
		var clear_btn := button("Quitar ruta (15 ✦)", func():
			if META.clear_path():
				SFX.play("ui")
				open_meta_upgrades(), content)
		clear_btn.disabled = int(meta.get("star_fragments", 0)) < 15
	label("Upgrades generales:", content, 14)
	for id in META.UPGRADE_DEFS:
		var def: Dictionary = META.UPGRADE_DEFS[id]
		var level: int = META.upgrade_level(id)
		var max_level: int = int(def.get("max", 1))
		var cost: int = META.upgrade_cost(id)
		var row_text := "%s · %d/%d · %s" % [str(def.get("label", id)), level, max_level, str(def.get("desc", ""))]
		if level >= max_level:
			label(row_text + " · MÁX", content, 14)
		else:
			var buy := button("Comprar (%d ✦) — %s" % [cost, row_text], func():
				if META.buy_upgrade(id):
					SFX.play("pickup")
					open_meta_upgrades()
				else:
					SFX.play("ui"), content)
			buy.disabled = not META.can_buy_upgrade(id)
	button("Volver al inventario", open_inventory)
	show_panel()

func open_phase3_gallery() -> void:
	current_kind = "phase3_gallery"
	clear()
	label("Galería de referencias · Fase 3")
	label("Arte de biomas, NPCs, tiendas, pantallas y sistemas. Los textos del juego siguen siendo controles editables.", content, 13)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 350
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for asset_path in PHASE3_REFERENCE_ASSETS:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(210, 135)
		grid.add_child(card)
		var preview := TextureRect.new()
		preview.texture = load(asset_path)
		preview.custom_minimum_size = Vector2(205, 100)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview)
		var short_name := asset_path.get_file().trim_suffix(".png").replace("_", " ")
		label(short_name.capitalize(), card, 11)
	button("Volver al inventario", open_inventory)
	show_panel()

# Servicios entre salas: elegir la siguiente sala del grafo, curar al equipo,
# abrir cofre con llave o visitar una recompensa especial con ticket. Tras
# derrotar al jefe muestra la transición al siguiente piso.
func show_routes() -> void:
	if overlay.visible: return
	current_kind = "routes"
	clear()
	if game.awaiting_floor_start:
		label("¡JEFE DERROTADO! Piso %d superado." % game.run.current_floor)
		label("Comienza el piso %d con más dificultad y nuevas salas." % (game.run.current_floor + 1))
		button("Continuar al siguiente piso", func():
			game.awaiting_reward = false
			game.start_after_boss())
		show_panel()
		return
	label("Sala completada · Elige el siguiente encuentro")
	_add_floor_map()
	var options: Array = game.run.next_options()
	for option in options:
		var room_id: int = option.room_id
		var route_button := button("Ir a: %s" % option.type_label(), func():
			game.awaiting_reward = false
			game.awaiting_floor_start = false
			close()
			game.go_to_room(room_id))
		route_button.icon = VISUALS.room_icon(option.room_type)
		route_button.expand_icon = true
		route_button.custom_minimum_size = Vector2(0, 40)
	if options.is_empty():
		button("Continuar", func(): game.start_next_room())
	var heal := button("Curar 25% al equipo vivo · 3 monedas", func():
		system.coins -= 3
		system.heal_team(0.25)
		game.player._emit_stats()
		show_routes_refresh())
	heal.disabled = system.coins < 3
	var key := button("Abrir cofre especial · 1 llave", func():
		system.keys -= 1
		system.owned.golden_key = system.keys
		pending.append("chest")
		close())
	key.disabled = system.keys < 1
	var ticket := button("Visitar sala de recompensa · 1 ticket", func():
		system.tickets -= 1
		system.owned.starlight_ticket = system.tickets
		pending.append("special")
		close())
	ticket.disabled = system.tickets < 1
	show_panel()

# Vuelve a mostrar los servicios de ruta tras una compra (p. ej. curar).
func show_routes_refresh() -> void:
	overlay.hide()
	show_routes()

# Mapa visual del piso: clic en un nodo resaltado = elegir esa ruta.
func _add_floor_map() -> void:
	var options: Array = game.run.next_options()
	var map := FLOOR_MAP.new()
	map.setup(game.run, options)
	map.room_chosen.connect(func(room_id: int):
		game.awaiting_reward = false
		game.awaiting_floor_start = false
		close()
		game.go_to_room(room_id))
	content.add_child(map)
	label("Clic en un nodo azul para entrar · Amarillo = sala actual", content, 12)

# --- Salas fuera de combate -------------------------------------------------

# Evento con una sola acción (compatibilidad).
func open_event(text: String, effect: Callable) -> void:
	open_event_choices(text, [{"text": "Aceptar", "fn": effect}])

# Evento con varias opciones (salas EVENT del catálogo).
func open_event_choices(title: String, choices: Array) -> void:
	current_kind = "event"
	clear()
	label("EVENTO")
	label(title, content, 16)
	for choice in choices:
		var entry: Dictionary = choice
		var choice_text: String = str(entry.get("text", "…"))
		var effect: Callable = entry.get("fn", Callable())
		button(choice_text, func():
			if effect.is_valid():
				effect.call()
			game.finish_non_combat_room())
	show_panel()

# Sala REWARD: elige entre objeto (pool mejorada), botín o descanso.
func open_reward_special() -> void:
	current_kind = "reward_special"
	clear()
	label("SALA DE RECOMPENSA")
	label("Escoge cómo cobrar el botín de esta sala.", content, 15)
	button("Elegir un objeto (rareza mejorada)", func():
		game.run.complete_current()
		game.awaiting_reward = true
		game.room_number = game.run.rooms_completed + 1
		current_kind = "reward"
		roll_choices()
		show_choices()
		game._autosave_session())
	button("Botín rápido (+10 monedas, +1 llave)", func():
		system.coins += 10
		system.keys += 1
		game.player._emit_stats()
		game.finish_non_combat_room())
	button("Descanso breve (+20% Voz, +1 ticket)", func():
		system.heal_team(0.20)
		system.tickets += 1
		game.player._emit_stats()
		game.finish_non_combat_room())
	show_panel()

# Abre la tienda de una sala SHOP: tres ofertas con precio por rareza.
func open_shop() -> void:
	current_kind = "shop"
	shop_offers = _roll_shop_offers()
	_show_shop()

func _roll_shop_offers() -> Array:
	var offers: Array = []
	var pool: Array[String] = []
	for entry in CATALOG.all():
		if not system.can_acquire(entry.id): continue
		if entry.id in ["treasure_chest", "legendary_celestial_chest"]: continue
		pool.append(entry.id)
	while offers.size() < 3 and not pool.is_empty():
		var id: String = pool[system.rng.randi_range(0, pool.size() - 1)]
		var entry := CATALOG.entry(id)
		offers.append({"id": id, "price": _shop_price(entry.rarity)})
		pool = pool.filter(func(candidate): return candidate != id)
	return offers

func _shop_price(rarity: String) -> int:
	var base := 20
	match rarity:
		"COMMON": base = 3
		"UNCOMMON": base = 5
		"RARE": base = 8
		"EPIC": base = 12
		_: base = 20
	return maxi(1, base - int(system.shop_discount))

func _show_shop() -> void:
	clear()
	label("TIENDA · %d monedas" % system.coins)
	for offer in shop_offers:
		var entry := CATALOG.entry(offer["id"])
		button("Comprar %s (%s) · %d monedas" % [entry.display_name, entry.rarity, offer["price"]], func():
			if system.coins >= offer["price"] and system.acquire(offer["id"]):
				system.coins -= offer["price"]
				game.player._emit_stats()
				_show_shop(), content)
	button("Salir de la tienda", func(): game.finish_non_combat_room())
	show_panel()
