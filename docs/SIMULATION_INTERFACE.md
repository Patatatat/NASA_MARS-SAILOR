# Contrato de simulación · resumen final v1

> **Migración vigente (propuesta del hackathon):** esta base está migrando desde el contrato histórico descrito abajo. El estado ejecutable ahora usa cuatro existencias: `regolith`, `energy`, `air` y `food` (agua + comida). El sol nominal dura 60 s dentro de una partida de 42 soles; hay 40 s de día y 20 s de noche, energía almacenada con capacidad, y mapa de tamaño 16/24/32 con terreno bloqueado generado por semilla. Algunos detalles históricos de este documento aún no se han actualizado y no deben prevalecer sobre `docs/PROPUESTA_BUCLE_HACKATHON.md` ni el código vigente.

## Integración de interfaz y simulación

La decisión confirmada por Rafael al integrar sustituye el mapa original: **32×32 y huellas de varias celdas**, con el tablero 3D de Andrés. Se conservan tiempos, costos y sistemas actuales de simulación. F5 abre `crew_selection.tscn`; la selección muestra las probabilidades configuradas antes de elegir equipo y pasa cuatro IDs validados a `simulation_lab.tscn`.

El tablero conserva giro, desplazamiento, zoom, menú de construcción y HUD superpuesto. Sus paneles desplegables añaden ROBERTS, refugio, enterramiento, mejoras, sesiones de mantenimiento, inspector, historial y resumen final. Un clic en cualquier celda ocupada identifica al edificio por su huella. Los resultados éxito/fallo son controles de prueba explícitos hasta integrar los minijuegos de Luque. Los historiales conservan posición de lectura y se limpian al reiniciar.

Esta guía corresponde al código ejecutable de la base inicial. El plan vigente y el diseño v0.4 orientan el alcance; `local-only/Especificaciones/00-main-handoff.md` y `01-interface-guide.md` son referencias históricas locales, no incluidas en el repositorio. No se cargan sus JSON. Este incremento no completa el juego del fin de semana.

## Uso por Andrés

Instanciar `preload("res://domain/simulation.gd").new()`; cargar `simulation_config.gd.load_file()`, comprobar `ok`, pasar `data` a `configure()`. Después llamar `reset_run(crew_ids, seed)` y construir durante planificación. `start_run()` comienza la simulación. Un único controlador llama `advance(delta)` por frame. No usar simultáneamente otro reloj o Timer para la economía.

No requiere autoloads. La instancia es un `RefCounted` independiente de escenas. Convención: los miembros con `_` son internos; GDScript no impone privacidad. Todas las lecturas públicas devuelven copias profundas. No editar miembros internos.

| API | Entrada / salida |
| --- | --- |
| `configure(data: Dictionary)` | Valida y copia datos; solo antes de inicializar la partida. Para otra configuración crear otra instancia. |
| `reset_run(crew_ids: Array, run_seed: int = 1)` | Exactamente 4 IDs únicos de los 6 disponibles. Reinicia reloj, mapa, edificios, registro, salud y final. El mismo seed reproduce el mapa y las ventanas de eventos. Error conserva la partida anterior. |
| `get_catalog()` / `get_snapshot()` | Copias profundas de configuración / estado. |
| `get_run_summary()` | Respuesta estándar con `result` = resumen final v1; errores `not_initialized` / `not_finished` si todavía no existe. No muta y se puede consultar durante `run_finished`. |
| `preview_placement(kind: String, cell: Vector2i)` | Comprueba huella completa, límites, terreno bloqueado, tipo, distancia y regolito; devuelve costo y duración sin mutar. |
| `place_building(kind: String, cell: Vector2i)` | Revalida, cobra regolito una sola vez y reserva la huella; retorna `result.building_id`. |
| `get_building_footprint_size(kind: String)` / `get_building_footprint_cells(kind, anchor)` | Consulta el lado en celdas y todas las coordenadas ocupadas por un edificio. |
| `set_enabled(building_id: String, enabled: bool)` | Enciende/apaga; repetir mismo estado no duplica registro. Hábitat no apagable. |
| `start_run()` | Solo desde planificación. |
| `set_paused(paused: bool)` | Solo durante simulación. |
| `set_speed(speed: float)` | 0.5, 1, 2 o 4. |
| `advance(real_seconds: float)` | Delta real finito, no negativo. Pasos lógicos de 1 segundo. |
| `get_forecast()` | Antes de una partida, devuelve probabilidades y rangos. Después de `reset_run`, incluye ventanas sorteadas para esa semilla sin revelar si ocurrirán. |
| `preview_robert(robert_id: String, destination_id: String)` | Requisitos actuales, potencia reservada, duración, carga y riesgo estimado; no muta. |
| `send_robert(robert_id: String, destination_id: String)` | Revalida y despacha una misión; devuelve ID y segundo de retorno. |
| `set_sheltered(enabled: bool)` | Refugio: reduce dosis futura, detiene obras/enterramiento y bloquea nuevas expediciones. |
| `bury_habitat()` | Cobra regolito al iniciar; protección al terminar. Sin cancelación. |
| `preview_upgrade(building_id: String)` | Valida y devuelve costo, duración estimada, duración base, definición actual y definición del nivel 2, sin mutación. |
| `start_upgrade(building_id: String)` | Revalida, cobra regolito una vez e inicia trabajo. Mantiene nivel 1 durante la obra. |
| `get_building_status(building_id: String)` | Respuesta `{ok, error_code, cost, result}` con inspector e historial local; copia profunda. |
| `begin_maintenance(building_id: String)` | Abre un intento y devuelve datos/token del minijuego. |
| `apply_maintenance_result(session_id: String, success: bool, elapsed_seconds: float, abandoned: bool = false)` | Aplica una sola vez el resultado de ese intento. |
| `reactivate_building(building_id: String)` | Después del enfriamiento, cobra regolito y recupera rendimiento normal. |

