# Ítems: integración del prototipo

Fuente: `item_stats_source.txt`, extraído del DOCX proporcionado por el usuario. El documento fuente se conserva íntegro; las adaptaciones siguientes describen la implementación actual.

## Imágenes y catálogo

- `assets/items/reward_items_spritesheet.png`: primeros 16 objetos, por filas de izquierda a derecha.
- `assets/items/relic_items_spritesheet.png`: cuatro reliquias personales y los 12 objetos de sistema.
- Los PNG originales conservan sus bytes. Los 32 iconos se leen mediante AtlasTexture, sin recortar destructivamente las imágenes.
- `data/items.json`: identificador, nombre, rareza, categoría, límite de acumulación, descripción y región del icono.
- `scripts/run_items.gd`: efectos; `scripts/item_ui.gd`: inventario, catálogo, selección de recompensas y servicios entre salas.

## Cómo jugar

`I` abre el inventario y el catálogo. Limpiar una sala ofrece hasta tres objetos diferentes; elegir uno lo aplica inmediatamente. El combate queda pausado durante la elección. Los objetos poseídos al máximo se excluyen. Si quedan menos de tres opciones válidas se muestran las disponibles; siempre se puede omitir.

Cada enemigo entrega una moneda y 10 EXP (30 para Eclipse). Cada 100 EXP aumenta el nivel y concede otra elección. Una moneda renueva opciones; tres monedas curan 25% de Voz máxima a las integrantes vivas. Las llaves y tickets se consumen en los servicios entre salas. Las llaves abren una elección de cofre; los tickets visitan una recompensa rara o superior. Al continuar se cambia de escenario y comienza una nueva sala finita.

Hay salas élite cada tres salas y jefe cada cinco. Las élite garantizan una opción rara o superior, las de jefe una épica o superior, sujeto a que quede alguna disponible. La brújula revela el tipo del próximo encuentro de esta ruta lineal. No se ha añadido un mapa de rutas ramificadas.

## Adaptaciones a la vida individual

- Poción: cura 25% de la Voz máxima a **cada integrante viva**, sin revivir.
- Amplificador: Voz máxima de cada integrante pasa de 100 a 115; curación recibida +10%. No rellena la vida automáticamente ni revive.
- Pluma de resurrección: solo se activa al caer la última integrante; revive a las cuatro con 30% de Voz. Una activación por partida, consume el objeto y no se puede volver a adquirir.
- Escudos: individuales, absorben daño antes de la vida. El mayor escudo reemplaza al menor; no se suman sin límite. El escudo normal dura 6 s (valor de prototipo), el del campo dura lo que quede del campo. Solar con talismán añade 1 s. La reliquia defensiva se activa después del golpe y no evita por sí misma un golpe letal.

## Valores de prototipo donde la fuente no concreta reglas

