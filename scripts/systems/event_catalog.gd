# ---------------------------------------------------------------------------
# systems/event_catalog.gd — Encuentros de salas EVENT (decisiones con
# riesgo/beneficio). main.gd elige uno al azar y item_ui muestra las opciones.
# ---------------------------------------------------------------------------
class_name EventCatalog
extends RefCounted

# Cada entrada: title + choices[{text, id}]. Los ids se resuelven en main.
static func for_floor(floor_number: int) -> Array:
	var pool: Array = all()
	if floor_number >= 8:
		pool.append_array(late_events())
	return pool

static func all() -> Array:
	return [
		{
			"id": "harmony_shrine",
			"title": "Santuario de armonía\nUn altar cálido responde a vuestra canción.",
			"choices": [
				{"text": "Orar juntos (+30% Voz al equipo)", "effect": "heal_30"},
				{"text": "Ofrecer 5 monedas (+1 ticket)", "effect": "pay_ticket"},
				{"text": "Tomar una nota (+25 Compostura)", "effect": "composure_25"},
			],
		},
		{
			"id": "corruption_dealer",
			"title": "Trato del vacío\nUna figura ofrece poder a cambio de Voz.",
			"choices": [
				{"text": "Aceptar (+12 monedas, −20 Voz activa)", "effect": "coins_hurt"},
				{"text": "Negociar (−8 monedas, +1 llave)", "effect": "buy_key"},
				{"text": "Rechazar (+15 Compostura)", "effect": "composure_15"},
			],
		},
		{
			"id": "mysterious_dealer",
			"title": "Comerciante misterioso\nTres fardos sellados; solo uno es seguro.",
			"choices": [
				{"text": "Abrir el fardo azul (objeto aleatorio)", "effect": "random_item"},
				{"text": "Pagar 6 monedas por una poción", "effect": "buy_potion"},
				{"text": "Pasar de largo", "effect": "noop"},
			],
		},
		{
			"id": "challenge_keeper",
			"title": "Guardián del desafío\nPropone una prueba de compostura.",
			"choices": [
				{"text": "Aceptar (−15 Voz activa, +1 llave y +40 Compostura)", "effect": "challenge"},
				{"text": "Entrenar suave (+20 Compostura)", "effect": "composure_20"},
				{"text": "Declinar", "effect": "noop"},
			],
		},
		{
			"id": "archivist",
			"title": "Archivista estelar\nOfrece conocimiento o un recuerdo sellado.",
			"choices": [
				{"text": "Estudiar (+40 XP)", "effect": "xp_40"},
				{"text": "Pedir un recuerdo (objeto UNCOMMON+)", "effect": "uncommon_item"},
				{"text": "Descansar un momento (+15% Voz)", "effect": "heal_15"},
			],
		},
		{
			"id": "echo_whisper",
			"title": "Susurro del eco\nOís vuestra propia armonía repetida.",
			"choices": [
				{"text": "Sincronizar (+20 Armonía, +20 Compostura)", "effect": "sync"},
				{"text": "Silenciar el eco (+8 monedas)", "effect": "coins_8"},
				{"text": "Ignorar", "effect": "noop"},
			],
		},
	]

# Eventos exclusivos del tramo largo (pisos 8–13).
static func late_events() -> Array:
	return [
		{
			"id": "eclipse_rite",
			"title": "Rito del eclipse\nLa luz se parte; el vacío ofrece un pacto.",
			"choices": [
				{"text": "Aceptar la marca (−25 Voz, +1 objeto RARO+)", "effect": "eclipse_rite"},
				{"text": "Ofrecer Compostura completa (+2 llaves)", "effect": "composure_for_keys"},
				{"text": "Romper el rito (+30% Voz)", "effect": "heal_30"},
			],
		},
		{
			"id": "void_bargain",
			"title": "Regateo del Void Conductor\nUn metrónomo invisible marca el precio.",
			"choices": [
				{"text": "Pagar 12 monedas (+1 ticket y +40 Compostura)", "effect": "void_pay"},
				{"text": "Arriesgar (−10 Voz, +15 monedas)", "effect": "void_gamble"},
				{"text": "Retirarse", "effect": "noop"},
			],
		},
		{
			"id": "encore_trial",
			"title": "Prueba del encore\nSolo una integrante puede brillar ahora.",
			"choices": [
				{"text": "Solo activa (+35 Compostura, −8 Voz a las demás)", "effect": "encore_solo"},
				{"text": "Ensayo grupal (+15% Voz al equipo)", "effect": "heal_15"},
				{"text": "Cancelar la función", "effect": "noop"},
			],
		},
	]