Los comandos retornan `{ok, error_code, cost, result}`. Un fallo no muta. Códigos principales: `select_four`, `invalid_crew`, `invalid_phase`, `invalid_building`, `outside_grid`, `footprint_outside_grid`, `occupied_footprint`, `reactor_too_close`, `insufficient_mass`, `unknown_building`, `habitat_required`, `invalid_speed`, `invalid_delta`, `busy`.

Señales: `state_updated(snapshot)` después de una operación completa, `event_changed(event)` para aviso/inicio/fin/ausencia de evento, `robert_changed(robert)` para salida/retorno/pérdida y `run_finished(result)` una sola vez por partida. No llamar comandos síncronos desde estas señales: se rechazan para evitar reentrada. Encolar la intención para el siguiente frame. No modificar el payload compartido entre suscriptores; obtener otra copia si se necesita manipularlo. Con un frame largo, las notificaciones de transiciones se entregan en orden al finalizar `advance`: sus payloads son históricos, el snapshot es el estado actual. Usar timestamps del evento y el registro para cronología.

Snapshot: fase (`planning`, `running`, `finished`), semilla, segundos enteros, sol mostrado (1–12), soles completados (0–12), pausa, velocidad, recursos, tripulación, edificios, potencia, déficits acumulados, registro y resultado. Cada edificio tiene ID, tipo, x/y, nivel 1, habilitación, potencia, tiempo restante y aviso. Los IDs se reinician con la partida; descartar referencias de la sesión anterior.

## Reglas y unidades de esta base

- Masa/regolito/aire/agua/comida son cantidades de balance; potencia es tasa disponible, nunca inventario ni batería. Salud 0–100. No son cifras científicas ni parámetros médicos.
- El HUD muestra `Energía` como suministro eléctrico disponible / demanda eléctrica, no como una reserva acumulable. `Soles transcurridos` muestra `completed_sols`: inicia en 0 y aumenta al completar cada día marciano simulado.
- Configuración nominal: 12 soles × 25 segundos. Datos numéricos provisionales en `data/balance.json`; validación estructural, tipos numéricos finitos y no negativos. Los valores de duración de sol y construcción son enteros. Grid fijo 32×32.
- Huellas cuadradas: hábitat 3×3, solar 3×3, reactor 4×4, generador de oxígeno 2×2, invernadero 3×3 y laboratorio 2×2. Los edificios no pueden solapar huellas ni salir del tablero; las huellas que solo comparten borde sí pueden tocarse. En medidas pares, la celda ancla es la primera de las dos centrales y la extensión sobrante queda hacia +X/+Y. El hábitat empieza en (15,15). Se conserva la distancia Manhattan mínima 2 para el reactor. Construir paga al ordenar; durante planificación los temporizadores están detenidos. Al iniciar, una obra de 5 segundos termina al final del tick 5 y produce desde el 6. No hay cancelación ni reembolso.
- Prioridad eléctrica provisional: hábitat → oxígeno → invernadero → laboratorio → ROBERTS; empates por orden de construcción/ID de robot. Cada consumidor requiere toda su potencia. Las fuentes no necesitan potencia. No hay noche ni baterías.
- Orden por segundo: transiciones de eventos → avisos/degradación/apagado de mantenimiento → potencia → producción (riego antes del consumo de la tripulación) → consumos separados → faltantes/daño/muerte → radiación/daño/muerte → obras/mejoras/enterramiento → retorno de ROBERTS → soles/resumen → recalcular potencia/bonus → final. Un retorno no salva a un tripulante muerto durante el consumo del mismo paso. Sí cuenta para el inventario final al coincidir con el relevo. El reloj real de sesiones se procesa también en fracciones de un paso simulado, respetando cada transición de evento.
- Conversión de tasas: `cantidad_por_sol / sol_seconds`. Invernadero sin agua suficiente para el paso no produce ni cobra riego. Falta de potencia detiene producción. Producción precede al consumo y puede cubrirlo en el mismo paso.
- Daño provisional por cada recurso: unidades faltantes × tasa de daño / vivos al comenzar el consumo. La salud se reduce por igual entre vivos. Muertos dejan de consumir y aportar bonus desde el próximo paso; potencia recalculada inmediatamente.
- Bonus implementados: ingeniería ×1.2 suministro, botánica ×1.25 aire/comida del invernadero, sistemas ×0.8 demanda del generador, medicina ×0.75 dosis futura, geología ×1.25 carga y ×0.75 riesgo, ciencia ×0.75 duración de mejora. Solo miembros vivos aportan bonus.
- Final: cero vivos → `total_defeat` (prioridad incluso al coincidir con relevo); a 300 s, vivos + hábitat energizado + aire positivo → `relief_achieved`; en otro caso `partial_defeat`. Definición inicial explícita de soporte operativo: hábitat energizado. No calcula puntaje.
- El tiempo fraccionario se acumula internamente; `get_snapshot()` no es un formato de guardado/restauración. Dos RNG separados: eventos con la semilla de partida y misiones con semilla XOR `0x524F4245`; se pueden inyectar RNG distintos en el constructor. `reset_run` reinicia ambos y elimina misiones/avisos anteriores. Eventos se sortean al reiniciar, antes de decisiones, usando exactamente las probabilidades del pronóstico. No se promete reproducibilidad entre versiones del motor; requiere los mismos datos y acciones.