- Habilidades: 100 de energía máxima; coste 100, regeneración base 20/s. La batería multiplica la regeneración +20% por unidad. El CD se aplica además del requisito de energía. Así la batería es útil junto a reducciones de cooldown. Echo no paga energía ni reinicia cooldown otra vez.
- Ad-lib: `Q` consume 100 de Armonía y abre una ventana de 5 s; todavía no existe el medidor independiente de Compostura. El núcleo activa sus bonus durante esta ventana; las bajas extienden hasta 3 s en total.
- Reacción elemental: golpe de una integrante distinta a la anterior sobre un enemigo controlado o con Ardor. La nota de Wheein busca el siguiente enemigo más cercano. La propagación no genera nuevas propagaciones, recompensas adicionales ni Harmony Chain por sí misma.
- Ardor dura 4 s y habilita la explosión. No inflige daño periódico porque la fuente no especifica una cantidad. Explosión: radio 110, daño 40% del golpe final; sin recursión.
- Rare Cosmic Orb: cuenta cambios manuales, 20 de daño en radio 160 cada cuatro cambios; otorga exactamente 8 puntos de Armonía.
- Harmony Chain Enhancer: onda de 10 de daño en radio 170 al pasar a Cuarteto. No se dispara de nuevo por cada golpe mientras siga el mismo Cuarteto.
- Solar: campo radio 130, cada integrante recibe un escudo una vez por campo; salir del campo elimina el bonus de daño, no renueva escudos consumidos.
- Eclipse de Moonbyul: consume la marca infligiendo 120% del daño básico de la integrante entrante. Wheein añade un pulso de 8 de daño en radio 90; Hwasa suma 10% si el enemigo está por debajo de 35% de vida. Solar recibe 5% de Voz máxima en escudo.
- Pergamino: elegir integrante, +20% de potencia por nivel. Solar aumenta daño y curación; Moonbyul aumenta distancia de desplazamiento y duración del control; Wheein/Hwasa aumentan daño. Máximo cuatro pergaminos por partida.
- Fragmentos de jefe: +3% daño contra Eclipse por fragmento; tres fragmentos desbloquean -10% daño recibido de jefe (efecto especial no concretado en la fuente).
- Encore: ataques de Wheein propagan una reacción menor de 15% de daño; si posee su reliquia usa 35%. Hwasa tiene 10% de probabilidad de crítico durante Encore y daño crítico 165% (150% base +15 puntos). No hay otro sistema global de críticos.
- Talismán: Eclipse produce daño de corrupción; Feedback aplica un freno de 20% durante 2 s tras contacto válido. Esto permite comprobar las resistencias y la superarmadura. La superarmadura impide nuevos efectos de control, no el daño ni los debuffs anteriores.
- Bonus repetibles: máximo tres unidades en shard, moon token, flame emblem, speed feather, EXP orb y batería; cinco gemas de cooldown; una en reliquias salvo tres fragmentos. Los recursos y consumibles tienen límites propios en el catálogo.
- Límites: reducción de CD 40%, velocidad de objetos +35%, generación de Armonía +60%. Los bonus de daño del mismo grupo se suman y se limitan; los efectos secundarios no se autoactivan recursivamente.

## Excepción del cofre legendario

La fuente pide tres reliquias legendarias para elegir, pero solo define **Quartet Crown** como reliquia legendaria (el otro objeto legendario es el propio cofre). Para no inventar estadísticas de dos reliquias nuevas, este cofre cura 20% a las vivas y ofrece una selección de reliquias épicas/legendarias disponibles. La descripción y la ventana lo indican. Falta definir al menos dos reliquias legendarias adicionales para que las tres opciones puedan ser siempre legendarias.

## Verificación

`tests/items_smoke.gd` comprueba catálogo/iconos, adquisición de los 32 ítems, valores, límites, efectos condicionales, sinergias, Echo y resurrección. `tests/rewards_flow.gd` recorre limpieza de sala, elección, llaves, tickets, cofres y continuación. Las pruebas anteriores de combate, controles, supervivencia e interfaz se mantienen.

Los objetos y recursos son de la partida actual. Reiniciar crea un equipo e inventario nuevos.

## Rarezas de las recompensas (sistema procedural)

Desde la implementación del hito procedural, las probabilidades de rareza de las
recompensas de sala salen de `scripts/systems/reward_manager.gd` y siguen la
especificación (45/30/15/8/2): combate usa la base; élite y salas REWARD suben
Rare/Epic/Legendary; el jefe nunca da objetos comunes. Las salas ofrecen tres
opciones distintas extraídas del catálogo compatible.

En `item_ui.roll_choices()` se **elige primero la rareza** según el peso de la
sala y luego un objeto uniforme de esa rareza, de modo que los porcentajes
documentados se respetan sin que la cantidad de objetos de cada rareza en el
catálogo distorsione la probabilidad. La tienda de las salas SHOP usa un precio
fijo por rareza (3/5/8/12/20 monedas).
