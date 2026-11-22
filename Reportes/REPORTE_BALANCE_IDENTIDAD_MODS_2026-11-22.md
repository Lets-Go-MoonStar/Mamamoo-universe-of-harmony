# Reporte: Identidad Mamamoo · Modifiers · Balance (22 Nov 2026)

## Objetivo
Cerrar los tres techos pendientes:
1. Fantasía / identidad de marca (sin pack de arte real)
2. Variedad a 20+ runs (capa distinta a más `.tres`)
3. Balance fino validado (proxy de 5 escenarios × 4 rutas)

## 1. Fantasía Mamamoo
| Entrega | Detalle |
|---------|---------|
| `MemberIdentity` | Nombres Solar/Moonbyul/Wheein/Hwasa, colores, taglines, stages `feat. X` |
| SFX por integrante | Acordes `solar` / `moonbyul` / `wheein` / `hwasa` al switch y al E |
| HUD / intro | Tagline de ruta en intro de piso; borde de arena teñido por ruta |
| Copy de rutas | Descripciones meta alineadas a sinergias actuales |

**Límite honesto:** sigue sin pack ilustrado/audio real; la identidad se sostiene por paleta + voz + copy.

## 2. Variedad 20+ runs — Room modifiers
Nueva capa `RoomModifier` (6 mods), piso ≥5 en COMBAT/ELITE:

| ID | Efecto |
|----|--------|
| `high_tempo` | Enemigos +18% vel · jugador +8% |
| `spotlight` | +12% daño dado · +15% recibido |
| `muted_stage` | Habilidad +35% CD · Compostura +20% |
| `harmony_drain` | Armonía −4/s · kills Compostura +25% (piso ≥8) |
| `dense_fog` | +1 zona · jugador −10% vel |
| `encore_pressure` | Compostura −25% · Ad-lib +10% (piso ≥8) |

Patrones de set piece existentes se mantienen; los mods cambian **reglas**, no solo spawns.

## 3. Balance — auditoría sintética
Suite `tests/balance_audit.gd`: 5 escenarios × 4 rutas (DPS de ruta, Compostura delta, sinergia, supervivencia vs hazard élite, stress `spotlight`).

### Resultados (post-tune)
| Ruta | Score medio (runs 1–4) |
|------|-------------------------|
| Solar | 26.5 |
| Moonbyul | 28.3 |
| Wheein | 27.5 |
| Hwasa | 27.1 |

- **Spread relativo:** 6.7% (objetivo &lt; 35%) → PASS  
- **path_empower:** bumps 4–11% (cap máx +14%) → PASS  
- **Élite hazard cycle:** &lt; 100 Voz → PASS  

### Ajustes aplicados tras la 1ª auditoría (Hwasa alto)
- Hwasa: kill Compostura 1.60→**1.45**, Ad-lib 1.12→**1.10**, high-comp +6%→**+5%**
- Moonbyul: dodge shot **+22%**, CD esquiva −22%, vel +12%
- Score de auditoría mide **aporte de ruta**, no DPS bruto del miembro (asimetría Solar/Hwasa base es intencional)

### Qué no sustituye
Playtest humano real (5 runs por ruta en editor). El proxy valida bandas; no captura skill ceiling ni fatiga de UI.

## Tests
- `identity_mods_smoke` 11/0  
- `balance_audit` 9/0  
- `set_pieces_smoke` 20/0  
- `combat_smoke` 16/0  

## Rama / PR
Cambios en `cursor/set-pieces-routes-v2` (PR #11). Milestone README **16**.

## Veredicto
Las tres tareas quedan **cerradas a nivel de prototipo**: identidad legible sin art pack, modifiers como segunda camada de replay, y rutas dentro de banda sintéticamente. Siguiente salto de producción: arte/SFX reales o playtest humano documentado.