## Eventos, radiación y expediciones

Configuración provisional en `balance.json`, sin cambiar costos ni reservas originales:

- Tormenta: 60%, aviso en 55 s, activa en `[75,125)`, solar ×0.25; reactor inmune. Partículas: 50%, aviso en 155 s, activas en `[175,200)`, +35 dosis/sol. Intervalos en segundos simulados. Config rechaza solapamiento de avisos/crisis. Horarios fijos en este incremento; se sortea ocurrencia, no fecha. Al omitirse un evento se notifica `skipped` al llegar su ventana de aviso.
- `snapshot.event`: vacío o `{kind, state, start_seconds, end_seconds, seconds}`. `forecast` no contiene resultados ocultos. Estados públicos `warning`, `active`; los payloads de señal incluyen también `ended`/`skipped`.
- Dosis individual acumulativa: ambiente 1/sol más partículas si activas. Médico ×0.75, refugio ×0.25 y hábitat enterrado ×0.4, multiplicativos. `crew[].dose_avoided` mide dosis reducida frente al incremento bruto de ese paso; no demuestra una muerte evitada. Daño: 2 salud por unidad NUEVA de dosis que supere 40. Cifras abstractas de juego, sin interpretación médica.
- Enterrar: 10 masa + 20 regolito, 25 s efectivos de trabajo. `burial.state`: `surface`, `building`, `buried`. Refugio pausa construcción y enterramiento; producción automática y viajes ya iniciados continúan. La protección empieza en el paso siguiente a terminar la obra; la dosis pasada nunca disminuye.
- IDs de robots: `robert_1`, `robert_2`. Destinos: `ice` → 45 agua, riesgo base 15%; `quarry` → 25 regolito, 5%; `wreckage` → 20 masa, 25%. Hielo se convierte directamente en agua, sin procesamiento avanzado.
- Requisitos de salida: fase running, robot disponible, no estar refugiados, laboratorio terminado/habilitado/energizado y 2 de potencia sobrante. Se reservan 2 de demanda **durante el viaje**, sin descontar energía de un inventario. Cada misión dura dos soles, 50 s con el balance nominal. No exige fecha de retorno anterior al relevo: si termina la partida primero no entrega carga después.
- Regla provisional de autonomía: perder energía de soporte o apagar laboratorio después de salir no detiene ni reinicia el viaje; `robert.powered` muestra si la base cubre su demanda. No introduce un segundo castigo por apagado. Vuelve y convierte carga automáticamente aunque el laboratorio esté apagado.
- Cualquier paso de viaje que coincida con tormenta marca `storm_exposed` (incluido el paso del retorno). Al retornar se realiza UNA tirada con `clamp((riesgo_base + 0.25 si hubo tormenta) × bonus_geólogo, 0, 1)`. Geólogo vivo al retorno determina riesgo y carga; la vista previa es estimativa y puede cambiar por tormenta/muerte. La exposición no acumula 25% por segundo.
- `roberts[]` contiene `id`, `state` (`available`, `on_mission`, `lost`), `mission_id`, `destination`, `return_seconds`, `storm_exposed`, `powered`. Tras retorno conserva los datos de la última misión para inspección. Un robot perdido no se reutiliza; uno disponible admite una nueva misión con ID nuevo. El reinicio restablece los dos.
- Nuevos errores: `unknown_robert`, `robert_unavailable`, `unknown_destination`, `crew_sheltered`, `laboratory_not_operational`, `insufficient_power`, `burial_already_started`, `insufficient_resources`. En salidas, `cost.power_demand` representa tasa reservada; en enterramiento `cost.mass/regolith` son cantidades pagadas.

