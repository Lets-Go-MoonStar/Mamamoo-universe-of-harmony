# Reporte de análisis de código — Universe of Harmony
**Fecha:** 20 de septiembre de 2026  
**Método:** Revisión estática completa de todos los scripts (`.gd`) + cruce con `tests/logic_audit.gd` y el informe previo `REPORTE_LOGICA_2026-09-20.md`  
**Alcance:** 18 scripts de producción + 9 suites de tests  
**Motor:** Godot 4 (GDScript)

---

## Aviso importante: cambios ya aplicados

En la sesión inmediatamente anterior a este reporte se aplicaron **4 correcciones** a los scripts de producción y se añadieron **2 pruebas de regresión** a `tests/items_smoke.gd`. Dichos cambios se describen en la sección correspondiente. A partir de este punto **no se ha modificado nada más**.

---

## Resumen ejecutivo

| Categoría | Total |
|---|---:|
| Bugs ya corregidos (sesión anterior) | 4 |
| Bugs pendientes de alta prioridad | 3 |
| Bugs pendientes de media prioridad | 1 |
| Bugs pendientes de baja prioridad | 1 |
| Debilidades de cobertura en tests | 4 |

Los tres bugs de alta prioridad que quedan afectan al flujo de combate central (jefe, victoria de sala, fin de partida) y producen comportamientos incorrectos reproducibles.

---

## Bugs ya corregidos

### BUG-F1 · Crítico · `scripts/run_items.gd` líneas 281 y 317

**Descripción:** La detección de "enemigo jefe" usaba `enemy.art_index == 3` en lugar de `enemy.is_boss`.  
El **Echo Overlord** (jefe de pisos 1-2) tiene `sprite_index = 0` y el **Crystal Critic** (pisos 2-4) tiene `sprite_index = 2`. Por tanto:

- El bono ofensivo de `boss_seal_fragment` (+3 % de daño por fragmento) **nunca aplicaba** contra el Overlord ni el Critic.
- Matarlos otorgaba **10 XP** en lugar de los 30 que corresponden a un jefe.
- Solo el Eclipse (`sprite_index = 3`) recibía el tratamiento correcto, siendo el jefe de mayor dificultad (pisos 3-13).

**Archivos afectados:**
```
scripts/run_items.gd:281   if enemy.art_index == 3 → if enemy.is_boss
scripts/run_items.gd:317   enemy.art_index == 3    → enemy.is_boss
```

**Tests de regresión añadidos** (`tests/items_smoke.gd`):
- `"Matar jefe (is_boss=true, art_index=0) otorga 30 XP base"`
- `"Boss seal fragment aplica bono ofensivo a jefes con art_index != 3 (Echo Overlord)"`

---

### BUG-F2 · Mayor · `scripts/item_ui.gd` línea 148

**Descripción:** Los pesos por tipo de sala (`RewardManager.weights_for`) solo se usaban para filtrar rarezas prohibidas (peso == 0), pero el pool se construía con `rarity_weight()` (= `BASE_WEIGHTS`). En la práctica una sala BOSS y una sala COMBAT producían distribuciones casi idénticas, ignorando las probabilidades diseñadas (EPIC 34 %, LEGENDARY 16 % para jefes frente a 8 % y 2 % de BASE_WEIGHTS).

**Archivo afectado:**
```
scripts/item_ui.gd:148   REWARD_MANAGER.rarity_weight(entry.rarity)
                       → int(weights.get(entry.rarity, 0.0))
```

---

### BUG-F3 · Menor · `scripts/systems/run_manager.gd` línea 100

**Descripción:** `enter_room()` accedía a `current_room().connections` sin verificar que `current_room()` no fuera nulo. Si `current_room_id` quedara fuera de rango (estado inválido), la llamada causaría un error de puntero nulo.

**Archivo afectado:**
```
scripts/systems/run_manager.gd:100   añadido null-check para current_room()
```

---

### BUG-F4 · Menor · `scripts/main.gd` línea 289

**Descripción:** `_handle_room_cleared()` llamaba `run.current_room()` dos veces tras `complete_current()`, y la condición `room_type != "BOSS"` era siempre verdadera (las salas BOSS van por la rama `_handle_boss_cleared()`). Se unificó a una sola llamada cacheada con null-check.

