# Reporte de trabajo — Universe of Harmony

**Identificador:** `UOH-20260921-001`  
**Fecha:** 21 de septiembre de 2026  
**Proyecto:** `mamamoo_universe_proto`  
**Ruta:** `res://`

## Alcance

Este reporte reúne el trabajo realizado en la conversación sobre pruebas de lógica, organización de recursos visuales, integración de assets y correcciones de interfaz y animaciones.

## Pruebas de lógica

Se ejecutaron las suites headless de Godot para combate, controles, pisos, HUD, objetos, recompensas, supervivencia, arte y casos límite.

La auditoría adicional `tests/logic_audit.gd` llegó a detectar seis problemas de flujo. Fueron corregidos y posteriormente verificó:

- Navegar a una sala cierra el menú y reanuda el árbol.
- Los refuerzos no cuentan como derrota del jefe.
- El piso 13 emite el final una sola vez y no regenera al jefe.
- Las recompensas élite usan pesos distintos.
- El escalado de vida y daño por piso se aplica a enemigos.
- Un presupuesto cero no genera enemigos.

Resultado final de la auditoría: **9 comprobaciones, 0 fallos**.

También pasaron las pruebas visuales y de combate:

- `visual_integration.gd`: 0 fallos.
- `art_smoke.gd`: 0 fallos.
- `combat_smoke.gd`: 16 comprobaciones correctas.
- `items_smoke.gd`: 101 comprobaciones correctas.
- `floor_system.gd`: 0 fallos.
- `boundary_cases.gd`: 43 comprobaciones correctas.

## Assets iniciales

Se organizaron y conectaron las hojas de personajes, recuperación, enemigos, jefe, proyectiles, efectos, iconos y arquitectura.

Las cuatro hojas antiguas de personajes fueron reemplazadas por las transparentes nuevas y se actualizó `scripts/actor_art.gd` para usar:

```text
assets/characters/transparent/solar_spritesheet.png
assets/characters/transparent/moonbyul_spritesheet.png
assets/characters/transparent/wheein_spritesheet.png
assets/characters/transparent/hwasa_spritesheet.png
```

Se conectaron también:

- Hojas de recuperación en `assets/characters/recovery/`.
- Atlas de proyectiles, combate y estados en `assets/vfx/`.
- Iconos y marcos de recompensa en `assets/ui/icons/`.
- Arquitectura celestial en `assets/environment/tilesets/`.
- Variantes de enemigos en `scripts/actor_art.gd` y `scripts/enemy.gd`.
- Decoración de biomas en `scripts/main.gd`.

## Jefes y regiones

Las hojas de referencia de Eco Overlord y Crystal Critic se normalizaron a hojas de 1024×1024 con celdas de 128×128. Se conservaron las referencias originales.

Rutas finales:

```text
assets/enemies/bosses/twin_echo/echo_overlord_spritesheet.png
assets/enemies/bosses/twin_echo/echo_overlord_reference.png
assets/enemies/bosses/crystal_critic/crystal_critic_spritesheet.png
assets/enemies/bosses/crystal_critic/crystal_critic_reference.png
```

Se añadieron animaciones direccionales con el patrón definido en la especificación:

```text
idle_s, idle_se, idle_e, idle_ne, idle_n, idle_nw, idle_w, idle_sw
move_s, attack_1_s, attack_2_s, special_s
phase_change_s, hurt_s, death_s
```

También se mantuvieron aliases compatibles (`idle`, `move`, `attack`, `ability`) para el controlador actual.

## Assets adicionales de integración

Se organizaron los recursos de biomas, jefes, tilesets, HUD, iconos, tiendas y pantallas:

```text
assets/environment/lunar_ruins/
assets/environment/neon_district/
assets/enemies/bosses/twin_echo/
assets/enemies/bosses/crystal_critic/
assets/vfx/bosses/
assets/ui/icons/
assets/ui/shop/
assets/ui/screens/
assets/ui/systems/
assets/ui/events/
assets/ui/bosses/
assets/ui/vfx/
assets/ui/npcs/
```

Los atlas funcionales quedaron conectados de esta forma:

- Efectos de Eco Overlord y Crystal Critic durante ataques y cambios de fase.
- Iconos de tipo de sala en los botones de navegación.
- Tilesets de Ruinas Lunares y Distrito Neón como decoración de escenario.
- Retratos y marcos corregidos en el HUD.
- Efectos elementales separados por integrante.
- Asignación de `neon_assassin` y `resonance_totem` a variantes de enemigos.

Las láminas que contienen textos y composiciones de diseño se conservaron como referencias y no se usan directamente como fondos jugables.

## Galería de referencias Fase 3

Se añadió una galería dentro del inventario. Para abrirla:

1. Pulsar `I`.
2. Seleccionar `Galería Fase 3`.

La galería muestra las 48 referencias nuevas de biomas, tilesets, NPCs, tiendas, eventos, jefes, efectos, sistemas y pantallas. Los recursos se cargan como miniaturas manteniendo su proporción.

La implementación está en `scripts/item_ui.gd`, mediante `PHASE3_REFERENCE_ASSETS` y `open_phase3_gallery()`.

## Archivos de producción modificados

- `scripts/actor_art.gd`
- `scripts/enemy.gd`
- `scripts/main.gd`
- `scripts/player.gd`
- `scripts/item_ui.gd`
- `scripts/visual_assets.gd`
- `scripts/projectile.gd`
- `scripts/enemy_projectile.gd`
- `scripts/run_items.gd`
- `scripts/item_catalog.gd`

También se añadieron o actualizaron pruebas de integración visual en `tests/`.

## Importación y estado final

Godot reimportó los recursos nuevos correctamente mediante el editor headless. No quedaron imágenes nuevas sin clasificar en la raíz de `assets/` durante las revisiones realizadas.

El proyecto conserva las imágenes de referencia originales cuando fueron necesarias para comparación o respaldo. Las referencias con texto incrustado se usan en la galería y como guía de diseño; los sprites normalizados se usan en combate.

## Observación técnica

Los assets de referencia no deben sustituir directamente una interfaz dinámica ni un TileMap final cuando contienen texto, etiquetas o varias pantallas en una misma imagen. La galería permite revisarlos dentro del juego sin introducir esos textos como parte fija de la interfaz.