Registro adicional: transiciones `event_*`, `robert_dispatched/returned/lost` con ID de misión, riesgo resuelto y carga real, `shelter_changed`, `burial_paid`, `habitat_buried`, `radiation_exposure`. `metrics.solar_output_lost_power_seconds` integra la reducción real de suministro solar por tormenta; no es energía almacenada ni producción de aire perdida.

Registro causal: `id`, `seconds`, `reason`, `target`, `details`. Incluye pago, terminación, encendido, déficit medido, producción bloqueada por agua, muerte y final. No basta para calcular todavía todos los componentes del informe final. No inferir muertes hipotéticas o consecuencias no medidas.

## Mejoras de nivel 1 → 2

Disponibles durante `running` para los cinco edificios construibles. El hábitat se protege mediante enterramiento. Los datos `upgrades` y `scientist_upgrade_duration_multiplier` son obligatorios y se validan al cargar; no alteran los costos/tasas anteriores de nivel 1.

| Edificio | Masa | Trabajo base (s) | Efecto de nivel 2, antes de bonus |
| --- | --- | --- | --- |
| Solar | 10 | 20 | Potencia 5 → 8 |
| Reactor | 25 | 25 | Potencia 14 → 20 |
| Oxígeno | 15 | 20 | Aire 12 → 18/sol; demanda 4 → 5 |
| Invernadero | 15 | 25 | Comida 10 → 15/sol; aire 2 → 3/sol; agua 4 → 6/sol; demanda 3 → 4 |
| Laboratorio | 10 | 20 | Demanda 2 → 1; viajes y conversión inmediata conservan sus reglas |

Reglas provisionales:

- `preview_upgrade` retorna costo y `result.{target_level, duration_seconds, base_duration_seconds, current, next}`. La estimación asume que el científico sigue vivo y no se entra al refugio. La UI debe mostrar también la demanda/insumos del nuevo nivel para anticipar los costos operativos.
- `start_upgrade` comprueba objetivo, obra inicial terminada, nivel máximo, mejora en curso, refugio y masa. Cobra al ordenar y no devuelve recursos. Repetir la orden rechaza sin cobrar. Puede mejorarse un edificio apagado/sin potencia; la obra no lo enciende.
- Mientras hay mejora, producción, consumo y laboratorio continúan con nivel 1. Al finalizar cambia `level` a 2, recalcula potencia y la nueva economía aplica desde el siguiente paso. El último paso de obra sigue produciendo a nivel 1. La mejora no extiende la partida.
- Cada edificio contiene `upgrade_remaining_work` y `upgrade_total_work`, en segundos equivalentes de trabajo base. Ambos empiezan en cero. Progreso de UI: `1 - remaining / total` si total > 0. Tras finalizar, remaining=0 y level=2; total conserva el trabajo contratado para inspección.
- Científico vivo aporta `1 / 0.75` unidades de trabajo por segundo; sin él, 1. Por pasos enteros, 20 s base duran 15 s con científico, 25 s duran 19 s. El bonus se recalcula después de muertes en cada paso; morir no reinicia ni ralentiza retroactivamente lo ya hecho. No acelera construcción inicial ni enterramiento.
- Pausa global y refugio detienen la mejora. Apagar el edificio no detiene su obra. Cero potencia tampoco detiene este trabajo; no hay costo eléctrico de construcción en esta regla.
- `upgrade_paid` y `upgrade_completed` se registran una vez por mejora. `metrics.scientist_extra_upgrade_work` suma trabajo adicional realmente realizado, no una estimación de vidas/producción salvadas. `state_updated` basta para conectar progreso y nivel; no hay una señal nueva obligatoria.
- Nuevos errores: `upgrade_not_supported`, `building_under_construction`, `max_level`, `upgrade_in_progress`; reutiliza `invalid_phase`, `unknown_building`, `crew_sheltered`, `insufficient_mass`, `busy`.

## Diagnóstico de reutilización de ROBERTS

La reutilización después de retornar está permitida. Se comprobó el mismo robot en tres misiones consecutivas con carga (tres IDs distintos y 75 regolito). Este caso ya pasaba antes de cambiar la pantalla: no se encontró un bloqueo permanente del dominio.

