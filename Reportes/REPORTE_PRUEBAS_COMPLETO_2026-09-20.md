# Reporte de Pruebas Completo — Universe of Harmony
**Fecha:** 20 de septiembre de 2026  
**Motor:** Godot 4.7.2 stable (Flatpak)  
**Metodología aplicada:** Plan de QA - Control de Calidad a Nivel de Código (Pruebas de Caja Blanca)  

---

## Resumen ejecutivo

| Suite | Checks | Fallos | Estado |
|---|---|---:|---:|
| `validate_systems.gd` | 5 seeds × 3 pisos (asserts) | 0 | ✅ PASS |
| `floor_system.gd` *(sala BOSS solo-jefe)* | 86 | 0 | ✅ PASS |
| `team_survival.gd` | 11 | 0 | ✅ PASS |
| `combat_smoke.gd` | 16 | 0 | ✅ PASS |
| `items_smoke.gd` | 101 | 0 | ✅ PASS |
| `rewards_flow.gd` | 9 | 0 | ✅ PASS |
| `directional_controls.gd` | 15 | 0 | ✅ PASS |
| `hud_smoke.gd` | 8 | 0 | ✅ PASS |
| `art_smoke.gd` | 42 | 0 | ✅ PASS |
| `logic_audit.gd` | 9 | 0 | ✅ PASS |
| **`boundary_cases.gd`** *(nueva)* | **43** | **0** | ✅ PASS |
| **TOTAL** | **340 PASS** | **0** | ✅ |

**Resultado: todas las suites pasan sin ningún fallo.**

**Revalidación (noche):** tras integrar 8 assets nuevos (5 hojas de enemigos, retratos, marcos y VFX de habilidades) la batería completa vuelve a dar 0 fallos en Godot 4.7.2 Flatpak y 4.3 headless (`visual_integration.gd`: regiones de atlas válidas para todos los índices, incluidos los enemigos 0-5).

---

## Suite nueva: `tests/boundary_cases.gd`

Implementada siguiendo la Fase de Expansión de Casos (§3.3 del plan) con cobertura de:
**Ejecución verificada:** 43 checks, 0 fallos (Godot 4.7.2 Flatpak y 4.3 headless). Registro en `tests/results/boundary_cases.log`.

### A — `HarmonyEnemy.take_damage()` (4 checks)

| ID | Caso | Resultado |
|---|---|---|
| A1 | Daño = 0 | vida no cambia, `dying=false` |
| A2 | Daño = −20 | vida **no cambia** (guardia RB-01 aplicada: daño negativo se ignora) |
| A3 | Daño = 999 999 | enemigo muere en un golpe |
| A4 | Daño sobre `dying=true` | llamada ignorada por completo |

> **Nota A2:** Con la guardia RB-01 aplicada (`enemy.take_damage` retorna si `dying` o `amount <= 0`), el daño negativo ya no cura al enemigo; la fragilidad documentada en la primera versión queda cerrada y el test ahora lo verifica.

---

### B — `HarmonyPlayer.receive_damage()` (5 checks)

| ID | Caso | Resultado |
|---|---|---|
| B1 | Daño = 0 | Voz no cambia |
| B2 | Daño = −10 | Voz no cambia (`absorb` clampea con `maxf`) |
| B3 | Daño = 999 999 (una vez) | Solar cae; equipo sigue en pie |
| B4 | Daño = 999 999 × 4 | equipo completamente derrotado |
| B5 | Llamada con `team_defeated=true` | ignorada por completo |

---

### C — Curación desbordante (3 checks)

| ID | Caso | Resultado |
|---|---|---|
| C1 | `heal_member(0, 99 999)` | clampea exactamente a `voice_max` |
| C2 | `heal_team(9 999)` | todas las integrantes al máximo |
| C3 | Curar integrante con Voz=0 | sin efecto (no revive) |

---

### D — `absorb()` valores extremos (4 checks)

| ID | Caso | Resultado |
|---|---|---|
| D1 | `absorb(0)` sin escudo | retorna 0.0 |
| D2 | `absorb(-5)` | retorna 0.0 (`maxf` clampea) |
| D3 | Daño > escudo | escudo se agota; excedente pasa |
| D4 | Daño == escudo | escudo se agota; residual = 0 |

---

### E — `hit()` casos límite (2 checks)

| ID | Caso | Resultado |
|---|---|---|
| E1 | `hit()` sobre enemigo `dying=true` | retorna 0.0 sin daño |
| E2 | `hit()` con daño = 0 | vida del enemigo no cambia |

---

### F — `EncounterDirector.build_encounter()` (4 checks)