**Archivo afectado:**
```
scripts/main.gd:286-292   cacheado + condición muerta eliminada
```

---

## Bugs pendientes

### BUG-P1 · Alta · `scripts/main.gd` — Matar un refuerzo del jefe da la victoria al jugador

**Ubicación:** `main.gd:273`

```gdscript
if current_room_type() == "BOSS":
    _handle_boss_cleared()
    return
```

**Descripción:** La función `_on_enemy_defeated` se activa para **cualquier** enemigo eliminado. Cuando el tipo de sala es BOSS y el jefe invoca refuerzos (fase 2), matar un refuerzo ejecuta `_handle_boss_cleared()` aunque el jefe siga vivo. Esto encola la recompensa de jefe, marca `awaiting_floor_start = true` y bloquea el combate.

**Cómo reproducir:**
1. Llegar a la sala BOSS del piso 1 (Echo Overlord).
2. Dañar al jefe por debajo del 70 % de vida (activa fase 2, invoca 3 refuerzos).
3. Matar solo un refuerzo sin tocar al jefe → la pantalla de "JEFE DERROTADO" aparece con el jefe vivo.

**Reproducido por:** `tests/logic_audit.gd` (check nº 4, `FAIL`).

**Corrección sugerida:**

```gdscript
# main.gd:273 — solo activar si el enemigo derrotado ES el jefe
if current_room_type() == "BOSS" and _enemy.is_boss:
    _handle_boss_cleared()
    return
```

> **Corrección refinada (misma noche, verificado en juego):** la guardia `and _enemy.is_boss` bloquea `_handle_boss_cleared`, pero NO evitaba el flujo genérico de completar sala: al morir un refuerzo en una sala BOSS (`room_budget = 1`) el `if room_kills >= room_budget` disparaba igualmente `_handle_room_cleared()` → `queue_reward("boss")` + `complete_current()` (el panel "JEFE DERROTADO" y el avance de piso). Fix definitivo en `_on_enemy_defeated`: en una sala BOSS solo la derrota del jefe completa la sala y todo lo demás retorna:

```gdscript
if current_room_type() == "BOSS":
    # En la sala del jefe solo su derrota completa la sala: matar a un
    # refuerzo no debe activar la victoria ni el avance de piso.
    if _enemy.is_boss:
        _handle_boss_cleared()
    return
```

> El test COV-3 original era un **falso negativo** (consulta `pending` tras un frame en el que el panel ya hacía `pop`); se amplió a 6 aserciones que sí detectan el fallo (ver `Reportes/REPORTE_PRUEBAS_COMPLETO_2026-09-20.md` → "Regresión detectada en juego").

---

### BUG-P2 · Alta · `scripts/main.gd` — Pulsar "Ir a sala de combate" no cierra el menú de rutas

**Ubicación:** `item_ui.gd:272` / `main.gd:362`

```gdscript
# item_ui.gd:272
button("Ir a: %s" % option.type_label(), func(): game.go_to_room(room_id))
```

**Descripción:** El botón de ruta llama directamente a `game.go_to_room()`, que cambia la sala y arranca el encuentro, pero **no llama a `close()`**. El overlay permanece visible, el árbol de escena sigue pausado (`get_tree().paused = true` desde `show_panel()`) y el combate queda bloqueado. El problema solo ocurre para salas de combate; las salas de jefe tienen su propio camino (`start_after_boss`).

**Cómo reproducir:**
1. Completar la sala START (el panel de rutas aparece).
2. Pulsar "Ir a: Combate" (o cualquier sala de combate disponible).
3. La sala cambia pero el panel de rutas sigue superpuesto y los enemigos no se mueven.

**Reproducido por:** `tests/logic_audit.gd` (check nº 2, `FAIL`).

**Corrección sugerida:**

```gdscript
# item_ui.gd:272
button("Ir a: %s" % option.type_label(), func():
    close()
    game.go_to_room(room_id))
```

---

### BUG-P3 · Alta · `scripts/main.gd` — Al terminar el piso 13 se vuelve a generar el jefe

**Ubicación:** `main.gd:304`