Reproducción de un bloqueo condicional: solar + laboratorio, salida a los 10 s, retorno a los 60 s; en 60 s puede volver a salir. Si espera hasta los 75 s y ocurre tormenta, la potencia solar baja a 1.5 con ingeniero, y el hábitat consume 1: el laboratorio queda sin energía. El robot conserva estado `available`, pero `send_robert` rechaza con `laboratory_not_operational`. Al terminar la tormenta, vuelve a permitir salida sin reiniciar ni recrear el robot.

El reporte manual solo indicó un posible mensaje «inválido», insuficiente para asociarlo a esa reproducción. También `invalid_phase` bloquea salidas después del relevo/derrota, y `crew_sheltered` bloquea si sigue el refugio. La escena técnica ahora muestra la causa actual de bloqueo en español y, para un robot disponible, no muestra la potencia de soporte ni el horario vencido de su viaje anterior. No se cambió el balance de ROBERTS para ocultar el síntoma.

## Mantenimiento y conexión con Luque

Reglas de alcance vigente (no son las reparaciones de túneles del handoff):

- Solo reactor y generador de oxígeno solicitan mantenimiento. Primer aviso a cuatro soles de terminar la construcción; la medición se inicia en su primer paso ya construido. Tras éxito o reactivación, el siguiente aviso vence cuatro soles después. Edificios apagados no crean avisos nuevos; un aviso existente sigue envejeciendo aunque se apague el edificio.
- Máximo dos avisos pendientes (`requested`/`degraded`), separados globalmente al menos 25 s simulados. No aparecen nuevos durante `warning`/`active` de eventos. El tercero espera capacidad sin fabricar otro temporizador ni avisos duplicados.
- Ignorar un aviso durante un sol reduce producción al 70%; dos soles lo apagan. La demanda del oxígeno y su costo operativo no se reducen por degradación. Un edificio apagado por mantenimiento no produce ni demanda potencia y no se recupera mediante `set_enabled` ni mejoras.
- Apagado: enfriamiento de dos soles. Después, `reactivate_building` cobra 5 masa una vez, devuelve condición `healthy` y respeta la habilitación manual del edificio. No enciende uno que el jugador hubiera deshabilitado. Las cifras están en `balance.json.maintenance` y son provisionales.
- Una única sesión de minijuego simultánea, hasta dos intentos y **15 segundos reales activos en total**, compartidos por ambos intentos. El límite no cambia con ×0.5/×4 y también vence entre ticks de economía. Pausa global detiene ambos relojes. El edificio continúa operando con su condición vigente durante la sesión; el resto del juego sigue avanzando.
- Aviso/crisis o refugio suspenden sesión y reloj real; al terminar, se reanuda con el mismo token, intentos y tiempo. Atender un aviso congela su edad mientras la sesión siga activa/suspendida, evitando un apagado automático durante los 15 segundos del minijuego. Después de fallo/abandono/timeout, la edad sigue. Un resultado recibido durante suspensión se rechaza sin consumirlo.
- Si hay al menos un ROBERT disponible al abrir el intento: `robot_support=true`, dificultad ×0.8. Ambos fuera/perdidos: ×1. Ese dato queda fijado para el intento, no cambia los resultados ni agrega premios. Luque decide cómo convertir ese multiplicador en tolerancia/dificultad de sus escenas.

Cada edificio incorpora `maintenance`:

```text
state: healthy | requested | degraded | shutdown
next_due_seconds, request_id, age_seconds, shutdown_until
attempts, elapsed_real_seconds
session: {} o {id, state, building_id, minigame_id, robot_support, difficulty_multiplier}
session.state: active | suspended | success | failure | abandoned | timeout | interrupted_shutdown
```

`begin_maintenance` devuelve la sesión en `result`. IDs de minijuego: `load_balance` (reactor) y `oxygen_reaction` (oxígeno). La sesión incluye identificador de partida, solicitud e intento: un callback anterior al reinicio no coincide con el nuevo. Repetir apertura no crea otra sesión; repetir un resultado no aplica cambios. El snapshot conserva la última sesión cerrada para inspección.

**Adaptador que debe hacer Andrés:** abrir con `begin_maintenance(building_id)`; guardar el token devuelto para ese intento; instanciar la escena de Luque; conectar su señal y llamar `iniciar(building_id, dificultad)`. Al recibir `resultado(success, elapsed_seconds)`, llamar `apply_maintenance_result(token, success, tiempo_activo_total_de_la_sesion)`. Para un segundo intento, sumar el tiempo activo del intento previo al que devuelve Luque. El dominio también cuenta tiempo real: conserva el mayor entre su medición y el tiempo reportado, validando que sea finito y de 0 a 15. Cerrar manualmente llama con `success=false, abandoned=true`.

