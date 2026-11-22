# Playtest humano — 5 runs por ruta

El audit sintético **no** sustituye esto. Objetivo: 5 runs jugadas por persona en cada ruta (Solar / Moonbyul / Wheein / Hwasa).

## Antes
1. En **Mejoras**, elige la ruta a testear (45 ✦ la primera vez).
2. Al terminar cada run se appendea a `user://playtest_runs.jsonl`.
3. En pantalla de fin: contadores `Playtest 5×ruta: S# M# W# H#` + promedio feel de la ruta.
4. Pulsa 1–5 cuatro veces: **Poder → Dificultad → Diversión → Fatiga** (se escribe en el log).

## Por cada run (checklist)
- [ ] Ruta correcta al empezar (borde de arena del color de la integrante)
- [ ] Pisos 1–3: viste **ZONA** y tip “sal antes del flash”
- [ ] Piso 3+: **Opening Act** u otro mod; Beam Diva / SILENCE / SPLIT si aparecieron
- [ ] Al menos 1 **élite set piece** o patrón distinto (piso 4+)
- [ ] 1 jefe con cambio de fase (ECHO RING / CRYSTAL CORNERS / …)
- [ ] Ratings 1–5 en pantalla de fin
- [ ] Notas libres (opcional) en un doc aparte

## Preguntas de balance (mano humana)
| Señal | Qué mirar |
|-------|-----------|
| Moonbyul floja | Poder avg < 2.5 tras 5 runs |
| Hwasa abusiva | Dificultad avg < 2.0 **o** Poder avg > 4.5 con Fatiga baja |
| Curva aburrida | Fatiga avg > 3.5 antes de piso 8 |

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
