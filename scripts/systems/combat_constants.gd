# ---------------------------------------------------------------------------
# combat_constants.gd — Números definitivos de Compostura, Ad-lib y
# reacciones elementales (hito de prototipo). Un solo sitio para tunear.
# ---------------------------------------------------------------------------
class_name CombatConstants
extends RefCounted

# --- Compostura / Ad-lib ---------------------------------------------------
const COMPOSURE_MAX := 100.0
const COMPOSURE_ON_HIT := 4.0
const COMPOSURE_ON_KILL := 8.0
const COMPOSURE_ON_CHAIN_STEP := 5.0
const COMPOSURE_ON_QUARTET := 15.0
const ADLIB_COST := 100.0
const ADLIB_DURATION := 5.0
const ADLIB_EXTEND_PER_KILL := 0.5
const ADLIB_EXTEND_CAP := 3.0
const ADLIB_SPARK_SPEED := 0.15
const ADLIB_SPARK_DAMAGE := 0.12

# --- Reacciones / estados --------------------------------------------------
const ARDOR_DURATION := 4.0
const ARDOR_DOT_PER_SEC := 3.0
const ARDOR_EXPLOSION_RADIUS := 110.0
const ARDOR_EXPLOSION_RATIO := 0.40
const ARDOR_NOTE_SPREAD := 1.4
const ECLIPSE_DURATION := 5.0
const ECLIPSE_SWITCH_MULT := 1.20
const ECLIPSE_WHEEIN_PULSE := 8.0
const ECLIPSE_WHEEIN_RADIUS := 90.0
const ECLIPSE_HWASA_EXECUTE := 0.10
const ECLIPSE_SOLAR_SHIELD := 0.05
const REACTION_NOTE_BASE := 0.15
const REACTION_NOTE_RELIC := 0.35
const NOTE_CD := 3.0
const ENCORE_CRIT_CHANCE := 0.10
const ENCORE_CRIT_MULT := 1.65