```gdscript
func start_after_boss() -> void:
    awaiting_floor_start = false
    awaiting_reward = false
    run.complete_current()        # en piso 13 emite run_completed, pero NO llama goto_floor
    if run.current_room() != null:
        _begin_current_room()     # ← current_room() devuelve la sala BOSS ya completada
```

**Descripción:** En `run_manager.gd:complete_current()`, cuando `current_floor >= 13` se emite `run_completed` pero **no se llama `goto_floor`**. El `current_room_id` sigue apuntando a la sala BOSS (ahora marcada `completed = true`). De vuelta en `start_after_boss()`, `run.current_room()` devuelve esa misma sala, pasa el check `!= null`, y `_begin_current_room()` la vuelve a entrar, spawneando un segundo jefe en la misma sala.

**Cómo reproducir:**
1. Llegar al piso 13 y matar al jefe.
2. Pulsar "Continuar al siguiente piso" en el panel de victoria.
3. Aparece un nuevo jefe sin haber cambiado de escena.

**Reproducido por:** `tests/logic_audit.gd` (check nº 6, `FAIL`).

**Corrección sugerida:**

```gdscript
func start_after_boss() -> void:
    awaiting_floor_start = false
    awaiting_reward = false
    run.complete_current()
    var next := run.current_room()
    if next != null and not next.completed:   # ← sala completada = piso 13 finalizado
        _begin_current_room()
```

---

### BUG-P4 · Media · `scripts/enemy.gd` / `scripts/main.gd` — Multiplicadores de dificultad por piso no se aplican a los enemigos

**Ubicación:** `enemy.gd:setup_data()` líneas 98 y 100

```gdscript
max_hp = enemy_data.max_hp        # sin multiplicar por difficulty_multiplier
contact_damage = enemy_data.damage  # sin multiplicar por damage_multiplier
```

**Descripción:** `FloorConfig` calcula `difficulty_multiplier` (×1.96 en piso 13) y `damage_multiplier` (×1.72 en piso 13), pero `main.gd:_spawn_wave()` llama a `enemy.setup_data(player, enemy_data)` sin pasarle el config del piso. Los enemigos del piso 13 tienen exactamente los mismos puntos de vida y daño que los del piso 1.

**Cómo detectar:** El test `logic_audit.gd` verifica que `enemy.max_hp == enemy_data.max_hp * difficulty_multiplier` en el piso 13 → `FAIL` (escala sin aplicar).

**Corrección sugerida (dos pasos):**

1. Añadir parámetros opcionales a `setup_data`:

```gdscript
func setup_data(new_target, enemy_data: EnemyData,
                hp_mult := 1.0, dmg_mult := 1.0) -> void:
    ...
    max_hp = enemy_data.max_hp * hp_mult
    contact_damage = enemy_data.damage * dmg_mult
    if enemy_data.is_elite:
        max_hp *= 1.8   # el multiplicador de élite se aplica sobre la base ya escalada
    hp = max_hp
```

2. Pasar los multiplicadores desde `main.gd:_spawn_wave()`:

```gdscript
func _spawn_wave(wave: Array) -> void:
    var cfg := run.floor_config()
    for enemy_data in wave:
        var enemy := ENEMY.new()
        enemy.setup_data(player, enemy_data,
                         cfg.difficulty_multiplier, cfg.damage_multiplier)
        ...
```

---

### BUG-P5 · Baja · `scripts/systems/encounter_director.gd` línea 42 — Presupuesto cero genera un enemigo

**Ubicación:** `encounter_director.gd:42`

```gdscript
var remaining := maxi(1, budget)
```

**Descripción:** Si se llama `build_encounter` con `budget = 0`, la guardia `maxi(1, 0) = 1` permite generar al menos un enemigo de coste 1 (Echo). Las salas de servicios actuales (EVENT, SHOP, REST, REWARD) no llaman a `prepare_encounter`, por lo que en la práctica esto no ocurre. Sin embargo, es una discrepancia entre la intención (presupuesto cero = sin encuentro) y el comportamiento real.

**Corrección sugerida:**

```gdscript
var remaining := budget   # sin guardia; la sala con presupuesto 0 no genera enemigos
if remaining <= 0:
    return []
```

---

## Debilidades de cobertura en los tests

### COV-1 · `tests/validate_systems.gd` línea 56

```gdscript
assert(boss.connections.is_empty() or true, "boss con salidas")
```

