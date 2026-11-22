extends SceneTree
# Smoke del catálogo e inventario (32 ítems + efectos clave).
# godot --headless --path . --fixed-fps 60 --script res://tests/items_smoke.gd

const CATALOG = preload("res://scripts/item_catalog.gd")
const RUN_ITEMS = preload("res://scripts/run_items.gd")
const PLAYER = preload("res://scripts/player.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func run() -> void:
	var catalog := CATALOG.all()
	check(catalog.size() == 34, "Catálogo tiene 34 ítems")
	check(CATALOG.entry("curtain_call_brooch").rarity == "LEGENDARY", "Curtain Call Brooch es legendaria")
	check(CATALOG.entry("stage_guardian_veil").rarity == "LEGENDARY", "Stage Guardian Veil es legendaria")
	var seen := {}
	for entry in catalog:
		check(not entry.id.is_empty() and not seen.has(entry.id), "Ítem único: %s" % entry.id)
		seen[entry.id] = true
		check(entry.has("rarity") and entry.has("max_stacks"), "Metadatos básicos de %s" % entry.id)
		var icon := CATALOG.icon(entry.id)
		check(icon != null and icon.atlas != null, "Icono atlas de %s" % entry.id)

	var player: HarmonyPlayer = PLAYER.new()
	root.add_child(player)
	await frames(2)
	player.set_physics_process(false)
	var items = player.items
	check(items != null, "HarmonyPlayer monta RunItems")

	# Adquisición de todos los ítems (con selección donde hace falta).
	for entry in catalog:
		var id: String = entry.id
		if id == "duo_bond_charm":
			check(items.acquire(id, 0, 1), "Adquiere %s" % id)
		elif id == "skill_scroll":
			check(items.acquire(id, 0), "Adquiere %s" % id)
		elif id in ["heart_recovery_potion", "treasure_chest", "legendary_celestial_chest"]:
			# Consumibles: se borran al adquirir; aún deben devolver true.
			check(items.acquire(id, 0, 1), "Adquiere consumible %s" % id)
		else:
			check(items.can_acquire(id), "Puede adquirir %s" % id)
			check(items.acquire(id), "Adquiere %s" % id)

	check(player.voice_max == 115.0, "Amplificador sube Voz máxima a 115")
	check(items.coins >= 1 and items.keys >= 1 and items.tickets >= 1, "Recursos (moneda/llave/ticket) aplicados")
	check(items.skill_ranks[0] >= 1, "Pergamino sube rango de Solar")
	check(items.duo[0] == 0 and items.duo[1] == 1, "Vínculo de dúo configurado")

	var before := player.member_voice.duplicate()
	items.heal_team(0.25)
	var healed := false
	for i in range(4):
		if player.member_voice[i] > before[i]:
			healed = true
	check(healed or before[0] >= player.voice_max, "heal_team cura o ya estaba al máximo")

	items.add_shield(0, 0.2, 6.0)
	check(items.shields[0] > 0.0, "Escudo individual aplicado")
	var absorbed: float = items.absorb(10.0)
	check(absorbed < 10.0, "Escudo absorbe parte del daño")

	# Límites de stacking / cooldown / velocidad / armonía.
	check(items.ability_cooldown() <= 4.5, "Gemas de nota reducen cooldown (o dejan base)")
	check(items.speed_multiplier() >= 1.0 and items.speed_multiplier() <= 1.35, "Velocidad acotada a +35%")
	check(items.harmony_multiplier() >= 1.0 and items.harmony_multiplier() <= 1.60, "Armonía acotada a +60%")

	# Boss seal: bono ofensivo usa is_boss, no art_index.
	var boss := HarmonyEnemy.new()
	boss.is_boss = true
	boss.art_index = 0
	boss.max_hp = 100.0
	boss.hp = 100.0
	root.add_child(boss)
	await frames(1)
	items.owned["boss_seal_fragment"] = 3
	var dealt: float = items.hit(boss, 100.0, 0)
	check(dealt >= 100.0 * 1.09 - 0.01, "Boss seal fragment aplica bono ofensivo a jefes con art_index != 3")
	boss.queue_free()
	await frames(1)

	# XP de jefe vs normal.
	var dummy_boss := HarmonyEnemy.new()
	dummy_boss.is_boss = true
	dummy_boss.art_index = 0
	var xp_before: float = items.xp
	items.on_kill(dummy_boss)
	check(items.xp >= xp_before + 30.0 - 0.01, "Matar jefe (is_boss=true, art_index=0) otorga 30 XP base")
	dummy_boss.free()

	# Resurrección de un solo uso.
	for i in range(4):
		player.member_voice[i] = 0.0
	player.team_defeated = true
	items.owned["revival_feather"] = 1
	items.revival_used = false
	check(items.revive(), "Pluma revive al equipo una vez")
	check(not items.revive(), "Pluma no revive una segunda vez")
	check(player.member_voice[0] > 0.0, "Tras revive hay Voz > 0")

	# Ad-lib.
	player.harmony = 100.0
	items.start_adlib()
	check(items.active("adlib"), "Ad-lib activa ventana de 5 s")

	player.set_physics_process(false)
	player.team_defeated = false

	# Curtain Call Brooch: energía al abrir Ad-lib + Armonía al cambiar.
	items.owned.clear()
	items.owned["curtain_call_brooch"] = 1
	items.energy = 40.0
	player.harmony = 100.0
	items.timers.erase("adlib")
	items.start_adlib()
	check(items.energy >= 65.0, "Curtain Call Brooch otorga 25 energía al activar Ad-lib")
	var harmony_before: float = player.harmony
	items.on_switch(0, 1)
	check(player.harmony >= harmony_before + 6.0 - 0.01, "Curtain Call Brooch otorga +6 Armonía al cambiar durante Ad-lib")

	# Stage Guardian Veil: salva la primera caída.
	items.owned.clear()
	items.owned["stage_guardian_veil"] = 1
	for i in range(4):
		items.guardian_saved[i] = false
	player.member_voice = [100.0, 100.0, 100.0, 100.0]
	player.active_index = 0
	player.invulnerable = 0.0
	player.receive_damage(999.0)
	check(player.member_voice[0] > 0.0 and items.guardian_saved[0], "Stage Guardian Veil salva la primera caída")
	player.invulnerable = 0.0
	player.receive_damage(999.0)
	check(player.member_voice[0] <= 0.0 or player.active_index != 0, "La segunda caída de la misma integrante no se vuelve a salvar")

	# Cofre celestial: pool legendaria con al menos 3 reliquias (sin el cofre).
	var legendary_pool: Array[String] = []
	for entry in CATALOG.all():
		if entry.rarity == "LEGENDARY" and entry.id != "legendary_celestial_chest":
			legendary_pool.append(entry.id)
	check(legendary_pool.size() >= 3, "Hay al menos 3 reliquias legendarias para el cofre celestial")
	check(legendary_pool.has("quartet_crown") and legendary_pool.has("curtain_call_brooch") and legendary_pool.has("stage_guardian_veil"), "Pool incluye Crown, Brooch y Veil")

	print("ITEMS SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
