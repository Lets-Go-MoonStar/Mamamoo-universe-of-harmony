# Universe of Harmony — reporte de trabajo

Fecha: 20 de septiembre de 2026  
Proyecto: prototipo Godot 4.x  
Ruta: `mamamoo_universe_proto/`

## Resultado de hoy

El prototipo pasó de usar gráficos provisionales a tener una presentación jugable con personajes, enemigos, escenarios, HUD, controles direccionales, vida individual por integrante, salas de combate, recompensas e inventario. También se integraron las imágenes de ítems y sus efectos principales a partir de `Universe_of_Harmony_Item_Stats.docx`.

### Actualización vespertina: sistema procedural (especificación de programación)

A partir de `Universe_of_Harmony_Especificacion_Programacion.docx` se implementó el **primer hito del diseño experimental**: 3 pisos procedurales, 10 variantes de enemigos (5 arquetipos), 3 jefes con fases, 5+ tipos de sala, recompensas por rareza y semilla reproducible.

- **Capa de datos (Resources `.tres`)** en `resources/`:
  - `enemy_pool/` — 10 variantes (echo, echo_swift, echo_armored, echo_corrupted, echo_elite, feedback, feedback_elite, mute, mute_elite, tuner) con coste de dificultad según la tabla del GDD (1/2/3/4/5) y rango de piso válido (`EnemyData`).
  - `boss_pool/` — Echo Overlord (1-2), Crystal Critic (2-4), Eclipse (3-13), con fases 100/70/35 y abilities `ranged|enrage` (`BossData`). La sala BOSS contiene únicamente al jefe (sin invocación de refuerzos).
  - `floor_configs/` — pisos 1, 2 y 3 con número de salas, presupuesto, probabilidades de sala y pools (`FloorConfig`). De 4 a 13 se usa `FloorConfig.make_default` (rangos y escalado del GDD).
- **Nuevos sistemas** en `scripts/systems/`:
  - `RoomData` — nodo del grafo (tipo, conexiones, presupuesto, estado).
  - `FloorGenerator` — grafo con ruta garantizada `START → … → BOSS` y ramas que reconvergen (sin bucles ni callejones).
  - `EncounterDirector` — EncounterBudget por coste, élites al final, tope de activos (small 4 / medium 7 / large 10) y oleadas.
  - `RewardManager` — rarezas 45/30/15/8/2, tres opciones por sala, mejoradas para élite/jefe (el jefe nunca da comunes).
  - `RunManager` — seed reproducible (`R` = misma seed, `M` = run nueva), piso, selección de jefe y señales estándar (`room_completed`, `boss_defeated`, `floor_completed`, `run_completed`).
- **IA enemiga y jefes** (`scripts/enemy.gd`): arquetipos chaser/swarm/tank/ranged/élite; ranged dispara con `scripts/enemy_projectile.gd`; jefes con fases y furia (<50%), en solitario (la sala BOSS no invoca refuerzos).
- **Salas fuera de combate**: REWARD (recompensa inmediata), SHOP (3 ítems con precio por rareza), EVENT (evento aleatorio), REST (curación) y elección de ruta en el mapa del piso.
- **Pruebas**: nuevas suites `tests/validate_systems.gd` y `tests/floor_system.gd` (grafo, seeds, presupuesto, rarezas, jefe con fases) y actualización de `combat_smoke`/`rewards_flow` al flujo procedural.

## Assets organizados

Se crearon y organizaron estas carpetas:

- `assets/characters/`: hojas de sprites de Solar, Moonbyul, Wheein y Hwasa.
- `assets/enemies/`: cuatro hojas de enemigos, incluido Eclipse.
- `assets/backgrounds/`: nueve escenarios ilustrados.
- `assets/ui/`: hojas de HUD y menús.
- `assets/items/`: dos hojas con los 32 iconos de objetos.

Los archivos recibieron nombres descriptivos. Los PNG se conservaron sin recortes destructivos; el juego obtiene regiones mediante `AtlasTexture`.

## Assets nuevos integrados (noche)

Se integraron 8 imágenes nuevas añadidas a `assets/`:

- **5 hojas de enemigos** (`assets/enemies/{crimson_reaper,astral_mage,neon_assassin,crystal_sentinel,resonance_totem}_spritesheet.png`, 1024x1536): reemplazan al atlas compartido de enemigos en `scripts/actor_art.gd`. Cada arquetipo usa ahora su propia hoja dedicada, con la misma rejilla de filas que los personajes (idle 0-280, move 280-540, attack 540-780, ability 780-1040). Mapeo `arquetipo → hoja`: `chaser → crimson_reaper`, `ranged → astral_mage`, `resto → neon_assassin`, `tank → crystal_sentinel`, `swarm → resonance_totem`. La silueta de muerte sigue usando el atlas `enemy_variants_overview.png`.
- **`assets/ui/portraits/member_portraits_atlas.png`**: retratos de las 4 integrantes; se usan como textura de los botones 1-4 del HUD (`scripts/combat_hud.gd`), recortando cada columna (grid asumido 4x1; banda superior cabeza/torso).
- **`assets/ui/member_frames_hud_atlas.png`**: marco decorativo detrás de cada botón de integrante (grid asumido 2x2).
- **`assets/vfx/elemental_abilities_atlas.png`**: ráfaga elemental al lanzar la habilidad, por fila de integrante (grid asumido 4x4), vía `VISUALS.burst` en `scripts/player.gd`.

Los recortes de los 3 atlas de UI/VFX se hicieron por convención del proyecto y conviene revisarlos visualmente en partida por si el grid real difiere.

## Personajes y enemigos

`scripts/actor_art.gd` construye y almacena animaciones desde las hojas de sprites. Cada personaje tiene reposo, movimiento, ataque, habilidad, esquiva, daño y derrota. Los enemigos tienen movimiento y ataque; Eclipse usa más vida, daño y tamaño.

Cada integrante conserva su propia Voz. Cuando una cae queda bloqueada, se activa automáticamente la siguiente integrante viva y recibe un segundo de protección. La partida solo termina cuando caen las cuatro; reiniciar restaura al equipo completo.

## Escenarios

Se integraron nueve fondos seleccionables con `N` o desde el selector superior derecho:

1. Arena del eclipse
2. Palacio estelar
3. Jardines del amanecer
4. Ruinas lunares
5. Cascadas de cristal
6. Castillo de fuego
7. Ciudad neón
8. Vacío fragmentado
9. Trono del eclipse

## HUD y controles

El HUD usa `ui_hud_spritesheet.png` y `ui_menus_spritesheet.png`. Muestra Voz, Armonía, energía, escudo, cadena, cooldowns, monedas, experiencia y el estado de cada integrante.

- Flechas: mover al personaje.
- `W`, `A`, `S`, `D`: disparar arriba, izquierda, abajo y derecha.
- Si se mantienen varias teclas de disparo, tiene prioridad la última pulsada.
- `E`: habilidad, con 100 de energía.
- `Q`: activar Ad-lib al alcanzar 100 de Armonía.
- `Shift`: esquiva.
- `1`–`4`: cambiar integrante.
- `I`: abrir inventario y catálogo.
- `N`: cambiar escenario.
- `R`: reiniciar.

Los disparos básicos no apuntan en diagonal. Las flechas pueden mover al personaje mientras se mantiene una tecla de disparo.

## Sistema de objetos

Las hojas se renombraron como:

- `assets/items/reward_items_spritesheet.png`
- `assets/items/relic_items_spritesheet.png`

`data/items.json` contiene los 32 ítems del documento de estadísticas, con identificador, nombre, rareza, categoría, límite de acumulación, descripción y región del icono.

Los scripts principales son:

- `scripts/item_catalog.gd`: catálogo e iconos.
- `scripts/run_items.gd`: inventario y efectos durante la partida.
- `scripts/item_ui.gd`: inventario, catálogo, recompensas, cofres y servicios entre salas.

Se conectaron generación de Armonía, reducción de cooldown, daño condicional, curación, escudos, velocidad, energía, resurrección, experiencia, reliquias personales, vínculos de dúo/trío/cuarteto, Ad-lib, Echo Orb, fragmentos de jefe, brújula y talismanes.

La curación se adaptó a la vida individual: las pociones curan a integrantes vivas y no reviven. `Revival Feather` se consume una vez cuando cae la última integrante y restaura 30% de Voz al equipo.

## Salas y recompensas

Las salas son finitas. Al derrotar a los enemigos aparece una ventana que pausa el combate y ofrece tres recompensas distintas. Se puede elegir una, renovar opciones con una moneda u omitir.