La condición `or true` hace que la aserción **nunca falle**, independientemente del estado de `boss.connections`. La comprobación no verifica nada.

**Corrección sugerida:** Eliminar el `or true` y decidir qué se quiere verificar (¿la sala BOSS no tiene salidas? ¿tiene al menos una?).

---

### COV-2 · `tests/rewards_flow.gd` línea 45

```gdscript
ui.choose(ui.choices[0] if not ui.choices.is_empty() else ui.choices[0])
```

Ambas ramas de la condición ternaria son idénticas (`ui.choices[0]`), por lo que si `ui.choices` está vacío, el código produce igualmente un error de índice fuera de rango. Además, en ese punto `ui.pending` fue vaciado y el panel está oculto, por lo que `choose()` retorna sin aplicar ninguna recompensa, dejando el test en estado inconsistente.

---

### COV-3 · Tests de flujo del jefe no verifican el fallo P1

Las pruebas existentes de `floor_system.gd` matan al jefe directamente (`boss_node.take_damage(10000)`). Ningún test comprueba qué ocurre si se mata un **refuerzo** mientras el jefe sigue vivo, que es exactamente el escenario del BUG-P1.

---

### COV-4 · Tests de navegación no comprueban que el panel se cierre

`floor_system.gd:run_scene()` navega a la siguiente sala llamando directamente a `scene.go_to_room()`, sin pasar por el botón de la UI. El BUG-P2 (panel de rutas que no se cierra) solo se activa a través del botón real, por lo que las pruebas existentes no lo detectan.

---

## Cómo ejecutar los tests

Desde la carpeta raíz del workspace, con Godot instalado como Flatpak:

```sh
cd universe_of_harmony_godot_prototype

# Suites smoke (todas deberían dar 0 failures)
flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
  --fixed-fps 60 --script res://tests/items_smoke.gd

flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
  --fixed-fps 60 --script res://tests/combat_smoke.gd

flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
  --fixed-fps 60 --script res://tests/floor_system.gd

flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
  --fixed-fps 60 --script res://tests/team_survival.gd

# Auditoría de lógica (reproduce los bugs P1-P5; esperado: 5 failures)
flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto \
  --fixed-fps 60 --script res://tests/logic_audit.gd
```

> **Nota:** Antes de la corrección BUG-F2 (item_ui.gd), `logic_audit.gd` reportaba 6 failures. Con ese fix y las correcciones de la "Actualización posterior" ya aplicadas, el resultado actual es **9 checks, 0 failures** en ambas versiones del motor.

---

## Tabla de estado consolidada

| ID | Severidad | Archivo | Descripción corta | Estado |
|---|---|---|---|---|
| BUG-F1 | Crítico | `run_items.gd:281,317` | `art_index==3` detecta jefe incorrectamente | ✅ Corregido |
| BUG-F2 | Mayor | `item_ui.gd:148` | Pesos de rareza por sala no aplicados al pool | ✅ Corregido |
| BUG-F3 | Menor | `run_manager.gd:100` | Null access en `enter_room()` | ✅ Corregido |
| BUG-F4 | Menor | `main.gd:286` | Doble acceso y condición muerta en `_handle_room_cleared` | ✅ Corregido |
| BUG-P1 | Alta | `main.gd:273` | Matar refuerzo da victoria sobre jefe vivo | ✅ Corregido |
| BUG-P2 | Alta | `item_ui.gd:272` | Botón de ruta no cierra el panel ni reanuda el árbol | ✅ Corregido |
| BUG-P3 | Alta | `main.gd:304` | Piso 13: se re-spawnea el jefe al terminar | ✅ Corregido |
| BUG-P4 | Media | `enemy.gd:98,100` | Multiplicadores de dificultad/daño por piso ignorados | ✅ Corregido |
| BUG-P5 | Baja | `encounter_director.gd:42` | Presupuesto 0 genera 1 enemigo | ✅ Corregido |
| REF-1 | Media | `item_ui.gd:roll_choices` | Rareza por peso de sala, ítem uniforme después (LOGICA nº 4) | ✅ Corregido |
| COV-1 | — | `validate_systems.gd:56` | Aserción siempre verdadera (`or true`) | ✅ Corregido |
| COV-2 | — | `rewards_flow.gd:45` | Condición ternaria idéntica en ambas ramas | ✅ Corregido |
| COV-3 | — | `floor_system.gd` | No cubre matar refuerzo con jefe vivo | ✅ Corregido |
| COV-4 | — | `floor_system.gd` | Navegación sin pasar por botón de UI | ✅ Corregido |

