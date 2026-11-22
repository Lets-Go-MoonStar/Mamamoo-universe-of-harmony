# Playtest humano — 5 runs por ruta

El audit sintético **no** sustituye esto. Objetivo: 5 runs jugadas por persona en cada ruta (Solar / Moonbyul / Wheein / Hwasa).

## Antes
1. En **Mejoras**, elige la ruta a testear (45 ✦ la primera vez).
2. Asegúrate de que el juego escribe telemetría: al terminar cada run se appendea a `user://playtest_runs.jsonl`.
3. En pantalla de fin verás contadores `Playtest 5×ruta: S# M# W# H#`.

## Por cada run (checklist)
- [ ] Ruta correcta al empezar (borde de arena del color de la integrante)
- [ ] Al menos 1 **room modifier** visto (piso 5+)
- [ ] Al menos 1 **élite set piece** o patrón distinto
- [ ] 1 jefe con cambio de fase (lee el label: ECHO RING / CRYSTAL CORNERS / …)
- [ ] Anota feel 1–5: poder / dificultad / diversión / fatiga
- [ ] Notas libres (opcional): pegar en un doc o en el JSON manualmente

## Meta de cobertura
| Ruta | Runs humanas |
|------|----------------|
| Solar | 5 |
| Moonbyul | 5 |
| Wheein | 5 |
| Hwasa | 5 |

Cuando los 4 lleguen a 5, exporta `user://playtest_runs.jsonl` y revisad balance/feel juntos.

## Dónde está el log (Windows)
`%APPDATA%\Godot\app_userdata\<nombre_proyecto>\playtest_runs.jsonl`

## Arte / SFX reales
Sustituye `assets/sfx/{kind}.wav` (ver `assets/sfx/README.md`). El juego prioriza el archivo sobre el tono procedural.
