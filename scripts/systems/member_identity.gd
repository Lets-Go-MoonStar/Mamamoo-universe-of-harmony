# ---------------------------------------------------------------------------
# member_identity.gd — Identidad de marca del cuarteto (color, nombre, voz).
# shortcut: sin pack ilustrado; la fantasía se sostiene por copy + paleta + SFX.
# ---------------------------------------------------------------------------
class_name MemberIdentity
extends RefCounted

const NAMES := ["Solar", "Moonbyul", "Wheein", "Hwasa"]
const PATHS := ["solar", "moonbyul", "wheein", "hwasa"]
const COLORS := [
	Color("ffd166"), # Solar — sol / ámbar
	Color("c77dff"), # Moonbyul — luna / violeta
	Color("4cc9f0"), # Wheein — agua / cian
	Color("ff5d5d"), # Hwasa — ember / rojo
]
const TAGLINES := [
	"Luz que abre el escenario",
	"Sombra que marca el tempo",
	"Corriente que sostiene la armonía",
	"Fuego que cierra el encore",
]
const STAGE_TITLES := [
	"Eclipse Stage",
	"Starlight Hall",
	"Sunrise Garden",
	"Lunar Ruins",
	"Crystal Falls",
	"Ignite Castle",
	"Neon District",
	"Shattered Void",
	"Eclipse Throne",
]

static func index_for_path(path_id: String) -> int:
	var i := PATHS.find(path_id)
	return i if i >= 0 else -1

static func color(member: int) -> Color:
	return COLORS[clampi(member, 0, 3)]

static func path_color(path_id: String) -> Color:
	var i := index_for_path(path_id)
	return color(i) if i >= 0 else Color("ffd166")

static func display_name(member: int) -> String:
	return NAMES[clampi(member, 0, 3)]

static func hud_label(member: int) -> String:
	return "%s · %s" % [NAMES[clampi(member, 0, 3)].to_upper(), TAGLINES[clampi(member, 0, 3)]]

static func path_tagline(path_id: String) -> String:
	var i := index_for_path(path_id)
	if i < 0:
		return "Universe of Harmony"
	return "Ruta %s — %s" % [NAMES[i], TAGLINES[i]]

static func stage_title(biome: int, path_id: String = "") -> String:
	var base: String = STAGE_TITLES[clampi(biome, 0, STAGE_TITLES.size() - 1)]
	var i := index_for_path(path_id)
	if i < 0:
		return base
	return "%s · feat. %s" % [base, NAMES[i]]

static func sfx_for_path(path_id: String) -> String:
	return path_id if PATHS.has(path_id) else "intro"

static func pulse_color(path_id: String) -> Color:
	var c := path_color(path_id)
	c.a = 0.30
	return c