Escuchar `maintenance_changed(change)` para mostrar avisos, suspender/reanudar la escena y actualizar estado. `change` contiene `reason`, `target` (ID de edificio), `seconds`, `maintenance` y `details`. Para suspensión, pausar/reanudar el minijuego conservando su estado; no enviar un abandono. Si cambia `run_generation` o termina la partida, cerrar la escena y descartar sus callbacks. No llamar comandos síncronos dentro de señales del dominio: encolar para el siguiente frame.

La escena técnica tiene botones **Prueba: éxito/fallo**, que permiten ejercitar este contrato; no sustituyen los dos minijuegos de Luque. El sistema no calcula puntaje ni entrega recursos por mantenimiento: éxito restaura condición/producción y registra el hecho.

Errores adicionales: `maintenance_not_pending`, `maintenance_session_active`, `another_maintenance_active`, `maintenance_attempts_exhausted`, `maintenance_suspended`, `invalid_maintenance_result`, `unknown_maintenance_session`, `maintenance_result_already_closed`, `maintenance_not_shutdown`, `maintenance_cooling_down`; reutiliza `unknown_building`, `invalid_phase`, `insufficient_mass`.

## Inspector y resumen por sol para Andrés

`get_building_status(id).result` incluye estado del edificio, definición de su nivel, `power_output`, `power_demand`, `output_multiplier`, `effective_production_per_sol.{air,food}`, `water_demand_per_sol`, evento activo, mantenimiento, progreso, `local_log` y `blocked_this_sol`. Las tasas efectivas representan operación posible en el estado actual (cero si no está energizado o falta agua). Son unidades abstractas, no vatios medidos. `local_log` filtra los hechos cuyo `target` es el edificio; los eventos globales se consultan aparte. No inventa una salud estructural que la simulación no tiene.

El snapshot incorpora `sol_reports` y `current_sol_report`. `sol_report_ready(report)` se emite al completar cada sol y por un último tramo parcial si hay derrota anticipada. Nunca vuelve a emitirse después del final. Con un frame largo se entregan todos los informes en orden. No se pausa automáticamente ni se elige una decisión por el usuario.

Cada resumen contiene `sol`, `start_seconds`, `end_seconds`, `partial`, reservas `opening/closing/delta`, `production`, `consumption`, `requested_consumption`, `deficits`, `imports`, `blocked_seconds` y `fact_ids`. Diccionarios de cantidades: claves ausentes equivalen a cero. Producción/consumo se miden por paso; consumo incluye riego y cantidad realmente disponible para tripulación, mientras `requested_consumption` mide necesidades solicitadas por la tripulación. `deficits` registra faltantes antes de limitar inventario. `imports` registra retornos de ROBERTS. Para aire/agua/comida: variación = producción + importación − consumo real. Masa/regolito también cambian por comandos cuyos pagos constan en el registro; no usar esa igualdad para ellos sin incluir las transacciones.

`blocked_seconds[building_id][reason]` cuenta pasos reales de paro por `under_construction`, `disabled`, `power_shortage`, `maintenance_shutdown` o `water_shortage`. No convierte automáticamente esas duraciones en cosechas perdidas ni muertes hipotéticas. `fact_ids` enlaza al registro de hechos; Andrés puede redactar hasta tres causas respaldadas, por ejemplo «el invernadero estuvo sin agua 15 segundos». No se generaron explicaciones desde el stock final solamente.

El handoff antiguo aporta separación de UI/dominio, inspector y explicación causal. No se trasladaron 42 soles, cohetes, túneles, baterías, moral, escaneo, ocho perfiles ni los tres templates antiguos de Decision Maker. Los minijuegos y el diseño visual de los avisos siguen a cargo de sus carriles; este incremento deja los contratos de simulación utilizables.

Para historiales de UI, `scenes/history_panel.gd` es un `TextEdit` de lectura con `update_history(content, reset_position=false)`: conserva desplazamiento al recibir datos y retiene la rueda dentro del panel. La escena técnica lo usa para los hechos globales y para el historial del inspector. Reinicia posición únicamente al cambiar de partida/edificio; el contrato del dominio no cambió con esta corrección.

## Resumen final v1 · contrato para Andrés

`domain/run_summary.gd` concentra las mediciones y normalización. La simulación genera y congela el resumen una vez por partida, antes de emitir `state_updated`/`run_finished`. El snapshot terminado lo incluye en `run_summary`; `get_run_summary().result` entrega otra copia profunda. En planificación/partida activa, ese campo está vacío y el getter devuelve `not_finished`. Reiniciar elimina historial, oportunidades y resumen de la nueva partida. Una copia ya obtenida puede trasladarse a otra escena: no contiene nodos ni referencias a la simulación.

Uso al finalizar:

```gdscript
func _on_run_finished(_result: Dictionary) -> void:
    var response: Dictionary = simulation.get_run_summary()
    if response.ok:
        var summary: Dictionary = response.result
        # Guardar o pasar esta copia a la pantalla final de Andrés.
        show_report(summary)
```

