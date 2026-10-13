# Universe of Harmony — Prototype (completo)

Prototype for **Godot 4.x** validating the core loop of the source GDD:
procedural dungeons, a 4-member switchable team fighting through rooms with
individual **Voice** health, Harmony chains, abilities, a 32-item inventory
and data-driven enemies/bosses/floors.

This is a fan prototype. No copyrighted art, music, logos or recordings are
included; all visuals are provided assets of the project.

## What is implemented

**Combate y equipo**
- Four switchable members: **Solar, Moonbyul, Wheein, Hwasa**.
- Individual **Voice** (health) per member. When one falls she is blocked and
  control automatically rotates to the next living member with protection.
  The run ends only when all four fall.
- **Harmony Chain**: Solo -> Duet -> Trio -> Quartet by landing attacks with
  distinct members within a short window.
- **Harmony** meter (Q activates **Ad-lib** at 100%).
- **Abilities** (E, costs 100 energy) and **Tag Skills** on member switch.
- Dodge (Shift) with invulnerability window.

**Dungeon procedural (sección 1-9 de la especificación)**
- **Pisos** data-driven: `resources/floor_configs/floor_1..3.tres`; de 4 a 13
  se genera una configuración por defecto respetando los rangos del GDD y el
  escalado `hp = 1+(piso-1)*0.08`, `dmg = 1+(piso-1)*0.06`.
- **Grafo de salas** por piso (`RoomData` + `FloorGenerator`): siempre existe
  una ruta válida `START -> ... -> BOSS`, con rutas alternativas que reconvergen
  (sin bucles ni callejones). Tipos: COMBAT, ELITE, EVENT, REWARD, SHOP, REST y
  BOSS.
- **Enemigos** data-driven (10 variantes / 5 arquetipos IA): chaser, swarm,
  tank, ranged (dispara `enemy_projectile`) y élite (`enrage`). Viven en
  `resources/enemy_pool/*.tres` (`EnemyData`).
- **Jefes** (3) con fases por umbrales 100/70/35% y abilities
  `ranged | enrage`: Echo Overlord (pisos 1-2), Crystal Critic
  (2-4) y Eclipse (3-13). Pool en `resources/boss_pool/*.tres` (`BossData`).
  La sala BOSS contiene únicamente al jefe: no invoca refuerzos.
- **EncounterBudget** (`EncounterDirector`): composición de salas por coste de
  dificultad, élites al final, tope de enemigos simultáneos (small 4, medium 7,
  large 10) y división en oleadas.
- **RunManager**: `R` reinicia con la MISMA seed (mapa idéntico), `M` genera
  una run nueva; las señales estándar (`room_completed`, `boss_defeated`,
  `floor_completed`, `run_completed`) desacoplan al MC central.
- **Recompensas** (`RewardManager`): rarezas 45/30/15/8/2, tres opciones por
  sala, mejoradas para élite y jefe (el jefe nunca da comunes).

**Servicios & economía**
- Coins, XP/levels, keys, tickets, chests (cofre con llave y cofre celestial),
  y 32 ítems (healing, shields, speed, cooldown, relics, duo/trio/quartet,
  Ad-lib, Echo Orb, boss fragments, compass, talismans...).
- **Inventario y catálogo** (I). Tienda en salas SHOP, curación y mejoras en
  las rutas, salas REWARD y eventos (EVENT).
- Nueve **fondo**s (N o dropdown); el bioma del piso se aplica automáticamente.

## Controls

- **Arrows**: move
- **W / A / S / D**: shoot up / left / down / right (last key held wins)
- **E**: ability (requires 100 energy)
- **Q**: Ad-lib (requires 100 Harmony)
- **Shift**: dodge
- **1 / 2 / 3 / 4**: switch member
- **I**: inventory and catalog
- **N**: next background
- **R**: restart with the same seed
- **M**: new run (new seed)

## Run

1. Install Godot 4.x (`godot` or the provided binary at
   `/tmp/opencode/godot_bin/Godot_v4.3-stable_linux.x86_64`).
2. Import the folder containing `project.godot` (`--headless --import` the
   first time so the global class cache is rebuilt).
3. Open the project and press **F5** (or run headless).

## Tests

Headless suites live in `tests/`. From the project folder:

```sh
GODOT=/tmp/opencode/godot_bin/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --fixed-fps 60 --script res://tests/validate_systems.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/floor_system.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/combat_smoke.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/items_smoke.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/team_survival.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/directional_controls.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/rewards_flow.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/art_smoke.gd
$GODOT --headless --path . --fixed-fps 60 --script res://tests/hud_smoke.gd
```

`floor_system.gd` cubre el sistema procedural: reproducibilidad por seed,
validez del grafo, presupuesto/oleadas, rarezas y flujo completo (recompensa,
rutas y jefe con fases).

## Reference files

- `data/items.json` — 32-item catalog (id, rarity, category, stack limit, icon cell).
- `docs/items_implementation.md` — design adaptations and prototype values.
- `docs/item_stats_source.txt` — raw text extracted from the source GDD.
- `REPORTE_TRABAJO_2026-09-20.md` — work report for 20 September 2026.
- `scripts/systems/*.gd` — sistemas data-driven (EnemyData, BossData,
  FloorConfig, RoomData, FloorGenerator, EncounterDirector, RewardManager y
  RunManager).
- `resources/enemy_pool/`, `resources/boss_pool/`, `resources/floor_configs/`
  — datos de enemigos, jefes y pisos.

## Notes / adaptations

The source GDD proposes a shared Voice meter; the prototype uses individual
Voice per member (see `docs/items_implementation.md`). The celestial chest asks
for three legendary relics, but the doc only defines `Quartet Crown`, so it
currently offers a fallback pool of epic/legendary relics. Las salas de pisos
4-13 usan `FloorConfig.make_default`, que referencia la pool completa y filtra
por rango de piso de cada variante.

## Next milestones

1. Two more legendary relics so the celestial chest always offers three.
2. Maps/mapa visual del piso y reselección de ruta antes de entrar.
3. Numbers definitivos de Composure / Ad-lib / reacciones elementales.
4. Persistencia de sesión (inventario entre partidas).