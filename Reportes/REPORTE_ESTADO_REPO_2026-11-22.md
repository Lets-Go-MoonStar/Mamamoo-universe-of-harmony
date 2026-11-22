# Estado del repositorio — 22 noviembre 2026

## Problemas encontrados

| # | Problema | Causa | Acción |
|---|---|---|---|
| 1 | Falta `assets/` | Nunca se subió al commit único de GitHub (`Add files via upload`) | Placeholders PNG en las 91 rutas referenciadas + `assets/README.md` + generador |
| 2 | Tests huérfanos | Había `.uid` sin `.gd` (`logic_audit`, `visual_integration`); faltaban `items_smoke`, `rewards_flow`, `boundary_cases` | Suites restauradas / reescritas |
| 3 | Previews `art_stage_4/6/7/8.png` | Solo quedaban `.import` | Placeholders creados |
| 4 | Bugs P1–P5 del reporte 20-sep | Pendientes en el informe histórico | Verificados en código actual (ya corregidos) |
| 5 | Sin `.gitignore` | Carpeta `.godot/` y basura local podían colarse | Añadido `.gitignore` |

## Verificación de bugs (código actual)

| ID | Estado | Evidencia |
|---|---|---|
| P1 jefe/refuerzos | Corregido (y diseño: sala BOSS solo-jefe) | `main.gd:_on_enemy_defeated` solo completa si `_enemy.is_boss` |
| P2 rutas sin `close()` | Corregido | `item_ui.gd` botón de ruta llama `close()` antes de `go_to_room` |
| P3 piso 13 regenera jefe | Corregido | `start_after_boss` exige `next != null and not next.completed` |
| P4 escalado por piso | Corregido | `_spawn_wave` pasa `cfg.difficulty_multiplier` / `damage_multiplier` a `setup_data` |
| P5 presupuesto 0 | Corregido | `EncounterDirector.build_encounter` retorna `[]` si `budget <= 0` |
| COV-1 `or true` | Corregido | `validate_systems.gd` aserta `boss.connections.is_empty()` |

## Assets

- **Origen real:** no está en este PC, ni en GitHub, ni en `Juego de mamamoo` (ese pack es otro prototipo web).
- **Ahora:** 91 placeholders con tamaños coherentes con atlases/spritesheets.
- **Restaurar arte final:** sobrescribir `assets/` con el pack original (mismas rutas).

## Tests restaurados

- `tests/logic_audit.gd`
- `tests/items_smoke.gd`
- `tests/rewards_flow.gd`
- `tests/visual_integration.gd`
- `tests/boundary_cases.gd`

Nota: no son copias bit-a-bit de las suites originales (nunca estuvieron en git); recrean la cobertura descrita en los reportes de septiembre.

## Pendiente del usuario

1. Sustituir placeholders por el pack visual real (si aún lo tienes en otra máquina / backup / OneDrive).
2. Instalar Godot 4.x y correr la batería headless.
3. Decidir si se hace commit de `assets/` placeholders o se publica el arte vía LFS / release.
