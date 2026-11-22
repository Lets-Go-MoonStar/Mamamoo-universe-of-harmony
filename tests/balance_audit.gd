extends SceneTree
# Auditoría sintética: 5 escenarios por ruta (proxy de playtest humano).
# godot --headless --path . --fixed-fps 60 --script res://tests/balance_audit.gd

const META = preload("res://scripts/systems/meta_progress.gd")
const PLAYER = preload("res://scripts/player.gd")
const ROOM_MOD = preload("res://scripts/systems/room_modifier.gd")
const IDENTITY = preload("res://scripts/systems/member_identity.gd")

var failures := 0
var checks := 0
var report_lines: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func log_line(text: String) -> void:
	report_lines.append(text)
	print(text)

func path_power(path_id: String, empower: int = 0) -> Dictionary:
	var p: HarmonyPlayer = PLAYER.new()
	root.add_child(p)
	p.set_physics_process(false)
	p.meta_path = path_id
	p.path_empower = empower
	# Réplica de main._refresh_path_bonuses
	p.ability_damage_mult = 1.0
	p.dodge_cd_mult = 1.0
	p.speed_path_mult = 1.0
	p.harmony_path_mult = 1.0
	p.kill_composure_mult = 1.0
	p.adlib_damage_mult = 1.0
	p.chain_window = 2.6
	var emp := 1.0 + CombatConstants.PATH_EMPOWER_STEP * float(empower)
	match path_id:
		"solar":
			p.ability_damage_mult = 1.18 * emp
		"moonbyul":
			p.dodge_cd_mult = 0.78 / emp
			p.speed_path_mult = 1.12 * emp
		"wheein":
			p.harmony_path_mult = 1.25 * emp
			p.chain_window = 2.6 + CombatConstants.WHEEIN_CHAIN_BONUS
		"hwasa":
			p.kill_composure_mult = 1.45 * emp
			p.adlib_damage_mult = 1.10 * emp
	# Escenario 1: aporte de ruta (no DPS bruto del miembro — asimetría base es intencional)
	var member := IDENTITY.index_for_path(path_id)
	p.active_index = member
	var path_dps: float = 0.0
	match path_id:
		"solar":
			path_dps = float(p.members[member]["damage"]) * (p.ability_damage_mult - 1.0) * 6.0
		"moonbyul":
			p.dodge_shot_boost = 1.0
			path_dps = float(p.members[member]["damage"]) * CombatConstants.MOONBYUL_DODGE_SHOT * 8.0
			path_dps += (p.speed_path_mult - 1.0) * 40.0
		"wheein":
			path_dps = (p.harmony_path_mult - 1.0) * 50.0 + CombatConstants.WHEEIN_CHAIN_BONUS * 20.0
		"hwasa":
			p.composure = 80.0
			path_dps = float(p.members[member]["damage"]) * CombatConstants.HWASA_HIGH_COMP_BONUS * 8.0
			path_dps += (p.adlib_damage_mult - 1.0) * 55.0
	# Escenario 2: Compostura por 8 hits + 3 kills (delta vs baseline sin ruta)
	var comp: float = 0.0
	for i in range(8):
		comp += CombatConstants.COMPOSURE_ON_HIT * p.composure_gain_mult * p.room_composure_mult
	for i in range(3):
		comp += CombatConstants.COMPOSURE_ON_KILL * p.kill_composure_mult * p.room_kill_composure_mult * p.composure_gain_mult * p.room_composure_mult
	var baseline_comp: float = CombatConstants.COMPOSURE_ON_HIT * 8.0 + CombatConstants.COMPOSURE_ON_KILL * 3.0
	var comp_delta: float = comp - baseline_comp
	# Escenario 3: sinergia Solar heal
	var synergy: float = 0.0
	if path_id == "solar":
		synergy = CombatConstants.SOLAR_HEAL_COMPOSURE * 3.0 * p.composure_gain_mult
	# Escenario 4: hazard survival proxy
	var hazard_load: float = (7.0 + CombatConstants.ELITE_HAZARD_DMG_BONUS) * float(CombatConstants.HAZARD_PULSES)
	var survival: float = p.voice_max / maxf(1.0, hazard_load)
	# Escenario 5: modifier spotlight
	ROOM_MOD.apply(p, "spotlight")
	var spotlight_taken: float = 12.0 * p.room_damage_taken_mult
	var spotlight_dealt: float = 14.0 * p.room_damage_dealt_mult
	ROOM_MOD.clear(p)
	var score: float = path_dps * 0.45 + comp_delta * 0.35 + synergy * 0.2 + survival * 4.0 + (spotlight_dealt - spotlight_taken) * 0.4
	var out := {
		"path": path_id,
		"dps10": path_dps,
		"composure": comp_delta,
		"synergy": synergy,
		"survival": survival,
		"spotlight_net": spotlight_dealt - spotlight_taken,
		"score": score,
		"empower": empower,
	}
	p.queue_free()
	return out