| ID | Caso | Resultado |
|---|---|---|
| F1 | Pool vacío, presupuesto 10 | retorna `[]` sin crash |
| F2 | Pool válido, presupuesto −5 | retorna `[]` sin generar enemigos |
| F3 | Pool válido, presupuesto 0 | retorna `[]` sin generar enemigos |
| F4 | Pool válido, presupuesto 9 999 | genera ≤ 300 enemigos (guardia activo) |

---

### G — `FloorConfig.make_default()` en pisos extremos (5 checks)

| ID | Caso | Resultado |
|---|---|---|
| G1 | Piso 0 | config válida sin crash |
| G2 | Piso −1 | config válida sin crash |
| G3 | Piso −1 · multiplicador | `difficulty_multiplier < 1.0` (escalado invertido, documentado) |
| G4 | Piso 9 999 | `difficulty_multiplier > 1.0` sin overflow |
| G5 | Piso 9 999 · NaN/∞ | multiplicador finito y no-NaN |

> **Nota G3:** Con la fórmula `1.0 + (floor - 1) * 0.08`, pisos negativos producen multiplicador < 1 (los enemigos serían más débiles que en el piso 1). No es una ruta accesible en el juego, pero vale documentarlo.

---

### H — `RunManager` índices fuera de rango (5 checks)

| ID | Caso | Resultado |
|---|---|---|
| H1 | `room(-1)` | retorna `null` |
| H2 | `room(99 999)` | retorna `null` |
| H3 | `enter_room(-1)` | retorna `null` |
| H4 | `enter_room(99 999)` | retorna `null` |
| H5 | `complete_current()` con sala ya completada | `rooms_completed` **no cambia** (aserción real) |

---

### I — `ItemCatalog` ID inválido (2 checks)

| ID | Caso | Resultado |
|---|---|---|
| I1 | `entry("id_inexistente")` | retorna `{}` sin crash |
| I2 | `entry("")` | retorna `{}` sin crash |

> **Nota I (mejora aplicada, RB-02):** En la primera versión `catalog.icon(id)` llamaba a `item.sheet` sobre `{}` si el ID no existía, produciendo un error en tiempo de ejecución. **RB-02 se ha aplicado**: `icon()` devuelve una `AtlasTexture.new()` vacía cuando `entry(id)` es `{}`. El test sigue cubriendo `entry()` con IDs inválidos, y ahora `icon()` también es seguro.

---

### J — Desbordamiento de XP y nivel (3 checks)

| ID | Caso | Resultado |
|---|---|---|
| J1 | 100 kills · XP resultante | no es NaN ni infinito |
| J2 | 100 kills · nivel resultante | `level >= 1` |
| J3 | 100 kills × 10 XP = 1000 XP | `level >= 10` (sube correctamente) |

---

### K — Multiplicadores con inventario vacío (4 checks)

| ID | Caso | Resultado |
|---|---|---|
| K1 | `damage_multiplier(0)` | exactamente 1.0 |
| K2 | `speed_multiplier()` | exactamente 1.0 |
| K3 | `harmony_multiplier()` | exactamente 1.0 |
| K4 | `ability_cooldown()` | exactamente 4.5 (valor base) |

---

### L — `voice_max = 0` (2 checks)

| ID | Caso | Resultado |
|---|---|---|
| L1 | `heal_team(1.0)` con `voice_max=0` | sin crash ni excepción |
| L2 | `add_shield(0, 0.5)` con `voice_max=0` | escudo queda en 0 (guardia de Voz=0) |

---

## Hallazgos de robustez

### RB-01 · Bajo riesgo · `enemy.gd:take_damage()` — ✅ corregido

Detectado en la primera versión: `take_damage(amount)` ejecuta `hp -= amount` sin validar el signo, por lo que un valor negativo curaba al enemigo. **Aplicado:** la función ahora retorna si `dying o amount <= 0.0`. La suite actualiza el caso A2 para verificar que el daño negativo se ignora (vida sin cambios), y no hay ninguna llamada de producción que pase daño negativo (verificado por rastreo de callers).

```gdscript
func take_damage(amount: float, _member_index: int = -1) -> void:
    if dying or amount <= 0.0:
        return
    hp -= amount
```

### RB-02 · Bajo riesgo · `item_catalog.gd:icon()` — ✅ corregido

Detectado en la primera versión: `icon(id)` accedía a `item.sheet` sin validar `entry(id)`. **Aplicado:** si el ID no existe, `icon()` devuelve una `AtlasTexture.new()` vacía en lugar de crashear. El resto de callers (`item_ui`) usan únicamente IDs válidos del catálogo.