`show_report` representa el consumidor de UI, no un método del dominio. La escena de partida actual ya ofrece una vista sencilla en el panel **Resumen**, que se abre al terminar y se puede cerrar/reabrir. No altera el menú principal. La lectura es válida dentro de señales; los comandos de mutación siguen bloqueados durante publicación.

| Campo | Contenido |
| --- | --- |
| `schema_version`, `seed`, `run_generation` | Versión del contrato, semilla y sesión de partida. |
| `verdict`, `elapsed_seconds`, `target_seconds` | Veredicto autoritativo y tiempos simulados. No inferir victoria del puntaje. |
| `components` | `survival`, `crew`, `sustainability`, `resilience`: cuatro floats de 0 a 1. |
| `crew` | Vivos, cuatro plazas, salud media contando muertos como cero, miembros con salud/dosis acumulada/dosis reducida total. No atribuir toda esa reducción únicamente al médico. |
| `sustainability` | Inicio/fin, duración real evaluada, ventana deseada, mediciones y valor por recurso. |
| `resilience` | Oportunidades con IDs/hechos, total, resueltas, pendientes, éxitos sin crítico y uso del neutral. |
| `final_resources`, `final_power`, `deficits`, `metrics`, `roberts` | Cantidades/medidas finales; unidades abstractas del juego. |
| `timeline`, `facts` | Informes por sol, incluido tramo parcial si hubo derrota anticipada, y registro completo de hechos para resolver IDs sin conservar la instancia de simulación. |
| `causes` | Hasta cuatro hechos explicativos estructurados, con `fact_ids` y/o `sol_refs`. |
| `criteria` | Copia de los umbrales `balance.json.summary` usados para obtener estos valores. |

### Normalización provisional (ajustable por balance)

- Supervivencia: `elapsed_seconds / target_seconds`, limitado a 0–1.
- Tripulación: suma de salud de miembros vivos / 400. Cada muerto aporta cero; no dividir solo entre supervivientes. Salud y dosis se muestran por separado.
- Sostenibilidad: muestreo cada segundo lógico; ventana exacta de los últimos `window_sols × sol_seconds` segundos, por defecto 50. Si la derrota llega antes, se usa el tiempo realmente vivido. Se conserva una muestra de apertura y las muestras de cierre, sin incluir dos veces el tramo parcial del último sol.
- Para cada recurso vital: demanda media = promedio de consumo de tripulantes vivos por sol en esas muestras; disponibilidad = promedio de `clamp(reserva / (demanda × reserve_target_sols), 0, 1)` en cada cierre. La demanda no incluye riego. Sin vivos, la disponibilidad de ese paso es cero; si la demanda configurada es cero pero hay vivos, vale 1 con reserva positiva y 0 sin ella.
- Tendencia neta por sol = `(reserva_final − reserva_apertura) × sol_seconds / duración_evaluada`. Incluye retornos reales de ROBERTS; no representa exclusivamente producción local.
- Valor de tendencia = `clamp(1 + tendencia_neta / demanda_media, 0, 1)`. Si demanda media es cero: 1 para tendencia no negativa, 0 para negativa. Valor del recurso = disponibilidad × valor de tendencia. Sostenibilidad = media de aire/agua/comida. Un stock grande que solo cae al ritmo de todo el consumo no recibe puntuación alta por acumulación.
- Resiliencia: un evento cuenta solo cuando llega a `active`, no por su pronóstico/aviso ni por `skipped`. Se resuelve cuando termina. Cada solicitud de mantenimiento cuenta una vez por `request_id`; fallos/reintentos/abandono no crean oportunidades nuevas. Éxito o reactivación resuelven la solicitud; un apagado mantiene la marca crítica aunque se reactive después.
- Estado crítico durante una oportunidad: cualquier muerte, un vivo con salud ≤25, hábitat sin potencia, un faltante nuevo de recursos o una reserva vital ≤0.25 soles de consumo de la tripulación. Los umbrales son datos del JSON. Las oportunidades resueltas se consideran exitosas solo si nunca entraron en crítico. Puede ser preparación exitosa sin un botón de respuesta, por ejemplo reactor sosteniendo la base durante tormenta.
- Resiliencia = éxitos sin crítico / oportunidades totales. Las que siguen pendientes al relevo/derrota permanecen en el denominador; no se inventa su resolución. Sin oportunidades: valor neutral configurado 0.5 y `neutral_used=true`.

Cada oportunidad conserva `critical_reasons`, `first_critical_seconds` y una `critical_snapshot` de reservas, tripulación, déficits y potencia del hábitat al observar el primer estado crítico. Los códigos incluyen `habitat_unpowered`, `crew_death`, `low_crew_health`, `low_reserve_<recurso>`, `deficit_<recurso>` y `maintenance_shutdown`. Una muerte individual no queda ocultada por la salud alta de los otros supervivientes. Estos diagnósticos permiten explicar el indicador sin reconstruir una partida hipotética.