func run() -> void:
	log_line("=== BALANCE AUDIT · 5 escenarios × 4 rutas ===")
	var scores: Array = []
	for path_id in IDENTITY.PATHS:
		for run_i in range(5):
			var empower := 1 if run_i == 4 else 0
			var row: Dictionary = path_power(path_id, empower)
			scores.append(row)
			log_line("  %s run%d empower=%d  dps10=%.1f  comp=%.1f  syn=%.1f  surv=%.2f  spot=%.1f  SCORE=%.1f" % [
				path_id, run_i + 1, empower, row["dps10"], row["composure"], row["synergy"], row["survival"], row["spotlight_net"], row["score"]
			])

	# Agregados por ruta (runs 1-4 sin empower)
	var by_path := {}
	for row in scores:
		if int(row["empower"]) != 0:
			continue
		var pid: String = str(row["path"])
		if not by_path.has(pid):
			by_path[pid] = []
		by_path[pid].append(float(row["score"]))
	var means := {}
	var lo := 1e9
	var hi := -1e9
	for pid in by_path:
		var arr: Array = by_path[pid]
		var sum := 0.0
		for v in arr:
			sum += float(v)
		var mean := sum / float(arr.size())
		means[pid] = mean
		lo = minf(lo, mean)
		hi = maxf(hi, mean)
		log_line("MEAN %s = %.1f" % [pid, mean])

	var spread := (hi - lo) / maxf(1.0, lo)
	log_line("Spread relativo rutas = %.1f%% (objetivo < 35%%)" % (spread * 100.0))
	check(spread < 0.35, "Rutas dentro de banda ±35%% de poder sintético")

	# Empower no debe disparar más de +12% score
	for path_id in IDENTITY.PATHS:
		var base: Dictionary = path_power(path_id, 0)
		var emp: Dictionary = path_power(path_id, 1)
		var bump := (float(emp["score"]) - float(base["score"])) / maxf(1.0, float(base["score"]))
		log_line("EMPOWER %s bump=%.1f%%" % [path_id, bump * 100.0])
		check(bump <= 0.14, "path_empower %s ≤ +14%%" % path_id)

	# Hazard no liquida un miembro en un solo ciclo de élite (proxy)
	var lethal := (7.0 + CombatConstants.ELITE_HAZARD_DMG_BONUS) * float(CombatConstants.HAZARD_PULSES)
	check(lethal < 100.0, "Élite hazard cycle < 100 Voz (no one-shot)")
	check(CombatConstants.PATH_EMPOWER_MAX == 1, "Empower max 1")

	# Identidad / modifiers presentes
	check(IDENTITY.NAMES.size() == 4, "4 nombres de identidad")
	check(ROOM_MOD.all_ids().size() >= 6, "≥6 modifiers de sala")

	# Escribir reporte
	var path := "res://Reportes/REPORTE_BALANCE_IDENTIDAD_MODS_2026-11-22.md"
	# user:// más fiable en headless write; también intentamos ProjectSettings
	var out_path := "user://REPORTE_BALANCE_IDENTIDAD_MODS_2026-11-22.md"
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file:
		file.store_string("# Reporte balance / identidad / modifiers\n\n")
		file.store_string("Generado por `tests/balance_audit.gd`.\n\n")
		for line in report_lines:
			file.store_string(line + "\n")
		file.store_string("\n## Veredicto\n")
		file.store_string("- Spread rutas: %.1f%%\n" % (spread * 100.0))
		file.store_string("- Failures: %d / %d checks\n" % [failures, checks])
		file.store_string("- Nota: proxy sintético; no sustituye 5 runs humanas por ruta, pero valida bandas.\n")
		file.close()
		log_line("Wrote %s" % out_path)

	print("BALANCE AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