```gdscript
static func icon(id: String) -> AtlasTexture:
    var item := entry(id)
    if item.is_empty():
        return AtlasTexture.new()
    ...
```

> **Nota de verificación:** el caso H5 de la primera versión usaba `check(true, …)` (tautología). Se sustituyó por una aserción real: `rooms_completed` no cambia al completar una sala ya completada.

> **Nota de registros:** la batería se revalidó con Godot 4.7.2 (Flatpak) y 4.3 (binario headless); todas las suites con 0 fallos y `tests/results/boundary_cases.log` guardado. Al salir, los tests `--script` que instancian escenas con física pueden imprimir `1 RID ... GodotBody2D leaked` / `ObjectDB instances leaked` en el cierre del motor: es ruido del teardown del harness (una ejecución normal del juego sale limpia), no una fuga de producto.

---

## Regresión detectada en juego: matar un refuerzo del jefe daba la victoria

Detectada durante la verificación manual en Flatpak 4.7.2: matando a **cualquier enemigo** en una sala BOSS aparecía el panel "¡JEFE DERROTADO!" y se completaba la sala por el camino equivocado.

**Causa raíz:** la guardia de `_on_enemy_defeated` (BUG-P1) solo bloqueaba el caso `_enemy.is_boss`, pero el bloque genérico seguía ejecutándose para los refuerzos: en una sala BOSS `room_budget = 1`, así que matar a un solo refuerzo hacía `room_kills >= room_budget` y disparaba `_handle_room_cleared()` → `item_ui.queue_reward("boss")` + `run.complete_current()` (que marca el piso superado). El test COV-3 anterior era un **falso negativo**: comprobaba `pending` y `awaiting_floor_start` tras `await process_frame`, pero el panel ya había hecho `pop` del pending en ese frame, enmascarando el fallo.

**Fix aplicado** en `scripts/main.gd:_on_enemy_defeated`: dentro de una sala BOSS, solo la derrota del propio jefe completa la sala; las bajas de refuerzos se contabilizan (`room_kills`) pero nunca activan `_handle_room_cleared` ni el avance de piso.

**COV-3 ampliado** (de 3 a 6 aserciones, ahora sí detectan el fallo): matar un refuerzo no activa `awaiting_floor_start`, no encola recompensa `boss`, no abre `awaiting_reward`, no muestra el `overlay`, no marca `completed` la sala BOSS, y el jefe sigue con vida.

> **Cambio de diseño posterior (petición del usuario):** en la sala BOSS ya **no se invocan refuerzos**: el jefe pelea en solitario. Se eliminó el emit de `boss_summon` en `enemy.gd:_check_boss_phase`, el handler `_on_boss_summon` de `main.gd`, la señal y el campo `enemy_summons` (y el tag `summon`) de `BossData` y de los 3 `.tres` del `boss_pool`. Las fases (100/70/35) y la furia (`enrage`) se conservan. `floor_system.gd` y `logic_audit.gd` se actualizaron: ahora verifican que la sala solo contiene al jefe, que el cambio de fase no genera nada y que derrotar al jefe abre la transición de piso. Revalidado con **0 fallos** en Flatpak 4.7.2 y Godot 4.3 (batería completa **340 PASS** + asserts de `validate_systems`).

---

## Cómo ejecutar todas las suites

```sh
cd universe_of_harmony_godot_prototype

# Suites originales
for suite in validate_systems floor_system team_survival combat_smoke items_smoke \
             rewards_flow directional_controls hud_smoke art_smoke logic_audit; do
  echo "=== $suite ==="
  flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
    --fixed-fps 60 --script "res://tests/${suite}.gd"
done

# Suite de valores límite (nueva)
echo "=== boundary_cases ==="
flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
  --fixed-fps 60 --script res://tests/boundary_cases.gd
```

---

## Correspondencia con el Plan de QA

| Sección del plan | Cobertura alcanzada |
|---|---|
| §3.1 Fase Roja/Verde (TDD) | Las 9 suites existentes fueron generadas con este ciclo |
| §3.3 Boundary/Edge Cases | **`boundary_cases.gd`**: 43 checks en 12 categorías |
| §4-A Pruebas unitarias | `items_smoke`, `boundary_cases` (funciones aisladas) |
| §4-B Pruebas de integración | `floor_system`, `rewards_flow`, `logic_audit` |
| §4-C Mocking | No aplica (sin servicios externos en este prototipo) |
| §4-D Pruebas de motor | `combat_smoke`, `art_smoke`, `hud_smoke`, `directional_controls` |
| §5 Regresión | Todos los tests actúan como barrera de regresión |

El único punto del plan no cubierto por ser un prototipo offline es la sección §4-C (simulación de servicios externos/red).