---

## Actualización posterior (mismo día): P1–P5, REF-1 y COV-1..4 corregidos

Tras este reporte se aplicaron todas las correcciones pendientes y las debilidades
de cobertura, y se revalidó con `tests/logic_audit.gd` (que reproduce los fallos):

- **BUG-P1** — `scripts/main.gd`: `_on_enemy_defeated` solo completa el jefe si
  `_enemy.is_boss`; matar refuerzos ya no otorga la victoria. **Refinado horas
  después:** verificado en juego, la guardia no bastaba (el flujo genérico de
  presupuesto seguía completando la sala BOSS); se cerró con un retorno total en
  salas BOSS (ver BUG-P1 arriba). Además, por decisión de diseño, la sala BOSS ya
  **no invoca refuerzos**: se eliminó `boss_summon`/`_on_boss_summon`, el
  `enemy_summons` y el tag `summon` (solo `ranged|enrage`), y el jefe pelea en
  solitario.
- **BUG-P2** — `scripts/item_ui.gd:272`: el botón "Ir a: …" resetea
  `awaiting_reward`/`awaiting_floor_start`, cierra el panel y reanuda el árbol
  antes de navegar; además `main.go_to_room()` cierra de forma defensiva el panel
  si quedara abierto (cubre "Continuar" y las navegaciones de test).
- **BUG-P3** — `scripts/main.gd:start_after_boss()`: entra solo si la sala no está
  `completed`; el piso 13 ya no regenera el jefe.
- **BUG-P4** — `scripts/enemy.gd:setup_data()` admite `hp_mult`/`dmg_mult` (élite
  ×1.8 sobre la base escalada) y `main._spawn_wave()` pasa los multiplicadores de
  `run.floor_config()`.
- **BUG-P5** — `scripts/systems/encounter_director.gd`: presupuesto ≤ 0 devuelve
  encuentro vacío.
- **REF-1** — `item_ui.roll_choices()` elige primero la rareza por peso de la sala
  (`weights_for`) y después un ítem uniforme de esa rareza, respetando los
  porcentajes 45/30/15/8/2 sin distorsión por cantidad de objetos por rareza.
- **COV-1** — `validate_systems.gd`: `assert(boss.connections.is_empty(), …)` (el
  BOSS es terminal en el grafo; las ramas reconvergen antes).
- **COV-2** — `rewards_flow.gd`: elige la recompensa con el panel visible y
  `choices` no vacío (guarda real en vez de la ternaria idéntica).
- **COV-3** — `floor_system.gd`: verifica que la sala BOSS solo contiene al jefe,
  que el cambio de fase no invoca nada y que derrotar al jefe abre la transición
  de piso (sustituye al antiguo test de "matar refuerzo").
- **COV-4** — `floor_system.gd`: navega pulsando el botón real
  (`Button.pressed.emit()`) y verifica que el panel se cierra y el árbol se
  reanuda.

### Resultado revalidado

Ejecutado con Godot 4.7.2 (Flatpak) y 4.3 (binario headless), ambas sin fallos:

| Suite | Comprobaciones | Resultado |
|---|---:|---|
| validate_systems | aserciones internas (assert) | ✅ 0 fallos |
| floor_system | 86 (sala BOSS solo-jefe) | ✅ 0 fallos |
| combat_smoke | 16 | ✅ 0 fallos |
| items_smoke | 101 | ✅ 0 fallos |
| team_survival | 11 | ✅ 0 fallos |
| directional_controls | 15 | ✅ 0 fallos |
| rewards_flow | 9 | ✅ 0 fallos |
| art_smoke | 42 | ✅ 0 fallos |
| hud_smoke | 8 | ✅ 0 fallos |
| logic_audit | 9 (antes 5 fallos / 6 en la primera auditoría) | ✅ 0 fallos |

Además, 20 segundos de ejecución real headless sin errores de script. Registros
actualizados en `tests/results/`.
