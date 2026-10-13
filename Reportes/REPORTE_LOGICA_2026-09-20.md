# Auditoría de lógica — 20 de septiembre de 2026

## Resultado

No se puede declarar correcto todo el código: la auditoría adicional reproduce **6 fallos en 9 comprobaciones**. Las nueve suites originales pasan, con 280 comprobaciones `PASS` más las aserciones de `validate_systems.gd` (5 seeds × 3 pisos y validación de recursos).

Se ejecutó Godot **4.7.2 stable (Flatpak)**, en modo headless con `--fixed-fps 60`. La importación del editor finalizó correctamente. No se observaron errores de script en las suites ejecutadas. Esto no certifica todas las combinaciones de juego ni constituye una revisión visual/manual o una validación en Godot 4.3.

## Pruebas existentes

| Suite | Comprobaciones PASS | Resultado |
|---|---:|---|
| art_smoke | 42 | Correcto |
| combat_smoke | 16 | Correcto |
| directional_controls | 15 | Correcto |
| floor_system | 81 | Correcto |
| hud_smoke | 8 | Correcto |
| items_smoke | 99 | Correcto |
| rewards_flow | 8 | Correcto |
| team_survival | 11 | Correcto |
| validate_systems | Aserciones internas | Correcto |

Los registros de estas ejecuciones están en `tests/results/*.log`.

## Fallos reproducidos

1. **Alta — Navegar a una sala de combate deja la interfaz de rutas abierta y el árbol pausado.** `scripts/item_ui.gd:256` conecta los botones directamente a `game.go_to_room()`. `scripts/main.gd:362` cambia la sala sin cerrar el panel ni reanudar el árbol. La auditoría configura una ruta válida como COMBAT, pulsa la señal del botón real y verifica que la sala cambia pero el menú anterior permanece.
2. **Alta — Derrotar un refuerzo otorga la victoria sobre un jefe todavía vivo.** `scripts/main.gd:267` llama a `_handle_boss_cleared()` por cualquier enemigo derrotado mientras el tipo de sala sea BOSS. El caso reproduce una invocación en la fase 2 y mata solo al refuerzo; se activa la transición de piso y se encola la recompensa de jefe.
3. **Alta — El final del piso 13 vuelve a generar al jefe.** `scripts/main.gd:303` llama a `_begin_current_room()` después de `run.complete_current()`. En el último piso, RunManager emite `run_completed` pero mantiene la sala actual; esta vuelve a iniciarse. La señal de final sí se emite, pero la escena vuelve a tener un jefe.
4. **Media — Las recompensas élite tienen la misma selección que las normales.** `scripts/item_ui.gd:148` usa `rarity_weight()` con los pesos base; los pesos por tipo de sala solo filtran rarezas con peso cero. En 100 seeds emparejadas, COMBAT y ELITE producen exactamente las mismas opciones. Además, ponderar cada objeto por el peso de su rareza hace depender la probabilidad total de cuántos objetos haya de esa rareza. Para respetar los porcentajes documentados se necesita seleccionar primero una rareza entre las disponibles y después un objeto de esa rareza.
5. **Media — El escalado de vida y daño por piso no se aplica a los enemigos.** `FloorConfig` calcula ambos multiplicadores, pero la creación de enemigos en `main.gd` y `enemy.gd` conserva los valores base de EnemyData (y el aumento propio de élite). El caso verifica enemigos reales del START del piso 13 contra los multiplicadores configurados.
6. **Baja — Un presupuesto cero genera enemigos.** `scripts/systems/encounter_director.gd:42` convierte el presupuesto en al menos 1 mediante `maxi(1, budget)`. Con el enemigo Echo de coste 1, un presupuesto 0 genera una oleada de coste 1. Es un caso límite del sistema; las salas de servicios actuales no solicitan encuentros.

## Debilidades de cobertura detectadas

- `tests/validate_systems.gd:56` usa `assert(boss.connections.is_empty() or true, ...)`; esa condición siempre pasa.
- `tests/rewards_flow.gd:45` selecciona `choices[0]` en ambas ramas de la condición, incluso si la lista está vacía. Además, previamente oculta el panel, por lo que `choose()` retorna sin aplicar una recompensa.
- Las pruebas de pisos verifican fases e invocaciones, pero no matan un refuerzo antes que al jefe ni verifican el final del piso 13.
- Navegar mediante llamadas directas al controlador no comprueba que los botones cierren el panel de rutas.

## Reproducir la auditoría

Desde la carpeta raíz del workspace:

```sh
flatpak run org.godotengine.Godot --headless --path mamamoo_universe_proto --fixed-fps 60 --script res://tests/logic_audit.gd
```

Resultado esperado con el código actual: `LOGIC AUDIT RESULT: 9 checks, 6 failures`, código de salida 1. Esos fallos se dejan visibles intencionalmente: representan errores reproducidos, no una corrección aplicada.

## Alcance de los cambios

Se añadió `tests/logic_audit.gd`, este reporte y registros de pruebas. No se modificaron scripts de producción. La importación de Godot puede actualizar su caché y metadatos generados. El directorio no dispone de un repositorio Git operativo, por lo que no fue posible obtener un diff mediante Git.

## Corrección posterior (mismo día)

Tras esta auditoría se corrigieron los 6 fallos reproducidos y las 4 debilidades
de cobertura (ver `REPORTE_ANALISIS_CODIGO_2026-09-20.md`, "Actualización
posterior"):

1. El botón de ruta ahora cierra el panel y reanuda el árbol antes de navegar
   (`scripts/item_ui.gd:272` + cierre defensivo en `main.go_to_room()`).
2. Matar un refuerzo ya no otorga la victoria sobre el jefe vivo
   (`main.gd`: condición `and _enemy.is_boss`; refinado después a retorno total
   para salas BOSS). Además, por petición del usuario la sala BOSS quedó
   **solo-jefe**: se eliminó la invocación de refuerzos (`boss_summon`
   /`_on_boss_summon`, `enemy_summons` y tag `summon`), conservando fases y furia.
3. El final del piso 13 no vuelve a generar el jefe (`start_after_boss()` entra
   solo si la sala no está `completed`).
4. Las recompensas élite aplican pesos distintos y, además, ahora se elige
   primero la rareza por peso y después un ítem de esa rareza (`roll_choices`).
5. El escalado de vida y daño por piso se aplica a los enemigos
   (`setup_data(hp_mult, dmg_mult)` + `_spawn_wave` con el `floor_config`).
6. Un presupuesto cero ya no genera enemigos (`encounter_director`).

Las debilidades de cobertura se resolvieron: `validate_systems` verifica que el
BOSS es terminal, `rewards_flow` elige con panel visible, y `floor_system`
verifica la sala BOSS solo-jefe (COV-3, ya sin refuerzos) y navegó con el botón
real de la UI (COV-4).

### Revalidación

Con Godot **4.7.2 (Flatpak)** y **4.3 (binario headless)**, todas las suites
pasan: `logic_audit.gd` → **9 checks, 0 failures**; `floor_system.gd` → 86
pass (sala BOSS solo-jefe), 0 fallos; `combat_smoke` 16, `items_smoke` 101, `team_survival` 11,
`directional_controls` 15, `rewards_flow` 9, `art_smoke` 42, `hud_smoke` 8 y
`validate_systems` (asserts) sin fallos. 20 segundos de ejecución real headless
sin errores de script. Registros en `tests/results/*.log`.