- Cada eliminación concede una moneda y experiencia; Eclipse concede más experiencia.
- Cada 100 EXP abre otra elección.
- Las monedas permiten renovar recompensas o curar al equipo entre salas.
- Las llaves abren cofres especiales y los tickets abren recompensas raras o superiores.
- Las salas élite aparecen cada tres salas y las de jefe cada cinco.
- `Portal Compass` muestra el tipo de la siguiente sala de la ruta lineal actual.

El inventario se consulta con `I`; el catálogo también muestra objetos que todavía no se poseen.

## Adaptaciones documentadas

El documento fuente propone Voz compartida, mientras que el prototipo usa Voz individual por integrante. La adaptación está descrita en [docs/items_implementation.md](docs/items_implementation.md), junto con los valores usados donde el documento no definía cantidades exactas.

El cofre legendario solicita tres reliquias legendarias, pero el documento solo define `Quartet Crown` como reliquia legendaria. Actualmente ofrece una combinación de reliquias épicas y legendarias disponibles; el comportamiento está indicado en la descripción del ítem.

El texto original extraído del DOCX se conserva en [docs/item_stats_source.txt](docs/item_stats_source.txt).

## Verificación

Se comprobaron combate, supervivencia de las cuatro integrantes, controles WASD y flechas, animaciones, escenarios, HUD, catálogo, efectos de los 32 objetos, recompensas, cofres, tickets y continuación de salas. En la fase vespertina se añadieron las suites procedurales.

Resultados registrados (3 ejecuciones consecutivas, 0 fallos en todas):

- 16 comprobaciones de combate: 0 fallos.
- 11+ comprobaciones de supervivencia: 0 fallos.
- 15 comprobaciones de controles: 0 fallos.
- 99 comprobaciones de objetos y efectos: 0 fallos.
- Flujo de recompensas (3 opciones, seed, rutas, siguientes salas): 0 fallos.
- `validate_systems.gd` (10 enemigos, 3 jefes, 3 pisos × 5 seeds): 0 fallos.
- `floor_system.gd` (reproducibilidad, grafo, presupuesto/oleadas, rarezas, jefe con fases): 0 fallos.
- HUD, arte y escenarios: 0 fallos.
- 20 segundos de ejecución real headless sin errores de script.

Comandos principales:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/combat_smoke.gd
godot --headless --path . --fixed-fps 60 --script res://tests/team_survival.gd
godot --headless --path . --fixed-fps 60 --script res://tests/directional_controls.gd
godot --headless --path . --fixed-fps 60 --script res://tests/items_smoke.gd
godot --headless --path . --fixed-fps 60 --script res://tests/rewards_flow.gd
godot --headless --path . --fixed-fps 60 --script res://tests/validate_systems.gd
godot --headless --path . --fixed-fps 60 --script res://tests/floor_system.gd
```

## Archivos de referencia

- [README.md](README.md): descripción general y controles.
- [data/items.json](data/items.json): catálogo estructurado.
- [docs/items_implementation.md](docs/items_implementation.md): decisiones y adaptaciones.
- [scripts/main.gd](scripts/main.gd): flujo de salas, run procedural, escenarios.
- [scripts/systems/](scripts/systems/): EnemyData, BossData, FloorConfig, RoomData, FloorGenerator, EncounterDirector, RewardManager y RunManager.
- [resources/](resources/): datos `.tres` de enemigos, jefes y pisos.
- [scripts/enemy.gd](scripts/enemy.gd): arquetipos IA y jefes con fases.
- [scripts/player.gd](scripts/player.gd): combate, vida individual y cambios de integrante.
- [scripts/run_items.gd](scripts/run_items.gd): efectos de objetos.
- [scripts/item_ui.gd](scripts/item_ui.gd): inventario, recompensas, rutas, tienda y evento.

## Pendientes conocidos

- Definir dos reliquias legendarias adicionales para completar las tres opciones del cofre celestial.
- Puzzle/encuentros únicos para salas EVENT y recompensas especiales por sala REWARD (hoy ofrecen casos simples).
- Balanceo fino de presupuestos y jefes a partir de partidas reales (probar el recorrido completo 1-3).
- Sustituir valores provisionales cuando se definan Compostura, Ad-lib y las reacciones elementales completas.
- Añadir persistencia de la partida si se desea conservar inventario entre sesiones.
- Pisos 4-13: partidas extendidas con la configuración automática (falta su ficha `.tres` propia y pools específicos).