Andrés aplica los pesos acordados **35/25/20/20** y los rangos en su pantalla. El dominio no calcula un puntaje total ni lo usa para cambiar el veredicto. Ejemplo de consumo, no otra regla de simulación:

```gdscript
var c: Dictionary = summary.components
var score: int = roundi(100.0 * (0.35 * c.survival + 0.25 * c.crew + 0.20 * c.sustainability + 0.20 * c.resilience))
```

### Hechos explicativos

`causes` selecciona en orden determinista: faltantes de aire/agua/comida, apagados de mantenimiento, ROBERTS perdidos, bloqueos por agua/potencia/apagado manual y, si queda espacio, retornos/mantenimiento exitoso/mejoras/enterramiento. No compara magnitudes de unidades distintas ni afirma que sean un análisis causal exhaustivo.

`kind` puede ser `crew_resource_deficit`, `maintenance_shutdown`, `robert_lost`, `building_blocked`, `robert_returned`, `maintenance_success`, `upgrade_completed`, `habitat_buried`. La UI traduce esos códigos. Un bloqueo incluye `reason` y `duration_seconds`; una transacción incluye `details` del hecho original. Los IDs de `fact_ids` se resuelven en `facts`, y `sol_refs` en `timeline`. No afirmar que un robot se perdió *por* la tormenta solo porque `storm_exposed=true`; sí que la expedición perdida estuvo expuesta. Tampoco convertir dosis reducida en «muertes evitadas».

## Archivos a integrar

Presentación para navegador de escritorio: base lógica **1600×900**, escalado `canvas_items` con aspecto `expand`. La ventana de desarrollo abre a 1440×810; el área efectiva del navegador la determina el lienzo de la página anfitriona. El HUD se recalcula al redimensionar: texto de 16/18 px según ancho, panel lateral de 390–560 px y separación entre recursos, avisos, acciones y cámara. Comprobado geométricamente en 1280×720, 1600×900 y 1920×1080; no implica validación móvil ni de una exportación web.

F11 o **Ajustes → Pantalla completa** alternan el modo de ventana. En web, ese botón se debe activar desde el gesto del usuario; el comportamiento y tamaño final deben probarse en el alojamiento/navegador real. Las reglas de simulación y el resumen no cambian con el tamaño. Los paneles de historial y resumen aprovechan la altura disponible y mantienen scroll propio.

La pantalla de partida usa ahora `WorldView` a ventana completa y un `HUD` superpuesto, sin encabezado ni columna gris de diagnóstico. Recursos y potencia permanecen arriba; tiempo/velocidad y cámara abajo. La barra de acciones abre un único panel a la vez para Base, ROBERTS, Mejoras, Mantenimiento, Tripulación, Historial o Ajustes. Construir indica seleccionar una celda vacía y abre su menú contextual. Semilla y reinicio siguen accesibles en Ajustes; selección de equipo conserva su escena.

Cámara: rueda pulsada + arrastrar desplaza sobre el plano del tablero; botón derecho + arrastrar gira; girar la rueda cambia zoom. El desplazamiento usa rayos de cámara para seguir el cursor con cualquier orientación/zoom y queda limitado al área del mapa. Soltar sobre HUD o perder foco libera el arrastre. Restablecer vista recupera centro, giro y zoom. Vista inicial de 48 unidades, render del SubViewport sin reducción (`stretch_shrink=1`), MSAA 8×. Los modelos ocupan aproximadamente 75% del ancho de su huella lógica; las etiquetas se elevan sobre su altura. Esto no cambia costos, celdas reservadas ni reglas de colocación. El aumento de antialiasing debe medirse en la futura exportación web.

Seleccionar un edificio ahora abre Base/inspector **sin apagarlo**. La acción Encender/Apagar es un botón explícito del inspector. Los comandos del dominio no cambian. Las pruebas de integración verifican la nueva interacción, el viewport a tamaño completo y exclusión de paneles; las de historial abren su panel antes de desplazar. Mantenimiento conserva sus controles de prueba hasta integrar las escenas reales de Luque.

Al integrar, conservar los `.gd.uid` generados y los cambios en `domain/`, `data/balance.json`, `tests/` y esta guía. La escena técnica es opcional. Andrés debe combinar el `project.godot` con el suyo; no sobrescribir su escena principal. Ignorar `.godot/`, `local-only/` y archivos temporales. Este incremento no hace commit ni push.

Los directorios `skills-rafael/`, `skills-equipo/` y `Especificaciones/` se conservan dentro de `local-only/`, junto con planes personales y resultados de pruebas. Esta carpeta y `.agents/` están excluidas mediante `.gitignore`. No enviar logs, preferencias del motor ni cachés generados.
